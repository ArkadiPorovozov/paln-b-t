-- Затопление на dark-ocean: постройки под водой не работают.
--
-- Механика повторяет maraxsis (scripts/pressure-dome.lua, set_flooded):
--   * entity.disabled_by_script = true — постройка останавливается;
--   * entity.custom_status = {diode = red, label = ...} — красный статус
--     «Затоплено» в подсказке и в alt-режиме;
--   * rendering.draw_sprite — значок над постройкой, видимый всегда.
--
-- Оптимизация тоже как у maraxsis: никакого обхода поверхности по тикам.
-- Постройку топим сразу в событии постройки, значок живёт в сейве, а раз в
-- 66667 тиков (как в maraxsis) чистим storage от мёртвых записей. Полный проход
-- по поверхности делается РОВНО ОДИН РАЗ на сейв — чтобы дозатопить то, что
-- стояло на планете до установки мода (в maraxsis это миграция).
--
-- Почему «под водой» = вся поверхность dark-ocean: вода на этой планете — не
-- тайл, а сущности dark-water-shader, накрывающие каждый чанк
-- (prototype/dark-water.lua, script/planet/dark-ocean.lua). Слой рисуется выше
-- построек, поэтому вся планета, включая острова, выглядит затонувшей. Когда
-- появятся купола (защита от затопления), они будут снимать флаг через
-- unflood() — всё остальное менять не придётся.

local SURFACE = "dark-ocean"
local SPRITE = "paln-flooded-warning"

-- Версия разовой миграции. Подними число, если дозатопление старого сейва
-- нужно прогнать заново.
local MIGRATION = 1

-- Типы, которые «работают» и поэтому тонут. Список взят у maraxsis
-- (DOME_DISABLEABLE_TYPES) плюс сельхозвышка из 2.0. Ленты, манипуляторы,
-- трубы, сундуки, насосы и техника не тонут: под водой логично продолжать
-- работать именно им, да и отключать их значило бы полностью парализовать базу.
local FLOODABLE = {
  ["assembling-machine"] = true,
  ["furnace"] = true,
  ["lab"] = true,
  ["beacon"] = true,
  ["mining-drill"] = true,
  ["rocket-silo"] = true,
  ["generator"] = true,
  ["fusion-generator"] = true,
  ["fusion-reactor"] = true,
  ["reactor"] = true,
  ["boiler"] = true,
  ["agricultural-tower"] = true,
}

local FLOODABLE_LIST = {}
local FLOODABLE_FILTERS = {}
for name in pairs(FLOODABLE) do
  FLOODABLE_LIST[#FLOODABLE_LIST + 1] = name
  -- Фильтр события: обработчик вообще не вызывается для остальных сущностей.
  FLOODABLE_FILTERS[#FLOODABLE_FILTERS + 1] = {filter = "type", type = name}
end

local STATUS = {
  diode = defines.entity_status_diode.red,
  label = {"entity-status.paln-flooded"},
}
local STATUS_KEY = STATUS.label[1]

-- =====================================================================
-- Реестр затопленных
-- =====================================================================

-- storage.paln_flooded[surface_index .. ":" .. unit_number] = {
--   entity = LuaEntity,
--   icon = LuaRenderObject,
--   was_disabled = было ли disabled_by_script у постройки до нас,
-- }
local function registry()
  storage.paln_flooded = storage.paln_flooded or {}
  return storage.paln_flooded
end

local function key_of(entity)
  return entity.surface_index .. ":" .. entity.unit_number
end

-- Значок над постройкой. render_layer обязателен: слой по умолчанию ("object")
-- ниже слоя воды dark-water-shader ("light-effect"), и значок был бы под водой.
-- "selection-box" — ближайший слой над водой (как рамка выделения), но всё ещё
-- под курсором.
local function draw_icon(entity)
  return rendering.draw_sprite({
    sprite = SPRITE,
    target = {
      entity = entity,
      offset = entity.prototype.alert_icon_shift or {0, 0},
    },
    surface = entity.surface_index,
    x_scale = 1.04,
    y_scale = 1.04,
    render_layer = "selection-box",
  })
end

local function flood(entity)
  if not (entity and entity.valid and entity.unit_number) then
    return false
  end
  -- Служебные сущности, по которым нельзя кликнуть (накладки, невидимые
  -- помощники), не топим: игрок их не видит, а значок над ними дублировал бы
  -- значок настоящей постройки. Так, у ssc-turbine ребёнок-генератор
  -- "ssc-turbine-plant" стоит ровно на месте котла, и турбина не получает два
  -- значка. Без пара генератор и так не работает.
  if entity.prototype.selectable_in_game == false then
    return false
  end
  local reg = registry()
  local key = key_of(entity)
  if reg[key] then
    return false -- уже затоплено (мёртвые записи чистятся по редкому тику)
  end

  -- Если постройку уже выключил кто-то другой, вернём как было, когда вода
  -- уйдёт: чужой disabled_by_script мы не должны снимать.
  local was_disabled = entity.disabled_by_script

  entity.disabled_by_script = true
  entity.custom_status = STATUS
  reg[key] = {
    entity = entity,
    icon = draw_icon(entity),
    was_disabled = was_disabled,
  }
  return true
end

-- Снять затопление. Сейчас вызывается только когда постройку увезли на другую
-- поверхность; купола (защита от воды) будут дёргать это же.
local function unflood(key, entry)
  local entity = entry.entity
  if entity and entity.valid then
    local status = entity.custom_status
    if status and status.label and status.label[1] == STATUS_KEY then
      entity.custom_status = nil
    end
    entity.disabled_by_script = entry.was_disabled or false
  end
  if entry.icon and entry.icon.valid then
    entry.icon.destroy()
  end
  registry()[key] = nil
end

-- =====================================================================
-- События постройки (как maraxsis.events.on_built)
-- =====================================================================

-- ВАЖНО: в одном моде на событие может быть только один обработчик. Сейчас
-- on_built_entity свободен (script/carkas.lua отключён в control.lua). Если
-- включишь carkas обратно — объедини подписки, иначе одна из них затрёт другую.
local BUILT = {
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
}

-- Фильтры можно вешать только на одно событие, поэтому подписываемся в цикле.
local function on_built(event)
  local entity = event.entity
  if entity and entity.valid and entity.surface.name == SURFACE then
    flood(entity)
  end
end

for _, event in pairs(BUILT) do
  script.on_event(event, on_built, FLOODABLE_FILTERS)
end

-- Клонирование (entity.clone()) — отдельное событие, сущность в destination.
script.on_event(defines.events.on_entity_cloned, function(event)
  local entity = event.destination
  if entity and entity.valid and entity.surface.name == SURFACE then
    flood(entity)
  end
end)

-- =====================================================================
-- Разовая миграция
-- =====================================================================

-- Постройки, которые стояли на планете до установки мода (или до этой версии),
-- событий постройки уже не дадут — их надо дозатопить одним проходом.
--
-- on_init / on_configuration_changed в этом моде «заняты»: их регистрирует
-- script/clouds.lua и затирает всех, кто был раньше (см. комментарии в
-- script/ssc-turbine.lua и script/planet/locality.lua). Поэтому разовую
-- миграцию делаем на свободном тике 57 и сразу снимаем обработчик — дальше тик
-- не тикает.
local function migrate()
  if storage.paln_flood_migration == MIGRATION then
    return
  end
  storage.paln_flood_migration = MIGRATION

  local surface = game.surfaces[SURFACE]
  if not surface then
    return
  end
  for _, entity in pairs(surface.find_entities_filtered({type = FLOODABLE_LIST})) do
    flood(entity)
  end
end

script.on_nth_tick(57, function()
  -- on_nth_tick выстреливает и на нулевом тике (0 % 57 == 0) — тогда на карте
  -- ещё ничего нет. Ждём первый настоящий тик после загрузки.
  if game.tick == 0 then
    return
  end
  script.on_nth_tick(57, nil)
  migrate()
end)

-- =====================================================================
-- Редкая чистка
-- =====================================================================

-- Как в maraxsis (66667 тиков): значок умирает вместе с постройкой сам, но
-- запись в storage остаётся. Раз в ~18 игровых часов забываем мёртвые записи и
-- снимаем затопление с построек, уехавших на другую поверхность.
script.on_nth_tick(66667, function()
  local reg = registry()
  for key, entry in pairs(reg) do
    local entity = entry.entity
    if not (entity and entity.valid) then
      if entry.icon and entry.icon.valid then
        entry.icon.destroy()
      end
      reg[key] = nil
    elseif entity.surface.name ~= SURFACE then
      unflood(key, entry)
    end
  end
end)
