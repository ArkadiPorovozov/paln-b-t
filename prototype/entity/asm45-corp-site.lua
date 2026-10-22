-- Стройплощадка ассемблера asm45_corp.
--
-- Это настоящий ассемблер с фиксированным рецептом "asm45-corp-site-build":
-- каждая партия берёт по 1 единице каждого ресурса, и он сам «строится» ровно
-- столько, сколько идёт крафт. Когда отработано 10 партий,
-- script/asm45-corp-site.lua превращает площадку в готовый
-- assembling-machine-45-corp, а всё, что осталось в машине сверх этих партий,
-- сгорает.
--
-- Выглядит как готовая машина: статичная картинка asm45_corp.png + тень.
--
-- Каркасы: на первой скрафченной партии над площадкой поднимаются штатные
-- анимации постройки сущностей на космоплатформе (mb-panim-*, как в
-- script/carkas.lua), а при превращении в готовый завод — сворачиваются.

local C = require("prototype.entity.shared")
local q = C.q

local RECIPE   = "asm45-corp-site-build"
local CATEGORY = "asm45-corp-site"

data:extend(
{
  {
    type = "recipe-category",
    name = CATEGORY
  },
  {
    -- Скрытый рецепт площадки: одна единица каждого ресурса за раз,
    -- результат пустой — машина «строит» ничего. Партия идёт 2 секунды
    -- (energy_required 1 при crafting_speed 0.5).
    type = "recipe",
    name = RECIPE,
    categories = {CATEGORY},
    hidden = true,
    enabled = true,
    -- у рецепта нет результатов, поэтому иконку задаём вручную
    icon = q .. "/graphics/entity/asm45_corp/asm45_corp.png",
    icon_size = 300,
    energy_required = 1,
    ingredients =
    {
      {type = "item", name = "iron-plate", amount = 1},
      {type = "item", name = "copper-plate", amount = 1},
      {type = "item", name = "steel-plate", amount = 1},
      {type = "item", name = "electronic-circuit", amount = 1}
    },
    results = {},
    allow_productivity = false,
    allow_quality = false,
    auto_recycle = false
  }
})

local asm45_corp_site =
{
  type = "assembling-machine",
  name = "asm45-corp-site",
  localised_name = {"entity-name.asm45-corp-site"},
  localised_description = {"entity-description.asm45-corp-site"},
  icon = q .. "/graphics/entity/asm45_corp/asm45_corp.png",
  icon_size = 300,
  flags = {"placeable-neutral", "player-creation"},
  minable = {mining_time = 1, result = "assembling-machine-45-corp"},
  max_health = 300,
  collision_box = {{-1.8, -1.8}, {1.8, 1.8}},
  selection_box = {{-2, -2}, {2, 2}},
  rotatable = false,
  crafting_categories = {CATEGORY},
  -- постройка идёт неспешно: одна партия — 2 секунды, все 10 — 20 секунд
  crafting_speed = 0.5,
  fixed_recipe = RECIPE,
  -- площадке не нужно электричество: она «строится» сама
  energy_usage = "1kW",
  energy_source = {type = "void"},
  module_slots = 0,
  allowed_effects = {},
  show_recipe_icon = false,
  graphics_set =
  {
    animation =
    {
      layers =
      {
        {
          filename = q .. "/graphics/entity/asm45_corp/asm45_corp-shadow.png",
          width = 300,
          height = 300,
          scale = 0.5,
          shift = util.by_pixel_hr(40, 30),
          draw_as_shadow = true
        },
        {
          filename = q .. "/graphics/entity/asm45_corp/asm45_corp.png",
          width = 300,
          height = 300,
          scale = 0.5,
          shift = util.by_pixel_hr(0, 0)
        }
      }
    }
  }
}

data:extend({asm45_corp_site})
