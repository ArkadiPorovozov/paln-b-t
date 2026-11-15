local hit_effects = require ("__base__.prototypes.entity.hit-effects")
local base_tile_sounds = require("__base__.prototypes.tile.tile-sounds")
local space_age_tile_sounds = require ("__space-age__.prototypes.tile.tile-sounds")
local base_sounds = require("__base__.prototypes.entity.sounds")
local decorative_trigger_effects = require("__base__.prototypes.decorative.decorative-trigger-effects")
local simulations = require("__space-age__.prototypes.factoriopedia-simulations")


local function collision_mask_1()
    return {
        layers = {
            ground_tile = true
        }
    }
end



local vulcanus_c_name = table.deepcopy(data.raw["simple-entity"]["vulcanus-chimney-cold"].name)

local new_name = vulcanus_c_name .. "q1"
-- Предмета-постройки у трубы НЕТ: её нельзя поставить вручную. Раньше здесь был
-- item-прототип с place_result = new_name — убран, чтобы труба не появлялась
-- ни в инвентаре, ни в чертежах, ни в списке строительства. Сама сущность
-- остаётся в мире (её ставит автогенерация dark-ocean).
local vulcanus_c = table.deepcopy(data.raw["simple-entity"]["vulcanus-chimney-cold"])
vulcanus_c.name = new_name
-- Добыча трубы даёт камень: от 10 до 50 штук за одну трубу.
vulcanus_c.minable = { mining_time = 0.5, results = {
    { type = "item", name = "stone", amount_min = 10, amount_max = 50 },
} }
vulcanus_c.collision_mask = collision_mask_1()
-- Цвет на карте: у ванильной трубы он средний бурый ({129, 105, 78}).
-- На тёмной воде такие пятна слишком светлые, поэтому затемняем — труба
-- читается на карте как тёмное пятно, а не светлое.
vulcanus_c.map_color = {58, 46, 34}
-- Эффект убран: у ванильного "vulcanus-chimney-cold" он задан через
-- stateless_visualisation_variations (холодный сернокислый пар, три выброса).
-- Копия его унаследовала — гасим обе возможные формы, чтобы из трубы ничего
-- не шло.
vulcanus_c.stateless_visualisation_variations = nil
vulcanus_c.stateless_visualisation = nil
-- Автогенерация. Сам прототип ничего не спавнит (paln_const_zero): копия
-- унаследовала бы autoplace ванильного "vulcanus-chimney-cold"
-- (probability_expression = "vulcanus_chimney_cold") и вылезла бы на Vulcanus
-- и любой другой планете. Реальную вероятность задаёт только dark-ocean —
-- см. prototype/planet/autoplace.lua
-- (property_expression_names["entity:vulcanus-chimney-coldq1:probability"]).
-- Коллизия только с ground_tile (collision_mask_1 выше): труба не встаёт на
-- сушу, зато свободно ставится на тёмную воду.
vulcanus_c.autoplace = {
  order = "a[landscape]-c[chimney]-a[full]-c",
  probability_expression = "paln_const_zero",
  richness_expression = "paln_const_zero",
}
data:extend({vulcanus_c})


