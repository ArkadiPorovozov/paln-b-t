-- Этап прототипов: группа предметов, микроблок каркаса 1x1, зелёный фрейм-сундук запроса,
-- сущности плана для каждого здания (автогенерация), инструмент выбора, анимации.

local shared = require("shared")
local FRAME = shared.FRAME_NAME
local STORAGE = shared.STORAGE_NAME
local SELECTOR = shared.SELECTOR_NAME

-- ===== отдельная группа предметов (вкладка в крафте) =====
data:extend({
  {
    type = "item-group",
    name = "mb-group",
    icon = "__base__/graphics/icons/steel-chest.png",
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
local FRAME_TINT = {r = 0.45, g = 0.9, b = 1.0, a = 0.6} -- голубоватый, полупрозрачный

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

if frame.animation then
  if frame.animation.layers then
    for _, layer in pairs(frame.animation.layers) do
      if not layer.draw_as_shadow then
        layer.tint = FRAME_TINT
      end
    end
  else
    frame.animation.tint = FRAME_TINT
  end
elseif frame.picture and frame.picture.layers then
  for _, layer in pairs(frame.picture.layers) do
    if not layer.draw_as_shadow then
      layer.tint = FRAME_TINT
    end
  end
end

local frame_item = util.table.deepcopy(data.raw.item["steel-chest"])
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

-- ===== 2-й зелёный фрейм: сундук запроса для дронов (без разгрузки дронами) =====
local STORAGE_TINT = {r = 0.35, g = 1.0, b = 0.45, a = 1.0}

local storage
if base_requester then
  storage = util.table.deepcopy(base_requester)
else
  storage = util.table.deepcopy(data.raw.container["steel-chest"])
  storage.type = "logistic-container"
  storage.logistic_mode = "requester"
end

storage.name = STORAGE
storage.localised_name = {"multibuild.storage-name"}
storage.localised_description = {"multibuild.storage-hint"}
storage.minable = {mining_time = 0.5, result = STORAGE}
storage.inventory_size = 1
storage.render_not_in_network_icon = false
storage.order = "b-storage"

if storage.animation then
  if storage.animation.layers then
    for _, layer in pairs(storage.animation.layers) do
      if not layer.draw_as_shadow then
        layer.tint = STORAGE_TINT
      end
    end
  else
    storage.animation.tint = STORAGE_TINT
  end
elseif storage.picture and storage.picture.layers then
  for _, layer in pairs(storage.picture.layers) do
    if not layer.draw_as_shadow then
      layer.tint = STORAGE_TINT
    end
  end
end

local storage_item = util.table.deepcopy(data.raw.item["steel-chest"])
storage_item.name = STORAGE
storage_item.localised_name = {"multibuild.storage-name"}
storage_item.localised_description = {"multibuild.storage-hint"}
storage_item.place_result = STORAGE
storage_item.subgroup = "multibuild-frames"
storage_item.order = "b-storage"
storage_item.icons = {
  {
    icon = "__base__/graphics/icons/steel-chest.png",
    icon_size = 64,
    tint = STORAGE_TINT,
  },
}

local storage_recipe = {
  type = "recipe",
  name = STORAGE,
  enabled = true,
  energy_required = 1,
  ingredients = {
    {type = "item", name = "steel-chest", amount = 1},
    {type = "item", name = "iron-plate", amount = 10},
  },
  results = {{type = "item", name = STORAGE, amount = 1}},
  subgroup = "multibuild-frames",
  order = "b-storage",
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
  alt_select = {          -- ПКМ: отмена выделения / отмена плана
    border_color = {r = 1.0, g = 0.4, b = 0.4, a = 1.0},
    cursor_box_type = "not-allowed",
    mode = {"nothing"},
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
  storage, storage_item, storage_recipe,
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

    if not cbox then
      cbox = {{-w/2 + 0.1, -h/2 + 0.1}, {w/2 - 0.1, h/2 - 0.1}}
    elseif w ~= h then
      local cx1 = cbox[1] and (cbox[1][1] or cbox[1].x) or (-w/2 + 0.1)
      local cy1 = cbox[1] and (cbox[1][2] or cbox[1].y) or (-h/2 + 0.1)
      local cx2 = cbox[2] and (cbox[2][1] or cbox[2].x) or (w/2 - 0.1)
      local cy2 = cbox[2] and (cbox[2][2] or cbox[2].y) or (h/2 - 0.1)
      if math.abs(math.abs(cx2 - cx1) - math.abs(cy2 - cy1)) < 0.1 then
        cbox = {{-w/2 + 0.1, -h/2 + 0.1}, {w/2 - 0.1, h/2 - 0.1}}
      end
    end

    local function make_layers(sw, sh)
      local layers = {}
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
