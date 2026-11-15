-- Белые «водные» тайлы — копии ванильных тайлов с осветлёнными текстурами:
--   * white-lava            — копия глубокой лавы Вулкана (tile "lava-hot", tile-effect "lava");
--   * white-oil-ocean-deep  — копия глубокого нефтяного океана Фулгоры ("oil-ocean-deep");
--   * white-oil-ocean-deep-2 — его второй вариант ("oil-ocean-deep-2").
--
-- Плюс копии наземных тайлов Фулгоры в двух вариантах — тёмном и светлом:
--   * fulgoran-sand-dark / -light,
--   * fulgoran-rock-dark / -light.
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

-- Группы тайлов разложены по файлам: 1 файл = 1 группа тайлов.
-- Порядок подключения важен: dark-* ссылаются на dark-deep-lake.

-- Идентификаторы групп переходов обычно задаёт saplib. Мод на неё не
-- опирается, поэтому дублируем значения (если saplib уже загружена, её
-- значения сохраняются).
default_transition_group_id = default_transition_group_id or 0
water_transition_group_id = water_transition_group_id or 1
out_of_map_transition_group_id = out_of_map_transition_group_id or 2
lava_transition_group_id = lava_transition_group_id or 3

require("prototype.tiles.white")
require("prototype.tiles.fulgora-copies")
require("prototype.tiles.sun")
require("prototype.tiles.dark-lake")
require("prototype.tiles.dark-volcanic")
require("prototype.tiles.dark-lava")
