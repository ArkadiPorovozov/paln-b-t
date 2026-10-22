-- Белые «водные» тайлы — копии ванильных тайлов с осветлёнными текстурами:
--   * white-lava            — копия глубокой лавы Вулкана (tile "lava-hot", tile-effect "lava");
--   * white-oil-ocean-deep  — копия глубокого нефтяного океана Фулгоры ("oil-ocean-deep");
--   * white-oil-ocean-deep-2 — его второй вариант ("oil-ocean-deep-2").
--
-- Плюс копии наземных тайлов Фулгоры в двух вариантах — тёмном и светлом:
--   * fulgoran-sand-dark / -light,
--   * fulgoran-rock-dark / -light.
--
-- Цвет воды на «водных» тайлах задаёт не только effect_color, но и сами текстуры:
--   * <тайл>.png        — поверхность тайла (variants),
--   * <тайл>-shader.png — текстура поверхности для шейдера (tile-effect.image_textures[1]).
-- Их копии лежат в graphics/terrain: родной рисунок сохраняется один в один,
-- убрана только темнота (переведено в серый и поднята яркость).
-- Шум (lava-noise-*.png, oilNoise.png, oilGradient.png) берётся ОРИГИНАЛЬНЫЙ
-- из Space Age — это и есть «живая» анимация поверхности.
--
-- Но цвет задают не только текстуры: шейдер лавы по берегу подмешивает
-- зашитый тёплый цвет — у белой лавы он убирается порогами (см. ниже).
--
-- Яркость нефти: у первого тайла множитель 0.125, у второго 0.25,
-- то есть первый ровно в 2 раза темнее второго (и по поверхности, и по шейдеру).

local graphics = "__paln-b-test__/graphics/terrain/"
local texture = function(name) return graphics .. name end

-- Отдельная подгруппа тайлов в самом верху списка
-- (в группе "tiles" первая подгруппа — "artificial-tiles" с order = "a")
data:extend({
  {
    type = "item-subgroup",
    name = "white-tiles",
    group = "tiles",
    order = "0"
  }
})

-- source_surface — путь текстуры поверхности в исходном тайле, его и подменяем.
local white_tiles = {
  {
    name = "white-lava",
    source = "lava-hot",
    source_effect = "lava",
    effect = "white-lava",
    order = "a[lava]",
    source_surface = "__space-age__/graphics/terrain/vulcanus/lava-hot.png",
    surface = texture("white-lava.png"),
    shader_texture = texture("white-lava-shader.png"),
    effect_color = {235, 238, 243},
    map_color = {240, 244, 250},
    -- Шейдер лавы подмешивает по берегу ЗАШИТЫЙ тёплый цвет
    -- (tiles-lava-effect.frag): от dark_threshold идёт (1, 0.5, 0),
    -- от specular_threshold — (1, 0.5, 0). Из-за этого вокруг белой лавы
    -- остаётся оранжевая кромка. Оба порога в 0 её убирают.
    effect_patch = function(water)
      water.dark_threshold = {0, 0}
      water.specular_threshold = {0, 0}
    end
  },
  {
    name = "white-oil-ocean-deep",
    source = "oil-ocean-deep",
    source_effect = "oil-deep",
    effect = "white-oil-deep",
    order = "a[oil]-b[deep]",
    source_surface = "__space-age__/graphics/terrain/oil-ocean-deep.png",
    surface = texture("white-oil-ocean-deep-1.png"),
    shader_texture = texture("white-oil-ocean-deep-1-shader.png"),
    effect_color = {104, 106, 110},
    map_color = {112, 115, 120}
  },
  {
    name = "white-oil-ocean-deep-2",
    source = "oil-ocean-deep-2",
    source_effect = "oil-deep",
    effect = "white-oil-deep-2",
    order = "a[oil]-b[deep]",
    source_surface = "__space-age__/graphics/terrain/oil-ocean-deep.png",
    surface = texture("white-oil-ocean-deep-2.png"),
    shader_texture = texture("white-oil-ocean-deep-2-shader.png"),
    effect_color = {208, 211, 220},
    map_color = {224, 229, 240},
    -- в фактопедии показываем один раз (как у оригинала)
    factoriopedia_alternative = "white-oil-ocean-deep"
  }
}

-- Заменяем текстуру поверхности тайла на нужную нам копию
local function replace_surface_texture(tbl, original, replacement)
  for k, v in pairs(tbl) do
    if type(v) == "string" then
      if v == original then
        tbl[k] = replacement
      end
    elseif type(v) == "table" then
      replace_surface_texture(v, original, replacement)
    end
  end
end

for _, def in ipairs(white_tiles) do
  local source = data.raw["tile"][def.source]
  if source then
    -- свой tile-effect: копия исходного с родным шумом
    -- и своей текстурой поверхности для шейдера
    local effect = table.deepcopy(data.raw["tile-effect"][def.source_effect])
    effect.name = def.effect
    effect.water.image_textures[1].filename = def.shader_texture
    if def.effect_patch then
      def.effect_patch(effect.water)
    end
    data:extend({effect})

    local tile = table.deepcopy(source)
    tile.name = def.name
    tile.order = def.order
    tile.subgroup = "white-tiles"
    tile.localised_name = {"tile-name." .. def.name}

    -- собственно перекраска
    tile.effect = def.effect
    tile.effect_color = def.effect_color
    tile.effect_color_secondary = def.effect_color
    tile.map_color = def.map_color
    replace_surface_texture(tile, def.source_surface, def.surface)

    -- это отдельный тайл, а не замена: не спавним его рядом с оригиналом
    tile.autoplace = nil
    -- снимаем ограничение "сосед только lava": белая лава ставится где угодно
    tile.allowed_neighbors = nil
    tile.factoriopedia_alternative = def.factoriopedia_alternative

    data:extend({tile})

    -- как в Space Age (tiles-fulgora.lua): помечаем тайл «водным»,
    -- чтобы остальные тайлы рисовали к нему переходы
    water_tile_type_names = water_tile_type_names or {}
    table.insert(water_tile_type_names, def.name)
  else
    log("[paln-b-test] prototype/tile.lua: не найден исходный тайл " .. def.source)
  end
end

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
      log("[paln-b-test] prototype/tile.lua: не найден исходный тайл " .. def.source)
    end
  end
end

