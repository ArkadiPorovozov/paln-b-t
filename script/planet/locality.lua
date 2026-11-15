-- Локальность генерации на существующих поверхностях (лечение старых сейвов).
--
-- В прототипах у тайлов мода autoplace = paln_const_zero, а вероятность задаёт
-- только «своя» планета. Но в старом сохранении surface.map_gen_settings уже
-- содержит сохранённые override-выражения. Если там когда-то оказалась
-- ненулевая вероятность чужого тайла, новые чанки продолжат его генерировать.
--
-- Здесь мы обнуляем нашим тайлам вероятность 0 там, где они не должны
-- появляться:
--   * на поверхности планеты мода — для тайлов, которые этой планете не
--     принадлежат (prototype/planet/locality.lua);
--   * на любой ЧУЖОЙ поверхности (Nauvis, Vulcanus, Fulgora, Gleba, Aquilo,
--     платформы, планеты других модов) — для всех наших тайлов: на Вулкане
--     наши «тёмная лава»/«солнечная лава» появляться не должны.
--
-- В норме этого не требуется: у наших тайлов в прототипе autoplace =
-- paln_const_zero, поэтому сами по себе они не генерируются нигде. Но если
-- чужой сейв или мод прописал нашему тайлу ненулевую вероятность, мы её гасим.
-- Трогаем ТОЛЬКО строки с именами наших тайлов ("tile:<наш тайл>:probability"):
-- ванильные и чужие ключи не задеваем, отсутствующие ключи не добавляем.
--
-- Числовой 0 — литеральная константа: по документации property_expression_names
-- принимает числа без определения noise-expression.
--
-- Уже сгенерированные чанки это не перерисовывает: изменения касаются только
-- новых чанков.
--
-- ВАЖНО: в этом моде on_init/on_configuration_changed — «один обработчик на
-- мод»: повторная регистрация затирает чужие (см. комментарии в
-- script/clouds.lua и script/ssc-turbine.lua). Поэтому здесь не трогаем их, а
-- делаем разовую проверку на свободном тике 1. Версия мода в script.active_mods
-- позволяет повторить миграцию после обновления мода.

local locality = require("prototype.planet.locality")

local MOD_NAME = "paln-b-test"

local function sanitize(surface)
  -- Набор наших тайлов, разрешённых на этой поверхности. Чужая поверхность
  -- (в т.ч. Вулкан) — nil, значит не разрешён ни один наш тайл.
  local allowed = locality.planets[surface.name]
  local map_gen_settings = surface.map_gen_settings
  local names = map_gen_settings.property_expression_names
  -- Переопределений нет вообще: отсутствующий ключ и так даёт вероятность 0
  -- из прототипа (autoplace = paln_const_zero), добавлять его не нужно.
  if not names then
    return
  end

  local changed = 0
  for _, tile_name in ipairs(locality.tiles) do
    -- На «своей» планете тайл разрешён — не трогаем.
    if not (allowed and allowed[tile_name]) then
      local key = "tile:" .. tile_name .. ":probability"
      -- Правим только уже существующее ненулевое значение.
      local current = names[key]
      if current ~= nil and current ~= 0 then
        names[key] = 0
        changed = changed + 1
      end
    end
  end

  if changed > 0 then
    surface.map_gen_settings = map_gen_settings
    log("[paln-b-test] locality: " .. surface.name ..
      " — обнулена вероятность чужих тайлов мода: " .. changed)
  end
end

local function sanitize_all()
  for _, surface in pairs(game.surfaces) do
    sanitize(surface)
  end
end

-- Разовая миграция при загрузке и после обновления версии мода.
script.on_nth_tick(1, function()
  local version = script.active_mods[MOD_NAME]
  if storage.locality_applied_version == version then
    return
  end
  storage.locality_applied_version = version
  sanitize_all()
end)

-- Новая поверхность (в т.ч. планета другого мода): sanitize обнулит на ней наши
-- тайлы (если для них есть ненулевые ключи) и не тронет чужие.
script.on_event(defines.events.on_surface_created, function(event)
  local surface = game.get_surface(event.surface_index)
  if surface then
    sanitize(surface)
  end
end)