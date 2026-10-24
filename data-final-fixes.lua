-- Границы и свечение белой лавы: меняются прототипы, созданные в data.lua.
require("prototype.white-lava-edges")

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

local function add_resource_cloud(planet, template_name, suffix, order, parts)
  local template = data.raw["simple-entity"] and data.raw["simple-entity"][template_name]
  if not template or #parts == 0 then
    return
  end

  -- Уникальные имена на планету: облака разных планет не должны конфликтовать,
  -- а имя не зависит от порядка обхода планет.
  local planet_key = sanitize(planet.name)
  local probability_name = "resource_cloud_probability_" .. planet_key .. "_" .. suffix
  local cloud_name = "resource-cloud-" .. planet_key .. "-" .. suffix

  data:extend({
    {
      type = "noise-expression",
      name = probability_name,
      expression = "clamp(" .. max_expression(parts) .. ", 0, 1)",
    },
  })

  local cloud = table.deepcopy(template)
  cloud.name = cloud_name
  cloud.autoplace = {
    -- У облаков order больше, чем у руд (у руд order пустой), чтобы облако не
    -- занимало тайл раньше ресурса. У белого и оранжевого облака РАЗНЫЕ order:
    -- движок ставит только одно из сущностей с одинаковым order на тайл, а
    -- облака должны накладываться друг на друга.
    order = order,
    probability_expression = probability_name,
    richness_expression = "1",
  }
  data:extend({cloud})

  local entity_settings = get_entity_settings(planet)
  if entity_settings then
    entity_settings.settings[cloud_name] = {}
  end
end

for _, planet in pairs(data.raw.planet or {}) do
  local enabled = {}
  for _, resource_name in ipairs(planet_resource_names(planet)) do
    enabled[resource_name] = true
  end

  for _, cloud in ipairs(CLOUD_RESOURCES) do
    if enabled[cloud.resource] then
      local probability = resource_probability_expression(planet, cloud.resource)
      if probability then
        add_resource_cloud(planet, cloud.template, cloud.suffix, cloud.order, {probability})
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
-- Ребёнок "generator" (ssc-turbine-generator) описан ниже и создаётся/удаляется
-- вместе с турбиной. Скрипт script/ssc-turbine.lua его не трогает: он лишь
-- включает генератор (6MW), пока турбина жжёт топливо, и выключает (0), когда
-- не жжёт.
local things_names = data.raw["mod-data"] and data.raw["mod-data"]["things-names"]

if things_names then
  ---@type things.ThingRegistration
  things_names.data["ssc-turbine"] = {
    name = "ssc-turbine",
    -- Автоматически делать Thing из каждой построенной турбины.
    intercept_construction = true,
    children = {
      generator = {
        -- Automatic child: Things создаст этот генератор вместе с турбиной.
        create = { name = "ssc-turbine-generator" },
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
