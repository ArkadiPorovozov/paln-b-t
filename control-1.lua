-- ============================================================================
-- СЕКЦИЯ 1: ПОДКЛЮЧЕНИЕ МОДУЛЕЙ
-- ============================================================================
local config       = require("script.config")
local gui          = require("script.gui")
local logic        = require("script.logic")
local effects      = require("script.effects")
local server_logic = require("script.server_logic")
local smoke        = require("script.smoke")

-- ============================================================================
-- СЕКЦИЯ 2: ИНИЦИАЛИЗАЦИЯ И ОБНОВЛЕНИЕ
-- ============================================================================
local function setup_all()
    storage.shells = storage.shells or {}
    storage.players = storage.players or {}
    storage.radiators = storage.radiators or {}
    
    for _, player in pairs(game.players) do
        gui.create_main_button(player)
    end
end

script.on_init(setup_all)

script.on_configuration_changed(function()
    setup_all()
    smoke.rescan_all() -- Находим все радиаторы при обновлении/загрузке
end)

script.on_event(defines.events.on_player_created, function(event)
    setup_all()
end)

-- ============================================================================
-- СЕКЦИЯ 3: ЯДРО ПЕРЕСЕЛЕНИЯ (TRANSFER)
-- ============================================================================
function complete_transfer(player, idx)
    storage.shells = storage.shells or {}
    local target = storage.shells[idx]
    if not target or not target.valid then return end
    
    local target_capacity = server_logic.get_cooling_capacity(target.surface)
    
    -- Финальная проверка связи и охлаждения
    if target_capacity == 0 or not server_logic.is_server_available(player.surface) or not server_logic.is_server_available(target.surface) then
        player.print({"big-niga.no-link-error"}, {1, 0, 0})
        return 
    end

    -- Очистка статуса сервера перед воплощением
    server_logic.clear_server_status(player)

    local p_data = storage.players[player.index]
    if p_data then
        p_data.slow_death_ticks = 0
        p_data.fatal_death_ticks = 0
        p_data.spasm_stage = nil
        p_data.last_transfer = game.tick -- Запуск КД
        p_data.is_in_server = false
    end

    -- Упаковка текущего тела (если есть)
    if player.character then
        local old_shell = player.character.surface.create_entity{
            name = "sleeping-body", position = player.character.position, force = player.force, color = player.color
        }
        logic.transfer_items(player.character, old_shell, true)
        player.character.destroy()
        table.insert(storage.shells, old_shell)
    end
    
    -- Прыжок
    player.teleport(target.position, target.surface)
    local new_char = target.surface.create_entity{name = "character", position = target.position, force = player.force}
    player.set_controller{type = defines.controllers.character, character = new_char}
    
    -- Распаковка
    logic.transfer_items(target, new_char, false)
    target.destroy()
    table.remove(storage.shells, idx)

    -- Применение побочных эффектов (из модуля effects)
    effects.apply_reincarnation_side_effects(player)
    
    if config.SOUND_FINISH then player.play_sound{path = config.SOUND_FINISH} end
    if player.gui.screen.body_master_frame then player.gui.screen.body_master_frame.destroy() end
end

-- ============================================================================
-- СЕКЦИЯ 4: ОБРАБОТКА ТИКОВ (БЛОКИРОВКА, UI, ДЫМ)
-- ============================================================================
script.on_event(defines.events.on_tick, function(event)
    for p_idx, data in pairs(storage.players or {}) do
        local p = game.get_player(p_idx)
        if p and p.valid then
            
            -- ПОЛНАЯ БЛОКИРОВКА В СЕРВЕРЕ
            if data.is_in_server then
                if data.current_server and data.current_server.valid then 
                    p.teleport(data.current_server.position)
                    p.walking_state = {walking = false, direction = 0}
                else 
                    server_logic.clear_server_status(p) 
                end
            end

            -- Обновление таймеров GUI (раз в секунду)
            if event.tick % 60 == 0 and p.gui.screen.body_master_frame then
                gui.update_timer(p)
            end

            -- Эффекты крови и урона
            effects.process_tick(p, data, event.tick)

            -- Обработка таймера телепортации
            if data.transfer_target_tick and event.tick >= data.transfer_target_tick then
                complete_transfer(p, data.target_shell_idx)
                data.transfer_target_tick = nil
            end
        end
    end

    -- ОБНОВЛЕНИЕ ДЫМА РАДИАТОРОВ
    smoke.update(event.tick)
end)

-- ============================================================================
-- СЕКЦИЯ 5: GUI СОБЫТИЯ И КЛИКИ
-- ============================================================================
script.on_event(defines.events.on_gui_click, function(event)
    local p, name = game.get_player(event.player_index), event.element.name
    
    if name == "bn_main_button" then gui.open_body_menu(p)
    elseif name == "bn_close_menu" then p.gui.screen.body_master_frame.destroy()
    
    -- ПРЫЖОК В ХАБ ПЛАНЕТЫ
    elseif name:find("bn_hub_jump_") then
        local target = game.surfaces[name:match("bn_hub_jump_(.*)")]
        if target and server_logic.is_server_available(target) then
            if p.character and server_logic.get_current_shells_count(p.surface) >= server_logic.get_cooling_capacity(p.surface) then
                p.print({"big-niga.overheat-error"}); return
            end
            if p.character then
                local old_shell = p.character.surface.create_entity{name = "sleeping-body", position = p.character.position, force = p.force, color = p.color}
                logic.transfer_items(p.character, old_shell, true); p.character.destroy(); table.insert(storage.shells, old_shell)
            end
            local ent = server_logic.get_server_entity(target)
            p.set_controller{type = defines.controllers.ghost}; p.teleport(ent.position, ent.surface)
            storage.players[p.index].is_in_server, storage.players[p.index].current_server = true, ent
            gui.open_body_menu(p); game.print({"big-niga.hub-connected", target.name:upper()})
        end
    
    -- ВХОД В СОСУД (ENTER)
    elseif name:find("bn_transfer_idx_") then
        local idx = tonumber(name:match("bn_transfer_idx_(%d+)"))
        local p_data = storage.players[p.index]
        local target_shell = storage.shells[idx]
        
        if not target_shell or server_logic.get_cooling_capacity(target_shell.surface) == 0 then 
            p.print({"big-niga.no-link-error"}, {1, 0, 0}); return 
        end
        
        if (p_data.last_transfer and game.tick < p_data.last_transfer + (config.TRANSFER_COOLDOWN * 60)) or p_data.transfer_target_tick then return end
        
        p.print({"big-niga.transfer-initiated"})
        if config.SOUND_START then p.play_sound{path = config.SOUND_START} end
        p_data.transfer_target_tick, p_data.target_shell_idx = game.tick + (config.TRANSFER_DURATION * 60), idx
        gui.update_timer(p)
    end
end)

-- Фикс закрытия на ESC и E
script.on_event(defines.events.on_gui_closed, function(event)
    if event.element and event.element.name == "body_master_frame" then event.element.destroy() end
end)

-- Перехват открытия сервера (вместо инвентаря открываем Хаб)
script.on_event(defines.events.on_gui_opened, function(event)
    if event.entity and event.entity.name == config.SERVER_BUILDING_NAME then
        local p = game.get_player(event.player_index)
        p.opened = nil 
        gui.open_body_menu(p)
    end
end)

-- ============================================================================
-- СЕКЦИЯ 6: ПОСТРОЙКА, СМЕРТЬ И СНОС
-- ============================================================================
local function handle_built(ent, p_idx)
    if not ent or not ent.valid then return end
    
    -- Регистрация радиатора (для дыма)
    if ent.name == config.RADIATOR_NAME then smoke.register_radiator(ent) end

    -- Регистрация сервера
    if ent.name == config.SERVER_BUILDING_NAME and not server_logic.check_server_limit(ent) then
        local p = p_idx and game.get_player(p_idx); if p then p.insert{name = config.SERVER_BUILDING_NAME, count = 1} end; ent.destroy()
    
    -- Регистрация сосуда (с проверкой охлаждения)
    elseif ent.name == "sleeping-body" then
        if server_logic.get_current_shells_count(ent.surface) >= server_logic.get_cooling_capacity(ent.surface) then
            local p = p_idx and game.get_player(p_idx); if p then p.print({"big-niga.overheat-error"}); p.insert{name = "body-capsule", count = 1} end; ent.destroy()
        else 
            table.insert(storage.shells, ent)
            if p_idx then ent.color = game.get_player(p_idx).color end 
        end
    end
end

script.on_event(defines.events.on_built_entity, function(e) handle_built(e.entity, e.player_index) end)
script.on_event(defines.events.on_robot_built_entity, function(e) handle_built(e.created_entity) end)
script.on_event(defines.events.on_space_platform_built_entity, function(e) handle_built(e.entity) end)
script.on_event(defines.events.script_raised_built, function(e) handle_built(e.entity) end)

-- ЛОГИКА СМЕРТИ (Взрыв сервера, снос, аннигиляция трупа)
local function kill_player_in_server(entity)
    for p_idx, data in pairs(storage.players) do
        local p = game.get_player(p_idx); if p and data.is_in_server and data.current_server == entity then
            p.print({"big-niga.hardware-lost"}); data.destroy_corpse_next_tick = true; 
            if p.character then p.character.die() else 
                local tmp = entity.surface.create_entity{name="character", position=entity.position, force=p.force}
                p.set_controller{type=defines.controllers.character, character=tmp}; tmp.die()
            end; server_logic.clear_server_status(p)
        end
    end
end

script.on_event(defines.events.on_entity_died, function(e)
    if e.entity.name == config.SERVER_BUILDING_NAME then kill_player_in_server(e.entity)
    elseif e.entity.name == "sleeping-body" then for i, s in ipairs(storage.shells) do if s == e.entity then table.remove(storage.shells, i); break end end end
end)

script.on_event(defines.events.on_player_mined_entity, function(e)
    if e.entity.name == config.SERVER_BUILDING_NAME then kill_player_in_server(e.entity)
    elseif e.entity.name == "sleeping-body" then for i, s in ipairs(storage.shells) do if s == e.entity then table.remove(storage.shells, i); break end end end
end)

script.on_event(defines.events.on_player_died, function(e) 
    local p = game.get_player(e.player_index); if p.gui.screen.body_master_frame then p.gui.screen.body_master_frame.destroy() end
    local d = storage.players[e.player_index]; if d and d.destroy_corpse_next_tick then
        for _, c in pairs(p.surface.find_entities_filtered{name="character-corpse", position=p.position, radius=5}) do c.destroy() end; d.destroy_corpse_next_tick = false
        game.print({"big-niga.body-collapsed"})
    end
end)

-- ============================================================================
-- СЕКЦИЯ 7: УПРАВЛЕНИЕ (ХОТКЕЙ)
-- ============================================================================
script.on_event("bn-open-menu-hotkey", function(e) 
    local p = game.get_player(e.player_index)
    if p.gui.screen.body_master_frame then p.gui.screen.body_master_frame.destroy() else gui.open_body_menu(p) end 
end)