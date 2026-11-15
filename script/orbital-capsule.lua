-- Орбитальная капсула: видимая капсула, тень и запуск.
--
-- У rocket-silo нет способа спрятать базу на время запуска, а капсулы-ракеты
-- нет до заправки. Поэтому вся графика «здания» у прототипа убрана, и:
--   * тень под капсулой рисуется этим скриптом всегда;
--   * капсула в простое (пока в шахте нет собранной ракеты) тоже рисуется
--     скриптом;
--   * когда ракета собрана, капсулу рисует движок через rocket_sprite, а нашу
--     копию мы убираем — иначе она задвоится;
--   * при запуске капсула поднимается и улетает сама, а пламя и розжиг сопел
--     рисуются отдельными объектами (как thruster-ignition → thruster-loop в
--     Drivable Cargo Pod).

local CAPSULE_NAME = "orbital-capsule"
local PARKED_SPRITE = "orbital-capsule-parked"
local SHADOW_SPRITE = "orbital-capsule-shadow"
local FLAME_ANIMATION = "orbital-capsule-flame"
local IGNITION_ANIMATION = "orbital-capsule-ignition"
local IGNITION_TICKS = 20

-- === Запрет перелёта игроков ракетой ===
--
-- У rocket-silo нет отдельного поля «не пускать игроков»: перелёт на
-- космические платформы ракетой управляется модификатором силы
-- unlock_travel_to_space_platforms. Держим его выключенным у всех сил,
-- в том числе после исследований, которые могли бы его включить.
--
-- Внимание: это отключает перелёт ракетой для ВСЕХ ракетных шахт, а не
-- только для орбитальной капсулы — другого штатного способа нет.

local function disable_player_travel()
  for _, force in pairs(game.forces) do
    force.unlock_travel_to_space_platforms = false
  end
end

-- === Состояние капсул ===

local function get_data()
  storage.orbital_capsule = storage.orbital_capsule or {capsules = {}}
  return storage.orbital_capsule
end

local function destroy(object)
  if object and object.valid then object.destroy() end
end

local function has_rocket(silo)
  local rocket = silo.rocket
  return rocket ~= nil and rocket.valid
end

local function draw_shadow(silo)
  return rendering.draw_sprite{
    sprite = SHADOW_SPRITE,
    target = silo,
    surface = silo.surface,
    render_layer = "lower-object",
  }
end

local function draw_parked(silo)
  return rendering.draw_sprite{
    sprite = PARKED_SPRITE,
    target = silo,
    surface = silo.surface,
    render_layer = "object",
  }
end

-- Приводит одну капсулу к нужному виду. Возвращает false, если сущность
-- больше не существует (тогда запись надо удалить).
local function sync_one(record)
  local silo = record.entity
  if not (silo and silo.valid) then
    destroy(record.parked)
    destroy(record.shadow)
    record.parked, record.shadow = nil, nil
    return false
  end

  if not (record.shadow and record.shadow.valid) then
    record.shadow = draw_shadow(silo)
  end

  if has_rocket(silo) then
    -- Движок рисует капсулу сам — нашу копию убираем.
    destroy(record.parked)
    record.parked = nil
  elseif not (record.parked and record.parked.valid) then
    record.parked = draw_parked(silo)
  end

  return true
end

local function register(silo)
  if not (silo and silo.valid and silo.name == CAPSULE_NAME) then return end
  local data = get_data()
  local id = silo.unit_number
  local record = data.capsules[id]
  if not record then
    record = {}
    data.capsules[id] = record
  end
  record.entity = silo
  sync_one(record)
end

local function unregister(silo)
  if not silo then return end
  local data = get_data()
  local record = data.capsules[silo.unit_number]
  if record then
    destroy(record.parked)
    destroy(record.shadow)
    data.capsules[silo.unit_number] = nil
  end
end

local function sync_all()
  local data = get_data()
  for id, record in pairs(data.capsules) do
    if not sync_one(record) then
      data.capsules[id] = nil
    end
  end
end

local function register_all_existing()
  for _, surface in pairs(game.surfaces) do
    for _, silo in pairs(surface.find_entities_filtered{name = CAPSULE_NAME}) do
      register(silo)
    end
  end
end

-- === Жизненный цикл капсул ===

script.on_init(function()
  disable_player_travel()
  register_all_existing()
end)

script.on_configuration_changed(function()
  disable_player_travel()
  register_all_existing()
  sync_all()
end)

local function on_built(event)
  register(event.entity)
end

for _, event_id in pairs{
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
} do
  script.on_event(event_id, on_built)
end

script.on_event(defines.events.on_entity_cloned, function(event)
  register(event.destination)
end)

local function on_removed(event)
  unregister(event.entity)
end

for _, event_id in pairs{
  defines.events.on_entity_died,
  defines.events.on_player_mined_entity,
  defines.events.on_robot_mined_entity,
  defines.events.script_raised_destroy,
} do
  script.on_event(event_id, on_removed)
end

-- Периодическая сверка: ракета появляется/исчезает без отдельного события,
-- поэтому раз в полсекунды проверяем, где нужна нарисованная капсула.
script.on_nth_tick(30, sync_all)

-- === Запуск: розжиг и пламя ===
--
-- Поле rocket_flame_animation движок проигрывает постоянно, пока существует
-- сущность ракеты, и на стоянке огонь горел бы всегда. Поэтому пламя рисуем
-- сами, только когда шахту реально запускают. Объекты привязаны к ракете: пока
-- она летит, огонь летит с ней, а когда ракета исчезает — объекты удаляются.
--
-- Слой: капсула с rocket_render_layer_switch_distance = 0 всегда рисуется в
-- "air-object" (160), поэтому пламя ставим в "smoke" (159) — на один слой
-- ниже. Тогда низ капсулы перекрывает верх пламени, и огонь не проступает
-- сквозь капсулу.

script.on_event(defines.events.on_rocket_launch_ordered, function(event)
  local silo = event.rocket_silo
  local rocket = event.rocket
  if not (silo and silo.valid and silo.name == CAPSULE_NAME) then return end
  if not (rocket and rocket.valid) then return end

  local data = get_data()
  local record = data.capsules[silo.unit_number]
  if record then
    destroy(record.parked)
    record.parked = nil
  end

  -- Короткий розжиг, затем ровное пламя.
  rendering.draw_animation{
    animation = IGNITION_ANIMATION,
    target = rocket,
    surface = rocket.surface,
    render_layer = "smoke",
    time_to_live = IGNITION_TICKS,
  }
  rendering.draw_animation{
    animation = FLAME_ANIMATION,
    target = rocket,
    surface = rocket.surface,
    render_layer = "smoke",
  }
end)

-- === Перелёт игроков ===

script.on_event(defines.events.on_research_finished, disable_player_travel)
script.on_event(defines.events.on_player_joined_game, disable_player_travel)