local zone = require("script.zone-s")
local work = require("script.work-s")
local config = require("script.config")

-- ♂️ Debug Command ♂️
commands.add_command("scrub_debug", "Toggle Gym Visualization", function()
    storage.debug_enabled = not storage.debug_enabled
    rendering.clear(script.mod_name)
    game.print("♂️ Scrubber Debug: " .. (storage.debug_enabled and "ON" or "OFF") .. " ♂️")
end)

-- Отрисовка радиусов для Master'а
local function draw_debug_zones()
    if not storage.debug_enabled then return end
    rendering.clear(script.mod_name)
    
    for name, params in pairs(config.scrubbers) do
        for _, surface in pairs(game.surfaces) do
            local entities = surface.find_entities_filtered{name = name}
            for _, ent in pairs(entities) do
                rendering.draw_rectangle{
                    color = params.color,
                    width = 2,
                    filled = false,
                    left_top = {ent.position.x - params.radius, ent.position.y - params.radius},
                    right_bottom = {ent.position.x + params.radius, ent.position.y + params.radius},
                    surface = ent.surface,
                    target = ent,
                    draw_on_ground = true,
                    time_to_live = 65 -- чуть больше секунды (если обновляем раз в 60 тиков)
                }
            end
        end
    end
end

-- Обработка событий
script.on_event({
    defines.events.on_built_entity, 
    defines.events.on_robot_built_entity, 
    defines.events.on_space_platform_built_entity
}, function(event)
    local ent = event.entity
    if not (ent and ent.valid) then return end

    -- Проверка на расстановку
    if config.scrubbers[ent.name] then
        zone.check_placement(ent, event.player_index)
    end

    -- Если поставили раба, сразу чекаем его статус
    if config.slaves[ent.name] then
        work.update_slave_status(ent)
    end
end)

-- Рабочий цикл
script.on_nth_tick(60, function()
    work.process_all_slaves()
    if storage.debug_enabled then
        draw_debug_zones()
    end
end)

-- Инициализация storage
script.on_init(function()
    storage.debug_enabled = false
end)