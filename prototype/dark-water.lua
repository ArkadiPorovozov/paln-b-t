-- Полупрозрачная тёмная вода: большой анимированный слой «как в maraxsis».
--
-- Сейчас это рабочий ассет планеты dark-ocean (prototype/planet/gen-dark-ocean.lua):
-- script/planet/dark-ocean.lua ставит по одной сущности dark-water-shader в каждую
-- клетку 16×16 тайлов, то есть 4 штуки на чанк 32×32.
--
-- Что внутри:
--   * dark-water          — type = "animation", 64 кадра 256x256. Годится и для
--                           rendering.draw_animation, если нужен эффект без
--                           сущностей (но отрисовки не сохраняются в сейве).
--   * dark-water-shader   — simple-entity 16x16 тайлов: одна штука на клетку
--                           16x16, как maraxsis-water-shader в моде maraxsis
--                           (там сущность 32x32, то есть ровно на чанк).
--                           Невидима для мыши, не имеет коллизии, не ломается,
--                           не мешает строить и не попадает на карту.
--                           Рисует один слой — саму воду. Тень (второй
--                           чёрный слой-маска волн) сейчас ОТКЛЮЧЕНА, см.
--                           `animations` в конце прототипа.

local q = "__paln-b-test__"
local WATER_SHEET = q .. "/graphics/tile/water/dark-water-combined.png"
-- Текстура-маска тени: чёрная (RGB=0), альфа = рисунок волн. У самой воды
-- альфа постоянная, поэтому её копия дала бы ровную заливку, а не тень.
local SHADOW_SHEET = q .. "/graphics/tile/water/dark-water-shadow.png"

-- Размер одной сущности в тайлах. Поменяй на 32 — получится ровно как в
-- maraxsis: одна сущность на чанк. Скрипт (script/planet/dark-ocean.lua) считает
-- количество клеток на чанк сам, так что менять нужно только это число.
local TILES = 16
-- 256 px * scale 2 = 512 px = 16 тайлов (32 px на тайл). Масштаб выводится из
-- TILES, чтобы картинка всегда ложилась ровно на клетку.
local FRAME_SIZE = 256
-- Лист взят у maraxsis (graphics/tile/water/water-combined.png): 32 кадра
-- 256x256. Чтобы анимация была плавнее, кадры удвоены интерполяцией соседних
-- (с замыканием цикла), итого 64 кадра, два ряда -> 8192x512. Контраст волн
-- приподнят, а вода сильно затемнена. Прежняя наша текстура лежит рядом как
-- dark-water-combined-old.png; версии с прежней альфой: -old2/-old4/-old5 — 0.53,
-- -old3 — 0.40. Текущая альфа — 0.53 (тёмная вода).
-- Альфу можно пересчитать заново: C:\Users\eblan\AppData\Local\Temp\opencode\make-water-alpha.ps1
local FRAME_COUNT = 64
local LINE_LENGTH = 32 -- 32 кадра в ряд, два ряда -> лист 8192x512
local TILE_SCALE = TILES * 32 / FRAME_SIZE
-- Цикл держим как раньше: 64 кадра / 0.2 = 320 тиков. Кадров вдвое больше,
-- чем у maraxsis, поэтому движение получается мягче, без «кипения».
local ANIMATION_SPEED = 0.2

-- ВКЛЮЧЕНА: слой тени подключён в animations (см. конец прототипа) —
-- { shadow_layer, animation }. Это те самые «маленькие волны» на тайле.
--
-- Тень под водой — как у облаков в prototype/entity/clouds.lua: это НЕ
-- draw_as_shadow, а обычный второй слой, залитый чёрным и сдвинутый. Так тень
-- не зависит от shadow_opacity поверхности и не добавляет теней сверх обычных
-- теней построек. Слой рисуется ПЕРВЫМ (под водой), а полупрозрачная вода
-- (~0.53) ложится поверх — рисунок виден сквозь неё как тень на дне.
-- Альфа берётся из отдельной маски (dark-water-shadow.png): у воды альфа
-- постоянная, её копия дала бы ровную заливку.
-- Волны приглушены: раньше было 0.5 (слишком заметно), сейчас 0.25. Крутилка:
-- 0 — волн нет, 0.5 — как было изначально. Можно также уменьшить SHADOW_SHIFT,
-- тогда рябь станет мельче (0.2 — очень тонкая).
local SHADOW_ALPHA = 0.25 -- tint.a, домножается на альфу маски
local SHADOW_SHIFT = {0.4, 0.4} -- в тайлах, вниз-вправо (1 тайл = 32 px)

local animation = {
  filename = WATER_SHEET,
  width = FRAME_SIZE,
  height = FRAME_SIZE,
  frame_count = FRAME_COUNT,
  line_length = LINE_LENGTH,
  scale = TILE_SCALE,
  animation_speed = ANIMATION_SPEED,
  -- Прозрачность вшита в PNG (постоянная альфа ~0.53), поэтому тут tint не
  -- нужен. Если надо приглушить/подкрасить снаружи — tint = {r, g, b, a}, где
  -- a домножается на альфу текстуры.
}

-- Слой-тень: чёрная маска волн, сдвинутая вниз-вправо.
local shadow_layer = {
  filename = SHADOW_SHEET,
  width = FRAME_SIZE,
  height = FRAME_SIZE,
  frame_count = FRAME_COUNT,
  line_length = LINE_LENGTH,
  scale = TILE_SCALE,
  animation_speed = ANIMATION_SPEED,
  shift = SHADOW_SHIFT,
  tint = {r = 0, g = 0, b = 0, a = SHADOW_ALPHA},
}

data:extend({
  {
    type = "animation",
    name = "dark-water",
    filename = WATER_SHEET,
    width = FRAME_SIZE,
    height = FRAME_SIZE,
    frame_count = FRAME_COUNT,
    line_length = LINE_LENGTH,
    scale = TILE_SCALE,
    animation_speed = ANIMATION_SPEED,
  },
  {
    type = "simple-entity",
    name = "dark-water-shader",
    localised_name = "Dark water shader",
    flags = {"not-on-map", "not-blueprintable", "not-rotatable"},
    collision_box = {{-TILES / 2, -TILES / 2}, {TILES / 2, TILES / 2}},
    collision_mask = {layers = {}},
    -- Вода — ПОВЕРХ построек и вообще всего наземного И воздушного,
    -- включая летающих роботов (строительных, логистических, боевых).
    --
    -- Числовые значения слоёв RenderLayer (higher = выше):
    --   ... 92 "decorative" → 103 "floor" → 104 "transport-belt" →
    --   109 "item" → 124 "object" (почти все постройки, техника, рельсы) →
    --   125 "cargo-hatch" → 126 "higher-object-under" →
    --   127 "higher-object-above" →
    --   ... 154 "explosion" → 158 "projectile" → 159 "smoke" →
    --   160 "air-object" (тут летающие роботы) →
    --   161 "air-entity-info-icon" → 162 "light-effect" (берём его) →
    --   ... 187 "selection-box" (UI: рамки выделения, курсор).
    --
    -- Раньше брали "higher-object-above" (127) — над постройками. Но движок
    -- рисует летающих роботов на "air-object" (160)
    -- (см. RoboportPrototype::stationing_render_layer_swap_height: робот в
    -- воздухе на "air-object", при посадке/стоянке временно уходит на
    -- "object"). Чтобы вода была и над роботами, берём "light-effect" (162):
    -- выше роботов и их иконок, но ниже UI выделения и курсора.
    --
    -- Слой задаёт только порядок; режим смешивания берётся из спрайта
    -- (draw_as_glow/draw_as_light). Наша вода их не использует, поэтому
    -- рисуется обычным альфа-блендом, как и раньше.
    render_layer = "light-effect",
    -- Все пузыри (dark-water-bubbles) лежат на более низком слое "smoke",
    -- поэтому вода рисуется поверх них уже по слою; secondary_draw_order с ними
    -- не связан. Значение -1 — как было изначально.
    secondary_draw_order = -1,
    selectable_in_game = false,
    hidden = true,
    protected_from_tile_building = false,
    remove_decoratives = "false",
    count_as_rock_for_filtered_deconstruction = false,
    -- Вода должна идти в одной фазе во всех 16x16 клетках, иначе рисунок волн
    -- рвётся на стыках.
    random_animation_offset = false,
    -- Два слоя: сначала тень волн (чёрная маска), затем сама вода. Это те
    -- самые «маленькие волны» на тайле тёмной воды — сдвинутая вниз-вправо
    -- маска читается как рябь. Чтобы убрать — оставь только { animation }.
    animations = { layers = { shadow_layer, animation } },
  },
})

-- Как это используется: script/planet/dark-ocean.lua на on_chunk_generated ставит
-- TILES-клетки на каждый чанк поверхности dark-ocean. Если сущность нужно
-- ставить на другой поверхности — это одна константа SURFACE там.
