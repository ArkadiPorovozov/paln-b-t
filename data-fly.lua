local config = require("shared")
local util   = require("util")

local function make_graphic(name, sheet, run_mode)
  local params = {}
  if not sheet.static then params.frame_count = sheet.frames end

  for key, value in pairs(sheet.extra or {}) do
    if key == "shift_px" then
      params.shift = util.by_pixel(value[1], value[2])
    else
      params[key] = value
    end
  end

  local result = util.sprite_load(sheet.path, params)
  result.name = name

  if sheet.center then result.shift = {0, 0} end

  if sheet.static then
    result.type = "sprite"
    result.animation_speed, result.frame_count = nil, nil
    result.line_length, result.run_mode, result.frames = nil, nil, nil
  else
    result.type = "animation"
    result.run_mode = run_mode or "forward"
    result.animation_speed = 1
  end

  return result
end

local function set_attack_origin(node, origin)
  if type(node) ~= "table" then return end

  for _, field in ipairs({"projectile_center", "source_offset", "gun_center_shift"}) do
    if type(node[field]) == "table" then node[field] = { origin[1], origin[2] } end
  end

  for _, offset in ipairs(node.projectile_creation_offsets or {}) do
    offset[1], offset[2] = origin[1], origin[2]
  end

  for _, child in pairs(node) do set_attack_origin(child, origin) end
end

local function collect_beams(node, found)
  found = found or {}
  if type(node) ~= "table" then return found end
  if type(node.beam) == "string" then found[#found + 1] = node.beam end
  for _, child in pairs(node) do collect_beams(child, found) end
  return found
end

local function rename_beams(node, renamed)
  if type(node) ~= "table" then return end
  if type(node.beam) == "string" and renamed[node.beam] then
    node.beam = node.beam .. "-aircraft"
  end
  for _, child in pairs(node) do rename_beams(child, renamed) end
end

local aircraft_prototypes, copied_beams = {}, {}

for _, equipment_type in ipairs(config.equipment_types) do
  for equipment_name, original in pairs(data.raw[equipment_type] or {}) do
    if original.attack_parameters and not equipment_name:find("%-aircraft$") then
      local copy = table.deepcopy(original)
      copy.name        = equipment_name .. "-aircraft"
      copy.take_result = original.take_result or equipment_name
      copy.hidden      = true
      set_attack_origin(copy.attack_parameters, config.behaviour.weapon_origin)
      aircraft_prototypes[#aircraft_prototypes + 1] = copy

      local renamed = {}
      for _, beam_name in ipairs(collect_beams(copy.attack_parameters)) do
        local beam = (data.raw.beam or {})[beam_name]
        if beam then
          renamed[beam_name] = true
          if not copied_beams[beam_name] then
            copied_beams[beam_name] = true
            local beam_copy = table.deepcopy(beam)
            beam_copy.name = beam_name .. "-aircraft"
            beam_copy.graphics_set = beam_copy.graphics_set or {}
            beam_copy.graphics_set.beam = beam_copy.graphics_set.beam or {}
            beam_copy.graphics_set.beam.render_layer = config.behaviour.render_layer_beam
            aircraft_prototypes[#aircraft_prototypes + 1] = beam_copy
          end
        end
      end
      rename_beams(copy.attack_parameters, renamed)
    end
  end
end

if #aircraft_prototypes > 0 then data:extend(aircraft_prototypes) end

local blocked = {}
for _, equipment_type in ipairs(config.blocked_equipment_types) do
  blocked[equipment_type] = true
end

for equipment_type, list in pairs(data.raw) do
  if equipment_type:find("%-equipment$") and not blocked[equipment_type] then
    for _, equipment in pairs(list) do
      if type(equipment.categories) == "table" then
        equipment.categories[#equipment.categories + 1] = config.equipment_category
      end
    end
  end
end

data:extend
{
  { type = "collision-layer",   name = "aircraft_layer" },
  { type = "equipment-category", name = config.equipment_category },

  {
    type = "equipment-grid",
    name = config.equipment_grid,
    width = 10,
    height = 10,
    equipment_categories = { config.equipment_category },
  },

  make_graphic(config.anim.body,               config.sheets.body),
  make_graphic(config.anim.body_emission,      config.sheets.body_emission),
  make_graphic(config.anim.thruster,           config.sheets.thruster),
  make_graphic(config.anim.thruster_on,        config.sheets.thruster_start,     "forward"),
  make_graphic(config.anim.thruster_off,       config.sheets.thruster_start,     "backward"),
  make_graphic(config.anim.gear_open,          config.sheets.gear_open,          "forward"),
  make_graphic(config.anim.gear_close,         config.sheets.gear_open,          "backward"),
  make_graphic(config.anim.gear_open_emission, config.sheets.gear_open_emission, "forward"),
  make_graphic(config.anim.gear_land,          config.sheets.gear_land,          "forward"),
  make_graphic(config.anim.gear_liftoff,       config.sheets.gear_land,          "backward"),
  make_graphic(config.anim.gear_close_emission,   config.sheets.gear_open_emission, "backward"),
  make_graphic(config.anim.shadow_flight,      config.sheets.shadow_flight),
  make_graphic(config.anim.shadow_landed,      config.sheets.shadow_landed),

  {
    type = "item-with-entity-data",
    name = config.entity_name,
    icon = "__base__/graphics/icons/cargo-pod.png",
    icon_size = 64,
    subgroup = "transport",
    order = "b[personal-transport]-d[aircraft]",
    place_result = config.entity_name,
    stack_size = 1,
    weight = 200 * 1000,
  },

  {
    type = "custom-input",
    name = "flying-transport-toggle-flight",
    key_sequence = "SHIFT + SPACE",
    consuming = "none",
    action = "lua",
  },

  {
    type = "car",
    name = config.entity_name,

    icon = "__base__/graphics/icons/cargo-pod.png",
    icon_size = 64,

    flags = {"placeable-neutral", "player-creation", "placeable-off-grid", "not-flammable"},
    minable = { mining_time = 0.6, result = config.entity_name },
    mined_sound = { filename = "__core__/sound/deconstruct-medium.ogg", volume = 0.8 },

    max_health = 700,
    is_military_target = true,
    deliver_category = "vehicle",
    alert_icon_shift = util.by_pixel(0, -20),

    collision_box = {{-1.0, -1.4}, {1.0, 1.4}},
    selection_box = {{-1.2, -1.6}, {1.2, 1.6}},
    drawing_box_vertical_extension = 2,
    collision_mask =
    {
      layers = { aircraft_layer = true },
      consider_tile_transitions = false,
    },

    immune_to_all_impacts = true,
    has_belt_immunity = true,
    terrain_friction_modifier = 0,
    energy_per_hit_point = 1,

    resistances =
    {
      { type = "fire",   percent = 60 },
      { type = "impact", percent = 90, decrease = 50 },
      { type = "acid",   percent = 30 },
    },

    effectivity = 1.0,
    consumption = "900kW",
    braking_force = (120 * 1000) / 60,
    friction_force = 0.4e-3,
    weight = 1200,
    rotation_speed = 0.0045,
    rotation_snap_angle = 0,
    tank_driving = true,

    energy_source =
    {
      type = "burner",
      fuel_categories = { "chemical" },
      effectivity = 1,
      fuel_inventory_size = 2,
    },

    inventory_size = 60,
    trash_inventory_size = 0,

    guns = config.guns,
    equipment_grid = config.equipment_grid,
    allow_remote_driving = true,
    chunk_exploration_radius = 3,

    render_layer = "air-object",
    animation = util.empty_animation(),

    minimap_representation =
    {
      filename = "__base__/graphics/icons/cargo-pod.png",
      flags = {"icon"},
      size = 64,
      scale = 0.5,
    },

    sound_no_fuel = { filename = "__base__/sound/fight/tank-no-fuel-1.ogg", volume = 0.6 },
    stop_trigger_speed = 0.15,
    impact_speed_to_volume_ratio = 1.0,
  },
}
