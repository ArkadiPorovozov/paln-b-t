-- Хелпер для эффекта пузырей: спавнит случайный из 10 вариантов.
--
-- Прототипы bubble-single-01 … -10 объявлены в prototype/entity/bubbles.lua.
-- В одном trivial-smoke движок не умеет случайные варианты, поэтому выбор
-- делается здесь, при спавне.
--
-- Использование:
--   local bubbles = require("script.bubbles")
--   bubbles.spawn(surface, position)                 -- случайный вариант
--   bubbles.spawn(surface, position, {speed = {0, -0.1}})

local bubbles = {}

local VARIANTS = 10

-- Имя случайного варианта, например "bubble-single-07".
function bubbles.random_name()
  return string.format("bubble-single-%02d", math.random(VARIANTS))
end

-- surface: LuaSurface, position: MapPosition.
-- extra: необязательные поля для create_trivial_smoke (speed, vertical_speed,
--        starting_frame и т.п.).
function bubbles.spawn(surface, position, extra)
  if not surface or not surface.valid or not position then return end

  local smoke = {
    name = bubbles.random_name(),
    position = position,
  }
  if extra then
    for key, value in pairs(extra) do
      smoke[key] = value
    end
  end

  surface.create_trivial_smoke(smoke)
end

return bubbles
