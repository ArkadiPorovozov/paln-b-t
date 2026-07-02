local config = require("config")
local work = {}

-- Обновление состояния конкретного "раба"
function work.update_slave_status(entity)
    local master_name = config.slaves[entity.name]
    if not master_name then return end

    local r = config.scrubbers[master_name].radius
    local pos = entity.position
    
    local master_gym = entity.surface.find_entities_filtered{
        name = master_name,
        area = {{pos.x - r, pos.y - r}, {pos.x + r, pos.y + r}}
    }

    -- Проверяем, есть ли хоть один активный (запитанный) скруббер
    local active_master = false
    for _, m in pairs(master_gym) do
        if m.status ~= defines.entity_status.no_power then
            active_master = true
            break
        end
    end

    entity.active = active_master
end

-- Глобальная проверка по всем поверхностям
function work.process_all_slaves()
    for _, surface in pairs(game.surfaces) do
        for slave_name, _ in pairs(config.slaves) do
            local entities = surface.find_entities_filtered{name = slave_name}
            for _, e in pairs(entities) do
                work.update_slave_status(e)
            end
        end
    end
end

return work