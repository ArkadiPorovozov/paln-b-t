local config = require("script.config")
local work = {}

-- ♂️ SURGICAL FIX: Lazy Initialization ♂️
local function get_backup_table()
    if not storage.backup_recipes then
        storage.backup_recipes = {}
    end
    return storage.backup_recipes
end

function work.update_entity(entity, surface)
    if not (entity and entity.valid) then return end
    
    local r = config.radius
    local pos = entity.position
    local u = entity.unit_number
    local backup_recipes = get_backup_table() -- ♂️ Safe access ♂️
    
    -- Поиск Босса в квадрате
    local masters = surface.find_entities_filtered{
        name = config.scrubber_name,
        area = {{pos.x - r, pos.y - r}, {pos.x + r, pos.y + r}}
    }

    local has_master = false
    for _, m in pairs(masters) do
        if m.active and (m.status == defines.entity_status.working or m.status == defines.entity_status.normal) then
            has_master = true
            break
        end
    end

    if not has_master then
        -- ♂️ DISABLING ♂️
        entity.operable = false
        
        local current_recipe = entity.get_recipe()
        if current_recipe then
            backup_recipes[u] = current_recipe.name
            entity.set_recipe(nil)
            game.print("♂️ Scrubber: Jabroni " .. entity.name .. " lost his recipe! ♂️")
        end
    else
        -- ♂️ ENABLING ♂️
        entity.operable = true
        
        if backup_recipes[u] then
            local r_name = backup_recipes[u]
            entity.set_recipe(r_name)
            backup_recipes[u] = nil
            game.print("♂️ Scrubber: Slave " .. entity.name .. " returned to work! ♂️")
        end
    end
end

function work.process_all(surface)
    for slave_name, _ in pairs(config.slaves) do
        local entities = surface.find_entities_filtered{name = slave_name}
        for _, e in pairs(entities) do
            work.update_entity(e, surface)
        end
    end
end

return work