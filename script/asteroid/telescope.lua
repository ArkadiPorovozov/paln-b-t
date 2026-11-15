-- Рантайм телескопа.
--
-- Телескоп стоит на планетной поверхности и раз в SEARCH_TICKS тиков пытается
-- найти астероид. Найденный астероид — космическая платформа:
--   * это небольшая площадка (space-platform-foundation) с хабом;
--   * из хаба можно войти/выйти и строить руками или дронами;
--   * двигатели строить/ставить нельзя, платформа не двигается.
--
-- Данные (прототипы) — prototype/asteroid/telescope.lua.

local shared = require("script.asteroid-test.shared")

local TELESCOPE = "asteroid-telescope"

-- Как часто и с каким шансом телескоп ищет астероид.
local SEARCH_TICKS = 600      -- 10 секунд
local SEARCH_CHANCE = 0.75
-- Общий предел найденных астероидов, чтобы не плодить платформы бесконечно.
local MAX_ASTEROIDS = 12

-- Небольшой кусок поверхности астероида вокруг хаба.
local LAND_RADIUS = 8
local LAND_TILE = "space-platform-foundation"

-- Как часто проверяем, что платформа не обзавелась двигателями.
local ENFORCE_TICKS = 63

----------------------------------------------------------------------------
-- Состояние
----------------------------------------------------------------------------

local function get_state()
  local state = storage.asteroid_telescope
  if not state then
    state = { counter = 0, platforms = {} }
    storage.asteroid_telescope = state
  end
  return state
end

local function is_asteroid_platform(platform)
  if not (platform and platform.valid) then return false end
  local state = storage.asteroid_telescope
  if not state then return false end
  for _, record in ipairs(state.platforms) do
    if record.name == platform.name then return true end
  end
  return false
end

----------------------------------------------------------------------------
-- Помощники
----------------------------------------------------------------------------

local function platform_exists(force, name)
  for _, platform in pairs(force.platforms or {}) do
    if platform.valid and platform.name == name then
      return true
    end
  end
  return false
end

local function next_platform_name(force, state)
  for _ = 1, 50 do
    state.counter = state.counter + 1
    local name = "asteroid-" .. state.counter
    if not platform_exists(force, name) then
      return name
    end
  end
  return "asteroid-" .. game.tick .. "-" .. math.random(100000)
end

-- Двигатели у найденного астероида не нужны: он не должен летать.
-- Убираем и готовые двигатели, и их призраки, чтобы дроны их даже не ставили.
local function remove_thrusters(platform)
  local surf = platform and platform.surface
  if not (surf and surf.valid) then return end
  local thrusters = surf.find_entities_filtered({ name = "thruster" })
  for _, thruster in ipairs(thrusters) do
    if thruster.valid then thruster.destroy() end
  end
  local ghosts = surf.find_entities_filtered({ name = "entity-ghost", ghost_name = "thruster" })
  for _, ghost in ipairs(ghosts) do
    if ghost.valid then ghost.destroy() end
  end
end

-- Застилаем площадку вокруг хаба тайлами платформы — «кусок земли».
local function make_land(surf, cx, cy)
  local tiles = {}
  for x = cx - LAND_RADIUS, cx + LAND_RADIUS do
    for y = cy - LAND_RADIUS, cy + LAND_RADIUS do
      tiles[#tiles + 1] = { position = { x, y }, name = LAND_TILE }
    end
  end
  pcall(function() surf.set_tiles(tiles, true) end)
end

-- Платформа не должна летать: пауза, нулевая скорость, никаких двигателей.
local function enforce_immobile(platform)
  if not (platform and platform.valid) then return end
  pcall(function() platform.paused = true end)
  pcall(function() platform.speed = 0 end)
  remove_thrusters(platform)
end

----------------------------------------------------------------------------
-- Создание найденного астероида-платформы
----------------------------------------------------------------------------

local function create_asteroid_platform(force, planet)
  local state = get_state()
  local name = next_platform_name(force, state)

  local ok, platform = pcall(function()
    return force.create_space_platform({
      name = name,
      planet = planet,
      starter_pack = shared.starter_pack,
    })
  end)
  if not ok or not platform then
    return nil, "create_space_platform: " .. tostring(platform)
  end

  pcall(function() platform.apply_starter_pack() end)

  local surf = platform.surface
  if not (surf and surf.valid) then
    pcall(function() platform.destroy(1) end)
    return nil, "platform surface is missing"
  end

  surf.ignore_surface_conditions = true

  local hub = platform.hub
  local cx = hub and math.floor(hub.position.x) or 0
  local cy = hub and math.floor(hub.position.y) or 0

  make_land(surf, cx, cy)
  enforce_immobile(platform)

  local record = {
    platform = platform,
    name = name,
    planet = planet,
    found_tick = game.tick,
    hub_position = { x = cx, y = cy },
  }
  state.platforms[#state.platforms + 1] = record

  log(("[asteroid-telescope] found %s around %s (hub at %d,%d)")
    :format(name, planet, cx, cy))
  return record
end

----------------------------------------------------------------------------
-- Поддержание платформы неподвижной
----------------------------------------------------------------------------

script.on_nth_tick(ENFORCE_TICKS, function()
  local state = storage.asteroid_telescope
  if not state then return end
  for i = #state.platforms, 1, -1 do
    local record = state.platforms[i]
    local platform = record.platform
    if platform and platform.valid and platform.scheduled_for_deletion == 0 then
      enforce_immobile(platform)
    else
      table.remove(state.platforms, i)
    end
  end
end)

-- Ручную постройку двигателя на астероиде запрещаем сразу.
-- Остальное строить можно и руками, и дронами.
script.on_event(defines.events.on_pre_build, function(event)
  local player = game.get_player(event.player_index)
  if not (player and player.valid) then return end
  local surf = player.surface
  local platform = surf and surf.platform
  if not is_asteroid_platform(platform) then return end

  local stack = player.cursor_stack
  if stack and stack.valid_for_read and stack.name == "thruster" then
    player.print({ "asteroid-telescope.no-thrusters" })
    return false
  end
end)

----------------------------------------------------------------------------
-- Поиск по таймеру
----------------------------------------------------------------------------

local function count_valid(state)
  local valid = 0
  for i = #state.platforms, 1, -1 do
    local record = state.platforms[i]
    local platform = record.platform
    if platform and platform.valid and platform.scheduled_for_deletion == 0 then
      valid = valid + 1
    else
      table.remove(state.platforms, i)
    end
  end
  return valid
end

local function telescope_powered(telescope)
  local ok, powered = pcall(function()
    return telescope.is_connected_to_electric_network()
  end)
  return ok and powered
end

local function notify_found(force, record)
  if force then
    force.print({ "asteroid-telescope.found", record.name })
  end
end

script.on_nth_tick(SEARCH_TICKS, function()
  -- В моде на одно событие/тик может быть только один обработчик, поэтому
  -- не перехватываем on_built_entity (его уже занимает script/carkas.lua),
  -- а периодически ищем телескопы на планетных поверхностях.
  local state = get_state()
  local found = count_valid(state)
  if found >= MAX_ASTEROIDS then return end

  for _, surf in pairs(game.surfaces) do
    if surf.valid and surf.planet then
      local telescopes = surf.find_entities_filtered({ name = TELESCOPE })
      for _, telescope in ipairs(telescopes) do
        if telescope.valid and telescope_powered(telescope) and math.random() < SEARCH_CHANCE then
          local record = create_asteroid_platform(telescope.force, surf.planet.name)
          if record then
            found = found + 1
            notify_found(telescope.force, record)
            if found >= MAX_ASTEROIDS then return end
          end
        end
      end
    end
  end
end)

----------------------------------------------------------------------------
-- Команды и remote-интерфейс (для ручной проверки)
----------------------------------------------------------------------------

local function reply(player, message)
  if player and player.valid then
    player.print(message)
  else
    game.print(message)
  end
end

commands.add_command("asteroid-find", "Найти астероид у текущей планеты (для проверки)", function(event)
  local player = game.get_player(event.player_index)
  if not (player and player.valid) then return end
  local surf = player.surface
  if not (surf and surf.valid and surf.planet) then
    reply(player, "[asteroid] нужно стоять на планетной поверхности")
    return
  end
  local record, err = create_asteroid_platform(player.force, surf.planet.name)
  if record then
    reply(player, ("[asteroid] найден %s, поверхность: %s"):format(record.name, record.platform.surface.name))
  else
    reply(player, "[asteroid] не удалось создать: " .. tostring(err))
  end
end)

commands.add_command("asteroid-list", "Показать найденные астероиды", function(event)
  local player = game.get_player(event.player_index)
  local state = get_state()
  local count = count_valid(state)
  if count == 0 then
    reply(player, "[asteroid] пока ничего не найдено")
    return
  end
  reply(player, ("[asteroid] найдено %d:"):format(count))
  for _, record in ipairs(state.platforms) do
    local platform = record.platform
    if platform and platform.valid then
      local surf = platform.surface
      reply(player, ("  %s (планета %s, поверхность %s, хаб %s)"):format(
        record.name,
        tostring(record.planet),
        surf and surf.name or "?",
        tostring(platform.hub ~= nil)))
    end
  end
end)

commands.add_command("asteroid-cleanup", "Удалить все найденные астероиды", function(event)
  local player = game.get_player(event.player_index)
  local state = get_state()
  local removed = 0
  for _, record in ipairs(state.platforms) do
    local platform = record.platform
    if platform and platform.valid then
      pcall(function() platform.destroy(1) end)
      removed = removed + 1
    end
  end
  state.platforms = {}
  reply(player, ("[asteroid] удалено платформ: %d"):format(removed))
end)

remote.add_interface("asteroid-telescope", {
  find = function(planet)
    local force = game.forces.player
    local record, err = create_asteroid_platform(force, planet or "nauvis")
    if not record then return "error: " .. tostring(err) end
    return ("%s surface=%s hub=%s paused=%s speed=%s")
      :format(record.name, record.platform.surface.name,
        tostring(record.platform.hub ~= nil), tostring(record.platform.paused), tostring(record.platform.speed))
  end,
  list = function()
    local state = get_state()
    local names = {}
    for _, record in ipairs(state.platforms) do
      if record.platform and record.platform.valid then
        names[#names + 1] = record.name
      end
    end
    return table.concat(names, ",")
  end,
  cleanup = function()
    local state = get_state()
    local removed = 0
    for _, record in ipairs(state.platforms) do
      local platform = record.platform
      if platform and platform.valid then
        pcall(function() platform.destroy(1) end)
        removed = removed + 1
      end
    end
    state.platforms = {}
    return removed
  end,
})