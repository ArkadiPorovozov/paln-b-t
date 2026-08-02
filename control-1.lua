local config = require("script.config")
local effects = require("script.effects")


local neural = nil
if config.NEURAL_NETWORK_ENABLED then
    neural = require("script.neural_system")
end

local function ensure_storage()
    storage.scrubbers = storage.scrubbers or {}
    if config.NEURAL_NETWORK_ENABLED and neural then neural.init_storage() end
end

script.on_init(ensure_storage)
script.on_configuration_changed(ensure_storage)


script.on_nth_tick(config.scrubber.check_interval, function(event)
    ensure_storage()


    for i = #storage.scrubbers, 1, -1 do
        local ent = storage.scrubbers[i]
        if not ent or not ent.valid then table.remove(storage.scrubbers, i)
        elseif ent.status == defines.entity_status.working then
            effects.spawn_turbine_steam(ent)
            local speed = ent.crafting_speed or 1
            local final_damage = config.scrubber.base_damage * speed
            local slaves = ent.surface.find_entities_filtered{
                area = {{ent.position.x-10, ent.position.y-10}, {ent.position.x+10, ent.position.y+10}},
                name = config.slaves.target_names
            }
            for _, slave in pairs(slaves) do
                if slave.valid then
                    slave.damage(final_damage, ent.force, config.scrubber.damage_type)
                    effects.spawn_punishment_smoke(slave, speed)
                end
            end
        end
    end


    if config.NEURAL_NETWORK_ENABLED and neural then
        neural.process_tick(event.tick)
    end
end)

script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, function(event)
    ensure_storage()
    local ent = event.entity or event.created_entity
    if not ent or not ent.valid then return end

    -- Scrubber Logic
    if ent.name == config.scrubber.name then
        -- (Твоя проверка на "иди нахуй" и дистанцию остается тут)
        table.insert(storage.scrubbers, ent)
    end

    -- Neural Logic
    if config.NEURAL_NETWORK_ENABLED and neural then
        neural.handle_built(ent, event.player_index)
    end
end)

-- Передача GUI событий в модуль Neural
if config.NEURAL_NETWORK_ENABLED then
    script.on_event(defines.events.on_gui_click, function(e) neural.handle_gui(e) end)
    script.on_event("bn-open-menu-hotkey", function(e) neural.handle_hotkey(e) end)
end