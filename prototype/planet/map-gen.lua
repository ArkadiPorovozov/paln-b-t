local planet_map_gen = require("__base__/prototypes/planet/planet-map-gen")
data:extend({
  {
    type = "noise-expression",
    name = "const_zero",
    expression = "0"
  },
  {
    type = "noise-expression",
    name = "const_one",
    expression = "1"
  },
})


planet_map_gen.p1 = function()
  return {
    property_expression_names = {
      elevation       = "const_zero",
      temperature     = "const_zero",
      moisture        = "const_zero",
      aux             = "const_zero",
      cliffiness      = "const_zero",
      cliff_elevation = "const_zero",

      --["entity:electrolyte-well:probability"] = "electrolyte_well_probability",
      --["entity:electrolyte-well:richness"]    = "electrolyte_well_richness",

      --["entity:satellite-debris:probability"] = "satellite_debris_probability",
      --["entity:satellite-debris:richness"]    = "satellite_debris_richness",

--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---         
      --["tile:wetland-dead-skiprobability"] = "water_mask",
        ["tile:wetland-dead-skin:richness"] = "const_zero",
        ["tile:volcanic-folds:richness"] = "const_zero",
        ["tile:volcanic-cracks:richness"] = "const_zero",
        ["tile:volcanic-folds-flat:richness"] = "const_zero",
        ["tile:wetland-dead-skin:probability"]   = "dead_skin_prob",
        ["tile:volcanic-folds-flat:probability"] = "volcanic_folds_flat_prob",
        ["tile:volcanic-cracks:probability"]     = "volcanic_cracks_prob",
        ["tile:volcanic-folds:probability"]      = "volcanic_folds_prob",
      --["tile:refined-concrete:probability"] = ""
    },
    autoplace_settings =
    {
      tile =
      {
        settings =
        {
            ["wetland-dead-skin"] = {},
            ["volcanic-folds"] = {},
            ["volcanic-cracks"] = {},
            ["volcanic-folds-flat"] = {},
        }
      },
      decorative = {
        settings =
        {
          --["matches-small"]        = {},
          --["polycephalum-balloon"] = {},
        }
      },
      entity = {
        settings = {
          --["electrolyte-well"] = {},
          --["satellite-debris"] = {},
          ["q1-ore"] = {},
          ["q2-ore"] = {},
        }
      },
--[[
      autoplace_controls = {
        ["electrolyte_well"] = {},
        ["satellite_debris"] = {},
        ["rot_ore"] = {},
      },
]]
    }
  }
end

return planet_map_gen

--wetland-dead-skin=Мёртвое болото
--volcanic-folds=Вулканические складки
--volcanic-cracks=Вулканические трещины
--volcanic-folds-flat=Плоские вулканические складки

--refined-concrete