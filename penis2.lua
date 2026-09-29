-- Этап прототипов: группа предметов, микроблок каркаса 1x1,
-- сущности плана для каждого здания (автогенерация), инструмент выбора, анимации.

local shared = require("shared")
local FRAME = shared.FRAME_NAME
local SELECTOR = shared.SELECTOR_NAME

-- ===== отдельная группа предметов (вкладка в крафте) =====
data:extend({
  {
    type = "item-group",
    name = "mb-group",
    icon = "__base__/graphics/icons/requester-chest.png",
    icon_size = 64,
    order = "z-mb",
    localised_name = {"multibuild.item-group"},
  },
  {
    type = "item-subgroup",
    name = "multibuild-frames",
    group = "mb-group",
    order = "a",
    localised_name = {"multibuild.item-subgroup"},
  },
})

-- Базовый прототип сундука запроса
local base_requester = data.raw["logistic-container"] and data.raw["logistic-container"]["requester-chest"]

-- ===== микроблок каркаса 1x1 (logistic-container requester с 1 слотом) =====
local frame
if base_requester then
  frame = util.table.deepcopy(base_requester)
else
  frame = util.table.deepcopy(data.raw.container["steel-chest"])
  frame.type = "logistic-container"
  frame.logistic_mode = "requester"
end

frame.name = FRAME
frame.localised_name = {"multibuild.frame"}
frame.minable = {mining_time = 0.2, result = FRAME}
frame.inventory_size = 1
frame.render_not_in_network_icon = false
frame.order = "a-frame"
frame.allow_copy_paste = true

-- Поддержка копирования настроек (Shift+ПКМ -> Shift+ЛКМ)
frame.additional_pastable_entities = {FRAME}

-- Полноценная текстура синего сундука запроса (requester chest) из игры
local blue_chest_sprite = {
  layers = {
    {
      filename = "__base__/graphics/entity/logistic-chest/requester-chest.png",
      priority = "extra-high",
      width = 66,
      height = 74,
      shift = util.by_pixel(0, -2),
      scale = 0.5,
    },
    {
      filename = "__base__/graphics/entity/logistic-chest/logistic-chest-shadow.png",
      priority = "extra-high",
      width = 112,
      height = 46,
      shift = util.by_pixel(12, 4),
      scale = 0.5,
      draw_as_shadow = true,
    }
  }
}

frame.picture = blue_chest_sprite
frame.animation = nil
frame.robot_door = nil
frame.landing_location_offset = nil
frame.opened_duration = nil
frame.animation_sound = nil

local frame_item = util.table.deepcopy(data.raw.item["requester-chest"] or data.raw.item["steel-chest"])
frame_item.icon = "__base__/graphics/icons/requester-chest.png"
frame_item.icon_size = 64
frame_item.name = FRAME
frame_item.localised_name = {"multibuild.frame"}
frame_item.place_result = FRAME
frame_item.subgroup = "multibuild-frames"
frame_item.order = "a-frame"

local frame_recipe = {
  type = "recipe",
  name = FRAME,
  enabled = true,
  energy_required = 0.5,
  ingredients = {{type = "item", name = "iron-plate", amount = 1}},
  results = {{type = "item", name = FRAME, amount = 2}},
  subgroup = "multibuild-frames",
  order = "a-frame",
  allow_productivity = false,
}

-- ===== инструмент выбора области постройки =====
local selector = {
  type = "selection-tool",
  name = SELECTOR,
  localised_name = {"multibuild.area-selector"},
  localised_description = {"multibuild.area-selector-desc"},
  icon = "__base__/graphics/icons/blueprint.png",
  icon_size = 64,
  flags = {"only-in-cursor", "not-stackable", "spawnable"},
  subgroup = "multibuild-frames",
  order = "c-selector",
  stack_size = 1,
  draw_label_for_cursor_render = true,
  select = {
    border_color = {r = 0.2, g = 0.85, b = 1.0, a = 1.0},
    cursor_box_type = "entity",
    mode = {"any-tile", "any-entity"},
  },
  alt_select = {          -- ПКМ: открытие меню каталога чертежей
    border_color = {r = 0.2, g = 0.85, b = 1.0, a = 1.0},
    cursor_box_type = "entity",
    mode = {"any-tile", "any-entity"},
  },
}

local selector_recipe = {
  type = "recipe",
  name = SELECTOR,
  enabled = true,
  energy_required = 0.5,
  ingredients = {{type = "item", name = "iron-plate", amount = 1}},
  results = {{type = "item", name = SELECTOR, amount = 1}},
  subgroup = "multibuild-frames",
  order = "c-selector",
  allow_productivity = false,
}

local shortcut = {
  type = "shortcut",
  name = "mb-area-toggle",
  action = "lua",
  order = "z-mb",
  localised_name = {"multibuild.shortcut-area"},
  localised_description = {"multibuild.area-selector-desc"},
  icon = "__base__/graphics/icons/blueprint.png",
  icon_size = 64,
  small_icon = "__base__/graphics/icons/blueprint.png",
  small_icon_size = 64,
  disabled_icon = "__base__/graphics/icons/blueprint.png",
  disabled_small_icon = "__base__/graphics/icons/blueprint.png",
}

local hotkey = {
  type = "custom-input",
  name = "mb-area-toggle",
  key_sequence = "ALT + B",
  localised_name = {"multibuild.shortcut-area"},
  localised_description = {"multibuild.area-selector-desc"},
}

data:extend({
  {
    type = "recipe-category",
    name = "multibuild-dummy",
  },
  frame, frame_item, frame_recipe,
  selector, selector_recipe,
  shortcut, hotkey,
})

-- ===== АВТОМАТИЧЕСКАЯ ГЕНЕРАЦИЯ СУЩНОСТЕЙ ПЛАНА ДЛЯ КАЖДОГО ЗДАНИЯ =====
-- Каждая сущность плана:
-- 1) Имеет точный selection_box целевого здания (игра рисует рамку выделения НА ТИВНО, без rendering!)
-- 2) Имеет collision_mask = {layers = {}} (не мешает ставить каркасы под собой)
-- 3) Отображает полупрозрачную иконку здания в центре
-- 4) Копируется чертежами (Ctrl+C), пипеткой (Q) и Shift-кликом
local plan_entities = {}
local plan_items = {}

for _, target_name in ipairs(shared.TARGETS) do
  local proto = nil
  for _, cat_table in pairs(data.raw) do
    if type(cat_table) == "table" and cat_table[target_name] then
      local candidate = cat_table[target_name]
      if type(candidate) == "table" and (candidate.selection_box or candidate.collision_box) then
        proto = candidate
        break
      end
    end
  end

  if proto then
    local sbox = proto.selection_box and util.table.deepcopy(proto.selection_box) or {{-1.5, -1.5}, {1.5, 1.5}}
    local cbox = proto.collision_box and util.table.deepcopy(proto.collision_box)
    local icon = proto.icon
    local icons = proto.icons and util.table.deepcopy(proto.icons)
    local icon_size = proto.icon_size or 64

    local x1 = sbox[1] and (sbox[1][1] or sbox[1].x) or -1.5
    local y1 = sbox[1] and (sbox[1][2] or sbox[1].y) or -1.5
    local x2 = sbox[2] and (sbox[2][1] or sbox[2].x) or 1.5
    local y2 = sbox[2] and (sbox[2][2] or sbox[2].y) or 1.5

    local w = math.floor(x2 - x1 + 0.5)
    local h = math.floor(y2 - y1 + 0.5)
    if w <= 0 then w = 1 end
    if h <= 0 then h = 1 end
    local plan_name = "mb-plan-" .. target_name

    -- Точный collision_box под размер здания, чтобы шаг протягивания (drag) совпадал с размером здания
    cbox = {{-w/2 + 0.15, -h/2 + 0.15}, {w/2 - 0.15, h/2 - 0.15}}

    local function make_layers(sw, sh)
      local layers = {}

      -- 1) Угловые рамки выделения из нативной текстуры курсора/выделения игры
      -- Текстура углов выделения __core__/graphics/cursor-boxes-32x32.png или cursor-boxes.png
      local corner_scale = 1.0
      local x_off = (sw / 2) - 0.25
      local y_off = (sh / 2) - 0.25

      -- 4 нативных угловых маркера выделения чертежа
      table.insert(layers, {
        filename = "__core__/graphics/cursor-boxes-32x32.png",
        x = 0, y = 0, width = 32, height = 32,
        shift = {-x_off, -y_off},
        scale = corner_scale,
        tint = {r = 0.2, g = 0.85, b = 1.0, a = 0.9},
        render_layer = "air-object",
      })
      table.insert(layers, {
        filename = "__core__/graphics/cursor-boxes-32x32.png",
        x = 32, y = 0, width = 32, height = 32,
        shift = {x_off, -y_off},
        scale = corner_scale,
        tint = {r = 0.2, g = 0.85, b = 1.0, a = 0.9},
        render_layer = "air-object",
      })
      table.insert(layers, {
        filename = "__core__/graphics/cursor-boxes-32x32.png",
        x = 0, y = 32, width = 32, height = 32,
        shift = {-x_off, y_off},
        scale = corner_scale,
        tint = {r = 0.2, g = 0.85, b = 1.0, a = 0.9},
        render_layer = "air-object",
      })
      table.insert(layers, {
        filename = "__core__/graphics/cursor-boxes-32x32.png",
        x = 32, y = 32, width = 32, height = 32,
        shift = {x_off, y_off},
        scale = corner_scale,
        tint = {r = 0.2, g = 0.85, b = 1.0, a = 0.9},
        render_layer = "air-object",
      })

      -- 2) Иконка целевого здания в центре
      if icons then
        for _, ic in ipairs(icons) do
          table.insert(layers, {
            filename = ic.icon,
            size = ic.icon_size or icon_size,
            scale = (0.5 + math.min(sw, sh) * 0.22) * (ic.scale or 1),
            tint = ic.tint or {r = 1, g = 1, b = 1, a = 0.88},
            shift = ic.shift or {0, 0},
            render_layer = "air-object",
          })
        end
      elseif icon then
        table.insert(layers, {
          filename = icon,
          size = icon_size,
          scale = 0.5 + math.min(sw, sh) * 0.22,
          tint = {r = 1, g = 1, b = 1, a = 0.88},
          render_layer = "air-object",
        })
      else
        table.insert(layers, {
          filename = "__base__/graphics/icons/steel-chest.png",
          size = 64,
          scale = 1.0,
          tint = {r = 1, g = 1, b = 1, a = 0.88},
          render_layer = "air-object",
        })
      end
      return layers
    end

    local sprite_layers = make_layers(w, h)
    local sprite_4way = {
      north = { layers = sprite_layers },
      east = { layers = sprite_layers },
      south = { layers = sprite_layers },
      west = { layers = sprite_layers },
    }

    local plan_entity = {
      type = "assembling-machine",
      name = plan_name,
      localised_name = {"", {"entity-name." .. target_name}, " [", {"multibuild.pending"}, "]"},
      icon = icon,
      icons = icons,
      icon_size = icon_size,
      hidden = true,
      hidden_in_factoriopedia = true,
      flags = {"placeable-player", "player-creation", "not-on-map"},
      subgroup = "multibuild-frames",
      order = "z-plan-" .. target_name,
      max_health = 100,
      selection_box = sbox,
      collision_box = cbox,
      collision_mask = {layers = {}},
            crafting_categories = {"multibuild-dummy"},
      crafting_speed = 1,
      energy_source = {type = "void"},
      energy_usage = "1W",
      render_layer = "air-object",
      graphics_set = {
        idle_animation = sprite_4way,
        always_draw_idle_animation = true,
        animation = sprite_4way,
        working_visualisations = {
          {
            always_draw = true,
            render_layer = "air-object",
            north_animation = sprite_4way.north,
            east_animation = sprite_4way.east,
            south_animation = sprite_4way.south,
            west_animation = sprite_4way.west,
          }
        }
      },
      minable = {mining_time = 0.1, result = nil},
      allow_copy_paste = true,
      additional_pastable_entities = {FRAME, plan_name, target_name},
    }

    local plan_item = {
      type = "item",
      name = plan_name,
      localised_name = {"", {"entity-name." .. target_name}, " [", {"multibuild.pending"}, "]"},
      icon = icon,
      icons = icons,
      icon_size = icon_size,
      hidden = true,
      hidden_in_factoriopedia = true,
      flags = {"only-in-cursor"},
      subgroup = "multibuild-frames",
      order = "z-plan-" .. target_name,
      place_result = plan_name,
      stack_size = 1,
    }

    table.insert(plan_entities, plan_entity)
    table.insert(plan_items, plan_item)

    -- Разрешаем копирование настроек между целевым зданием и планом
    proto.additional_pastable_entities = proto.additional_pastable_entities or {}
    table.insert(proto.additional_pastable_entities, FRAME)
    table.insert(proto.additional_pastable_entities, plan_name)

    table.insert(frame.additional_pastable_entities, target_name)
    table.insert(frame.additional_pastable_entities, plan_name)
  end
end

data:extend(plan_entities)
data:extend(plan_items)

-- ===== полупрозрачный стиль окна меню выбора здания =====
local gui_style = data.raw["gui-style"]["default"]
gui_style.mb_transparent_frame = {
  type = "frame_style",
  parent = "frame",
  graphical_set = {
    base = {
      filename = "__core__/graphics/gui-new.png",
      position = {0, 0},
      corner_size = 8,
      opacity = 0.75,
    },
  },
}

-- =====================================================================
-- Анимация строительных лесов космической платформы.
-- =====================================================================
local function any_feature_flag_enabled()
  for _, boolean in pairs(feature_flags) do
    if boolean then return true end
  end
  return false
end
local flags_ok = any_feature_flag_enabled()

local panim = require("entity-build-animations")
local panim_count = 0
for corner, animations in pairs(panim) do
  for name, animation in pairs(animations) do
    animation.type = "animation"
    animation.name = "mb-panim-" .. corner .. "-" .. name
    if not flags_ok then
      for _, layer in ipairs(animation.layers) do
        layer.tint = {0, 0, 0, 0}
      end
    end
    data:extend{animation}
    panim_count = panim_count + 1
  end
end
log("multibuild: анимаций лесов зарегистрировано: " .. panim_count)
