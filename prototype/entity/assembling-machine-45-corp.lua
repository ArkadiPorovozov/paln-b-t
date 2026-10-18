-- assembling-machine-45-corp
local C = require("prototype.entity.shared")
local q, a_speed = C.q, C.a_speed

local asm45_corp_it = table.deepcopy(data.raw["item"]["assembling-machine-3"])
asm45_corp_it.name = "assembling-machine-45-corp"
asm45_corp_it.icon = q .. "/graphics/entity/asm45_corp/asm45_corp.png"
asm45_corp_it.icon_size = 300
asm45_corp_it.place_result = asm45_corp_it.name
asm45_corp_it.subgroup = "space-platform"
data:extend({asm45_corp_it})

local asm45_corp = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
asm45_corp.name = asm45_corp_it.name
asm45_corp.icon = asm45_corp_it.icon
asm45_corp.icon_size = asm45_corp_it.icon_size
asm45_corp.minable = {mining_time = 1, result = asm45_corp_it.name}
asm45_corp.next_upgrade = nil
asm45_corp.collision_box = {{-1.8, -1.8}, {1.8, 1.8}}
asm45_corp.selection_box = {{-2, -2}, {2, 2}}
asm45_corp.crafting_speed = 1.25
asm45_corp.graphics_set = {
    animation = {
      layers = {
        {
          filename = q .. "/graphics/entity/asm45_corp/asm45_corp-anim.png",
          width = 140,
          height = 160,
          frame_count = 64,
          line_length = 8,
          lines_per_file = 8,
          animation_speed = a_speed,
          scale = 0.5,
          shift = util.by_pixel_hr(28, -50)
        },
        {
          filename = q .. "/graphics/entity/asm45_corp/asm45_corp-shadow.png",
          width = 300,
          height = 300,
          frame_count = 1,
          repeat_count = 64,
          scale = 0.5,
          shift = util.by_pixel_hr(40, 30),
          draw_as_shadow = true
        },
        {
          filename = q .. "/graphics/entity/asm45_corp/asm45_corp-base.png",
          width = 300,
          height = 300,
          frame_count = 1,
          repeat_count = 64,
          scale = 0.5,
          shift = util.by_pixel_hr(0, 0)
        },
      }
    }
  }
data:extend({asm45_corp})
