

require ("util")
local hit_effects = require("__base__.prototypes.entity.hit-effects")
local sounds = require("__base__.prototypes.entity.sounds")
local hit_effects = require("__base__.prototypes.entity.hit-effects")
local sounds = require("__base__.prototypes.entity.sounds")
local space_age_sounds = require ("__space-age__.prototypes.entity.sounds")
require ("prototype.graphics.optickabile")

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

--scrubber
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

local spase_asm2_it = table.deepcopy(data.raw["item"]["assembling-machine-3"])
spase_asm2_it.name = "assembling-machine-45"
spase_asm2_it.icon = "__cr-commons__/graphics/entity/assembler/icon.png"
spase_asm2_it.place_result = spase_asm2_it.name
spase_asm2_it.subgroup = "space-platform"
data:extend({spase_asm2_it})

local a = -8
local c = 2
local spase_asm2 = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
spase_asm2.name = spase_asm2_it.name
spase_asm2.graphics_set = {
  animation = {
      layers = {
        util.sprite_load("__base__/graphics/entity/assembling-machine-3/assembling-machine-3-base",
        {
          priority = "high",
          frame_count = 1,
          repeat_count = 64,
          scale = 0.5,
          shift = util.by_pixel(0 + c, a),
        }),
        util.sprite_load(q .. "/graphics/entity/assembling-machine-3-anim",
        {
          priority = "high",
          frame_count = 64,
          scale = 0.5,
          shift = util.by_pixel(0 + c, a),
        }),
        {
          filename = q .. "/graphics/entity/sa111.png",
          priority = "high",
          frame_count = 1,
          repeat_count = 64,
          scale = 0.5,
          width = 300,
          height = 300,
          draw_as_shadow = true,
          shift = util.by_pixel(10 + c,5 + a ),
        },
        {
          filename = q .. "/graphics/entity/sa1234.png",
          priority = "high",
          frame_count = 1,
          repeat_count = 64,
          scale = 0.5,
          width = 253,
          height = 275,
          shift = util.by_pixel(-7 + c,-3 + a),
        }
      }
    }
  }
spase_asm2.fluid_boxes = {{
  --pipe_covers = pipecoverspictures(),
  production_type = "input",
  volume = 200,
  pipe_connections = {
    { flow_direction = "input", direction = defines.direction.west,  position = { -1, 0 },connection_category = "cable"},
    { flow_direction = "input", direction = defines.direction.east,  position = { 1, 0 }, connection_category = "cable"},
    { flow_direction = "input", direction = defines.direction.north, position = { 0, -1 },connection_category = "cable"},
    { flow_direction = "input", direction = defines.direction.south, position = { 0, 1 }, connection_category = "cable"},
  },
  secondary_draw_orders = { north = -1, }
}}

data:extend({spase_asm2})

local ssc_turbine_it = table.deepcopy(data.raw["item"]["steam-turbine"])
ssc_turbine_it.name = "ssc-turbine"
ssc_turbine_it.icon = "__cr-commons__/graphics/entity/assembler/icon.png"
ssc_turbine_it.place_result = ssc_turbine_it.name
ssc_turbine_it.subgroup = "space-platform"
data:extend({ssc_turbine_it})


local ssc_turbine = {}
ssc_turbine.type = "generator"
ssc_turbine.name = ssc_turbine_it.name
ssc_turbine.icon = ssc_turbine_it.icon
ssc_turbine.minable = {mining_time = 0.4, result = ssc_turbine_it.name}
ssc_turbine.flags = {"placeable-neutral", "placeable-player", "player-creation"}
ssc_turbine.effectivity = 1
ssc_turbine.fluid_usage_per_tick = 1
ssc_turbine.maximum_temperature = 500
ssc_turbine.burns_fluid = false
ssc_turbine.resistances = {{ type = "fire", percent = 70 }}
ssc_turbine.collision_box = {{-1.75, -1.75}, {1.75, 1.75}}
ssc_turbine.selection_box = {{-1.8, -1.8}, {1.8, 1.8}}
ssc_turbine.damaged_trigger_effect = hit_effects.entity()
ssc_turbine.max_power_output = "5MW"
ssc_turbine.energy_source = { type = "electric", usage_priority = "secondary-output" }
ssc_turbine.fluid_box = {
  volume = 200,
  pipe_covers =  pipe_connectors,
  pipe_connections = {
        { direction = defines.direction.east,  position =  { 1.5, -1.5 },},
        { direction = defines.direction.west,  position =  { -1.5, 1.5 },},
        { direction = defines.direction.west,  position =  { -1.5, -1.5},},
        { direction = defines.direction.east,  position =  {  1.5, 1.5 },},
      },
  production_type = "input",
  filter = "steam",
  minimum_temperature = 100.0
}
ssc_turbine.two_direction_only = true
ssc_turbine.smoke =
    {
      {
        name = "turbine-smoke",
        north_position = {0.5, -1.0},
        east_position  = {0.5, -1.0},
        frequency = 10 / 32,
        starting_vertical_speed = 0.08,
        starting_frame_deviation = 60
      }
    }
ssc_turbine.open_sound = sounds.machine_open
ssc_turbine.close_sound = sounds.machine_close
ssc_turbine.working_sound = {
  sound =
  {
    filename = "__base__/sound/steam-turbine.ogg",
    volume = 0.49,
    modifiers = volume_multiplier("main-menu", 0.7),
    speed_smoothing_window_size = 60,
    advanced_volume_control = {attenuation = "exponential"},
    audible_distance_modifier = 0.8,
  },
  match_speed_to_activity = true,
  max_sounds_per_prototype = 3,
  fade_in_ticks = 4,
  fade_out_ticks = 20
  }
local turbine_animation = {
    layers = {
        {
          filename = q .. "/graphics/entity/sa-gen-1231.png",
          width = 349,
          height = 353,
          frame_count = 1,
          repeat_count = 32,
          line_length = 1,
          shift = util.by_pixel(0 ,-10),
          scale = 0.5
        },
        {
          filename = q .. "/graphics/entity/sa-gen123-s.png",
          width = 298,
          height = 303,
          frame_count = 1,
          repeat_count = 32,
          line_length = 1,
          draw_as_shadow = true,
          shift = util.by_pixel(40 ,10),
          scale = 0.5
        },
        util.sprite_load("__base__/graphics/entity/cargo-hubs/hubs/planet-hub-turbine",
        {
          priority = "high",
          frame_count = 32,
          scale = 0.5,
          shift = util.by_pixel(50, -67),
          animation_speed = 1.2
        }),
    }
}
--ssc_turbine.horizontal_animation = turbine_animation
--ssc_turbine.vertical_animation = turbine_animation
ssc_turbine.pictures = {
  north = {animation = turbine_animation},
  east  = {animation = turbine_animation},
}
ssc_turbine.perceived_performance = {minimum = 0.25, performance_to_activity_rate = 2.0}

data:extend({ssc_turbine})







function clone_entity(source_type, source_name, new_name, overrides, to_remove)
    local source = data.raw[source_type][source_name]
    if not source then return nil end

    local new_obj = table.deepcopy(source)
    new_obj.name = new_name


    if overrides then
        for key, value in pairs(overrides) do
            new_obj[key] = value
        end
    end


    local keys_to_kill = to_remove or { "surface_conditions", "surface_condition", "bound_decoratives" }
    for _, key in ipairs(keys_to_kill) do
        new_obj[key] = nil
    end

    return new_obj
end



local master_wall = clone_entity("wall", "snouz_wall_hull", "sheathing", {
    max_health = 500,
    place_result = "sheathing",
    minable = {mining_time = 0.2, result = "sheathing"},
})
if master_wall then data:extend({master_wall}) end

local master_wall_item = clone_entity("item", "snouz_wall_hull", "sheathing", {
    place_result = "sheathing",
    order = "vc[sheathing]",
    minable = {mining_time = 0.4, result = "sheathing"},
    stack_size = 100,

})
if master_wall_item then data:extend({master_wall_item}) end


local spase_ground_it = clone_entity("item", "space-platform-for-ground", "sheathing-ground", {
    subgroup = "space-platform",
    place_as_tile = {
      result = "sheathing-ground",
      condition_size = 1,
      condition = {layers={water_tile=true}}
    },
    order = "vc[sheathing-ground]",
})
if spase_ground_it then data:extend({spase_ground_it}) end


local spase_ground = clone_entity("tile", "space-platform-for-ground", "sheathing-ground",
    {
        layer_group = "ground",
        minable = {mining_time = 0.1, result = "sheathing-ground"},
    },
    {
        "surface_conditions",
        "surface_condition",
        "bound_decoratives"
    }
)

if spase_ground then
    spase_ground.layer = 100
    data:extend({spase_ground})
end

--data:extend({

--})


--cable


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








-- ==========================================================
-- ШАГ 1: Создаем новый тайл лавы на основе оригинальной
-- ==========================================================
local base_lava = data.raw["tile"]["lava"]
local empty_space = data.raw["tile"]["out-of-map"] or data.raw["tile"]["empty-space"]

if base_lava and empty_space then
    -- Делаем полную копию лавы
    local new_lava = table.deepcopy(base_lava)
    
    -- Задаем новое имя
    new_lava.name = "new-lava"
    
    -- Копируем маску коллизий пустоты (САМОЕ ГЛАВНОЕ ДЛЯ РАЗМЕЩЕНИЯ ОБШИВКИ)
    new_lava.collision_mask = table.deepcopy(empty_space.collision_mask)
    
    -- Делаем недобываемой и непроходимой (как пустота)
    new_lava.minable = nil
    new_lava.walkable = false
    
    -- Добавляем новый тайл в игру
    data:extend({new_lava})
end


-- ==========================================================
-- ШАГ 2: Учим обшивку рисоваться рядом с новой лавой
-- ==========================================================
local plating = data.raw["tile"]["space-platform-foundation"]

if plating and plating.transitions then
    for _, transition_group in pairs(plating.transitions) do
        if transition_group.to_tiles then
            -- Ищем переходы, которые обшивка делает к пустоте
            local is_void_transition = false
            for _, to_tile in ipairs(transition_group.to_tiles) do
                if to_tile == "out-of-map" or to_tile == "empty-space" then
                    is_void_transition = true
                    break
                end
            end
            
            -- Добавляем нашу лаву в этот же список переходов
            if is_void_transition then
                table.insert(transition_group.to_tiles, "new-lava")
            end
        end
    end
end


-- ==========================================================
-- ШАГ 3: Разрешаем класть обшивку на планетах (а не только в космосе)
-- ==========================================================
local plating_item = data.raw["item"]["space-platform-foundation"]
if plating_item then
    -- Удаляем ограничение на гравитацию/поверхность
    plating_item.surface_conditions = nil
end