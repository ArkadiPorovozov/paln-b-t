-- ssc-turbine: турбина выдаёт 50MW, пока внутри горит И лёд, И твёрдое топливо.
--
-- Механика:
--   * сама турбина ("ssc-turbine") — assembling-machine с фиксированным рецептом,
--     который тратит 1 лёд + 1 твёрдое топливо в секунду;
--   * электричество выдаёт скрытый генератор "ssc-turbine-generator"
--     (electric-energy-interface). Это автоматический "ребёнок" турбины в
--     терминах библиотеки 0-things (см. data-final-fixes.lua): Things сам создаёт
--     его вместе с турбиной (в т.ч. при постройке из чертежа) и уничтожает с ней.
--
-- Этот скрипт генератор не создаёт и не удаляет — он только держит у него
-- мощность: 50MW, пока турбина жжёт топливо, и 0, когда не жжёт. Так проще и
-- надёжнее, чем дёргать интерфейс:
--   * при выключении обнуляется и накопленный буфер генератора (50МДж), иначе
--     он ещё какое-то время питал бы сеть уже после остановки турбины;
--   * заодно гасятся "осиротевшие" генераторы (оставшиеся от старых версий мода
--     или от снесённых турбин) — иначе такой генератор вечно выдавал бы 50MW;
--   * если генератора у турбины почему-то нет (например, его убрала старая
--     версия скрипта) — он создаётся и привязывается к турбине обратно.
--
-- Плюс скрипт пускает дым из трубы, пока турбина работает — тем же прототипом
-- "turbine-smoke", что и ванильная паровая турбина (у assembling-machine нет
-- поля `smoke`, поэтому делаем это вручную).

local THINGS = "things"

local TURBINE   = "ssc-turbine"
local GENERATOR = "ssc-turbine-generator"
local CHILD_KEY = "generator"

-- Мощность генератора. В рантайме power_production задаётся в Дж/тик
-- (в прототипе те же 50МВт записаны как energy_production = "50MW").
local POWER = 50 * 1000 * 1000 / 60

-- Дым — как у ванильной "steam-turbine".
local SMOKE_NAME      = "turbine-smoke"
local SMOKE_FREQUENCY = 10 / 32                 -- пафов за тик (frequency из steam-turbine)
local SMOKE_POSITION  = { x = 0.36, y = -1.7 }  -- у трубы турбины, в тайлах от её центра

-- Турбина работает, только пока машина реально крафтит: именно в этот момент
-- игра тратит лёд и твёрдое топливо. Как только топливо кончилось, машину
-- отключили сигналом или обесточили — статус перестаёт быть working, и
-- генератор гаснет.
local function is_burning(turbine)
  return turbine.status == defines.entity_status.working
end

local function pos_key(position)
  return position.x .. ":" .. position.y
end

-- Включает/выключает генератор. При выключении обнуляем и накопленный буфер,
-- иначе генератор ещё отдавал бы в сеть запасённые 50МДж.
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
-- это лишь страховка.
local function ensure_thing(turbine)
  local _, id = remote.call(THINGS, "get_thing_id", turbine)
  if id then
    return id
  end
  local _, summary = remote.call(THINGS, "create_thing", { entity = turbine })
  return summary and summary.id
end

-- Находит генератор турбины. Если его нет — подбирает уже лежащий на месте
-- турбины (чтобы не завести второй) или создаёт новый, и привязывает его к
-- турбине как ребёнка Thing.
local function get_generator(turbine)
  local _, child = remote.call(THINGS, "get_child", turbine, CHILD_KEY)
  local generator = child and child.entity
  if generator and generator.valid then
    return generator
  end

  local surface = turbine.surface
  local existing = surface.find_entities_filtered({
    name = GENERATOR,
    position = turbine.position,
    radius = 0.1,
  })
  generator = existing and existing[1] or surface.create_entity({
    name = GENERATOR,
    position = turbine.position,
    force = turbine.force,
    raise_built = false,
  })
  if not generator then
    return nil
  end

  ensure_thing(turbine)
  remote.call(THINGS, "add_child", turbine, CHILD_KEY, generator)
  return generator
end

-- Раз в 15 тиков: состояние всех турбин и список тех, кто сейчас работает.
-- storage.ssc_smoking[ключ] = { entity = турбина, accumulator = ... }
local function update_turbines()
  local smoking = storage.ssc_smoking or {}
  local seen = {}

  for _, surface in pairs(game.surfaces) do
    -- генераторы, которые мы в этом проходе оставили включёнными
    local active = {}

    for _, turbine in pairs(surface.find_entities_filtered({ name = TURBINE })) do
      if turbine.valid then
        local burning = is_burning(turbine)
        local generator = get_generator(turbine)

        if generator then
          set_power(generator, burning)
          if burning then
            active[generator.unit_number] = true
          end
        end

        local uid = turbine.unit_number
        if burning and uid then
          local key = surface.index .. ":" .. uid
          local entry = smoking[key]
          if not entry then
            entry = { accumulator = 0 }
            smoking[key] = entry
          end
          entry.entity = turbine
          seen[key] = true
        end
      end
    end

    -- Гасим всё, что не является включённым генератором работающей турбины:
    -- осиротевшие генераторы от старых версий мода, дубликаты и т.п.
    for _, generator in pairs(surface.find_entities_filtered({ name = GENERATOR })) do
      if generator.valid and not active[generator.unit_number] then
        set_power(generator, false)
      end
    end
  end

  -- забываем турбины, которые перестали работать или исчезли
  for key, entry in pairs(smoking) do
    if not seen[key] or not entry.entity or not entry.entity.valid then
      smoking[key] = nil
    end
  end

  storage.ssc_smoking = smoking
end

-- Дым пускаем каждый тик, чтобы он шёл ровно, как у ванильной турбины.
local function emit_smoke()
  local smoking = storage.ssc_smoking
  if not smoking then
    return
  end

  for _, entry in pairs(smoking) do
    local turbine = entry.entity
    if turbine and turbine.valid then
      entry.accumulator = entry.accumulator + SMOKE_FREQUENCY
      if entry.accumulator >= 1 then
        entry.accumulator = entry.accumulator - 1
        turbine.surface.create_trivial_smoke({
          name = SMOKE_NAME,
          position = {
            x = turbine.position.x + SMOKE_POSITION.x,
            y = turbine.position.y + SMOKE_POSITION.y,
          },
        })
      end
    end
  end
end

script.on_nth_tick(1, emit_smoke)
script.on_nth_tick(15, update_turbines)
