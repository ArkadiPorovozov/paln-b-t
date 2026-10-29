-- Планета dark-ocean — океан тёмной воды с крупными вулканическими островами.
--
-- Основной тайл — dark-deep-lake (тёмная вода, см. prototype/tile.lua). Суша —
-- большие и мелкие острова из семи тёмных копий вулканических тайлов Вулкана
-- (тоже prototype/tile.lua), плюс гарантированный стартовый остров и пятачок в
-- точке высадки. Генерация островов — как на Fulgora: из полей spot_noise и
-- basis_noise (см. ниже). По каждому чанку script/dark-ocean.lua ставит
-- сущности dark-water-shader 16×16 тайлов — большой полупрозрачный слой тёмной
-- воды из prototype/dark-water.lua, поверх всей поверхности.
--
-- Файл самодостаточный: планета, технология, топология и map-gen лежат здесь,
-- поэтому всю планету можно выключить одним require в data.lua.

local q = "__paln-b-test__"
local planet_map_gen = require("__base__/prototypes/planet/planet-map-gen")
local asteroid_util = require("__space-age__/prototypes/planet/asteroid-spawn-definitions")

-- Тёмная вода — сущность и анимация для слоя поверх океана.
require("prototype.dark-water")

local PLANET = "dark-ocean"
local ICON = q .. "/graphics/icons/dark-ocean.png"

-- ---------------------------------------------------------------------------
-- Генерация карты: тёмный океан + вулканические острова по уровням
-- ---------------------------------------------------------------------------
--
-- Как на Fulgora, один остров — это одна ячейка диаграммы Вороного
-- (voronoi_cell_id): одно «зерно» = один остров. Тип острова задаётся хешем
-- ячейки и постоянен на всём острове:
--   * тип 1 (камень): folds-flat → folds → smooth-stone → smooth-stone-warm;
--   * тип 2 (пепел):  ash-cracks → ash-light → jagged-ground.
-- Внутри острова тайлы идут «по уровням»: у берега низкий уровень, к середине
-- острова — высокий. Границы уровней размыты мелким шумом, поэтому соседние
-- уровни перемешиваются, а не режутся ровной линией.
-- Всё, что не суша, — тёмная вода (dark-deep-lake, вероятность 1).
data:extend({
  -- Пятачок суши в точке высадки: гарантированно твёрдая земля радиусом ~14
  -- вокруг 0,0. Побеждает любой другой тайл (см. dark_ocean_prob_folds_flat).
  {
    type = "noise-expression",
    name = "dark_ocean_landing_pad_prob",
    expression = "(1 - clamp(sqrt(x * x + y * y) / 14, 0, 1)) * 30000",
  },

  -- Волнистость береговой линии (общая для всех островов).
  {
    type = "noise-expression",
    name = "dark_ocean_island_edge",
    expression = [[
      0.05 * (basis_noise{x = x, y = y, seed0 = map_seed, seed1 = 12004, input_scale = 0.06} - 0.5)
      + 0.03 * (basis_noise{x = x, y = y, seed0 = map_seed, seed1 = 12005, input_scale = 0.18} - 0.5)
    ]],
  },

  -- Мягкое искажение координат — чтобы зерно Вороного (а значит и остров)
  -- не сидело в правильной сетке.
  {
    type = "noise-expression",
    name = "dark_ocean_wobble_x",
    expression = [[
      multioctave_noise{x = x, y = y, seed0 = map_seed, seed1 = 12201, octaves = 4, persistence = 0.7, input_scale = 0.0167, output_scale = 22}
    ]],
  },
  {
    type = "noise-expression",
    name = "dark_ocean_wobble_y",
    expression = [[
      multioctave_noise{x = x, y = y, seed0 = map_seed, seed1 = 12202, octaves = 4, persistence = 0.7, input_scale = 0.0167, output_scale = 22}
    ]],
  },
  {
    type = "noise-expression",
    name = "dark_ocean_wobble_mask",
    expression = [[
      clamp(multioctave_noise{x = x, y = y, seed0 = map_seed, seed1 = 12203, octaves = 3, persistence = 0.5, input_scale = 0.021, output_scale = 3} + 0.6, 0, 1)
    ]],
  },
  {
    type = "noise-expression",
    name = "dark_ocean_wx",
    expression = "x + dark_ocean_wobble_x * dark_ocean_wobble_mask",
  },
  {
    type = "noise-expression",
    name = "dark_ocean_wy",
    expression = "y + dark_ocean_wobble_y * dark_ocean_wobble_mask",
  },

  -- Ячейка-остров: id ячейки и «пирамида» (1 в центре ячейки, 0 на её краю).
  -- Один и тот же seed1 — значит пирамида принадлежит тем же зёрнам, что и id.
  {
    type = "noise-expression",
    name = "dark_ocean_cells",
    expression = [[
      voronoi_cell_id{x = dark_ocean_wx, y = dark_ocean_wy, seed0 = map_seed, seed1 = 12210, grid_size = 220, distance_type = 'manhattan', jitter = 0.7}
    ]],
  },
  {
    type = "noise-expression",
    name = "dark_ocean_islands",
    expression = [[
      voronoi_pyramid_noise{x = dark_ocean_wx, y = dark_ocean_wy, seed0 = map_seed, seed1 = 12210, grid_size = 220, distance_type = 'manhattan', jitter = 0.7}
    ]],
  },

  -- Тип и «амплитуда» острова — из хеша ячейки (voronoi_cell_id даёт 0..1 на
  -- всю ячейку). Разные множители дают независимые значения: type2 == 1 →
  -- пепельный остров; amp мал → остров маленький, amp велик → крупный.
  -- Вблизи точки высадки тип всегда каменный (радиус 90), чтобы стартовый
  -- остров был одного типа с пятачком.
  {
    type = "noise-expression",
    name = "dark_ocean_type2",
    expression = "(((dark_ocean_cells * 3.7) % 1) > 0.5) * (sqrt(x * x + y * y) > 90)",
  },
  -- voronoi_pyramid_noise — это «расстояние до ближайшего края ячейки», у
  -- крупной ячейки максимум ~0.43. Множитель поднимает пик острова до ~0.4..1.3,
  -- чтобы уровни реально раскладывались от берега до середины.
  {
    type = "noise-expression",
    name = "dark_ocean_amp",
    expression = "((dark_ocean_cells * 7.3) % 1) * 2.0 + 0.9",
  },

  -- Стартовый остров радиусом ~50 тайлов вокруг точки высадки. Высоту держим
  -- ниже 1, чтобы уровни по нему раскладывались, а не упирались в максимум.
  {
    type = "noise-expression",
    name = "dark_ocean_start_island",
    expression = [[
      clamp((1 - sqrt(x * x + y * y) / 75) * 0.95 + dark_ocean_island_edge * 0.5, 0, 1)
    ]],
  },

  -- «Высота» суши. Порог 0.30 — уровень воды.
  {
    type = "noise-expression",
    name = "dark_ocean_height",
    expression = [[
      max(dark_ocean_islands * dark_ocean_amp, dark_ocean_start_island) + dark_ocean_island_edge
    ]],
  },
  {
    type = "noise-expression",
    name = "dark_ocean_land_mask",
    expression = "clamp((dark_ocean_height - 0.30) * 20, 0, 1)",
  },

  -- Уровень: 0 у берега, 1 в середине острова. Мелкий шум размывает границы
  -- уровней — соседние уровни перемешиваются.
  {
    type = "noise-expression",
    name = "dark_ocean_level",
    expression = "clamp((dark_ocean_height - 0.30) / 0.70, 0, 1)",
  },
  {
    type = "noise-expression",
    name = "dark_ocean_level_mix",
    expression = [[
      dark_ocean_level
      + 0.18 * multioctave_noise{x = x, y = y, seed0 = map_seed, seed1 = 12220, octaves = 3, persistence = 0.6, input_scale = 0.09}
    ]],
  },

  -- Вес каждого уровня: 1 внутри полосы, линейно гаснет на границе (±0.12),
  -- поэтому у стыков два уровня сосуществуют (смешение).
  { type = "noise-expression", name = "dark_ocean_stone_island", expression = "1 - dark_ocean_type2" },
  { type = "noise-expression", name = "dark_ocean_ash_island", expression = "dark_ocean_type2" },

  -- тип 1 (камень): полосы 0.28 / 0.52 / 0.78. Тёплый камень (swarm) начинается
  -- высоко (0.78) и гаснет к 0.96 — его намеренно мало.
  { type = "noise-expression", name = "dark_ocean_w_flat",  expression = "clamp((0.40 - dark_ocean_level_mix) / 0.12, 0, 1)" },
  { type = "noise-expression", name = "dark_ocean_w_folds", expression = "clamp((dark_ocean_level_mix - 0.16) / 0.12, 0, 1) * clamp((0.64 - dark_ocean_level_mix) / 0.12, 0, 1)" },
  { type = "noise-expression", name = "dark_ocean_w_sstone", expression = "clamp((dark_ocean_level_mix - 0.40) / 0.12, 0, 1) * clamp((0.90 - dark_ocean_level_mix) / 0.12, 0, 1)" },
  { type = "noise-expression", name = "dark_ocean_w_swarm", expression = "clamp((dark_ocean_level_mix - 0.78) / 0.10, 0, 1) * clamp((0.96 - dark_ocean_level_mix) / 0.08, 0, 1)" },

  -- тип 2 (пепел): полосы 0.42 / 0.72
  { type = "noise-expression", name = "dark_ocean_w_acrack", expression = "clamp((0.54 - dark_ocean_level_mix) / 0.12, 0, 1)" },
  { type = "noise-expression", name = "dark_ocean_w_alight", expression = "clamp((dark_ocean_level_mix - 0.30) / 0.12, 0, 1) * clamp((0.84 - dark_ocean_level_mix) / 0.12, 0, 1)" },
  { type = "noise-expression", name = "dark_ocean_w_jagged", expression = "clamp((dark_ocean_level_mix - 0.60) / 0.12, 0, 1) * clamp((0.96 - dark_ocean_level_mix) / 0.08, 0, 1)" },

  -- Лавовый «пик»: самый верх уровня, поверх любого типа острова. Выше него
  -- уже ничего нет — там, где пик острова дотягивается до этой полосы, лежит лава.
  { type = "noise-expression", name = "dark_ocean_w_lava", expression = "clamp((dark_ocean_level_mix - 0.90) / 0.06, 0, 1)" },

  -- Вероятности тайлов. Все островные — порядка 10000, чтобы уверенно
  -- побеждать тёмную воду (у неё вероятность 1). Тип острова выбирает
  -- семейство уровней, уровень — конкретный тайл.
  {
    type = "noise-expression",
    name = "dark_ocean_prob_folds_flat",
    expression = "dark_ocean_land_mask * dark_ocean_stone_island * dark_ocean_w_flat * 10000 + dark_ocean_landing_pad_prob",
  },
  {
    type = "noise-expression",
    name = "dark_ocean_prob_folds",
    expression = "dark_ocean_land_mask * dark_ocean_stone_island * dark_ocean_w_folds * 10000",
  },
  {
    type = "noise-expression",
    name = "dark_ocean_prob_smooth_stone",
    expression = "dark_ocean_land_mask * dark_ocean_stone_island * dark_ocean_w_sstone * 10000",
  },
  {
    type = "noise-expression",
    name = "dark_ocean_prob_smooth_stone_warm",
    expression = "dark_ocean_land_mask * dark_ocean_stone_island * dark_ocean_w_swarm * 10000",
  },
  {
    type = "noise-expression",
    name = "dark_ocean_prob_ash_cracks",
    expression = "dark_ocean_land_mask * dark_ocean_ash_island * dark_ocean_w_acrack * 10000",
  },
  {
    type = "noise-expression",
    name = "dark_ocean_prob_ash_light",
    expression = "dark_ocean_land_mask * dark_ocean_ash_island * dark_ocean_w_alight * 10000",
  },
  {
    type = "noise-expression",
    name = "dark_ocean_prob_jagged",
    expression = "dark_ocean_land_mask * dark_ocean_ash_island * dark_ocean_w_jagged * 10000",
  },
  {
    type = "noise-expression",
    name = "dark_ocean_prob_lava",
    expression = "dark_ocean_land_mask * dark_ocean_w_lava * 10000",
  },
})

-- Тайлы планеты: тёмная вода + лавовый пик + семь тёмных вулканических тайлов.
-- Имена совпадают с prototype/tile.lua.
local dark_ocean_tiles = {
  "dark-deep-lake",
  "dark-lava",
  "dark-volcanic-folds-flat",
  "dark-volcanic-folds",
  "dark-volcanic-smooth-stone",
  "dark-volcanic-smooth-stone-warm",
  "dark-volcanic-ash-cracks",
  "dark-volcanic-jagged-ground",
  "dark-volcanic-ash-light",
}

local dark_ocean_tile_probabilities = {
  ["dark-deep-lake"] = "const_one",
  ["dark-lava"] = "dark_ocean_prob_lava",
  ["dark-volcanic-folds-flat"] = "dark_ocean_prob_folds_flat",
  ["dark-volcanic-folds"] = "dark_ocean_prob_folds",
  ["dark-volcanic-smooth-stone"] = "dark_ocean_prob_smooth_stone",
  ["dark-volcanic-smooth-stone-warm"] = "dark_ocean_prob_smooth_stone_warm",
  ["dark-volcanic-ash-cracks"] = "dark_ocean_prob_ash_cracks",
  ["dark-volcanic-jagged-ground"] = "dark_ocean_prob_jagged",
  ["dark-volcanic-ash-light"] = "dark_ocean_prob_ash_light",
}

local function make_map_gen()
  local tile_settings = {}
  local property_expression_names = {
    elevation = "const_zero",
    temperature = "const_zero",
    moisture = "const_zero",
    aux = "const_zero",
    cliffiness = "const_zero",
    cliff_elevation = "const_zero",
  }

  for _, name in ipairs(dark_ocean_tiles) do
    tile_settings[name] = {}
    property_expression_names["tile:" .. name .. ":probability"] =
      dark_ocean_tile_probabilities[name]
    property_expression_names["tile:" .. name .. ":richness"] = "const_zero"
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
        settings = {},
      },
    },
  }
end

planet_map_gen[PLANET] = make_map_gen

-- ---------------------------------------------------------------------------
-- Планета и технология
-- ---------------------------------------------------------------------------

data:extend({
  {
    type = "planet",
    name = PLANET,
    icon = ICON,
    starmap_icon = q .. "/graphics/planet/dark-ocean-starmap.png",
    starmap_icon_size = 512,
    gravity_pull = 10,
    distance = 15,
    orientation = 0.35,
    magnitude = 1,
    order = "z[dark-ocean]",
    subgroup = "planets",
    map_gen_settings = planet_map_gen[PLANET](),
    platform_surface_render_parameters = {},
    -- Тени на поверхности. shadow_opacity = 0 полностью отключает тени
    -- (постройки, деревья и т.п.), поэтому вернули дефолтное 0.5 — как у
    -- остальных планет (см. __space-age__/base-data-updates.lua).
    surface_render_parameters = {
      shadow_opacity = 0.5,
    },
    draw_orbit = true,
    unlocked = true,
    surface_properties = {
      gravity = 10,
      pressure = 1000,
      ["magnetic-field"] = 15,
      ["day-night-cycle"] = 0,
      -- Плотная облачность: солнце почти не пробивается.
      ["solar-power"] = 40,
    },
  },
  {
    type = "technology",
    name = PLANET,
    icon = ICON,
    icon_size = 64,
    effects = {
      {
        type = "unlock-space-location",
        space_location = PLANET,
        use_icon_overlay_constant = true,
      },
    },
    unit = {
      count = 100,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
      },
      time = 30,
    },
  },
})

-- ---------------------------------------------------------------------------
-- Как планета выглядит из космоса
-- ---------------------------------------------------------------------------

local nauvis_backdrop =
  data.raw.planet["nauvis"].platform_surface_render_parameters.platform_backdrop

data.raw.planet[PLANET].platform_surface_render_parameters.platform_backdrop = {
  emission_scales_with_shadow = false,
  radius = nauvis_backdrop.radius * 1.2,
  rotation_seconds = 300,
  surface_vertical_offset = 0.1,
  specular_intensity = 0.55,
  specular_color = {0.45, 0.72, 0.9, 1},
  atmosphere_color = {0.10, 0.35, 0.50, 0.35},
  planet_axis = {0.2, 5.0},
  planet_axis_deviation_amplitude = {4.0, 4.0},
  planet_axis_deviation_seconds = {1200.0, 900.0},
  position = {200, -250},
  parallax_strength = {0.95, 0.95},
  light_direction = {-0.42, 0.23, 0.4},
  light_intensity_contrast = 0.25,
  light_radius = 9.0,
  planet_surface = {
    filename = q .. "/graphics/planet/dark-ocean-color.png",
    width = 1024,
    height = 1024,
  },
}

-- ---------------------------------------------------------------------------
-- Топология: откуда долететь
-- ---------------------------------------------------------------------------

data:extend({
  {
    type = "space-connection",
    name = "nauvis-" .. PLANET,
    subgroup = "planet-connections",
    from = "nauvis",
    to = PLANET,
    order = "g[nauvis-dark-ocean]",
    length = 15000,
    asteroid_spawn_definitions = asteroid_util.spawn_definitions(asteroid_util.nauvis_vulcanus),
    icon = ICON,
  },
})
