-- script/effects.lua
local config = require("script.config")
local effects = {}

function effects.spawn_turbine_steam(entity)
    if not entity or not entity.valid then return end

    local surface = entity.surface
    local pos = entity.position
    local speed = entity.crafting_speed

    local amount = math.ceil(config.visuals.base_smoke_count * speed)

    for i = 1, amount do
        local rx = (math.random() - config.random_tr.range) * config.random_tr.frequency
        local ry = (math.random() - config.random_tr.range) * config.random_tr.frequency

        pcall(function()
            surface.create_trivial_smoke{
                name = config.visuals.smoke_name,
                position = {
                    pos.x + config.visuals.smoke_offset.x + rx,
                    pos.y + config.visuals.smoke_offset.y + ry
                },
                vertical_speed = config.visuals.vertical_speed
            }
        end)
    end
end


function effects.spawn_punishment_smoke(slave, multiplier)
    if not slave or not slave.valid then return end

    local p_config = config.punishment_visuals
    local surface = slave.surface
    local pos = slave.position

    local amount = math.ceil(p_config.count * multiplier)

    for i = 1, amount do
        local rx = (math.random() - 0.5) * 2 * p_config.deviation.x
        local ry = (math.random() - 0.5) * 2 * p_config.deviation.y

        pcall(function()
            surface.create_trivial_smoke{
                name = p_config.smoke_name,
                position = {
                    pos.x + p_config.offset.x + rx,
                    pos.y + p_config.offset.y + ry
                },
                vertical_speed = p_config.vertical_speed + (math.random() * 0.02)
            }
        end)
    end
end

return effects