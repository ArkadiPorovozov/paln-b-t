-- Границы и свечение белой лавы: меняются прототипы, созданные в data.lua.
require("prototype.white-lava-edges")

-- Регистрация турбины в библиотеке 0-things (Thing).
--
-- Things берёт на себя жизненный цикл турбины: постройка/снос, чертежи,
-- undo/redo, восстановление из "призраков" и т.п. А ещё он автоматически
-- создаёт и уничтожает "детей" турбины.
--
-- Ребёнок "generator" (ssc-turbine-generator) описан ниже и создаётся/удаляется
-- вместе с турбиной. Скрипт script/ssc-turbine.lua его не трогает: он лишь
-- включает генератор (50MW), пока турбина жжёт топливо, и выключает (0), когда
-- не жжёт.
local things_names = data.raw["mod-data"] and data.raw["mod-data"]["things-names"]

if things_names then
  ---@type things.ThingRegistration
  things_names.data["ssc-turbine"] = {
    name = "ssc-turbine",
    -- Автоматически делать Thing из каждой построенной турбины.
    intercept_construction = true,
    children = {
      generator = {
        -- Automatic child: Things создаст этот генератор вместе с турбиной.
        create = { name = "ssc-turbine-generator" },
      },
    },
  }
end
