-- Вулканические декорации островов dark-ocean: средние камни, трещины
-- и кратеры с Вулкана (space-age).
--
-- Все прототипы — deepcopy ванильных optimized-decorative из
-- __space-age__/prototypes/decorative/decoratives-vulcanus.lua. Копируем, а не
-- переиспользуем ванильные, по трём причинам:
--   * нужен свой (более светлый) оттенок камней — на вечной ночи ванильный
--     почти чёрный и полностью теряется на тёмной земле;
--   * нужна своя плотность: ванильные вероятности рассчитаны на шум Вулкана и
--     его тайлы (vulcanus_rock_small и т.п.), на dark-ocean таких выражений нет;
--   * autoplace в прототипе выключаем (paln_const_zero), иначе копии вылезли бы
--     на чужие планеты — реальную вероятность задаёт только dark-ocean
--     (prototype/planet/autoplace.lua) через
--     property_expression_names["decorative:<имя>:probability"].
--
-- Сами вероятности считает prototype/planet/gen-dark-ocean.lua
-- (paln_dark_ocean_deco_*): только суша, только не лава, пятнами.
--
-- Модуль возвращает список {name, probability}: его читает
-- prototype/planet/autoplace.lua, чтобы не дублировать имена.

-- Оттенок камней. Ванильный tintable_rock_tint — 0.2588 (почти чёрный).
-- 0.62 оставляет камень тёмно-серым, но он читается в вечной ночи.
local ROCK_TINT = {0.62, 0.62, 0.62}

-- Проставить tint всем спрайтам декорации. pictures у optimized-decorative —
-- это либо массив спрайтов, либо массив {layers = {...}} (у medium-volcanic-rock),
-- поэтому обходим рекурсивно.
local function tint_sprites(pictures, tint)
  local function walk(node)
    if type(node) ~= "table" then
      return
    end
    if node.filename then
      node.tint = tint
      node.tint_as_overlay = true
      return
    end
    for _, child in pairs(node) do
      walk(child)
    end
  end
  walk(pictures)
end

-- name      — имя копии в моде;
-- source    — ванильный прототип space-age;
-- probability — noise-expression с вероятностью (gen-dark-ocean.lua);
-- tint      — перекрасить камни (для декалей не нужно — у них свой цвет).
local SPECS = {
  {
    name = "dark-volcanic-rock-medium",
    source = "medium-volcanic-rock",
    probability = "paln_dark_ocean_deco_medium_rock_prob",
    tint = ROCK_TINT,
  },
  {
    -- Горячие трещины: оранжевые прожилки, хорошо видны в темноте.
    name = "dark-volcanic-crack-warm",
    source = "vulcanus-crack-decal-warm",
    probability = "paln_dark_ocean_deco_crack_warm_prob",
  },
  {
    name = "dark-volcanic-crack-huge-warm",
    source = "vulcanus-crack-decal-huge-warm",
    probability = "paln_dark_ocean_deco_crack_huge_warm_prob",
  },
  {
    name = "dark-volcanic-crater-small",
    source = "crater-small",
    probability = "paln_dark_ocean_deco_crater_small_prob",
  },
  {
    name = "dark-volcanic-crater-large",
    source = "crater-large",
    probability = "paln_dark_ocean_deco_crater_large_prob",
  },
  {
    -- Каменистая декаль 4x4 тайла, редкая.
    name = "dark-volcanic-rock-decal",
    source = "vulcanus-rock-decal-large",
    probability = "paln_dark_ocean_deco_rock_decal_prob",
  },
}

local registered = {}

for _, spec in ipairs(SPECS) do
  local source = data.raw["optimized-decorative"] and
    data.raw["optimized-decorative"][spec.source]

  if source then
    local deco = table.deepcopy(source)
    deco.name = spec.name
    -- У ванильных декораций имя берётся из [decorative-name] по имени
    -- прототипа; копия с новым именем своего ключа не имеет — ссылаемся на
    -- ванильный, чтобы в отладочных списках не было "Unknown key".
    deco.localised_name = {"decorative-name." .. spec.source}

    if spec.tint then
      tint_sprites(deco.pictures, spec.tint)
    end

    -- Autoplace: порядок (order) и остальные поля берём ванильные, но
    -- плотность кандидатов — 1 на тайл (дальше всё решает вероятность), а сама
    -- вероятность в прототипе — ноль. Реальную задаёт только dark-ocean.
    deco.autoplace = deco.autoplace or {}
    deco.autoplace.placement_density = 1
    deco.autoplace.probability_expression = "paln_const_zero"
    deco.autoplace.richness_expression = nil

    data:extend({deco})
    registered[#registered + 1] = {
      name = spec.name,
      probability = spec.probability,
    }
  else
    log("[paln-b-test] prototype/decorative/volcanic-rocks.lua: " ..
      "не найден ванильный прототип " .. spec.source)
  end
end

return registered
