-- ВЫКЛЮЧЕНО: старый прототип space-assembler, оставлен как история.
-- Этот файл нигде не подключается (require на него нет), весь код закомментирован.
-- При желании можно удалить целиком.

--[[
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

]]
