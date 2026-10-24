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

local THINGS = "things"

local TURBINE      = "ssc-turbine"
local GENERATOR    = "ssc-turbine-generator"
local CHILD_KEY    = "generator"
local SMOKE_SOURCE = "ssc-turbine-steam-source"

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
    -- следующий проход (10 тиков).
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

-- Реестр турбин: "surface_index:unit_number" -> LuaEntity.
-- Полный поиск сущностей по всей поверхности на большой базе недешёвый, поэтому
-- мы не сканируем карту каждые 10 тиков: реестр заполняется один раз при
-- загрузке и потом пополняется редким сканированием (раз в 60 тиков).
local function ensure_registry()
  storage.ssc_turbine_generators = storage.ssc_turbine_generators or {}
  storage.ssc_turbine_checked = storage.ssc_turbine_checked or {}
  if storage.ssc_turbines then
    return
  end

  storage.ssc_turbines = {}
  for _, surface in pairs(game.surfaces) do
    for _, turbine in pairs(surface.find_entities_filtered({ name = TURBINE })) do
      if turbine.valid and turbine.unit_number then
        storage.ssc_turbines[turbine.surface.index .. ":" .. turbine.unit_number] = turbine
      end
    end
  end

  -- Один раз гасим "осиротевшие" генераторы от старых версий мода: они стоят
  -- не на турбине, но могли остаться включёнными на 6MW.
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

-- Пополняет реестр турбинами, поставленными без события постройки (например,
-- скриптом другого мода). Вызывается редко, а не каждые 10 тиков.
local function discover_turbines()
  for _, surface in pairs(game.surfaces) do
    for _, turbine in pairs(surface.find_entities_filtered({ name = TURBINE })) do
      if turbine.valid and turbine.unit_number then
        local key = turbine.surface.index .. ":" .. turbine.unit_number
        if not storage.ssc_turbines[key] then
          storage.ssc_turbines[key] = turbine
        end
      end
    end
  end
end

-- Обновляет одну турбину. Вынесено отдельно, чтобы ошибка на одной турбине не
-- останавливала обработку всех остальных.
local function process_turbine(turbine, key, sources, seen)
  local burning = is_burning(turbine)

  local generators = storage.ssc_turbine_generators
  local generator = generators[key]
  if not (generator and generator.valid) then
    generator = get_generator(turbine)
    generators[key] = generator

    -- Один раз на турбину: старые версии скрипта создавали генератор вручную,
    -- поэтому на месте турбины мог остаться второй (осиротевший) генератор.
    if generator and not storage.ssc_turbine_checked[key] then
      storage.ssc_turbine_checked[key] = true
      for _, other in pairs(turbine.surface.find_entities_filtered({
        name = GENERATOR,
        position = turbine.position,
        radius = 0.1,
      })) do
        if other.valid and other ~= generator then
          other.destroy()
        end
      end
    end
  end

  if generator and generator.valid then
    set_power(generator, burning)
  end

  -- Пар: пока турбина работает, держим у трубы particle-source. Он сам пускает
  -- ванильные клубы, которые поднимаются вверх (starting_vertical_speed).
  local source = sources[key]
  if burning then
    if not (source and source.valid) then
      source = create_smoke_source(turbine)
      sources[key] = source
    end
    seen[key] = true
  else
    if source and source.valid then
      source.destroy()
    end
    sources[key] = nil
  end
end

-- Раз в 10 тиков: состояние турбин из реестра и пар у работающих.
-- storage.ssc_smoke_sources[ключ] = particle-source у трубы.
--
-- Тик 10, а не 15: внутри одного мода на каждый интервал может быть только
-- один обработчик, а тик 15 занят script/asm45-corp-site.lua.
local function update_turbines()
  ensure_registry()

  local turbines = storage.ssc_turbines
  local generators = storage.ssc_turbine_generators
  local sources = storage.ssc_smoke_sources or {}
  local seen = {}

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
      local ok, err = pcall(process_turbine, turbine, key, sources, seen)
      if not ok and not storage.ssc_turbine_error_logged then
        storage.ssc_turbine_error_logged = true
        log("ssc-turbine: ошибка обработки турбины: " .. tostring(err))
      end
    end
  end

  -- Убираем источники пара у турбин, которые перестали работать или исчезли.
  for key, source in pairs(sources) do
    if not seen[key] then
      if source and source.valid then
        source.destroy()
      end
      sources[key] = nil
    end
  end

  storage.ssc_smoke_sources = sources

  -- Раз в 60 тиков (каждый 6-й вызов) пополняем реестр: так новые турбины,
  -- поставленные без события постройки, подхватываются максимум за секунду.
  local n = (storage.ssc_turbine_scan_timer or 0) + 1
  if n >= 6 then
    n = 0
    discover_turbines()
  end
  storage.ssc_turbine_scan_timer = n
end

script.on_nth_tick(10, update_turbines)
