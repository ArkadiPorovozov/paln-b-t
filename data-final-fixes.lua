-- Границы и свечение белой лавы: меняются прототипы, созданные в data.lua.
require("prototype.white-lava-edges")

-- Планета sun использует тайлы космоса и космическую платформу на обычной
-- поверхности планеты. space-platform-foundation по умолчанию помечен как
-- "space": подсказка атласу, что спрайты нужны только на космических
-- платформах. На sun они нужны и на поверхности планеты, поэтому разрешаем
-- использовать их везде (иначе кромка платформы может не попасть в атлас).
local space_platform_foundation = data.raw["tile"] and data.raw["tile"]["space-platform-foundation"]
if space_platform_foundation then
  space_platform_foundation.sprite_usage_surface = "any"
end

-- Рецепт солнечного фундамента открывается там же, где ванильный рецепт
-- space-platform-foundation: технологией rocket-silo (вместе с
-- unlock-space-platforms). Так на sun можно строить платформу над лавой,
-- как только в игре появляются космические платформы.
local rocket_silo_technology = data.raw["technology"] and data.raw["technology"]["rocket-silo"]
if rocket_silo_technology and data.raw["recipe"]["sun-platform-foundation"] then
  rocket_silo_technology.effects = rocket_silo_technology.effects or {}
  local already_unlocked = false
  for _, effect in pairs(rocket_silo_technology.effects) do
    if effect.type == "unlock-recipe" and effect.recipe == "sun-platform-foundation" then
      already_unlocked = true
      break
    end
  end
  if not already_unlocked then
    table.insert(rocket_silo_technology.effects,
      {type = "unlock-recipe", recipe = "sun-platform-foundation"})
  end
end

-- Теплообменник открывается технологией sun: раньше на планету всё равно не
-- попасть, а на месте без него база не проживёт и минуты.
local SUN_TECHNOLOGY = "sun"
local SUN_RECIPES = {"sun-heat-exchanger"}
local sun_technology = data.raw["technology"] and data.raw["technology"][SUN_TECHNOLOGY]
if sun_technology then
  sun_technology.effects = sun_technology.effects or {}
  for _, recipe in ipairs(SUN_RECIPES) do
    if data.raw["recipe"][recipe] then
      local already_unlocked = false
      for _, effect in pairs(sun_technology.effects) do
        if effect.type == "unlock-recipe" and effect.recipe == recipe then
          already_unlocked = true
          break
        end
      end
      if not already_unlocked then
        table.insert(sun_technology.effects, {type = "unlock-recipe", recipe = recipe})
      end
    end
  end
end

-- Регистрация генерации планет (autoplace тайлов/облаков/дыма) вынесена в planet/.
require("prototype.planet.autoplace")

-- Регистрация турбины в библиотеке 0-things (Thing).
--
-- Things берёт на себя жизненный цикл турбины: постройка/снос, чертежи,
-- undo/redo, восстановление из "призраков" и т.п. А ещё он автоматически
-- создаёт и уничтожает "детей" турбины.
--
-- Ребёнок "generator" (нативный генератор ssc-turbine-plant) создаётся/удаляется
-- вместе с турбиной. Скрипт его не трогает вообще: генератор жжёт плазму из
-- турбины сам, сам даёт 6 МВт и сам пускает пар (см. prototype/entity/ssc-turbine.lua).
local things_names = data.raw["mod-data"] and data.raw["mod-data"]["things-names"]

if things_names then
  ---@type things.ThingRegistration
  things_names.data["ssc-turbine"] = {
    name = "ssc-turbine",
    -- Автоматически делать Thing из каждой построенной турбины.
    intercept_construction = true,
    -- 0-things переизлучает свои события как обычные кастомные события Factorio.
    -- Скрипт (script/ssc-turbine.lua) ловит их и так узнаёт о новой турбине — без
    -- подписки на on_built_entity (её уже занимает script/carkas.lua, а второй
    -- обработчик на то же событие в одном моде затирает первый) и без сканов
    -- поверхности. on_initialized — турбина построена; on_children_changed — у неё
    -- появился генератор-ребёнок (в этот момент скрипт связывает баки).
    custom_events = {
      on_initialized = "ssc-turbine-initialized",
      on_children_changed = "ssc-turbine-children-changed",
    },
    children = {
      generator = {
        -- Automatic child: Things создаст этот генератор вместе с турбиной.
        create = { name = "ssc-turbine-plant" },
      },
    },
  }

  -- Стройплощадка asm45_corp. Things ведёт её жизненный цикл (постройка, снос,
  -- чертежи, undo/redo), а скрипт script/asm45-corp-site.lua держит надпись над
  -- площадкой как render object, привязанный к Thing.
  things_names.data["asm45-corp-site"] = {
    name = "asm45-corp-site",
    intercept_construction = true,
  }
end

-- Кастомные события, которые 0-things переизлучает для турбины (см. custom_events
-- выше). Регистрируем их всегда: script.on_event по имени необъявленного события
-- падает с ошибкой при загрузке. Само событие, разумеется, придёт, только если
-- 0-things есть.
data:extend({
  { type = "custom-event", name = "ssc-turbine-initialized" },
  { type = "custom-event", name = "ssc-turbine-children-changed" },
})

-- Стоящий каркас площадки: один кадр из штатной анимации MultiBuild.
--
-- animation_speed у render object анимацию не останавливает (0 движок понимает
-- как «по умолчанию»), поэтому «замерший» каркас — это отдельный прототип,
-- в котором просто нечего проигрывать: одна и та же картинка в кадре 16.
local STAND_FRAME = 16 -- 1-based, то есть 15-й кадр с нуля — как в platform_anim

for _, corner in ipairs({"back_left", "back_right", "front_left", "front_right"}) do
  for _, part in ipairs({"top", "body"}) do
    local source = data.raw["animation"] and data.raw["animation"]["mb-panim-" .. corner .. "-" .. part]
    if source then
      local animation = table.deepcopy(source)
      animation.name = "asm45-scaffold-" .. corner .. "-" .. part
      for _, layer in ipairs(animation.layers) do
        layer.frame_sequence = {STAND_FRAME}
      end
      data:extend({animation})
    end
  end
end

-- =====================================================================
-- Локальность генерации: тайлы мода не спавнятся сами по себе.
-- =====================================================================
-- Вероятность каждого нашего тайла задаёт только та планета, которой он
-- принадлежит (prototype/planet/gen-*.lua через property_expression_names).
-- В прототипе autoplace всегда paln_const_zero. Здесь это принудительно
-- восстанавливается в data-final-fixes: если другой мод (или старый код)
-- вернул тайлу настоящий autoplace, мы его снова гасим.
--
-- Список тайлов и разрешённых планет — prototype/planet/locality.lua.
local locality = require("prototype.planet.locality")

for _, name in ipairs(locality.tiles) do
  local tile = data.raw["tile"] and data.raw["tile"][name]
  if tile then
    local autoplace = tile.autoplace
    if type(autoplace) ~= "table"
      or autoplace.probability_expression ~= "paln_const_zero" then
      tile.autoplace = {probability_expression = "paln_const_zero"}
      log("[paln-b-test] locality: тайл " .. name .. " снова получил autoplace = paln_const_zero")
    end
  end
end
