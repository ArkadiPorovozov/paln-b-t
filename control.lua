-- control.lua
-- Подключаем наши элитные модули из папки script
local config = require("script.config")
local effects = require("script.effects")

-- Инициализация storage для Factorio 2.1
local function ensure_storage()
    storage.scrubbers = storage.scrubbers or {}
end

script.on_init(ensure_storage)
script.on_configuration_changed(ensure_storage)

-- Функция поиска всех типов рабов в квадратной зоне
local function get_slaves_in_square(scrubber)
    local r = config.scrubber.square_range
    local pos = scrubber.position
    local area = {{pos.x - r, pos.y - r}, {pos.x + r, pos.y + r}}
    
    return scrubber.surface.find_entities_filtered{
        area = area,
        name = config.slaves.target_names 
    }
end

-- Основной цикл Workout (наказание)
script.on_nth_tick(config.scrubber.check_interval, function(event)
    ensure_storage()
    
    -- Чистим список Scrubbers
    for i = #storage.scrubbers, 1, -1 do
        local scrubber = storage.scrubbers[i]
        
        if not scrubber or not scrubber.valid then
            table.remove(storage.scrubbers, i)
        else
            -- Наказываем только когда Scrubber РАБОТАЕТ
            if scrubber.status == defines.entity_status.working then
                
                -- 1. Вызываем пар на самом мастере
                effects.spawn_turbine_steam(scrubber)
                
                -- 2. Рассчитываем урон (база * множитель скорости от маяков/модулей)
                local current_speed = scrubber.crafting_speed
                local final_damage = config.scrubber.base_damage * current_speed
                
                -- 3. Находим всех рабов в квадрате
                local slaves = get_slaves_in_square(scrubber)
                
                for _, slave in pairs(slaves) do
                    if slave.valid then
                        -- Физическое внушение (урон)
                        slave.damage(final_damage, scrubber.force, config.scrubber.damage_type)
                        
                        -- Визуальное внушение (дым на рабе)
                        effects.spawn_punishment_smoke(slave, current_speed)
                    end
                end
            end
        end
    end
end)

-- ♂️ RIGHT VERSION: Логика запрета на пересечение зон ♂️
local function on_built(event)
    ensure_storage()
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end

    if entity.name == config.scrubber.name then
        local pos = entity.position
        -- Чтобы зоны 30x30 не пересекались, расстояние между центрами 
        -- должно быть минимум 2 * square_range (т.е. 30 метров)
        local r = config.scrubber.square_range * 2
        
        local area = {
            {pos.x - (r - 0.1), pos.y - (r - 0.1)}, 
            {pos.x + (r - 0.1), pos.y + (r - 0.1)}
        }
        
        -- Ищем конкурентов в двойном радиусе
        local rivals = entity.surface.find_entities_filtered{
            area = area,
            name = config.scrubber.name
        }

        -- Если нашли больше одного (включая только что поставленный), значит Gym переполнен
        if #rivals > 1 then
            local player = event.player_index and game.get_player(event.player_index)
            if player then
                -- Выдаем брутальное предупреждение
                player.create_local_flying_text{
                    text = "THIS GYM IS TOO SMALL FOR TWO MASTERS! ♂️",
                    position = entity.position,
                    color = {r = 1, g = 0, b = 0}
                }
                -- Возвращаем Scrubber в инвентарь или выбрасываем рядом
                local inserted = player.insert({name = config.scrubber.name, count = 1})
                if inserted == 0 then
                    entity.surface.spill_item_stack(entity.position, {name = config.scrubber.name, count = 1})
                end
            end
            
            -- Удаляем нарушителя границ
            entity.destroy()
            return
        end
        
        -- Если всё чисто — регистрируем нового хозяина
        table.insert(storage.scrubbers, entity)
    end
end

script.on_event({
    defines.events.on_built_entity, 
    defines.events.on_robot_built_entity, 
    defines.events.on_space_platform_built_entity
}, on_built)