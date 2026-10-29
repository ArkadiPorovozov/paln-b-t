-- Один модуль для обеих стадий Factorio: data.lua и control.lua.
-- Движок запускает их в отдельных Lua-состояниях.
if data then
  -- Временный вид: ванильный комбинатор, без добавления файлов графики.
  -- Комбинатор открывает GUI по клику и не содержит инвентаря.
  local entity = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
  entity.name = "orbital-construction-requester"
  entity.minable = {mining_time = 0.5, result = entity.name}
  entity.max_health = 350
  -- Размер заказчика и рамка выделения: 4×4 тайла.
  entity.tile_width = 4
  entity.tile_height = 4
  entity.collision_box = {{-1.9, -1.9}, {1.9, 1.9}}
  entity.selection_box = {{-2, -2}, {2, 2}}
  -- Без коллизии с будущим зданием; остальные препятствия всё равно проверяются.
  entity.collision_mask = {layers = {}}
  local item = table.deepcopy(data.raw.item["steel-chest"])
  item.name = entity.name
  item.place_result = entity.name
  item.stack_size = 50
  local recipe = {
    type = "recipe", name = entity.name, enabled = false,
    ingredients = {{type = "item", name = "steel-plate", amount = 10},
                   {type = "item", name = "processing-unit", amount = 5}},
    results = {{type = "item", name = entity.name, amount = 1}},
  }
  data:extend({entity, item, recipe})
  local tech = data.raw.technology["rocket-silo"]
  if tech then
    tech.effects = tech.effects or {}
    table.insert(tech.effects, {type = "unlock-recipe", recipe = entity.name})
  else
    recipe.enabled = true
  end
  return
end

-- Одно здание за один заказ. В капсуле перевозится настоящий предмет.
-- GUI-события делегируются из carkas.lua: отдельная регистрация перезаписала бы их.
local M = {}
local REQUESTER = "orbital-construction-requester"
local GUI = "orbital_requester_window"
-- ================================================================
-- СПИСОК ЗАКАЗОВ (настраивается здесь, в runtime-части файла).
-- entity — имя прототипа итоговой постройки;
-- item   — предмет, который лежит в хабе выбранной платформы.
-- Чтобы добавить здание: {entity = "имя-сущности", item = "имя-предмета"},
-- затем перезапустите Factorio/перезагрузите мод. Несуществующие прототипы
-- автоматически скрываются из меню. На один заказ расходуется один предмет.
-- ================================================================
local ORDERS = {
  -- Производство
  {entity = "assembling-machine-1", item = "assembling-machine-1"},
  {entity = "assembling-machine-2", item = "assembling-machine-2"},
  {entity = "assembling-machine-3", item = "assembling-machine-3"},
  {entity = "stone-furnace", item = "stone-furnace"},
  {entity = "steel-furnace", item = "steel-furnace"},
  {entity = "electric-furnace", item = "electric-furnace"},
  {entity = "chemical-plant", item = "chemical-plant"},
  {entity = "oil-refinery", item = "oil-refinery"},
  {entity = "centrifuge", item = "centrifuge"},
  -- Наука и инфраструктура
  {entity = "lab", item = "lab"},
  {entity = "beacon", item = "beacon"},
  {entity = "roboport", item = "roboport"},
  {entity = "rocket-silo", item = "rocket-silo"},
  {entity = "substation", item = "substation"},
  -- Space Age
  {entity = "biochamber", item = "biochamber"},
  {entity = "electromagnetic-plant", item = "electromagnetic-plant"},
  {entity = "foundry", item = "foundry"},
  {entity = "cryogenic-plant", item = "cryogenic-plant"},
  {entity = "agricultural-tower", item = "agricultural-tower"},
}

local function find_order(entity_name)
  for _, order in ipairs(ORDERS) do
    if order.entity == entity_name and prototypes.entity[order.entity] and prototypes.item[order.item] then
      return order
    end
  end
end

local function state()
  storage.orbital_requests = storage.orbital_requests or {}
  storage.orbital_pods = storage.orbital_pods or {}
  return storage.orbital_requests, storage.orbital_pods
end

local function targets()
  local list = {}
  for _, order in ipairs(ORDERS) do
    if prototypes.entity[order.entity] and prototypes.item[order.item] then
      list[#list + 1] = order
    end
  end
  return list
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

function M.open(event)
  local entity = event.entity
  if not (entity and entity.valid and entity.name == REQUESTER) then return false end
  local player = game.get_player(event.player_index)
  if not player then return true end
  player.opened = nil
  close(player)
  local requests = state()
  local request = requests[entity.unit_number]
  local ts, ps = targets(), platforms(entity.force)
  local selected = request and find_order(request.target) or ts[1]
  local window = player.gui.screen.add{type = "frame", name = GUI,
    style = "mb_transparent_frame", direction = "vertical",
    tags = {requester = entity.unit_number, target = selected and selected.entity or ""}}
  window.auto_center = true

  local title = window.add{type = "flow", direction = "horizontal"}
  title.add{type = "label", style = "frame_title", caption = {"orbital-requester.title"}}
  local spacer = title.add{type = "empty-widget", style = "draggable_space_header"}
  spacer.style.horizontally_stretchable = true
  spacer.drag_target = window
  title.add{type = "sprite-button", name = "orbital_close", style = "frame_action_button",
    sprite = "utility/close", tooltip = {"gui.close"}}

  local chosen = window.add{type = "flow", name = "orbital_chosen", direction = "horizontal"}
  if selected then
    local icon = chosen.add{type = "sprite", name = "orbital_chosen_icon", sprite = "item/" .. selected.item}
    icon.style.width = 24
    icon.style.height = 24
    local label = chosen.add{type = "label", name = "orbital_chosen_label",
      caption = {"orbital-requester.selected", prototypes.entity[selected.entity].localised_name}}
    label.style.maximal_width = 220
  else
    chosen.add{type = "label", caption = {"orbital-requester.none"}}
  end

  local scroll = window.add{type = "scroll-pane", direction = "vertical",
    horizontal_scroll_policy = "never", vertical_scroll_policy = "auto"}
  scroll.style.maximal_height = 145
  scroll.style.maximal_width = 230
  local grid = scroll.add{type = "table", column_count = 5}
  for _, order in ipairs(ts) do
    grid.add{type = "sprite-button", name = "orbital_choose_" .. order.entity,
      sprite = "item/" .. order.item, style = "slot_button",
      tooltip = {"orbital-requester.order-tooltip", prototypes.entity[order.entity].localised_name,
        prototypes.item[order.item].localised_name},
      tags = {target = order.entity}, enabled = not (request and request.in_flight)}
  end

  local labels, indices, platform_selected = {}, {}, 1
  for i, platform in ipairs(ps) do
    labels[i] = platform.name .. " (#" .. platform.index .. ")"
    indices[i] = platform.index
    if request and request.platform == platform.index then platform_selected = i end
  end
  if #labels == 0 then labels[1] = {"orbital-requester.no-platform"} end
  local picker = window.add{type = "drop-down", name = "orbital_platform", items = labels,
    selected_index = platform_selected, tags = {indices = indices},
    tooltip = {"orbital-requester.platform"}, enabled = not (request and request.in_flight)}
  picker.style.maximal_width = 230
  local status = request and (request.in_flight and "flying" or (request.status or "waiting")) or "not-ordered"
  local status_label = window.add{type = "label", caption = {"orbital-requester." .. status}}
  status_label.style.single_line = false
  status_label.style.maximal_width = 230
  local row = window.add{type = "flow", direction = "horizontal"}
  row.add{type = "button", name = "orbital_order", caption = {"orbital-requester.order"}, enabled = not (request and request.in_flight)}
  row.add{type = "button", name = "orbital_cancel", caption = {"orbital-requester.cancel"}, enabled = not (request and request.in_flight)}
  player.opened = window
  return true
end

function M.click(event)
  local el = event.element
  if not (el and el.valid and (string.sub(el.name, 1, 15) == "orbital_choose_" or el.name == "orbital_order" or el.name == "orbital_cancel" or el.name == "orbital_close")) then return false end
  local player = game.get_player(event.player_index)
  if not player then return true end
  local window = player.gui.screen[GUI]
  if not window then return true end
  local requests = state()
  local id = window.tags.requester
  if string.sub(el.name, 1, 15) == "orbital_choose_" then
    local order = find_order(el.tags.target)
    if order and not (requests[id] and requests[id].in_flight) then
      local tags = window.tags
      tags.target = order.entity
      window.tags = tags
      window.orbital_chosen.orbital_chosen_icon.sprite = "item/" .. order.item
      window.orbital_chosen.orbital_chosen_label.caption = {"orbital-requester.selected", prototypes.entity[order.entity].localised_name}
    end
    return true
  elseif el.name == "orbital_cancel" then
    if requests[id] and not requests[id].in_flight then requests[id] = nil end
  elseif el.name == "orbital_order" then
    local order = find_order(window.tags.target)
    local index = window.orbital_platform.tags.indices[window.orbital_platform.selected_index]
    local entity = storage.orbital_gui_entities and storage.orbital_gui_entities[player.index]
    if entity and entity.valid and entity.unit_number == id and entity.force == player.force and order and index then
      if not requests[id] or not requests[id].in_flight then
        requests[id] = {entity = entity, target = order.entity, item = order.item, platform = index, status = "waiting"}
        player.print({"orbital-requester.order-saved"})
      end
    else
      player.print({"orbital-requester.invalid-selection"})
    end
  end
  close(player)
  return true
end

function M.closed(event)
  if event.element and event.element.valid and event.element.name == GUI then
    local player = game.get_player(event.player_index)
    if player then close(player) end
    if storage.orbital_gui_entities then storage.orbital_gui_entities[event.player_index] = nil end
  end
end

function M.remember_open(event)
  if event.entity and event.entity.valid and event.entity.name == REQUESTER then
    storage.orbital_gui_entities = storage.orbital_gui_entities or {}
    storage.orbital_gui_entities[event.player_index] = event.entity
  end
  return M.open(event)
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

script.on_nth_tick(61, function()
  local requests, pods = state()
  for id, request in pairs(requests) do
    local entity = request.entity
    if not (entity and entity.valid) then
      requests[id] = nil -- находящаяся в полёте капсула останется с грузом
    elseif request.in_flight and not (request.pod and request.pod.valid) then
      pods[request.pod_id] = nil
      request.in_flight = false
      request.pod, request.pod_id = nil, nil
      request.status = "pod-lost"
    elseif not request.in_flight then
      local item = request.item or request.target -- совместимость со старыми заказами
      local platform = entity.force.platforms[request.platform]
      local planet = entity.surface.planet
      if not (platform and platform.valid and platform.hub and platform.hub.valid and planet
          and platform.space_location and platform.space_location.name == planet.name) then
        request.status = "wrong-orbit"
      elseif not prototypes.entity[request.target] or not prototypes.item[item] then
        request.status = "invalid-selection"
      elseif not can_build(entity, request.target) then
        request.status = "blocked"
      else
        local source = platform.hub.get_inventory(defines.inventory.hub_main)
        if not source or source.get_item_count{name = item, quality = "normal"} < 1 then
          request.status = "missing-item"
        else
          local pod = platform.hub.create_cargo_pod()
          if not pod then
            request.status = "no-hatch"
          else
            local cargo = pod.get_inventory(defines.inventory.cargo_unit)
            local removed = source.remove{name = item, count = 1, quality = "normal"}
            if cargo and removed == 1 and cargo.insert{name = item, count = 1, quality = "normal"} == 1 then
              request.in_flight = true
              request.pod, request.pod_id = pod, pod.unit_number
              request.status = "flying"
              pods[pod.unit_number] = {request_id = id, target = request.target, item = item}
              pod.cargo_pod_destination = {type = defines.cargo_destination.surface,
                surface = entity.surface, position = entity.position, land_at_exact_position = true}
            else
              if removed == 1 then source.insert{name = item, count = 1, quality = "normal"} end
              pod.destroy()
              request.status = "no-hatch"
            end
          end
        end
      end
    end
  end
end)

script.on_event(defines.events.on_cargo_pod_delivered_cargo, function(event)
  local requests, pods = state()
  local pod = event.cargo_pod
  local delivery = pod and pod.valid and pods[pod.unit_number]
  if not delivery then return end
  pods[pod.unit_number] = nil
  local request = requests[delivery.request_id]
  local entity = request and request.entity
  if not (entity and entity.valid) then return end -- обычная выгрузка капсулы
  local item = delivery.item or delivery.target -- старые капсулы
  local container = event.spawned_container
  local cargo = container and container.valid and container.get_inventory(defines.inventory.chest)
  if not cargo or cargo.get_item_count{name = item, quality = "normal"} < 1 then
    request.in_flight = false
    request.status = "missing-item"
    return
  end
  -- Предмет уже доставлен в появившийся контейнер. Не трогаем саму капсулу
  -- в её обработчике; удаляем пустой контейнер перед проверкой места.
  local surface, position, force, direction = entity.surface, building_position(entity, delivery.target), entity.force, entity.direction
  cargo.remove{name = item, count = 1, quality = "normal"}
  if cargo.is_empty() then container.destroy() end
  if can_build(entity, delivery.target) then
    local built = surface.create_entity{name = delivery.target, position = position,
      force = force, direction = direction, raise_built = true}
    if built then
      entity.destroy{raise_destroy = true}
      requests[delivery.request_id] = nil
      return
    end
  end
  surface.spill_item_stack{position = position, stack = {name = item, count = 1},
    force = force, enable_looted = true}
  requests[delivery.request_id] = nil
  force.print({"orbital-requester.delivery-blocked"})
end)

return M
