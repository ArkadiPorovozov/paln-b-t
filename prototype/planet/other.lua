-- Прочее, не относящееся к самим планетам и их генерации: технологии,
-- открывающие перелёт, и подобная мелочь.

local q = "__paln-b-test__"

-- Технология, открывающая перелёт на планету: разблокирует точку в звёздной
-- карте с той же иконкой, что у планеты.
local function create_technology(name, icon)
  return {
    type = "technology",
    name = name,
    icon = icon,
    icon_size = 64,
    effects = {
      {
        type = "unlock-space-location",
        space_location = name,
        use_icon_overlay_constant = true,
      },
    },
    unit = {
      count = 100,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
      },
      time = 30,
    },
  }
end

data:extend({
  create_technology("zalupa", "__space-age__/graphics/icons/solar-system-edge.png"),
  create_technology("sun", q .. "/graphics/icons/sun.png"),
  create_technology("dark-ocean", q .. "/graphics/icons/dark-ocean.png"),
})
