-- Орбитальный заказчик строительства: прототипы (data-стадия).
--
-- Ставится на поверхность планеты, открывает GUI и по заказу вызывает капсулу
-- с выбранной космической платформы. Runtime-логика — в script/orbital-requester/.
--
-- Внешне пока ванильный постоянный комбинатор: новая графика не добавлялась.
-- Рамка заказчика занимает 4×4 тайла и не имеет коллизии с будущим зданием —
-- остальные препятствия при постройке всё равно проверяются скриптом.

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
