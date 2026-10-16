-- ============================================================
-- Quantum Assemblers - Factorio 2.0 + Space Age
-- NO util.sprite_load — only direct sprite definitions
-- ============================================================

local hit_effects = require("__base__/prototypes/entity/hit-effects")
local sounds = require("__base__/prototypes/entity/sounds")

local q = "__paln-b-test__"

-- ============================================================
-- QUANTUM COMPUTER — 9x9 tiles
-- Base: 1024x1024 | Animation: 4096x4096 (4x4 = 16 frames)
-- ============================================================

local qc_item = table.deepcopy(data.raw["item"]["assembling-machine-3"])
qc_item.name = "quantum-computer"
qc_item.icon = q .. "/graphics/entity/quantum-computer/quantum-computer.png"
qc_item.icon_size = 1024
qc_item.place_result = "quantum-computer"
qc_item.subgroup = "production-machine"
qc_item.order = "c[quantum-computer]"
qc_item.stack_size = 10
data:extend({qc_item})

local qc = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
qc.name = "quantum-computer"
qc.icon = q .. "/graphics/entity/quantum-computer/quantum-computer.png"
qc.icon_size = 1024
qc.minable = {mining_time = 0.5, result = "quantum-computer"}
qc.next_upgrade = nil
qc.collision_box = {{-4.3, -4.3}, {4.3, 4.3}}
qc.selection_box = {{-4.5, -4.5}, {4.5, 4.5}}
qc.damaged_trigger_effect = hit_effects.entity()
qc.crafting_speed = 5.0
qc.energy_source = {
    type = "electric",
    usage_priority = "secondary-input",
    emissions_per_minute = { pollution = 5 }
}
qc.energy_usage = "2MW"
qc.crafting_categories = {"crafting", "advanced-crafting", "crafting-with-fluid"}
qc.module_specification = { module_slots = 4 }
qc.open_sound = sounds.machine_open
qc.close_sound = sounds.machine_close
qc.working_sound = {
    sound = {
        filename = "__base__/sound/assembling-machine-t3-1.ogg",
        volume = 0.45,
        audible_distance_modifier = 0.5,
    },
    fade_in_ticks = 4,
    fade_out_ticks = 20,
}
qc.graphics_set = {
    animation = {
        layers = {
            {
                filename = q .. "/graphics/entity/quantum-computer/quantum-computer.png",
                width = 1024,
                height = 1024,
                frame_count = 1,
                repeat_count = 16,
                scale = 0.35,
                shift = util.by_pixel(0, 0),
            },
            {
                filename = q .. "/graphics/entity/quantum-computer/quantum-computer_animation.png",
                width = 1024,
                height = 1024,
                frame_count = 16,
                line_length = 4,
                animation_speed = 1.0,
                scale = 0.35,
                shift = util.by_pixel(0, 0),
            },
        }
    },
    working_visualisations = {
        {
            always_draw = false,
            light = {
                type = "basic",
                intensity = 0.6,
                size = 12,
                color = {r = 1, g = 1, b = 1},
            },
        },
    },
}
data:extend({qc})

-- ============================================================
-- COMPUTER CORE — 5x5 tiles
-- Base: 512x512 | Animation: 3072x3072 (6x6 = 36 frames)
-- ============================================================

local cc_item = table.deepcopy(data.raw["item"]["assembling-machine-2"])
cc_item.name = "computer-core"
cc_item.icon = q .. "/graphics/entity/computer-core/computer-core.png"
cc_item.icon_size = 512
cc_item.place_result = "computer-core"
cc_item.subgroup = "production-machine"
cc_item.order = "c[computer-core]"
cc_item.stack_size = 20
data:extend({cc_item})

local cc = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
cc.name = "computer-core"
cc.icon = q .. "/graphics/entity/computer-core/computer-core.png"
cc.icon_size = 512
cc.minable = {mining_time = 0.3, result = "computer-core"}
cc.next_upgrade = nil
cc.collision_box = {{-2.3, -2.3}, {2.3, 2.3}}
cc.selection_box = {{-2.5, -2.5}, {2.5, 2.5}}
cc.damaged_trigger_effect = hit_effects.entity()
cc.crafting_speed = 2.0
cc.energy_source = {
    type = "electric",
    usage_priority = "secondary-input",
    emissions_per_minute = { pollution = 2 }
}
cc.energy_usage = "500kW"
cc.crafting_categories = {"crafting", "advanced-crafting"}
cc.module_specification = { module_slots = 2 }
cc.open_sound = sounds.machine_open
cc.close_sound = sounds.machine_close
cc.working_sound = {
    sound = {
        filename = "__base__/sound/assembling-machine-t2-1.ogg",
        volume = 0.4,
        audible_distance_modifier = 0.5,
    },
    fade_in_ticks = 4,
    fade_out_ticks = 20,
}
cc.graphics_set = {
    animation = {
        layers = {
            {
                filename = q .. "/graphics/entity/computer-core/computer-core.png",
                width = 512,
                height = 512,
                frame_count = 1,
                repeat_count = 36,
                scale = 0.35,
                shift = util.by_pixel(0, 0),
            },
            {
                filename = q .. "/graphics/entity/computer-core/computer-core_animation.png",
                width = 512,
                height = 512,
                frame_count = 36,
                line_length = 6,
                animation_speed = 1.0,
                scale = 0.35,
                shift = util.by_pixel(0, 0),
            },
        }
    },
    working_visualisations = {
        {
            always_draw = false,
            light = {
                type = "basic",
                intensity = 0.6,
                size = 10,
                color = {r = 1, g = 1, b = 1},
            },
        },
    },
}
data:extend({cc})