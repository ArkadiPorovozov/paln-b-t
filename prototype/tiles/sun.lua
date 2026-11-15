local shared = require("prototype.tiles.shared")
local add_border_to = shared.add_border_to

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
  log("[paln-b-test] prototype/tiles/sun.lua: не найден tile-effect lava")
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
  -- Собственный autoplace выключен: вероятность задаёт планета
  -- (prototype/planet/gen-sun.lua -> ["sun-surface"] = "paln_const_one"), поэтому
  -- лава не появится ни на одной чужой планете.
  sun_surface.autoplace = {probability_expression = "paln_const_zero"}
  data:extend({sun_surface})

  local sun_void = table.deepcopy(empty_space)
  sun_void.name = "sun-void"
  sun_void.order = "z[other]-b[sun-void]"
  sun_void.localised_name = {"tile-name.sun-void"}
  sun_void.factoriopedia_alternative = "empty-space"
  sun_void.autoplace = {probability_expression = "paln_const_zero"}
  data:extend({sun_void})
else
  log("[paln-b-test] prototype/tiles/sun.lua: не найден тайл empty-space")
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
  sun_lava_hot.autoplace = {probability_expression = "paln_const_zero"}
  -- Ванильные "lava"/"lava-hot" в списке быть не должно — иначе при генерации
  -- Вулкана движок достраивает sun-lava-hot рядом с ванильной лавой, несмотря
  -- на autoplace = paln_const_zero (та же причина, что у dark-lava ниже).
  -- На sun ванильной лавы нет, поэтому эти имена не нужны.
  sun_lava_hot.allowed_neighbors =
    {"sun-lava-hot", "sun-void", "sun-platform-foundation"}
  sun_lava_hot.sprite_usage_surface = "any"
  -- На старых сохранениях sun лава должна рисовать берег к sun-void так же,
  -- как к out-of-map. Правим только эту копию, не добавляя sun-void в
  -- глобальный out_of_map_tile_type_names.
  add_border_to(sun_lava_hot, out_of_map_transition_group_id, "sun-void")
  data:extend({sun_lava_hot})
else
  log("[paln-b-test] prototype/tiles/sun.lua: не найден тайл lava-hot")
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
  -- Пятачок фундамента в точке высадки задаёт планета (prototype/planet/
  -- gen-sun.lua -> ["sun-platform-foundation"] = "paln_sun_landing_pad_prob").
  -- Собственный autoplace выключен, иначе фундамент появился бы в точке 0,0
  -- на любой чужой планете. Остальная поверхность — лава, по ней нельзя
  -- ходить, пока не построен фундамент.
  sun_platform.autoplace = {probability_expression = "paln_const_zero"}
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
  log("[paln-b-test] prototype/tiles/sun.lua: не найден тайл space-platform-foundation")
end
