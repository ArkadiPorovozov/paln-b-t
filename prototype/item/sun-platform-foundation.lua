-- Фундамент космической платформы для планеты sun.
--
-- По лаве солнца (sun-surface) нельзя ходить и строить. Единственное,
-- на чём там можно стоять и строить, — этот фундамент. Это копия
-- space-platform-foundation, но со своим тайлом (sun-platform-foundation,
-- см. prototype/tile.lua), потому что ванильный предмет кладёт ванильный
-- тайл.
--
-- Края и стыки платформы рисуются спрайтами из
-- __space-age__/graphics/terrain/space-platform (side, inner/outer corner,
-- double side, u, o + background/mask): они целиком унаследованы копией
-- тайла в prototype/tile.lua.
local item_sounds = require("__base__.prototypes.item_sounds")

data:extend({
  {
    type = "item",
    name = "sun-platform-foundation",
    icon = "__space-age__/graphics/icons/space-platform-foundation.png",
    icon_size = 64,
    subgroup = "space-platform",
    order = "a[space-platform-foundation]-b[sun]",
    inventory_move_sound = item_sounds.metal_large_inventory_move,
    pick_sound = item_sounds.metal_large_inventory_pickup,
    drop_sound = item_sounds.metal_large_inventory_move,
    stack_size = 100,
    weight = 20 * kg,
    place_as_tile =
    {
      result = "sun-platform-foundation",
      condition_size = 1,
      -- Маску не ограничиваем: тайл сам решает, куда его можно класть.
      condition = {layers = {}},
      -- Класть можно только на фотосферу и на уже построенный фундамент
      -- (чтобы тянуть платформу «сквозь» себя). sun-lava-hot/lava/lava-hot/
      -- sun-void добавлены для старых сохранений, где sun был другим.
      tile_condition =
      {
        "sun-surface",
        "sun-lava-hot",
        "lava",
        "lava-hot",
        "sun-void",
        "sun-platform-foundation",
      }
    }
  },
  {
    type = "recipe",
    name = "sun-platform-foundation",
    enabled = false,
    categories = {"crafting"},
    energy_required = 10,
    ingredients =
    {
      {type = "item", name = "steel-plate", amount = 20},
      {type = "item", name = "copper-cable", amount = 20}
    },
    results = {{type = "item", name = "sun-platform-foundation", amount = 1}}
  }
})
