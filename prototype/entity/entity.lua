-- Прототипы сущностей мода.
-- Здесь только подключение: каждый прототип живёт в своём файле рядом.
-- Порядок require сохранён как в старом общем файле.

require("prototype.entity.shared")   -- общие зависимости и хелперы (должен идти первым)

-- Отключённые прототипы. Вернуть = поставить true.
local enable_scrubber = false
local enable_asm45 = false

if enable_scrubber then
  require("prototype.entity.scrubber")
end

if enable_asm45 then
  require("prototype.entity.assembling-machine-45")
end

require("prototype.entity.assembling-machine-45-corp")
require("prototype.entity.asm45-corp-site")
require("prototype.entity.ssc-turbine")
require("prototype.entity.atmo-cond")
require("prototype.entity.clouds")
require("prototype.entity.sheathing")
require("prototype.entity.sheathing-ground")
require("prototype.entity.cable")
