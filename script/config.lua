-- script/config.lua
local config = {}

config.scrubber = {
    name = "scrubber",
    square_range = 15,
    check_interval = 20,
    base_damage = 5,
    damage_type = "electric"
}

config.slaves = {
    target_name = "assembling-machine-3"
}

-- Настройки пара самого Scrubber (из трубы)
config.visuals = {
    smoke_name = "turbine-smoke",
    smoke_offset = {x = -0.1, y = -1.4},
    base_smoke_count = 1
}

-- ♂️ Новая секция: Дым наказания на асемблерах ♂️
config.punishment_visuals = {
    smoke_name = "smoke",
    count = 4,
    offset = {x = 0, y = 0},
    deviation = {x = 1.2, y = 1.2},
    vertical_speed = 0.04
}

return config