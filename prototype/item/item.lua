local item_sounds = require("__base__.prototypes.item_sounds")
local item_tints = require("__base__.prototypes.item-tints")
local space_age_item_sounds = require("__space-age__.prototypes.item_sounds")

local q = "__paln-b-test__"




local function make_item(args)
    return {
        type = "item",
        name = args.name,
        icon = args.icon,
        icons = args.iconsor,
        icon_size = args.icon_size or 64,
        pictures = args.pictures,
        subgroup = args.subgroup or "raw-material",
        order = "a[" .. args.name .. "]",
        inventory_move_sound = item_sounds.metal_small_inventory_move,
        pick_sound = item_sounds.metal_small_inventory_pickup,
        drop_sound = item_sounds.metal_small_inventory_move,
        stack_size = args.stack_size or 50,
        weight = (args.weight or 4) * kg
    }
end


data:extend({
    make_item{
        name = "part-electronic-storage",
        icon = q .. "/graphics/icon/item/part-electronic-storage.png",
    },
    make_item{
        name = "part-electronic-triode",
        icon = q .. "/graphics/icon/item/part-electronic-triode.png",
        stack_size = 100,
    },
    make_item{
        name = "part-electronic-memory", 
        icon = q .. "/graphics/icon/item/part-electronic-memory.png",
        stack_size = 20,
    },
})
