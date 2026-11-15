local shared = require("script.asteroid-test.shared")

local function normalize(x, y)
  local d = math.sqrt(x * x + y * y)
  if d < 1e-9 then return 0, 0, 0 end
  return x / d, y / d, d
end

local function update_orientation(entity, vx, vy)
  if vx * vx + vy * vy < 1e-8 then return end
  local orientation = (math.atan2(vy, vx) / (2 * math.pi) + 0.25) % 1
  pcall(function() entity.orientation = orientation end)
end

-- Совместимость со старыми сейвами: одно поле state.asteroid -> список записей.
local function get_records(state)
  if state.asteroids then
    return state.asteroids
  end
  local records = {}
  if state.asteroid and state.asteroid.valid then
    records[1] = {
      entity = state.asteroid,
      name = state.asteroid.name,
      kind = state.asteroid_kind,
      vel = state.vel or {x = 0, y = 0},
    }
  end
  state.asteroids = records
  return records
end

local function drop_invalid(records)
  for i = #records, 1, -1 do
    local record = records[i]
    if not (record.entity and record.entity.valid) then
      table.remove(records, i)
    end
  end
end

-- "Persist": тот же самый астероид двигается телепортом, без destroy/create.
local function step_teleport(state, record, desired)
  local turn = state.turn or shared.default_turn
  record.vel = record.vel or {x = 0, y = 0}
  record.vel.x = record.vel.x + (desired.x - record.vel.x) * turn
  record.vel.y = record.vel.y + (desired.y - record.vel.y) * turn
  local entity = record.entity
  local pos = entity.position
  pcall(function()
    entity.teleport({x = pos.x + record.vel.x, y = pos.y + record.vel.y})
  end)
  update_orientation(entity, record.vel.x, record.vel.y)
end

script.on_nth_tick(1, function()
  local state = storage.ast_test
  if not state or not state.running then return end
  local surf = shared.get_surface(state)
  if not (surf and surf.valid) then
    state.running = false
    return
  end
  local target = state.target
  if not target then return end

  local records = get_records(state)
  drop_invalid(records)
  if #records == 0 then
    state.running = false
    return
  end

  local speed = state.speed or shared.default_speed
  for _, record in ipairs(records) do
    local entity = record.entity
    if entity and entity.valid then
      local pos = entity.position
      local nx, ny, dist = normalize(target.x - pos.x, target.y - pos.y)
      local desired = {x = 0, y = 0}
      if dist > 0.05 then
        desired.x = nx * speed
        desired.y = ny * speed
      end
      step_teleport(state, record, desired)
    end
  end
end)