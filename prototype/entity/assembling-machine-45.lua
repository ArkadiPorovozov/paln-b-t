-- assembling-machine-45
local C = require("prototype.entity.shared")
local q = C.q

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
