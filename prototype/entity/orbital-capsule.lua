-- Орбитальная капсула: капсула-шахта 3×3.
--
-- Функционально это rocket-silo, но от ванильной шахты не остаётся ничего:
-- все поля заданы явно, и графики «здания» нет вообще. На карте видна только
-- сама капсула — закрытый грузовой под, — а не площадка, люк, руки и прочие
-- оверлеи шахты.
--
-- Раскладка графики (ванильные спрайты грузовой капсулы):
--   * капсула (когда собрана ракета) ... pod-static-detached (rocket_sprite);
--   * капсула в простое ................ pod-static-detached (рисует скрипт,
--                                        прототип "orbital-capsule-parked");
--   * тень ............................. pod-static-shadow  (рисует скрипт,
--                                        прототип "orbital-capsule-shadow").
--
-- У rocket-silo база (base_day_sprite) и тень (shadow_sprite) рисуются движком
-- всегда, и убрать их на время запуска нельзя. Поэтому база не задана вовсе:
-- в простое капсулу и тень рисует скрипт (script/orbital-capsule.lua), а когда
-- в шахте собрана ракета — капсулу рисует движок через rocket_sprite. При
-- запуске поднимается и улетает ровно одна капсула, без «остатка» на земле.
--
-- Капсула-ракета не предмет и не вынимается ни игроком, ни инсертерами: её
-- можно только запустить.
--
-- Заправка: один компонент — 1000 thruster-fuel. Окислитель не нужен.
-- Рецепт шахты даёт ровно один rocket-part, поэтому на запуск уходит ровно
-- 1000 топлива. Электричество не требуется: energy_source = void.
--
-- Пламя (pod-thruster-ignition → pod-thruster-loop) задано отдельными
-- прототипами и рисуется скриптом только на время запуска: родное поле
-- rocket_flame_animation движок проигрывает постоянно, и на стоянке огонь
-- горел бы даже в простое.

local q = "__paln-b-test__"

-- Масштаб ванильных спрайтов капсулы: как в cargo-pod-catalogue.
local POD_SCALE = 0.5

-- Насколько поднять капсулу над землёй (пиксели, вверх — положительное).
local CAPSULE_RAISE_PX = 8

-- Сдвиг тени капсулы влево (пиксели; отрицательное — влево).
local SHADOW_LEFT_PX = -10

-- Капсула-ребёнок: обязательное поле rocket_entity у шахты.
-- Она не выбирается, не попадает на карту и не минится — только летит.
local rocket = {
  type = "rocket-silo-rocket",
  name = "orbital-capsule-rocket",
  flags = {"not-on-map", "not-selectable-in-game", "not-deconstructable", "not-blueprintable"},
  hidden = true,
  collision_mask = {layers = {}, not_colliding_with_itself = true},
  collision_box = {{-1, -1}, {1, 1}},
  selection_box = {{0, 0}, {0, 0}},

  inventory_size = 20,
  cargo_pod_entity = "cargo-pod",
  -- Иконка в alt-режиме (если появится) — в «воздушном» слое иконок, а не за
  -- спрайтом капсулы.
  icon_draw_specification = {render_layer = "air-entity-info-icon"},

  -- Скорости запуска.
  -- rising_speed — доля подъёма за тик. Отдельного подъёма из шахты нет
  -- (initial_offset == rise_offset), поэтому этот параметр не двигает капсулу;
  -- оставляем его «мгновенным», чтобы состояние rocket_rising не давало паузу.
  rising_speed = 1,
  engine_starting_speed = 1 / (5.5 * 60),
  flying_speed = 1 / (2000 * 60),
  flying_acceleration = 0.01,

  -- Обязательные углы боковых струй (сами струи не задаём).
  rocket_flame_left_rotation = 0.0611,
  rocket_flame_right_rotation = 0.952,

  -- Сама капсула — ванильный спрайт грузовой капсулы в закрытом виде. Это
  -- единственное, что видно на месте шахты, когда в ней уже собрана ракета;
  -- при запуске поднимается и улетает. Сдвиг — ванильный
  -- (cargo-pod-catalogue), а подъём задаёт rocket_initial_offset.
  rocket_sprite = util.sprite_load("__base__/graphics/entity/cargo-pod/pod-static-detached", {
    priority = "medium",
    scale = POD_SCALE,
    shift = util.by_pixel(1, 3),
  }),

  -- Пламя здесь НЕ задаём. Поле rocket_flame_animation движок проигрывает
  -- постоянно, пока существует сущность ракеты, — на раскрытой капсуле его
  -- ничем не закрыть, и огонь горел бы всегда, даже в простое. Поэтому пламя
  -- рисуется скриптом только по событию запуска (см. script/orbital-capsule.lua,
  -- прототип анимации "orbital-capsule-flame" ниже).

  -- Капсула стоит в проёме в покое и НЕ приподнимается перед запуском:
  -- initial_offset и rise_offset совпадают, поэтому отдельной фазы подъёма
  -- (rocket_rising) нет. Вверх капсула уходит уже самим полётом при запуске.
  -- CAPSULE_RAISE_PX приподнимает капсулу над землёй (тень остаётся внизу).
  rocket_initial_offset = util.by_pixel(0, -CAPSULE_RAISE_PX),
  rocket_rise_offset = util.by_pixel(0, -CAPSULE_RAISE_PX),
  rocket_launch_offset = {0, -256},

  -- Обязательные дистанции/фейды.
  -- Капсула сразу в слое air-object (160) и всегда видна поверх раскрытой
  -- капсулы, без промежуточной фазы, пока она «вылезает» из-под текстуры.
  -- Перекрывать alt-иконки нечем: у шахты они отключены
  -- (show_recipe_icon = false и т.п.).
  rocket_render_layer_switch_distance = 0,
  full_render_layer_switch_distance = 0,
  effects_fade_in_start_distance = 4.5,
  effects_fade_in_end_distance = 7.5,
  shadow_fade_out_start_ratio = 0.25,
  shadow_fade_out_end_ratio = 0.75,
  rocket_visible_distance_from_center = 2.75,
}

-- Само здание. Обязательные поля rocket-silo заданы явно.
local capsule = {
  type = "rocket-silo",
  name = "orbital-capsule",
  icon = q .. "/graphics/entity/orbital-capsule-icon.png",
  icon_size = 64,
  flags = {"placeable-player", "player-creation"},
  max_health = 1000,
  minable = {mining_time = 1, result = "orbital-capsule"},

  -- 3×3 (как assembling-machine-3: коллизия ±1.2, выделение ±1.5).
  collision_box = {{-1.2, -1.2}, {1.2, 1.2}},
  selection_box = {{-1.5, -1.5}, {1.5, 1.5}},

  -- Крафт.
  crafting_categories = {"rocket-building"},
  -- Убираем иконку в alt-режиме полностью (как у ванильной шахты): иначе над
  -- капсулой висит значок рецепта/предмета. Дублируем для карты, убираем тёмный
  -- фон под значком и значок «нет сети логистики».
  show_recipe_icon = false,
  show_recipe_icon_on_map = false,
  draw_entity_info_icon_background = false,
  render_not_in_network_icon = false,
  crafting_speed = 1,
  -- Электричество не нужно: капсула работает от топлива. Void-источник
  -- удовлетворяет любые energy_usage, включая запуск.
  energy_source = {
    type = "void",
  },
  energy_usage = "250kW",
  active_energy_usage = "3990kW",
  lamp_energy_usage = "0kW",
  fixed_recipe = "orbital-capsule-part",

  -- Ракета и груз.
  rocket_entity = "orbital-capsule-rocket",
  rocket_parts_required = 1,
  rocket_quick_relaunch_start_offset = -0.625,
  lift_weight = 0.5 * tons,
  launch_to_space_platforms = true,

  -- Обязательные поля, даже если дверей/люка нет.
  door_back_open_offset = {0, 0},
  door_front_open_offset = {0, 0},
  door_opening_speed = 1 / (4.25 * 60),
  hole_clipping_box = {{-1.2, -1.2}, {1.2, 1.2}},
  times_to_blink = 3,
  light_blinking_speed = 1 / (3 * 60),
  silo_fade_out_start_distance = 8,
  silo_fade_out_end_distance = 15,

  -- Куда летит груз: в хаб платформы на орбите этой планеты.
  cargo_station_parameters = {
    is_input_station = false,
    is_output_station = true,
    hatch_definitions = {
      {
        hatch_graphics = nil,
        offset = {0, 0},
        pod_shadow_offset = {0, 0},
        cargo_unit_entity_to_spawn = nil,
        receiving_cargo_units = {},
      },
    },
  },

  -- Бак под жидкое топливо. Один патрубок снизу по центру: позиция внутри
  -- рамки 3×3 (как у химического завода), движок сам выводит подключение на
  -- южный край. Крышка трубы и значок подключения видимы — видно, куда вести
  -- топливо.
  fluid_boxes = {
    {
      production_type = "input",
      volume = 2000,
      -- Только топливо: случайно залитая вода или окислитель в бак не попадут.
      filter = "thruster-fuel",
      -- Крышка патрубка должна рисоваться поверх спрайта капсулы, иначе её
      -- не видно: база шахты лежит выше стандартного слоя fluid box.
      render_layer = "higher-object-above",
      pipe_covers = pipecoverspictures(),
      pipe_connections = {
        {
          flow_direction = "input",
          direction = defines.direction.south,
          -- Почти у самого южного края: крышка патрубка выглядывает из-под
          -- капсулы, а не прячется за её корпусом.
          position = util.by_pixel(0, 38),
        },
      },
    },
  },

  -- Графики «здания» у шахты нет совсем: ни базы, ни тени, ни люка, ни рук.
  -- Видна только сама капсула. В простое её и тень рисует скрипт
  -- (script/orbital-capsule.lua), а когда в шахте собрана ракета — её рисует
  -- движок через rocket_sprite. Так капсула не задваивается, а при запуске
  -- капсула поднимается и улетает одна, без «силуэта шахты» на земле.
}

-- "Топливный" рецепт для шахты: 1000 thruster-fuel за один запуск.
-- Продукты шахта игнорирует (ей важен сам факт крафта), поэтому
-- result — rocket-part.
local fuel_recipe = {
  type = "recipe",
  name = "orbital-capsule-part",
  categories = {"rocket-building"},
  enabled = true,
  hide_from_player_crafting = true,
  energy_required = 10,
  ingredients = {
    {type = "fluid", name = "thruster-fuel", amount = 1000},
  },
  results = {{type = "item", name = "rocket-part", amount = 1}},
}

-- Предмет и рецепт самой капсулы. Без технологии — доступна сразу.
local item = {
  type = "item",
  name = "orbital-capsule",
  icon = q .. "/graphics/entity/orbital-capsule-icon.png",
  icon_size = 64,
  order = "a[orbital-capsule]",
  place_result = "orbital-capsule",
  stack_size = 10,
}

local capsule_recipe = {
  type = "recipe",
  name = "orbital-capsule",
  enabled = true,
  energy_required = 10,
  ingredients = {
    {type = "item", name = "steel-plate", amount = 50},
    {type = "item", name = "processing-unit", amount = 10},
    {type = "item", name = "low-density-structure", amount = 10},
  },
  results = {{type = "item", name = "orbital-capsule", amount = 1}},
}

-- Пламя двигателя как отдельный прототип анимации: его рисует скрипт только
-- на время запуска (rendering.draw_animation). Тот же pod-thruster-loop, что и
-- в ванильном каталоге капсулы: 10 кадров, additive glow. Смещение — ванильное,
-- под капсулу со сдвигом (1, 3).
local flame = {
  type = "animation",
  name = "orbital-capsule-flame",
  filename = "__base__/graphics/entity/cargo-pod/pod-thruster-loop.png",
  width = 172,
  height = 256,
  frame_count = 10,
  line_length = 5,
  animation_speed = 0.5,
  scale = 0.25,
  shift = util.by_pixel(1, 64 + 3 - CAPSULE_RAISE_PX),
  draw_as_glow = true,
  blend_mode = "additive",
  priority = "medium",
}

-- Капсула в простое: тот же закрытый под, что и rocket_sprite, но нарисованный
-- скриптом, пока в шахте нет собранной ракеты. Сдвиг = rocket_initial_offset +
-- сдвиг rocket_sprite, чтобы стоять ровно там же, где встанет настоящая ракета.
local parked = {
  type = "sprite",
  name = "orbital-capsule-parked",
  filename = "__base__/graphics/entity/cargo-pod/pod-static-detached.png",
  width = 78,
  height = 172,
  scale = POD_SCALE,
  shift = util.by_pixel(1, 3 - CAPSULE_RAISE_PX),
  priority = "medium",
}

-- Тень под капсулой. Рисуется скриптом всегда (в том числе при запуске, когда
-- капсула уже поднялась), поэтому её можно свободно сдвигать.
local capsule_shadow = {
  type = "sprite",
  name = "orbital-capsule-shadow",
  filename = "__base__/graphics/entity/cargo-pod/pod-static-shadow.png",
  width = 174,
  height = 56,
  scale = POD_SCALE,
  shift = util.by_pixel(SHADOW_LEFT_PX, 0),
  draw_as_shadow = true,
  priority = "medium",
}

-- Розжиг сопел: короткая вспышка перед основным пламенем (как в Drivable Cargo
-- Pod: thruster-ignition → thruster-loop).
local ignition = {
  type = "animation",
  name = "orbital-capsule-ignition",
  filename = "__base__/graphics/entity/cargo-pod/pod-thruster-ignition.png",
  width = 172,
  height = 256,
  frame_count = 10,
  line_length = 5,
  animation_speed = 0.5,
  scale = 0.25,
  shift = util.by_pixel(1, 64 + 3 - CAPSULE_RAISE_PX),
  draw_as_glow = true,
  blend_mode = "additive",
  priority = "medium",
}

data:extend({rocket, capsule, item, capsule_recipe, fuel_recipe,
             flame, ignition, parked, capsule_shadow})
