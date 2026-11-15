-- Эффект пузырей (trivial-smoke) — «как дым/пар», из graphics/effects/blob.
--
-- Спрайт-листы: 10 файлов 512×512, каждый — сетка 8×8 (кадр 64×64, 64 кадра).
-- Движок не умеет выбирать случайный вариант внутри одного trivial-smoke,
-- поэтому здесь 10 отдельных прототипов bubble-single-01 … -10 (по одному
-- листу), а случайный выбор делается при спавне — см. script/bubbles.lua.
--
-- Спавн: local bubbles = require("script.bubbles")
--        bubbles.spawn(surface, position)

local q = "__paln-b-test__"
local VARIANTS = 10

local bubble_smokes = {}
for i = 1, VARIANTS do
  bubble_smokes[i] = {
    type = "trivial-smoke",
    name = string.format("bubble-single-%02d", i),
    -- Как у дыма/пара: живёт duration тиков, плавно появляется и пропадает.
    duration = 600,
    fade_in_duration = 30,
    fade_away_duration = 300,
    spread_duration = 600,
    start_scale = 0.6,
    end_scale = 1.0,
    -- Свои цвета спрайта сохраняем: белый непрозрачный множитель.
    color = {r = 1, g = 1, b = 1, a = 1},
    cyclic = true,
    affected_by_wind = false,
    render_layer = "smoke",
    animation = {
      filename = string.format(
        "%s/graphics/effects/blob/single_bubbles/bubble_single_bubbles_%02d.png", q, i),
      priority = "high",
      width = 64,        -- кадр 512 / 8
      height = 64,       -- кадр 512 / 8
      line_length = 8,   -- кадров в строке (512 / 64)
      frame_count = 64,  -- 8 × 8
      shift = {0, 0},
      animation_speed = 0.5,
      flags = {"smoke"},
    },
  }
end

data:extend(bubble_smokes)
