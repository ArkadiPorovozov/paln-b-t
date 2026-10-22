-- Атмосферные облака: статично стоящие simple-entity высоко над картой.
-- Белые висят над рудой q1, оранжевые — над рудой q2.
-- Слой "air-object" — выше зданий, дыма, снарядов и проводов.
--
-- Каждый файл в graphics/clouds — это одна анимация 8x8 кадров по 128x128
-- (облако "надувается"), поэтому файлы идут как варианты анимации,
-- а не как статичные картинки.
--
-- У каждого варианта два слоя: тень (draw_as_shadow) и само облако.

local q = "__paln-b-test__"

-- прозрачность самих облаков (1 = непрозрачные)
local cloud_alpha = 0.25
-- цветовой множитель: чем меньше, тем темнее облака
local cloud_tint = {r = 0.62, g = 0.62, b = 0.62}
-- плотность тени (обычный тёмный слой, а не draw_as_shadow)
local shadow_alpha = 0.45
-- насколько тень отодвинута от облака: чем дальше, тем выше висит облако
-- (у белых облаков высота больше, чем у жёлтых)
local heights = {
  white = {cloud = -3.5, shadow = 6.5},
  orange = {cloud = -2, shadow = 4},
}

local function animations(folder, height, alpha)
  local anims = {}
  for i = 1, 10 do
    local file = q .. "/graphics/clouds/" .. folder .. "/cloud_" .. folder .. "_"
      .. string.format("%02d", i) .. ".png"

    anims[#anims + 1] = {
      layers = {
        {
          filename = file,
          width = 128,
          height = 128,
          frame_count = 64,
          line_length = 8,
          lines_per_file = 8,
          -- 0.5: кадр 128 px -> 64 px -> 2 тайла
          scale = 0.5,
          -- 64 кадра по 0.4 = ~2.7 секунды на цикл
          animation_speed = 0.4,
          -- тень смещена вниз-вправо: облако висит высоко
          shift = {2, height.shadow},
          -- ВАЖНО: не draw_as_shadow. В режиме "скрыть высокие объекты"
          -- движок не рисует слой тени, и она бы пропадала.
          -- Обычный чёрный полупрозрачный слой гаснет вместе с облаком.
          tint = {r = 0, g = 0, b = 0, a = shadow_alpha},
          mipmaps = 4,
        },
        {
          filename = file,
          width = 128,
          height = 128,
          frame_count = 64,
          line_length = 8,
          lines_per_file = 8,
          scale = 0.5,
          animation_speed = 0.4,
          shift = {0, height.cloud},
          mipmaps = 4,
          tint = {r = cloud_tint.r, g = cloud_tint.g, b = cloud_tint.b, a = alpha},
        },
      },
    }
  end
  return anims
end

local function cloud(name, folder, order, alpha)
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
    animations = animations(folder, heights[folder], alpha),
  }
end

data:extend({
  cloud("q1-cloud-white", "white", 100, cloud_alpha),
  cloud("q2-cloud-orange", "orange", 101, cloud_alpha),
})
