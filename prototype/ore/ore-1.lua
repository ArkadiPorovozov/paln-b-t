local tile_sounds = require("__base__.prototypes.tile.tile-sounds")
local resource_autoplace = require("resource-autoplace")



local ore_it = table.deepcopy(data.raw["item"]["iron-ore"])
ore_it.name = "zalupa1"
ore_it.place_result = ore_it.name
ore_it.subgroup = "space-platform"
data:extend({ore_it})


local ore = table.deepcopy(data.raw["resource"]["iron-ore"])
ore.name = ore_it.name
ore.additional_pastable_entities = "wetland-dead-skin"
data:extend({ore})