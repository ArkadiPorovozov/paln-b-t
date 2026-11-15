-- =====================================================================
-- Тёмное глубокое озеро — копия gleba-deep-lake с Глебы.
-- =====================================================================
--
-- Отличия от оригинала:
--   * темнее: оттенок воды задаёт effect_color (тинт water-шейдера), он
--     приглушён примерно в 2.5 раза — вместе с map_color и
--     effect_color_secondary;
--   * без звуков: убраны шаги, приводнение, транспорт и ambient
--     (плеск воды / дождь), а также звук постройки;
--   * без бликов: у своего tile-effect обнулён specular_lightness — шейдер не
--     рисует «зайчики» солнца на воде (ванильный не трогаем, см. ниже);
--   * лежит ПОД всеми остальными тайлами — так же, как лава на sun.
--
-- Как это работает (подробный разбор — в разделе sun выше):
--   * layer_group = "water", layer = 1 — самая нижняя группа тайлов:
--     zero -> water -> water-overlay -> ground-natural -> ground-artificial.
--     Всё, что выше (земля, насыпь, плиты платформы), рисуется поверх;
--   * effect_is_opaque = false — ключевой флаг. Если оставить по умолчанию
--     (true при непрозрачном effect_color), water-шейдер рисуется отдельным
--     НЕПРОЗРАЧНЫМ проходом поверх обычных тайлов, и layer_group его не
--     спасает. С false шейдер смешивается внутри своей группы;
--   * в "water" полупрозрачный шейдер ещё и анимируется, а в "water-overlay"
--     движок рисует его статично (проверено на sun).
--
-- Тайл самодостаточен и сам по себе не генерируется (autoplace = paln_const_zero).
-- Чтобы использовать его на планете, достаточно прописать его в
-- map_gen_settings (пример — prototype/planet/gen-dark-ocean.lua); тогда же можно
-- убрать слой сущностей dark-water-shader, он станет не нужен.
local deep_lake = data.raw["tile"] and data.raw["tile"]["gleba-deep-lake"]
if deep_lake then
  -- Своя подгруппа, чтобы тайл не терялся среди ванильных в редакторе.
  data:extend({
    {
      type = "item-subgroup",
      name = "dark-tiles",
      group = "tiles",
      order = "0-a[dark-tiles]"
    }
  })

  local dark_lake = table.deepcopy(deep_lake)
  dark_lake.name = "dark-deep-lake"
  dark_lake.order = "z[other]-a[dark-deep-lake]"
  dark_lake.subgroup = "dark-tiles"
  dark_lake.localised_name = {"tile-name.dark-deep-lake"}
  dark_lake.factoriopedia_alternative = "gleba-deep-lake"

  -- Цвет. effect_color — тинт water-шейдера, именно он задаёт оттенок воды:
  -- у Gleba {31, 51, 60}. Сначала вода была почти чёрной (в 2.5 раза темнее,
  -- {12, 20, 25}) — получилось слишком глухо, поэтому сделали чуть светлее
  -- (примерно в 1.9 раза темнее Глебы, {16, 26, 33}), вместе с
  -- effect_color_secondary и map_color.
  dark_lake.effect_color = {16, 26, 33}
  dark_lake.effect_color_secondary = {24, 38, 8}
  dark_lake.map_color = {11, 20, 27}

  -- Группа "water", layer 1 — как у ванильной воды и лавы (base/deepwater,
  -- sun-surface). Ключевое: именно в "water" движок АНИМИРУЕТ полупрозрачный
  -- water-шейдер; в "water-overlay" и ниже он рисуется СТАТИЧНО. Поэтому тайл
  -- обязан лежать в "water" — иначе на тёмном глубоком озере нет волн
  -- (подробнее см. prototype/tiles/sun.lua, раздел про слои).
  dark_lake.layer_group = "water"
  dark_lake.layer = 1
  dark_lake.effect_is_opaque = false

  -- Спрайты должны попасть в атлас на любой поверхности, а не только Глебы.
  dark_lake.sprite_usage_surface = "any"

  -- Тишина: ни шагов, ни плеска, ни дождя, ни звука постройки.
  dark_lake.walking_sound = nil
  dark_lake.landing_steps_sound = nil
  dark_lake.driving_sound = nil
  dark_lake.ambient_sounds = nil
  dark_lake.ambient_sounds_group = nil
  dark_lake.build_sound = nil
  dark_lake.mined_sound = nil

  -- Сам по себе не генерируется: вероятность задаёт map_gen планеты.
  dark_lake.autoplace = {probability_expression = "paln_const_zero"}

  -- Убираем «блики» — блеск солнца на воде. Их даёт specular_lightness
  -- water-шейдера tile-effect "wetland-blue-slime" (унаследован от
  -- gleba-deep-lake). Этот tile-effect общий с тайлами Глебы, поэтому делаем
  -- свою копию и обнуляем specular_lightness только у неё: ванильные тайлы
  -- не затрагиваются, а океан dark-ocean перестаёт бликовать.
  local effect_set = data.raw["tile-effect"]
  local base_water_effect = effect_set and effect_set["wetland-blue-slime"]
  if base_water_effect then
    local dark_water_effect = table.deepcopy(base_water_effect)
    dark_water_effect.name = "dark-deep-lake-effect"
    if dark_water_effect.water then
      -- Без бликов солнца («зайчиков»).
      dark_water_effect.water.specular_lightness = {0, 0, 0}
      -- Волны мягче, чем на Глебе: у ванильного wetland-blue-slime
      -- animation_speed = 1.5, здесь 0.5 — рябь спокойнее и незаметнее.
      -- Хочешь ещё тише — 0.25; как было у Глебы — 1.5.
      dark_water_effect.water.animation_speed = 0.5
    end
    data:extend({dark_water_effect})
    dark_lake.effect = "dark-deep-lake-effect"
  else
    log("[paln-b-test] prototype/tiles/dark-lake.lua: не найден tile-effect wetland-blue-slime")
  end

  data:extend({dark_lake})

  -- Как sun-surface: тайл ничего не рисует по краям. Убираем чужие переходы
  -- (водные из gleba-deep-lake), а empty_transitions = true у него уже есть от
  -- оригинала — кромку к нашей воде рисует сосед (вулканический тайл).
  dark_lake.transitions = nil
  dark_lake.transitions_between_transitions = nil
else
  log("[paln-b-test] prototype/tiles/dark-lake.lua: не найден тайл gleba-deep-lake")
end
