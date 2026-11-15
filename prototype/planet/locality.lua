-- Локальность генерации: какие тайлы мода где разрешены.
--
-- Файл не вызывает data:extend и вообще ничего не патчит — это чистые данные.
-- Его подключают:
--   * data-final-fixes.lua — принудительно ставит всем нашим тайлам
--     autoplace = paln_const_zero (вероятность задаётся только планетой через
--     property_expression_names);
--   * script/planet/locality.lua — прописывает нашим тайлам вероятность 0
--     там, где они не разрешены: на поверхности планеты мода — для тайлов,
--     которые ей не принадлежат, а на ЛЮБОЙ ЧУЖОЙ поверхности (Nauvis,
--     Vulcanus, Fulgora, Gleba, Aquilo, платформы, планеты других модов) —
--     для всех наших тайлов. Лечит старые сохранения, где в map_gen_settings
--     могли остаться ненулевые значения. Чужие/ванильные ключи не трогаются.
--
-- ВАЖНО: тайлы, которые не перечислены ни у одной планеты (white-lava,
-- white-oil-ocean-deep, sun-void, sun-lava-hot), не должны генерироваться
-- нигде — они существуют только как заготовки/совместимость.

local planets = {
  ["dark-ocean"] = {
    ["dark-deep-lake"] = true,
    ["dark-lava"] = true,
    ["dark-volcanic-folds-flat"] = true,
    ["dark-volcanic-folds"] = true,
    ["dark-volcanic-smooth-stone"] = true,
    ["dark-volcanic-smooth-stone-warm"] = true,
    ["dark-volcanic-ash-cracks"] = true,
    ["dark-volcanic-jagged-ground"] = true,
    ["dark-volcanic-ash-light"] = true,
  },

  ["zalupa"] = {
    ["zalupa-empty-space"] = true,
    ["zalupa-fulgoran-sand"] = true,
    ["zalupa-fulgoran-dust"] = true,
    ["zalupa-fulgoran-dunes"] = true,
    ["zalupa-highland-dark-rock-2"] = true,
    ["zalupa-fulgoran-rock"] = true,
    ["zalupa-lava"] = true,
    ["zalupa-lava-hot"] = true,
    ["white-oil-ocean-deep-2"] = true,
  },

  ["sun"] = {
    ["sun-surface"] = true,
    ["sun-platform-foundation"] = true,
  },
}

-- Все тайлы, которые создаёт мод: копии из prototype/tiles/ и копии тайлов
-- zalupa-* из prototype/planet/gen-zalupa.lua.
local tiles = {
  "white-lava",
  "white-oil-ocean-deep",
  "white-oil-ocean-deep-2",

  "zalupa-empty-space",
  "zalupa-fulgoran-sand",
  "zalupa-fulgoran-dust",
  "zalupa-fulgoran-dunes",
  "zalupa-highland-dark-rock-2",
  "zalupa-fulgoran-rock",
  "zalupa-lava",
  "zalupa-lava-hot",

  "sun-surface",
  "sun-void",
  "sun-lava-hot",
  "sun-platform-foundation",

  "dark-deep-lake",
  "dark-lava",
  "dark-volcanic-folds-flat",
  "dark-volcanic-folds",
  "dark-volcanic-smooth-stone",
  "dark-volcanic-smooth-stone-warm",
  "dark-volcanic-ash-cracks",
  "dark-volcanic-jagged-ground",
  "dark-volcanic-ash-light",
}

return {
  planets = planets,
  tiles = tiles,
}

