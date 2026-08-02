local q = "__paln-b-test__"
local planet_map_gen = require(q .. ".prototype.planet.map-gen")


local function create_moon(name, icon, mame)
    return {
        type = "planet",
        name = name,
        icon = icon,
        starmap_icon = icon,
        starmap_icon_size = 64,
        gravity_pull = 5,
        distance = 20,
        orientation = 0.125,
        magnitude = 1,
        order = "z",
        subgroup = "planets",
        map_gen_settings = planet_map_gen[mame](),
        draw_orbit = true,
        --visible_when_disabled = true
    }
end

data:extend({
    create_moon("zalupa", "__space-age__/graphics/icons/solar-system-edge.png","p1"),
})

