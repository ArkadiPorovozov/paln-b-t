--[[
script.on_event(defines.events.on_player_mined_item, function(event)
    -- event.item_stack — это стек предмета (LuaItemStack)
    -- event.player_index — ID игрока, который это сделал
    
    local player = game.players[event.player_index]
    local item_name = event.item_stack.name

    if item_name == "iron-ore" then
        player.print("[eq")
    end
end)
]]

--[[
local function tech_unlock(event, name, message)
    if event.research.name == name then
        for _, player in pairs(event.research.force.players) do
            rendering.draw_text{
                text = message,
                surface = player.surface,
                target = player.character, -- привязка к игроку
                target_offset = {0, -2},    -- чуть выше головы
                players = {player},        -- видит только этот игрок
                time_to_live = 300,
                color = {1, 1, 0},
                alignment = "center",
                scale = 2
            }
        end
    end
end
]]
--[[
local function tech_unlock(event, name, message)
    if event.research.name == name then
        for _, player in pairs(event.research.force.players) do
            player.show_message_dialog{
                text = {"", "[font=heading-1]", message, "[/font]"},
                image = "technology/" .. name -- Покажет иконку технологии
            }
        end
    end
end



script.on_event(defines.events.on_research_finished, function(event)
    tech_unlock(event, "fast-inserter", "[color=255,0,0]fuck you[/color]: 123")
end)
]]

--[[
local function tech_unlock(event, name, message, color, time)
    if event.research.name == name then
        for _, player in pairs(event.research.force.players) do
            -- 1. Создаем "голый" текст без рамок
            local label = player.gui.screen.add{
                type = "label",
                name = "text_notify_" .. event.tick, -- уникальное имя
                caption = message
            }
            -- 2. Настраиваем внешний вид (размер и цвет)
            label.style.font = "heading-1" -- самый большой шрифт
            label.style.font_color = color  -- желтый
            label.force_auto_center() -- в центр экрана

            -- 3. Запоминаем, когда удалить (через 3 секунды = 180 тиков)
            storage.timers = storage.timers or {}
            storage.timers[label.name] = {
                player = player,
                destroy_at = event.tick + time
            }
        end
    end
end

script.on_nth_tick(30, function(event)
    if not storage.timers then return end

    for label_name, data in pairs(storage.timers) do
        if event.tick >= data.destroy_at then
            if data.player and data.player.valid then
                if data.player.gui.screen[label_name] then
                    data.player.gui.screen[label_name].destroy()
                end
            end
            storage.timers[label_name] = nil
        end
    end
end)

script.on_event(defines.events.on_research_finished, function(event)
    tech_unlock(event, "fast-inserter", "ТЕХНОЛОГИЯ ИЗУЧЕНА: МАНИПУЛЯТОРЫ", {1, 1, 0}, 180)
end)
]]


--require("script.planet-logistics")
require("script.carkas")
--require("control-alert-sys")


--require("script.penis")



