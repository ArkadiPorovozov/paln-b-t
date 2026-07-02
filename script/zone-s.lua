local config = require("config")
local zone = {}

-- Проверка квадратного радиуса при установке
function zone.check_placement(entity, player_index)
    local params = config.scrubbers[entity.name]
    if not params then return true end

    local r = params.radius
    local pos = entity.position
    local area = {{pos.x - r, pos.y - r}, {pos.x + r, pos.y + r}}

    local neighbors = entity.surface.find_entities_filtered{
        name = entity.name,
        area = area
    }

    for _, neighbor in pairs(neighbors) do
        if neighbor ~= entity then
            zone.reject_placement(entity, player_index, r)
            return false
        end
    end
    return true
end

function zone.reject_placement(entity, player_index, r)
    local surface = entity.surface
    local pos = entity.position
    local player = player_index and game.players[player_index]

    if player then
        player.create_local_flying_text{
            text = "♂️ Too close, jabroni! Radius: " .. r .. " ♂️",
            position = pos,
            color = {1, 0, 0}
        }
        local stack = entity.prototype.items_to_place_this[1]
        if stack then player.insert(stack) end
    else
        surface.spill_item_stack(pos, entity.prototype.items_to_place_this[1])
    end
    entity.destroy()
end

return zone