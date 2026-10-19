-- Белые «водные» тайлы — копии ванильных тайлов с осветлёнными текстурами:
--   * white-lava            — копия глубокой лавы Вулкана (tile "lava-hot", tile-effect "lava");
--   * white-oil-ocean-deep  — копия глубокого нефтяного океана Фулгоры ("oil-ocean-deep");
--   * white-oil-ocean-deep-2 — его второй вариант ("oil-ocean-deep-2").
--
-- Цвет воды на «водных» тайлах задаёт не только effect_color, но и сами текстуры:
--   * <тайл>.png        — поверхность тайла (variants),
--   * <тайл>-shader.png — текстура поверхности для шейдера (tile-effect.image_textures[1]).
-- Их копии лежат в graphics/terrain: родной рисунок сохраняется один в один,
-- убрана только темнота (переведено в серый и поднята яркость).
-- Шум (lava-noise-*.png, oilNoise.png, oilGradient.png) берётся ОРИГИНАЛЬНЫЙ
-- из Space Age — это и есть «живая» анимация поверхности.
--
-- Но цвет задают не только текстуры: шейдер лавы по берегу подмешивает
-- зашитый тёплый цвет — у белой лавы он убирается порогами (см. ниже).
--
-- Яркость нефти: у первого тайла множитель 0.125, у второго 0.25,
-- то есть первый ровно в 2 раза темнее второго (и по поверхности, и по шейдеру).

local graphics = "__paln-b-test__/graphics/terrain/"
local texture = function(name) return graphics .. name end

-- Отдельная подгруппа тайлов в самом верху списка
-- (в группе "tiles" первая подгруппа — "artificial-tiles" с order = "a")
data:extend({
  {
    type = "item-subgroup",
    name = "white-tiles",
    group = "tiles",
    order = "0"
  }
})

-- source_surface — путь текстуры поверхности в исходном тайле, его и подменяем.
local white_tiles = {
  {
    name = "white-lava",
    source = "lava-hot",
    source_effect = "lava",
    effect = "white-lava",
    order = "a[lava]",
    source_surface = "__space-age__/graphics/terrain/vulcanus/lava-hot.png",
    surface = texture("white-lava.png"),
    shader_texture = texture("white-lava-shader.png"),
    effect_color = {235, 238, 243},
    map_color = {240, 244, 250},
    -- Шейдер лавы подмешивает по берегу ЗАШИТЫЙ тёплый цвет
    -- (tiles-lava-effect.frag): от dark_threshold идёт (1, 0.5, 0),
    -- от specular_threshold — (1, 0.5, 0). Из-за этого вокруг белой лавы
    -- остаётся оранжевая кромка. Оба порога в 0 её убирают.
    effect_patch = function(water)
      water.dark_threshold = {0, 0}
      water.specular_threshold = {0, 0}
    end
  },
  {
    name = "white-oil-ocean-deep",
    source = "oil-ocean-deep",
    source_effect = "oil-deep",
    effect = "white-oil-deep",
    order = "a[oil]-b[deep]",
    source_surface = "__space-age__/graphics/terrain/oil-ocean-deep.png",
    surface = texture("white-oil-ocean-deep-1.png"),
    shader_texture = texture("white-oil-ocean-deep-1-shader.png"),
    effect_color = {104, 106, 110},
    map_color = {112, 115, 120}
  },
  {
    name = "white-oil-ocean-deep-2",
    source = "oil-ocean-deep-2",
    source_effect = "oil-deep",
    effect = "white-oil-deep-2",
    order = "a[oil]-b[deep]",
    source_surface = "__space-age__/graphics/terrain/oil-ocean-deep.png",
    surface = texture("white-oil-ocean-deep-2.png"),
    shader_texture = texture("white-oil-ocean-deep-2-shader.png"),
    effect_color = {208, 211, 220},
    map_color = {224, 229, 240},
    -- в фактопедии показываем один раз (как у оригинала)
    factoriopedia_alternative = "white-oil-ocean-deep"
  }
}

-- Заменяем текстуру поверхности тайла на нужную нам копию
local function replace_surface_texture(tbl, original, replacement)
  for k, v in pairs(tbl) do
    if type(v) == "string" then
      if v == original then
        tbl[k] = replacement
      end
    elseif type(v) == "table" then
      replace_surface_texture(v, original, replacement)
    end
  end
end

for _, def in ipairs(white_tiles) do
  local source = data.raw["tile"][def.source]
  if source then
    -- свой tile-effect: копия исходного с родным шумом
    -- и своей текстурой поверхности для шейдера
    local effect = table.deepcopy(data.raw["tile-effect"][def.source_effect])
    effect.name = def.effect
    effect.water.image_textures[1].filename = def.shader_texture
    if def.effect_patch then
      def.effect_patch(effect.water)
    end
    data:extend({effect})

    local tile = table.deepcopy(source)
    tile.name = def.name
    tile.order = def.order
    tile.subgroup = "white-tiles"
    tile.localised_name = {"tile-name." .. def.name}

    -- собственно перекраска
    tile.effect = def.effect
    tile.effect_color = def.effect_color
    tile.effect_color_secondary = def.effect_color
    tile.map_color = def.map_color
    replace_surface_texture(tile, def.source_surface, def.surface)

    -- это отдельный тайл, а не замена: не спавним его рядом с оригиналом
    tile.autoplace = nil
    -- снимаем ограничение "сосед только lava": белая лава ставится где угодно
    tile.allowed_neighbors = nil
    tile.factoriopedia_alternative = def.factoriopedia_alternative

    data:extend({tile})

    -- как в Space Age (tiles-fulgora.lua): помечаем тайл «водным»,
    -- чтобы остальные тайлы рисовали к нему переходы
    water_tile_type_names = water_tile_type_names or {}
    table.insert(water_tile_type_names, def.name)
  else
    log("[paln-b-test] prototype/tile.lua: не найден исходный тайл " .. def.source)
  end
end
