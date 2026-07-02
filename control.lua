local config = require("script.config")
local work = require("script.work-s")
local zone = require("script.zone-s")

-- Каждую секунду проверяем рабов
script.on_nth_tick(60, function()
    for _, surface in pairs(game.surfaces) do
        work.process_all(surface)
    end
end)

-- Ивенты постройки
script.on_event({
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.on_space_platform_built_entity
}, function(event)
    local e = event.entity
    if not (e and e.valid) then return end
    
    if e.name == config.scrubber_name then
        zone.check_placement(e, event.player_index)
    elseif config.slaves[e.name] then
        work.update_entity(e, e.surface)
    end
end)

-- Удаление данных при сносе здания (чтобы не забивать память)
script.on_event({defines.events.on_player_mined_entity, defines.events.on_robot_mined_entity, defines.events.on_entity_died}, function(event)
    if event.entity and event.entity.unit_number then
        if storage.backup_recipes then
            storage.backup_recipes[event.entity.unit_number] = nil
        end
    end
end)

-- Дебаг команда
commands.add_command("scrub_debug", "♂️ Show Radius ♂️", function()
    storage.debug = not storage.debug
    rendering.clear(script.mod_name)
    game.print("♂️ Debug mode: " .. (storage.debug and "ON" or "OFF"))
end)

script.on_nth_tick(61, function()
    if not storage.debug then return end
    rendering.clear(script.mod_name)
    local r = config.radius
    for _, surface in pairs(game.surfaces) do
        local ms = surface.find_entities_filtered{name = config.scrubber_name}
        for _, m in pairs(ms) do
            rendering.draw_rectangle{
                color = {r = 1, g = 0.5, b = 0, a = 0.15},
                width = 2,
                left_top = {m.position.x - r, m.position.y - r},
                right_bottom = {m.position.x + r, m.position.y + r},
                surface = m.surface,
                target = m,
                draw_on_ground = true
            }
        end
    end
end)

-- ♂️ FULL SAFETY INITIALIZATION ♂️
local function init_storage()
    storage.backup_recipes = storage.backup_recipes or {}
    storage.debug = storage.debug or false
end

script.on_init(init_storage)
script.on_configuration_changed(init_storage)