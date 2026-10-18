-- Белый нефтяной океан — копия глубокого нефтяного океана Фулгоры (Space Age):
-- data.raw.tile["oil-ocean-deep"] / ["oil-ocean-deep-2"], у обоих effect = "oil-deep".
--
-- Цвет воды на «водных» тайлах задаёт не только effect_color, но и сами текстуры,
-- а у нефтяного океана они тёмные:
--   * oil-ocean-deep.png        — поверхность тайла,
--   * oil-ocean-deep-shader.png — текстура поверхности для шейдера.
-- Их копии лежат в graphics/terrain: родной рисунок нефти сохраняется один в один,
-- убрана только темнота. Шум (oilNoise.png) и градиент тонкой плёнки (oilGradient.png)
-- берутся ОРИГИНАЛЬНЫЕ из Space Age — это и есть «нефтяная» анимация.
--
-- Яркость: у первого тайла множитель 0.125, у второго 0.25,
-- то есть первый ровно в 2 раза темнее второго (и по поверхности, и по шейдеру).

local graphics = "__paln-b-test__/graphics/terrain/"
local texture = function(name) return graphics .. name end

-- Отдельная подгруппа тайлов в самом верху списка
-- (в группе "tiles" первая подгруппа — "artificial-tiles" с order = "a")
data:extend({
  {
    type = "item-subgroup",
    name = "white-oil-ocean-tiles",
    group = "tiles",
    order = "0"
  }
})

local white_tiles = {
  {
    name = "white-oil-ocean-deep",
    source = "oil-ocean-deep",
    effect = "white-oil-deep",
    surface = texture("white-oil-ocean-deep-1.png"),
    shader_texture = texture("white-oil-ocean-deep-1-shader.png"),
    effect_color = {104, 106, 110},
    map_color = {112, 115, 120}
  },
  {
    name = "white-oil-ocean-deep-2",
    source = "oil-ocean-deep-2",
    effect = "white-oil-deep-2",
    surface = texture("white-oil-ocean-deep-2.png"),
    shader_texture = texture("white-oil-ocean-deep-2-shader.png"),
    effect_color = {208, 211, 220},
    map_color = {224, 229, 240},
    -- в фактопедии показываем один раз (как у оригинала)
    factoriopedia_alternative = "white-oil-ocean-deep"
  }
}

-- Заменяем текстуру поверхности тайла на нужную нам копию
local function replace_surface_texture(tbl, replacement)
  for k, v in pairs(tbl) do
    if type(v) == "string" then
      if v == "__space-age__/graphics/terrain/oil-ocean-deep.png" then
        tbl[k] = replacement
      end
    elseif type(v) == "table" then
      replace_surface_texture(v, replacement)
    end
  end
end

for _, def in ipairs(white_tiles) do
  local source = data.raw["tile"][def.source]
  if source then
    -- свой tile-effect: копия "oil-deep" с родным нефтяным шумом
    -- и своей текстурой поверхности для шейдера
    local effect = table.deepcopy(data.raw["tile-effect"]["oil-deep"])
    effect.name = def.effect
    effect.water.image_textures[1].filename = def.shader_texture
    data:extend({effect})

    local tile = table.deepcopy(source)
    tile.name = def.name
    tile.order = "a[oil]-b[deep]"
    tile.subgroup = "white-oil-ocean-tiles"
    tile.localised_name = {"tile-name.white-oil-ocean-deep"}

    -- собственно перекраска
    tile.effect = def.effect
    tile.effect_color = def.effect_color
    tile.effect_color_secondary = def.effect_color
    tile.map_color = def.map_color
    replace_surface_texture(tile, def.surface)

    -- это отдельный тайл, а не замена: не спавним его на Фулгоре рядом с оригиналом
    tile.autoplace = nil
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
