-- cable (оптоволокно: кабель + его остатки)
local C = require("prototype.entity.shared")
local q = C.q
local hit_effects, sounds = C.hit_effects, C.sounds

local cable_it = table.deepcopy(data.raw["item"]["pipe"])
cable_it.name = "cable1"
cable_it.icon = q .."/graphics/icon/optical-fiber.png"
cable_it.place_result = cable_it.name
cable_it.subgroup = "space-platform"
cable_it.order = "q[" .. cable_it.name .. "]"
data:extend({cable_it})

data:extend({
  {
    type = "corpse",
    name = "calfiber-remnants",
    icon = q .."/graphics/icon/optical-fiber.png",
    flags = {"placeable-neutral", "not-on-map"},
    hidden_in_factoriopedia = true,
    subgroup = "energy-pipe-distribution-remnants",
    order = "a-d-a",
    collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
    selection_box = {{-0.4, -0.4}, {0.4, 0.4}},
    selectable_in_game = false,
    time_before_removed = 60 * 60 * 15, -- 15 minutes
    expires = false,
    final_render_layer = "remnants",
    remove_on_tile_placement = false,
    animation = make_rotated_animation_variations_from_sheet(2,
    {
      filename = q .."/graphics/entity/opticalfiber/remnants/opticalfiber-remnants.png",
      width = 122,
      height = 120,
      line_length = 1,
      direction_count = 2,
      shift = util.by_pixel(1.5, 2.5), -- -0,5
      scale = 0.5
    })
  },

  {
    type = "pipe",
    name = cable_it.name,
    icon = q .."/graphics/icon/optical-fiber.png",
    flags = {"placeable-neutral", "player-creation"},
    minable = {mining_time = 0.1, result = cable_it.name},
    max_health = 10,
    corpse = "calfiber-remnants",
    dying_explosion = "pipe-explosion",
    icon_draw_specification = {scale = 0},
    resistances = {
      {
        type = "fire",
        percent = 30
      },
      {
        type = "impact",
        percent = 50
      }
    },
    fast_replaceable_group = "cable",
    collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
    selection_box = {{-0.4, -0.4}, {0.4, 0.4}},
    damaged_trigger_effect = hit_effects.entity(),
    fluid_box =
    {
      draw_only_when_connected = true,
      hide_connection_info = true,
      volume = 10,
      pipe_covers = opticalfibercoverspictures(), -- in case a real pipe is connected to a ghost
      pipe_connections =
      {
        { direction = defines.direction.north, position = {0, 0}, connection_category = "cable", hide_connection_info = true},
        { direction = defines.direction.east,  position = {0, 0}, connection_category = "cable", hide_connection_info = true},
        { direction = defines.direction.south, position = {0, 0}, connection_category = "cable", hide_connection_info = true},
        { direction = defines.direction.west,  position = {0, 0}, connection_category = "cable", hide_connection_info = true}
      },
      max_pipeline_extent = 1000000000,
    },
    impact_category = "glass",
    pictures = opticalfiberpictures(),
    working_sound = sounds.pipe,
    open_sound = sounds.metal_small_open,
    close_sound = sounds.metal_small_close,

    horizontal_window_bounding_box = {{-0.25, -0.28125}, {0.25, 0.15625}},
    vertical_window_bounding_box = {{-0.28125, -0.5}, {0.03125, 0.125}}
  },
})
