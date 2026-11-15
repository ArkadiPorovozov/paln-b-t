-- Регистрация генерации (autoplace) для планет мода — вынесено из
-- data-final-fixes.lua.
--
-- Здесь только то, что обязано выполняться в data-final-fixes (после того
-- как созданы все прототипы): включение autoplace тайлов и сущностей, у
-- которых в prototype/tiles/white.lua и prototype/entity/clouds.lua autoplace
-- намеренно снят. Подключается из data-final-fixes.lua через require.
--
--   * белая нефть (white-oil-ocean-deep-2) — базовый тайл планеты zalupa;
--   * облака над рудами q1/q2 (resource-cloud-<планета>-<suffix>);
--   * тёмный дым над лавой (lava-smoke-<планета>);
--   * пузыри над тёмной водой dark-ocean (декорация dark-water-bubbles);
--   * трубы на тёмной воде dark-ocean (сущность vulcanus-chimney-coldq1).
-- Белый глубокий нефтяной океан 2: в prototype/tiles/white.lua у белых тайлов
-- autoplace снят, чтобы они не спавнились сами. Для планеты zalupa он нужен:
-- это один из её тайлов. Собственный autoplace оставляем выключенным
-- (paln_const_zero) — вероятность задаёт сама планета (gen-zalupa.lua,
-- ["white-oil-ocean-deep-2"] = "paln_zalupa_big_oil_prob"), поэтому тайл не
-- появится ни на одной чужой планете.
local oil_tile = data.raw["tile"] and data.raw["tile"]["white-oil-ocean-deep-2"]
if oil_tile then
  oil_tile.autoplace = {
    probability_expression = "paln_const_zero",
    richness_expression = "paln_const_zero",
  }
end

-- Облака над ресурсами генерирует сама карта (autoplace), а не script/clouds.lua.
-- Облака ставятся только над атмосферными рудами мода (q1-ore/q2-ore, см.
-- prototype/ore/q1-q2.lua): q1-ore -> белое облако, q2-ore -> оранжевое.
-- Ванильные руды и чужие планеты не трогаем: там, где нет q1/q2, облаков нет.
--
-- Плотность 1:1 — облако берёт ровно ту же probability_expression, что и руда,
-- поэтому ставится на те же тайлы. Никакого runtime-создания нет: всё делает
-- генератор карты, а autoplace order "z" гарантирует, что облако не занимает
-- тайл раньше самого ресурса.

-- Ресурс -> облако над ним. suffix задаёт имя облака (resource-cloud-<планета>-<suffix>),
-- template — прототип-заготовка из prototype/entity/clouds.lua, order — порядок
-- autoplace (у белого и оранжевого РАЗНЫЙ, иначе движок поставит только одно).
local CLOUD_RESOURCES = {
  {resource = "q1-ore", suffix = "white", template = "q1-cloud-white", order = "z-a"},
  {resource = "q2-ore", suffix = "orange", template = "q2-cloud-orange", order = "z-b"},
}

-- Планеты, где облака не генерируются вообще. sun — раскалённая лава без
-- атмосферы: облака над рудой там смотрятся чужеродно, а дым над лавой ей
-- тем более не нужен. Облака ставит autoplace, поэтому недостаточно убрать
-- их из сейва — они попадут в каждый новый мир при генерации.
--
-- Прототипы для таких планет всё равно создаются (см. add_resource_cloud), но
-- без autoplace: в уже сгенерированных мирах облака могли быть поставлены, и
-- без прототипа сохранение не загрузилось бы. Так же в моде хранятся старые
-- тайлы и заготовки облаков (prototype/entity/clouds.lua).
local NO_CLOUDS_PLANETS = {
  sun = true,
}

local function resource_probability_expression(planet, resource_name)
  local map_gen_settings = planet.map_gen_settings
  local property_names = map_gen_settings and map_gen_settings.property_expression_names
  local property_probability = property_names and
    property_names["entity:" .. resource_name .. ":probability"]
  if type(property_probability) == "string" then
    return property_probability
  end
  if type(property_probability) == "table" then
    return property_probability.name or property_probability.expression
  end

  local resource = data.raw.resource and data.raw.resource[resource_name]
  local autoplace = resource and resource.autoplace
  local probability = autoplace and autoplace.probability_expression
  if type(probability) == "string" then
    return probability
  end
  if type(probability) == "table" then
    return probability.name or probability.expression
  end
end

-- Возвращает planet.map_gen_settings.autoplace_settings.entity или nil.
--
-- Ничего не создаём: у планеты без этой таблицы облако зарегистрировать нельзя, а
-- дописать её значило бы поменять набор сущностей планеты (treat_missing_as_default
-- решает, включать ли все сущности по умолчанию) — это затронуло бы чужие планеты.
-- Свои руды мод включает явно (prototype/planet/gen-*.lua), так что таблица есть.
local function get_entity_settings(planet)
  local map_gen_settings = planet.map_gen_settings
  if not map_gen_settings then
    return nil
  end
  local autoplace_settings = map_gen_settings.autoplace_settings
  if not autoplace_settings then
    return nil
  end
  local entity_settings = autoplace_settings.entity
  if entity_settings then
    entity_settings.settings = entity_settings.settings or {}
  end
  return entity_settings
end

-- Руда включена на планете ЯВНО (перечислена в autoplace_settings.entity.settings).
-- treat_missing_as_default здесь намеренно не учитывается: иначе на чужой
-- планете, где по умолчанию включены все ресурсы, над нашей рудой появились бы
-- облака, даже если сама руда там не генерируется.
local function planet_explicitly_lists_resource(planet, resource_name)
  local map_gen_settings = planet.map_gen_settings
  local autoplace_settings = map_gen_settings and map_gen_settings.autoplace_settings
  local entity_settings = autoplace_settings and autoplace_settings.entity
  local settings = entity_settings and entity_settings.settings
  return settings ~= nil and settings[resource_name] ~= nil
end

local function max_expression(parts)
  if #parts == 0 then
    return "0"
  end
  if #parts == 1 then
    return "(" .. parts[1] .. ")"
  end
  return "max(" .. table.concat(parts, ", ") .. ")"
end

-- Имя планеты для имён прототипов: всё, кроме букв/цифр, — подчёркивание.
local function sanitize(name)
  return (name:gsub("[^%w]", "_"))
end

local function add_resource_cloud(planet, template_name, suffix, order, parts, enable_autoplace)
  local template = data.raw["simple-entity"] and data.raw["simple-entity"][template_name]
  if not template then
    return
  end
  if enable_autoplace and #parts == 0 then
    return
  end

  -- Уникальные имена на планету: облака разных планет не должны конфликтовать,
  -- а имя не зависит от порядка обхода планет.
  local planet_key = sanitize(planet.name)
  local probability_name = "paln_resource_cloud_probability_" .. planet_key .. "_" .. suffix
  local cloud_name = "resource-cloud-" .. planet_key .. "-" .. suffix

  local cloud = table.deepcopy(template)
  cloud.name = cloud_name

  if enable_autoplace then
    data:extend({
      {
        type = "noise-expression",
        name = probability_name,
        expression = "clamp(" .. max_expression(parts) .. ", 0, 1)",
      },
    })

    -- Сам прототип облака ничего не генерирует (paln_const_zero): облако —
    -- глобальная simple-entity, и на ЛЮБОЙ другой планете движок включает
    -- незаданные сущности по умолчанию (treat_missing_as_default), поэтому с
    -- реальной вероятностью оно вылезло бы и на Nauvis/Vulcanus/Gleba. Родную
    -- вероятность задаёт только целевая планета — ниже, через
    -- property_expression_names ("entity:<облако>:probability").
    cloud.autoplace = {
      -- У облаков order больше, чем у руд (у руд order пустой), чтобы облако не
      -- занимало тайл раньше ресурса. У белого и оранжевого облака РАЗНЫЕ order:
      -- движок ставит только одно из сущностей с одинаковым order на тайл, а
      -- облака должны накладываться друг на друга.
      order = order,
      probability_expression = "paln_const_zero",
      richness_expression = "paln_const_zero",
    }
  else
    -- Планета без облаков: прототип остаётся только ради старых сейвов, где
    -- облака уже стоят (иначе они бы не загрузились). Новые не появляются.
    cloud.autoplace = nil
  end

  data:extend({cloud})

  if enable_autoplace then
    local entity_settings = get_entity_settings(planet)
    if entity_settings then
      entity_settings.settings[cloud_name] = {}
    end
    -- Реальная вероятность — только у этой планеты. На всех остальных
    -- переопределения нет, значит остаётся paln_const_zero из прототипа.
    local property_names = planet.map_gen_settings.property_expression_names
    if property_names then
      property_names["entity:" .. cloud_name .. ":probability"] = probability_name
    end
  end
end

for _, planet in pairs(data.raw.planet or {}) do
  local no_clouds = NO_CLOUDS_PLANETS[planet.name]

  for _, cloud in ipairs(CLOUD_RESOURCES) do
    if no_clouds then
      -- Планета без облаков (sun): прототипы создаём только ради старых
      -- сейвов — там облака могли остаться с тех пор, когда руда на планете
      -- ещё генерировалась. Autoplace не даём, поэтому новых не будет.
      add_resource_cloud(planet, cloud.template, cloud.suffix, cloud.order, {}, false)
    elseif planet_explicitly_lists_resource(planet, cloud.resource) then
      local probability = resource_probability_expression(planet, cloud.resource)
      if probability then
        add_resource_cloud(planet, cloud.template, cloud.suffix, cloud.order, {probability}, true)
      end
    end
  end
end

-- =====================================================================
-- Тёмный дым над лавой (simple-entity).
-- =====================================================================
-- Заготовка лежит в prototype/entity/clouds.lua ("lava-smoke") без autoplace.
-- Здесь выдаём ей autoplace — но только планетам, которые используют нашу
-- генерацию лавы. Признак: вероятность нашего лавового тайла указывает на
-- paln_zalupa_volcano_lava_prob. У новых планет тайл называется "zalupa-lava";
-- старый ключ "tile:lava:probability" оставлен для совместимости со
-- сохранениями, где планета пользовалась ванильным тайлом lava.
--
-- Само покрытие и разрывы считает noise-выражение paln_zalupa_lava_smoke_prob
-- (prototype/planet/gen-zalupa.lua): та же форма вулкана, что и у лавы,
-- поэтому дым ложится на лаву и чуть выходит за её край, а пробелы даёт
-- отдельное поле шума + случайный ролл autoplace.
local LAVA_SMOKE_TEMPLATE = "lava-smoke"
local LAVA_TILE_PROBABILITY = "paln_zalupa_volcano_lava_prob"

local lava_smoke_template = data.raw["simple-entity"] and
  data.raw["simple-entity"][LAVA_SMOKE_TEMPLATE]

if lava_smoke_template then
  for _, planet in pairs(data.raw.planet or {}) do
    local map_gen_settings = planet.map_gen_settings
    local property_names = map_gen_settings and map_gen_settings.property_expression_names
    local lava_probability = property_names and (
      property_names["tile:zalupa-lava:probability"]
      or property_names["tile:lava:probability"])

    if lava_probability == LAVA_TILE_PROBABILITY and not NO_CLOUDS_PLANETS[planet.name] then
      local cloud_name = "lava-smoke-" .. sanitize(planet.name)
      local cloud = table.deepcopy(lava_smoke_template)
      cloud.name = cloud_name
      -- Как у облаков: сам прототип ничего не генерирует (paln_const_zero), иначе
      -- дым-глобальная сущность вылез бы на чужие планеты. Вероятность задаёт
      -- только эта планета через property_expression_names (ниже).
      cloud.autoplace = {
        -- Дым кладём позже остальных autoplace-сущностей (руды/облака выше),
        -- чтобы он не занимал тайл раньше них. Маска столкновений у дыма
        -- пустая, так что он спокойно встаёт поверх руды.
        order = "z-z",
        probability_expression = "paln_const_zero",
        richness_expression = "paln_const_zero",
      }
      data:extend({cloud})

      -- Регистрируем дым в наборе сущностей планеты (у неё
      -- treat_missing_as_default = false, поэтому список обязателен).
      local entity_settings = get_entity_settings(planet)
      if entity_settings then
        entity_settings.settings[cloud_name] = {}
      end
      -- Родная вероятность дыма — только у этой планеты.
      if property_names then
        property_names["entity:" .. cloud_name .. ":probability"] =
          "paln_zalupa_lava_smoke_prob"
      end
    end
  end
end

-- =====================================================================
-- Пузыри над тёмной водой dark-ocean (optimized-decorative).
-- =====================================================================
-- Прототип — prototype/decorative/water-bubbles.lua; в нём autoplace выключен
-- (paln_const_zero), иначе глобальная декорация вылезла бы и на чужие планеты.
-- Декорации, как и сущности, перечисляются в наборе планеты
-- (autoplace_settings.decorative.settings — у нашей планеты
-- treat_missing_as_default = false), а вероятность задаётся через
-- property_expression_names["decorative:<имя>:probability"] — так же, как
-- сделаны облака и дым над лавой выше. Ставим только на dark-ocean.
local BUBBLE_DECORATION = "dark-water-bubbles"
local bubble_decoration = data.raw["optimized-decorative"] and
  data.raw["optimized-decorative"][BUBBLE_DECORATION]

if bubble_decoration then
  local planet = data.raw.planet and data.raw.planet["dark-ocean"]
  local map_gen_settings = planet and planet.map_gen_settings
  local autoplace_settings = map_gen_settings and map_gen_settings.autoplace_settings
  local decorative_settings = autoplace_settings and autoplace_settings.decorative
  local property_names = map_gen_settings and map_gen_settings.property_expression_names

  if decorative_settings and property_names then
    decorative_settings.settings = decorative_settings.settings or {}
    decorative_settings.settings[BUBBLE_DECORATION] = {}
    property_names["decorative:" .. BUBBLE_DECORATION .. ":probability"] =
      "paln_dark_ocean_bubble_prob"
  end
end

-- =====================================================================
-- Вулканические декорации островов dark-ocean (optimized-decorative).
-- =====================================================================
-- Прототипы — prototype/decorative/volcanic-rocks.lua: копии ванильных камней,
-- щебня, трещин и кратеров Вулкана. В прототипах autoplace выключен
-- (paln_const_zero), иначе они вылезли бы на чужие планеты. Как и пузыри,
-- перечисляем их в наборе декораций dark-ocean (у планеты
-- treat_missing_as_default = false, поэтому список обязателен) и задаём
-- вероятность через property_expression_names. Сами вероятности —
-- paln_dark_ocean_deco_* (prototype/planet/gen-dark-ocean.lua): только суша,
-- только не лава.
--
-- Модуль возвращает список {name, probability}, чтобы имена не дублировались
-- между прототипами и регистрацией.
local VOLCANIC_DECORATIONS = require("prototype.decorative.volcanic-rocks")

if #VOLCANIC_DECORATIONS > 0 then
  local planet = data.raw.planet and data.raw.planet["dark-ocean"]
  local map_gen_settings = planet and planet.map_gen_settings
  local autoplace_settings = map_gen_settings and map_gen_settings.autoplace_settings
  local decorative_settings = autoplace_settings and autoplace_settings.decorative
  local property_names = map_gen_settings and map_gen_settings.property_expression_names

  if decorative_settings and property_names then
    decorative_settings.settings = decorative_settings.settings or {}
    for _, spec in ipairs(VOLCANIC_DECORATIONS) do
      decorative_settings.settings[spec.name] = {}
      property_names["decorative:" .. spec.name .. ":probability"] = spec.probability
    end
  end
end

-- =====================================================================
-- Трубы на тёмной воде dark-ocean (simple-entity).
-- =====================================================================
-- Прототип — prototype/entity/rock.lua ("vulcanus-chimney-coldq1"): копия
-- ванильного vulcanus-chimney-cold без эффекта пара. В прототипе autoplace
-- выключен (paln_const_zero) — иначе глобальная сущность вылезла бы на
-- Vulcanus и чужих планетах. Как и пузыри, регистрируем трубу в наборе
-- сущностей dark-ocean (у планеты treat_missing_as_default = false, поэтому
-- список обязателен) и задаём вероятность через property_expression_names.
-- Саму вероятность кластерами считает paln_dark_ocean_chimney_prob
-- (prototype/planet/gen-dark-ocean.lua). Коллизия трубы с ground_tile
-- (см. rock.lua) не пускает её на острова — только на воду.
local CHIMNEY_ENTITY = "vulcanus-chimney-coldq1"
local chimney_entity = data.raw["simple-entity"] and
  data.raw["simple-entity"][CHIMNEY_ENTITY]

if chimney_entity then
  local planet = data.raw.planet and data.raw.planet["dark-ocean"]
  local map_gen_settings = planet and planet.map_gen_settings
  local autoplace_settings = map_gen_settings and map_gen_settings.autoplace_settings
  local entity_settings = autoplace_settings and autoplace_settings.entity
  local property_names = map_gen_settings and map_gen_settings.property_expression_names

  if entity_settings and property_names then
    entity_settings.settings = entity_settings.settings or {}
    entity_settings.settings[CHIMNEY_ENTITY] = {}
    property_names["entity:" .. CHIMNEY_ENTITY .. ":probability"] =
      "paln_dark_ocean_chimney_prob"
  end
end
