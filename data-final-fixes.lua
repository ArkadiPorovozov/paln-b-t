-- Границы и свечение белой лавы: меняются прототипы, созданные в data.lua.
require("prototype.white-lava-edges")

-- Планета sun использует тайлы космоса и космическую платформу на обычной
-- поверхности планеты. space-platform-foundation по умолчанию помечен как
-- "space": подсказка атласу, что спрайты нужны только на космических
-- платформах. На sun они нужны и на поверхности планеты, поэтому разрешаем
-- использовать их везде (иначе кромка платформы может не попасть в атлас).
local space_platform_foundation = data.raw["tile"] and data.raw["tile"]["space-platform-foundation"]
if space_platform_foundation then
  space_platform_foundation.sprite_usage_surface = "any"
end

-- Рецепт солнечного фундамента открывается там же, где ванильный рецепт
-- space-platform-foundation: технологией rocket-silo (вместе с
-- unlock-space-platforms). Так на sun можно строить платформу над лавой,
-- как только в игре появляются космические платформы.
local rocket_silo_technology = data.raw["technology"] and data.raw["technology"]["rocket-silo"]
if rocket_silo_technology and data.raw["recipe"]["sun-platform-foundation"] then
  rocket_silo_technology.effects = rocket_silo_technology.effects or {}
  local already_unlocked = false
  for _, effect in pairs(rocket_silo_technology.effects) do
    if effect.type == "unlock-recipe" and effect.recipe == "sun-platform-foundation" then
      already_unlocked = true
      break
    end
  end
  if not already_unlocked then
    table.insert(rocket_silo_technology.effects,
      {type = "unlock-recipe", recipe = "sun-platform-foundation"})
  end
end

-- Теплообменник открывается технологией sun: раньше на планету всё равно не
-- попасть, а на месте без него база не проживёт и минуты.
local SUN_TECHNOLOGY = "sun"
local SUN_RECIPES = {"sun-heat-exchanger"}
local sun_technology = data.raw["technology"] and data.raw["technology"][SUN_TECHNOLOGY]
if sun_technology then
  sun_technology.effects = sun_technology.effects or {}
  for _, recipe in ipairs(SUN_RECIPES) do
    if data.raw["recipe"][recipe] then
      local already_unlocked = false
      for _, effect in pairs(sun_technology.effects) do
        if effect.type == "unlock-recipe" and effect.recipe == recipe then
          already_unlocked = true
          break
        end
      end
      if not already_unlocked then
        table.insert(sun_technology.effects, {type = "unlock-recipe", recipe = recipe})
      end
    end
  end
end

-- Белый глубокий нефтяной океан 2: в prototype/tile.lua у белых тайлов
-- autoplace снят, чтобы они не спавнились сами. Для планеты zalupa он нужен:
-- это базовый тайл всей планеты. Выражение zalupa_oil_prob определено
-- в prototype/planet/noise-data.lua, поэтому включаем autoplace здесь.
local oil_tile = data.raw["tile"] and data.raw["tile"]["white-oil-ocean-deep-2"]
if oil_tile then
  oil_tile.autoplace = {
    probability_expression = "zalupa_oil_prob",
    richness_expression = "const_zero",
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
-- Свои руды мод включает явно (prototype/planet/map-gen.lua), так что таблица есть.
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

local function planet_resource_names(planet)
  local entity_settings = get_entity_settings(planet)
  if not entity_settings then
    return {}
  end

  local names, seen = {}, {}
  local function add(name)
    if not seen[name] and data.raw.resource and data.raw.resource[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end

  for name in pairs(entity_settings.settings or {}) do
    add(name)
  end
  -- treat_missing_as_default означает, что на планете включены все ресурсы,
  -- даже если их нет в списке settings.
  if entity_settings.treat_missing_as_default then
    for name in pairs(data.raw.resource or {}) do
      add(name)
    end
  end

  table.sort(names)
  return names
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
  local probability_name = "resource_cloud_probability_" .. planet_key .. "_" .. suffix
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

    cloud.autoplace = {
      -- У облаков order больше, чем у руд (у руд order пустой), чтобы облако не
      -- занимало тайл раньше ресурса. У белого и оранжевого облака РАЗНЫЕ order:
      -- движок ставит только одно из сущностей с одинаковым order на тайл, а
      -- облака должны накладываться друг на друга.
      order = order,
      probability_expression = probability_name,
      richness_expression = "1",
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
  end
end

for _, planet in pairs(data.raw.planet or {}) do
  local enabled = {}
  for _, resource_name in ipairs(planet_resource_names(planet)) do
    enabled[resource_name] = true
  end

  local no_clouds = NO_CLOUDS_PLANETS[planet.name]

  for _, cloud in ipairs(CLOUD_RESOURCES) do
    if no_clouds then
      -- Планета без облаков (sun): прототипы создаём только ради старых
      -- сейвов — там облака могли остаться с тех пор, когда руда на планете
      -- ещё генерировалась. Autoplace не даём, поэтому новых не будет.
      add_resource_cloud(planet, cloud.template, cloud.suffix, cloud.order, {}, false)
    elseif enabled[cloud.resource] then
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
-- генерацию лавы. Признак: вероятность тайла "lava" указывает на
-- zalupa_volcano_lava_prob (см. prototype/planet/map-gen.lua).
--
-- Само покрытие и разрывы считает noise-выражение zalupa_lava_smoke_prob
-- (prototype/planet/noise-data.lua): та же форма вулкана, что и у лавы,
-- поэтому дым ложится на лаву и чуть выходит за её край, а пробелы даёт
-- отдельное поле шума + случайный ролл autoplace.
local LAVA_SMOKE_TEMPLATE = "lava-smoke"
local LAVA_TILE_PROBABILITY = "zalupa_volcano_lava_prob"

local lava_smoke_template = data.raw["simple-entity"] and
  data.raw["simple-entity"][LAVA_SMOKE_TEMPLATE]

if lava_smoke_template then
  for _, planet in pairs(data.raw.planet or {}) do
    local map_gen_settings = planet.map_gen_settings
    local property_names = map_gen_settings and map_gen_settings.property_expression_names
    local lava_probability = property_names and property_names["tile:lava:probability"]

    if lava_probability == LAVA_TILE_PROBABILITY and not NO_CLOUDS_PLANETS[planet.name] then
      local cloud_name = "lava-smoke-" .. sanitize(planet.name)
      local cloud = table.deepcopy(lava_smoke_template)
      cloud.name = cloud_name
      cloud.autoplace = {
        -- Дым кладём позже остальных autoplace-сущностей (руды/облака выше),
        -- чтобы он не занимал тайл раньше них. Маска столкновений у дыма
        -- пустая, так что он спокойно встаёт поверх руды.
        order = "z-z",
        probability_expression = "zalupa_lava_smoke_prob",
      }
      data:extend({cloud})

      -- Регистрируем дым в наборе сущностей планеты (у неё
      -- treat_missing_as_default = false, поэтому список обязателен).
      local entity_settings = get_entity_settings(planet)
      if entity_settings then
        entity_settings.settings[cloud_name] = {}
      end
    end
  end
end

-- Регистрация турбины в библиотеке 0-things (Thing).
--
-- Things берёт на себя жизненный цикл турбины: постройка/снос, чертежи,
-- undo/redo, восстановление из "призраков" и т.п. А ещё он автоматически
-- создаёт и уничтожает "детей" турбины.
--
-- Ребёнок "generator" (нативный генератор ssc-turbine-plant) создаётся/удаляется
-- вместе с турбиной. Скрипт его не трогает вообще: генератор жжёт плазму из
-- турбины сам, сам даёт 6 МВт и сам пускает пар (см. prototype/entity/ssc-turbine.lua).
local things_names = data.raw["mod-data"] and data.raw["mod-data"]["things-names"]

if things_names then
  ---@type things.ThingRegistration
  things_names.data["ssc-turbine"] = {
    name = "ssc-turbine",
    -- Автоматически делать Thing из каждой построенной турбины.
    intercept_construction = true,
    -- 0-things переизлучает свои события как обычные кастомные события Factorio.
    -- Скрипт (script/ssc-turbine.lua) ловит их и так узнаёт о новой турбине — без
    -- подписки на on_built_entity (её уже занимает script/carkas.lua, а второй
    -- обработчик на то же событие в одном моде затирает первый) и без сканов
    -- поверхности. on_initialized — турбина построена; on_children_changed — у неё
    -- появился генератор-ребёнок (в этот момент скрипт связывает баки).
    custom_events = {
      on_initialized = "ssc-turbine-initialized",
      on_children_changed = "ssc-turbine-children-changed",
    },
    children = {
      generator = {
        -- Automatic child: Things создаст этот генератор вместе с турбиной.
        create = { name = "ssc-turbine-plant" },
      },
    },
  }

  -- Стройплощадка asm45_corp. Things ведёт её жизненный цикл (постройка, снос,
  -- чертежи, undo/redo), а скрипт script/asm45-corp-site.lua держит надпись над
  -- площадкой как render object, привязанный к Thing.
  things_names.data["asm45-corp-site"] = {
    name = "asm45-corp-site",
    intercept_construction = true,
  }
end

-- Кастомные события, которые 0-things переизлучает для турбины (см. custom_events
-- выше). Регистрируем их всегда: script.on_event по имени необъявленного события
-- падает с ошибкой при загрузке. Само событие, разумеется, придёт, только если
-- 0-things есть.
data:extend({
  { type = "custom-event", name = "ssc-turbine-initialized" },
  { type = "custom-event", name = "ssc-turbine-children-changed" },
})

-- Стоящий каркас площадки: один кадр из штатной анимации MultiBuild.
--
-- animation_speed у render object анимацию не останавливает (0 движок понимает
-- как «по умолчанию»), поэтому «замерший» каркас — это отдельный прототип,
-- в котором просто нечего проигрывать: одна и та же картинка в кадре 16.
local STAND_FRAME = 16 -- 1-based, то есть 15-й кадр с нуля — как в platform_anim

for _, corner in ipairs({"back_left", "back_right", "front_left", "front_right"}) do
  for _, part in ipairs({"top", "body"}) do
    local source = data.raw["animation"] and data.raw["animation"]["mb-panim-" .. corner .. "-" .. part]
    if source then
      local animation = table.deepcopy(source)
      animation.name = "asm45-scaffold-" .. corner .. "-" .. part
      for _, layer in ipairs(animation.layers) do
        layer.frame_sequence = {STAND_FRAME}
      end
      data:extend({animation})
    end
  end
end
