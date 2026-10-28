-- =====================================================================
-- СТАРЫЙ ФАЙЛ. Механика нагрева/плавления на sun отключена, а её код лежит в
-- файлах *-old.lua (см. script/sun-cooling-old.lua). Этот файл, в отличие от
-- скрипта, ПРОДОЛЖАЕТ подключаться из data.lua: движок хранит в сейве имена
-- прототипов отрисовок, поэтому удалять сами прототипы (тип урона и анимации-
-- облака) нельзя — старые сейвы с уже нарисованными облаками иначе не
-- загрузятся. Сама по себе регистрация прототипов ничего не делает.
-- =====================================================================
--
-- Плавление и охлаждение на планете sun: тип урона и анимации-облака.
--
-- Тип урона нужен, чтобы время плавления не зависело от резистов зданий: у fire
-- и impact у части построек есть сопротивления, и «60 секунд» превращались бы в
-- разные числа для разных зданий. У sun-heat резистов ни у кого нет.
--
-- Урон наносит script/sun-cooling.lua:
--   entity.damage(entity.max_health * PASS_TICKS / (60 * MELT_SECONDS), ...)
-- то есть ровно 1/MELT_SECONDS максимального здоровья в секунду.
--
-- Сами облака — те же спрайты, что и у атмосферных облаков планеты
-- (graphics/clouds/orange и /white, см. prototype/entity/clouds.lua): 10
-- вариантов, в каждом файле лист 8x8 кадров по 128 px. Оранжевые — нагрев,
-- белые — охлаждение. Вариант для конкретного тайла выбирает скрипт
-- (animation_for в script/sun-cooling.lua), чтобы облака не были близнецами.
--
-- Отдельные прототипы нужны именно потому, что rendering.draw_animation
-- принимает имя AnimationPrototype, а не путь к файлу.

local q = "__paln-b-test__"

local FRAME = 128
local FRAMES = 64
local LINE_LENGTH = 8
-- Кадр 128 px: при отрисовке масштаб 0.5 (script/sun-cooling.lua) даёт 64 px =
-- 2 тайла. Скорость задаётся и здесь, и при отрисовке: второе значение
-- заменяет первое, а не перемножается. 0.8 кадра/тик — цикл ~80 тиков (1.3 с),
-- заметно бодрее прежних 0.3.
local ANIMATION_SPEED = 0.8

-- Сколько вариантов лежит в каждой папке graphics/clouds/<folder>.
local VARIANTS = 10

-- Один вариант облака. Имя базовое + номер.
local function cloud_animation(name, folder, index)
  return {
    type = "animation",
    name = name,
    filename = string.format("%s/graphics/clouds/%s/cloud_%s_%02d.png",
      q, folder, folder, index),
    width = FRAME,
    height = FRAME,
    frame_count = FRAMES,
    line_length = LINE_LENGTH,
    lines_per_file = LINE_LENGTH,
    animation_speed = ANIMATION_SPEED,
    mipmaps = 4,
  }
end

local function cloud_animations(base, folder)
  local out = {}
  for i = 1, VARIANTS do
    out[#out + 1] = cloud_animation(string.format("%s-%02d", base, i), folder, i)
  end
  -- Старое имя без номера: сейвы, где уже висели отрисовки с этим именем,
  -- должны грузиться (отрисовки сохраняются в сейв вместе с именем прототипа).
  -- Файл тот же, движок держит такую текстуру в памяти один раз.
  out[#out + 1] = cloud_animation(base, folder, 1)
  return out
end

data:extend({
  {
    type = "damage-type",
    name = "sun-heat",
  },
})

-- Оранжевое — нагрев, белое — охлаждение.
data:extend(cloud_animations("sun-melting-cloud", "orange"))
data:extend(cloud_animations("sun-cooling-cloud", "white"))
