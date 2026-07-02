local config = require("script.config")
local zone = {}

function zone.check_placement(entity, player_index)
    if not (entity and entity.valid) or entity.name ~= config.scrubber_name then return end
    
    local r = config.radius
    local area = {
        {entity.position.x - r, entity.position.y - r},
        {entity.position.x + r, entity.position.y + r}
    }

    local neighbors = entity.surface.find_entities_filtered{
        name = config.scrubber_name,
        area = area
    }

    for _, n in pairs(neighbors) do
        if n ~= entity then
            if player_index then
                game.players[player_index].create_local_flying_text{
                    text = "♂️ Hey Jabroni, too close! (Radius " .. r .. ") ♂️",
                    position = entity.position,
                    color = {1, 0, 0}
                }
            end
            entity.destroy()
            return
        end
    end
end

return zone