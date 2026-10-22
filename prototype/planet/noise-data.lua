data:extend({

  {
    type = "noise-expression",
    name = "dead_skin_base",
    expression = "-10"
  },

  {
    type = "noise-expression",
    name = "islands_raw_noise",
    expression = [[
      multioctave_noise{
        x = x,
        y = y,
        seed0 = map_seed,
        seed1 = 123,
        octaves = 4,
        persistence = 0.5,
        input_scale = 0.05, 
        output_scale = 1
      }
    ]]
  },


  {
    type = "noise-expression",
    name = "islands_mask",
    expression = "clamp((islands_raw_noise - 0.68) * 2, 0, 1)"
  },


  {
    type = "noise-expression",
    name = "quantum_elevation",
    intended_property = "elevation",
    expression = "dead_skin_base + (islands_mask * 35)"
  },

  {
    type = "noise-expression",
    name = "dead_skin_prob",
    intended_property = "probability",
    expression = "10" 
  },


  {
    type = "noise-expression",
    name = "volcanic_folds_flat_prob",
    expression = "(islands_mask > 0.05) * 20"
  },


  {
    type = "noise-expression",
    name = "volcanic_cracks_prob",
    expression = "(islands_mask > 0.80) * 25"
  },


  {
    type = "noise-expression",
    name = "volcanic_folds_prob",
    expression = "(islands_mask > 0.95) * 30"
  },

  -- Атмосферные руды q1/q2: у каждой своё поле, чтобы пятна не пересекались.
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
