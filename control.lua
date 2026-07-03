-- control.lua
local config = require("script.config")
local effects = require("script.effects")


local function ensure_storage()
    storage.scrubbers = storage.scrubbers or {}
end

script.on_init(ensure_storage)
script.on_configuration_changed(ensure_storage)


local function get_slaves_in_square(scrubber)
    local r = config.scrubber.square_range
    local pos = scrubber.position
    local area = {{pos.x - r, pos.y - r}, {pos.x + r, pos.y + r}}

    return scrubber.surface.find_entities_filtered{
        area = area,
        name = config.slaves.target_names 
    }
end


script.on_nth_tick(config.scrubber.check_interval, function(event)
    ensure_storage()

    for i = #storage.scrubbers, 1, -1 do
        local scrubber = storage.scrubbers[i]

        if not scrubber or not scrubber.valid then
            table.remove(storage.scrubbers, i)
        else

            if scrubber.status == defines.entity_status.working then
                effects.spawn_turbine_steam(scrubber)

                local current_speed = scrubber.crafting_speed
                if not current_speed or current_speed <= 0 then current_speed = 1 end

                local final_damage = config.scrubber.base_damage * current_speed

                local slaves = get_slaves_in_square(scrubber)

                for _, slave in pairs(slaves) do
                    if slave.valid then

                        slave.damage(final_damage, scrubber.force, config.scrubber.damage_type)

                        effects.spawn_punishment_smoke(slave, current_speed)
                    end
                end
            end
        end
    end
end)


local function on_built(event)
    ensure_storage()
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end

    if entity.name == config.scrubber.name then
        local pos = entity.position
        local r = config.scrubber.square_range * 2

        local area = {
            {pos.x - (r - 0.1), pos.y - (r - 0.1)}, 
            {pos.x + (r - 0.1), pos.y + (r - 0.1)}
        }

        local rivals = entity.surface.find_entities_filtered{
            area = area,
            name = config.scrubber.name
        }

        if #rivals > 1 then
            local player = event.player_index and game.get_player(event.player_index)
            if player then
                player.create_local_flying_text{
                    text = "THIS GYM IS TOO SMALL FOR TWO MASTERS! ♂️",
                    position = entity.position,
                    color = {r = 1, g = 0, b = 0}
                }
                local inserted = player.insert({name = config.scrubber.name, count = 1})
                if inserted == 0 then
                    entity.surface.spill_item_stack(entity.position, {name = config.scrubber.name, count = 1})
                end
            end
            entity.destroy()
            return
        end
        table.insert(storage.scrubbers, entity)
    end
end

script.on_event({
    defines.events.on_built_entity, 
    defines.events.on_robot_built_entity, 
    defines.events.on_space_platform_built_entity
}, on_built)