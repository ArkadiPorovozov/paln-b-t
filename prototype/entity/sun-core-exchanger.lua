-- Внутренний теплообменник солнца (sun-core-exchanger).
--
-- Появляется сам, в центре стартовой площадки, как только существует поверхность
-- sun (script/sun-cooling.lua): снести его нельзя, открыть — тоже (у simple-entity
-- вообще нет окна), ресурсов он не требует. Раньше он постоянно охлаждал стартовую
-- площадку (радиус 14 вокруг 0,0). Сейчас нагрев/плавление на sun отключено
-- (см. script/sun-cooling-old.lua), и ядро осталось просто частью планеты.
--
-- Внешне это та же ракетная турель, что и sun-heat-exchanger (prototype/entity/
-- sun-heat-exchanger.lua). База и тень — статичные слои самого прототипа; башня
-- вынесена в отдельную анимацию sun-core-turret-head, и её крутит скрипт: 64
-- спрайта направлений (rocket-turret-shooting-*.png) проигрываются по кругу.
--
-- Почему башня не в прототипе: движок запрещает слои с разным числом кадров
-- («Different frame counts in layers»), а база — один кадр, башня — 64.
local rocket_turret_shift = -20 -- px, как в space-age/prototypes/entity/turrets.lua

-- Пиксельное смещение слоя -> смещение в тайлах.
local function turret_shift(x, y)
  return {x / 32, (y + rocket_turret_shift) / 32}
end

data:extend({
  -- Башня теплообменника: все 64 направления подряд. Скрипт рисует её поверх
  -- базы (rendering.draw_animation), поэтому это обычная анимация, а не
  -- RotatedAnimation: кадры просто идут по кругу и дают вращение.
  {
    type = "animation",
    name = "sun-core-turret-head",
    layers =
    {
      {
        filenames = {
          "__space-age__/graphics/entity/rocket-turret/rocket-turret-shooting-1.png",
          "__space-age__/graphics/entity/rocket-turret/rocket-turret-shooting-2.png",
          "__space-age__/graphics/entity/rocket-turret/rocket-turret-shooting-3.png",
        },
        width = 160,
        height = 164,
        scale = 0.5,
        shift = turret_shift(0, -8.5),
        priority = "high",
        line_length = 1,
        lines_per_file = 22,
        frame_count = 64,
        -- 0.5 кадра/тик — оборот примерно за 128 тиков (~2.1 с).
        animation_speed = 0.5,
      },
    },
  },

  {
    type = "simple-entity",
    name = "sun-core-exchanger",
    icon = "__space-age__/graphics/icons/rocket-turret.png",

    -- Ни снести, ни выбрать (значит, и открыть), ни скопировать в чертёж, ни
    -- починить: это часть самой планеты, а не постройка игрока.
    flags = {
      "placeable-neutral", "player-creation",
      "not-deconstructable", "not-selectable-in-game", "not-blueprintable",
      "not-repairable", "not-rotatable", "not-upgradable", "not-on-map",
    },
    -- Урону не поддаётся вовсе: расплавить его нельзя.
    destructible = false,

    collision_box = {{-1.2, -1.2}, {1.2, 1.2}},
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
    render_layer = "object",

    animations =
    {
      {
        layers =
        {
          {
            filename = "__space-age__/graphics/entity/rocket-turret/rocket-turret-base.png",
            width = 202,
            height = 168,
            scale = 0.5,
            shift = turret_shift(-0.5, 24.5),
            priority = "high",
          },
          {
            filename = "__space-age__/graphics/entity/rocket-turret/rocket-turret-base-shadow.png",
            width = 204,
            height = 148,
            scale = 0.5,
            shift = turret_shift(7.5, 26.5),
            draw_as_shadow = true,
          },
        },
      },
    },
  },
})
