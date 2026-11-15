-- Орбитальный заказчик строительства: точка входа runtime-части.
-- Прототипы для data-стадии лежат в prototype/entity/orbital-requester.lua.
-- GUI-события делегируются из carkas.lua: отдельная регистрация перезаписала бы их.
--
-- Модули:
--   orders.lua    — список заказов и поиск по нему;
--   gui.lua       — окно заказчика и его обработчики;
--   delivery.lua  — отправка капсул и приём груза.
--
-- Одно здание за один заказ. В капсуле перевозится настоящий предмет.
local orders = require("script.orbital-requester.orders")

local M = {}
local REQUESTER = "orbital-construction-requester"
local GUI = "orbital_requester_window"

local function state()
  storage.orbital_requests = storage.orbital_requests or {}
  storage.orbital_pods = storage.orbital_pods or {}
  return storage.orbital_requests, storage.orbital_pods
end

local function platforms(force)
  local list = {}
  for _, platform in pairs(force.platforms) do
    if platform.valid and platform.hub and platform.hub.valid then list[#list + 1] = platform end
  end
  table.sort(list, function(a, b) return a.index < b.index end)
  return list
end

local function close(player)
  local window = player.gui.screen[GUI]
  if window then window.destroy() end
end

-- Центр 4×4 стоит на границе тайлов. Для 3×3 (и других нечётных
-- размеров) итоговый центр должен быть в середине тайла.
local function building_position(entity, target)
  local position = entity.position
  local proto = prototypes.entity[target]
  local box = proto and proto.selection_box
  if not box then return position end
  local left, right = box.left_top or box[1], box.right_bottom or box[2]
  if not left or not right then return position end
  local width = math.floor((right.x or right[1]) - (left.x or left[1]) + 0.5)
  local height = math.floor((right.y or right[2]) - (left.y or left[2]) + 0.5)
  if width < 1 or height < 1 then return position end
  if defines.direction and (entity.direction == defines.direction.east or entity.direction == defines.direction.west) then
    width, height = height, width
  end
  local function snap(value, size)
    if size % 2 == 1 then return math.floor(value) + 0.5 end
    return math.floor(value + 0.5)
  end
  return {x = snap(position.x, width), y = snap(position.y, height)}
end

local function can_build(entity, target)
  return entity.surface.can_place_entity{
    name = target, position = building_position(entity, target), direction = entity.direction,
    force = entity.force, build_check_type = defines.build_check_type.script
  }
end

-- Ядро модуля: общие константы и хелперы, которые нужны gui и delivery.
local core = {
  REQUESTER = REQUESTER,
  GUI = GUI,
  orders = orders,
  state = state,
  platforms = platforms,
  close = close,
  building_position = building_position,
  can_build = can_build,
}

local gui = require("script.orbital-requester.gui")(core)
require("script.orbital-requester.delivery")(core)

M.open = gui.open
M.click = gui.click
M.closed = gui.closed
M.remember_open = gui.remember_open

return M
