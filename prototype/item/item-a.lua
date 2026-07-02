local item_sounds = require("__base__.prototypes.item_sounds")
local item_tints = require("__base__.prototypes.item-tints")
local space_age_item_sounds = require("__space-age__.prototypes.item_sounds")

local q = "__test12__"


local items_to_generate = {
    {
        base_name = "part-electronic-memory",
        variations = 1,
        weight = 20,
        stack_size = 100,
        subgroup = "intermediate-product",
    },
    {
        base_name = "part-ammo-crate",
        variations = 2,
        weight = 20,
        stack_size = 100,
        subgroup = "intermediate-product",
    },
    {
        base_name = "part-electronic-ribbon-cable",
        variations = 3,
        weight = 20,
        stack_size = 100,
        subgroup = "intermediate-product",
    },
    {
        base_name = "part-electronic-storage",
        variations = 1,
        weight = 20,
        stack_size = 100,
        subgroup = "intermediate-product",
    },
    {
        base_name = "part-electronic-triode",
        variations = 1,
        weight = 20,
        stack_size = 100,
        subgroup = "intermediate-product",
    },
    {
        base_name = "part-electronic-composite",
        variations = 1,
        weight = 20,
        stack_size = 100,
        subgroup = "intermediate-product",
    },
}

local defaults = {
    variations = 1,
    weight = 100,
    stack_size = 50,
    subgroup = "other",
    icon_size = 64,
    icon_mipmaps = 4,
    inventory_move_sound = item_sounds.resource_inventory_move,
    pick_sound = item_sounds.resource_inventory_pickup,
    drop_sound = item_sounds.resource_inventory_filler,
}

local final_items = {}

for _, config in ipairs(items_to_generate) do
    local count = config.variations or defaults.variations

    local main_icon_path = ""
    if count > 1 then
        main_icon_path = q .. "/graphics/icon/item/" .. config.base_name .. "-1.png"
    else
        main_icon_path = q .. "/graphics/icon/item/" .. config.base_name .. ".png"
    end


    local variations_pictures = {}
    if count > 1 then
        for i = 1, count do
            table.insert(variations_pictures, {
                filename = q .. "/graphics/icon/item/" .. config.base_name .. "-" .. i .. ".png",
                size = config.icon_size or defaults.icon_size,
                mipmap_count = config.icon_mipmaps or defaults.icon_mipmaps,
                scale = 0.5
            })
        end
    else
        table.insert(variations_pictures, {
            filename = q .. "/graphics/icon/item/" .. config.base_name .. ".png",
            size = config.icon_size or defaults.icon_size,
            mipmap_count = config.icon_mipmaps or defaults.icon_mipmaps,
            scale = 0.5
        })
    end

    table.insert(final_items, {
        type = "item",
        name = config.base_name,
        icon = main_icon_path,
        icon_size = config.icon_size or defaults.icon_size,
        icon_mipmaps = config.icon_mipmaps or defaults.icon_mipmaps,

        pictures = variations_pictures,

        weight = (config.weight or defaults.weight) * 100,
        subgroup = config.subgroup or defaults.subgroup,
        order = "z[" .. config.base_name .. "]",
        stack_size = config.stack_size or defaults.stack_size,

        inventory_move_sound = config.inventory_move_sound or defaults.inventory_move_sound,
        pick_sound = config.pick_sound or defaults.pick_sound,
        drop_sound = config.drop_sound or defaults.drop_sound,
    })
end

data:extend(final_items)