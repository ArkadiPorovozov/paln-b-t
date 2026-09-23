-- Анимация строительных лесов космической платформы.
-- Спрайты берутся НАПРЯМУЮ из Space Age (наш мод не таскает графику с собой).
-- Параметры кадров (width/height/shift/line_length) совпадают с helper-файлами SA,
-- структура таблиц — из мода Quezler "Space platform entity build animation lib" (MIT).
--
-- ВНИМАНИЕ: если после очередного обновления SA игра не найдёт PNG по этим путям,
-- поправь DIR ниже (точный путь виден в папке Factorio/data/space-age/graphics/...).

local DIR = "__space-age__/graphics/entity/space-platform-build-anim/"

local frame_count = 32
local scale = 0.5
local animation_speed = 0.5
local px = util.by_pixel

local function layer(name, width, height, shift, extra)
  local l = {
    filename = DIR .. name .. ".png",
    width = width,
    height = height,
    shift = shift,
    line_length = 8,
    frame_count = frame_count,
    scale = scale,
    animation_speed = animation_speed,
  }
  for k, v in pairs(extra or {}) do
    l[k] = v
  end
  return l
end

local animations = {
  back_left = {
    top = {
      layers = {
        layer("back-L-top", 76, 96, px(-3.0, -30.0)),
      },
    },
    body = {
      layers = {
        layer("back-L", 78, 146, px(-3.0, -17.5)),
        layer("back-L-shadow", 188, 84, px(28.5, 0.5), {draw_as_shadow = true}),
      },
    },
  },
  back_right = {
    top = {
      layers = {
        layer("back-R-top", 78, 96, px(3.0, -30.0)),
      },
    },
    body = {
      layers = {
        layer("back-R", 78, 146, px(3.0, -17.5)),
        layer("back-R-shadow", 174, 84, px(26.0, 0.5), {draw_as_shadow = true}),
      },
    },
  },
  front_left = {
    top = {
      layers = {
        layer("front-L-top", 76, 108, px(-3.0, -31.5)),
      },
    },
    body = {
      layers = {
        layer("front-L", 78, 164, px(-3.0, -18.0)),
        layer("front-L-shadow", 176, 88, px(25.5, 1.0), {draw_as_shadow = true}),
      },
    },
  },
  front_right = {
    top = {
      layers = {
        layer("front-R-top", 78, 108, px(3.0, -31.5)),
      },
    },
    body = {
      layers = {
        layer("front-R", 78, 164, px(3.0, -17.5)),
        layer("front-R-shadow", 172, 88, px(25.5, 1.0), {draw_as_shadow = true}),
      },
    },
  },
}

return animations
