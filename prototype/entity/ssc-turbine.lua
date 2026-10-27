-- ssc-turbine (v3): турбина = нативный КОТЁЛ + нативный генератор.
--
-- Механика: турбина жжёт твёрдое топливо и пьёт воду, гонит пар 500 °C; этот пар
-- жжёт нативный генератор "ssc-turbine-plant", который выдаёт ровно 6 МВт.
--
-- Почему именно котёл, а не генератор: нативный "generator" умеет жечь ТОЛЬКО
-- жидкость (его energy_source — это electric-output, burner-а у него нет),
-- предметы он не ест в принципе. Котёл — единственная нативная сущность, которая
-- жжёт предмет-топливо И пьёт воду. Поэтому схема ровно ванильная: котёл +
-- генератор, ни одного своего рецепта и ни одной своей жидкости.
--
-- Lua (script/ssc-turbine.lua) делает ровно одно: один раз связывает паровой бак
-- котла с паровым баком генератора ("linked"-связью — сущности стоят на одном
-- месте, обычной трубой их не соединить). Дальше всё считает движок, без тиков.
--
-- Прототип старой реализации лежит рядом, в ssc-turbine-old.lua.
--
-- Про смену ТИПА сущности с assembling-machine на boiler: движок это переживает —
-- при загрузке старого сейва турбина просто становится котлом (проверено). Так
-- что старая постройка не пропадёт, но её содержимое (лёд/топливо) может
-- потеряться — это ок, задание было «снести всё нахуй».

local C = require("prototype.entity.shared")
local q = C.q
local hit_effects, sounds = C.hit_effects, C.sounds

-- Из этих чисел получается ровно 6 МВт.
--
-- Пар — обычный ванильный steam: теплоёмкость 0.2 кДж/°C, вода на входе 15 °C,
-- максимальная температура пара 500 °C (движок не даёт выше — 515 движок
-- отвергает с ошибкой «target_temperature must be within the temperature limits
-- of the target fluid»). Значит единица пара при 500 °C несёт:
--     (500 - 15) * 0.2 = 97 кДж.
-- Чтобы получить ровно 6 МВт, генератор должен жечь
--     6000 кДж/с / 97 кДж = 61.86 ед./с = 100/97 ед./тик.
-- Отсюда FLUID_USAGE_PER_TICK = 100/97. Котёл при energy_consumption = 6MW
-- греет ровно те же 61.86 ед. воды/с из 15 °C в 500 °C, т.е. тратит на это
-- ровно 6 МВт топлива. Баланс сходится: сколько МВт сжёг — столько и выдал.
local STEAM_TEMPERATURE = 500
local POWER = "6MW"
local FLUID_USAGE_PER_TICK = 100 / 97

-- Совместимость со старыми сейвами: рабочая жидкость прошлой версии.
-- Новый код её не использует, но прототип оставлен, чтобы сейвы, где она ещё
-- налита в баки, вообще загружались (иначе — «fluid not found»).
data:extend({
  {
    type = "fluid",
    name = "ssc-turbine-plasma",
    icon = q .. "/graphics/entity/ssc_turbine/ssc_turbine.png",
    icon_size = 349,
    default_temperature = 500,
    max_temperature = 1000,
    heat_capacity = "0.2kJ",
    fuel_value = "1MJ",
    base_color = {r = 0.6, g = 0.7, b = 1.0},
    flow_color = {r = 0.75, g = 0.8, b = 1.0},
    auto_barrel = false,
    hidden = true,
  },
})

local ssc_turbine_it = table.deepcopy(data.raw["item"]["steam-turbine"])
ssc_turbine_it.name = "ssc-turbine"
ssc_turbine_it.icon = q .. "/graphics/entity/ssc_turbine/ssc_turbine.png"
ssc_turbine_it.icon_size = 349
ssc_turbine_it.place_result = ssc_turbine_it.name
ssc_turbine_it.subgroup = "space-platform"
data:extend({ssc_turbine_it})

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

-- Котёл обязан иметь картинки на все 4 стороны. У турбины арт один и тот же во
-- все стороны (как было), поэтому просто копируем её анимацию.
local function boiler_pictures()
  local function side()
    return { structure = table.deepcopy(turbine_animation) }
  end
  return {
    north = side(),
    east = side(),
    south = side(),
    west = side(),
  }
end

-- Турбина = нативный котёл: burner (твёрдое топливо) + вода -> пар.
local ssc_turbine = {}
ssc_turbine.type = "boiler"
ssc_turbine.name = ssc_turbine_it.name
ssc_turbine.icon = ssc_turbine_it.icon
ssc_turbine.icon_size = ssc_turbine_it.icon_size
ssc_turbine.minable = {mining_time = 0.4, result = ssc_turbine_it.name}
ssc_turbine.flags = {"placeable-neutral", "placeable-player", "player-creation"}
ssc_turbine.max_health = 400
ssc_turbine.resistances = {{ type = "fire", percent = 70 }}
ssc_turbine.collision_box = {{-2.3, -2.3}, {2.3, 2.3}}
ssc_turbine.selection_box = {{-2.5, -2.5}, {2.5, 2.5}}
ssc_turbine.damaged_trigger_effect = hit_effects.entity()

-- "output-to-separate-pipe": вода входит в fluid_box и выходит паром из
-- output_fluid_box. Теплоёмкости воды и пара равны (0.2 кДж), поэтому 1 вода ->
-- 1 пар.
ssc_turbine.mode = "output-to-separate-pipe"
ssc_turbine.target_temperature = STEAM_TEMPERATURE

-- Обязательное поле котла (optional=false в API), у ванильного котла = 20.
-- Без него прототип не загружается: «Key "burning_cooldown" not found».
ssc_turbine.burning_cooldown = 20

-- 6 МВт топлива -> 6 МВт тепла в пар. Сколько именно твёрдого топлива сгорит
-- в секунду — движок считает сам из fuel_value предмета (в разных сборках оно
-- разное), но мощность всегда ровно 6 МВт.
ssc_turbine.energy_consumption = POWER
ssc_turbine.energy_source = {
  type = "burner",
  fuel_categories = {"chemical"},
  effectivity = 1,
  fuel_inventory_size = 1,
}

-- Входной бак: вода. Подключается обычными трубами с любой стороны.
ssc_turbine.fluid_box = {
  volume = 200,
  production_type = "input",
  filter = "water",
  pipe_connections = {
    { flow_direction = "input-output", direction = defines.direction.west,  position = {-2,  0} },
    { flow_direction = "input-output", direction = defines.direction.east,  position = { 2,  0} },
    { flow_direction = "input-output", direction = defines.direction.north, position = { 0, -2} },
    { flow_direction = "input-output", direction = defines.direction.south, position = { 0,  2} },
  },
}

-- Выходной бак: пар. Соединён с генератором "linked"-связью (её регистрирует
-- скрипт один раз: turbine.add_fluid_box_linked_connection(1, generator, 1)).
-- direction у соединения обязателен для движка; для linked ни на что не влияет.
ssc_turbine.output_fluid_box = {
  volume = 200,
  production_type = "output",
  filter = "steam",
  pipe_connections = {
    {
      position = {0, 0},
      direction = defines.direction.north,
      flow_direction = "output",
      connection_type = "linked",
      linked_connection_id = 1,
    },
  },
}

ssc_turbine.open_sound = sounds.machine_open
ssc_turbine.close_sound = sounds.machine_close
ssc_turbine.pictures = boiler_pictures()
data:extend({ssc_turbine})

-- Нативный генератор на 6 МВт: жжёт пар из котла.
--
-- Это автоматический "ребёнок" турбины в терминах библиотеки 0-things:
-- Things сам создаёт его вместе с турбиной (в т.ч. из чертежа) и уничтожает
-- вместе с ней. Скрипт его не обслуживает: он сам глохнет без пара и сам пускает
-- пар (поле smoke).
--
-- Флаг "not-blueprintable" обязателен: не-Thing дети в Things должны быть
-- неблюпринтуемыми.
data:extend({{
  type = "generator",
  name = "ssc-turbine-plant",
  icon = ssc_turbine_it.icon,
  icon_size = ssc_turbine_it.icon_size,
  flags = {"placeable-neutral", "hide-alt-info", "not-blueprintable"},
  hidden_in_factoriopedia = true,
  selectable_in_game = false,
  collision_mask = { layers = {} },
  -- Провода подключаются к границе сущности, поэтому генератор размером с саму
  -- турбину. Коллизии нет (маска пустая), на постройку и проход не влияет.
  collision_box = {{-2.3, -2.3}, {2.3, 2.3}},
  selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
  max_health = 1,
  energy_source = {
    type = "electric",
    -- Как у ванильной паровой турбины (см. base/.../entities.lua, steam-turbine).
    usage_priority = "secondary-output",
  },
  -- Входной бак связан с паровым баком котла "linked"-связью (регистрирует скрипт).
  -- production_type = "input" обязателен — без него движок не считает пар входным
  -- и генератор не жжёт его (проверено: с ним статус "working", без него пар
  -- стоит в баке, а выработка 0).
  fluid_box = {
    filter = "steam",
    volume = 200,
    production_type = "input",
    pipe_connections = {
      {
        position = {0, 0},
        direction = defines.direction.north,
        flow_direction = "input",
        connection_type = "linked",
        linked_connection_id = 1,
      },
    },
  },
  -- 100/97 ед./тик ≈ 61.86 ед./с; 97 кДж на единицу при 500 °C => 6 МВт.
  fluid_usage_per_tick = FLUID_USAGE_PER_TICK,
  burns_fluid = false,
  minimum_input_temperature = 100,
  maximum_temperature = STEAM_TEMPERATURE,
  effectivity = 1,
  max_power_output = POWER,
  -- Звук турбины — здесь, на ГЕНЕРАТОРЕ, а не на котле.
  --
  -- working_sound играет, пока сущность «работает». Котёл «работает» всегда, пока
  -- в нём есть топливо и вода: он горит и гонит пар независимо от того, нужна ли
  -- кому-то электроэнергия. У генератора же статус «working», когда он подключён и
  -- в нём есть пар, а его activity — это ДОЛЯ текущей выработки от максимума
  -- (0..1): при простое, когда сеть не берёт мощность, пар не жжётся и activity = 0.
  -- В этом и разница, поэтому звук стоит на генераторе.
  --
  -- ВАЖНО: одного match_speed_to_activity мало. При нулевой нагрузке activity = 0,
  -- скорость воспроизведения уходит в 0, но сам луп всё равно слышен (это и было
  -- «звук при простое»). Тишину даёт только match_volume_to_activity: громкость =
  -- activity, значит при 0 нагрузки — 0, т.е. полная тишина. Так же сделано у
  -- ванильного heat-pipe (громкость = активность). Ванильные генераторы (steam-
  -- engine/turbine, burner-generator) match_volume_to_activity НЕ используют — они
  -- специально держат perceived_performance.minimum = 0.25, чтобы гудеть на холостых
  -- (и визуально тихо вращаться). Нам нужна тишина, поэтому floor убираем:
  -- perceived_performance.minimum = 0, и activity свободно доходит до нуля.
  working_sound = {
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
    -- Громкость пропорциональна нагрузке: 0 нагрузки -> 0 громкости -> тишина.
    match_volume_to_activity = true,
    activity_to_volume_modifiers = {multiplier = 1, minimum = 0, maximum = 1},
    max_sounds_per_prototype = 3,
    fade_in_ticks = 4,
    fade_out_ticks = 20
  },
  -- Доля нагрузки, без «пола» из ванили: при простое activity = 0 (см. выше про
  -- match_volume_to_activity). Максимум = 1, чтобы звук не разгонялся выше нормы.
  perceived_performance = {minimum = 0, maximum = 1},
  -- Пар пускает сам генератор, только пока работает.
  smoke = {
    {
      name = "ssc-turbine-steam",
      frequency = 0.5,
      position = {0.36, -1.7},
      starting_vertical_speed = 0.08,
      starting_vertical_speed_deviation = 0,
      starting_frame_deviation = 60,
    },
  },
}})

-- Пар из трубы турбины.
--
-- Точная копия ванильного "turbine-smoke" (тот же цвет, размер, время жизни и
-- анимация), только под своим именем: у каждого прототипа дыма лимит 255
-- одновременно живущих экземпляров, и копия не отбирает бюджет у обычных
-- паровых турбин.
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
})

-- =====================================================================
-- Совместимость со старыми сейвами (можно удалить, когда старых сейвов не
-- останется).
--
-- Раньше генератором был electric-energy-interface "ssc-turbine-generator", а
-- пар пускал скрытый particle-source "ssc-turbine-steam-source". Новый код эти
-- сущности не создаёт (script/ssc-turbine.lua при обновлении сейва их удаляет),
-- но прототипы оставлены, чтобы старые сейвы вообще загружались.
-- =====================================================================
data:extend({
  {
    type = "electric-energy-interface",
    name = "ssc-turbine-generator",
    icon = ssc_turbine_it.icon,
    icon_size = ssc_turbine_it.icon_size,
    flags = {"placeable-neutral", "hide-alt-info", "not-blueprintable"},
    hidden_in_factoriopedia = true,
    selectable_in_game = false,
    collision_mask = { layers = {} },
    collision_box = {{-2.3, -2.3}, {2.3, 2.3}},
    selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
    max_health = 1,
    energy_source = {
      type = "electric",
      usage_priority = "primary-output",
      buffer_capacity = "100kJ",
    },
    energy_production = "6MW",
    gui_mode = "none",
  },
  {
    type = "particle-source",
    name = "ssc-turbine-steam-source",
    icon = "__core__/graphics/empty.png",
    icon_size = 64,
    flags = {"not-on-map"},
    hidden = true,
    hidden_in_factoriopedia = true,
    selectable_in_game = false,
    time_to_live = 60 * 60 * 24,
    time_before_start = 0,
    height = 0,
    vertical_speed = 0,
    horizontal_speed = 0,
    smoke = {
      {
        name = "ssc-turbine-steam",
        position = {0, 0},
        frequency = 10 / 32,
        starting_vertical_speed = 0.08,
        starting_vertical_speed_deviation = 0,
        starting_frame_deviation = 60,
      },
    },
  },
})
