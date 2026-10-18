-- scrubber
local C = require("prototype.entity.shared")
local q, a_speed = C.q, C.a_speed
local hit_effects, sounds = C.hit_effects, C.sounds
local proto = C.proto

local pipe_picture = require(q .. ".prototype.pipe_picture")

-- 4 патрубка (2 вход / 2 выход) для сборщика
local function F()
  return
  {
    {
      production_type = "input",
      pipe_picture = pipe_picture.e1_pipe_pictures(),
      pipe_covers = pipecoverspictures(),
      volume = 1000,
      pipe_connections = { { flow_direction = "input", direction = defines.direction.north, position = { 0, -1 } } },
      secondary_draw_orders = { north = -1 }
    },
    {
      production_type = "input",
      pipe_picture = pipe_picture.e1_pipe_pictures(),
      pipe_covers = pipecoverspictures(),
      volume = 1000,
      pipe_connections = { { flow_direction = "input", direction = defines.direction.south, position = { 0, 1 } } },
      secondary_draw_orders = { north = -1 }
    },
    {
      production_type = "output",
      pipe_picture = pipe_picture.e1_pipe_pictures(),
      pipe_covers = pipecoverspictures(),
      volume = 1000,
      pipe_connections = { { flow_direction = "output", direction = defines.direction.east, position = { 1, 0 } } },
      secondary_draw_orders = { north = -1 }
    },
    {
      production_type = "output",
      pipe_picture = pipe_picture.e1_pipe_pictures(),
      pipe_covers = pipecoverspictures(),
      volume = 1000,
      pipe_connections = { { flow_direction = "output", direction = defines.direction.west, position = { -1, 0 } } },
      secondary_draw_orders = { north = -1 }
    },
  }
end

-- energy_source: электричество + загрязнение 2/мин
local function E()
  return
    {
      type = "electric",
      usage_priority = "secondary-input",
      emissions_per_minute = { pollution = 2 }
    }
end

local scrubber_it = table.deepcopy(data.raw["item"]["assembling-machine-3"])
scrubber_it.name = "scrubber"
scrubber_it.icon = q .. "/graphics/icon/scrubber-icon.png"
scrubber_it.place_result = scrubber_it.name
scrubber_it.subgroup = "space-platform"
data:extend({scrubber_it})

local ab = 0.0
local b = -12
local scrubber = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
scrubber.name = scrubber_it.name
scrubber.icon = q .. "/graphics/icon/scrubber-icon.png"
scrubber.minable = {mining_time = 1, result = "scrubber"}
scrubber.max_health = 300
scrubber.corpse = "asteroid-collector-remnants"
--scrubber.dying_explosion = "nuclear-reactor-explosion"
scrubber.flags = {"placeable-neutral", "placeable-player", "player-creation"}
scrubber.effect_receiver = { base_effect = { productivity = 1 }}
--scrubber.resistances = {{ type = "fire", percent = 70 }}
scrubber.collision_box = {{-1.25, -1.25}, {1.25, 1.25}}
scrubber.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}
scrubber.source_inventory_size = 1
scrubber.result_inventory_size = 1
scrubber.damaged_trigger_effect = hit_effects.entity()
scrubber.crafting_categories = {"crafting", "advanced-crafting", "crafting-with-fluid"}
scrubber.crafting_speed = 1.25
scrubber.energy_source = E()
scrubber.energy_usage = "520kW"
scrubber.next_upgrade = nil
scrubber.energy_source_secondary = { type = "electric", usage_priority = "secondary-input" }
scrubber.open_sound = sounds.machine_open
scrubber.close_sound = sounds.machine_close
scrubber.impact_category = "metal"
scrubber.module_slots = 1
scrubber.allowed_effects = {"consumption", "speed", "pollution"}
scrubber.surface_conditions = proto.planet()
scrubber.fluid_boxes_off_when_no_fluid_recipe = true
scrubber.fluid_boxes = F()
scrubber.graphics_set = {
    animation = {
      layers = {
        {
          filename = q .. "/graphics/entity/scrubber/scrubber-animation.png",
          height = 280,
          width = 210,
          shift = util.by_pixel(0, -15 + b),
          animation_speed = a_speed,
          line_length = 10,
          frame_count = 60,
          scale = 0.5 - ab
        },
        {
          filename = q .. "/graphics/entity/scrubber/scrubber-corp-123.png",
          height = 286,
          width = 287,
          shift = util.by_pixel(-1, 4 + b),
          line_length = 1,
          repeat_count = 60,
          scale = 0.5 - ab
        },
--[[
        {
          filename = q .. "/graphics/entity/scrubber/scrubber-shadow.png",
          width = 400,
          height = 350,
          shift = util.by_pixel(0, -15),
          animation_speed = a_speed,
          line_length = 1,
          repeat_count = 60,
          scale = 0.5,
          draw_as_shadow = true
        },
]]
        {
          filename = q .. "/graphics/entity/scrubber/scrubber-shadow-123.png",
          width = 226,
          height = 261,
          shift = util.by_pixel(45, -10 + b),
          line_length = 1,
          repeat_count = 60,
          scale = 0.5 - ab,
          draw_as_shadow = true
        },
      }
    }
  }
data:extend({scrubber})
