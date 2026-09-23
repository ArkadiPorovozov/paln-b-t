local item_sounds = require("__base__.prototypes.item_sounds")
local item_tints = require("__base__.prototypes.item-tints")
local space_age_item_sounds = require("__space-age__.prototypes.item_sounds")

local function make_fluid(args)
    return {
        type = "fluid",
        name = args.name,
        

        icon = args.icon,
        icon_size = args.icon_size or 64,
        icons = args.icons, -- Если нужны слои или тинты (tint)
        
        -- Категория и сортировка
        subgroup = args.subgroup or "fluid",
        order = args.order or "a[" .. args.name .. "]",
        
        -- Специфика жидкостей:
        default_temperature = args.default_temperature or 25,
        max_temperature = args.max_temperature or 100,
        heat_capacity = args.heat_capacity or "1kJ", -- Теплоемкость (обязательно в формате строки с единицами)
        

        gas_temperature = args.gas_temperature, -- Температура, при которой жидкость становится газом (для анимации труб)
        fuel_value = args.fuel_value,           -- Если жидкость является топливом (например, как в Space Age)
        hidden = args.hidden or false,          -- Скрытая жидкость (не показывается в фильтрах игроку)
        auto_barrel = args.auto_barrel,
    }
end