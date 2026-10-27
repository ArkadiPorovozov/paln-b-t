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
-- пустой космос везде, острова — песок, пыль и дюны Фульгоры,
-- а на островах-гигантах — высокогорный камень, фульгорианский камень,
-- лава и горячая лава.
-- Большие острова (средний размер) — как гиганты, но без высокой скалы,
-- а лава заменена белой нефтью (white-oil-ocean-deep-2).
local tiles = {
  "empty-space",
  "fulgoran-sand",
  "fulgoran-dust",
  "fulgoran-dunes",
  "highland-dark-rock-2",
  "fulgoran-rock",
  "lava",
  "lava-hot",
  -- белая нефть: на больших островах заменяет лаву
  "white-oil-ocean-deep-2",
}

local tile_probabilities = {
  ["empty-space"] = "zalupa_space_prob",
  ["fulgoran-sand"] = "zalupa_sand_island_prob",
  ["fulgoran-dust"] = "zalupa_dust_island_prob",
  ["fulgoran-dunes"] = "zalupa_dunes_island_prob",
  ["highland-dark-rock-2"] = "zalupa_volcano_rock_prob",
  ["fulgoran-rock"] = "zalupa_volcano_fulgoran_prob",
  ["lava"] = "zalupa_volcano_lava_prob",
  ["lava-hot"] = "zalupa_volcano_hot_prob",
  ["white-oil-ocean-deep-2"] = "zalupa_big_oil_prob",
}

-- Планета sun: вся поверхность — лава (sun-surface), по которой можно
-- построить фундамент космической платформы (см. prototype/tile.lua).
-- Исключение — пятачок фундамента в точке высадки (sun_landing_pad_prob,
-- см. prototype/planet/noise-data.lua): без него на лаву нельзя
-- высадиться и негде построить первый фундамент.
--
-- Руд на sun нет вообще: список руд передаётся третьим аргументом, и для sun
-- он пустой. Вместе с рудами пропадают и облака над ними (см.
-- data-final-fixes.lua) — на раскалённой лаве им не место.
local sun_tiles = {
  "sun-surface",
  "sun-platform-foundation",
}

local sun_tile_probabilities = {
  ["sun-surface"] = "const_one",
  ["sun-platform-foundation"] = "sun_landing_pad_prob",
}

-- Руда, которая генерируется на планете. Пустой список — планета без руд:
-- entity.settings остаётся пустым, а treat_missing_as_default = false
-- запрещает движку включить все руды по умолчанию.
local DEFAULT_ORES = {"q1-ore", "q2-ore"}
local SUN_ORES = {}

local function make_map_gen(tile_names, probabilities, ores)
  return function()
    local tile_settings = {}
    local entity_settings = {}
    local property_expression_names = {
      elevation = "const_zero",
      temperature = "const_zero",
      moisture = "const_zero",
      aux = "const_zero",
      cliffiness = "const_zero",
      cliff_elevation = "const_zero",
    }

    for _, name in ipairs(tile_names) do
      tile_settings[name] = {}
      property_expression_names["tile:" .. name .. ":probability"] =
        probabilities[name]
      property_expression_names["tile:" .. name .. ":richness"] = "const_zero"
    end

    for _, name in ipairs(ores or {}) do
      entity_settings[name] = {}
    end

    return {
      property_expression_names = property_expression_names,
      autoplace_settings = {
        tile = {
          -- только космос, лава и островные тайлы
          treat_missing_as_default = false,
          settings = tile_settings,
        },
        decorative = {
          treat_missing_as_default = false,
          settings = {},
        },
        entity = {
          -- только руды из списка планеты, без деревьев/камней с других планет
          treat_missing_as_default = false,
          settings = entity_settings,
        },
      },
    }
  end
end

planet_map_gen.p1 = make_map_gen(tiles, tile_probabilities, DEFAULT_ORES)
-- sun без руд: ни q1/q2, ни каких-либо других.
planet_map_gen.sun = make_map_gen(sun_tiles, sun_tile_probabilities, SUN_ORES)

return planet_map_gen
