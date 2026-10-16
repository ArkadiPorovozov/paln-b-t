-- Общая конфигурация: используется и на этапе прототипов (data.lua),
-- и в рантайме (control.lua).

local FRAME_NAME = "mb-frame"            -- универсальный микроблок каркаса 1x1
local STORAGE_NAME = "mb-storage"        -- зелёный фрейм-сундук запроса
local SELECTOR_NAME = "mb-area-selector" -- инструмент выбора области постройки

local COST_FROM_INVENTORY = true -- true: сборка списывает 1 предмет здания
                                  -- сначала из фреймов постройки или касающегося
                                  -- зелёного сундука (впритык), затем из инвентаря игрока.

-- Как часто (в тиках) проверять запланированные постройки — те, что ждут ресурс.
local PENDING_POLL_TICKS = 10

-- Здания, которые можно ставить из каркаса.
-- Отсутствующие в игре (например, без Space Age) просто пропускаются.
local TARGETS = {
  "assembling-machine-1",
  "assembling-machine-2",
  "assembling-machine-3",
  "stone-furnace",
  "steel-furnace",
  "electric-furnace",
  "chemical-plant",
  "oil-refinery",
  "centrifuge",
  "lab",
  "beacon",
  "roboport",
  "rocket-silo",
  -- Space Age:
  "biochamber",
  "electromagnetic-plant",
  "foundry",
  "cryogenic-plant",
  "agricultural-tower",
  "substation",
}

return {
  FRAME_NAME = FRAME_NAME,
  STORAGE_NAME = STORAGE_NAME,
  SELECTOR_NAME = SELECTOR_NAME,
  COST_FROM_INVENTORY = COST_FROM_INVENTORY,
  PENDING_POLL_TICKS = PENDING_POLL_TICKS,
  TARGETS = TARGETS,
}
