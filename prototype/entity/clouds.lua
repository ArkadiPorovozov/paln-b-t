-- Атмосферные облака: статично стоящие simple-entity высоко над картой.
-- Белые висят над рудой q1, оранжевые — над рудой q2.
-- Слой "air-object" — выше зданий, дыма, снарядов и проводов.
--
-- Каждый файл в graphics/clouds — это одна анимация 8x8 кадров по 128x128
-- (облако "надувается"), поэтому файлы идут как варианты анимации,
-- а не как статичные картинки.
--
-- У каждого варианта есть тень (обычный тёмный слой) и само облако.

local q = "__paln-b-test__"

-- Масштаб облака: 0.6 = ~2.4 тайла (кадр 128 px -> ~77 px). В data-final-fixes.lua
-- autoplace ставит облака ровно на тайлы ресурсов (та же probability_expression,
-- плотность 1:1), поэтому на плотных пятнах облака накладываются друг на друга.
local cloud_scale = 1
-- прозрачность самих облаков (1 = непрозрачные).
-- tint.a умножается на альфу самой текстуры (у облаков средняя ~0.34).
-- ВНИМАНИЕ: наложения складывают альфу, а не берут максимум:
--   итог = 1 - (1 - a)^N   (N — сколько облаков легло на пиксель),
-- поэтому большая alpha даёт «пересвет» до 100% в плотных пятнах.
-- Текущее значение 0.00005 — облака практически невидимы (тест/отладка).
-- ВАЖНО: прототипы читаются только при запуске игры. Правка этого числа
-- подействует, лишь если ПОЛНОСТЬЮ закрыть и снова открыть Factorio —
-- перезагрузка сейва не помогает.
local cloud_alpha = 0.005
-- цветовой множитель: чем меньше, тем темнее облака.
-- 1 = цвет текстуры как есть; 0.62 — старый приглушённо-тёмный вид.
local cloud_tint = {r = 0.12, g = 0.12, b = 0.12}
-- плотность тени (обычный тёмный слой, а не draw_as_shadow)
local shadow_alpha = 0.15
-- насколько тень отодвинута от облака: чем дальше, тем выше висит облако
-- (у белых облаков высота больше, чем у жёлтых)
local heights = {
  white = {cloud = -3.5, shadow = 6.5},
  orange = {cloud = -2, shadow = 4},
}

local function animations(folder, height, alpha, tint, shadow_alpha, shadow_x)
  local anims = {}
  for i = 1, 10 do
    local file = q .. "/graphics/clouds/" .. folder .. "/cloud_" .. folder .. "_"
      .. string.format("%02d", i) .. ".png"

    -- тень (рисуется первой, под облаком)
    local layers = {
      {
        filename = file,
        width = 128,
        height = 128,
        frame_count = 64,
        line_length = 8,
        lines_per_file = 8,
        -- cloud_scale 0.6: кадр 128 px -> ~77 px -> ~2.4 тайла
        scale = cloud_scale,
        -- 64 кадра по 0.4 = ~2.7 секунды на цикл
        animation_speed = 0.4,
        -- тень смещена вниз-вправо: облако висит высоко
        shift = {shadow_x or 2, height.shadow},
        -- ВАЖНО: не draw_as_shadow. В режиме "скрыть высокие объекты"
        -- движок не рисует слой тени, и она бы пропадала.
        -- Обычный чёрный полупрозрачный слой гаснет вместе с облаком.
        tint = {r = 0, g = 0, b = 0, a = shadow_alpha},
        mipmaps = 4,
      },
    }

    -- само облако
    layers[#layers + 1] = {
      filename = file,
      width = 128,
      height = 128,
      frame_count = 64,
      line_length = 8,
      lines_per_file = 8,
      scale = cloud_scale,
      animation_speed = 0.4,
      shift = {0, height.cloud},
      mipmaps = 4,
      tint = {r = tint.r, g = tint.g, b = tint.b, a = alpha},
    }

    anims[#anims + 1] = { layers = layers }
  end
  return anims
end

-- opts: { alpha, tint, shadow_alpha, height, shadow_x } —
-- цвет/прозрачность/высота конкретного облака.
local function cloud(name, folder, order, opts)
  opts = opts or {}
  return {
    type = "simple-entity",
    name = name,
    icon = "__core__/graphics/empty.png",
    icon_size = 64,
    flags = {"placeable-neutral", "not-on-map", "not-deconstructable", "not-blueprintable", "hide-alt-info"},
    hidden_in_factoriopedia = true,
    selectable_in_game = false,
    -- движок сам делает облака полупрозрачными, когда включено "скрыть высокие объекты"
    tall = true,
    render_layer = "air-object",
    secondary_draw_order = order,

    collision_mask = {layers = {}},
    collision_box = {{-0.01, -0.01}, {0.01, 0.01}},
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},

    max_health = 100000,
    create_ghost_on_death = false,
    resistances = {
      {type = "physical", percent = 100},
      {type = "impact", percent = 100},
      {type = "explosion", percent = 100},
      {type = "fire", percent = 100},
      {type = "acid", percent = 100},
      {type = "electric", percent = 100},
      {type = "laser", percent = 100},
      {type = "poison", percent = 100},
    },

    -- каждый вариант анимации играется со своего кадра — облака не синхронны
    random_animation_offset = true,
    random_variation_on_create = true,
    animations = animations(
      folder,
      opts.height or heights[folder],
      opts.alpha or cloud_alpha,
      opts.tint or cloud_tint,
      opts.shadow_alpha or shadow_alpha,
      opts.shadow_x
    ),
  }
end

data:extend({
  -- Шаблоны облаков и совместимость со старыми сейвами. Новые облака над
  -- ресурсами создаются в data-final-fixes.lua как копии этих прототипов
  -- и получают autoplace.
  cloud("q1-cloud-white", "white", 100),
  cloud("q2-cloud-orange", "orange", 101),

  -- Атмосферные облака: скрипт их не ставит (см. script/clouds.lua).
  -- Прототипы оставлены для старых сейвов и ручной установки.
  --
  -- Чёрное: у самой земли; тень по силе как у остальных облаков, но смещена
  -- в противоположную сторону (влево).
  cloud("q-cloud-black", "white", 102, {
    height = {cloud = -0.9, shadow = 0.6},
    shadow_x = -0.6,
    alpha = 0.5,
    tint = {r = 0.03, g = 0.03, b = 0.03},
    shadow_alpha = 0.25,
  }),
})
