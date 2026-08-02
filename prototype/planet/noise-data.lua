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

})