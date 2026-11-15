-- Сами планеты мода: прототипы planet, вид из космоса и топология перелётов.
--
-- Генерация каждой планеты лежит в отдельном файле gen-<планета>.lua и
-- подключается здесь через local. Технологии (исследования) и прочая мелочь —
-- в prototype/planet/other.lua.
local w = "7lut"
local q = "__paln-b-test__"

local gen_zalupa = require("prototype.planet.gen-zalupa")
local gen_sun = require("prototype.planet.gen-sun")
local gen_dark_ocean = require("prototype.planet.gen-dark-ocean")

local asteroid_util = require("__space-age__.prototypes.planet.asteroid-spawn-definitions")

-- Общий конструктор планеты. map_gen — функция map_gen_settings (её возвращает
-- файл gen-<планета>.lua). options — переопределения полей (близость к центру,
-- размер на карте, атмосфера и т.п.).
local function create_planet(name, icon, map_gen, options)
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
    map_gen_settings = map_gen(),
    platform_surface_render_parameters = {},
    draw_orbit = true,
    unlocked = true,
  }

  if options then
    for key, value in pairs(options) do
      planet[key] = value
    end
  end

  return planet
end

-- =====================================================================
-- zalupa
-- =====================================================================

local zalupa_icon = "__space-age__/graphics/icons/solar-system-edge.png"

data:extend({
  create_planet("zalupa", zalupa_icon, gen_zalupa),
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

-- =====================================================================
-- sun: лава + космос.
-- =====================================================================
-- Поверхность целиком состоит из sun-void (космос, как на платформе) и
-- морей горячей лавы; сверху тот же рельеф островов, что и у zalupa.
-- На sun-void можно ставить space-platform-foundation, и её кромка
-- рисуется так же, как на космической платформе.
data:extend({
  create_planet("sun", q.."/graphics/icons/sun.png", gen_sun, {
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
  }),
})

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

-- =====================================================================
-- dark-ocean
-- =====================================================================

local dark_ocean_icon = q .. "/graphics/icons/dark-ocean.png"

data:extend({
  create_planet("dark-ocean", dark_ocean_icon, gen_dark_ocean, {
    starmap_icon = q .. "/graphics/planet/dark-ocean-starmap.png",
    starmap_icon_size = 512,
    gravity_pull = 10,
    distance = 15,
    orientation = 0.35,
    magnitude = 1,
    order = "z[dark-ocean]",
    -- Тени на поверхности. shadow_opacity = 0 полностью отключает тени
    -- (постройки, деревья и т.п.), поэтому вернули дефолтное 0.5 — как у
    -- остальных планет (см. __space-age__/base-data-updates.lua).
    surface_render_parameters = {
      shadow_opacity = 0.5,
      -- Вид поверхности задаётся своим LUT'ом (graphics/lut/1lut.png) на всех
      -- ключевых точках — то есть цветокором планеты целиком, независимо от
      -- времени суток (скриптов нет).
      --
      -- Время суток на планете заморожено (["day-night-cycle"] = 0 ниже) на
      -- полдне, поэтому движок не меняет LUT сам: вид поверхности определяется
      -- только таблицей ниже.
      day_night_cycle_color_lookup = {
        {0.00, q .. "/graphics/lut/"..w..".png"},
        {0.45, q .. "/graphics/lut/"..w..".png"},
        {0.55, q .. "/graphics/lut/"..w..".png"},
        {0.80, q .. "/graphics/lut/"..w..".png"},
      },
    },
    surface_properties = {
      gravity = 10,
      pressure = 1000,
      ["magnetic-field"] = 15,
      -- Время суток не идёт: вид поверхности задаёт LUT выше, а не цикл.
      ["day-night-cycle"] = 0,
      -- Плотная облачность: солнце почти не пробивается.
      ["solar-power"] = 40,
    },
  }),
})

local nauvis_backdrop =
  data.raw.planet["nauvis"].platform_surface_render_parameters.platform_backdrop

data.raw.planet["dark-ocean"].platform_surface_render_parameters.platform_backdrop = {
  emission_scales_with_shadow = false,
  radius = nauvis_backdrop.radius * 1.2,
  rotation_seconds = 300,
  surface_vertical_offset = 0.1,
  specular_intensity = 0.55,
  specular_color = {0.45, 0.72, 0.9, 1},
  atmosphere_color = {0.10, 0.35, 0.50, 0.35},
  planet_axis = {0.2, 5.0},
  planet_axis_deviation_amplitude = {4.0, 4.0},
  planet_axis_deviation_seconds = {1200.0, 900.0},
  position = {200, -250},
  parallax_strength = {0.95, 0.95},
  light_direction = {-0.42, 0.23, 0.4},
  light_intensity_contrast = 0.25,
  light_radius = 9.0,
  planet_surface = {
    filename = q .. "/graphics/planet/dark-ocean-color.png",
    width = 1024,
    height = 1024,
  },
}

-- =====================================================================
-- Топология: откуда долететь
-- =====================================================================

data:extend({
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
  {
    type = "space-connection",
    name = "nauvis-dark-ocean",
    subgroup = "planet-connections",
    from = "nauvis",
    to = "dark-ocean",
    order = "g[nauvis-dark-ocean]",
    length = 15000,
    asteroid_spawn_definitions = asteroid_util.spawn_definitions(asteroid_util.nauvis_vulcanus),
    icon = dark_ocean_icon,
  },
})
