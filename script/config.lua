local config = {}

config.scrubbers = {
    ["scrubber"] = {
        radius = 4,
        draw_color = {r = 1, g = 0.5, b = 0, a = 0.2}
    }
}

-- Какие здания зависят от скрубберов
config.dependent_buildings = {
    ["assembling-machine-1"] = {requires = "scrubber"}
}

return config