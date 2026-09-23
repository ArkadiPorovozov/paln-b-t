-- Инициализация при старте
script.on_init(function()
    storage.deliveries = {}
end)

script.on_nth_tick(30, function(event)
    for _, surface in pairs(game.surfaces) do
        local hubs = surface.find_entities_filtered{name = "planetary-hub"}
        
        for _, hub in ipairs(hubs) do
            local output_inv = hub.get_output_inventory()
            
            if output_inv and not output_inv.is_empty() then
                local pad = surface.find_entities_filtered{name = "cargo-landing-pad", limit = 1}[1]

                if pad and pad.valid then
                    -- 1. ЗАБИРАЕМ ГРУЗ
                    local contents = output_inv.get_contents()
                    output_inv.clear()

                    -- 2. ВЗЛЕТ (ВИЗУАЛЬНЫЙ)
                    surface.create_entity({
                        name = "pod-ascent-projectile",
                        position = {x = hub.position.x, y = hub.position.y - 1},
                        target = {x = hub.position.x, y = hub.position.y - 200},
                        speed = 0.2
                    })
                    surface.create_entity({name = "big-artillery-explosion", position = hub.position})
                    surface.play_sound({path = "entity-build/rocket-silo", position = hub.position, volume = 0.5})

                    -- 3. СОЗДАЕМ ВАНИЛЬНУЮ ПАДАЮЩУЮ КАПСУЛУ
                    local arrival_time = game.tick + 120 -- Падение длится 2 секунды
                    local pod = surface.create_entity({
                        name = "cargo-pod",
                        position = pad.position,
                        target = pad, -- Цель — площадка
                        arrival_tick = arrival_time, -- ВКЛЮЧАЕТ АНИМАЦИЮ СПУСКА
                        force = hub.force
                    })

                    -- 4. РЕГИСТРИРУЕМ ДОСТАВКУ
                    -- Мы сохраняем предметы в памяти, чтобы выгрузить их В МОМЕНТ ПРИЗЕМЛЕНИЯ
                    if pod then
                        table.insert(storage.deliveries, {
                            arrival_tick = arrival_time,
                            target_pad = pad,
                            items = contents,
                            pod = pod
                        })
                    end
                end
            end
        end
    end
end)

-- ЛОГИКА МОМЕНТА ПРИЗЕМЛЕНИЯ
script.on_event(defines.events.on_tick, function(event)
    if not storage.deliveries or #storage.deliveries == 0 then return end

    for i = #storage.deliveries, 1, -1 do
        local d = storage.deliveries[i]

        -- Если время приземления настало
        if event.tick >= d.arrival_tick then
            if d.target_pad and d.target_pad.valid then
                -- Перекладываем ресурсы в Cargo Landing Pad
                -- Индекс 1 у площадки - это основной инвентарь
                local pad_inv = d.target_pad.get_inventory(defines.inventory.cargo_landing_pad_main) 
                                or d.target_pad.get_main_inventory()
                
                if pad_inv then
                    for _, item_stack in ipairs(d.items) do
                        pad_inv.insert(item_stack)
                    end
                end

                -- Эффекты касания земли
                d.target_pad.surface.create_entity({name = "fusty-cloud-small", position = d.target_pad.position})
                d.target_pad.surface.play_sound({path = "entity-build/rocket-silo", position = d.target_pad.position, volume = 0.4})
            end
            
            -- Удаляем запись о доставке
            table.remove(storage.deliveries, i)
        end
    end
end)