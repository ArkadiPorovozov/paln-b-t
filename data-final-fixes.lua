-- Границы и свечение белой лавы: меняются прототипы, созданные в data.lua.
require("prototype.white-lava-edges")

-- Регистрация турбины в библиотеке 0-things (Thing).
--
-- Things берёт на себя жизненный цикл турбины: постройка/снос, чертежи,
-- undo/redo, восстановление из "призраков" и т.п. А ещё он автоматически
-- создаёт и уничтожает "детей" турбины.
--
-- Ребёнок "generator" (ssc-turbine-generator) описан ниже и создаётся/удаляется
-- вместе с турбиной. Скрипт script/ssc-turbine.lua его не трогает: он лишь
-- включает генератор (50MW), пока турбина жжёт топливо, и выключает (0), когда
-- не жжёт.
local things_names = data.raw["mod-data"] and data.raw["mod-data"]["things-names"]

if things_names then
  ---@type things.ThingRegistration
  things_names.data["ssc-turbine"] = {
    name = "ssc-turbine",
    -- Автоматически делать Thing из каждой построенной турбины.
    intercept_construction = true,
    children = {
      generator = {
        -- Automatic child: Things создаст этот генератор вместе с турбиной.
        create = { name = "ssc-turbine-generator" },
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
