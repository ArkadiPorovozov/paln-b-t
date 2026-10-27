local q = "__paln-b-test__"
local planet_map_gen = require(q .. ".prototype.planet.map-gen")

local meld = require("__core__.lualib.meld")
local asteroid_util = require("__space-age__.prototypes.planet.asteroid-spawn-definitions")
local tile_sounds = require("__space-age__/prototypes/tile/tile-sounds")
local cargo_pod_catalogue_additions = require("__space-age__/prototypes/entity/cargo-pod-catalogue")
local procession_graphic_catalogue_types = require("__base__/prototypes/planet/procession-graphic-catalogue-types")

local tile_graphics = require("__base__/prototypes/tile/tile-graphics")
local tile_spritesheet_layout = tile_graphics.tile_spritesheet_layout


local function create_tex(name, icon)
  return {
    type = "technology",
    name = name,
    icon = icon,
    icon_size = 64,
    effects =
    {
      {
        type = "unlock-space-location",
        space_location = name,
        use_icon_overlay_constant = true
      }
    },
    --prerequisites = {},
    unit =
    {
      count = 100,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1}
      },
      time = 30
    }

  }
end





local function create_p(name, icon, meme, options)
    local planet = {
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
        map_gen_settings = planet_map_gen[meme](),
        platform_surface_render_parameters = {},
        draw_orbit = true,
        unlocked = true,
        --visible_when_disabled = true
    }

    -- Переопределения для конкретной планеты: так sun может быть ближе к
    -- центру системы, иметь другой размер на карте и свою атмосферу.
    if options then
        for key, value in pairs(options) do
            planet[key] = value
        end
    end

    return planet
end


local function a1(name, icon, meme, options)
  local a = create_p(name, icon, meme, options)
  local b =  create_tex(name, icon)
  return {a,b}
end


data:extend(a1("zalupa", "__space-age__/graphics/icons/solar-system-edge.png","p1"))



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


-- =====================================================================
-- Планета sun: лава + космос.
-- =====================================================================
-- Поверхность целиком состоит из sun-void (космос, как на платформе) и
-- морей горячей лавы; сверху тот же рельеф островов, что и у zalupa.
-- На sun-void можно ставить space-platform-foundation, и её кромка
-- рисуется так же, как на космической платформе.
data:extend(a1("sun", q.."/graphics/icons/sun.png", "sun", {
  starmap_icon = q.."/graphics/planet/sun_starmap_icon.png",
  starmap_icon_size = 512,
  gravity_pull = 20,
  -- Ближе к центру системы, чем любая ванильная планета (Nauvis — 15).
  distance = 2,
  orientation = 0.75,
  magnitude = 0.7,
  order = "a[sun]",
  solar_power_in_space = 1200,
  asteroid_spawn_influence = 1,
  asteroid_spawn_definitions =
    asteroid_util.spawn_definitions(asteroid_util.nauvis_vulcanus, 0.9),
  surface_properties = {
    -- Как на космической платформе: нет атмосферы, гравитации и смены дня.
    -- day-night-cycle = 0 — смены дня нет, на солнце всегда день.
    gravity = 0,
    pressure = 0,
    ["magnetic-field"] = 0,
    ["day-night-cycle"] = 0,
    -- Рядом со звездой солнечные панели дают намного больше.
    ["solar-power"] = 1000,
  },
}))


-- Солнце в небе над платформой, летящей на орбите sun: большой светящийся
-- шар. Для поверхности и для emission берётся одна и та же текстура, чтобы
-- планета не была наполовину тёмной.
data.raw.planet["sun"].platform_surface_render_parameters.platform_backdrop =
{
  emission_scales_with_shadow = false,
  radius = data.raw.planet["nauvis"].platform_surface_render_parameters.platform_backdrop.radius * 1.6,
  rotation_seconds = 240,
  surface_vertical_offset = 0.1,
  specular_intensity = 0.05,
  specular_color = {1, 0.95, 0.8, 1},
  atmosphere_color = {1, 0.45, 0.05, 0.45},
  planet_axis = {0.0, 0.0},
  planet_axis_deviation_amplitude = {0.0, 0.0},
  planet_axis_deviation_seconds = {1000.0, 1000.0},
  position = {-300, 220},
  parallax_strength = {0.95, 0.95},
  light_direction = {-0.42, 0.23, 0.4},
  light_intensity_contrast = 0.1,
  light_radius = 14.0,
  planet_surface =
  {
    filename = q.."/graphics/planet/sun_color.png",
    width = 1024,
    height = 1024
  },
  planet_emission =
  {
    filename = q.."/graphics/planet/sun_color.png",
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
		{
			type = "space-connection",
			name = "nauvis-sun",
			subgroup = "planet-connections",
			from = "nauvis",
			to = "sun",
			order = "e[nauvis-sun]",
			length = 12000,
			asteroid_spawn_definitions = asteroid_util.spawn_definitions(asteroid_util.nauvis_vulcanus),
			icon = q.."/graphics/icons/sun.png"
		},
		{
			type = "space-connection",
			name = "zalupa-sun",
			subgroup = "planet-connections",
			from = "zalupa",
			to = "sun",
			order = "f[zalupa-sun]",
			length = 8000,
			asteroid_spawn_definitions = asteroid_util.spawn_definitions(asteroid_util.nauvis_vulcanus),
			icon = q.."/graphics/icons/sun.png"
		},
	}
)
