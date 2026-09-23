local character = data.raw.character.character
local biter = data.raw.unit["small-biter"]

if data.raw.character["pcg-ghost"] then
  data.raw.character["pcg-ghost"] = nil
end
for name in pairs(data.raw.unit or {}) do
  if name == "pcg-ghost" or string.sub(name, 1, 10) == "pcg-ghost-" then
    data.raw.unit[name] = nil
  end
end

local function ghostify(node, seen)
  if type(node) ~= "table" then
    return
  end
  seen = seen or {}
  if seen[node] then
    return
  end
  seen[node] = true
  if node.layers then
    for _, layer in pairs(node.layers) do
      ghostify(layer, seen)
    end
  end
  if node.hr_version then
    ghostify(node.hr_version, seen)
  end
  if node.filename or node.filenames or node.stripes then
    if node.draw_as_shadow then
      node.tint = { r = 0, g = 0, b = 0, a = 0.18 }
    else
      node.apply_runtime_tint = false
      node.tint = { r = 0.58, g = 0.68, b = 0.88, a = 0.42 }
      node.blend_mode = "additive-soft"
    end
  else
    for _, v in pairs(node) do
      if type(v) == "table" then
        ghostify(v, seen)
      end
    end
  end
end

local set
for _, s in pairs(character.animations or {}) do
  if type(s) == "table" and s.running then
    set = s
    break
  end
end
set = set or character.animations[1] or character.animations

local run_anim = table.deepcopy((set and set.running) or biter.run_animation)
local atk_anim = table.deepcopy((set and (set.running_with_gun or set.idle_with_gun or set.running)) or biter.attack_parameters.animation)
ghostify(run_anim)
ghostify(atk_anim)

local function ammo_type_of(ammo)
  local t = ammo.ammo_type
  if not t then
    return nil
  end
  if t.action or t.category then
    return table.deepcopy(t)
  end
  for _, one in pairs(t) do
    if type(one) == "table" and one.action then
      return table.deepcopy(one)
    end
  end
end

local function ammo_for_gun(gun)
  local ap = gun.attack_parameters
  if not ap then
    return nil
  end
  local cats = {}
  if ap.ammo_category then
    cats[ap.ammo_category] = true
  end
  for _, c in pairs(ap.ammo_categories or {}) do
    cats[c] = true
  end
  local prefer = {
    ["firearm-magazine"] = true,
    ["shotgun-shell"] = true,
    rocket = true,
    ["flamethrower-ammo"] = true
  }
  local fallback
  for _, ammo in pairs(data.raw.ammo or {}) do
    local cat = ammo.ammo_category
    if not cat and ammo.ammo_type then
      cat = ammo.ammo_type.category
    end
    if cat and cats[cat] and ammo_type_of(ammo) then
      if prefer[ammo.name] then
        return ammo
      end
      fallback = fallback or ammo
    end
  end
  return fallback
end

local function make_unit(name, attack)
  attack.animation = table.deepcopy(atk_anim)
  local u = table.deepcopy(biter)
  u.name = name
  u.localised_name = " "
  u.icon = character.icon or u.icon
  u.icon_size = character.icon_size or u.icon_size or 64
  u.icons = nil
  u.max_health = 1e9
  u.healing_per_tick = 0
  u.alert_when_damaged = false
  u.hidden_in_factoriopedia = true
  u.create_ghost_on_death = false
  u.minable = nil
  u.loot = {}
  u.corpse = nil
  u.dying_explosion = nil
  u.dying_trigger_effect = nil
  u.damaged_trigger_effect = nil
  u.spawn_decoration = nil
  u.walking_sound = nil
  u.running_sound_animation_positions = nil
  u.warcry = nil
  u.dying_sound = nil
  u.movement_speed = 0.12
  u.distance_per_frame = 0.1
  u.vision_distance = 22
  u.rotation_speed = 0.05
  u.min_pursue_time = 60
  u.max_pursue_distance = 18
  u.has_belt_immunity = true
  u.move_while_shooting = false
  u.run_animation = run_anim
  u.attack_parameters = attack
  u.absorptions_to_join_attack = {}
  u.ai_settings = u.ai_settings or {}
  u.ai_settings.destroy_when_commands_fail = false
  u.ai_settings.allow_try_return_to_spawner = false
  u.ai_settings.join_attacks = false
  u.flags = {
    "placeable-off-grid",
    "not-repairable",
    "not-on-map",
    "not-flammable",
    "not-in-kill-statistics",
    "get-by-unit-number"
  }
  data:extend({ u })
end

make_unit("pcg-ghost", {
  type = "projectile",
  range = 1.2,
  cooldown = 20,
  ammo_category = "melee",
  ammo_type = {
    target_type = "entity",
    action = {
      type = "direct",
      action_delivery = {
        type = "instant",
        target_effects = {
          { type = "damage", damage = { amount = 12, type = "physical" } }
        }
      }
    }
  }
})

for _, gname in pairs({
  "pistol",
  "submachine-gun",
  "shotgun",
  "combat-shotgun",
  "rocket-launcher",
  "flamethrower",
  "railgun",
  "teslagun"
}) do
  local gun = data.raw.gun[gname]
  if gun and gun.attack_parameters then
    local ammo = ammo_for_gun(gun)
    local at = ammo and ammo_type_of(ammo)
    if at then
      local ap = table.deepcopy(gun.attack_parameters)
      ap.ammo_type = at
      if not ap.type then
        ap.type = "projectile"
      end
      make_unit("pcg-ghost-" .. gname, ap)
    end
  end
end
