-- ssc-turbine (v3): скрипт больше НЕ обслуживает турбины по тикам.
--
-- Раньше здесь был цикл на 30 тиков (is_crafting, set_power, создание/снос
-- particle-source) плюс реестр турбин. Теперь всё это не нужно:
--   * турбина — нативный КОТЁЛ (жжёт твёрдое топливо, пьёт воду, гонит пар),
--     а нативный генератор "ssc-turbine-plant" жжёт этот пар и даёт 6 МВт
--     (см. prototype/entity/ssc-turbine.lua);
--   * жизненный цикл генератора-ребёнка ведёт библиотека 0-things
--     (см. data-final-fixes.lua), а не скрипт.
--
-- Единственное, что осталось скрипту, — один раз связать паровой бак котла-
-- турбины с паровым баком генератора ("linked"-соединение; обычные "normal"-
-- соединения работают только между соседними тайлами, а турбина и генератор
-- стоят на одном месте). Связь сохраняется в сейве, поэтому повторять её не
-- нужно.
--
-- О новых турбинах скрипт узнаёт от самой библиотеки 0-things: она переизлучает
-- свои события как кастомные (on_initialized / on_children_changed, см.
-- data-final-fixes.lua). Поэтому подписки на on_built_entity нет (её уже занимает
-- script/carkas.lua, а второй обработчик на то же событие в одном моде затирает
-- первый) и поверхность по тикам не сканируется. Раз в 55 тиков идёт дешёвый
-- reconcile() по своему реестру — он добирает то, что не связалось сразу.
--
-- Старая версия целиком лежит рядом, в script/ssc-turbine-old.lua, и больше не
-- подключается.

local THINGS = "things"

local TURBINE     = "ssc-turbine"
local NEW_PLANT   = "ssc-turbine-plant"
local OLD_EEI     = "ssc-turbine-generator"
local OLD_SMOKE   = "ssc-turbine-steam-source"
local CHILD_KEY   = "generator"

-- Идентификатор linked-соединения. Должен совпадать с linked_connection_id
-- у выходного бака турбины и у входного бака генератора.
local LINK_ID = 1

-- Как часто (в тиках) на всякий случай проходить поверхность целиком. Нужно лишь
-- как страховка на случай, если кастомное событие 0-things почему-то не придёт:
-- в норме всех турбин добирает reconcile() по реестру. Редко — чтобы не тратить
-- UPS (одна выборка по имени раз в ~30 секунд).
local SCAN_EVERY = 55 * 33

-- =====================================================================
-- Связывание баков
-- =====================================================================

local function key_of(entity)
  return entity.surface.index .. ":" .. entity.unit_number
end

-- Генератор-ребёнок турбины. Сначала спрашиваем у 0-things, если не вышло —
-- ищем на месте турбины (генератор всегда стоит ровно там же).
local function find_generator(turbine)
  if remote.interfaces[THINGS] then
    local ok, _, child = pcall(remote.call, THINGS, "get_child", turbine, CHILD_KEY)
    if ok and child then
      local entity = child.entity
      if entity and entity.valid then
        return entity
      end
    end
  end

  return turbine.surface.find_entities_filtered({
    name = NEW_PLANT,
    position = turbine.position,
    radius = 0.5,
  })[1]
end

-- Проверяет/создаёт linked-связь между турбиной и её генератором.
--
-- ВАЖНО: методы LuaEntity вызываются БЕЗ self — движок сам держит объект в
-- замыкании (так же сделано в script/carkas.lua: entity.get_inventory(...),
-- plan_entity.destroy()). Поэтому в pcall первым идёт только сам метод, а
-- аргументы — со следующей позиции: pcall(obj.method, arg1, arg2).
local function link(turbine, generator)
  if not (generator and generator.valid) then
    return false
  end

  local ok, other = pcall(generator.get_fluid_box_linked_connection, LINK_ID)
  if ok and other and other.valid then
    return true
  end

  return (pcall(turbine.add_fluid_box_linked_connection, LINK_ID, generator, LINK_ID))
end

local function ensure_storage()
  storage.ssc_turbines     = storage.ssc_turbines or {}
  storage.ssc_turbine_gens = storage.ssc_turbine_gens or {}
end

-- =====================================================================
-- Реестр турбин (нужен только чтобы добирать ещё не связанные)
-- =====================================================================

local function register(entity)
  if not (entity and entity.valid and entity.unit_number) then
    return false
  end
  if entity.name ~= TURBINE then
    return false
  end
  ensure_storage()
  storage.ssc_turbines[key_of(entity)] = entity
  return true
end

-- Разовое наполнение реестра (init / смена конфигурации / первый тик).
local function full_scan()
  ensure_storage()

  for _, surface in pairs(game.surfaces) do
    for _, turbine in pairs(surface.find_entities_filtered({ name = TURBINE })) do
      if turbine.valid and turbine.unit_number then
        storage.ssc_turbines[key_of(turbine)] = turbine
      end
    end
  end
end

-- Один дешёвый проход: забыть мёртвые турбины и связать бак там, где связи ещё
-- нет (например, генератор-ребёнок появился после события постройки).
local function reconcile()
  ensure_storage()
  local turbines = storage.ssc_turbines
  local generators = storage.ssc_turbine_gens

  for key, turbine in pairs(turbines) do
    if not turbine.valid then
      turbines[key] = nil
      generators[key] = nil
    else
      local generator = generators[key]
      if not (generator and generator.valid) then
        generator = find_generator(turbine)
        generators[key] = generator
      end
      if link(turbine, generator) then
        generators[key] = generator
      end
    end
  end
end

-- =====================================================================
-- Совместимость со старыми сейвами (можно удалить, когда старых сейвов не
-- останется).
-- =====================================================================

-- Убирает сущности прошлой версии: старый генератор (electric-energy-interface)
-- и скрытые particle-source. Новый код их не создаёт, поэтому просто сносим всё,
-- что осталось в сейве.
local function remove_old_entities()
  for _, surface in pairs(game.surfaces) do
    for _, name in ipairs({OLD_EEI, OLD_SMOKE}) do
      for _, entity in pairs(surface.find_entities_filtered({ name = name })) do
        if entity.valid then
          entity.destroy()
        end
      end
    end
  end
end

-- Старые турбины уже были Thing-ами, но их ребёнок "generator" указывал на
-- снесённый прототип. Просим Things пересоздать ребёнка уже как ssc-turbine-plant.
-- Всё в pcall: интерфейсы библиотеки могут отличаться, и падать из-за этого на
-- загрузке сейва нельзя.
local function ensure_new_children()
  if not remote.interfaces[THINGS] then
    return
  end

  for _, surface in pairs(game.surfaces) do
    for _, turbine in pairs(surface.find_entities_filtered({ name = TURBINE })) do
      if turbine.valid then
        local _, child = remote.call(THINGS, "get_child", turbine, CHILD_KEY)
        local entity = child and child.entity
        if not (entity and entity.valid and entity.name == NEW_PLANT) then
          -- Просим Things забыть мёртвого ребёнка (если такой API есть) —
          -- дальше он создаст нового сам.
          pcall(remote.call, THINGS, "remove_child", turbine, CHILD_KEY)

          -- Запасной путь: если у турбины ещё нет нового генератора, ставим его
          -- руками и пробуем привязать как ребёнка.
          local existing = surface.find_entities_filtered({
            name = NEW_PLANT,
            position = turbine.position,
            radius = 0.1,
          })[1]
          if not existing then
            local created = surface.create_entity({
              name = NEW_PLANT,
              position = turbine.position,
              force = turbine.force,
              raise_built = false,
            })
            if created then
              pcall(remote.call, THINGS, "add_child", turbine, CHILD_KEY, created)
            end
          end
        end
      end
    end
  end
end

-- Старая версия гоняла свою жидкость (плазму) — выливаем её из баков турбины и
-- генератора, чтобы не осталось мусора с неподходящим фильтром.
local function clear_fluids()
  for _, surface in pairs(game.surfaces) do
    for _, name in ipairs({TURBINE, NEW_PLANT}) do
      for _, entity in pairs(surface.find_entities_filtered({ name = name })) do
        if entity.valid then
          -- clear_fluids() очищает баки самой сущности и не лезет в подключённые
          -- сегменты (трубы). Имя метода именно такое: clear_fluid_contents в API
          -- нет (была ошибка «LuaEntity doesn't contain key clear_fluid_contents»).
          pcall(function() entity.clear_fluids() end)
        end
      end
    end
  end
end

local function migrate()
  if storage.ssc_turbine_v3_migrated then
    return
  end
  storage.ssc_turbine_v3_migrated = true

  -- Старое состояние (реестры, кэш источников, флаг ошибки) больше не нужно.
  storage.ssc_turbine_generators   = nil
  storage.ssc_turbine_checked      = nil
  storage.ssc_turbines_scanned     = nil
  storage.ssc_turbine_error_logged = nil
  storage.ssc_smoke_sources        = nil

  -- Сначала перевешиваем ребёнка (пока старый генератор ещё существует),
  -- потом сносим остатки старой версии, и только затем чистим баки.
  ensure_new_children()
  remove_old_entities()
  clear_fluids()
  full_scan()
  reconcile()

  -- full_scan() выше уже прошёл поверхность; следующий плановый — только через
  -- SCAN_EVERY.
  storage.ssc_turbine_next_scan = game.tick + SCAN_EVERY
end

-- =====================================================================
-- События
-- =====================================================================

-- Турбины узнаём от библиотеки 0-things (её кастомные события объявлены в
-- data-final-fixes.lua). Своих подписок на on_built_entity нет: в одном моде на
-- событие может быть только один обработчик, и script/carkas.lua уже подписан на
-- on_built_entity — наша подписка затёрла бы его.

-- Турбина построена (руками, дроном, из чертежа, копированием и т.п.).
script.on_event("ssc-turbine-initialized", function(event)
  local turbine = event.entity
  if register(turbine) then
    -- Генератор-ребёнок 0-things создаёт в этом же кадре, но чуть позже, поэтому
    -- с первого раза его может ещё не быть — тогда свяжет on_children_changed
    -- или reconcile(). Само связывание защищено pcall, см. link().
    link(turbine, find_generator(turbine))
  end
end)

-- У турбины появился ребёнок "generator" — самое время связать баки. К моменту
-- этого события генератор уже создан и инициализирован (0-things вызывает
-- initialize() ребёнка до рассылки события).
script.on_event("ssc-turbine-children-changed", function(event)
  local turbine = event.thing and event.thing.entity
  if turbine and turbine.valid and turbine.name == TURBINE then
    register(turbine)
    link(turbine, find_generator(turbine))
  end
end)

script.on_configuration_changed(migrate)
script.on_init(migrate)

-- Страховка. В одном моде на событие может быть только один обработчик, а
-- script/clouds.lua регистрируется позже и затирает наши on_init /
-- on_configuration_changed. Поэтому миграция идёт с тика 55 (он свободен), а
-- вместе с ней — дешёвый reconcile(), который добирает несвязанные баки. Раз в
-- SCAN_EVERY тиков дополнительно проходим поверхность целиком — на случай, если
-- кастомное событие 0-things не придёт.
script.on_nth_tick(55, function(event)
  if not storage.ssc_turbine_v3_migrated then
    migrate()
  end

  if event.tick >= (storage.ssc_turbine_next_scan or 0) then
    storage.ssc_turbine_next_scan = event.tick + SCAN_EVERY
    full_scan()
  end

  reconcile()
end)
