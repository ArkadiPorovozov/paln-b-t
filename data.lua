--require("prototype.item.item")
--require("prototype.item.item-a")
--require("prototype.entity.entity")
--require("prototype.space-map.gen-space-lock")
--require("death-is-not-the-end.data")



require("prototype.entity.entity")
require("prototype.entity.entity-a")
require("prototype.entity.rock")
require("prototype.entity.sun-heat-exchanger")   -- теплообменник, который охлаждает sun
require("prototype.entity.sun-core-exchanger")   -- внутренний теплообменник: стоит на площадке всегда
require("prototype.entity.orbital-requester")    -- орбитальный заказчик строительства
require("prototype.entity.orbital-capsule")      -- орбитальная капсула: раскрытая капсула с заказами, 1000 топлива
--require("prototype.entity.planet-logistics")
require("prototype.item.item")
require("prototype.tiles.init")
require("prototype.flood-warning")   -- значок «затоплено» для dark-ocean (рисует скрипт)
require("prototype.decorative.water-bubbles")   -- пузыри над тёмной водой dark-ocean (декорация)
require("prototype.decorative.volcanic-rocks") -- камни/трещины/кратеры с Вулкана на островах dark-ocean
require("prototype.sun-cooling-old")   -- прототипы отключённой механики sun: нужны только для загрузки старых сейвов
require("prototype.item.sun-platform-foundation")

-- Планеты: сами прототипы (planet.lua), генерация (gen-*.lua) и технологии (other.lua).
require("prototype.planet.planet")
require("prototype.planet.other")
require("prototype.ore.q1-q2")
--require("prototype.ore.ore-1")

--require("data-a")

--require("penis2")   -- каркасы MultiBuild отключены (см. control.lua: script.carkas)

-- Астероиды/телескоп
require("prototype.asteroid.init")
