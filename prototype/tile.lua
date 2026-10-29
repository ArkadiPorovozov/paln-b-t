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

-- =====================================================================
-- Планета sun: полупрозрачная лавовая поверхность + фундамент платформы.
-- =====================================================================
--
-- Вся поверхность sun — sun-surface: лава из двух слоёв.
--   1. variants.main — «корка» graphics/terrain/sun-lava.png. Это лавовая
--      текстура с альфой ~63 %, она задаёт рисунок поверхности; шейдер берёт
--      её как основу и анимирует.
--   2. effect = "sun-lava" — копия ванильного шейдера глубокой лавы
--      (tile-effect "lava"), но с нашей текстурой и более злыми
--      параметрами анимации.
--
-- Ключевой момент — прозрачность эффекта. По умолчанию
-- effect_is_opaque = true, если альфа effect_color равна 1. В этом режиме
-- water-шейдер рисуется отдельным НЕПРОЗРАЧНЫМ проходом поверх нижних
-- слоёв: он закрывает и собственную корку, и подложку платформы, и вообще
-- всё, что оказалось под ним на «уровне обычных тайлов». Именно это давало
-- множество багов. Мы ставим effect_is_opaque = false и альфу < 1 —
-- движок смешивает шейдер с тем, что под ним, и нижние слои больше не
-- перекрываются.
--
-- ВАЖНО: полупрозрачный эффект анимируется только в группе "water".
-- В "water-overlay" (где лежит ванильная неглубокая лава) движок рисует
-- полупрозрачный tile-effect статично — кадры анимации шейдера не
-- обновляются. Проверено на копиях тайла: официальные эффекты lava и lava-2
-- в "water-overlay" с alpha < 1 стоят, а тот же тайл в "water" с alpha < 1
-- анимируется. Непрозрачный вариант в "water-overlay" тоже анимируется, но
-- он и не прозрачный. Поэтому лава живёт в "water", как ванильная lava-hot.
--
-- Порядок отрисовки:
--   * "water", layer 5 — сама лава (как ванильная горячая лава Вулкана,
--     lava-hot);
--   * "ground-natural" — «изнанка» переходов платформы (background_layout);
--   * "ground-artificial", layer 15 — плиты sun-platform-foundation.
-- Так платформа висит над лавой: плиты сверху, изнанка между лавой и
-- плитами. Изнанку пришлось поднять из "water-overlay" в "ground-natural":
-- при прозрачном эффекте шейдер смешивается на уровне своей группы и иначе
-- закрывал бы её.
--
-- Почему тайл, а не simple-entity: сущности рисуются в своих render_layer, и
-- хотя в 2.0 есть слой "under-tiles", сущность на каждый тайл планеты — это
-- неподъёмная цена (лавой покрыта вся поверхность), тогда как тайл
-- рендерится тайловым проходом бесплатно.
--
-- ВАЖНО: основа тайла — empty-space, а не lava-hot. Границу и переходы
-- задаёт не картинка, а сам прототип: у empty-space variants.empty_transitions
-- = true и нет списка transitions, поэтому поверхность нигде не рисует
-- «берег» — ни к краю карты, ни к плите (кромку плиты рисует её
-- собственный transition.overlay). Копия lava-hot принесла бы кромку
-- lava_to_out_of_map_transition и сломала бы текущий вид границы.
-- Поэтому базу оставляем empty-space и меняем только поверхность (текстуру
-- лавы) и эффект (анимацию лавы).
--
-- collision_mask тоже скопирован у empty-space: ходить по лаве нельзя,
-- строить можно только sun-platform-foundation.
--
-- sun-void остался от первой версии планеты (космос + лавовые моря). В новой
-- генерации он не используется, но прототип сохранён: старые сохранения
-- могут содержать этот тайл, и без прототипа они бы не загрузились.

-- tile-effect "sun-lava" — анимация лавы на поверхности планеты sun.
-- Копия ванильного tile-effect "lava" (шейдер воды с вариацией "lava"):
-- подменена текстура поверхности для шейдера (наша копия
-- graphics/terrain/sun-lava-shader.png) и усилена анимация.
local lava_effect = data.raw["tile-effect"] and data.raw["tile-effect"]["lava"]
if lava_effect then
  local sun_lava_effect = table.deepcopy(lava_effect)
  sun_lava_effect.name = "sun-lava"
  local water = sun_lava_effect.water
  water.image_textures[1].filename =
    "__paln-b-test__/graphics/terrain/sun-lava-shader.png"
  -- Максимально злая лава: поток в ~2.3 раза быстрее ванильного, сильнее
  -- искажение рисунка и заметно мощнее векторы панорамирования.
  -- Для варианта шейдера "lava" поля означают не то же, что для воды
  -- (см. doc-html/prototype-api.json -> WaterTileEffectParameters):
  --   animation_speed — скорость панорамирования/искажения (у ванилы 1.5);
  --   animation_scale — сила искажения (у ванилы 0.7/0.75). Слишком большое
  --     значение рвёт поток на мелкую «крупу», поэтому ~0.7 — предел;
  --   reflection_threshold — масштаб дисторсии (у ванилы 1.0);
  --   dark_threshold — яркость «береговой» лавы. У сплошной поверхности
  --     берегов нет, поэтому оставлено ванильное значение: на вид не влияет;
  --   specular_lightness и foam_color * foam_color_multiplier — векторы
  --     панорамирования (у ванилы specular ~{22..30, 48..51, 17..22},
  --     foam {59..73, 5..30, 5..9}); чем больше, тем быстрее поток.
  -- Эффект лежит ПОД полупрозрачной коркой, поэтому картинка не плоская.
  water.animation_speed = 3.5
  water.animation_scale = {0.70, 0.70}
  water.specular_lightness = {120, 70, 30}
  water.foam_color = {190, 45, 6}
  water.foam_color_multiplier = 2.4
  water.dark_threshold = {0.755, 0.755}
  water.reflection_threshold = {0.95, 0.95}
  water.specular_threshold = {0.75, 0.25}
  data:extend({sun_lava_effect})
else
  log("[paln-b-test] prototype/tile.lua: не найден tile-effect lava")
end

-- Поверхность планеты sun:
--   true  — анимированная лава (текущая реализация; sun-lava.png +
--           shader-текстура sun-lava-shader.png);
--   false — статичная «фотосфера» (старая реализация; sun-surface-1x1.png
--           + graphics/planet/sun_color.png).
-- Обе картинки остались в graphics, поэтому вернуть прежний вид — один флаг.
local sun_surface_use_lava = true

local empty_space = data.raw["tile"]["empty-space"]
if empty_space then
  local sun_surface = table.deepcopy(empty_space)
  sun_surface.name = "sun-surface"
  sun_surface.order = "z[other]-a[sun-surface]"
  sun_surface.localised_name = {"tile-name.sun-surface"}
  sun_surface.factoriopedia_alternative = "empty-space"
  -- Лава лежит в "water", layer 5 (как ванильная горячая лава lava-hot).
  -- Группа выбрана из-за анимации: полупрозрачный tile-effect в
  -- "water-overlay" движок рисует статично (подробности в шапке раздела).
  -- "water" лежит НИЖЕ ground-слоёв, поэтому лава не «прогрызывается» на
  -- уровне обычных тайлов.
  sun_surface.layer_group = "water"
  sun_surface.layer = 5

  if sun_surface_use_lava then
    -- Анимированная лава: тот же шейдер, что у лавы Вулкана
    -- (tile-effect "sun-lava" выше).
    sun_surface.effect = "sun-lava"
    -- Полупрозрачный эффект. По умолчанию effect_is_opaque = true, если
    -- альфа effect_color равна 1 — тогда шейдер рисуется непрозрачным
    -- слоем ПОВЕРХ тайлов и закрывает всё, что лежит ниже него (в том числе
    -- корку и подложку платформы). Именно это давало «прогрызание» лавы на
    -- уровне обычных тайлов. С effect_is_opaque = false и alpha < 1 движок
    -- смешивает шейдер с тем, что под ним, и лава становится прозрачной.
    sun_surface.effect_is_opaque = false
    sun_surface.effect_color = {255, 168, 72, 150}
    sun_surface.effect_color_secondary = {255, 200, 70, 120}
    -- Текстура-корка — sun-lava.png (4096x576, сетка как у ванильной
    -- lava.png): 16 вариантов 1x1, 16 вариантов 2x2 и 16 вариантов 4x4.
    -- Разные варианты ломают однообразный повтор, а шейдер поверх корки
    -- добавляет живое течение лавы.
    local sun_lava_texture = "__paln-b-test__/graphics/terrain/sun-lava.png"
    sun_surface.variants =
    {
      main =
      {
        {
          picture = sun_lava_texture,
          count = 16,
          scale = 0.5,
          size = 1,
          line_length = 16,
        },
        {
          picture = sun_lava_texture,
          count = 16,
          scale = 0.5,
          size = 2,
          y = 128,
          line_length = 16,
          probability = 1,
        },
        {
          picture = sun_lava_texture,
          count = 16,
          scale = 0.5,
          size = 4,
          y = 320,
          line_length = 16,
          probability = 0.1,
        },
      },
      empty_transitions = true,
    }
  else
    -- Звёздный шейдер не нужен: фотосфера закрывает фон целиком.
    sun_surface.effect = nil
    sun_surface.effect_color = nil
    sun_surface.effect_color_secondary = nil
    sun_surface.particle_tints = nil
    -- Текстура солнца 1024x1024 нарезана на 16 кадров 256x256 (4 в ряд),
    -- каждый кадр покрывает 8x8 тайлов при 32 px на тайл. Отдельный лист
    -- 128x128 (16 кадров 32x32) — обязательный 1x1-вариант: он нужен движку
    -- для одиночных тайлов и краёв, иначе тайл не загрузится.
    sun_surface.variants =
    {
      main =
      {
        {
          picture = "__paln-b-test__/graphics/terrain/sun-surface-1x1.png",
          count = 16,
          size = 1,
          line_length = 4,
        },
        {
          picture = "__paln-b-test__/graphics/planet/sun_color.png",
          count = 16,
          size = 8,
          line_length = 4,
          probability = 1,
        }
      },
      empty_transitions = true,
    }
  end

  sun_surface.map_color = {255, 120, 30}
  sun_surface.sprite_usage_surface = "any"
  -- Если поверхность чем-то накроют, по умолчанию это наша плита.
  sun_surface.default_cover_tile = "sun-platform-foundation"
  sun_surface.autoplace = {probability_expression = "const_one"}
  data:extend({sun_surface})

  local sun_void = table.deepcopy(empty_space)
  sun_void.name = "sun-void"
  sun_void.order = "z[other]-b[sun-void]"
  sun_void.localised_name = {"tile-name.sun-void"}
  sun_void.factoriopedia_alternative = "empty-space"
  sun_void.autoplace = {probability_expression = "const_zero"}
  data:extend({sun_void})

  -- Лава должна рисовать берег к sun-void так же, как к out-of-map.
  out_of_map_tile_type_names = out_of_map_tile_type_names or {}
  table.insert(out_of_map_tile_type_names, "sun-void")
else
  log("[paln-b-test] prototype/tile.lua: не найден тайл empty-space")
end

-- sun-lava-hot — копия lava-hot, оставшаяся от версии «солнце из лавы».
-- В текущей генерации не используется (поверхность — sun-surface), но
-- прототип сохранён: старые сохранения могут содержать этот тайл.
-- Причины, по которым это была копия, а не ванильная lava-hot:
--   * у lava-hot allowed_neighbors = {"lava"}: на Вулкане горячая лава
--     обязана граничить с обычной, а на sun она была одна на всю планету;
--   * sprite_usage_surface = "vulcanus" не учитывает поверхность sun.
local lava_hot = data.raw["tile"]["lava-hot"]
if lava_hot then
  local sun_lava_hot = table.deepcopy(lava_hot)
  sun_lava_hot.name = "sun-lava-hot"
  sun_lava_hot.localised_name = {"tile-name.sun-lava-hot"}
  sun_lava_hot.factoriopedia_alternative = "lava-hot"
  sun_lava_hot.autoplace = {probability_expression = "const_zero"}
  sun_lava_hot.allowed_neighbors =
    {"lava", "lava-hot", "sun-lava-hot", "sun-void", "sun-platform-foundation"}
  sun_lava_hot.sprite_usage_surface = "any"
  data:extend({sun_lava_hot})

  -- Другие тайлы (фундамент, покрытия) должны рисовать кромку лавы и для
  -- этой копии.
  lava_tile_type_names = lava_tile_type_names or {}
  table.insert(lava_tile_type_names, "sun-lava-hot")
  water_tile_type_names = water_tile_type_names or {}
  table.insert(water_tile_type_names, "sun-lava-hot")
else
  log("[paln-b-test] prototype/tile.lua: не найден тайл lava-hot")
end

-- sun-platform-foundation — копия фундамента космической платформы.
-- Глубокая копия целиком сохраняет variants:
--   * main — плиты 1x1/2x2;
--   * transition.overlay_layout — side / inner_corner / outer_corner /
--     double_side / u_transition / o_transition ("все концы" платформы);
--   * transition.background_layout и mask_layout — подложка и маски к ним.
-- То есть кромка платформы, стыки плит и внутренние/внешние углы рисуются
-- теми же спрайтами из graphics/terrain/space-platform, что и в космосе.
local platform_foundation = data.raw["tile"]["space-platform-foundation"]
if platform_foundation then
  local sun_platform = table.deepcopy(platform_foundation)
  sun_platform.name = "sun-platform-foundation"
  sun_platform.localised_name = {"tile-name.sun-platform-foundation"}
  sun_platform.order = "a[artificial]-d[utility]-c[sun-platform-foundation]"
  sun_platform.subgroup = "artificial-tiles"
  sun_platform.factoriopedia_alternative = "space-platform-foundation"
  sun_platform.minable = {mining_time = 0.5, result = "sun-platform-foundation"}
  -- Спрайты платформы нужны на обычной поверхности планеты, а не только
  -- на космической платформе — иначе кромка может не попасть в атлас.
  sun_platform.sprite_usage_surface = "any"
  -- Пятачок фундамента в точке высадки (см. sun_landing_pad_prob в
  -- prototype/planet/noise-data.lua). Остальная поверхность — лава, по ней
  -- нельзя ходить, пока не построен фундамент.
  sun_platform.autoplace = {probability_expression = "sun_landing_pad_prob"}
  sun_platform.allowed_neighbors = nil
  sun_platform.allows_being_covered = false
  -- Ещё раз копируем таблицы краевых вариантов, чтобы копия ничего не
  -- делила с ванильным прототипом.
  sun_platform.variants.main = table.deepcopy(platform_foundation.variants.main)
  sun_platform.variants.transition =
    table.deepcopy(platform_foundation.variants.transition)
  -- В ванили подложка платформы (трубы/вентиляция снизу) рисуется ПОД
  -- тайлами: на космической платформе сосед — empty-space с прозрачной
  -- картинкой, поэтому она видна. На солнце сосед — лавовый тайл
  -- ("water-overlay"), и такая подложка оказывается под ним (платформа
  -- выглядела бы плоской).
  --
  -- Поднять подложку в отдельную группу слоёв можно, но движок для
  -- background/overlay разрешает tile_height только 1..4, а у платформы 8:
  -- спрайт подложки — кадр 512 px высотой (8 тайлов), из которых реально
  -- заняты верхние ~4 тайла, остальное — прозрачный отступ. Поэтому кладём
  -- в graphics/terrain обрезанные по этому отступу листы с tile_height = 4
  -- (масштаб и размер рисунка те же, что в ванили).
  --
  -- Группу выбираем "ground-natural": она идёт сразу ПОСЛЕ "water-overlay"
  -- (где лежит лава) и ДО плит платформы (ground-artificial, layer 15).
  -- Подложка в "water-overlay" не подошла: при полупрозрачном эффекте
  -- шейдер лавы смешивается на уровне своей группы и закрывал её.
  local background_names =
  {
    side = "side",
    double_side = "double-side",
    inner_corner = "inner-corner",
    outer_corner = "outer-corner",
    u_transition = "u",
  }
  local background_layout = sun_platform.variants.transition.background_layout
  for variant, file_name in pairs(background_names) do
    local layout = background_layout[variant]
    if layout then
      layout.spritesheet = "__paln-b-test__/graphics/terrain/sun-platform-"
        .. file_name .. "-background.png"
      layout.tile_height = 4
    end
  end
  sun_platform.variants.transition.background_layer_group = "ground-natural"
  sun_platform.variants.transition.background_layer_offset = 0
  sun_platform.variants.transition.draw_background_layer_under_tiles = false
  data:extend({sun_platform})
else
  log("[paln-b-test] prototype/tile.lua: не найден тайл space-platform-foundation")
end

-- =====================================================================
-- Тёмное глубокое озеро — копия gleba-deep-lake с Глебы.
-- =====================================================================
--
-- Отличия от оригинала:
--   * темнее: оттенок воды задаёт effect_color (тинт water-шейдера), он
--     приглушён примерно в 2.5 раза — вместе с map_color и
--     effect_color_secondary;
--   * без звуков: убраны шаги, приводнение, транспорт и ambient
--     (плеск воды / дождь), а также звук постройки;
--   * лежит ПОД всеми остальными тайлами — так же, как лава на sun.
--
-- Как это работает (подробный разбор — в разделе sun выше):
--   * layer_group = "water", layer = 1 — самая нижняя группа тайлов:
--     zero -> water -> water-overlay -> ground-natural -> ground-artificial.
--     Всё, что выше (земля, насыпь, плиты платформы), рисуется поверх;
--   * effect_is_opaque = false — ключевой флаг. Если оставить по умолчанию
--     (true при непрозрачном effect_color), water-шейдер рисуется отдельным
--     НЕПРОЗРАЧНЫМ проходом поверх обычных тайлов, и layer_group его не
--     спасает. С false шейдер смешивается внутри своей группы;
--   * в "water" полупрозрачный шейдер ещё и анимируется, а в "water-overlay"
--     движок рисует его статично (проверено на sun).
--
-- Тайл самодостаточен и сам по себе не генерируется (autoplace = const_zero).
-- Чтобы использовать его на планете, достаточно прописать его в
-- map_gen_settings (пример — prototype/planet/dark-ocean.lua); тогда же можно
-- убрать слой сущностей dark-water-shader, он станет не нужен.
local deep_lake = data.raw["tile"] and data.raw["tile"]["gleba-deep-lake"]
if deep_lake then
  -- Своя подгруппа, чтобы тайл не терялся среди ванильных в редакторе.
  data:extend({
    {
      type = "item-subgroup",
      name = "dark-tiles",
      group = "tiles",
      order = "0-a[dark-tiles]"
    }
  })

  local dark_lake = table.deepcopy(deep_lake)
  dark_lake.name = "dark-deep-lake"
  dark_lake.order = "z[other]-a[dark-deep-lake]"
  dark_lake.subgroup = "dark-tiles"
  dark_lake.localised_name = {"tile-name.dark-deep-lake"}
  dark_lake.factoriopedia_alternative = "gleba-deep-lake"

  -- Цвет. effect_color — тинт water-шейдера, именно он задаёт оттенок воды:
  -- у Gleba {31, 51, 60}. Сначала вода была почти чёрной (в 2.5 раза темнее,
  -- {12, 20, 25}) — получилось слишком глухо, поэтому сделали чуть светлее
  -- (примерно в 1.9 раза темнее Глебы, {16, 26, 33}), вместе с
  -- effect_color_secondary и map_color.
  dark_lake.effect_color = {16, 26, 33}
  dark_lake.effect_color_secondary = {24, 38, 8}
  dark_lake.map_color = {11, 20, 27}

  -- Как out-of-map/empty-space: самый нижний слой "zero". Тогда родная
  -- вулканическая кромка (её background в ванили тоже "zero") рисуется ровно
  -- как на Вулкане — над водой и под вулканической плиткой.
  dark_lake.layer_group = "zero"
  dark_lake.layer = 0
  dark_lake.effect_is_opaque = false

  -- Спрайты должны попасть в атлас на любой поверхности, а не только Глебы.
  dark_lake.sprite_usage_surface = "any"

  -- Тишина: ни шагов, ни плеска, ни дождя, ни звука постройки.
  dark_lake.walking_sound = nil
  dark_lake.landing_steps_sound = nil
  dark_lake.driving_sound = nil
  dark_lake.ambient_sounds = nil
  dark_lake.ambient_sounds_group = nil
  dark_lake.build_sound = nil
  dark_lake.mined_sound = nil

  -- Сам по себе не генерируется: вероятность задаёт map_gen планеты.
  dark_lake.autoplace = {probability_expression = "const_zero"}

  data:extend({dark_lake})

  -- Как sun-surface: тайл ничего не рисует по краям. Убираем чужие переходы
  -- (водные из gleba-deep-lake), а empty_transitions = true у него уже есть от
  -- оригинала — кромку к нашей воде рисует сосед (вулканический тайл).
  dark_lake.transitions = nil
  dark_lake.transitions_between_transitions = nil

  -- Игра сама считает тёмную воду «краем карты» для переходов (как
  -- out-of-map/empty-space). Так любой тайл со своим out-of-map переходом
  -- нарисует к ней родную кромку, без наших правок в его прототипе.
  out_of_map_tile_type_names = out_of_map_tile_type_names or {}
  table.insert(out_of_map_tile_type_names, "dark-deep-lake")
else
  log("[paln-b-test] prototype/tile.lua: не найден тайл gleba-deep-lake")
end

-- =====================================================================
-- Тёмные копии вулканических тайлов Вулкана.
-- =====================================================================
--
-- Семь наземных тайлов Вулкана копируются один в один (префикс "dark-") и
-- кладутся в подгруппу "dark-tiles". Локализация берётся у ванильных тайлов:
-- localised_name ссылается на tile-name.<оригинал>, поэтому новых записей в
-- locale не нужно.
--
-- Переходы у копий остаются родные (water/lava/out-of-map из
-- lava_stone_transitions), поэтому связи с обычными тайлами работают как у
-- ванильных вулканических тайлов. Для границы с тёмной водой мы не подменяем
-- спрайты, а просим движок нарисовать её сам: добавляем "dark-deep-lake" в
-- to_tiles родного out-of-map перехода.
--
-- Тайлы самодостаточны и сами по себе не генерируются (autoplace = const_zero):
-- чтобы использовать их на планете, пропишите их в map_gen_settings
-- (пример — prototype/planet/dark-ocean.lua).
local dark_volcanic_tiles = {
  "volcanic-folds-flat",
  "volcanic-folds",
  "volcanic-smooth-stone",
  "volcanic-smooth-stone-warm",
  "volcanic-ash-cracks",
  "volcanic-jagged-ground",
  "volcanic-ash-light",
}

-- Настраиваем родной out-of-map переход копии так, чтобы движок сам рисовал
-- вулканическую кромку к тёмной воде. Спрайт и layout родные, цвет не трогаем;
-- в to_tiles ванильной записи перечислены
-- {"out-of-map", "empty-space", "oil-ocean-shallow"} — добавляем туда
-- "dark-deep-lake". Список принадлежит глубокой копии тайла, ванильные тайлы
-- не затрагиваются. Все остальные переходы (вода/лава/обычные тайлы) остаются
-- родными.
--
-- Слой: в ванили этот background лежит в "zero" — ниже воды, потому что сосед
-- там out-of-map без шейдера. У нас сосед — тёмная вода с водным шейдером,
-- который рисуется выше "zero" и полностью закрывает кромку. Поэтому кладём
-- background в "water-overlay": по описанию движка это группа для «переходов
-- к воде, которые должны быть под тайлами». Она выше водного шейдера и ниже
-- ground-natural, то есть кромка видна над водой и остаётся под плиткой —
-- так же, как выглядит ванильная кромка на Вулкане.
-- Кромка к тёмной воде рисуется родным спрайтом out-of-map перехода. Чтобы
-- она «растворялась» вниз (в воду), у спрайта-копии альфа background-колонки
-- притушена книзу: верх кромки непрозрачный, к дальнему краю уходит в 0.
-- (В спрайтшите видимую альфу даёт колонка background; колонка mask — жёсткая
-- маска только 0/255.) Копии лежат в graphics/terrain/volcanic-oom/; сами
-- спрайты готовятся из ванильных скриптом, здесь только подключаем.
local out_of_map_border_copies = {
  ["__space-age__/graphics/terrain/out-of-map-transition/volcanic-out-of-map-transition.png"] =
    graphics .. "volcanic-oom/volcanic-out-of-map-transition.png",
  ["__space-age__/graphics/terrain/out-of-map-transition/volcanic-out-of-map-transition-transition.png"] =
    graphics .. "volcanic-oom/volcanic-out-of-map-transition-transition.png",
}

local function apply_oom_border_copy(list)
  for _, transition in ipairs(list or {}) do
    local copy = out_of_map_border_copies[transition.spritesheet]
    if copy then
      transition.spritesheet = copy
    end
  end
end

local function apply_space_border(tile)
  apply_oom_border_copy(tile.transitions)
  apply_oom_border_copy(tile.transitions_between_transitions)
  for _, transition in ipairs(tile.transitions or {}) do
    if transition.transition_group == out_of_map_transition_group_id then
      local to_tiles = transition.to_tiles or {}

      local has_dark_lake = false
      for _, name in ipairs(to_tiles) do
        if name == "dark-deep-lake" then
          has_dark_lake = true
          break
        end
      end
      if not has_dark_lake then
        table.insert(to_tiles, "dark-deep-lake")
      end
      transition.to_tiles = to_tiles

      transition.background_layer_group = "water-overlay"
      transition.background_layer_offset = 1
      transition.offset_background_layer_by_tile_layer = true
    end
  end
end

for _, source_name in ipairs(dark_volcanic_tiles) do
  local source = data.raw["tile"] and data.raw["tile"][source_name]
  if source then
    local tile = table.deepcopy(source)
    tile.name = "dark-" .. source_name
    tile.subgroup = "dark-tiles"
    tile.order = "z[other]-c[dark-" .. source_name .. "]"
    tile.localised_name = {"tile-name." .. source_name}
    -- Спрайты нужны на поверхности нашей планеты, а не только на Вулкане.
    tile.sprite_usage_surface = "any"
    tile.autoplace = {probability_expression = "const_zero"}
    apply_space_border(tile)
    data:extend({tile})
  else
    log("[paln-b-test] prototype/tile.lua: не найден исходный тайл " .. source_name)
  end
end

-- =====================================================================
-- Лавовый пик островов тёмного океана.
-- =====================================================================
--
-- Полная копия ванильной лавы Вулкана (tile "lava"): deepcopy целиком, только
-- переименование и то, без чего копия не заработает на нашей поверхности.
-- На тёмном океане она ставится на самый верх уровня острова — «пик» (см.
-- prototype/planet/dark-ocean.lua, dark_ocean_prob_lava).
--
-- Изменяется относительно ванильного оригинала:
--   * name/subgroup/order/localised_name — это отдельный тайл;
--   * sprite_usage_surface = "any" — спрайты нужны на нашей поверхности;
--   * autoplace = const_zero — сам по себе не генерируется (иначе полез бы
--     ещё и на Вулкан);
--   * allowed_neighbors: в ванили там только {"lava-hot"} (на Вулкане лава
--     обязана граничить с горячей), расширяем до наших вулканических тайлов —
--     иначе лава не может соседствовать с островом. Так же сделано у
--     sun-lava-hot;
--   * регистрируем копию в lava_tile_type_names/water_tile_type_names, чтобы
--     соседние тайлы рисовали к ней родную лавовую кромку и шейдер (как
--     sun-lava-hot и white-lava).
local lava_source = data.raw["tile"] and data.raw["tile"]["lava"]
if lava_source then
  local dark_lava = table.deepcopy(lava_source)
  dark_lava.name = "dark-lava"
  dark_lava.subgroup = "dark-tiles"
  dark_lava.order = "z[other]-b[dark-lava]"
  dark_lava.localised_name = {"tile-name.lava"}
  dark_lava.sprite_usage_surface = "any"
  dark_lava.autoplace = {probability_expression = "const_zero"}

  local lava_neighbors = {
    "dark-lava", "lava", "lava-hot",
    "dark-deep-lake",
    "dark-volcanic-folds-flat", "dark-volcanic-folds",
    "dark-volcanic-smooth-stone", "dark-volcanic-smooth-stone-warm",
    "dark-volcanic-ash-cracks", "dark-volcanic-ash-light",
    "dark-volcanic-jagged-ground",
  }
  dark_lava.allowed_neighbors = lava_neighbors

  data:extend({dark_lava})

  -- Другие тайлы (вулканические, фундамент и т.д.) должны рисовать кромку лавы
  -- и для этой копии, а шейдер — считать её лавовой.
  lava_tile_type_names = lava_tile_type_names or {}
  table.insert(lava_tile_type_names, "dark-lava")
  water_tile_type_names = water_tile_type_names or {}
  table.insert(water_tile_type_names, "dark-lava")
else
  log("[paln-b-test] prototype/tile.lua: не найден тайл lava")
end
