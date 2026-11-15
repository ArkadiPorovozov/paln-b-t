-- Отправка капсул и приём доставленного груза.
-- Фабрика: принимает ядро модуля (состояние, позиционирование, проверка места)
-- и регистрирует свои обработчики при подключении.
return function(core)
  local state = core.state
  local building_position = core.building_position
  local can_build = core.can_build

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

  return {}
end
