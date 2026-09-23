local q = "__paln-b-test__"
local planet_map_gen = require(q .. ".prototype.planet.map-gen")

local meld = require("__core__.lualib.meld")
local asteroid_util = require("__space-age__.prototypes.planet.asteroid-spawn-definitions")
local tile_sounds = require("__space-age__/prototypes/tile/tile-sounds")
local cargo_pod_catalogue_additions = require("__space-age__/prototypes/entity/cargo-pod-catalogue")
local procession_graphic_catalogue_types = require("__base__/prototypes/planet/procession-graphic-catalogue-types")

local tile_graphics = require("__base__/prototypes/tile/tile-graphics")
local tile_spritesheet_layout = tile_graphics.tile_spritesheet_layout

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
        platform_surface_render_parameters = {},
        draw_orbit = true,
        unlocked = true,
        --visible_when_disabled = true
    }
end

data:extend({
    create_moon("zalupa", "__space-age__/graphics/icons/solar-system-edge.png","p1"),
})



data.raw.planet["zalupa"].platform_surface_render_parameters.platform_backdrop =
{
  emission_scales_with_shadow = false,
  radius = data.raw.planet["nauvis"].platform_surface_render_parameters.platform_backdrop.radius * 0.7,
  rotation_seconds = data.raw.planet["nauvis"].platform_surface_render_parameters.platform_backdrop.rotation_seconds / 1.8,
  surface_vertical_offset = 0.1,
  specular_intensity = 0.7,
  specular_color = {0.95, 0.83, 0.52, 1},
  atmosphere_color = {0.07, 0.057, 0.075, 0.1},
  planet_axis = {3.0, 13.0},
  planet_axis_deviation_amplitude = {10.0, 10.0},
  planet_axis_deviation_seconds = {890.5/1.8, 753.7/1.8},
  position = {-400, 270},
  parallax_strength = {0.95, 0.95},
  light_direction = {-0.42, 0.23, 0.4},
  light_intensity_contrast = 0.3,
  light_radius = 5.9,
  planet_surface =
  {
    filename = q.."/graphics/planet/planet_color.png",
    width = 1024,
    height = 1024
  },
  planet_normal =
  {
    filename =  q.."/graphics/planet/planet_normal.png",
    width = 1024,
    height = 1024
  },
  planet_reflectivity =
  {
    filename =  q.."/graphics/planet/planet_roughness.png",
    width = 1024,
    height = 1024
  }
}


data:extend(
	{
		{
			type = "space-connection",
			name = "zalupa-nauvis",
			subgroup = "planet-connections",
			from = "zalupa",
			to = "nauvis",
			order = "d",
			length = 10000,
			asteroid_spawn_definitions = asteroid_util.spawn_definitions(asteroid_util.nauvis_fulgora),
			icon = "__space-age__/graphics/icons/solar-system-edge.png"
		},
	}
)

-- Проверяем, существует ли нужная технология, чтобы игра не выдала ошибку
if data.raw.technology["space-science-pack"] then
  -- Если у технологии еще нет массива эффектов, создаем его
  data.raw.technology["space-science-pack"].effects = data.raw.technology["space-science-pack"].effects or {}
  
  -- Добавляем эффект открытия нашей локации
  table.insert(data.raw.technology["space-science-pack"].effects, {
        type = "unlock-space-location",
        space_location = "zalupa",
        use_icon_overlay_constant = true
  })
end
