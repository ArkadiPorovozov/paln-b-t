-- Генерация планеты sun: площадка высадки и устаревшие шумовые выражения.
--
-- Текущая генерация — сплошная лава (sun-surface) с пятачком фундамента в
-- точке высадки. Выражения sun_void_* оставлены только для совместимости со
-- старыми сохранениями: они ссылаются на эти имена при догенерации чанков.

local make_map_gen = require("prototype.planet.map-gen")

data:extend({
  -- =====================================================================
  -- sun: стартовая площадка и старая генерация (только совместимость).
  -- =====================================================================
  -- paln_sun_landing_pad_prob — круглая площадка фундамента радиусом ~14 тайлов
  -- вокруг начала координат, то есть в точке высадки на sun. Вся остальная
  -- поверхность планеты — лава с вероятностью 1, поэтому фундамент выигрывает
  -- только внутри круга (там вероятность до 10000).
  {
    type = "noise-expression",
    name = "paln_sun_landing_pad_prob",
    expression = [[
      (1 - clamp(sqrt(x * x + y * y) / 14, 0, 1)) * 10000
    ]]
  },

  -- Старая генерация sun (космос + моря лавы) — только для совместимости.
  -- Сейчас sun генерируется сплошной лавой (см. список tiles ниже),
  -- и эти выражения не используются. Они оставлены, потому что сохранения,
  -- созданные до переделки, хранят в map_gen_settings ссылки на них: без них
  -- старый сейв не сможет догенерировать новые чанки на sun.
  {
    type = "noise-expression",
    name = "paln_sun_void_mask",
    expression = [[
      clamp(
        (basis_noise{
          x = x + 30 * (basis_noise{
            x = x, y = y,
            seed0 = map_seed, seed1 = 7102,
            input_scale = 0.009
          } - 0.5),
          y = y + 30 * (basis_noise{
            x = x, y = y,
            seed0 = map_seed, seed1 = 7103,
            input_scale = 0.009
          } - 0.5),
          seed0 = map_seed, seed1 = 7101,
          input_scale = 0.0035
        } - 0.5) * 6,
        0, 1)
    ]]
  },

  {
    type = "noise-expression",
    name = "paln_sun_void_prob",
    expression = "paln_sun_void_mask * (1 - paln_zalupa_island_mask) * 10000 + 1"
  },

  {
    type = "noise-expression",
    name = "paln_sun_lava_prob",
    expression = "max(paln_zalupa_volcano_hot_prob, (1 - paln_sun_void_mask) * (1 - paln_zalupa_island_mask) * 10000)"
  },
})

-- Вся поверхность — лава, по которой строят фундамент платформы. Пятачок
-- фундамента в точке высадки — paln_sun_landing_pad_prob (см. выше).
local tiles = {
  "sun-surface",
  "sun-platform-foundation",
}

local tile_probabilities = {
  ["sun-surface"] = "paln_const_one",
  ["sun-platform-foundation"] = "paln_sun_landing_pad_prob",
}

-- Руд на sun нет: пустой список + treat_missing_as_default = false.
return make_map_gen(tiles, tile_probabilities, {})
