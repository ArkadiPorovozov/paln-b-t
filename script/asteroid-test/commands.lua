local shared = require("script.asteroid-test.shared")
local surface_module = require("script.asteroid-test.surface")

local SURFACE_LABEL = "platform (space platform, asteroids persist)"

local function reply(player, message)
  if player and player.valid then
    player.print(message)
  else
    game.print(message)
  end
end

local function get_entity(state)
  local records = state.asteroids
  if records then
    for _, record in ipairs(records) do
      local entity = record.entity
      if entity and entity.valid then return entity end
    end
  end
  local entity = state.asteroid
  if entity and entity.valid then return entity end
  return nil
end

local function valid_records(state)
  local result = {}
  for _, record in ipairs(state.asteroids or {}) do
    if record.entity and record.entity.valid then
      result[#result + 1] = record
    end
  end
  return result
end

commands.add_command("ast-test-start", "Create an empty asteroid test platform and spawn 4 big asteroids", function(event)
  local player = shared.get_player(event)
  local state = shared.get_state()
  shared.last_create_error = nil

  local surf = surface_module.ensure()
  if not surf then
    reply(player, "[ast-test] surface=" .. SURFACE_LABEL)
    reply(player, "[ast-test] surface create failed: " .. tostring(shared.last_create_error))
    return
  end

  state.surface_index = surf.index
  state.running = true
  state.tick_acc = 0
  state.vel = {x = 0, y = 0}
  state.target = {x = 0, y = 8}

  surface_module.clear_asteroids(surf)
  state.asteroid = nil
  state.asteroids = surface_module.spawn_asteroids(surf, {x = 0, y = 0})
  local first = state.asteroids[1]
  if first then
    state.asteroid = first.entity
    state.asteroid_kind = first.kind
  end

  if player then
    surface_module.focus_player(player, surf)
    reply(player, "[ast-test] surface=" .. SURFACE_LABEL)
    local count = #state.asteroids
    local total = #shared.asteroid_types
    if count > 0 then
      local kinds = {}
      for _, record in ipairs(state.asteroids) do
        kinds[#kinds + 1] = record.kind
      end
      reply(player, ("[ast-test] spawned %d/%d big asteroids: %s"):format(count, total, table.concat(kinds, ", ")))
      reply(player, "[ast-test] ALT + right click to set target, /ast-test-debug for state")
    else
      reply(player, "[ast-test] asteroid spawn failed: " .. tostring(shared.last_create_error))
    end
    if count > 0 and count < total then
      reply(player, "[ast-test] spawn errors: " .. tostring(shared.last_create_error))
    end
  end
end)

commands.add_command("ast-test-stop", "Stop steering the test asteroids", function(event)
  local state = shared.get_state()
  state.running = false
  reply(shared.get_player(event), "[ast-test] stopped")
end)

commands.add_command("ast-test-speed", "Set asteroid speed in tiles per tick", function(event)
  local state = shared.get_state()
  local value = event.parameter and tonumber(event.parameter)
  if value then
    state.speed = math.max(0.001, math.min(1, value))
  end
  reply(shared.get_player(event), "[ast-test] speed=" .. tostring(state.speed))
end)

commands.add_command("ast-test-target", "Set target position: /ast-test-target x y", function(event)
  local state = shared.get_state()
  local x, y = event.parameter and event.parameter:match("^%s*([%d%.%-]+)%s+([%d%.%-]+)")
  if x and y then
    state.target = {x = tonumber(x), y = tonumber(y)}
  end
  if state.target then
    reply(shared.get_player(event), ("[ast-test] target=(%.2f, %.2f)"):format(state.target.x, state.target.y))
  else
    reply(shared.get_player(event), "[ast-test] no target")
  end
end)

commands.add_command("ast-test-velocity", "Read and test writing LuaEntity.velocity", function(event)
  local state = shared.get_state()
  local player = shared.get_player(event)
  local entity = get_entity(state)
  if not entity then
    reply(player, "[ast-test] no asteroid")
    return
  end
  local ok_read, old = pcall(function() return entity.velocity end)
  local ok_write, err = pcall(function() entity.velocity = {x = 0.01, y = 0.01} end)
  if ok_write and ok_read and type(old) == "table" then
    pcall(function() entity.velocity = old end)
  end
  reply(player, "velocity read=" .. tostring(ok_read) .. " write=" .. tostring(ok_write))
  if not ok_write then
    reply(player, "write error: " .. tostring(err))
  end
  if ok_read and type(old) == "table" then
    reply(player, ("old=(%.4f, %.4f)"):format(old.x or 0, old.y or 0))
  end
end)

commands.add_command("ast-test-status", "Show which test surface and steering mode are active", function(event)
  local state = shared.get_state()
  local player = shared.get_player(event)
  reply(player, "[ast-test] surface=" .. SURFACE_LABEL)
  reply(player, "[ast-test] steering=persist, running=" .. tostring(state.running))
  reply(player, "[ast-test] asteroids=" .. tostring(#valid_records(state)) .. "/" .. tostring(#shared.asteroid_types))
end)

commands.add_command("ast-test-debug", "Print asteroid test state", function(event)
  local state = shared.get_state()
  local player = shared.get_player(event)
  reply(player, "surface=" .. SURFACE_LABEL)
  reply(player, "steering=persist running=" .. tostring(state.running))
  reply(player, "speed=" .. tostring(state.speed))
  local records = valid_records(state)
  if #records == 0 then
    reply(player, "no asteroids")
    return
  end
  for i, record in ipairs(records) do
    local entity = record.entity
    reply(player, ("#%d %s pos=(%.2f, %.2f)"):format(i, tostring(record.name), entity.position.x, entity.position.y))
  end
  if state.target then
    reply(player, ("target=(%.2f, %.2f)"):format(state.target.x, state.target.y))
  end
end)

commands.add_command("ast-test-cleanup", "Delete the asteroid test platform", function(event)
  local state = shared.get_state()
  state.running = false
  state.asteroid = nil
  state.asteroid_kind = nil
  state.asteroids = nil
  state.target = nil
  local ok, err = surface_module.cleanup()
  reply(shared.get_player(event), "[ast-test] cleanup=" .. tostring(ok) .. (ok and "" or (" " .. tostring(err))))
end)