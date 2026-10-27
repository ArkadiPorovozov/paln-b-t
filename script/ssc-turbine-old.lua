-- =====================================================================
-- АРХИВ. Это старая реализация ssc-turbine (до переезда на нативный генератор).
-- Файл НЕ подключается через require и не влияет на игру: оставлен как бэкап,
-- чтобы можно было вернуться/сравнить. Актуальный скрипт — script/ssc-turbine.lua.
-- =====================================================================
--
-- ssc-turbine: турбина выдаёт 6MW, пока внутри горит И лёд, И твёрдое топливо.
--
-- Механика:
--   * сама турбина ("ssc-turbine") — assembling-machine с фиксированным рецептом,
--     который тратит 1 лёд + 1 твёрдое топливо в секунду;
--   * электричество выдаёт скрытый генератор "ssc-turbine-generator"
--     (electric-energy-interface). Это автоматический "ребёнок" турбины в
--     терминах библиотеки 0-things (см. data-final-fixes.lua): Things сам создаёт
--     его вместе с турбиной (в т.ч. при постройке из чертежа) и уничтожает с ней.
--
-- Генератор создаёт и удаляет Things. Скрипт его не создаёт (иначе рядом
-- появляется второй), а только держит у ребёнка мощность: 6MW, пока турбина
-- жжёт топливо, и 0, когда не жжёт:
--   * при выключении обнуляется и накопленный буфер генератора (100кДж — один
--     тик на 6 МВт), иначе
--     он ещё какое-то время питал бы сеть уже после остановки турбины;
--   * заодно гасятся "осиротевшие" генераторы (оставшиеся от старых версий мода
--     или от снесённых турбин) — иначе такой генератор вечно выдавал бы 6MW.
--
-- Пар: пока турбина работает, рядом с трубой существует скрытый particle-source
-- "ssc-turbine-steam-source". Он пускает ванильный пар (ssc-turbine-steam —
-- копия turbine-smoke) с starting_vertical_speed, поэтому клубы поднимаются
-- вверх точно так же, как у обычной паровой турбины.
--
-- ПРОИЗВОДИТЕЛЬНОСТЬ (важно для UPS на больших базах):
--   * турбины регистрируются по событиям постройки/клонирования: о постройке
--     сообщает сама игра, поэтому постоянный скан поверхности не нужен.
--     Разовый скан остаётся только на init/смене конфигурации — для турбин,
--     которые уже стоят в сейве (событий постройки по ним не будет);
--   * состояние опрашивается раз в 30 тиков (0.5 с), а не раз в 10;
--   * источник пара держим только у турбин рядом с подключённым игроком: дым
--     всё равно виден лишь там, а на большой базе это убирает сотни "дальних"
--     particle-source (каждый из них — отдельная сущность, обновляемая каждый тик);
--   * pcall больше не вызывается на каждую турбину — только один раз на проход.
--
-- ВНИМАНИЕ: скрытый генератор (electric-energy-interface) на каждую турбину
-- остаётся: assembling-machine сам мощность не производит. Если в profiler'е
-- всё ещё большая строка "Electric network" — следующий шаг: переделать турбину
-- в настоящий "generator" (он жжёт жидкость, поэтому потребуется звено, которое
-- делает эту жидкость из льда и твёрдого топлива).

local THINGS = "things"

local TURBINE      = "ssc-turbine"
local GENERATOR    = "ssc-turbine-generator"
local CHILD_KEY    = "generator"
local SMOKE_SOURCE = "ssc-turbine-steam-source"

-- Как часто (в тиках) опрашивать состояние турбин. Рецепт жжёт топливо 1 раз в
-- секунду, поэтому 30 тиков (0.5 с) — с запасом. Тик 15 занят
-- script/asm45-corp-site.lua, а более частый опрос смысла не имеет.
local POLL_TICKS = 30

-- Дым держим только в радиусе от подключённых игроков (в тайлах). Поставь nil,
-- чтобы вернуть дым у всех турбин карты.
local SMOKE_RADIUS = 64
local SMOKE_RADIUS_2 = SMOKE_RADIUS and SMOKE_RADIUS * SMOKE_RADIUS

-- Мощность генератора. В рантайме power_production задаётся в Дж/тик
-- (в прототипе те же 6МВт записаны как energy_production = "6MW").
local POWER = 6 * 1000 * 1000 / 60

-- Устье выхлопной трубы на спрайте — в точке (-0.88, -1.30) от центра турбины.
-- Анимация дыма рисуется со сдвигом shift = (-0.53125, -0.4375), поэтому
-- источник ставим со сдвигом обратно: (-0.88, -1.30) - shift = (-0.35, -0.86).
local SMOKE_POSITION = { x = 0.36, y = -1.7 }

-- Турбина работает, только пока машина реально крафтит: именно в этот момент
-- игра тратит лёд и твёрдое топливо. Как только топливо кончилось, машину
-- отключили сигналом или обесточили — статус перестаёт быть working, и
-- генератор гаснет.
local function is_burning(turbine)
  return turbine.status == defines.entity_status.working
      or (turbine.is_crafting and turbine.is_crafting())
end

-- Включает/выключает генератор. При выключении обнуляем и накопленный буфер,
-- иначе генератор ещё отдавал бы в сеть запасённые 100кДж.
local function set_power(generator, on)
  if on then
    if generator.power_production ~= POWER then
      generator.power_production = POWER
    end
  else
    if generator.power_production ~= 0 then
      generator.power_production = 0
    end
    if generator.energy ~= 0 then
      generator.energy = 0
    end
  end
end

-- Возвращает Thing-ид турбины, при необходимости создавая Thing вручную.
-- Обычно турбина уже Thing (intercept_construction в data-final-fixes.lua),
-- это лишь страховка для старых сейвов и турбин, поставленных скриптом.
-- Things при создании Thing сам создаёт зарегистрированных детей, поэтому
-- после create_thing генератор появляется без нашего участия.
local function ensure_thing(turbine)
  if not remote.interfaces[THINGS] then
    return nil
  end
  local _, id = remote.call(THINGS, "get_thing_id", turbine)
  if id then
    return id
  end
  local err, summary = remote.call(THINGS, "create_thing", { entity = turbine })
  if err then
    log("ssc-turbine: не удалось зарегистрировать турбину: "
      .. tostring(err.message or err.code))
    return nil
  end
  return summary and summary.id
end

-- Читает генератор-ребёнка из Things. Именно так и надо: генератор создаёт и
-- удаляет Things (см. data-final-fixes.lua), а не скрипт. Если создавать его
-- ещё и руками, рядом появляется второй генератор, а add_child падает с
-- "could_not_add_child", потому что ключ "generator" уже занят автоматическим
-- ребёнком.
local function get_child_generator(turbine)
  if not remote.interfaces[THINGS] then
    return nil
  end
  local _, child = remote.call(THINGS, "get_child", turbine, CHILD_KEY)
  local generator = child and child.entity
  if generator and generator.valid then
    return generator
  end
end

-- Находит генератор турбины. Сначала просит его у Things; если турбина ещё не
-- Thing (старый сейв, постройка скриптом/редактором) — регистрирует её, и
-- Things создаёт генератор сам. Своё создание — только на случай, когда Things
-- недоступен или не смог зарегистрировать турбину.
local function get_generator(turbine)
  local generator = get_child_generator(turbine)
  if generator then
    return generator
  end

  local thing_id = ensure_thing(turbine)

  generator = get_child_generator(turbine)
  if generator then
    return generator
  end
  if thing_id then
    -- Thing уже создан, но Things ещё не успел создать ребёнка: он делает это
    -- отдельным событием инициализации. Не плодим дубликат — подождём
    -- следующий проход.
    return nil
  end

  local surface = turbine.surface
  local existing = surface.find_entities_filtered({
    name = GENERATOR,
    position = turbine.position,
    radius = 0.1,
  })[1]
  generator = existing or surface.create_entity({
    name = GENERATOR,
    position = turbine.position,
    force = turbine.force,
    raise_built = false,
  })
  if not generator then
    return nil
  end

  if remote.interfaces[THINGS] then
    remote.call(THINGS, "add_child", turbine, CHILD_KEY, generator)
  end
  return generator
end

-- Создаёт скрытый источник пара у трубы турбины.
local function create_smoke_source(turbine)
  return turbine.surface.create_entity({
    name = SMOKE_SOURCE,
    position = {
      x = turbine.position.x + SMOKE_POSITION.x,
      y = turbine.position.y + SMOKE_POSITION.y,
    },
    force = turbine.force,
  })
end

-- =====================================================================
-- Реестр турбин: "surface_index:unit_number" -> LuaEntity.
-- =====================================================================

local function key_of(entity)
  return entity.surface.index .. ":" .. entity.unit_number
end

local function ensure_storage()
  storage.ssc_turbines           = storage.ssc_turbines or {}
  storage.ssc_turbine_generators = storage.ssc_turbine_generators or {}
  storage.ssc_turbine_checked    = storage.ssc_turbine_checked or {}
end

-- Добавляет турбину в реестр. Вызывается по событиям постройки, поэтому
-- постоянный скан поверхности больше не нужен.
local function register_turbine(entity)
  if not (entity and entity.valid and entity.unit_number) then
    return
  end
  if entity.name ~= TURBINE then
    return
  end
  ensure_storage()
  storage.ssc_turbines[key_of(entity)] = entity
end

-- Разовое наполнение реестра (init / смена конфигурации) + гашение
-- "осиротевших" генераторов от старых версий мода.
local function full_scan()
  ensure_storage()
  if storage.ssc_turbines_scanned then
    return
  end
  storage.ssc_turbines_scanned = true

  for _, surface in pairs(game.surfaces) do
    for _, turbine in pairs(surface.find_entities_filtered({ name = TURBINE })) do
      if turbine.valid and turbine.unit_number then
        storage.ssc_turbines[key_of(turbine)] = turbine
      end
    end
  end

  for _, surface in pairs(game.surfaces) do
    for _, generator in pairs(surface.find_entities_filtered({ name = GENERATOR })) do
      if generator.valid then
        local turbine = surface.find_entities_filtered({
          name = TURBINE,
          position = generator.position,
          radius = 0.1,
        })[1]
        if not turbine then
          set_power(generator, false)
        end
      end
    end
  end
end

-- Источник пара нужен только там, где его видно: рядом с подключённым игроком.
local function near_any_player(position, players)
  if not SMOKE_RADIUS_2 then
    return true
  end
  for i = 1, #players do
    local dx = position.x - players[i].x
    local dy = position.y - players[i].y
    if dx * dx + dy * dy <= SMOKE_RADIUS_2 then
      return true
    end
  end
  return false
end

-- Один раз на турбину: старые версии скрипта создавали генератор вручную,
-- поэтому на месте турбины мог остаться второй (осиротевший) генератор.
local function drop_duplicate_generators(turbine, keep, key)
  if storage.ssc_turbine_checked[key] then
    return
  end
  storage.ssc_turbine_checked[key] = true
  for _, other in pairs(turbine.surface.find_entities_filtered({
    name = GENERATOR,
    position = turbine.position,
    radius = 0.1,
  })) do
    if other.valid and other ~= keep then
      other.destroy()
    end
  end
end

-- Раз в POLL_TICKS тиков: состояние турбин из реестра и пар у работающих.
local function update_turbines()
  ensure_storage()

  -- Страховка: если реестр так и не собрался (например, скрипт обновился на
  -- лету), собираем его сейчас.
  if not storage.ssc_turbines_scanned then
    full_scan()
  end

  local turbines = storage.ssc_turbines
  local generators = storage.ssc_turbine_generators
  local sources = storage.ssc_smoke_sources or {}
  storage.ssc_smoke_sources = sources

  -- Позиции подключённых игроков по поверхностям — для отсечения "дальнего"
  -- пара (и чтобы не плодить пар на поверхности, где игрока нет).
  local players_by_surface = {}
  for _, player in pairs(game.connected_players) do
    if player.valid then
      local index = player.surface.index
      local list = players_by_surface[index]
      if not list then
        list = {}
        players_by_surface[index] = list
      end
      list[#list + 1] = player.position
    end
  end

  local seen = {}

  -- Один pcall на весь проход: ошибка на одной турбине не роняет обработку
  -- остальных, но и не стоит по pcall на каждую турбину.
  local ok, err = pcall(function()
    for key, turbine in pairs(turbines) do
      if not turbine.valid then
        local generator = generators[key]
        if generator and generator.valid then
          set_power(generator, false)
        end
        turbines[key] = nil
        generators[key] = nil
        storage.ssc_turbine_checked[key] = nil
      else
        local burning = is_burning(turbine)

        local generator = generators[key]
        if not (generator and generator.valid) then
          generator = get_generator(turbine)
          generators[key] = generator
          if generator then
            drop_duplicate_generators(turbine, generator, key)
          end
        end

        if generator and generator.valid then
          set_power(generator, burning)
        end

        -- Пар: только у работающей турбины и только рядом с игроком.
        local want_smoke = false
        if burning then
          local list = players_by_surface[turbine.surface.index]
          want_smoke = list ~= nil and near_any_player(turbine.position, list)
        end

        local source = sources[key]
        if want_smoke then
          if not (source and source.valid) then
            sources[key] = create_smoke_source(turbine)
          end
          seen[key] = true
        else
          if source and source.valid then
            source.destroy()
          end
          sources[key] = nil
        end
      end
    end
  end)

  if not ok and not storage.ssc_turbine_error_logged then
    storage.ssc_turbine_error_logged = true
    log("ssc-turbine: ошибка обработки турбины: " .. tostring(err))
  end

  -- Убираем источники пара у турбин, которые перестали работать, исчезли или
  -- ушли далеко от игрока.
  for key, source in pairs(sources) do
    if not seen[key] then
      if source and source.valid then
        source.destroy()
      end
      sources[key] = nil
    end
  end
end

script.on_init(function()
  ensure_storage()
  full_scan()
end)

script.on_configuration_changed(function()
  -- Мод могли включить на существующем сейве: пересобираем реестр с нуля.
  storage.ssc_turbines_scanned = nil
  storage.ssc_turbine_generators = {}
  storage.ssc_turbine_checked = {}
  storage.ssc_turbine_error_logged = nil
  full_scan()
end)

-- Турбины регистрируются событием, а не сканом поверхности. Работает и для
-- ручной постройки, и для дронов/чертежей, и для клонирования, и для платформ.
script.on_event({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
  defines.events.on_space_platform_built_entity,
}, function(event)
  register_turbine(event.entity or event.created_entity)
end)

script.on_event(defines.events.on_entity_cloned, function(event)
  register_turbine(event.destination)
end)

script.on_nth_tick(POLL_TICKS, update_turbines)
