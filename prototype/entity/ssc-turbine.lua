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


-- ssc-turbine: работает на льду + твёрдом топливе и выдаёт 6MW.
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

-- Скрытый генератор на 6MW.
-- Это автоматический "ребёнок" турбины в терминах библиотеки 0-things:
-- Things сам создаёт его вместе с турбиной (в т.ч. при постройке из чертежа)
-- и уничтожает вместе с ней. Скрипт script/ssc-turbine.lua его не трогает:
-- он лишь включает генератор (6MW), пока турбина жжёт топливо, и выключает
-- (0), когда не жжёт.
-- Флаг "not-blueprintable" обязателен: не-Thing дети в Things должны быть
-- неблюпринтуемыми (иначе Things падает с ошибкой при загрузке данных).
-- Мощность задаётся полем energy_production (6MW); в рантайме то же значение
-- доступно как power_production и измеряется в Дж/тик (6e6/60).
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
    -- Ровно один тик выработки на 6 МВт: больше не нужно, иначе GUI
    -- показывает буфер как «максимальную выработку» (6 МДж/тик = 360 МВт).
    buffer_capacity = "100kJ",
  },
  energy_production = "6MW",
  gui_mode = "none",
}})

-- Пар из трубы турбины.
--
-- Это точная копия ванильного "turbine-smoke" (тот же цвет, размер, время
-- жизни и анимация), только под своим именем: у каждого прототипа дыма лимит
-- 255 одновременно живущих экземпляров, и копия не отбирает бюджет у обычных
-- паровых турбин.
--
-- Пускает пар не create_trivial_smoke (он не умеет вертикальную скорость), а
-- скрытый particle-source: у него есть starting_vertical_speed, поэтому клубы
-- поднимаются вверх ровно так же, как у ванильной паровой турбины.
data:extend({
  {
    type = "trivial-smoke",
    name = "ssc-turbine-steam",
    duration = 600,
    fade_in_duration = 30,
    fade_away_duration = 570,
    spread_duration = 600,
    start_scale = 0.8,
    end_scale = 1.0,
    color = {r = 0.5, g = 0.5, b = 0.5, a = 0.3},
    cyclic = true,
    affected_by_wind = true,
    render_layer = "smoke",
    animation = {
      filename = "__base__/graphics/entity/smoke/smoke.png",
      priority = "high",
      width = 152,
      height = 120,
      line_length = 5,
      frame_count = 60,
      shift = {-0.53125, -0.4375},
      animation_speed = 0.25,
      flags = {"smoke"},
    },
  },
  {
    -- Скрытый источник пара: сам не рисуется, но пока существует — пускает
    -- клубы "ssc-turbine-steam" из своей позиции. Скрипт создаёт его, пока
    -- турбина работает, и удаляет, когда она гаснет.
    type = "particle-source",
    name = "ssc-turbine-steam-source",
    icon = "__core__/graphics/empty.png",
    icon_size = 64,
    flags = {"not-on-map"},
    hidden = true,
    hidden_in_factoriopedia = true,
    selectable_in_game = false,
    -- время в секундах; если источник всё же истечёт, скрипт создаст новый
    time_to_live = 60 * 60 * 24,
    time_before_start = 0,
    height = 0,
    vertical_speed = 0,
    horizontal_speed = 0,
    smoke = {
      {
        name = "ssc-turbine-steam",
        position = {0, 0},
        -- как у ванильной steam-turbine
        frequency = 10 / 32,
        starting_vertical_speed = 0.08,
        starting_vertical_speed_deviation = 0,
        starting_frame_deviation = 60,
      },
    },
  },
})
