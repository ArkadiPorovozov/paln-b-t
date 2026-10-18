-- Клонирование прототипа (обычно из другого мода) с правками и удалением полей.
-- Возвращает функцию, чтобы файлы-прототипы могли взять её так:
--   local clone_entity = require("prototype.entity.clone-entity")
local function clone_entity(source_type, source_name, new_name, overrides, to_remove)
    local source = data.raw[source_type][source_name]
    if not source then return nil end

    local new_obj = table.deepcopy(source)
    new_obj.name = new_name


    if overrides then
        for key, value in pairs(overrides) do
            new_obj[key] = value
        end
    end


    local keys_to_kill = to_remove or { "surface_conditions", "surface_condition", "bound_decoratives" }
    for _, key in ipairs(keys_to_kill) do
        new_obj[key] = nil
    end

    return new_obj
end

return clone_entity
