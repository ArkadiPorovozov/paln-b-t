-- atmo-cond: атмосферный конденсатор.
-- Это mining-drill: качает жидкость из атмосферной руды (q1-ore / q2-ore),
-- поэтому работает как pumpjack — выдаёт fluid через output_fluid_box.
-- Рецепта пока нет: предмет можно выдать только через консоль/редактор.

local C = require("prototype.entity.shared")
local q = C.q
local hit_effects = C.hit_effects

-- Графика: корпус + две турбины + два фильтра + тень.
-- "копия" в исходнике — это те же файлы, просто два слоя с разными shift.
-- scale 0.5: 400 px * 0.5 = 200 px = 6.25 тайла (коллизия 5.8, выделение 6x6).
local animation = {
  layers = {
    {
      filenames = {q .. "/graphics/entity/atmo-cond.png"},
      width = 400,
      height = 400,
      frame_count = 1,
      repeat_count = 32,
      line_length = 1,
      lines_per_file = 1,
      scale = 0.5,
      shift = util.by_pixel_hr(0, 0),
    },
    {
      filenames = {"__base__/graphics/entity/cargo-hubs/hubs/planet-hub-turbine.png"},
      width = 116,
      height = 78,
      frame_count = 32,
      line_length = 8,
      lines_per_file = 4,
      scale = 0.5,
      animation_speed = 1,
      shift = util.by_pixel_hr(-36, -57),
    },
    {
      filenames = {"__base__/graphics/entity/cargo-hubs/hubs/planet-hub-turbine.png"},
      width = 116,
      height = 78,
      frame_count = 32,
      line_length = 8,
      lines_per_file = 4,
      scale = 0.5,
      animation_speed = 1,
      shift = util.by_pixel_hr(55, -132),
    },
    {
      filenames = {"__base__/graphics/entity/rocket-silo/filter.png"},
      width = 82,
      height = 78,
      frame_count = 32,
      line_length = 6,
      lines_per_file = 6,
      scale = 0.5,
      animation_speed = 1,
      shift = util.by_pixel_hr(108, 67),
    },
    {
      filenames = {"__base__/graphics/entity/rocket-silo/filter.png"},
      width = 82,
      height = 78,
      frame_count = 32,
      line_length = 6,
      lines_per_file = 6,
      scale = 0.5,
      animation_speed = 1,
      shift = util.by_pixel_hr(156, 67),
    },
    {
      filenames = {q .. "/graphics/entity/atmo-cond-shadow.png"},
      width = 400,
      height = 400,
      frame_count = 1,
      repeat_count = 32,
      line_length = 1,
      lines_per_file = 1,
      scale = 0.5,
      shift = util.by_pixel_hr(60, 0.5),
      draw_as_shadow = true,
    },
  },
}

local atmo_cond_it = {
  type = "item",
  name = "atmo-cond",
  icon = q .. "/graphics/entity/atmo-cond-icon.png",
  icon_size = 64,
  subgroup = "production-machine",
  order = "e[atmo-cond]",
  place_result = "atmo-cond",
  stack_size = 10,
}
data:extend({atmo_cond_it})

data:extend({{
  type = "mining-drill",
  name = "atmo-cond",
  icon = atmo_cond_it.icon,
  icon_size = atmo_cond_it.icon_size,
  flags = {"placeable-neutral", "placeable-player", "player-creation"},
  minable = {mining_time = 0.5, result = "atmo-cond"},
  max_health = 500,
  damaged_trigger_effect = hit_effects.entity(),

  -- корпус 400x400 при scale 0.5 = 200 px = 6.25 тайла (чуть больше хитбокса)
  -- коллизия чуть меньше 6: при ровно +-3 соседние корпуса упираются друг в друга
  collision_box = {{-2.9, -2.9}, {2.9, 2.9}},
  -- ровно 6x6, без запаса под тень
  selection_box = {{-3, -3}, {3, 3}},

  resource_categories = {"atmospheric"},
  resource_searching_radius = 6,
  require_resources_to_place = true,
  -- 1 цикл = mining_time руды / mining_speed = 2 с, за цикл 10 единиц жидкости
  mining_speed = 0.5,
  energy_usage = "150kW",
  energy_source = {
    type = "electric",
    usage_priority = "secondary-input",
    emissions_per_minute = {pollution = 5},
  },

  vector_to_place_result = {0, 0},
  output_fluid_box = {
    volume = 1000,
    pipe_covers = pipecoverspictures(),
    -- южный край 6x6: тайлы центров -1.5 и 1.5, ровно на границе корпуса
    pipe_connections = {
      {
        flow_direction = "output",
        direction = defines.direction.south,
        position = {-1.5, 2.5},
      },
      {
        flow_direction = "output",
        direction = defines.direction.south,
        position = {1.5, 2.5},
      },
    },
  },

  radius_visualisation_picture =
    data.raw["mining-drill"]["electric-mining-drill"].radius_visualisation_picture,

  graphics_set = {animation = animation},

  circuit_connector = circuit_connector_definitions.create_vector(
    universal_connector_template,
    {
      {variation = 29, main_offset = util.by_pixel_hr(-103, -40), shadow_offset = {0, 0}, show_shadow = true},
      {variation = 29, main_offset = util.by_pixel_hr(-103, -40), shadow_offset = {0, 0}, show_shadow = true},
      {variation = 29, main_offset = util.by_pixel_hr(-103, -40), shadow_offset = {0, 0}, show_shadow = true},
      {variation = 29, main_offset = util.by_pixel_hr(-103, -40), shadow_offset = {0, 0}, show_shadow = true},
    }
  ),
  circuit_wire_max_distance = 9,
}})
