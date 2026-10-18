-- Общие вещи для прототипов сущностей: библиотеки и локальные константы.
-- Подключается первым в prototype/entity/entity.lua, остальные файлы берут всё отсюда.

require("util")

-- задаёт глобальные opticalfiberpictures / opticalfibercoverspictures
require("prototype.graphics.optickabile")

local q = "__paln-b-test__"

return {
  q = q,
  a_speed = 1,

  hit_effects = require("__base__.prototypes.entity.hit-effects"),
  sounds = require("__base__.prototypes.entity.sounds"),
  space_age_sounds = require("__space-age__.prototypes.entity.sounds"),

  proto = require(q .. ".prototype.proto"),
}
