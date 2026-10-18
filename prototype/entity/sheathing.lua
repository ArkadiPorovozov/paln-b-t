-- sheathing (стена)
local clone_entity = require("prototype.entity.clone-entity")

local master_wall = clone_entity("wall", "snouz_wall_hull", "sheathing", {
    max_health = 500,
    place_result = "sheathing",
    minable = {mining_time = 0.2, result = "sheathing"},
})
if master_wall then data:extend({master_wall}) end

local master_wall_item = clone_entity("item", "snouz_wall_hull", "sheathing", {
    place_result = "sheathing",
    order = "vc[sheathing]",
    minable = {mining_time = 0.4, result = "sheathing"},
    stack_size = 100,

})
if master_wall_item then data:extend({master_wall_item}) end
