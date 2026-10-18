-- sheathing-ground (плитка земли)
local clone_entity = require("prototype.entity.clone-entity")

local spase_ground_it = clone_entity("item", "space-platform-for-ground", "sheathing-ground", {
    subgroup = "space-platform",
    place_as_tile = {
      result = "sheathing-ground",
      condition_size = 1,
      condition = {layers={water_tile=true}}
    },
    order = "vc[sheathing-ground]",
})
if spase_ground_it then data:extend({spase_ground_it}) end


local spase_ground = clone_entity("tile", "space-platform-for-ground", "sheathing-ground",
    {
        layer_group = "ground",
        minable = {mining_time = 0.1, result = "sheathing-ground"},
    },
    {
        "surface_conditions",
        "surface_condition",
        "bound_decoratives"
    }
)

if spase_ground then
    spase_ground.layer = 100
    data:extend({spase_ground})
end
