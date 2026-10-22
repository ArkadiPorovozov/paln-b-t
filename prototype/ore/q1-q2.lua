-- Атмосферные руды q1/q2 и их жидкости.
-- Руда невидима: она нужна только как логика добычи, карта и подсветка.
-- Облака над ней — отдельные сущности (prototype/entity/clouds.lua).

local function fluid(name, color, flow_color)
  return {
    type = "fluid",
    name = name,
    icon = "__core__/graphics/empty.png",
    icon_size = 64,
    default_temperature = 15,
    max_temperature = 100,
    auto_barrel = false,
    base_color = color,
    flow_color = flow_color,
  }
end

local function ore(name, fluid_name, order, map_color, probability, richness)
  return {
    type = "resource",
    name = name,
    category = "atmospheric",
    icon = "__core__/graphics/empty.png",
    icon_size = 64,
    flags = {"placeable-neutral"},
    order = order,

    infinite = true,
    -- minimum == normal: дебит не падает по мере "истощения"
    minimum = 500,
    normal = 500,
    infinite_depletion_amount = 1,
    resource_patch_search_radius = 12,

    highlight = true,
    map_color = map_color,

    -- пустая маска: руда ничего не перекрывает, строить можно прямо на ней
    collision_mask = {layers = {}},
    collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},

    -- для жидкости нужен results, а не result
    minable = {
      mining_time = 1,
      results = {{type = "fluid", name = fluid_name, amount = 10}},
    },

    -- невидимый спрайт: руда есть, но её не видно
    stages = {
      sheet = {
        filename = "__core__/graphics/empty.png",
        priority = "extra-high",
        width = 1,
        height = 1,
        frame_count = 1,
        variation_count = 1,
        scale = 0.01,
      },
    },
    stage_counts = {1},

    autoplace = {
      probability_expression = probability,
      richness_expression = richness,
    },
  }
end

data:extend({
  fluid("q1", {r = 0.85, g = 0.90, b = 1.00}, {r = 0.95, g = 0.97, b = 1.00}),
  fluid("q2", {r = 0.95, g = 0.55, b = 0.15}, {r = 1.00, g = 0.75, b = 0.40}),

  {type = "resource-category", name = "atmospheric"},

  -- порядок ("a"/"b") важен: руды не могут лежать на одном тайле,
  -- поэтому у каждой своё поле шума
  ore("q1-ore", "q1", "e-a", {r = 0.85, g = 0.90, b = 1.00},
      "q1_ore_probability", "q1_ore_richness"),
  ore("q2-ore", "q2", "e-b", {r = 0.95, g = 0.62, b = 0.25},
      "q2_ore_probability", "q2_ore_richness"),
})
