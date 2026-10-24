-- Шумовые выражения планеты zalupa.
--
-- Первый, простой вариант:
--   * вся планета залита white-oil-ocean-deep-2;
--   * крупные острова и редкие острова-гиганты сделаны из fulgoran-sand;
--   * вокруг гигантов есть пустая зона, где не появляются другие острова;
--   * у мелких островов есть разнообразие: песок, пыль и дюны;
--   * на островах-гигантах много больших вулканов: фульгорианский камень,
--     высокогорный камень, лава и горячая лава; над лавой поднимается дым;
--   * вокруг стартовой точки есть гарантированный песчаный остров.
--
-- Реки, оазисы и прочие биомы сюда пока не добавляем — будем делать их
-- следующими порциями.

data:extend({
  -- =====================================================================
  -- Острова
  -- =====================================================================

  -- Мелкие острова: по одному пятну на область 64x64, с искажением
  -- координат, чтобы форма не была идеально круглой.
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
        suggested_minimum_candidate_point_spacing = 32,
        skip_span = 1,
        skip_offset = 0,
        region_size = 64,
        density_expression = 1,
        spot_quantity_expression = 484,
        spot_radius_expression = 22,
        spot_favorability_expression = 1,
        hard_region_target_quantity = 0,
        basement_value = 0,
        maximum_spot_basement_radius = 64
      }
    ]]
  },

  -- Крупные острова: отдельный, более редкий слой. Он не смешивается
  -- с мелкими островами — мелкие вырезаются там, где уже есть крупный.
  {
    type = "noise-expression",
    name = "zalupa_big_island_raw",
    expression = [[
      spot_noise{
        x = x + 10 * (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 6001,
          input_scale = 0.010
        } - 0.5),
        y = y + 10 * (basis_noise{
          x = x,
          y = y,
          seed0 = map_seed,
          seed1 = 6002,
          input_scale = 0.010
        } - 0.5),
        seed0 = map_seed,
        seed1 = 6003,
        candidate_spot_count = 1,
        suggested_minimum_candidate_point_spacing = 80,
        skip_span = 1,
        skip_offset = 0,
        region_size = 160,
        density_expression = 1,
        spot_quantity_expression = 2304,
        spot_radius_expression = 48,
        spot_favorability_expression = 1,
        hard_region_target_quantity = 0,
        basement_value = 0,
        maximum_spot_basement_radius = 160
      }
    ]]
  },

  -- Очень редкие острова-гиганты. Их мало, и вокруг каждого остаётся
  -- пустая нефтяная зона: остальные острова в этот радиус не попадают.
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

  -- Большие вулканы на островах-гигантах. Все три слоя используют одни
  -- и те же центры, поэтому лава, высокогорный камень и фульгорианский
  -- камень вокруг неё всегда совпадают.
  --
  -- Центры выбираются только в глубине острова: density_expression
  -- отсекает кандидаты у берега, чтобы вулканы не обрезались о нефть.
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

  -- Широкое каменное пятно с теми же центрами: высокогорный камень.
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
        spot_quantity_expression = 1444,
        spot_radius_expression = 38,
        spot_favorability_expression = 1,
        hard_region_target_quantity = 0,
        basement_value = 0,
        maximum_spot_basement_radius = 64
      }
    ]]
  },

  -- Мелкий шум, который рвёт береговую линию: острова должны быть
  -- неровными, а не ровными кругами.
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

  -- Превращаем шум в маску острова. Всё, что ниже порога, — нефть.
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

  -- Отступ от берега: вулканы не должны начинаться вплотную к кромке
  -- гиганта. Оставляем узкую песчаную полосу между камнем и нефтью.
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

  -- Вулканы строятся только внутри острова-гиганта. Внешнее кольцо —
  -- высокогорный камень, затем лава, в самом центре — горячая лава.
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

  {
    type = "noise-expression",
    name = "zalupa_volcano_any_mask",
    expression = "max(zalupa_volcano_rock_mask, zalupa_volcano_lava_mask, zalupa_volcano_hot_mask, zalupa_volcano_fulgoran_mask)"
  },

  {
    type = "noise-expression",
    name = "zalupa_big_island_shape",
    expression = "zalupa_big_island_raw + zalupa_island_edge"
  },

  {
    type = "noise-expression",
    name = "zalupa_big_island_mask",
    expression = "clamp((zalupa_big_island_shape - 0.32) * 20, 0, 1) * (1 - zalupa_giant_exclusion_mask)"
  },

  -- Два независимых поля, которые выбирают материал мелких островов.
  -- Частота подобрана так, чтобы пятна были меньше небольших островов
  -- и не превращались в размазанную рябь.
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

  -- Стартовый остров: гарантированно даёт песок в начале игры.
  -- Учитываем и центр карты, и реальные стартовые позиции. Край стартового
  -- острова тоже делаем неровным, а сам остров — небольшим.
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

  -- Пыль и дюны встречаются только на мелких островах и никогда не
  -- залезают на крупные острова, гиганты или стартовую площадку. Дюны
  -- имеют приоритет над пылью, а песок остаётся там, где не выбрано ничего.
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

  -- Общая суша: гиганты, крупные острова, мелкие острова и стартовая площадка.
  {
    type = "noise-expression",
    name = "zalupa_island_mask",
    expression = "max(zalupa_giant_island_mask, zalupa_big_island_mask, zalupa_small_island_mask)"
  },

  -- =====================================================================
  -- Вероятности тайлов
  -- =====================================================================

  -- На островах суши гораздо больше, чем нефти; вулканические тайлы
  -- вырезают песок под собой.
  {
    type = "noise-expression",
    name = "zalupa_sand_island_prob",
    expression = "zalupa_sand_island_mask * (1 - zalupa_volcano_any_mask) * 10000"
  },

  {
    type = "noise-expression",
    name = "zalupa_volcano_rock_prob",
    expression = "zalupa_volcano_rock_mask * (1 - zalupa_volcano_lava_mask) * 10000"
  },

  {
    type = "noise-expression",
    name = "zalupa_volcano_fulgoran_prob",
    expression = "zalupa_volcano_fulgoran_mask * (1 - zalupa_volcano_rock_mask) * (1 - zalupa_volcano_lava_mask) * 10000"
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

  -- Везде, кроме островов, — белая нефть. Единица нужна, чтобы нефть
  -- оставалась базовым тайлом даже на самом краю острова.
  {
    type = "noise-expression",
    name = "zalupa_oil_prob",
    expression = "(1 - zalupa_island_mask) * 10000 + 1"
  },

  -- =====================================================================
  -- Атмосферные руды q1/q2 (не трогаем — их поля остались прежними)
  -- =====================================================================

  -- Пятно = "озеро": крупная кучная масса (низкочастотный шум) плюс
  -- рваная береговая линия (мелкий шум) и искажение координат (domain warp).
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

  {
    type = "noise-expression",
    name = "q1_ore_probability",
    expression = "clamp((cloud_q1_field - 1.50) * 100, 0, 1)"
  },

  {
    type = "noise-expression",
    name = "q2_ore_probability",
    expression = "clamp((cloud_q2_field - 1.55) * 100, 0, 1)"
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
