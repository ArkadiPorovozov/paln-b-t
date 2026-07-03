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
    target_names = {"assembling-machine-3", "assembling-machine-2"}
}


config.visuals = {
    smoke_name = "turbine-smoke",
    smoke_offset = {x = 0, y = 0},
    base_smoke_count = 0.1,
    vertical_speed = 0.7
}
config.random_tr = {
    range = 0.5,
    frequency = 2
}

config.punishment_visuals = {
    smoke_name = "smoke",
    count = 3,
    offset = {x = 0, y = 0},
    deviation = {x = 1.5, y = 1.5},
    vertical_speed = 0.02
}
config.random = {
    range = 0.8,
    frequency = 0.8
}

return config