local config = {}

config.scrubber = {
    name = "scrubber",
    square_range = 10,
    check_interval = 20,
    base_damage = 1,
    damage_type = "electric"
}

config.slaves = {
    target_names = {"assembling-machine-3", "assembling-machine-2", "transport-belt"}
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
    count_per_unit = 0.1,
    offset = {x = 0, y = 0},
    vertical_speed = 0.1
}

return config