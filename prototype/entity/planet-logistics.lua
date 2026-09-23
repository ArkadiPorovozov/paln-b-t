local q = "__paln-b-test__"
local items_to_pack = { "iron-plate", "copper-plate", "steel-plate", "coal", "stone" }

data:extend({{ type = "recipe-category", name = "planetary-packaging" }})

-- Рецепты отправки
for _, item_name in ipairs(items_to_pack) do
  local base_item = data.raw.item[item_name]
  if base_item then
    data:extend({
      {
        type = "recipe",
        name = "send-" .. item_name,
        enabled = true,
        ingredients = {
          { type = "item", name = item_name, amount = 100 },
          { type = "item", name = "low-density-structure", amount = 20 }
        },
        results = {{ type = "item", name = item_name, amount = 100 }},
        energy_required = 2,
        categories = { "planetary-packaging" }
      }
    })
  end
end

data:extend({
  {
    type = "projectile",
    name = "pod-ascent-projectile",
    flags = {"not-on-map", "placeable-off-grid"},
    acceleration = 0.05,
    action = nil, -- Он ничего не взрывает при попадании
    animation = {
      filename = "__base__/graphics/entity/cargo-pod/pod-static-detached.png",
      width = 78,
      height = 172,
      frame_count = 1,
      scale = 0.5,
      priority = "high",
      run_mode = "forward"
    },
    speed = 0.2, -- Высокая начальная скорость
    light = {intensity = 0.5, size = 10, color = {r=1, g=0.8, b=0.6}},
    smoke = {
      {
        name = "smoke-fast",
        deviation = {0.15, 0.15},
        frequency = 1,
        position = {0, 0},
        slow_down_factor = 0.9,
        starting_frame = 3,
        starting_frame_deviation = 5,
        starting_velocity_deviation = 0.2
      }
    }
  }
})

local hub_it = table.deepcopy(data.raw.item["assembling-machine-3"])
hub_it.name = "planetary-hub"
hub_it.place_result = "planetary-hub"
hub_it.icon = "__base__/graphics/icons/rocket-silo.png"
hub_it.subgroup = "space-platform"
data:extend({ hub_it })

local col = 2.25
local sel = 2

local hub = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
hub.name = "planetary-hub"
hub.minable = { mining_time = 0.5, result = "planetary-hub" }
hub.collision_box = { { -col, -col }, { col, col } }
hub.selection_box = { { -sel, -sel }, { sel, sel } }
hub.crafting_categories = { "planetary-packaging" }
hub.fixed_recipe = nil
hub.crafting_speed = 0.8
hub.graphics_set = {
  animation = {
    layers = {
      {
        filename = q .. "/graphics/entity/saf123.png",
        width = 444,
        height = 460,
        scale = 0.5,
        frame_count = 1
      },
      {
        filename = "__space-age__/graphics/entity/cargo-hubs/hubs/platform-hub-1-B.png",
        shift = util.by_pixel(0, -23),
        width = 234,
        height = 176,
        scale = 0.5,
        frame_count = 1
      },
      {
        filename = "__space-age__/graphics/entity/cargo-hubs/hatches/platform-lower-hatch-occluder.png",
        width = 256,
        height = 142,
        frame_count = 1,
        shift = util.by_pixel(2, -2),
        render_layer = "higher-object-above",
        scale = 0.5
      }
    }
  }
}
hub.circuit_wire_max_distance = 15
hub.circuit_connector_definition = circuit_connector_definitions["assembling-machine"]
hub.draw_circuit_indicator = true

data:extend({ hub })
