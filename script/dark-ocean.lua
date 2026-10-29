-- Планета dark-ocean: слой тёмной воды по чанкам.
--
-- На каждый чанк 32×32 ставится 4 сущности dark-water-shader 16×16 тайлов
-- (2×2 клетки). Сущности невидимы для мыши, без коллизии, не ломаются и не
-- мешают строить — это чистая графика, как maraxsis-water-shader в maraxsis
-- (там одна сущность 32×32 на чанк; чтобы получить то же самое, поставь
-- TILES = 32 в prototype/dark-water.lua).
--
-- Стоимость: создание только в момент генерации чанка, дальше ничего не тикает.
-- Никаких сканов поверхности по тикам нет.

local SURFACE = "dark-ocean"
local ENTITY = "dark-water-shader"

local CHUNK = 32
-- Размер одной сущности в тайлах. Должен совпадать с TILES в
-- prototype/dark-water.lua: entity 16×16 тайлов.
local CELL = 16
local PER_CHUNK = CHUNK / CELL -- 2 клетки по каждой оси

local function add_water(surface, x, y)
  local water = surface.create_entity{
    name = ENTITY,
    position = {x, y},
    create_build_effect_smoke = false,
  }
  if water then
    water.destructible = false
    water.minable_flag = false
    water.disabled_by_script = true
  end
  return water
end

-- Заполняет один чанк: клетки 16×16, центры на 8, 24 от угла чанка.
local function fill_chunk(surface, chunk_x, chunk_y)
  local x0 = chunk_x * CHUNK
  local y0 = chunk_y * CHUNK

  for ix = 0, PER_CHUNK - 1 do
    for iy = 0, PER_CHUNK - 1 do
      add_water(surface,
        x0 + (ix + 0.5) * CELL,
        y0 + (iy + 0.5) * CELL)
    end
  end
end

script.on_event(defines.events.on_chunk_generated, function(event)
  if event.surface.name ~= SURFACE then
    return
  end
  fill_chunk(event.surface, event.position.x, event.position.y)
end)

-- Планета могла быть посещена до установки мода: тогда в старых чанках слоя
-- нет. Один раз досоздаём его — если на поверхности вообще нет наших сущностей.
-- Тик 58 свободен (59 занят sun, 55 — турбиной, 50 — облаками, 60 — asm45).
local function backfill()
  local surface = game.surfaces[SURFACE]
  if surface and surface.count_entities_filtered{name = ENTITY, limit = 1} == 0 then
    for chunk in surface.get_chunks() do
      if surface.is_chunk_generated({chunk.x * CHUNK, chunk.y * CHUNK}) then
        fill_chunk(surface, chunk.x, chunk.y)
      end
    end
  end
  script.on_nth_tick(58, nil)
end

script.on_nth_tick(58, backfill)

