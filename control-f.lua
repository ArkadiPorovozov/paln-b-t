local config = require("shared")

local STATE  = { LANDED = "landed", TAKEOFF = "takeoff",
                 FLYING = "flying", LANDING = "landing" }
local PHASES = { [STATE.TAKEOFF] = "takeoff", [STATE.LANDING] = "landing" }
local FINAL  = { [STATE.TAKEOFF] = STATE.FLYING, [STATE.LANDING] = STATE.LANDED }
local LAYERS = { "gear", "thruster" }

local RIDE_STOP     = defines.riding.acceleration.nothing
local RIDE_FORWARD  = defines.riding.acceleration.accelerating
local RIDE_REVERSE  = defines.riding.acceleration.reversing
local TURN_STRAIGHT = defines.riding.direction.straight

local LAYER_OF = {
  thruster = "render_layer_thruster", thruster_emission = "render_layer_emission",
  gear     = "render_layer_gear",     gear_emission     = "render_layer_emission",
  body     = "render_layer_body",     body_emission     = "render_layer_emission",
}

local function init_storage() storage.craft = storage.craft or {} end

local function lerp(a, b, t) return a + (b - a) * t end

local function clamp01(x)
  if x < 0 then return 0 elseif x > 1 then return 1 end
  return x
end

local function ease(x)
  x = clamp01(x)
  if config.behaviour.altitude.easing == "ease" then return x * x * (3 - 2 * x) end
  return x
end

local function is_ours(entity)
  return entity ~= nil and entity.valid and entity.name == config.entity_name
end

local function is_thrusting(craft)
  local riding = craft.entity.valid and craft.entity.riding_state
  if not riding then return false end
  if riding.acceleration == RIDE_FORWARD then return true end
  return riding.acceleration == RIDE_REVERSE and not config.behaviour.flight.forbid_reverse
end

local function has_fuel(craft)
  local burner = craft.entity.valid and craft.entity.burner
  if not burner then return true end
  if (burner.remaining_burning_fuel or 0) > 0 then return true end
  local inv = burner.inventory
  return inv ~= nil and inv.valid and not inv.is_empty()
end

local function is_occupied(entity)
  return entity.valid
     and (entity.get_driver() ~= nil or entity.get_passenger() ~= nil)
end

local function phase_list(craft)
  local key = PHASES[craft.state]
  return key and config.phases[key] or nil
end

local function destroy_render(craft, key)
  local obj = craft.render[key]
  if obj and obj.valid then obj.destroy() end
  craft.render[key] = nil
end

local function clear_layer(craft, key)
  destroy_render(craft, key)
  destroy_render(craft, key .. "_emission")
  craft.clip_left[key], craft.clip_total[key], craft.clip_name[key] = nil, nil, nil
end

local function destroy_all_render(craft)
  for key in pairs(craft.render) do destroy_render(craft, key) end
end

local function apply_lift(craft)
  local entity = craft.entity
  if not entity.valid then return end

  local wanted = config.behaviour.altitude.body_lift * (craft.altitude or 0)
  local delta  = wanted - (craft.lift_applied or 0)
  if math.abs(delta) < 1e-6 then return end

  local position = entity.position
  if entity.teleport({ position.x, position.y - delta }) then
    craft.lift_applied = wanted
  end
end

local function draw(craft, key, animation_name, speed, frame, fixed, still)
  local params =
  {
    surface = craft.entity.surface,
    target = craft.entity,
    render_layer = config.behaviour[LAYER_OF[key] or "render_layer_gear"],
  }

  if fixed then
    params.orientation = fixed
  else
    params.orientation_target, params.use_target_orientation = craft.entity, true
  end

  if still then
    params.sprite = animation_name
    craft.render[key] = rendering.draw_sprite(params)
  else
    params.animation = animation_name
    params.animation_speed = speed or 0
    params.animation_offset = frame or 0
    craft.render[key] = rendering.draw_animation(params)
  end

  return craft.render[key]
end

local function compute_altitude(craft)
  if craft.state == STATE.FLYING then return 1 end
  if craft.state == STATE.LANDED  then return 0 end

  local list = phase_list(craft)
  local ph = list and list[craft.phase]
  if not ph then return craft.altitude or 0 end

  local total = config.phase_ticks(ph)
  local progress = (total > 0) and clamp01((total - (craft.left or 0)) / total) or 1
  local from = config.phase_alt_from(list, craft.phase,
                                     (craft.state == STATE.TAKEOFF) and 0 or 1)
  return lerp(from, ph.alt or from, ease(progress))
end

local function update_shadow(craft)
  local altitude = craft.altitude or 0
  local shadow   = config.behaviour.shadow
  local wanted   = (altitude <= (shadow.min_altitude or 0)) and "landed" or "flight"

  if craft.shadow_kind ~= wanted or not (craft.render.shadow and craft.render.shadow.valid) then
    destroy_render(craft, "shadow")

    local in_flight = (wanted == "flight")
    local params =
    {
      surface = craft.entity.surface,
      target = craft.entity,
      render_layer = config.behaviour.render_layer_shadow,
    }

    if in_flight and shadow.rotate_in_flight then
      params.orientation_target, params.use_target_orientation = craft.entity, true
      params.orientation = shadow.orientation_offset or 0
    else
      params.orientation = shadow.orientation or 0
    end

    if in_flight then
      params.animation = config.anim.shadow_flight
      params.animation_speed = 0
      params.animation_offset = craft.body_frame or 0
      craft.render.shadow = rendering.draw_animation(params)
    else
      params.sprite = config.anim.shadow_landed
      craft.render.shadow = rendering.draw_sprite(params)
    end
    craft.shadow_kind = wanted
  end

  local sprite = craft.render.shadow
  if not (sprite and sprite.valid) then return end

  sprite.target =
  {
    type = "entity",
    entity = craft.entity,
    offset = { shadow.max_offset[1] * altitude,
               shadow.max_offset[2] * altitude + (craft.lift_applied or 0) },
  }
  if craft.shadow_kind == "flight" then
    sprite.animation_offset = math.floor(craft.body_frame or 0)
  end
  sprite.x_scale = shadow.scale or 1
  sprite.y_scale = shadow.scale or 1
  sprite.color = { r = 1, g = 1, b = 1,
                   a = lerp(shadow.alpha_ground, shadow.alpha_air, altitude) }
end

local function is_moving(craft)
  if not craft.entity.valid then return false end
  return math.abs(craft.entity.speed or 0) > (config.behaviour.flight.moving_threshold or 0.004)
end

local function is_turning(craft)
  local riding = craft.entity.valid and craft.entity.riding_state
  return riding ~= nil and riding.direction ~= TURN_STRAIGHT
end

local function update_body_frame(craft)
  local flight, sheet = config.behaviour.flight, config.sheets.body
  local ratio = 0

  if is_moving(craft) then
    local full = flight.body_full_speed or 0.5
    ratio = (full > 0) and math.min(1, math.abs(craft.entity.speed or 0) / full) or 1
  end

  if is_turning(craft) then
    ratio = math.max(ratio, flight.body_turn_speed or 0)
  end

  if ratio > 0 then
    craft.body_frame = ((craft.body_frame or 0) + sheet.speed * ratio) % sheet.frames
  end

  local frame = math.floor(craft.body_frame or 0)
  for _, key in ipairs({"body", "body_emission"}) do
    local obj = craft.render[key]
    if obj and obj.valid then obj.animation_offset = frame end
  end

  if craft.shadow_kind == "flight" then
    local obj = craft.render.shadow
    if obj and obj.valid then obj.animation_offset = frame end
  end
end

local function emission_offset(craft)
  local shift = config.behaviour.flight.emission_offset or { 0, 0 }
  local angle = (craft.entity.orientation or 0) * 2 * math.pi
  local sin, cos = math.sin(angle), math.cos(angle)
  return { shift[1] * cos - shift[2] * sin, shift[1] * sin + shift[2] * cos }
end

local function ensure_body(craft)
  if craft.state ~= STATE.FLYING then
    destroy_render(craft, "body")
    destroy_render(craft, "body_emission")
    craft.emission_alpha, craft.body_frame = 0, 0
    return
  end

  if not (craft.render.body and craft.render.body.valid) then
    draw(craft, "body", config.anim.body, 0, craft.body_frame or 0)
  end

  local flight = config.behaviour.flight
  local lit = not flight.emission_with_thruster
           or (craft.clip_name.thruster
               and craft.render.thruster and craft.render.thruster.valid
               and flight.emission_clips[craft.clip_name.thruster] == true)

  local target = lit and 1 or 0
  local alpha  = craft.emission_alpha or 0
  local ticks  = (target > alpha) and (flight.emission_fade_in or 1)
                                   or (flight.emission_fade_out or 1)
  local step   = 1 / math.max(1, ticks)

  alpha = (alpha < target) and math.min(target, alpha + step)
       or (alpha > target) and math.max(target, alpha - step)
       or alpha
  craft.emission_alpha = alpha

  if alpha <= 0 then
    destroy_render(craft, "body_emission")
  else
    if not (craft.render.body_emission and craft.render.body_emission.valid) then
      draw(craft, "body_emission", config.anim.body_emission, 0, craft.body_frame or 0)
    end
    local obj = craft.render.body_emission
    if obj and obj.valid then
      obj.color = { r = alpha, g = alpha, b = alpha, a = alpha }
      obj.target = { type = "entity", entity = craft.entity,
                     offset = emission_offset(craft) }
    end
  end

  update_body_frame(craft)
end

local function frame_at(sheet, t)
  return math.min(sheet.frames - 1, math.floor(clamp01(t) * (sheet.frames - 1) + 0.5))
end

local function phase_emission_alpha(progress)
  local window = config.behaviour.flight.phase_emission_fade or 0
  if window <= 0 then return 1 end
  return math.min(1, clamp01(progress) / window, clamp01(1 - progress) / window)
end

local function start_clip(craft, clip_name)
  local clip = config.clips[clip_name]
  if not clip then return end

  local sheet = config.sheets[clip.sheet]
  local key   = clip.layer or "gear"
  local fixed = (not clip.rotating) and config.behaviour.landed_orientation or nil

  clear_layer(craft, key)
  craft.clip_name[key] = clip_name

  if clip.loop then
    draw(craft, key, config.anim[clip_name], sheet.speed, 0, fixed)
    return
  end

  draw(craft, key, config.anim[clip_name], 0, 0, fixed)
  if clip.emission then
    local obj = draw(craft, key .. "_emission", config.anim[clip.emission], 0, 0, fixed)
    local alpha = phase_emission_alpha(0)
    obj.color = { r = alpha, g = alpha, b = alpha, a = alpha }
  end

  local total = config.duration(sheet)
  craft.clip_left[key], craft.clip_total[key] = total, total
end

local function hold_last_frame(craft, clip_name)
  local clip  = clip_name and config.clips[clip_name]
  local sheet = clip and config.sheets[clip.sheet]
  if not sheet then return end

  local key = clip.layer or "gear"
  clear_layer(craft, key)
  craft.clip_name[key] = clip_name
  draw(craft, key, config.anim[clip_name], 0, sheet.frames - 1,
       config.behaviour.landed_orientation)
end

local function finish_clip(craft, key)
  local clip_name = craft.clip_name[key]
  local clip = clip_name and config.clips[clip_name]
  craft.clip_left[key], craft.clip_total[key] = nil, nil
  if not clip then return end

  if clip.next then return start_clip(craft, clip.next) end

  local mode = clip.on_end or ((key == "thruster") and "hide" or "freeze")
  if mode == "hide" then clear_layer(craft, key)
  else hold_last_frame(craft, clip_name) end
end

local function advance_clips(craft)
  for _, key in ipairs(LAYERS) do
    local left = craft.clip_left[key]
    if left then
      left = left - 1
      if left > 0 then
        craft.clip_left[key] = left
        local clip  = config.clips[craft.clip_name[key]]
        local sheet = clip and config.sheets[clip.sheet]
        local total = craft.clip_total[key]
        if sheet and total and total > 1 then
          local progress = (total - left) / (total - 1)
          local frame = frame_at(sheet, progress)
          for _, part in ipairs({key, key .. "_emission"}) do
            local layer = craft.render[part]
            if layer and layer.valid then layer.animation_offset = frame end
          end

          local emission = craft.render[key .. "_emission"]
          if emission and emission.valid then
            local alpha = phase_emission_alpha(progress)
            emission.color = { r = alpha, g = alpha, b = alpha, a = alpha }
          end
        end
      else
        craft.clip_left[key] = nil
        finish_clip(craft, key)
      end
    end
  end
end

local function update_thruster(craft)
  local flight = config.behaviour.flight
  if craft.state ~= STATE.FLYING or not flight.thruster_only_when_moving then return end

  local cur   = craft.clip_name.thruster
  local alive = craft.render.thruster and craft.render.thruster.valid

  if is_thrusting(craft) then
    if not (alive and (cur == "thruster" or cur == "thruster_on")) then
      start_clip(craft, "thruster_on")
    end
  elseif alive and cur ~= "thruster_off" then
    start_clip(craft, "thruster_off")
  end
end

local function apply_movement(craft)
  local entity = craft.entity
  if not entity.valid then return end

  local flight = config.behaviour.flight
  local riding  = entity.riding_state

  if config.behaviour.lock_when_landed and craft.state ~= STATE.FLYING then
    entity.speed, entity.effectivity_modifier, entity.friction_modifier = 0, 0, 12
    entity.orientation = config.behaviour.landed_orientation
    if riding and (riding.direction ~= TURN_STRAIGHT or riding.acceleration ~= RIDE_STOP) then
      entity.riding_state = { acceleration = RIDE_STOP, direction = TURN_STRAIGHT }
    end
    return
  end

  entity.effectivity_modifier = 1
  entity.friction_modifier    = 1

  if flight.forbid_reverse then
    if riding and riding.acceleration == RIDE_REVERSE then
      entity.riding_state = { acceleration = RIDE_STOP, direction = riding.direction }
      entity.speed = 0
    elseif (entity.speed or 0) < 0 then
      entity.speed = 0
    end
  end

  local speed = entity.speed or 0

  if is_thrusting(craft) then
    if not has_fuel(craft) then
      local crawl = (flight.max_speed or 1) * (flight.no_fuel_speed or 0.08)
      if speed < crawl then entity.speed = crawl end
    end
  elseif speed > 0 then
    local slowed = speed - (flight.coast_friction or 0.012)
    entity.speed = (slowed > (flight.moving_threshold or 0.004)) and slowed or 0
  end

  local cap = flight.max_speed
  if cap and (entity.speed or 0) > cap then entity.speed = cap end
end

local function sync_equipment(craft, airborne)
  local grid = craft.entity.valid and craft.entity.grid
  if not (grid and grid.valid) then return end

  local pending = {}
  for _, equipment in pairs(grid.equipment) do
    local base = equipment.name:gsub("%-aircraft$", "")
    local wanted = airborne and (base .. "-aircraft") or base
    if equipment.name ~= wanted and prototypes.equipment[wanted] then
      pending[#pending + 1] = { equipment = equipment, wanted = wanted }
    end
  end

  for _, item in ipairs(pending) do
    local equipment = item.equipment
    if equipment.valid then
      local position, quality = equipment.position, equipment.quality
      local energy, shield = equipment.energy, equipment.shield

      grid.take{ equipment = equipment }
      local fresh = grid.put{ name = item.wanted, position = position, quality = quality }

      if fresh and fresh.valid then
        if energy then fresh.energy = math.min(energy, fresh.max_energy or energy) end
        if shield and (fresh.max_shield or 0) > 0 then
          fresh.shield = math.min(shield, fresh.max_shield)
        end
      end
    end
  end
end

local function enter_phase(craft, index)
  local list = phase_list(craft)
  local ph = list and list[index]
  if not ph then return false end

  craft.phase, craft.left = index, config.phase_ticks(ph)
  for _, clip_name in ipairs(ph) do start_clip(craft, clip_name) end

  craft.altitude = compute_altitude(craft)
  apply_lift(craft)
  update_shadow(craft)
  return true
end

local function set_state(craft, state)
  craft.state, craft.phase, craft.left = state, nil, 0
  craft.clip_left  = craft.clip_left  or {}
  craft.clip_total = craft.clip_total or {}
  craft.clip_name  = craft.clip_name  or {}
  craft.idle_ticks = 0

  if state == STATE.LANDED then
    clear_layer(craft, "thruster")
    hold_last_frame(craft, "gear_land")
    craft.altitude = 0

  elseif state == STATE.FLYING then
    clear_layer(craft, "gear")
    if config.behaviour.flight.thruster_only_when_moving then
      clear_layer(craft, "thruster")
    elseif craft.clip_name.thruster ~= "thruster" then
      start_clip(craft, "thruster")
    end
    craft.altitude = 1

  else
    enter_phase(craft, 1)
  end

  ensure_body(craft)
  apply_lift(craft)
  update_shadow(craft)
  apply_movement(craft)
  sync_equipment(craft, state == STATE.FLYING)
end

local function toggle_flight(craft, player)
  local next_state = (craft.state == STATE.LANDED) and STATE.TAKEOFF
                  or (craft.state == STATE.FLYING) and STATE.LANDING
  if not next_state then return false end

  set_state(craft, next_state)
  if player then
    player.play_sound{ path = "utility/build_medium", position = craft.entity.position }
  end
  return true
end

local function register(entity, state)
  init_storage()
  local craft = { entity = entity, state = nil, phase = nil, left = 0,
                altitude = 0, lift_applied = 0, emission_alpha = 0,
                body_frame = 0, idle_ticks = 0,
                render = {}, clip_left = {}, clip_total = {}, clip_name = {} }
  storage.craft[entity.unit_number] = craft
  set_state(craft, state or config.behaviour.spawn_state)
  return craft
end

local function unregister(unit_number)
  init_storage()
  local craft = storage.craft[unit_number]
  if not craft then return end
  destroy_all_render(craft)
  storage.craft[unit_number] = nil
end

local function check_abandoned(craft)
  if craft.state ~= STATE.FLYING or not config.behaviour.land_on_exit then
    craft.idle_ticks = 0
    return
  end

  if is_occupied(craft.entity) then
    craft.idle_ticks = 0
    return
  end

  craft.idle_ticks = (craft.idle_ticks or 0) + 1
  if craft.idle_ticks >= (config.behaviour.auto_land_delay or 120) then
    craft.idle_ticks = 0
    toggle_flight(craft, nil)
  end
end

local filter = {{ filter = "name", name = config.entity_name }}

local function on_built(event)
  local entity = event.entity or event.destination
  if is_ours(entity) then register(entity) end
end

local function on_removed(event)
  if is_ours(event.entity) then unregister(event.entity.unit_number) end
end

for _, ev in ipairs({"on_built_entity", "on_robot_built_entity",
                     "on_space_platform_built_entity", "script_raised_built",
                     "script_raised_revive"}) do
  script.on_event(defines.events[ev], on_built, filter)
end

for _, ev in ipairs({"on_player_mined_entity", "on_robot_mined_entity",
                     "on_space_platform_mined_entity", "on_entity_died",
                     "script_raised_destroy"}) do
  script.on_event(defines.events[ev], on_removed, filter)
end

script.on_event(defines.events.on_entity_cloned, function(event)
  if is_ours(event.destination) then register(event.destination) end
end)

script.on_event("flying-transport-toggle-flight", function(event)
  local player = game.get_player(event.player_index)
  local veh = player and player.vehicle
  if not is_ours(veh) then return end
  init_storage()
  toggle_flight(storage.craft[veh.unit_number] or register(veh), player)
end)

script.on_event(defines.events.on_player_driving_changed_state, function(event)
  local veh = event.entity
  if not is_ours(veh) then return end

  init_storage()
  local craft = storage.craft[veh.unit_number] or register(veh)
  local player = game.get_player(event.player_index)

  if is_occupied(veh) then
    craft.idle_ticks = 0
    if config.behaviour.takeoff_on_enter and craft.state == STATE.LANDED then
      toggle_flight(craft, player)
    end
  end
end)

script.on_event(defines.events.on_tick, function()
  if not storage.craft then return end

  for unit_number, craft in pairs(storage.craft) do
    if not craft.entity.valid then
      destroy_all_render(craft)
      storage.craft[unit_number] = nil

    elseif craft.phase then
      craft.left = craft.left - 1
      if craft.left > 0 then
        advance_clips(craft)
        craft.altitude = compute_altitude(craft)
        apply_lift(craft)
        update_shadow(craft)
        apply_movement(craft)
      else
        local list = phase_list(craft)
        local cur  = list and list[craft.phase]
        if not enter_phase(craft, craft.phase + 1) then
          if cur and cur.hold then
            for _, name in ipairs(cur) do
              local clip = config.clips[name]
              if clip and (clip.layer or "gear") == "gear" then
                hold_last_frame(craft, name)
              end
            end
          end
          set_state(craft, FINAL[craft.state] or STATE.LANDED)
        end
      end

    else
      advance_clips(craft)
      update_thruster(craft)
      ensure_body(craft)
      apply_movement(craft)
      check_abandoned(craft)

      craft.equipment_check = (craft.equipment_check or 0) + 1
      if craft.equipment_check >= 60 then
        craft.equipment_check = 0
        sync_equipment(craft, craft.state == STATE.FLYING)
      end
    end
  end
end)

local function rescan_all()
  init_storage()

  for _, obj in pairs(rendering.get_all_objects(script.mod_name)) do
    if obj.valid then obj.destroy() end
  end

  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{ name = config.entity_name }) do
      local craft = storage.craft[entity.unit_number]
      if craft then
        craft.entity, craft.render = entity, {}
        craft.clip_left, craft.clip_total, craft.clip_name = {}, {}, {}
        local st = craft.state
        if st == STATE.TAKEOFF then st = STATE.FLYING end
        if st == STATE.LANDING then st = STATE.LANDED end
        set_state(craft, st or config.behaviour.spawn_state)
      else
        register(entity)
      end
    end
  end
end

script.on_init(rescan_all)
script.on_configuration_changed(rescan_all)
