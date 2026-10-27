-- Шумовые выражения планеты zalupa.
--
-- Первый, простой вариант:
--   * вся планета - пустой космос (empty-space);
--   * редкие острова-гиганты сделаны из fulgoran-sand;
--   * вокруг гигантов есть пустая зона, где не появляются другие острова;
--   * у мелких островов есть разнообразие: песок, пыль и дюны;
--   * на островах-гигантах много больших вулканов: фульгорианский камень,
--     высокогорный камень, лава и горячая лава; над лавой поднимается дым;
--   * вокруг стартовой точки есть гарантированный песчаный остров.
--   * [PATCH] Увеличен радиус фульгорианского камня вокруг вулканов 38->52
--   * [PATCH] Добавлены расщелины из фульгорианского камня по всем островам-гигантам
--   * [PATCH] Большие острова: как гиганты, но без высокой скалы, а лава
--     заменена белой нефтью (white-oil-ocean-deep-2); мелких островов меньше;
--     руды q1/q2 не появляются в большом радиусе вокруг вулканов.
--
-- Реки, оазисы и прочие биомы сюда пока не добавляем — будем делать их
-- следующими порциями.

data:extend({
  -- =====================================================================
  -- Острова
  -- =====================================================================

  -- Мелкие острова: по пятну на область, с искажением координат, чтобы
  -- форма не была идеально круглой.
  -- [ИЗМЕНЕНО] Островов стало заметно меньше: область кандидата увеличена
  -- 96 -> 160 (число островов ~ (96/160)^2 = 0.36 от прежнего), снята
  -- гарантия пятна в каждой области (hard_region_target_quantity 1 -> 0).
  -- Замечание: при candidate_spot_count = 1 плотность (density_expression)
  -- не влияет на число островов — на количество влияет именно region_size.
  {
    type = "noise-expression",
    name = "zalupa_island_raw",
    expression = [[
      spot_noise{
        x = x + 8 * (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 5001,
          input_scale = 0.010
        } - 0.5),
        y = y + 8 * (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 5002,
          input_scale = 0.010
        } - 0.5),
        seed0 = map_seed,
        seed1 = 5003,
        candidate_spot_count = 1,
        suggested_minimum_candidate_point_spacing = 96,
        skip_span = 1,
        skip_offset = 0,
        region_size = 160,
        density_expression = 1,
        spot_quantity_expression = 484,
        spot_radius_expression = 22,
        spot_favorability_expression = 1,
        hard_region_target_quantity = 0,
        basement_value = 0,
        maximum_spot_basement_radius = 96
      }
    ]]
  },

  -- =====================================================================
  -- Большие острова
  -- =====================================================================
  -- Как острова-гиганты, но заметно меньше и чаще. Это вулканические
  -- острова БЕЗ высокой скалы (highland-dark-rock-2): на них только
  -- фульгорианский песок/камень, а вместо лавы — белая нефть
  -- (см. блок «вулканы больших островов» ниже).
  {
    type = "noise-expression",
    name = "zalupa_big_island_raw",
    expression = [[
      spot_noise{
        x = x + 10 * (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 9501,
          input_scale = 0.012
        } - 0.5),
        y = y + 10 * (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 9502,
          input_scale = 0.012
        } - 0.5),
        seed0 = map_seed,
        seed1 = 9503,
        candidate_spot_count = 1,
        suggested_minimum_candidate_point_spacing = 192,
        skip_span = 1,
        skip_offset = 0,
        region_size = 256,
        density_expression = 1,
        spot_quantity_expression = 3025,
        spot_radius_expression = 55,
        spot_favorability_expression = 1,
        hard_region_target_quantity = 0,
        basement_value = 0,
        maximum_spot_basement_radius = 256
      }
    ]]
  },

  -- Очень редкие острова-гиганты. Их мало, и вокруг каждого остаётся
  -- пустая зона: остальные острова в этот радиус не попадают.
  {
    type = "noise-expression",
    name = "zalupa_giant_island_raw",
    expression = [[
      spot_noise{
        x = x + 12 * (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 9001,
          input_scale = 0.010
        } - 0.5),
        y = y + 12 * (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 9002,
          input_scale = 0.010
        } - 0.5),
        seed0 = map_seed,
        seed1 = 9003,
        candidate_spot_count = 1,
        suggested_minimum_candidate_point_spacing = 256,
        skip_span = 1,
        skip_offset = 0,
        region_size = 512,
        density_expression = 1,
        spot_quantity_expression = 8100,
        spot_radius_expression = 90,
        spot_favorability_expression = 1,
        hard_region_target_quantity = 0,
        basement_value = 0,
        maximum_spot_basement_radius = 512
      }
    ]]
  },

  -- Та же сетка пятен, но с гораздо большим радиусом. Это не остров,
  -- а «зона отчуждения» вокруг острова-гиганта.
  {
    type = "noise-expression",
    name = "zalupa_giant_exclusion_raw",
    expression = [[
      spot_noise{
        x = x + 12 * (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 9001,
          input_scale = 0.010
        } - 0.5),
        y = y + 12 * (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 9002,
          input_scale = 0.010
        } - 0.5),
        seed0 = map_seed,
        seed1 = 9003,
        candidate_spot_count = 1,
        suggested_minimum_candidate_point_spacing = 256,
        skip_span = 1,
        skip_offset = 0,
        region_size = 512,
        density_expression = 1,
        spot_quantity_expression = 25600,
        spot_radius_expression = 160,
        spot_favorability_expression = 1,
        hard_region_target_quantity = 0,
        basement_value = 0,
        maximum_spot_basement_radius = 512
      }
    ]]
  },

  -- Большие вулканы на островах-гигантах.
  {
    type = "noise-expression",
    name = "zalupa_volcano_raw",
    expression = [[
      spot_noise{
        x = x + 4 * (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 10001,
          input_scale = 0.03
        } - 0.5),
        y = y + 4 * (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 10002,
          input_scale = 0.03
        } - 0.5),
        seed0 = map_seed,
        seed1 = 10003,
        candidate_spot_count = 1,
        suggested_minimum_candidate_point_spacing = 16,
        skip_span = 1,
        skip_offset = 0,
        region_size = 32,
        density_expression = clamp((zalupa_giant_island_shape - 0.72) * 30, 0, 1),
        spot_quantity_expression = 324,
        spot_radius_expression = 18,
        spot_favorability_expression = 1,
        hard_region_target_quantity = 0,
        basement_value = 0,
        maximum_spot_basement_radius = 64
      }
    ]]
  },

  {
    type = "noise-expression",
    name = "zalupa_volcano_rock_raw",
    expression = [[
      spot_noise{
        x = x + 4 * (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 10001,
          input_scale = 0.03
        } - 0.5),
        y = y + 4 * (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 10002,
          input_scale = 0.03
        } - 0.5),
        seed0 = map_seed,
        seed1 = 10003,
        candidate_spot_count = 1,
        suggested_minimum_candidate_point_spacing = 16,
        skip_span = 1,
        skip_offset = 0,
        region_size = 32,
        density_expression = clamp((zalupa_giant_island_shape - 0.72) * 30, 0, 1),
        spot_quantity_expression = 1024,
        spot_radius_expression = 32,
        spot_favorability_expression = 1,
        hard_region_target_quantity = 0,
        basement_value = 0,
        maximum_spot_basement_radius = 64
      }
    ]]
  },

  -- Внешнее кольцо из фульгорианского камня вокруг вулканов.
  -- [ИЗМЕНЕНО] Радиус увеличен 38 -> 52
  {
    type = "noise-expression",
    name = "zalupa_volcano_fulgoran_raw",
    expression = [[
      spot_noise{
        x = x + 4 * (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 10001,
          input_scale = 0.03
        } - 0.5),
        y = y + 4 * (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 10002,
          input_scale = 0.03
        } - 0.5),
        seed0 = map_seed,
        seed1 = 10003,
        candidate_spot_count = 1,
        suggested_minimum_candidate_point_spacing = 16,
        skip_span = 1,
        skip_offset = 0,
        region_size = 32,
        density_expression = clamp((zalupa_giant_island_shape - 0.72) * 30, 0, 1),
        spot_quantity_expression = 2704,
        spot_radius_expression = 52,
        spot_favorability_expression = 1,
        hard_region_target_quantity = 0,
        basement_value = 0,
        maximum_spot_basement_radius = 64
      }
    ]]
  },

  {
    type = "noise-expression",
    name = "zalupa_island_edge",
    expression = [[
      0.05 * (basis_noise{
        x = x,
        y = y,
        seed0 = map_seed,
        seed1 = 5004,
        input_scale = 0.08
      } - 0.5)
      +
      0.03 * (basis_noise{
        x = x,
        y = y,
        seed0 = map_seed,
        seed1 = 5005,
        input_scale = 0.22
      } - 0.5)
    ]]
  },

  {
    type = "noise-expression",
    name = "zalupa_small_island_shape",
    expression = "zalupa_island_raw + zalupa_island_edge"
  },

  {
    type = "noise-expression",
    name = "zalupa_small_island_noise",
    expression = "clamp((zalupa_small_island_shape - 0.32) * 20, 0, 1)"
  },

  {
    type = "noise-expression",
    name = "zalupa_giant_island_shape",
    expression = "zalupa_giant_island_raw + zalupa_island_edge"
  },

  {
    type = "noise-expression",
    name = "zalupa_giant_island_mask",
    expression = "clamp((zalupa_giant_island_shape - 0.32) * 20, 0, 1)"
  },

  {
    type = "noise-expression",
    name = "zalupa_giant_volcano_mask",
    expression = "clamp((zalupa_giant_island_shape - 0.34) * 20, 0, 1)"
  },

  {
    type = "noise-expression",
    name = "zalupa_giant_exclusion_shape",
    expression = "zalupa_giant_exclusion_raw + zalupa_island_edge"
  },

  {
    type = "noise-expression",
    name = "zalupa_giant_exclusion_mask",
    expression = "clamp((zalupa_giant_exclusion_shape - 0.32) * 20, 0, 1)"
  },

  {
    type = "noise-expression",
    name = "zalupa_volcano_shape",
    expression = "zalupa_volcano_raw + zalupa_island_edge"
  },

  {
    type = "noise-expression",
    name = "zalupa_volcano_rock_shape",
    expression = "zalupa_volcano_rock_raw + zalupa_island_edge"
  },

  {
    type = "noise-expression",
    name = "zalupa_volcano_fulgoran_shape",
    expression = "zalupa_volcano_fulgoran_raw + zalupa_island_edge"
  },

  {
    type = "noise-expression",
    name = "zalupa_volcano_rock_mask",
    expression = "clamp((zalupa_volcano_rock_shape - 0.32) * 20, 0, 1) * zalupa_giant_volcano_mask"
  },

  {
    type = "noise-expression",
    name = "zalupa_volcano_fulgoran_mask",
    expression = "clamp((zalupa_volcano_fulgoran_shape - 0.32) * 20, 0, 1) * zalupa_giant_volcano_mask"
  },

  {
    type = "noise-expression",
    name = "zalupa_volcano_lava_mask",
    expression = "clamp((zalupa_volcano_shape - 0.52) * 20, 0, 1) * zalupa_giant_volcano_mask"
  },

  {
    type = "noise-expression",
    name = "zalupa_volcano_hot_mask",
    expression = "clamp((zalupa_volcano_shape - 0.72) * 20, 0, 1) * zalupa_giant_volcano_mask"
  },

  -- =====================================================================
  -- Вулканы больших островов
  -- =====================================================================
  -- Та же структура, что у вулканов островов-гигантов, но:
  --   * нет высокой скалы (highland-dark-rock-2);
  --   * вместо лавы/горячей лавы — белая нефть (white-oil-ocean-deep-2),
  --     вокруг неё кольцо фульгорианского камня.
  {
    type = "noise-expression",
    name = "zalupa_big_volcano_raw",
    expression = [[
      spot_noise{
        x = x + 4 * (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 10501,
          input_scale = 0.03
        } - 0.5),
        y = y + 4 * (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 10502,
          input_scale = 0.03
        } - 0.5),
        seed0 = map_seed,
        seed1 = 10503,
        candidate_spot_count = 1,
        suggested_minimum_candidate_point_spacing = 16,
        skip_span = 1,
        skip_offset = 0,
        region_size = 32,
        density_expression = clamp((zalupa_big_island_shape - 0.72) * 30, 0, 1),
        spot_quantity_expression = 324,
        spot_radius_expression = 18,
        spot_favorability_expression = 1,
        hard_region_target_quantity = 0,
        basement_value = 0,
        maximum_spot_basement_radius = 64
      }
    ]]
  },

  -- Внешнее кольцо фульгорианского камня вокруг нефтяного озера.
  {
    type = "noise-expression",
    name = "zalupa_big_volcano_rock_raw",
    expression = [[
      spot_noise{
        x = x + 4 * (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 10501,
          input_scale = 0.03
        } - 0.5),
        y = y + 4 * (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 10502,
          input_scale = 0.03
        } - 0.5),
        seed0 = map_seed,
        seed1 = 10503,
        candidate_spot_count = 1,
        suggested_minimum_candidate_point_spacing = 16,
        skip_span = 1,
        skip_offset = 0,
        region_size = 32,
        density_expression = clamp((zalupa_big_island_shape - 0.72) * 30, 0, 1),
        spot_quantity_expression = 1156,
        spot_radius_expression = 34,
        spot_favorability_expression = 1,
        hard_region_target_quantity = 0,
        basement_value = 0,
        maximum_spot_basement_radius = 64
      }
    ]]
  },

  {
    type = "noise-expression",
    name = "zalupa_big_volcano_shape",
    expression = "zalupa_big_volcano_raw + zalupa_island_edge"
  },

  {
    type = "noise-expression",
    name = "zalupa_big_volcano_rock_shape",
    expression = "zalupa_big_volcano_rock_raw + zalupa_island_edge"
  },

  {
    type = "noise-expression",
    name = "zalupa_big_volcano_mask",
    expression = "clamp((zalupa_big_island_shape - 0.34) * 20, 0, 1)"
  },

  {
    type = "noise-expression",
    name = "zalupa_big_rock_mask",
    expression = "clamp((zalupa_big_volcano_rock_shape - 0.32) * 20, 0, 1) * zalupa_big_volcano_mask"
  },

  {
    type = "noise-expression",
    name = "zalupa_big_oil_mask",
    expression = "clamp((zalupa_big_volcano_shape - 0.52) * 20, 0, 1) * zalupa_big_volcano_mask"
  },

  {
    type = "noise-expression",
    name = "zalupa_big_any_mask",
    expression = "max(zalupa_big_rock_mask, zalupa_big_oil_mask)"
  },

  {
    type = "noise-expression",
    name = "zalupa_volcano_any_mask",
    expression = "max(zalupa_volcano_rock_mask, zalupa_volcano_lava_mask, zalupa_volcano_hot_mask, zalupa_volcano_fulgoran_mask, zalupa_big_any_mask)"
  },

  -- =====================================================================
  -- Расщелины из фульгорианского камня на островах-гигантах
  -- =====================================================================
  {
    type = "noise-expression",
    name = "zalupa_giant_fulgoran_cracks_field",
    expression = [[
      multioctave_noise{
        x = x,
        y = y,
        seed0 = map_seed,
        seed1 = 9100,
        octaves = 3,
        persistence = 0.5,
        input_scale = 0.05,
        output_scale = 1
      }
      + 0.6 * multioctave_noise{
        x = x,
        y = y,
        seed0 = map_seed,
        seed1 = 9101,
        octaves = 2,
        persistence = 0.5,
        input_scale = 0.18,
        output_scale = 1
      }
    ]]
  },

  {
    type = "noise-expression",
    name = "zalupa_giant_fulgoran_cracks_mask",
    expression = [[
      clamp((zalupa_giant_fulgoran_cracks_field - 0.35) * 15, 0, 1)
      * max(zalupa_giant_island_mask, zalupa_big_island_mask)
      * (1 - zalupa_volcano_any_mask)
      * 0.7
    ]]
  },

  {
    type = "noise-expression",
    name = "zalupa_big_island_shape",
    expression = "zalupa_big_island_raw + zalupa_island_edge"
  },

  -- Большие острова не появляются внутри островов-гигантов и их зон
  -- отчуждения, чтобы структуры не накладывались друг на друга.
  {
    type = "noise-expression",
    name = "zalupa_big_island_mask",
    expression = [[
      clamp((zalupa_big_island_shape - 0.32) * 20, 0, 1)
      * (1 - zalupa_giant_volcano_mask)
      * (1 - zalupa_giant_exclusion_mask)
    ]]
  },

  {
    type = "noise-expression",
    name = "zalupa_dust_selector",
    expression = [[
      clamp(
        (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 7001,
          input_scale = 0.040
        } - 0.62) * 20,
        0,
        1
      )
    ]]
  },

  {
    type = "noise-expression",
    name = "zalupa_dunes_selector",
    expression = [[
      clamp(
        (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 8001,
          input_scale = 0.028
        } - 0.64) * 20,
        0,
        1
      )
    ]]
  },

  {
    type = "noise-expression",
    name = "zalupa_spawn_island",
    expression = [[
      max(
        clamp(
          (1 - sqrt(x * x + y * y) / 65) * 3
          + zalupa_island_edge * 3,
          0,
          1
        ),
        clamp(
          (1 - distance_from_nearest_point{
            x = x,
            y = y,
            points = starting_positions,
            maximum_distance = 65
          } / 65) * 3
          + zalupa_island_edge * 3,
          0,
          1
        )
      )
    ]]
  },

  {
    type = "noise-expression",
    name = "zalupa_small_island_mask",
    expression = [[
      max(
        zalupa_small_island_noise * (1 - zalupa_big_island_mask) * (1 - zalupa_giant_exclusion_mask),
        zalupa_spawn_island * (1 - zalupa_big_island_mask)
      )
    ]]
  },

  {
    type = "noise-expression",
    name = "zalupa_dunes_island_mask",
    expression = "zalupa_small_island_noise * (1 - zalupa_big_island_mask) * (1 - zalupa_giant_exclusion_mask) * (1 - zalupa_spawn_island) * zalupa_dunes_selector"
  },

  {
    type = "noise-expression",
    name = "zalupa_dust_island_mask",
    expression = "zalupa_small_island_noise * (1 - zalupa_big_island_mask) * (1 - zalupa_giant_exclusion_mask) * (1 - zalupa_spawn_island) * zalupa_dust_selector * (1 - zalupa_dunes_selector)"
  },

  {
    type = "noise-expression",
    name = "zalupa_sand_island_mask",
    expression = [[
      max(
        zalupa_giant_island_mask,
        zalupa_big_island_mask,
        zalupa_spawn_island * (1 - zalupa_big_island_mask),
        zalupa_small_island_noise * (1 - zalupa_big_island_mask) * (1 - zalupa_giant_exclusion_mask) * (1 - zalupa_spawn_island)
          * (1 - zalupa_dust_selector) * (1 - zalupa_dunes_selector)
      )
    ]]
  },

  {
    type = "noise-expression",
    name = "zalupa_island_mask",
    expression = "max(zalupa_giant_island_mask, zalupa_big_island_mask, zalupa_small_island_mask)"
  },

  -- =====================================================================
  -- Вероятности тайлов
  -- =====================================================================

  {
    type = "noise-expression",
    name = "zalupa_sand_island_prob",
    expression = "zalupa_sand_island_mask * (1 - zalupa_volcano_any_mask) * (1 - zalupa_giant_fulgoran_cracks_mask) * 10000"
  },

  {
    type = "noise-expression",
    name = "zalupa_volcano_rock_prob",
    expression = "zalupa_volcano_rock_mask * (1 - zalupa_volcano_lava_mask) * 10000"
  },

  {
    type = "noise-expression",
    name = "zalupa_volcano_fulgoran_prob",
    expression = "max(zalupa_volcano_fulgoran_mask * (1 - zalupa_volcano_rock_mask) * (1 - zalupa_volcano_lava_mask), zalupa_giant_fulgoran_cracks_mask) * 10000"
  },

  {
    type = "noise-expression",
    name = "zalupa_volcano_lava_prob",
    expression = "zalupa_volcano_lava_mask * (1 - zalupa_volcano_hot_mask) * 10000"
  },

  {
    type = "noise-expression",
    name = "zalupa_volcano_hot_prob",
    expression = "zalupa_volcano_hot_mask * 10000"
  },

  -- Большие острова: фульгорианский камень кольцом и белая нефть в ядре
  -- (вместо лавы). Белая нефть - тайл white-oil-ocean-deep-2 (см. map-gen.lua).
  {
    type = "noise-expression",
    name = "zalupa_big_rock_prob",
    expression = "zalupa_big_rock_mask * (1 - zalupa_big_oil_mask) * 10000"
  },

  {
    type = "noise-expression",
    name = "zalupa_big_oil_prob",
    expression = "zalupa_big_oil_mask * 10000"
  },

  {
    type = "noise-expression",
    name = "zalupa_dust_island_prob",
    expression = "zalupa_dust_island_mask * 10000"
  },

  {
    type = "noise-expression",
    name = "zalupa_dunes_island_prob",
    expression = "zalupa_dunes_island_mask * 10000"
  },

  -- Базовый тайл - теперь пустой космос, а не нефть
  -- Оставляем старое имя для совместимости + новое
  {
    type = "noise-expression",
    name = "zalupa_oil_prob",
    expression = "(1 - zalupa_island_mask) * 10000 + 1"
  },

  {
    type = "noise-expression",
    name = "zalupa_space_prob",
    expression = "(1 - zalupa_island_mask) * 10000 + 1"
  },

  -- =====================================================================
  -- sun: стартовая площадка и старая генерация (только совместимость).
  -- =====================================================================
  -- sun_landing_pad_prob — круглая площадка фундамента радиусом ~14 тайлов
  -- вокруг начала координат, то есть в точке высадки на sun. Вся остальная
  -- поверхность планеты — лава с вероятностью 1, поэтому фундамент выигрывает
  -- только внутри круга (там вероятность до 10000).
  {
    type = "noise-expression",
    name = "sun_landing_pad_prob",
    expression = [[
      (1 - clamp(sqrt(x * x + y * y) / 14, 0, 1)) * 10000
    ]]
  },

  -- Старая генерация sun (космос + моря лавы) — только для совместимости.
  -- Сейчас sun генерируется сплошной лавой (см. prototype/planet/map-gen.lua),
  -- и эти выражения не используются. Они оставлены, потому что сохранения,
  -- созданные до переделки, хранят в map_gen_settings ссылки на них: без них
  -- старый сейв не сможет догенерировать новые чанки на sun.
  {
    type = "noise-expression",
    name = "sun_void_mask",
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
    name = "sun_void_prob",
    expression = "sun_void_mask * (1 - zalupa_island_mask) * 10000 + 1"
  },

  {
    type = "noise-expression",
    name = "sun_lava_prob",
    expression = "max(zalupa_volcano_hot_prob, (1 - sun_void_mask) * (1 - zalupa_island_mask) * 10000)"
  },

  -- =====================================================================
  -- Запрет руд вокруг вулканов
  -- =====================================================================
  -- Большое пятно вокруг каждого вулкана (по форме внешнего фульгорианского
  -- кольца, радиус ~52 тайла): руды q1/q2 тут не появляются вовсе. Руды
  -- умножаются на (1 - это), внутри пятна это 1 -> вероятность 0.
  -- Множитель 30 делает край пятна почти ступенькой, чтобы в «полутонах»
  -- не проскакивали отдельные руды.
  {
    type = "noise-expression",
    name = "zalupa_volcano_ore_exclusion",
    expression = "clamp((zalupa_volcano_fulgoran_shape - 0.08) * 30, 0, 1) * zalupa_giant_volcano_mask"
  },

  -- Рукава дыма: гладкое крупное поле задаёт, в какие стороны дым
  -- вытягивается из лавового озера ровными языками (значения ~0..1, центр 0.5).
  -- basis_noise центрирован в 0, поэтому 0.5 прибавляем сами; одна октава и
  -- крупный масштаб — рукава получаются гладкими, без ряби.
  {
    type = "noise-expression",
    name = "zalupa_lava_smoke_branches",
    expression = [[
      clamp(
        0.5 + 1.3 * basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 11103,
          input_scale = 0.08
        },
        0,
        1
      )
    ]]
  },

  -- Пробелы в дыме: тоже гладкое поле (значения ~0..1, центр 0.5).
  -- Чем меньше значение в точке, тем больше там дыра.
  {
    type = "noise-expression",
    name = "zalupa_lava_smoke_gaps",
    expression = [[
      clamp(
        0.5 + 1.0 * basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 11101,
          input_scale = 0.10
        },
        0,
        1
      )
    ]]
  },

  -- Покрытие дыма. Считается из той же формы вулкана, что и лава
  -- (zalupa_volcano_shape):
  --   1) контур: над лавой всегда 1; порог смещают «рукава», поэтому дым
  --      вылезает за лаву ровными языками на небольшой радиус (~1-3 тайла);
  --   2) множитель 0.65 задаёт общую плотность;
  --   3) пробелы режут покрытие, но их порог растёт с удалением от центра,
  --      а в самом центре включён «пол» — дыры не могут выгрызть середину.
  {
    type = "noise-expression",
    name = "zalupa_lava_smoke_mask",
    expression = [[
      0.65
      * clamp(
          (zalupa_volcano_shape - (0.46 - 0.10 * zalupa_lava_smoke_branches)) * 12,
          0,
          1
        )
      * zalupa_giant_volcano_mask
      * max(
          clamp(
            (zalupa_lava_smoke_gaps - (0.80 - 1.0 * zalupa_volcano_shape)) * 1.5,
            0,
            1
          ),
          clamp((zalupa_volcano_shape - 0.60) * 3, 0, 1)
        )
    ]]
  },

  -- Вероятность поставить облако-дым на тайл (autoplace simple-entity,
  -- см. data-final-fixes.lua). Значение 0..1: движок сам раскидывает
  -- дым по тайлам, поэтому пробелы получаются ещё и случайными.
  {
    type = "noise-expression",
    name = "zalupa_lava_smoke_prob",
    expression = "zalupa_lava_smoke_mask"
  },

  -- =====================================================================
  -- Атмосферные руды q1/q2
  -- =====================================================================

  {
    type = "noise-expression",
    name = "cloud_q1_field",
    expression = [[
      multioctave_noise{
        x = x + 6 * basis_noise{x = x, y = y, seed0 = map_seed, seed1 = 1777, input_scale = 0.015},
        y = y + 6 * basis_noise{x = x, y = y, seed0 = map_seed, seed1 = 2777, input_scale = 0.015},
        seed0 = map_seed,
        seed1 = 777,
        octaves = 4,
        persistence = 0.5,
        input_scale = 0.05,
        output_scale = 1
      }
      +
      0.6 * multioctave_noise{
        x = x,
        y = y,
        seed0 = map_seed,
        seed1 = 5777,
        octaves = 3,
        persistence = 0.5,
        input_scale = 0.16,
        output_scale = 1
      }
    ]]
  },

  {
    type = "noise-expression",
    name = "cloud_q2_field",
    expression = [[
      multioctave_noise{
        x = x + 6 * basis_noise{x = x, y = y, seed0 = map_seed, seed1 = 1778, input_scale = 0.015},
        y = y + 6 * basis_noise{x = x, y = y, seed0 = map_seed, seed1 = 2778, input_scale = 0.015},
        seed0 = map_seed,
        seed1 = 778,
        octaves = 4,
        persistence = 0.5,
        input_scale = 0.05,
        output_scale = 1
      }
      +
      0.6 * multioctave_noise{
        x = x,
        y = y,
        seed0 = map_seed,
        seed1 = 5778,
        octaves = 3,
        persistence = 0.5,
        input_scale = 0.16,
        output_scale = 1
      }
    ]]
  },

  -- Руды не появляются в большом радиусе вокруг вулканов: множитель
  -- (1 - запрет) гасит их на вулканах и в их широких окрестностях
  -- (см. zalupa_volcano_ore_exclusion).
  {
    type = "noise-expression",
    name = "q1_ore_probability",
    expression = "clamp((cloud_q1_field - 1.50) * 100, 0, 1) * (1 - zalupa_volcano_ore_exclusion)"
  },

  {
    type = "noise-expression",
    name = "q2_ore_probability",
    expression = "clamp((cloud_q2_field - 1.55) * 100, 0, 1) * (1 - zalupa_volcano_ore_exclusion)"
  },

  {
    type = "noise-expression",
    name = "q1_ore_richness",
    expression = "500"
  },

  {
    type = "noise-expression",
    name = "q2_ore_richness",
    expression = "500"
  },
})
