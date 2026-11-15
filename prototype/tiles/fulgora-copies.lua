local shared = require("prototype.tiles.shared")
local graphics = shared.graphics
local texture = shared.texture

-- Копии наземных тайлов Фулгоры: тёмный и светлый вариант.
--
-- Песок и камень рисуют поверхность как material_background: один лист кадров,
-- который игра «настилает» по миру. Поэтому вариант — это заранее затемнённая
-- (×0.55) или отбелённая (28 % белого) копия листа в graphics/terrain; маски и
-- звуки остаются ванильные, меняется только яркость поверхности.
--
-- Переходы к другим тайлам (берега к «воде» и краю карты) — отдельные готовые
-- картинки, поэтому для них тоже сделаны перекрашенные копии: иначе у тёмного
-- песка оставался бы светлый берег от оригинала.
--
-- ОТКЛЮЧЕНО: копии больше не создаются (текстуры и код оставлены, чтобы вернуть).
local enable_ground_copies = false

local ground_copies = {
  {
    source = "fulgoran-sand",
    variants = {
      {suffix = "dark", picture = texture("fulgoran-sand-dark.png"), factor = 0.55},
      {suffix = "light", picture = texture("fulgoran-sand-light.png"), factor = 1.2}
    }
  },
  {
    source = "fulgoran-rock",
    variants = {
      {suffix = "dark", picture = texture("fulgoran-rock-dark.png"), factor = 0.55},
      {suffix = "light", picture = texture("fulgoran-rock-light.png"), factor = 1.2}
    }
  }
}

-- ванильный берег -> имя нашей копии в graphics/terrain/fulgora-copies
local transition_copies = {
  ["__space-age__/graphics/terrain/water-transitions/fulgora-rock-slab-transition.png"] =
    "fulgora-rock-slab-transition",
  ["__space-age__/graphics/terrain/water-transitions/fulgora-sand-transition.png"] =
    "fulgora-sand-transition",
  ["__space-age__/graphics/terrain/out-of-map-transition/fulgora-out-of-map-transition.png"] =
    "fulgora-out-of-map-transition",
  ["__space-age__/graphics/terrain/out-of-map-transition/fulgora-out-of-map-transition-b.png"] =
    "fulgora-out-of-map-transition-b",
  ["__space-age__/graphics/terrain/out-of-map-transition/fulgora-shore-out-of-map-transition.png"] =
    "fulgora-shore-out-of-map-transition"
}

-- Списки переходов — общий объект у нескольких тайлов, поэтому копируем список
-- и подменяем в нём только сам берег (spritesheet). Маски (mask_layout,
-- effect_map_layout, background_mask_layout) остаются ванильные: они задают
-- форму перехода, а не цвет.
--
-- В самих картинках-копиях перекрашены только цветные пиксели берега;
-- белое/чёрное/серое (маски, пена, тени) и альфа остались бит в бит — иначе
-- маска превращается в серую «пелену».
local function recolor_transitions(list, suffix)
  if not list then return nil end
  local copy = table.deepcopy(list)
  for _, transition in ipairs(copy) do
    local base = transition_copies[transition.spritesheet]
    if base then
      transition.spritesheet =
        graphics .. "fulgora-copies/" .. base .. "-" .. suffix .. ".png"
    end
  end
  return copy
end

-- map_color в прототипах бывает и массивом {r, g, b}, и таблицей {r=, g=, b=}
local function scale_color(color, factor)
  if not color then return nil end
  local function scale(value)
    return math.min(255, math.floor((value or 0) * factor + 0.5))
  end
  if color.r or color.g or color.b then
    return {r = scale(color.r), g = scale(color.g), b = scale(color.b), a = color.a}
  end
  return {scale(color[1]), scale(color[2]), scale(color[3])}
end

if enable_ground_copies then
  for _, def in ipairs(ground_copies) do
    local source = data.raw["tile"][def.source]
    if source then
      for _, variant in ipairs(def.variants) do
        local tile = table.deepcopy(source)
        local name = def.source .. "-" .. variant.suffix

        tile.name = name
        tile.localised_name = {"tile-name." .. name}
        tile.order = source.order .. "-" .. variant.suffix
        tile.variants.material_background.picture = variant.picture
        tile.map_color = scale_color(source.map_color, variant.factor)
        -- берега к другим тайлам — тоже в тон варианта
        tile.transitions = recolor_transitions(source.transitions, variant.suffix)
        tile.transitions_between_transitions =
          recolor_transitions(source.transitions_between_transitions, variant.suffix)
        -- отдельный тайл, а не замена: на карте сам не появляется
        tile.autoplace = nil

        data:extend({tile})
      end
    else
      log("[paln-b-test] prototype/tiles/fulgora-copies.lua: не найден исходный тайл " .. def.source)
    end
  end
end
