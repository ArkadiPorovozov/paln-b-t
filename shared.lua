
local config = {}

config.entity_name = "aircraft"

config.sheets =
{
  body =
  {
    path   = "__space-age__/graphics/entity/cargo-pod/pod-closed-rotation",
    frames = 59,
    speed  = 0.5,
    center = true,
    extra  = { priority = "medium", scale = 0.5 },
  },

  body_emission =
  {
    path   = "__space-age__/graphics/entity/cargo-pod/pod-closed-rotation-emission",
    frames = 59,
    speed  = 0.5,
    center = true,
    extra  = { priority = "medium", scale = 0.5, blend_mode = "additive", draw_as_glow = true },
  },

  thruster =
  {
    path   = "__base__/graphics/entity/cargo-pod/pod-thruster-loop",
    frames = 10,
    speed  = 0.5,
    extra  =
    {
      priority     = "medium",
      scale        = 0.25,
      draw_as_glow = true,
      blend_mode   = "additive",
      shift_px     = {0, 64},
      flags        = { "linear-minification", "linear-magnification" },
    },
  },

  thruster_start =
  {
    path   = "__base__/graphics/entity/cargo-pod/pod-thruster-ignition",
    frames = 10,
    speed  = 0.5,
    extra  =
    {
      priority     = "medium",
      scale        = 0.25,
      draw_as_glow = true,
      blend_mode   = "additive",
      shift_px     = {0, 64},
      flags        = { "linear-minification", "linear-magnification" },
    },
  },

  gear_open =
  {
    path   = "__base__/graphics/entity/cargo-pod/pod-opening",
    frames = 34,
    speed  = 0.6,
    extra  = { priority = "medium", scale = 0.5 },
  },

  gear_open_emission =
  {
    path   = "__base__/graphics/entity/cargo-pod/pod-opening-emission",
    frames = 34,
    speed  = 0.6,
    extra  = { priority = "medium", scale = 0.5, blend_mode = "additive", draw_as_glow = true },
  },

  gear_land =
  {
    path   = "__base__/graphics/entity/cargo-pod/pod-landing",
    frames = 13,
    speed  = 0.5,
    extra  = { priority = "medium", scale = 0.5 },
  },

  shadow_flight =
  {
    path   = "__space-age__/graphics/entity/cargo-pod/pod-closed-rotation",
    frames = 59,
    speed  = 0.5,
    center = true,
    extra  = { priority = "medium", scale = 0.5, draw_as_shadow = true },
  },

  shadow_landed =
  {
    path   = "__base__/graphics/entity/cargo-pod/pod-landed-shadow",
    static = true,
    extra  = { priority = "medium", scale = 0.5, draw_as_shadow = true },
  },
}

config.anim =
{
  body               = config.entity_name .. "-body",
  body_emission      = config.entity_name .. "-body-emission",

  thruster           = config.entity_name .. "-thruster",
  thruster_on        = config.entity_name .. "-thruster-on",
  thruster_off       = config.entity_name .. "-thruster-off",

  thruster_ignite    = config.entity_name .. "-thruster-on",
  thruster_fade      = config.entity_name .. "-thruster-off",

  gear_open          = config.entity_name .. "-gear-open",
  gear_close         = config.entity_name .. "-gear-close",
  gear_open_emission = config.entity_name .. "-gear-open-emission",

  gear_land          = config.entity_name .. "-gear-land",
  gear_liftoff       = config.entity_name .. "-gear-liftoff",
  gear_close_emission   = config.entity_name .. "-gear-close-emission",

  shadow_flight      = config.entity_name .. "-shadow-flight",
  shadow_landed      = config.entity_name .. "-shadow-landed",
}

config.clips =
{
  gear_liftoff = { layer = "gear",     sheet = "gear_land"  },
  gear_close   = { layer = "gear",     sheet = "gear_open",  emission = "gear_close_emission" },
  gear_open    = { layer = "gear",     sheet = "gear_open",  emission = "gear_open_emission" },
  gear_land    = { layer = "gear",     sheet = "gear_land"  },

  thruster_ignite = { layer = "thruster", sheet = "thruster_start", rotating = true,
                      next = "thruster_fade" },
  thruster_fade   = { layer = "thruster", sheet = "thruster_start", rotating = true,
                      on_end = "hide" },

  thruster_on     = { layer = "thruster", sheet = "thruster_start", rotating = true,
                      next = "thruster" },
  thruster_off    = { layer = "thruster", sheet = "thruster_start", rotating = true,
                      on_end = "hide" },
  thruster        = { layer = "thruster", sheet = "thruster", loop = true,
                      rotating = true },
}

config.guns = {}

config.equipment_types =
{
  "active-defense-equipment",
}

config.blocked_equipment_types =
{
  "movement-bonus-equipment",
}

config.equipment_category = config.entity_name .. "-equipment"
config.equipment_grid     = config.entity_name .. "-equipment-grid"

config.phases = {}

config.phases.takeoff =
{
  { "gear_liftoff",                  alt = 0.15 },
  { "gear_close", "thruster_ignite", alt = 1    },
}

config.phases.landing =
{
  { "gear_open", "thruster_ignite", alt = 0.15 },
  { "gear_land",                    alt = 0, hold = true },
}

local behaviour_defaults =
{
  render_layer_shadow   = "smoke",
  render_layer_thruster = "smoke",
  render_layer_body     = "air-object",
  render_layer_gear     = "air-object",
  render_layer_emission = "air-entity-info-icon",
  render_layer_beam     = "light-effect",

  weapon_origin = { 0, 0 },

  lock_when_landed = true,

  landed_orientation = 0,

  takeoff_on_enter = false,

  land_on_exit = true,

  auto_land_delay = 120,

  spawn_state = "landed",

  altitude =
  {
    body_lift = 6.5,

    easing = "ease",
  },

  flight =
  {
    coast_friction = 0.012,

    max_speed = 0.85,

    forbid_reverse = true,

    moving_threshold = 0.004,

    no_fuel_speed = 0.08,

    thruster_only_when_moving = true,

    emission_with_thruster = true,

    emission_fade_in  = 12,
    emission_fade_out = 20,

    phase_emission_fade = 0.35,

    body_full_speed = 0.5,

    body_turn_speed = 0.35,

    emission_offset = { 0, 0.2 },

    emission_clips =
    {
      thruster_ignite = true,
      thruster_on     = true,
      thruster        = true,
    },
  },

  shadow =
  {
    rotate_in_flight = true,

    orientation_offset = 0,

    orientation = 0,

    min_altitude = 0.02,

    max_offset = { 4.6, 0 },

    scale = 1.0,

    alpha_ground = 1.0,
    alpha_air    = 0.55,
  },
}

function config.duration(sheet)
  if not sheet.speed or sheet.speed <= 0 then return 1 end
  return math.max(1, math.ceil(sheet.frames / sheet.speed))
end

function config.phase_ticks(phase)
  if phase.ticks then return math.max(1, phase.ticks) end

  local longest = 0
  for _, clip_name in ipairs(phase) do
    local clip = config.clips[clip_name]
    local sheet = clip and config.sheets[clip.sheet]
    if sheet then
      local ticks = config.duration(sheet)
      if ticks > longest then longest = ticks end
    end
  end

  return math.max(1, longest)
end

function config.phase_alt_from(phases, index, default_first)
  if index <= 1 then return default_first or 0 end
  local prev = phases[index - 1]
  return prev and prev.alt or default_first or 0
end

config.behaviour = config.behaviour or {}

for key, value in pairs(behaviour_defaults) do
  if type(value) == "table" then
    if type(config.behaviour[key]) ~= "table" then config.behaviour[key] = {} end
    for sub_key, sub_value in pairs(value) do
      if config.behaviour[key][sub_key] == nil then config.behaviour[key][sub_key] = sub_value end
    end
  elseif config.behaviour[key] == nil then
    config.behaviour[key] = value
  end
end

return config
