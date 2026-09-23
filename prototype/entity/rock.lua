local hit_effects = require ("__base__.prototypes.entity.hit-effects")
local base_tile_sounds = require("__base__.prototypes.tile.tile-sounds")
local space_age_tile_sounds = require ("__space-age__.prototypes.tile.tile-sounds")
local base_sounds = require("__base__.prototypes.entity.sounds")
local decorative_trigger_effects = require("__base__.prototypes.decorative.decorative-trigger-effects")
local simulations = require("__space-age__.prototypes.factoriopedia-simulations")


local function collision_mask_1()
    return {
        layers = {
            ground_tile = true
        }
    }
end



local vulcanus_c_name = table.deepcopy(data.raw["simple-entity"]["vulcanus-chimney-cold"].name)

local new_name = vulcanus_c_name .. "q1"
local vulcanus_c_it = {
    type = "item",
    name = new_name,
    icon = data.raw["simple-entity"]["vulcanus-chimney-cold"].icon,
    icon_size = data.raw["simple-entity"]["vulcanus-chimney-cold"].icon_size,
    subgroup = data.raw["simple-entity"]["vulcanus-chimney-cold"].subgroup,
    order = "a[chimney]-a",
    stack_size = 50,
    place_result = new_name
}
data:extend({ vulcanus_c_it })

local vulcanus_c = table.deepcopy(data.raw["simple-entity"]["vulcanus-chimney-cold"])
vulcanus_c.name = new_name
vulcanus_c.minable = { mining_time = 0.5, result = new_name }
vulcanus_c.collision_mask = collision_mask_1()
data:extend({vulcanus_c})


