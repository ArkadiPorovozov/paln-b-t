-- Анимация строительных лесов космической платформы.
-- Порт мода Quezler "Space platform entity build animation lib" (лицензия MIT).
-- Источник: https://github.com/Quezler/glutenfree/tree/main/mods_2.0/109_space-platform-entity-build-animation-lib
--
-- Как это работает: на каждый тайл площадки рисуется пара draw_animation
-- (верх лесов + тело с тенью), подъём каждого тайла задержан на манхэттенское
-- расстояние от центра * FRAMES_BETWEEN_BUILDING. Леса замирают на 16-м кадре,
-- а через remove_scaffold_delay проигрываются кадры 16..32 (опускание).

local ANIM_PREFIX = "mb-panim-" -- префикс зарегистрированных в data.lua анимаций

local TICKS_PER_FRAME = 2
local FRAMES_BETWEEN_BUILDING = 8 * 2
local FRAMES_BETWEEN_REMOVING = 4

local M = {}

local function add_task(tick, task)
  storage.panim_tasks = storage.panim_tasks or {}
  local tasks = storage.panim_tasks[tick]
  if tasks then
    tasks[#tasks + 1] = task
  else
    storage.panim_tasks[tick] = {task}
  end
end

local function get_tilebox(area)
  local left_top = {x = math.floor(area.left_top.x), y = math.floor(area.left_top.y)}
  local right_bottom = {x = math.ceil(area.right_bottom.x), y = math.ceil(area.right_bottom.y)}
  local positions = {}
  for y = left_top.y, right_bottom.y - 1 do
    for x = left_top.x, right_bottom.x - 1 do
      positions[#positions + 1] = {x = x, y = y}
    end
  end
  return positions
end

-- какая угловая часть лесов стоит на данном тайле (position ожидается с .5)
local function get_piece(position, center)
  if position.x > center.x then
    return position.y < center.y and "back_right" or "front_right"
  else
    return position.y < center.y and "back_left" or "front_left"
  end
end

local function is_back_piece(piece)
  return piece == "back_left" or piece == "back_right"
end

local function get_manhattan_distance(position, center)
  return math.abs(position.x - center.x) + math.abs(position.y - center.y)
end

local function get_build_sound_path(area)
  local w = area.right_bottom.x - area.left_top.x
  local h = area.right_bottom.y - area.left_top.y
  local s = w * h
  local uc = prototypes.utility_constants
  if s < uc.small_area_size then return "utility/build_animated_small" end
  if s < uc.medium_area_size then return "utility/build_animated_medium" end
  if s < uc.large_area_size then return "utility/build_animated_large" end
  return "utility/build_animated_huge"
end

-- Запускает анимацию лесов над областью area на surface (center — точка внутри).
-- Возвращает up_at, down_at: тики, когда леса полностью подняты и полностью опущены.
function M.play(surface, area, center)
  -- позиция может прийти массивом {x, y} — нормализуем в {x=, y=}
  if center[1] then center = {x = center[1], y = center[2]} end
  local tick = game.tick
  local top_render_layer = "higher-object-above"

  -- звук постройки как у платформы (pcall — если в версии игры звука нет)
  pcall(surface.play_sound, surface, {path = get_build_sound_path(area), position = center})

  local tilebox = get_tilebox(area)
  local largest = 0
  for _, tile in ipairs(tilebox) do
    tile.center = {x = tile.x + 0.5, y = tile.y + 0.5}
    tile.manhattan = math.ceil(get_manhattan_distance(tile.center, center))
    if tile.manhattan > largest then largest = tile.manhattan end
  end

  local remove_scaffold_delay = (largest + 4) * FRAMES_BETWEEN_BUILDING
  local up_at = tick + 1 + largest * FRAMES_BETWEEN_BUILDING + 15 * TICKS_PER_FRAME
  local down_at = tick + 1 + largest * FRAMES_BETWEEN_REMOVING + remove_scaffold_delay + 16 * TICKS_PER_FRAME

  for _, tile in ipairs(tilebox) do
    local piece = get_piece(tile.center, center)
    local animations = {} -- {top, body}

    local up_base = tick + 1 + tile.manhattan * FRAMES_BETWEEN_BUILDING
    add_task(up_base + 0 * TICKS_PER_FRAME, {name = "start", animations = animations})
    add_task(up_base + 15 * TICKS_PER_FRAME, {name = "pause", offset = 15, animations = animations})

    local down_base = tick + 1 + tile.manhattan * FRAMES_BETWEEN_REMOVING + remove_scaffold_delay
    add_task(down_base + 0 * TICKS_PER_FRAME, {name = "unpause", offset = 16, animations = animations})

    local ttl = down_base - tick + 16 * TICKS_PER_FRAME

    animations[1] = rendering.draw_animation{
      target = tile.center,
      surface = surface,
      animation = ANIM_PREFIX .. piece .. "-top",
      time_to_live = ttl,
      animation_offset = 0,
      animation_speed = 0,
      render_layer = top_render_layer,
      visible = false,
    }
    animations[2] = rendering.draw_animation{
      target = tile.center,
      surface = surface,
      animation = ANIM_PREFIX .. piece .. "-body",
      time_to_live = ttl,
      animation_offset = 0,
      animation_speed = 0,
      render_layer = is_back_piece(piece) and "lower-object-above-shadow" or "object",
      visible = false,
    }
  end

  return up_at, down_at
end

-- Вызывать каждый тик: двигает плеер анимации (start/pause/unpause по расписанию).
function M.on_tick(tick)
  local storage_tasks = storage.panim_tasks
  local tasks = storage_tasks and storage_tasks[tick]
  if not tasks then return end
  storage_tasks[tick] = nil
  for _, task in ipairs(tasks) do
    local a1, a2 = task.animations[1], task.animations[2]
    if a1.valid and a2.valid then
      if task.name == "start" then
        local offset = -(tick * 0.5) % 32
        a1.visible = true; a2.visible = true
        a1.animation_speed = 1; a2.animation_speed = 1
        a1.animation_offset = offset; a2.animation_offset = offset
      elseif task.name == "pause" then
        a1.animation_speed = 0; a2.animation_speed = 0
        a1.animation_offset = task.offset; a2.animation_offset = task.offset
      elseif task.name == "unpause" then
        local offset = -(tick * 0.5) % 32
        a1.animation_speed = 1; a2.animation_speed = 1
        a1.animation_offset = offset + task.offset
        a2.animation_offset = offset + task.offset
      end
    end
  end
end

return M
