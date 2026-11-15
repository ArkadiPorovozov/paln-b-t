-- Общий помощник для map_gen_settings планет мода.
--
-- Возвращает функцию make_map_gen(tile_names, probabilities, ores,
-- entity_probabilities), которая строит таблицу map_gen_settings:
--   * базовые свойства (elevation/temperature/.../cliff_elevation) — paln_const_zero;
--   * вероятности и richness тайлов берутся из probabilities;
--   * генерируются только перечисленные руды (ores), а treat_missing_as_default
--     = false запрещает движку включить все руды по умолчанию;
--   * entity_probabilities (необязательно) переопределяет вероятность/richness
--     руд через property_expression_names ("entity:<руда>:probability"), чтобы
--     у руды в прототипе можно было держать autoplace = paln_const_zero.
-- Конкретные списки тайлов и руд задают файлы gen-<планета>.lua.

-- Базовые шумовые константы, на которые ссылаются map_gen и autoplace тайлов.
data:extend({
  {
    type = "noise-expression",
    name = "paln_const_zero",
    expression = "0",
  },
  {
    type = "noise-expression",
    name = "paln_const_one",
    expression = "1",
  },
})

local function make_map_gen(tile_names, probabilities, ores, entity_probabilities)
  return function()
    local tile_settings = {}
    local entity_settings = {}
    local property_expression_names = {
      elevation = "paln_const_zero",
      temperature = "paln_const_zero",
      moisture = "paln_const_zero",
      aux = "paln_const_zero",
      cliffiness = "paln_const_zero",
      cliff_elevation = "paln_const_zero",
    }

    for _, name in ipairs(tile_names) do
      tile_settings[name] = {}
      property_expression_names["tile:" .. name .. ":probability"] =
        probabilities[name]
      property_expression_names["tile:" .. name .. ":richness"] = "paln_const_zero"
    end

    for _, name in ipairs(ores or {}) do
      entity_settings[name] = {}
      -- У руд мода autoplace в прототипе выключен (paln_const_zero), поэтому
      -- вероятность и richness задаём здесь, попланетно.
      local overrides = entity_probabilities and entity_probabilities[name]
      if overrides then
        if overrides.probability then
          property_expression_names["entity:" .. name .. ":probability"] =
            overrides.probability
        end
        if overrides.richness then
          property_expression_names["entity:" .. name .. ":richness"] =
            overrides.richness
        end
      end
    end

    return {
      property_expression_names = property_expression_names,
      autoplace_settings = {
        tile = {
          treat_missing_as_default = false,
          settings = tile_settings,
        },
        decorative = {
          treat_missing_as_default = false,
          settings = {},
        },
        entity = {
          treat_missing_as_default = false,
          settings = entity_settings,
        },
      },
    }
  end
end

return make_map_gen
