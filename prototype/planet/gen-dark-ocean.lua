-- Генерация планеты dark-ocean: шум, вероятности тайлов и map_gen.
--
-- Тёмный океан (dark-deep-lake) + вулканические острова по уровням. Сама
-- планета, технология и топология — в prototype/planet/planet.lua и other.lua;
-- слой тёмной воды по чанкам — в script/planet/dark-ocean.lua.

local make_map_gen = require("prototype.planet.map-gen")

-- Тёмная вода — сущность и анимация для слоя поверх океана.
require("prototype.dark-water")

data:extend({
  -- Пятачок суши в точке высадки: гарантированно твёрдая земля радиусом ~14
  -- вокруг 0,0. Побеждает любой другой тайл (см. paln_dark_ocean_prob_folds_flat).
  {
    type = "noise-expression",
    name = "paln_dark_ocean_landing_pad_prob",
    expression = "(1 - clamp(sqrt(x * x + y * y) / 14, 0, 1)) * 30000",
  },

  -- Волнистость береговой линии (общая для всех островов).
  {
    type = "noise-expression",
    name = "paln_dark_ocean_island_edge",
    expression = [[
      0.05 * (basis_noise{x = x, y = y, seed0 = map_seed, seed1 = 12004, input_scale = 0.06} - 0.5)
      + 0.03 * (basis_noise{x = x, y = y, seed0 = map_seed, seed1 = 12005, input_scale = 0.18} - 0.5)
    ]],
  },

  -- Мягкое искажение координат — чтобы зерно Вороного (а значит и остров)
  -- не сидело в правильной сетке.
  {
    type = "noise-expression",
    name = "paln_dark_ocean_wobble_x",
    expression = [[
      multioctave_noise{x = x, y = y, seed0 = map_seed, seed1 = 12201, octaves = 4, persistence = 0.7, input_scale = 0.0167, output_scale = 22}
    ]],
  },
  {
    type = "noise-expression",
    name = "paln_dark_ocean_wobble_y",
    expression = [[
      multioctave_noise{x = x, y = y, seed0 = map_seed, seed1 = 12202, octaves = 4, persistence = 0.7, input_scale = 0.0167, output_scale = 22}
    ]],
  },
  {
    type = "noise-expression",
    name = "paln_dark_ocean_wobble_mask",
    expression = [[
      clamp(multioctave_noise{x = x, y = y, seed0 = map_seed, seed1 = 12203, octaves = 3, persistence = 0.5, input_scale = 0.021, output_scale = 3} + 0.6, 0, 1)
    ]],
  },
  {
    type = "noise-expression",
    name = "paln_dark_ocean_wx",
    expression = "x + paln_dark_ocean_wobble_x * paln_dark_ocean_wobble_mask",
  },
  {
    type = "noise-expression",
    name = "paln_dark_ocean_wy",
    expression = "y + paln_dark_ocean_wobble_y * paln_dark_ocean_wobble_mask",
  },

  -- Ячейка-остров: id ячейки и «пирамида» (1 в центре ячейки, 0 на её краю).
  -- Один и тот же seed1 — значит пирамида принадлежит тем же зёрнам, что и id.
  {
    type = "noise-expression",
    name = "paln_dark_ocean_cells",
    expression = [[
      voronoi_cell_id{x = paln_dark_ocean_wx, y = paln_dark_ocean_wy, seed0 = map_seed, seed1 = 12210, grid_size = 220, distance_type = 'manhattan', jitter = 0.7}
    ]],
  },

  -- Ячейка, в которую попадает точка высадки. Это тот же voronoi_cell_id, что и
  -- paln_dark_ocean_cells, но вызванный в фиксированной точке (0,0): x и y подставлены
  -- числами, поэтому значение — константа. Искажение координат (wx/wy) здесь
  -- расписано тем же шумом, что и выше, тоже в точке (0,0).
  {
    type = "noise-expression",
    name = "paln_dark_ocean_spawn_cell",
    expression = [[
      voronoi_cell_id{
        x = multioctave_noise{x = 0, y = 0, seed0 = map_seed, seed1 = 12201, octaves = 4, persistence = 0.7, input_scale = 0.0167, output_scale = 22}
            * clamp(multioctave_noise{x = 0, y = 0, seed0 = map_seed, seed1 = 12203, octaves = 3, persistence = 0.5, input_scale = 0.021, output_scale = 3} + 0.6, 0, 1),
        y = multioctave_noise{x = 0, y = 0, seed0 = map_seed, seed1 = 12202, octaves = 4, persistence = 0.7, input_scale = 0.0167, output_scale = 22}
            * clamp(multioctave_noise{x = 0, y = 0, seed0 = map_seed, seed1 = 12203, octaves = 3, persistence = 0.5, input_scale = 0.021, output_scale = 3} + 0.6, 0, 1),
        seed0 = map_seed, seed1 = 12210, grid_size = 220, distance_type = 'manhattan', jitter = 0.7
      }
    ]],
  },
  -- 1, если тайл лежит в ячейке высадки, иначе 0.
  {
    type = "noise-expression",
    name = "paln_dark_ocean_in_spawn_cell",
    expression = "(abs(paln_dark_ocean_cells - paln_dark_ocean_spawn_cell) < 0.0001)",
  },
  {
    type = "noise-expression",
    name = "paln_dark_ocean_islands",
    expression = [[
      voronoi_pyramid_noise{x = paln_dark_ocean_wx, y = paln_dark_ocean_wy, seed0 = map_seed, seed1 = 12210, grid_size = 220, distance_type = 'manhattan', jitter = 0.7}
    ]],
  },

  -- Тип и «амплитуда» острова — из хеша ячейки (voronoi_cell_id даёт 0..1 на
  -- всю ячейку). Разные множители дают независимые значения: type2 == 1 →
  -- пепельный остров; amp мал → остров маленький, amp велик → крупный.
  -- Тип зависит ТОЛЬКО от ячейки (никаких переключателей по радиусу): иначе
  -- остров, попавший под переключатель, делился бы на два типа. Ячейка высадки
  -- всегда каменная — стартовый остров одного типа с пятачком.
  {
    type = "noise-expression",
    name = "paln_dark_ocean_type2",
    expression = "(((paln_dark_ocean_cells * 3.7) % 1) > 0.5) * (1 - paln_dark_ocean_in_spawn_cell)",
  },
  -- voronoi_pyramid_noise — это «расстояние до ближайшего края ячейки», у
  -- крупной ячейки максимум ~0.43. Множитель поднимает пик острова до ~0.4..1.3,
  -- чтобы уровни реально раскладывались от берега до середины.
  {
    type = "noise-expression",
    name = "paln_dark_ocean_amp",
    expression = "((paln_dark_ocean_cells * 7.3) % 1) * 2.0 + 0.9",
  },

  -- Стартовый остров радиусом ~50 тайлов вокруг точки высадки. Высоту держим
  -- ниже 1, чтобы уровни по нему раскладывались, а не упирались в максимум.
  -- Множитель paln_dark_ocean_in_spawn_cell обрезает блин по границе своей ячейки —
  -- так он не срастается с пепельным островом соседней ячейки (между ними вода).
  {
    type = "noise-expression",
    name = "paln_dark_ocean_start_island",
    expression = [[
      clamp((1 - sqrt(x * x + y * y) / 75) * 0.95 + paln_dark_ocean_island_edge * 0.5, 0, 1) * paln_dark_ocean_in_spawn_cell
    ]],
  },

  -- Сырая высота до волнистости берега: пик острова (или стартовый блин).
  {
    type = "noise-expression",
    name = "paln_dark_ocean_base",
    expression = "max(paln_dark_ocean_islands * paln_dark_ocean_amp, paln_dark_ocean_start_island)",
  },
  -- Волнистость берега ослабляем вглубь острова: у воды она полная, а на суше
  -- (base > 0.42) — ноль. Иначе на маленьких островах шум берега (±0.04)
  -- продавливал высоту ниже уровня воды уже внутри острова — появлялись озёра.
  {
    type = "noise-expression",
    name = "paln_dark_ocean_coast",
    expression = "clamp((0.42 - paln_dark_ocean_base) / 0.12, 0, 1)",
  },
  -- «Высота» суши. Порог 0.30 — уровень воды.
  {
    type = "noise-expression",
    name = "paln_dark_ocean_height",
    expression = "paln_dark_ocean_base + paln_dark_ocean_island_edge * paln_dark_ocean_coast",
  },
  {
    type = "noise-expression",
    name = "paln_dark_ocean_land_mask",
    expression = "clamp((paln_dark_ocean_height - 0.30) * 20, 0, 1)",
  },

  -- «Материк»: 0 у самой воды и 1 в глубине острова. Лава умножается на неё,
  -- поэтому к берегу не подходит — между лавой и тёмной водой всегда остаётся
  -- полоса суши (насколько широкая — зависит от уклона острова; при пороге
  -- 0.34 это ~0.05 высоты над уровнем воды).
  {
    type = "noise-expression",
    name = "paln_dark_ocean_inland",
    expression = "clamp((paln_dark_ocean_height - 0.34) / 0.05, 0, 1)",
  },

  -- Уровень: 0 у берега, 1 в середине острова. Мелкий шум размывает границы
  -- уровней — соседние уровни перемешиваются.
  {
    type = "noise-expression",
    name = "paln_dark_ocean_level",
    expression = "clamp((paln_dark_ocean_height - 0.30) / 0.70, 0, 1)",
  },
  {
    type = "noise-expression",
    name = "paln_dark_ocean_level_mix",
    expression = [[
      paln_dark_ocean_level
      + 0.18 * multioctave_noise{x = x, y = y, seed0 = map_seed, seed1 = 12220, octaves = 3, persistence = 0.6, input_scale = 0.09}
    ]],
  },

  -- Вес каждого уровня: 1 внутри полосы, линейно гаснет на границе (±0.12),
  -- поэтому у стыков два уровня сосуществуют (смешение).
  { type = "noise-expression", name = "paln_dark_ocean_stone_island", expression = "1 - paln_dark_ocean_type2" },
  { type = "noise-expression", name = "paln_dark_ocean_ash_island", expression = "paln_dark_ocean_type2" },

  -- тип 1 (камень): полосы 0.28 / 0.52 / 0.78. Тёплый камень (swarm) начинается
  -- высоко (0.78) и гаснет к 0.96 — его намеренно мало. Выше 0.90 у него есть
  -- небольшое «плато» (0.5): без него на самых высоких пиках (level_mix > 0.96)
  -- все веса уровней обращаются в ноль, наземного тайла не остаётся — и там,
  -- где нет лавы, движок ставит воду (дыры с водой внутри острова).
  { type = "noise-expression", name = "paln_dark_ocean_w_flat",  expression = "clamp((0.40 - paln_dark_ocean_level_mix) / 0.12, 0, 1)" },
  { type = "noise-expression", name = "paln_dark_ocean_w_folds", expression = "clamp((paln_dark_ocean_level_mix - 0.16) / 0.12, 0, 1) * clamp((0.64 - paln_dark_ocean_level_mix) / 0.12, 0, 1)" },
  { type = "noise-expression", name = "paln_dark_ocean_w_sstone", expression = "clamp((paln_dark_ocean_level_mix - 0.40) / 0.12, 0, 1) * clamp((0.90 - paln_dark_ocean_level_mix) / 0.12, 0, 1)" },
  { type = "noise-expression", name = "paln_dark_ocean_w_swarm", expression = "max(clamp((paln_dark_ocean_level_mix - 0.78) / 0.10, 0, 1) * clamp((0.96 - paln_dark_ocean_level_mix) / 0.08, 0, 1), clamp((paln_dark_ocean_level_mix - 0.90) / 0.06, 0, 1) * 0.5)" },

  -- тип 2 (пепел): полосы 0.42 / 0.72. У верхнего тайла (jagged) — то же плато.
  { type = "noise-expression", name = "paln_dark_ocean_w_acrack", expression = "clamp((0.54 - paln_dark_ocean_level_mix) / 0.12, 0, 1)" },
  { type = "noise-expression", name = "paln_dark_ocean_w_alight", expression = "clamp((paln_dark_ocean_level_mix - 0.30) / 0.12, 0, 1) * clamp((0.84 - paln_dark_ocean_level_mix) / 0.12, 0, 1)" },
  { type = "noise-expression", name = "paln_dark_ocean_w_jagged", expression = "max(clamp((paln_dark_ocean_level_mix - 0.60) / 0.12, 0, 1) * clamp((0.96 - paln_dark_ocean_level_mix) / 0.08, 0, 1), clamp((paln_dark_ocean_level_mix - 0.90) / 0.06, 0, 1) * 0.5)" },

  -- Лавовый «пик»: самый верх уровня, поверх любого типа острова. Выше него
  -- уже ничего нет — там, где пик острова дотягивается до этой полосы, лежит
  -- лава. Порог опущен 0.90 -> 0.78, полоса расширена 0.06 -> 0.14: лавы
  -- заметно больше, и она появляется на большем числе островов.
  { type = "noise-expression", name = "paln_dark_ocean_w_lava", expression = "clamp((paln_dark_ocean_level_mix - 0.78) / 0.14, 0, 1)" },

  -- Вариация лавы: примерно половина островов (по хешу ячейки) вместо лужи на
  -- пике получает лаву-расщелины — ветвящуюся сеть трещин по всей суше.
  -- Стиль постоянен на всём острове, как и его тип.
  {
    type = "noise-expression",
    name = "paln_dark_ocean_lava_cracks",
    expression = "(((paln_dark_ocean_cells * 5.1) % 1) > 0.5)",
  },

  -- Поле расщелин: две частоты мультиоктавного шума. Трещина идёт там, где поле
  -- близко к нулю (abs ~ 0), поэтому линии получаются узкими и ветвящимися, а
  -- не пятном. Толщину линий задают порог (0.12) и множитель (8).
  {
    type = "noise-expression",
    name = "paln_dark_ocean_crack_field",
    expression = [[
      multioctave_noise{x = x, y = y, seed0 = map_seed, seed1 = 12310, octaves = 3, persistence = 0.5, input_scale = 0.03, output_scale = 1}
      + 0.5 * multioctave_noise{x = x, y = y, seed0 = map_seed, seed1 = 12311, octaves = 2, persistence = 0.5, input_scale = 0.09, output_scale = 1}
    ]],
  },
  {
    type = "noise-expression",
    name = "paln_dark_ocean_crack_mask",
    expression = "clamp((0.12 - abs(paln_dark_ocean_crack_field)) * 8, 0, 1)",
  },

  -- Вероятности тайлов. Все островные — порядка 10000, чтобы уверенно
  -- побеждать тёмную воду (у неё вероятность 1). Тип острова выбирает
  -- семейство уровней, уровень — конкретный тайл.
  {
    type = "noise-expression",
    name = "paln_dark_ocean_prob_folds_flat",
    expression = "paln_dark_ocean_land_mask * paln_dark_ocean_stone_island * paln_dark_ocean_w_flat * 10000 + paln_dark_ocean_landing_pad_prob * paln_dark_ocean_in_spawn_cell",
  },
  {
    type = "noise-expression",
    name = "paln_dark_ocean_prob_folds",
    expression = "paln_dark_ocean_land_mask * paln_dark_ocean_stone_island * paln_dark_ocean_w_folds * 10000",
  },
  {
    type = "noise-expression",
    name = "paln_dark_ocean_prob_smooth_stone",
    expression = "paln_dark_ocean_land_mask * paln_dark_ocean_stone_island * paln_dark_ocean_w_sstone * 10000",
  },
  {
    type = "noise-expression",
    name = "paln_dark_ocean_prob_smooth_stone_warm",
    expression = "paln_dark_ocean_land_mask * paln_dark_ocean_stone_island * paln_dark_ocean_w_swarm * 10000",
  },
  {
    type = "noise-expression",
    name = "paln_dark_ocean_prob_ash_cracks",
    expression = "paln_dark_ocean_land_mask * paln_dark_ocean_ash_island * paln_dark_ocean_w_acrack * 10000",
  },
  {
    type = "noise-expression",
    name = "paln_dark_ocean_prob_ash_light",
    expression = "paln_dark_ocean_land_mask * paln_dark_ocean_ash_island * paln_dark_ocean_w_alight * 10000",
  },
  {
    type = "noise-expression",
    name = "paln_dark_ocean_prob_jagged",
    expression = "paln_dark_ocean_land_mask * paln_dark_ocean_ash_island * paln_dark_ocean_w_jagged * 10000",
  },
  -- Лава: на обычных островах — лужа на пике, на «трещинных» — сеть расщелин.
  -- 11000 у расщелин чуть выше остальных наземных тайлов (10000), поэтому
  -- линия трещины не проигрывает им по вероятности; пятачок высадки (30000)
  -- всё равно остаётся поверх. Множитель paln_dark_ocean_inland не даёт лаве выйти
  -- на берег — к воде она не подходит.
  {
    type = "noise-expression",
    name = "paln_dark_ocean_prob_lava",
    expression = [[
      paln_dark_ocean_inland * max(
        paln_dark_ocean_w_lava * (1 - paln_dark_ocean_lava_cracks) * 10000,
        paln_dark_ocean_crack_mask * paln_dark_ocean_lava_cracks * 11000
      )
    ]],
  },

  -- Плотность пузырей на тёмной воде (декорация dark-water-bubbles,
  -- prototype/decorative/water-bubbles.lua). Это вероятность поставить
  -- декорацию на тайл; сама декорация коллизией с ground_tile не пускает себя
  -- на острова, поэтому на суше шум не нужен — множитель (1 - land_mask) лишь
  -- экономит роллы. Шумовой множитель даёт неровные «пятна» бурления.
  {
    type = "noise-expression",
    name = "paln_dark_ocean_bubble_prob",
    expression = [[
      0.03 * (1 - paln_dark_ocean_land_mask)
      * (0.4 + 1.2 * basis_noise{x = x, y = y, seed0 = map_seed, seed1 = 12330, input_scale = 0.05})
    ]],
  },

  -- =====================================================================
  -- Декорации островов (prototype/decorative/volcanic-rocks.lua).
  -- =====================================================================
  -- paln_dark_ocean_lava_mask — форма лавы 0..1 (та же, что у
  -- paln_dark_ocean_prob_lava, но без множителей 10000/11000). Декорации на
  -- лаву не ставятся: камни не должны плавать в лаве.
  {
    type = "noise-expression",
    name = "paln_dark_ocean_lava_mask",
    expression = [[
      paln_dark_ocean_inland * max(
        paln_dark_ocean_w_lava * (1 - paln_dark_ocean_lava_cracks),
        paln_dark_ocean_crack_mask * paln_dark_ocean_lava_cracks
      )
    ]],
  },
  -- «Твёрдая земля без лавы»: 0 на воде и на лаве, 1 на суше.
  {
    type = "noise-expression",
    name = "paln_dark_ocean_deco_ground",
    expression = "paln_dark_ocean_land_mask * (1 - paln_dark_ocean_lava_mask)",
  },
  -- Пятна каменистости: где-то камней густо, где-то почти нет. Две частоты:
  -- крупные пятна (камни) и мелкая рябь (щебень/трещины).
  {
    type = "noise-expression",
    name = "paln_dark_ocean_rock_field",
    expression = [[
      clamp(0.15 + 1.05 * basis_noise{x = x, y = y, seed0 = map_seed, seed1 = 12360, input_scale = 0.045}, 0, 1)
    ]],
  },
  {
    type = "noise-expression",
    name = "paln_dark_ocean_rock_field_fine",
    expression = [[
      clamp(0.20 + 1.10 * basis_noise{x = x, y = y, seed0 = map_seed, seed1 = 12361, input_scale = 0.11}, 0, 1)
    ]],
  },
  -- Вероятности декораций — шанс поставить декорацию на конкретный тайл.
  -- deco_ground плавно уходит в ноль к воде, поэтому к берегу камни редеют.
  {
    type = "noise-expression",
    name = "paln_dark_ocean_deco_medium_rock_prob",
    expression = "0.010 * paln_dark_ocean_deco_ground * paln_dark_ocean_inland * paln_dark_ocean_rock_field",
  },
  {
    type = "noise-expression",
    name = "paln_dark_ocean_deco_crack_warm_prob",
    expression = "0.022 * paln_dark_ocean_deco_ground * paln_dark_ocean_rock_field_fine",
  },
  {
    type = "noise-expression",
    name = "paln_dark_ocean_deco_crack_huge_warm_prob",
    expression = "0.004 * paln_dark_ocean_deco_ground * paln_dark_ocean_inland * paln_dark_ocean_rock_field_fine",
  },
  {
    type = "noise-expression",
    name = "paln_dark_ocean_deco_crater_small_prob",
    expression = "0.010 * paln_dark_ocean_deco_ground",
  },
  {
    type = "noise-expression",
    name = "paln_dark_ocean_deco_crater_large_prob",
    expression = "0.002 * paln_dark_ocean_deco_ground * paln_dark_ocean_inland",
  },
  {
    type = "noise-expression",
    name = "paln_dark_ocean_deco_rock_decal_prob",
    expression = "0.007 * paln_dark_ocean_deco_ground * paln_dark_ocean_inland * paln_dark_ocean_rock_field",
  },

  -- Плотность труб (vulcanus-chimney-coldq1, prototype/entity/rock.lua) на
  -- тёмной воде. Спавнятся ГРУППАМИ и РЕДКО.
  --
  -- Два шума перемножаются:
  --   * «область» (seed1 12341, input_scale 0.005, ~200 тайлов) — грубый
  --     порог: только в своих вершинах он вообще разрешает группы. Поэтому
  --     кластеры редкие: между ними десятки-сотни тайлов чистой воды;
  --   * «форма группы» (seed1 12340, input_scale 0.06, ~16 тайлов) — рождает
  --     саму группу: вершина шума даёт плотное пятно из нескольких труб, а не
  --     одиночку. Размер групп не меняли — реже стали только области.
  -- Множитель (1 - land_mask) гасит всё на островах (труба и так не встанет на
  -- землю из-за коллизии с ground_tile, так не тратим роллы на сушу).
  {
    type = "noise-expression",
    name = "paln_dark_ocean_chimney_prob",
    expression = [[
      0.15
      * clamp((basis_noise{x = x, y = y, seed0 = map_seed, seed1 = 12341, input_scale = 0.005} - 0.60) * 6, 0, 1)
      * clamp((basis_noise{x = x, y = y, seed0 = map_seed, seed1 = 12340, input_scale = 0.06} - 0.66) * 7, 0, 1)
      * (1 - paln_dark_ocean_land_mask)
    ]],
  },
})

-- Тайлы планеты: тёмная вода + лавовый пик + семь тёмных вулканических тайлов.
-- Имена совпадают с prototype/tiles/dark-lake.lua и prototype/tiles/dark-lava.lua.
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
  ["dark-deep-lake"] = "paln_const_one",
  ["dark-lava"] = "paln_dark_ocean_prob_lava",
  ["dark-volcanic-folds-flat"] = "paln_dark_ocean_prob_folds_flat",
  ["dark-volcanic-folds"] = "paln_dark_ocean_prob_folds",
  ["dark-volcanic-smooth-stone"] = "paln_dark_ocean_prob_smooth_stone",
  ["dark-volcanic-smooth-stone-warm"] = "paln_dark_ocean_prob_smooth_stone_warm",
  ["dark-volcanic-ash-cracks"] = "paln_dark_ocean_prob_ash_cracks",
  ["dark-volcanic-jagged-ground"] = "paln_dark_ocean_prob_jagged",
  ["dark-volcanic-ash-light"] = "paln_dark_ocean_prob_ash_light",
}

return make_map_gen(dark_ocean_tiles, dark_ocean_tile_probabilities, {})
