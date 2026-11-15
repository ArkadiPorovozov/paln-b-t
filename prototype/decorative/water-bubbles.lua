-- Пузыри над тёмной водой dark-ocean — декорация «как дым от лавы на Вулкане».
--
-- Механизм тот же, что у ванильного vulcanus-lava-fire
-- (__space-age__/prototypes/decorative/decoratives-vulcanus.lua): декорация
-- optimized-decorative с пустой картинкой (scale 0) и stateless_visualisation,
-- у которой nested_visualisations с заданным периодом рождают частицы. Движок
-- сам проигрывает это без скриптов и таймеров — декорации получать скрипт не
-- умеют, а тикающие сущности здесь не нужны.
--
-- Где появляется: только на dark-ocean, по тёмной воде (тайл dark-deep-lake).
-- В прототипе autoplace выключен (paln_const_zero), иначе глобальная
-- декорация вылезла бы и на чужие планеты; реальную вероятность задаёт
-- prototype/planet/autoplace.lua через
-- property_expression_names["decorative:dark-water-bubbles:probability"].
--
-- Про «пузыри»: спрайт-листы те же, что у trivial-smoke bubble-single-01...10
-- (prototype/entity/bubbles.lua): 10 файлов 512x512, сетка 8x8 кадров 64x64.
-- В AnimationVariations можно перечислить все 10 сразу — движок сам выберет
-- случайный вариант для каждой частицы (у trivial-smoke так нельзя, поэтому там
-- 10 отдельных прототипов, а тут достаточно одного списка).
--
-- Слой отрисовки: вода dark-ocean — сущность dark-water-shader на слое
-- "light-effect" (см. prototype/dark-water.lua). Все пузыри (и обычные, и
-- быстрые) кладём НИЖЕ — на "smoke" (159): вода всегда поверх, порядок не
-- зависит от сортировки по y внутри крупной 16x16-сущности воды. Пузыри
-- читаются как всплывающие ИЗ ГЛУБИНЫ сквозь полупрозрачную воду (~0.53).
-- Быстрые пузыри, чтобы быть заметными под водой, рисуются светящимися
-- (draw_as_glow) и не гаснут в конце — см. вторую группу ниже.

local q = "__paln-b-test__"

local VARIANTS = 10

-- Один лист пузырей как анимация (кадр 64x64, 8x8 кадров, 64 кадра).
-- glow = true — аддитивная («светящаяся») отрисовка: пузырь заметно светлее и
-- ярче, что нужно быстрым пузырям, которые теперь тоже уходят ПОД воду.
local function bubble_sheet(i, glow)
  local sheet = {
    filename = string.format(
      "%s/graphics/effects/blob/single_bubbles/bubble_single_bubbles_%02d.png", q, i),
    priority = "high",
    width = 64,
    height = 64,
    line_length = 8,
    frame_count = 64,
    animation_speed = 0.5,
    shift = {0, 0},
    flags = {"smoke"},
  }
  if glow then
    sheet.draw_as_glow = true
  end
  return sheet
end

-- Все варианты: движок берёт случайный на каждую частицу.
local bubble_animations = {}
for i = 1, VARIANTS do
  bubble_animations[i] = bubble_sheet(i)
end

-- Светлая (аддитивная) версия — для «вырывающихся» пузырей.
local bright_bubble_animations = {}
for i = 1, VARIANTS do
  bright_bubble_animations[i] = bubble_sheet(i, true)
end

data:extend({
  {
    type = "optimized-decorative",
    name = "dark-water-bubbles",
    order = "b[effect]-l[bubbles]-a[dark-water]",
    collision_box = {{-1, -1}, {1, 1}},
    -- Только тайлы, и коллизия с наземными тайлами (ground_tile): декорация
    -- встаёт там, где земли НЕТ, то есть на воде. Ванильный vulcanus-lava-fire
    -- сделан так же (коллизия с ground_tile) и потому держится на лаве.
    collision_mask = {layers = {ground_tile = true}, colliding_with_tiles_only = true},
    -- Сама декорация невидима: картинка нулевого масштаба, рисуют только
    -- частицы stateless_visualisation. Спрайт — тот же пустышка-камень, что у
    -- ванильного lava-fire.
    pictures = {
      {
        filename = "__space-age__/graphics/decorative/tiny-volcanic-rock/tiny-volcanic-rock-01.png",
        priority = "extra-high",
        width = 29,
        height = 21,
        scale = 0.0,
        shift = {0, 0},
      },
    },
    autoplace = {
      order = "d[ground-surface]-l[water]",
      -- Реальную вероятность даёт только dark-ocean
      -- (prototype/planet/autoplace.lua). В прототипе — ноль.
      probability_expression = "paln_const_zero",
    },
    stateless_visualisation = {
      render_layer = "smoke",
      min_count = 1,
      max_count = 1,
      -- Постоянного визуала нет — только рождающиеся частицы-пузыри.
      nested_visualisations = {
        {
          -- Побольше пузырей за цикл (было 3).
          count = 6,
          period = 140,
          -- Рождение частиц разносено почти на весь период: каждый следующий
          -- пузырь стартует через period/count тиков, поэтому они всплывают
          -- вразнобой, а не одновременно. (Было 110/30 ≈ 3.7 тика — все три
          -- пузыря рождались почти разом.)
          particle_tick_offset = 140 / 6,
          probability = 0.9,
          -- Мельче: масштаб и пределы роста уменьшены (было 0.35..0.7,
          -- 0.4 -> 1.0).
          scale = {0.18, 0.42},
          begin_scale = 0.3,
          end_scale = 0.8,
          -- Разброс вокруг центра декорации.
          offset_x = {-0.3, 0.3},
          offset_y = {-0.3, 0.3},
          -- Плавный подъём вверх (z) и лёгкий снос в стороны. Скорость подъёма
          -- поднята, чтобы пузырь успевал уйти заметно выше, а затухание
          -- (movement_slowdown_factor_z) близко к 1 — ход ровный, без рывка.
          speed_x = {-1 / 240, 1 / 240},
          speed_y = {-1 / 240, 1 / 240},
          speed_z = 7 / 240,
          movement_slowdown_factor_z = 0.995,
          adjust_animation_speed_by_base_scale = false,
          -- Слой НИЖЕ воды: dark-water-shader рисуется на "light-effect" (162),
          -- а частицы — на "smoke" (159). Так вода всегда поверх пузырей,
          -- независимо от положения пузыря по высоте внутри 16x16-сущности воды.
          render_layer = "smoke",
          affected_by_wind = false,
          -- Появляется «из глубины»: долгий, плавный наплыв прозрачности —
          -- у самого старта пузырь почти невидим и лишь постепенно проявляется.
          fade_in_progress_duration = 0.45,
          fade_out_progress_duration = 0.35,
          animation = bubble_animations,
        },
        {
          -- «Вырывающиеся» пузыри: быстрее и выше обычных, но появляются
          -- ВРАЗНОБОЙ, а не разом — particle_tick_offset растягивает кучку на
          -- весь период. Размер небольшой, подъём плавный.
          -- Слой "smoke" — как у обычных, под водой. «Баг» убран: пузыри больше
          -- не пробивают поверхность через сортировку по y.
          min_count = 2,
          max_count = 4,
          period = 180,
          -- Рождаются по очереди через period/4 тиков, а не одновременно.
          particle_tick_offset = 180 / 4,
          probability = 0.9,
          -- Мельче обычных.
          scale = {0.15, 0.32},
          begin_scale = 0.3,
          end_scale = 0.8,
          offset_x = {-0.25, 0.25},
          offset_y = {-0.25, 0.25},
          speed_x = {-2 / 240, 2 / 240},
          speed_y = {-2 / 240, 2 / 240},
          -- Плавный подъём: скорость умеренная, затухание мягкое (ближе к 1).
          speed_z = 8 / 240,
          movement_slowdown_factor_z = 0.998,
          adjust_animation_speed_by_base_scale = false,
          render_layer = "smoke",
          affected_by_wind = false,
          -- Не гаснет в конце: пузырь остаётся светлым почти до исчезновения.
          fade_in_progress_duration = 0.45,
          fade_out_progress_duration = 0.05,
          -- Светящаяся версия спрайта: под тёмной водой читается ярко.
          animation = bright_bubble_animations,
        },
      },
    },
  },
})
