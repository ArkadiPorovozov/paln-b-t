local PREFIX = "pcg-ghost"

local THROW = {
  grenade = "grenade",
  ["cluster-grenade"] = "cluster-grenade",
  ["poison-capsule"] = "poison-capsule",
  ["slowdown-capsule"] = "slowdown-capsule"
}

local function enabled()
  return settings.global["pcg-enabled"].value
end

local function init()
  storage.pending = storage.pending or {}
  storage.ghosts = storage.ghosts or {}
  storage.by_corpse = storage.by_corpse or {}
  storage.by_unit = storage.by_unit or {}
  storage.respawns = storage.respawns or {}
end

script.on_init(function()
  init()
  storage.force_ready = false
end)
script.on_configuration_changed(function()
  init()
  storage.force_ready = false
end)

local function dist2(a, b)
  local dx = a.x - b.x
  local dy = a.y - b.y
  return dx * dx + dy * dy
end

local function is_ghost_name(name)
  return name == PREFIX or string.sub(name, 1, 10) == "pcg-ghost-"
end

local function ghost_force()
  local f = game.forces["pcg-ghosts"]
  if not f then
    f = game.create_force("pcg-ghosts")
  end
  if not storage.force_ready then
    f.ai_controllable = true
    for _, other in pairs(game.forces) do
      if other.name ~= f.name then
        f.set_friend(other, false)
        f.set_cease_fire(other, false)
        other.set_friend(f, false)
        other.set_cease_fire(f, false)
      end
    end
    storage.force_ready = true
  end
  return f
end

local function throwable(name, proto)
  if THROW[name] then
    return true
  end
  return proto and proto.type == "capsule" and prototypes.entity[name] and name ~= "raw-fish"
end

local function scan_nades(inv, into)
  if not inv then
    return
  end
  for i = 1, #inv do
    local s = inv[i]
    if s.valid_for_read and throwable(s.name, s.prototype) then
      into[s.name] = true
    end
  end
end

local function snapshot(ch)
  local snap = { grenades = {} }
  local guns = ch.get_inventory(defines.inventory.character_guns)
  if guns then
    local i = ch.selected_gun_index or 1
    if guns[i] and guns[i].valid_for_read then
      snap.gun = guns[i].name
    else
      for j = 1, #guns do
        if guns[j].valid_for_read then
          snap.gun = guns[j].name
          break
        end
      end
    end
  end
  scan_nades(ch.get_main_inventory(), snap.grenades)
  local c = ch.cursor_stack
  if c and c.valid_for_read and throwable(c.name, c.prototype) then
    snap.grenades[c.name] = true
  end
  return snap
end

local function around(pos, radius)
  local a = math.random() * math.pi * 2
  local d = 2 + math.random() * math.max(1, radius)
  return { x = pos.x + math.cos(a) * d, y = pos.y + math.sin(a) * d }
end

local function dir_to(from, to)
  local dx = to.x - from.x
  local dy = to.y - from.y
  if dx == 0 and dy == 0 then
    return defines.direction.north
  end
  local angle = math.atan2(dx, -dy)
  if angle < 0 then
    angle = angle + 2 * math.pi
  end
  return (math.floor(angle / (2 * math.pi) * 8 + 0.5) % 8) * 2
end

local function set_cmd(ghost, cmd)
  local ok, c = pcall(function()
    return ghost.commandable
  end)
  if not ok or not c then
    return false
  end
  pcall(function()
    c.set_command(cmd)
  end)
  return true
end

local function walk_to(ghost, dest)
  local pos = ghost.position
  local d2 = dist2(pos, dest)
  local dir = dir_to(pos, dest)
  if d2 < 0.36 then
    pcall(function()
      ghost.walking_state = { walking = false, direction = dir }
    end)
    return true
  end
  pcall(function()
    ghost.direction = dir
    ghost.walking_state = { walking = true, direction = dir }
  end)
  return false
end

local function find_player(ghost, origin, radius)
  local r2 = radius * radius
  local best
  local best_d
  for _, p in pairs(game.players) do
    local ch = p.character
    if ch and ch.valid and ch.surface == ghost.surface and not is_ghost_name(ch.name) then
      local d = dist2(ch.position, origin)
      if d <= r2 and (not best_d or d < best_d) then
        best = ch
        best_d = d
      end
    end
  end
  return best
end

local function order(entry)
  local ghost = entry.entity
  local corpse = entry.corpse
  if not (ghost and ghost.valid and corpse and corpse.valid) then
    return
  end
  local radius = settings.global["pcg-guard-radius"].value
  local cpos = corpse.position
  if dist2(ghost.position, cpos) > radius * radius then
    entry.dest = cpos
    if not set_cmd(ghost, {
      type = defines.command.go_to_location,
      destination = cpos,
      radius = 2,
      distraction = defines.distraction.none
    }) then
      walk_to(ghost, cpos)
    end
    return
  end
  local target = find_player(ghost, cpos, radius)
  entry.target = target
  if target then
    entry.dest = target.position
    if not set_cmd(ghost, {
      type = defines.command.attack,
      target = target,
      distraction = defines.distraction.none
    }) then
      walk_to(ghost, target.position)
    end
  else
    local dest = around(cpos, 5)
    entry.dest = dest
    if not set_cmd(ghost, {
      type = defines.command.go_to_location,
      destination = dest,
      radius = 1.2,
      distraction = defines.distraction.none
    }) then
      walk_to(ghost, dest)
    end
  end
end

local function unregister(entry)
  if entry.ghost_reg then
    storage.ghosts[entry.ghost_reg] = nil
  end
  if entry.corpse_reg and storage.by_corpse[entry.corpse_reg] == entry then
    storage.by_corpse[entry.corpse_reg] = nil
  end
  if entry.unit_number then
    storage.by_unit[entry.unit_number] = nil
  end
end

local function kill_ghost(entry, animate)
  entry.dead = true
  local ghost = entry.entity
  unregister(entry)
  if ghost and ghost.valid then
    if animate then
      pcall(function()
        ghost.die()
      end)
    else
      ghost.destroy()
    end
  end
end

local function schedule(entry)
  if entry.dead or not entry.corpse_reg then
    return
  end
  local corpse = entry.corpse
  if not (corpse and corpse.valid) then
    return
  end
  if storage.respawns[entry.corpse_reg] then
    return
  end
  storage.respawns[entry.corpse_reg] = {
    snap = entry.snap,
    corpse = corpse,
    tick = game.tick + settings.global["pcg-respawn-seconds"].value * 60
  }
end

local spawn_ghost

local function corpse_gone(corpse)
  for _, entry in pairs(storage.by_corpse) do
    if entry.corpse == corpse then
      if entry.corpse_reg then
        storage.respawns[entry.corpse_reg] = nil
      end
      kill_ghost(entry, true)
      break
    end
  end
  for key, job in pairs(storage.respawns) do
    if job.corpse == corpse then
      storage.respawns[key] = nil
    end
  end
end

local function throw_nades(entry, ghost, target, tick)
  local nades = entry.snap.grenades
  if not nades or not next(nades) then
    return
  end
  if (entry.next_throw or 0) > tick then
    return
  end
  if dist2(ghost.position, target.position) > 400 then
    return
  end
  local item = next(nades)
  local proj = THROW[item] or item
  if not prototypes.entity[proj] then
    return
  end
  local ok = pcall(function()
    ghost.surface.create_entity({
      name = proj,
      position = ghost.position,
      target = target,
      source = ghost,
      force = ghost.force,
      speed = 0.3
    })
  end)
  if ok then
    entry.next_throw = tick + 600
  end
end

spawn_ghost = function(snap, corpse)
  if not enabled() or not snap or not corpse or not corpse.valid then
    return
  end
  for _, entry in pairs(storage.by_corpse) do
    if entry.corpse == corpse then
      return
    end
  end
  scan_nades(corpse.get_inventory(defines.inventory.character_corpse), snap.grenades)
  local name = PREFIX
  if snap.gun and prototypes.entity[PREFIX .. "-" .. snap.gun] then
    name = PREFIX .. "-" .. snap.gun
  end
  if not prototypes.entity[name] then
    return
  end
  local cpos = corpse.position
  local guess = around(cpos, 3)
  local pos = corpse.surface.find_non_colliding_position(name, guess, 10, 0.5) or guess
  local ghost = corpse.surface.create_entity({
    name = name,
    position = pos,
    force = ghost_force()
  })
  if not ghost or not ghost.valid then
    return
  end
  pcall(function()
    ghost.health = ghost.max_health
  end)
  local greg = script.register_on_object_destroyed(ghost)
  local creg = script.register_on_object_destroyed(corpse)
  if not greg or not creg then
    ghost.destroy()
    return
  end
  local entry = {
    entity = ghost,
    corpse = corpse,
    snap = snap,
    ghost_reg = greg,
    corpse_reg = creg,
    unit_number = ghost.unit_number,
    next_throw = 0,
    dest = around(cpos, 5)
  }
  storage.ghosts[greg] = entry
  storage.by_corpse[creg] = entry
  if ghost.unit_number then
    storage.by_unit[ghost.unit_number] = entry
  end
  storage.respawns[creg] = nil
  order(entry)
end

script.on_event(defines.events.on_tick, function(event)
  if not storage.ghosts then
    init()
  end
  local tick = event.tick
  if next(storage.ghosts) then
    for _, entry in pairs(storage.ghosts) do
      local ghost = entry.entity
      local corpse = entry.corpse
      if not ghost or not ghost.valid then
        -- cleaned by destroy handler
      elseif not corpse or not corpse.valid then
        entry.dead = true
        kill_ghost(entry, true)
      else
        local cmd
        pcall(function()
          cmd = ghost.commandable
        end)
        if not cmd then
          if not entry.dest or walk_to(ghost, entry.dest) then
            order(entry)
          end
          local t = entry.target
          if t and t.valid and dist2(ghost.position, t.position) < 2.25 then
            pcall(function()
              t.damage(12, ghost.force, "physical", ghost, ghost)
            end)
          end
        elseif tick % 60 == 0 then
          local t = find_player(ghost, corpse.position, settings.global["pcg-guard-radius"].value)
          if t then
            throw_nades(entry, ghost, t, tick)
          end
          order(entry)
        end
      end
    end
  end
  if storage.respawns and tick % 15 == 0 then
    for key, job in pairs(storage.respawns) do
      if tick >= job.tick then
        storage.respawns[key] = nil
        if job.corpse and job.corpse.valid then
          spawn_ghost(job.snap, job.corpse)
        end
      end
    end
  end
end)

script.on_event(defines.events.on_ai_command_completed, function(event)
  if event.was_destroyed or not event.unit_number then
    return
  end
  local entry = storage.by_unit and storage.by_unit[event.unit_number]
  if entry then
    order(entry)
  end
end)

script.on_event(defines.events.on_pre_player_died, function(event)
  if not enabled() then
    return
  end
  local player = game.get_player(event.player_index)
  local ch = player and player.character
  if not ch or not ch.valid or is_ghost_name(ch.name) then
    return
  end
  storage.pending[ch.unit_number or -player.index] = snapshot(ch)
end)

script.on_event(defines.events.on_post_entity_died, function(event)
  local proto = event.prototype
  if not proto then
    return
  end
  if is_ghost_name(proto.name) then
    if event.corpses then
      for _, leftover in pairs(event.corpses) do
        if leftover.valid then
          leftover.destroy()
        end
      end
    end
    return
  end
  if proto.type ~= "character" or not event.corpses then
    return
  end
  local snap
  if event.unit_number then
    snap = storage.pending[event.unit_number]
    storage.pending[event.unit_number] = nil
  end
  if not snap then
    for key, pending in pairs(storage.pending or {}) do
      snap = pending
      storage.pending[key] = nil
      break
    end
  end
  if not snap then
    return
  end
  for _, entity in pairs(event.corpses) do
    if entity.valid and entity.type == "character-corpse" then
      spawn_ghost(snap, entity)
      return
    end
  end
end)

script.on_event(defines.events.on_entity_died, function(event)
  local entity = event.entity
  if not entity or not is_ghost_name(entity.name) then
    return
  end
  local entry = entity.unit_number and storage.by_unit[entity.unit_number]
  if not entry then
    return
  end
  if not entry.dead then
    schedule(entry)
  end
  unregister(entry)
end)

local function on_corpse_mined(event)
  local entity = event.entity
  if entity and entity.valid and entity.type == "character-corpse" then
    corpse_gone(entity)
  end
end

local corpse_filter = { { filter = "type", type = "character-corpse" } }
script.on_event(defines.events.on_pre_player_mined_item, on_corpse_mined, corpse_filter)
script.on_event(defines.events.on_robot_pre_mined, on_corpse_mined, corpse_filter)
if defines.events.on_space_platform_pre_mined then
  script.on_event(defines.events.on_space_platform_pre_mined, on_corpse_mined, corpse_filter)
end

script.on_event(defines.events.on_character_corpse_expired, function(event)
  if event.corpse and event.corpse.valid then
    corpse_gone(event.corpse)
  end
end)

script.on_event(defines.events.on_object_destroyed, function(event)
  local reg = event.registration_number
  if not reg then
    return
  end
  storage.respawns[reg] = nil
  if storage.by_corpse[reg] then
    kill_ghost(storage.by_corpse[reg], true)
    return
  end
  local entry = storage.ghosts[reg]
  if entry then
    if not entry.dead then
      schedule(entry)
    end
    unregister(entry)
  end
end)

commands.add_command("pcg-die", "Kill your character (test ghost)", function(event)
  local player = game.get_player(event.player_index)
  if player and player.character and player.character.valid then
    player.character.die()
  end
end)
