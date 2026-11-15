local shared = require("prototype.tiles.shared")
local apply_space_border = shared.apply_space_border

local q = "__paln-b-test__"

-- =====================================================================
-- Лавовый пик островов тёмного океана.
-- =====================================================================
--
-- Полная копия ванильной лавы Вулкана (tile "lava"): deepcopy целиком, только
-- переименование и то, без чего копия не заработает на нашей поверхности.
-- На тёмном океане она ставится на самый верх уровня острова — «пик» (см.
-- prototype/planet/gen-dark-ocean.lua, paln_dark_ocean_prob_lava).
--
-- Изменяется относительно ванильного оригинала:
--   * name/subgroup/order/localised_name — это отдельный тайл;
--   * sprite_usage_surface = "any" — спрайты нужны на нашей поверхности;
--   * autoplace = paln_const_zero — сам по себе не генерируется (иначе полез бы
--     ещё и на Вулкан);
--   * allowed_neighbors: в ванили там только {"lava-hot"} (на Вулкане лава
--     обязана граничить с горячей), расширяем до наших вулканических тайлов —
--     иначе лава не может соседствовать с островом. ВАЖНО: ванильные
--     "lava"/"lava-hot" в список НЕ добавляем (см. комментарий ниже);
--   * apply_space_border — родная кромка out-of-map перехода рисуется и к
--     тёмной воде (dark-deep-lake), как у тёмной суши;
--   * добавлен light-слой: лава светится сама и не гаснет ночью (см. ниже);
--   * кромка от соседних наземных тайлов: у каждой тёмной копии
--     (add_border_to, см. выше) dark-lava добавлен в to_tiles лавового и
--     водного переходов. Глобальные lava_tile_type_names/water_tile_type_names
--     при этом не трогаются.
local lava_source = data.raw["tile"] and data.raw["tile"]["lava"]
if lava_source then
  local dark_lava = table.deepcopy(lava_source)
  dark_lava.name = "dark-lava"
  dark_lava.subgroup = "dark-tiles"
  dark_lava.order = "z[other]-b[dark-lava]"
  dark_lava.localised_name = {"tile-name.lava"}
  dark_lava.sprite_usage_surface = "any"
  dark_lava.autoplace = {probability_expression = "paln_const_zero"}

  -- Лава светится сама: добавляем тайлу light-слой (эмиссию).
  --
  -- Это отдельный спрайт-лист graphics/tile/dark-lava-light.png — копия
  -- лавового (lava.png) с чёрным фоном: остаются только раскалённые прожилки.
  -- Движок рисует light-слой аддитивно и ночным LUT его НЕ гасит, поэтому на
  -- вечной ночи лава остаётся ярко-оранжевой и подсвечивает саму себя — так же
  -- светятся ванильные volcanic-cracks-hot
  -- (tile_variations_template_with_transitions_and_light).
  --
  -- Раскладка спрайт-листа та же, что и у main (мы просто перекрасили
  -- lava.png), поэтому шаблон с дефолтными размерами 1/2/4 подходит один в
  -- один: те же 16 вариантов и те же y-смещения. Сгенерировать заново:
  -- C:\Users\eblan\AppData\Local\Temp\opencode\make-lava-light.ps1
  -- (threshold/span/boost — «сколько горячих пикселей оставить и насколько
  -- усилить»).
  dark_lava.variants.light = tile_variations_template(
    q .. "/graphics/tile/dark-lava-light.png", nil, { empty_transitions = true }).main

  -- Список соседей — только наши тёмные тайлы. Ванильных "lava"/"lava-hot"
  -- здесь быть НЕ должно: allowed_neighbors заставляет движок при генерации
  -- «подставлять» тайл рядом с уже сгенерированным соседом из списка. Если
  -- dark-lava разрешает границу с ванильной lava/lava-hot, движок достраивает
  -- dark-lava на Вулкане (и на любой планете с лавой), несмотря на
  -- autoplace = paln_const_zero, а вслед за ним тянется и dark-deep-lake.
  -- На своей планете dark-ocean ванильной лавы нет, поэтому эти имена там не
  -- нужны: генерация dark-ocean от их удаления не меняется.
  local lava_neighbors = {
    "dark-lava",
    "dark-deep-lake",
    "dark-volcanic-folds-flat", "dark-volcanic-folds",
    "dark-volcanic-smooth-stone", "dark-volcanic-smooth-stone-warm",
    "dark-volcanic-ash-cracks", "dark-volcanic-ash-light",
    "dark-volcanic-jagged-ground",
  }
  dark_lava.allowed_neighbors = lava_neighbors

  -- Кромку к тёмной воде (на краю острова) рисуем так же, как у тёмной суши:
  -- движок сам берёт родной спрайт out-of-map перехода и добавляет в него
  -- dark-deep-lake.
  apply_space_border(dark_lava)

  -- Кромку и шейдер к dark-lava рисуют соседние тайлы: их to_tiles мы поправили
  -- точечно (add_border_to в цикле выше), а не через общие
  -- lava_tile_type_names/water_tile_type_names.
  data:extend({dark_lava})
else
  log("[paln-b-test] prototype/tiles/dark-lava.lua: не найден тайл lava")
end
