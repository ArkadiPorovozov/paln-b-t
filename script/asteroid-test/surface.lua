local shared = require("script.asteroid-test.shared")

local surface = {}

-- Версия настроек платформы. При несовпадении старая пересоздаётся.
local SURFACE_VERSION = 4
local AREA = 64
local VOID_TILE = "empty-space"

-- Страховка: явно застилаем центральную область пустотой.
local function fill_empty_space(surf)
  local tiles = {}
  for x = -AREA, AREA - 1 do
    for y = -AREA, AREA - 1 do
      tiles[#tiles + 1] = { position = { x, y }, name = VOID_TILE }
    end
  end
  surf.set_tiles(tiles, true)
end

function surface.release_player(player)
  pcall(function() player.exit_remote_view() end)
end

-- Удаляет (планетную) поверхность, предварительно выкинув с неё игроков.
-- Нужно только для уборки поверхностей от старых версий мода.
function surface.delete(surf)
  if not (surf and surf.valid) then return true end
  local fallback = game.get_surface("nauvis") or game.get_surface(1)
  for _, player in pairs(game.players) do
    if player.valid and player.surface_index == surf.index then
      surface.release_player(player)
      if fallback then
        pcall(function() player.teleport({ x = 0, y = 0 }, fallback) end)
      end
    end
  end
  local ok, err = pcall(function() game.delete_surface(surf.name) end)
  return ok, err
end

local function find_platform()
  local platform = storage.ast_test_platform
  if platform and platform.valid then
    if platform.scheduled_for_deletion == 0 then return platform end
    storage.ast_test_platform = nil
  end

  local force = game.forces.player
  if not force then return nil end
  for _, candidate in pairs(force.platforms or {}) do
    if candidate.valid and candidate.scheduled_for_deletion == 0 and candidate.name == shared.platform_name then
      return candidate
    end
  end
  return nil
end

local function destroy_platform(platform)
  if not (platform and platform.valid) then
    storage.ast_test_platform = nil
    return true
  end
  local surf = platform.surface
  if surf and surf.valid then
    local fallback = game.get_surface("nauvis") or game.get_surface(1)
    for _, player in pairs(game.players) do
      if player.valid and player.surface_index == surf.index then
        surface.release_player(player)
        if fallback then
          pcall(function() player.teleport({ x = 0, y = 0 }, fallback) end)
        end
      end
    end
  end
  local ok, err = pcall(function() platform.destroy(1) end)
  if ok then storage.ast_test_platform = nil end
  return ok, err
end

-- Астероиды существуют только на поверхности космической платформы.
-- На обычной (планетной) поверхности движок удаляет их через секунду.
function surface.ensure()
  local platform = find_platform()
  if platform and storage.ast_test_surface_version ~= SURFACE_VERSION then
    log("[ast-test] ensure: destroying old platform version " .. tostring(storage.ast_test_surface_version))
    destroy_platform(platform)
    platform = nil
  end

  -- Убираем поверхность ast-test от старых версий мода (режим "planet").
  local legacy = game.get_surface(shared.surface_name)
  if legacy then
    log("[ast-test] ensure: deleting legacy surface '" .. legacy.name .. "'")
    surface.delete(legacy)
  end

  if platform then
    local surf = platform.surface
    if surf and surf.valid then
      surf.ignore_surface_conditions = true
      storage.ast_test_platform = platform
      storage.ast_test_surface_version = SURFACE_VERSION
      log("[ast-test] ensure: reusing platform surface '" .. surf.name .. "'")
      return surf
    end
  end

  local force = game.forces.player
  if not force then
    shared.last_create_error = "no player force"
    return nil
  end

  local ok, created = pcall(function()
    return force.create_space_platform({
      name = shared.platform_name,
      planet = shared.platform_planet,
      starter_pack = shared.starter_pack,
    })
  end)
  if not ok or not created then
    shared.last_create_error = "create_space_platform: " .. tostring(created)
    log("[ast-test] ensure: " .. shared.last_create_error)
    return nil
  end
  platform = created

  -- Без стартового набора у платформы ещё нет поверхности.
  local ok_apply, apply_err = pcall(function() platform.apply_starter_pack() end)
  if not ok_apply then
    log("[ast-test] ensure: apply_starter_pack failed: " .. tostring(apply_err))
  end

  local surf = platform.surface
  if not (surf and surf.valid) then
    shared.last_create_error = "platform surface is missing"
    log("[ast-test] ensure: " .. shared.last_create_error)
    destroy_platform(platform)
    return nil
  end

  -- Хаб не нужен: убираем его и застилаем всё пустотой.
  if platform.hub and platform.hub.valid then
    pcall(function() platform.hub.destroy() end)
  end
  local ok_fill, fill_err = pcall(fill_empty_space, surf)
  if not ok_fill then
    log("[ast-test] ensure: fill_empty_space failed: " .. tostring(fill_err))
    shared.last_create_error = tostring(fill_err)
  end
  surf.ignore_surface_conditions = true

  storage.ast_test_platform = platform
  storage.ast_test_surface_version = SURFACE_VERSION
  log("[ast-test] ensure: created platform surface '" .. surf.name .. "'")
  return surf
end

-- Убирает с поверхности все астероиды (перед новым спавном).
function surface.clear_asteroids(surf)
  if not (surf and surf.valid) then return 0 end
  local asteroids = surf.find_entities_filtered{type = "asteroid"}
  local removed = 0
  for _, entity in ipairs(asteroids) do
    if entity.valid then
      entity.destroy()
      removed = removed + 1
    end
  end
  log("[ast-test] cleared " .. removed .. " asteroid(s)")
  return removed
end

-- Спавнит по одному большому астероиду каждого вида из shared.asteroid_types.
-- Возвращает список записей {entity=..., name=..., kind=..., vel=...}.
function surface.spawn_asteroids(surf, center)
  center = center or {x = 0, y = 0}
  local records = {}
  local errors = {}
  for i, kind in ipairs(shared.asteroid_types) do
    local name = shared.asteroid_entity_name(kind)
    local offset = shared.asteroid_offsets[i] or {x = 0, y = 0}
    local position = {x = center.x + offset.x, y = center.y + offset.y}
    local ok, entity = pcall(function()
      return surf.create_entity({name = name, position = position})
    end)
    if ok and entity and entity.valid then
      records[#records + 1] = {
        entity = entity,
        name = name,
        kind = kind,
        vel = {x = 0, y = 0},
      }
      log(("[ast-test] spawned %s at (%.1f, %.1f)"):format(name, position.x, position.y))
    else
      local err = (ok and "create_entity returned nil") or tostring(entity)
      errors[#errors + 1] = kind .. ": " .. err
      log("[ast-test] spawn failed " .. name .. ": " .. err)
    end
  end
  if #errors > 0 then
    shared.last_create_error = table.concat(errors, "; ")
  end
  return records
end

function surface.focus_player(player, surf)
  local ok = pcall(function()
    player.set_controller({
      type = defines.controllers.remote,
      surface = surf,
      position = {x = 0, y = 0}
    })
  end)
  if not ok then
    pcall(function() player.teleport({x = 0, y = 0}, surf) end)
  end
end

function surface.cleanup()
  local ok, err = true, nil
  local platform = find_platform()
  if platform then
    local okp, errp = destroy_platform(platform)
    if not okp then ok, err = okp, errp end
  end
  storage.ast_test_platform = nil
  storage.ast_test_surface_version = nil

  -- На случай поверхности от старых версий.
  local legacy = game.get_surface(shared.surface_name)
  if legacy then
    local ok2, err2 = surface.delete(legacy)
    if not ok2 and ok then ok, err = ok2, err2 end
  end
  return ok, err
end

return surface