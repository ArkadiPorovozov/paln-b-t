local hit_effects = require("__base__.prototypes.entity.hit-effects")
local item_sounds = require("__base__.prototypes.item_sounds")
local sounds = require("__base__.prototypes.entity.sounds")

local config = require("script.config")

local q = "__paln-b-test__"
local a_speed = 1

local pipe_picture = require(q .. ".prototype.pipe_picture")
local proto = require(q .. ".prototype.proto")
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

local function E()
  return
    {
      type = "electric",
      usage_priority = "secondary-input",
      emissions_per_minute = { pollution = 2 }
    }
end



--space-assembler
local sapace_asm_it = table.deepcopy(data.raw["item"]["assembling-machine-2"])
sapace_asm_it.name = "space-assembler"
sapace_asm_it.icon = "__cr-commons__/graphics/entity/assembler/icon.png"
sapace_asm_it.place_result = sapace_asm_it.name
sapace_asm_it.subgroup = "space-platform"
data:extend({sapace_asm_it})

local sapace_asm = {}--table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
sapace_asm.name = sapace_asm_it.name
sapace_asm.type = "assembling-machine"
sapace_asm.icon = "__cr-commons__/graphics/entity/assembler/icon.png"
sapace_asm.minable = {mining_time = 1, result = "space-assembler"}
sapace_asm.max_health = 300
sapace_asm.corpse = "asteroid-collector-remnants"
--sapace_asm.dying_explosion = "nuclear-reactor-explosion"
sapace_asm.flags = {"placeable-neutral", "placeable-player", "player-creation"}
sapace_asm.effect_receiver = { base_effect = { productivity = 1 }}
sapace_asm.resistances = {{ type = "fire", percent = 70 }}
sapace_asm.collision_box = {{-1.25, -1.25}, {1.25, 1.25}}
sapace_asm.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}
sapace_asm.source_inventory_size = 1
sapace_asm.result_inventory_size = 1
sapace_asm.damaged_trigger_effect = hit_effects.entity()
sapace_asm.crafting_categories = {"crafting", "advanced-crafting", "crafting-with-fluid"}
sapace_asm.crafting_speed = 1.25
sapace_asm.energy_source = E()
sapace_asm.energy_usage = "1000kW"
sapace_asm.next_upgrade = nil
sapace_asm.energy_source_secondary = { type = "electric", usage_priority = "secondary-input" }
sapace_asm.open_sound = sounds.machine_open
sapace_asm.close_sound = sounds.machine_close
sapace_asm.impact_category = "metal"
sapace_asm.module_slots = 4
sapace_asm.allowed_effects = {"consumption", "speed", "pollution"}

sapace_asm.surface_conditions = proto.space()

sapace_asm.fluid_boxes_off_when_no_fluid_recipe = true
sapace_asm.fluid_boxes = F()

sapace_asm.graphics_set = {
    animation = {
      layers = {
        {
          filename = "__cr-commons__/graphics/entity/assembler/assembler.png",
          width = 194,
          height = 194,
          shift = util.by_pixel(0, 0),
          animation_speed = a_speed,
          line_length = 8,
          frame_count = 48,
          scale = 0.5
        },
        {
          filename = "__cr-commons__/graphics/entity/assembler/shadow.png",
          width = 194,
          height = 194,
          shift = util.by_pixel(35, 2),
          animation_speed = a_speed,
          line_length = 8,
          frame_count = 48,
          scale = 0.5,
          draw_as_shadow = true
        },
      }
    },
    working_visualisations = {
      {
        filename = "__cr-commons__/graphics/entity/assembler/assembler.png",
        width = 194,
        height = 194,
        shift = util.by_pixel(0, 0),
        animation_speed = a_speed,
        line_length = 8,
        frame_count = 48,
        scale = 0.5
      }
    }
  }
data:extend({sapace_asm})






--scrubber
local scrubber_it = table.deepcopy(data.raw["item"]["assembling-machine-3"])
scrubber_it.name = "scrubber"
scrubber_it.icon = q .. "/graphics/icon/scrubber-icon.png"
scrubber_it.place_result = scrubber_it.name
scrubber_it.subgroup = "space-platform"
data:extend({scrubber_it})

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
          shift = util.by_pixel(0, 0),
          animation_speed = a_speed,
          line_length = 10,
          frame_count = 60,
          scale = 0.5
        },
        {
          filename = q .. "/graphics/entity/scrubber/scrubber-shadow.png",
          width = 400,
          height = 350,
          shift = util.by_pixel(0, 0),
          animation_speed = a_speed,
          line_length = 1,
          repeat_count = 60,
          scale = 0.5,
          draw_as_shadow = true
        },
      }
    },
    working_visualisations = {
      {
        filename = q .. "/graphics/entity/scrubber/scrubber-color1.png",
        height = 280,
        width = 210,
        shift = util.by_pixel(0, 0),
        animation_speed = a_speed,
        line_length = 10,
        frame_count = 60,
        scale = 0.5
      }
    }
  }
data:extend({scrubber})

