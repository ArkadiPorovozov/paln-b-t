-- Телескоп: здание, которое ищет астероиды.
--
-- Астероид в этой механике — космическая платформа: небольшая площадка
-- (space-platform-foundation) с хабом, без двигателей, поэтому улететь она
-- не может. Из хаба можно войти/выйти, строить руками или дронами.
--
-- Телескоп ставится на планетной поверхности и ищет автоматически по таймеру.
-- Runtime-логика — script/asteroid/telescope.lua.

local ENTITY = "asteroid-telescope"

-- Внешний вид: ванильный радар (своей графики пока нет).
local telescope = table.deepcopy(data.raw["radar"]["radar"])
telescope.name = ENTITY
telescope.minable = { mining_time = 0.5, result = ENTITY }
telescope.max_health = 350
-- Телескопу не нужны связи «радар-радар» и лишние провода.
telescope.connects_to_other_radars = false
telescope.energy_usage = "150kW"

-- Предмет: иконка ванильного радара.
local item = table.deepcopy(data.raw.item["radar"])
item.name = ENTITY
item.place_result = ENTITY
item.stack_size = 20

-- Рецепт открывается вместе с космическими технологиями.
local anchor = data.raw.technology["space-science-pack"] or data.raw.technology["rocket-silo"]

local recipe = {
  type = "recipe",
  name = ENTITY,
  enabled = anchor == nil,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 20 },
    { type = "item", name = "advanced-circuit", amount = 10 },
    { type = "item", name = "processing-unit", amount = 10 },
    { type = "item", name = "radar", amount = 2 },
  },
  results = {
    { type = "item", name = ENTITY, amount = 1 },
  },
}

data:extend({ telescope, item, recipe })

if anchor then
  anchor.effects = anchor.effects or {}
  table.insert(anchor.effects, { type = "unlock-recipe", recipe = ENTITY })
end