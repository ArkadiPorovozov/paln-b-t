-- Теплообменник солнца.
--
-- На sun охлаждает не вода в трубах, а эта машина: пока она работает (то есть
-- пока в неё поступает вода), всё в радиусе COOLING_RADIUS не плавилось
-- (script/sun-cooling.lua). Сейчас нагрев и плавление на sun отключены — их код
-- лежит в script/sun-cooling-old.lua — поэтому машина пока только тратит воду.
--
-- Внешне это ракетная турель из space-age: берём её же спрайты, чтобы не тащить
-- в мод новые текстуры. База турели — один кадр, голова — первый кадр анимации
-- стрельбы (смещения повторяют space-age/prototypes/entity/turrets.lua).
local rocket_turret_shift = -20 -- px, как в space-age/prototypes/entity/turrets.lua

-- Пиксельное смещение слоя -> смещение в тайлах.
local function turret_shift(x, y)
  return {x / 32, (y + rocket_turret_shift) / 32}
end

-- Сколько воды машина съедает в секунду. Рецепт ниже — один крафт в секунду,
-- поэтому расход = количеству воды в рецепте.
local WATER_PER_SECOND = 6

data:extend({
  -- Своя категория, чтобы рецепт нельзя было поставить ни в одну другую машину.
  {type = "recipe-category", name = "sun-heat-exchange"},

  {
    type = "item",
    name = "sun-heat-exchanger",
    icon = "__space-age__/graphics/icons/rocket-turret.png",
    subgroup = "space-platform",
    order = "b[sun-heat-exchanger]",
    place_result = "sun-heat-exchanger",
    stack_size = 20,
    weight = 200 * kg,
  },

  {
    type = "assembling-machine",
    name = "sun-heat-exchanger",
    icon = "__space-age__/graphics/icons/rocket-turret.png",
    flags = {"placeable-player", "player-creation"},
    minable = {mining_time = 0.5, result = "sun-heat-exchanger"},
    max_health = 500,
    collision_box = {{-1.2, -1.2}, {1.2, 1.2}},
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}},

    -- Радиус охлаждения — штатная визуализация движка, как у турелей и вышек.
    -- Движок сам рисует эту текстуру по окружности и показывает её ТОЛЬКО когда
    -- машина выбрана (курсор наведён) или её держат в курсоре; в обычном
    -- состоянии отрисовки нет вовсе, скрипт за неё не платит.
    -- distance = 8 — прежний радиус охлаждения (COOLING_RADIUS в
    -- script/sun-cooling-old.lua).
    radius_visualisation_specification =
    {
      sprite =
      {
        filename = "__paln-b-test__/graphics/entity/sun-heat-exchanger/radius-visualization.png",
        size = 12,
        priority = "extra-high-no-scale",
      },
      distance = 8,
      draw_in_cursor = true,
      draw_on_selection = true,
    },

    -- Рецепт один и навсегда, поэтому машина не требует электричества:
    -- void-источник даёт «бесконечную» энергию (energy_usage при нём — только
    -- цифра в подсказке; ноль движок не любит).
    crafting_categories = {"sun-heat-exchange"},
    fixed_recipe = "sun-heat-exchange",
    crafting_speed = 1,
    energy_source = {type = "void"},
    energy_usage = "1kW",
    show_recipe_icon = false,

    graphics_set =
    {
      animation =
      {
        layers =
        {
          {
            filename = "__space-age__/graphics/entity/rocket-turret/rocket-turret-base.png",
            width = 202,
            height = 168,
            scale = 0.5,
            shift = turret_shift(-0.5, 24.5),
            priority = "high",
          },
          {
            filename = "__space-age__/graphics/entity/rocket-turret/rocket-turret-shooting-1.png",
            width = 160,
            height = 164,
            scale = 0.5,
            shift = turret_shift(0, -8.5),
            priority = "high",
          },
          {
            filename = "__space-age__/graphics/entity/rocket-turret/rocket-turret-base-shadow.png",
            width = 204,
            height = 148,
            scale = 0.5,
            shift = turret_shift(7.5, 26.5),
            draw_as_shadow = true,
          },
        },
      },
    },

    -- Вход со всех четырёх сторон: контур охлаждения — обычные трубы.
    fluid_boxes =
    {
      {
        production_type = "input",
        pipe_covers = pipecoverspictures(),
        volume = 100,
        pipe_connections =
        {
          {flow_direction = "input", direction = defines.direction.north, position = {0, -1}},
          {flow_direction = "input", direction = defines.direction.south, position = {0, 1}},
          {flow_direction = "input", direction = defines.direction.west, position = {-1, 0}},
          {flow_direction = "input", direction = defines.direction.east, position = {1, 0}},
        },
      },
    },
  },

  -- Внутренний рецепт теплообменника: вода на входе, продуктов нет.
  -- Благодаря ему вода реально тратится, а машина показывает обычный статус
  -- «работает» / «не хватает воды». В меню крафта его не видно.
  {
    type = "recipe",
    name = "sun-heat-exchange",
    categories = {"sun-heat-exchange"},
    icon = "__space-age__/graphics/icons/rocket-turret.png",
    subgroup = "space-platform",
    order = "b[sun-heat-exchanger]",
    enabled = true,
    hidden = true,
    energy_required = 1,
    ingredients = {{type = "fluid", name = "water", amount = WATER_PER_SECOND}},
    results = {},
    allow_productivity = false,
    allow_quality = false,
    allow_decomposition = false,
    auto_recycle = false,
  },

  {
    type = "recipe",
    name = "sun-heat-exchanger",
    enabled = false,
    energy_required = 10,
    ingredients =
    {
      {type = "item", name = "steel-plate", amount = 20},
      {type = "item", name = "pipe", amount = 10},
      {type = "item", name = "processing-unit", amount = 5},
    },
    results = {{type = "item", name = "sun-heat-exchanger", amount = 1}},
  },
})
