-- industrial-assembler — большой промышленный сборщик 4×4.
--
-- Картинка собрана из двух источников:
--   * graphics/entity/1123123.png — собственная база (тёмный колодец с трубами);
--   * ванильные кадры ракетной шахты, на которых сваривается ракета:
--     __base__/graphics/entity/rocket-silo/crafting.png (сама сборка),
--     .../crafting-light.png (свечение сборки, additive, только при работе).
-- Пар (steam-2.png) не используется.
-- Сдвиги и нарезка кадров подобраны под базу; менять их лучше вместе с картинкой.
--
-- Иконка предмета — industrial-assembler-icon.png: та же база с одним кадром
-- сборки, собранная в C:\Users\eblan\AppData\Local\Temp\opencode\make-industrial-assembler-icon.py.

local C = require("prototype.entity.shared")
local q = C.q

local NAME = "industrial-assembler"
local ICON = q .. "/graphics/entity/industrial-assembler-icon.png"

-- Общий сдвиг всей картинки относительно центра клетки: +X вправо, -Y вверх.
-- Значения в «высоких» пикселях (64 = 1 тайл), как у by_pixel_hr.
-- Правишь тут — двигается разом база, ракета, свет и пар.
local SHIFT_X, SHIFT_Y = 4, -16

-- Масштаб всей картинки. 0.5 — ванильный размер спрайтов; меньше — машина
-- визуально мельче, но клетки 4×4 не меняются.
local SCALE = 0.44

local function offs(x, y)
  return util.by_pixel_hr(x + SHIFT_X, y + SHIFT_Y)
end

-- =====================================================================
-- Предмет
-- =====================================================================

local item = table.deepcopy(data.raw["item"]["assembling-machine-3"])
item.name = NAME
item.icon = ICON
item.icon_size = 310
item.place_result = NAME
item.subgroup = "production-machine"
item.order = "c[assembling-machine-3]-a[industrial-assembler]"
item.stack_size = 20
data:extend({item})

-- =====================================================================
-- Постройка
-- =====================================================================

local entity = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
entity.name = NAME
entity.icon = ICON
entity.icon_size = 310
entity.minable = {mining_time = 1, result = NAME}
entity.max_health = 1000
-- Завод крупнее assembling-machine-3, поэтому и корпус, и рамка 4×4.
entity.collision_box = {{-1.9, -1.9}, {1.9, 1.9}}
entity.selection_box = {{-2, -2}, {2, 2}}
-- Пар из верхней части уходит выше клетки постройки — не обрезаем его.
entity.drawing_box_vertical_extension = 0.5
entity.crafting_speed = 2.5
entity.energy_usage = "750kW"
entity.module_slots = 4
-- Своя группа: 3×3 ассемблер не должен случайно «улучшаться» в 4×4 поверх
-- соседних построек.
entity.fast_replaceable_group = nil
entity.next_upgrade = nil
-- Остатки от 3×3 смотрелись бы меньше самой постройки.
entity.corpse = nil

-- Патрубки: у assembling-machine-3 они стоят в {0,±1} на корпусе 3×3, здесь
-- корпус 4×4 — отодвигаем к краям (1.9 - 0.2, как у ванильной машины).
entity.fluid_boxes = {
  {
    production_type = "input",
    pipe_covers = pipecoverspictures(),
    volume = 2000,
    pipe_connections = {
      {flow_direction = "input", direction = defines.direction.north, position = {0, -1.7}},
    },
    secondary_draw_orders = {north = -1},
  },
  {
    production_type = "output",
    pipe_covers = pipecoverspictures(),
    volume = 2000,
    pipe_connections = {
      {flow_direction = "output", direction = defines.direction.south, position = {0, 1.7}},
    },
    secondary_draw_orders = {north = -1},
  },
}
entity.fluid_boxes_off_when_no_fluid_recipe = true

entity.graphics_set = {
  -- База и сварка ракеты видны всегда.
  animation = {
    layers = {
      {
        animation_speed = 0.5,
        scale = SCALE,
        filenames = {
          q .. "/graphics/entity/1123123.png",
        },
        blend_mode = "normal",
        width = 310,
        height = 310,
        line_length = 1,
        lines_per_file = 1,
        frame_count = 1,
        repeat_count = 64,
        shift = offs(0, 0),
        tint = {r = 1, g = 1, b = 1, a = 1},
      },
      {
        animation_speed = 0.5,
        scale = SCALE,
        filenames = {
          "__base__/graphics/entity/rocket-silo/crafting.png",
        },
        blend_mode = "normal",
        width = 208,
        height = 210,
        line_length = 6,
        lines_per_file = 11,
        frame_count = 64,
        shift = offs(22, -2),
        tint = {r = 1, g = 1, b = 1, a = 1},
      },
    },
  },
  -- Свечение сварки — только пока машина работает: в простое и в предмете
  -- его не видно. Пар (steam-2) убран совсем.
  working_visualisations = {
    {
      animation = {
        animation_speed = 0.5,
        scale = SCALE,
        filenames = {
          "__base__/graphics/entity/rocket-silo/crafting-light.png",
        },
        blend_mode = "additive",
        width = 208,
        height = 212,
        line_length = 6,
        lines_per_file = 11,
        frame_count = 64,
        shift = offs(17, -2),
        tint = {r = 1, g = 1, b = 1, a = 1},
        draw_as_glow = true,
      },
    },
  },
}

data:extend({entity})
