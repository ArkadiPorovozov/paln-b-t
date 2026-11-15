-- Значок «затоплено» для планеты dark-ocean.
--
-- Рисуется скриптом script/planet/dark-ocean-flood.lua над каждой постройкой,
-- которая стоит под водой и из-за этого не работает.
--
-- Картинка своя: graphics/icon/flood-warning.png, 64x64. Геометрия и палитра
-- отличаются от maraxsis (у него #11CBFF, у нас #0FB2E2 — чуть темнее).
-- Пересобрать: C:\Users\eblan\AppData\Local\Temp\opencode\make-flood-icon.py
--
-- scale 0.5 — как у maraxsis-flooded-warning: 64 px превращаются в 32 px и
-- значок не закрывает саму постройку. flags "no-scale" не даёт игровым
-- настройкам масштаба иконок растянуть его повторно.
data:extend({
  {
    type = "sprite",
    name = "paln-flooded-warning",
    filename = "__paln-b-test__/graphics/icon/flood-warning.png",
    width = 64,
    height = 64,
    scale = 0.5,
    shift = {0, 0},
    flags = {"no-crop", "no-scale", "icon"},
  },
})
