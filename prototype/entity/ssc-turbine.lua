-- ssc-turbine: турбина + её рецепт "горения" + скрытый генератор.
local C = require("prototype.entity.shared")
local q = C.q
local hit_effects, sounds = C.hit_effects, C.sounds

local ssc_turbine_it = table.deepcopy(data.raw["item"]["steam-turbine"])
ssc_turbine_it.name = "ssc-turbine"
ssc_turbine_it.icon = q .. "/graphics/entity/ssc_turbine/ssc_turbine.png"
ssc_turbine_it.icon_size = 349
ssc_turbine_it.place_result = ssc_turbine_it.name
ssc_turbine_it.subgroup = "space-platform"
data:extend({ssc_turbine_it})


-- ssc-turbine: работает на льду + твёрдом топливе и выдаёт 50MW.
-- Сама турбина — это assembling-machine с фиксированным рецептом
-- (тратит 1 лёд + 1 твёрдое топливо в секунду), а электричество выдаёт
-- скрытый "ssc-turbine-generator" (см. script/ssc-turbine.lua).
local ssc_turbine = {}
ssc_turbine.type = "assembling-machine"
ssc_turbine.name = ssc_turbine_it.name
ssc_turbine.icon = ssc_turbine_it.icon
ssc_turbine.icon_size = ssc_turbine_it.icon_size
ssc_turbine.minable = {mining_time = 0.4, result = ssc_turbine_it.name}
ssc_turbine.flags = {"placeable-neutral", "placeable-player", "player-creation"}
ssc_turbine.resistances = {{ type = "fire", percent = 70 }}
ssc_turbine.collision_box = {{-2.3, -2.3}, {2.3, 2.3}}
ssc_turbine.selection_box = {{-2.5, -2.5}, {2.5, 2.5}}
ssc_turbine.damaged_trigger_effect = hit_effects.entity()
ssc_turbine.crafting_categories = {"ssc-turbine"}
ssc_turbine.fixed_recipe = "ssc-turbine-burn"
ssc_turbine.show_recipe_icon = false
ssc_turbine.crafting_speed = 1
ssc_turbine.energy_source = { type = "void" }
ssc_turbine.energy_usage = "1W"
ssc_turbine.open_sound = sounds.machine_open
ssc_turbine.close_sound = sounds.machine_close
ssc_turbine.working_sound = {
  sound =
  {
    filename = "__base__/sound/steam-turbine.ogg",
    volume = 0.49,
    modifiers = volume_multiplier("main-menu", 0.7),
    speed_smoothing_window_size = 60,
    advanced_volume_control = {attenuation = "exponential"},
    audible_distance_modifier = 0.8,
  },
  match_speed_to_activity = true,
  max_sounds_per_prototype = 3,
  fade_in_ticks = 4,
  fade_out_ticks = 20
  }
local turbine_animation = {
    layers = {
        {
          filename = q .. "/graphics/entity/ssc_turbine/ssc_turbine.png",
          width = 349,
          height = 353,
          frame_count = 1,
          repeat_count = 32,
          line_length = 1,
          shift = util.by_pixel_hr(0.5, 0.5),
          scale = 0.5
        },
        {
          filename = q .. "/graphics/entity/ssc_turbine/ssc_turbine-shadow.png",
          width = 298,
          height = 303,
          frame_count = 1,
          repeat_count = 32,
          line_length = 1,
          draw_as_shadow = true,
          shift = util.by_pixel_hr(70, 20),
          scale = 0.6
        },
        {
          filename = "__base__/graphics/entity/cargo-hubs/hubs/planet-hub-turbine.png",
          width = 116,
          height = 78,
          frame_count = 32,
          line_length = 8,
          lines_per_file = 4,
          scale = 0.5,
          shift = util.by_pixel_hr(14, -100),
          animation_speed = 1
        },
    }
}
ssc_turbine.graphics_set = { animation = turbine_animation }
data:extend({ssc_turbine})

-- Рецепт "горения" турбины: тратит лёд + твёрдое топливо (без результата).
-- Иконка прозрачная (рецепт скрытый и фиксированный) — визуально её нет.
data:extend({
  { type = "recipe-category", name = "ssc-turbine" },
  {
    type = "recipe",
    name = "ssc-turbine-burn",
    categories = {"ssc-turbine"},
    enabled = true,
    hidden = true,
    energy_required = 1,
    icon = "__core__/graphics/empty.png",
    icon_size = 64,
    ingredients = {
      { type = "item", name = "ice", amount = 1 },
      { type = "item", name = "solid-fuel", amount = 1 },
    },
    results = {},
  },
})

-- Скрытый генератор на 50MW.
-- Это автоматический "ребёнок" турбины в терминах библиотеки 0-things:
-- Things сам создаёт его вместе с турбиной (в т.ч. при постройке из чертежа)
-- и уничтожает вместе с ней. Скрипт script/ssc-turbine.lua его не трогает:
-- он лишь включает генератор (50MW), пока турбина жжёт топливо, и выключает
-- (0), когда не жжёт.
-- Флаг "not-blueprintable" обязателен: не-Thing дети в Things должны быть
-- неблюпринтуемыми (иначе Things падает с ошибкой при загрузке данных).
-- Мощность задаётся полем energy_production (50MW); в рантайме то же значение
-- доступно как power_production и измеряется в Дж/тик (50e6/60).
data:extend({{
  type = "electric-energy-interface",
  name = "ssc-turbine-generator",
  icon = ssc_turbine_it.icon,
  icon_size = ssc_turbine_it.icon_size,
  flags = {"placeable-neutral", "hide-alt-info", "not-blueprintable"},
  hidden_in_factoriopedia = true,
  selectable_in_game = false,
  collision_mask = { layers = {} },
  -- Провода подключаются к границе сущности, поэтому генератор — размером с саму
  -- турбину: иначе провода уходили бы в её центр. Коллизии у него нет (маска
  -- пустая), так что на постройку и проход это не влияет.
  collision_box = {{-2.3, -2.3}, {2.3, 2.3}},
  selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
  max_health = 1,
  energy_source = {
    type = "electric",
    usage_priority = "primary-output",
    buffer_capacity = "50MJ",
  },
  energy_production = "50MW",
  gui_mode = "none",
}})
