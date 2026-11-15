-- Окно заказчика и обработка его GUI-событий.
-- Фабрика: принимает ядро модуля (константы, состояние, платформы, хелперы)
-- и возвращает API open/click/closed/remember_open. События GUI делегируются
-- из carkas.lua через этот API: отдельная регистрация перезаписала бы их.
return function(core)
  local M = {}
  local GUI = core.GUI
  local find_order = core.orders.find
  local targets = core.orders.targets
  local platforms = core.platforms
  local state = core.state
  local close = core.close

  function M.open(event)
    local entity = event.entity
    if not (entity and entity.valid and entity.name == core.REQUESTER) then return false end
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

    -- Планета, на которой стоит сам заказчик: платформы на её орбите подсвечиваем.
    local planet = entity.surface.planet
    local labels, indices, platform_selected = {}, {}, 1
    for i, platform in ipairs(ps) do
      local location = platform.space_location
      local label = platform.name .. " (#" .. platform.index .. ")"
      -- Иконка планеты, у которой сейчас стоит платформа.
      if location then label = "[img=space-location/" .. location.name .. "] " .. label end
      -- Зелёным — платформы, готовые доставить заказ на эту планету.
      if planet and location and location.name == planet.name then
        label = "[color=green]" .. label .. "[/color]"
      end
      labels[i] = label
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
    if event.entity and event.entity.valid and event.entity.name == core.REQUESTER then
      storage.orbital_gui_entities = storage.orbital_gui_entities or {}
      storage.orbital_gui_entities[event.player_index] = event.entity
    end
    return M.open(event)
  end

  return M
end
