-- Границы и свечение белой лавы.
--
-- Переход "земля -> лава" задаётся не самим тайлом лавы, а соседними тайлами:
-- у них есть запись перехода с transition_group = lava, spritesheet берега
-- (lava-stone.png и её варианты) и карта света (lightmap) — именно lightmap
-- подсвечивает землю вокруг лавы.
--
-- Берег рисуется поверх лавы готовой картинкой: чёрный камень по краю и
-- оранжевые блики лавы внутри. Для white-lava берём копию, где белыми стали
-- только оранжевые блики, а чёрный камень и прозрачные пиксели не тронуты.
--
-- Lightmap — это свет, который падает на землю вокруг лавы. В белой копии
-- он белый: яркость та же, чёрное остаётся чёрным.
--
-- Ещё white-lava убирается из "водных" переходов: иначе часть тайлов рисует
-- к белой лаве холодный водный берег — без лавы и без свечения.

local WHITE_LAVA = "white-lava"

local border_graphics = "__paln-b-test__/graphics/terrain/white-lava-border/"

-- Берега и карты света, для которых сделаны белые копии (их используют
-- соседние тайлы).
local white_borders = {
  ["lava-stone.png"] = true,
  ["stone-path-lava.png"] = true,
  ["concrete-lava.png"] = true,
  ["refined-concrete-lava.png"] = true,
  ["foundation-lava.png"] = true
}

local white_lightmaps = {
  ["lava-stone-lightmap.png"] = true,
  ["stone-path-lava-lightmap.png"] = true,
  ["concrete-lava-lightmap.png"] = true,
  ["refined-concrete-lava-lightmap.png"] = true,
  ["foundation-lava-lightmap.png"] = true
}

local function list_contains(list, name)
  if not list then return false end
  for _, value in ipairs(list) do
    if value == name then return true end
  end
  return false
end

local function file_name(path)
  if type(path) ~= "string" then return nil end
  return path:match("[^/]+$")
end

-- Многие тайлы ссылаются на один и тот же список переходов (например, все
-- травяные тайлы), поэтому правим каждый список только один раз.
local patched = {}

local function patch_transitions(tile)
  local transitions = tile.transitions
  if not transitions or patched[transitions] then return end
  patched[transitions] = true

  local additions = {}

  for _, transition in ipairs(transitions) do
    -- white-lava не должен попадать в чужие (водные) переходы
    local to_tiles = transition.to_tiles
    if to_tiles then
      for i = #to_tiles, 1, -1 do
        if to_tiles[i] == WHITE_LAVA then
          table.remove(to_tiles, i)
        end
      end
    end

    -- свой переход "земля -> white-lava": белые блики берега и белый свет
    if transition.lightmap_layout
      and white_lightmaps[file_name(transition.lightmap_layout.spritesheet)]
      and white_borders[file_name(transition.spritesheet)]
      and (list_contains(to_tiles, "lava") or list_contains(to_tiles, "lava-hot")) then
      local white_transition = table.deepcopy(transition)
      white_transition.to_tiles = {WHITE_LAVA}
      white_transition.spritesheet = border_graphics .. file_name(transition.spritesheet)
      white_transition.lightmap_layout.spritesheet =
        border_graphics .. file_name(transition.lightmap_layout.spritesheet)
      additions[#additions + 1] = white_transition
    end
  end

  for _, transition in ipairs(additions) do
    transitions[#transitions + 1] = transition
  end
end

for _, tile in pairs(data.raw["tile"]) do
  patch_transitions(tile)
end
