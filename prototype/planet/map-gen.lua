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

-- Первый, простой вариант:
-- белая нефть везде, острова — песок, пыль и дюны Фульгоры,
-- а на островах-гигантах — высокогорный камень, фульгорианский камень,
-- лава и горячая лава.
local tiles = {
  "white-oil-ocean-deep-2",
  "fulgoran-sand",
  "fulgoran-dust",
  "fulgoran-dunes",
  "highland-dark-rock-2",
  "fulgoran-rock",
  "lava",
  "lava-hot",
}

local tile_probabilities = {
  ["white-oil-ocean-deep-2"] = "zalupa_oil_prob",
  ["fulgoran-sand"] = "zalupa_sand_island_prob",
  ["fulgoran-dust"] = "zalupa_dust_island_prob",
  ["fulgoran-dunes"] = "zalupa_dunes_island_prob",
  ["highland-dark-rock-2"] = "zalupa_volcano_rock_prob",
  ["fulgoran-rock"] = "zalupa_volcano_fulgoran_prob",
  ["lava"] = "zalupa_volcano_lava_prob",
  ["lava-hot"] = "zalupa_volcano_hot_prob",
}

planet_map_gen.p1 = function()
  local tile_settings = {}
  local property_expression_names = {
    elevation = "const_zero",
    temperature = "const_zero",
    moisture = "const_zero",
    aux = "const_zero",
    cliffiness = "const_zero",
    cliff_elevation = "const_zero",
  }

  for _, name in ipairs(tiles) do
    tile_settings[name] = {}
    property_expression_names["tile:" .. name .. ":probability"] =
      tile_probabilities[name]
    property_expression_names["tile:" .. name .. ":richness"] = "const_zero"
  end

  return {
    property_expression_names = property_expression_names,
    autoplace_settings = {
      tile = {
        -- только нефть и островные тайлы: никакой травы и прочего мусора
        treat_missing_as_default = false,
        settings = tile_settings,
      },
      decorative = {
        treat_missing_as_default = false,
        settings = {},
      },
      entity = {
        -- только руды q1/q2, без деревьев/камней с других планет
        treat_missing_as_default = false,
        settings = {
          ["q1-ore"] = {},
          ["q2-ore"] = {},
        },
      },
    },
  }
end

return planet_map_gen
