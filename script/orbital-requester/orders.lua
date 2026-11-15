-- Список доступных заказов орбитального заказчика строительства.
-- Только данные, без обращения к GUI или игровому состоянию.
local M = {}

-- ================================================================
-- СПИСОК ЗАКАЗОВ (настраивается здесь).
-- entity — имя прототипа итоговой постройки;
-- item   — предмет, который лежит в хабе выбранной платформы.
-- Чтобы добавить здание: {entity = "имя-сущности", item = "имя-предмета"},
-- затем перезапустите Factorio/перезагрузите мод. Несуществующие прототипы
-- автоматически скрываются из меню. На один заказ расходуется один предмет.
-- ================================================================
M.LIST = {
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

-- Находит заказ по имени прототипа постройки, если оба прототипа существуют.
function M.find(entity_name)
  for _, order in ipairs(M.LIST) do
    if order.entity == entity_name and prototypes.entity[order.entity] and prototypes.item[order.item] then
      return order
    end
  end
end

-- Возвращает только те заказы, для которых есть и сущность, и предмет.
function M.targets()
  local list = {}
  for _, order in ipairs(M.LIST) do
    if prototypes.entity[order.entity] and prototypes.item[order.item] then
      list[#list + 1] = order
    end
  end
  return list
end

return M
