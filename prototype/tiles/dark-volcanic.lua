local shared = require("prototype.tiles.shared")
local add_border_to = shared.add_border_to
local apply_space_border = shared.apply_space_border

-- =====================================================================
-- Тёмные копии вулканических тайлов Вулкана.
-- =====================================================================
--
-- Семь наземных тайлов Вулкана копируются один в один (префикс "dark-") и
-- кладутся в подгруппу "dark-tiles". Локализация берётся у ванильных тайлов:
-- localised_name ссылается на tile-name.<оригинал>, поэтому новых записей в
-- locale не нужно.
--
-- Переходы у копий остаются родные (water/lava/out-of-map из
-- lava_stone_transitions), поэтому связи с обычными тайлами работают как у
-- ванильных вулканических тайлов. Для границы с тёмной водой мы не подменяем
-- спрайты, а просим движок нарисовать её сам: добавляем "dark-deep-lake" в
-- to_tiles родного out-of-map перехода.
--
-- Тайлы самодостаточны и сами по себе не генерируются (autoplace = paln_const_zero):
-- чтобы использовать их на планете, пропишите их в map_gen_settings
-- (пример — prototype/planet/gen-dark-ocean.lua).
local dark_volcanic_tiles = {
  "volcanic-folds-flat",
  "volcanic-folds",
  "volcanic-smooth-stone",
  "volcanic-smooth-stone-warm",
  "volcanic-ash-cracks",
  "volcanic-jagged-ground",
  "volcanic-ash-light",
}



-- dark-lava на тёмном океане должен считаться лавой/водой для соседних
-- наземных тайлов — тогда они рисуют к нему родную лавовую кромку. Делаем это
-- точечно у каждой копии (add_border_to), а не через глобальные
-- lava_tile_type_names/water_tile_type_names: эти списки читают тайлы всех
-- планет и других модов, оставлять в них наши имена нельзя.

for _, source_name in ipairs(dark_volcanic_tiles) do
  local source = data.raw["tile"] and data.raw["tile"][source_name]
  if source then
    local tile = table.deepcopy(source)
    tile.name = "dark-" .. source_name
    tile.subgroup = "dark-tiles"
    tile.order = "z[other]-c[dark-" .. source_name .. "]"
    tile.localised_name = {"tile-name." .. source_name}
    -- Спрайты нужны на поверхности нашей планеты, а не только на Вулкане.
    tile.sprite_usage_surface = "any"
    tile.autoplace = {probability_expression = "paln_const_zero"}
    apply_space_border(tile)
    -- Родная лавовая/водная кромка к dark-lava (см. комментарий выше).
    add_border_to(tile, lava_transition_group_id, "dark-lava")
    add_border_to(tile, water_transition_group_id, "dark-lava")
    data:extend({tile})
  else
    log("[paln-b-test] prototype/tiles/dark-volcanic.lua: не найден исходный тайл " .. source_name)
  end
end
