-- Планета sun: нагрев и плавление ОТКЛЮЧЕНЫ.
--
-- Раньше этот файл целиком отвечал за механику планеты: урон от солнца по
-- постройкам, плавление тайлов платформы в лаву, облака нагрева/охлаждения и
-- сетку теплообменников. Теперь механика выключена: вся она перенесена в
-- script/sun-cooling-old.lua, который НЕ подключается из control.lua и только
-- документирует то, как было раньше.
--
-- Здесь остаётся только внутренний теплообменник (ядро стартовой площадки): он
-- часть планеты, стоит в центре и должен существовать всегда — независимо от
-- того, включена механика или нет.

local SUN_SURFACE = "sun"

-- Внутренний теплообменник: часть планеты, стоит в центре стартовой площадки.
local CORE = "sun-core-exchanger"
local CORE_HEAD_ANIM = "sun-core-turret-head"
local CORE_POSITION = {x = 0, y = 0}

-- Один on_nth_tick на весь мод: 60 уже занят asm45-corp-site, поэтому 59.
local PASS_TICKS = 59

-- Версия структуры storage. Поднята, потому что от старой механики в сейвах
-- могли остаться большие таблицы построек/тайлов/теплообменников — они больше
-- не нужны, а держать их в памяти незачем, поэтому просто выбрасываем.
local STATE_VERSION = 6

local function get_state()
  local st = storage.sun_cooling
  if not st or st.version ~= STATE_VERSION then
    st = {version = STATE_VERSION}
    storage.sun_cooling = st
  end
  return st
end

------------------------------------------------------------------------------
-- Внутренний теплообменник (ядро стартовой площадки)
------------------------------------------------------------------------------

-- Ядро — часть планеты, а не постройка: ставим его сами, если его ещё нет.
-- Оно неразрушимое, поэтому второй раз сюда не придём из-за сноса; проверка
-- нужна только на первый запуск/после правки сейва.
local function ensure_core(surface)
  local core = surface.find_entity(CORE, CORE_POSITION)
  if core then
    return core
  end
  return surface.create_entity{name = CORE, position = CORE_POSITION, force = "neutral"}
end

-- Башня ядра вращается наполовину скриптом: сам прототип несёт только базу и
-- тень (у слоёв не может быть разного числа кадров), а 64 кадра направлений
-- рисует эта отрисовка и крутит их сама. Ядро одно на всю карту, поэтому это
-- ровно одна отрисовка, и создаётся она один раз.
local function ensure_core_head(st, core, surface)
  local head = st.core_head
  if head and head.valid then
    if head.target ~= core then
      head.target = core
    end
    return
  end

  st.core_head = rendering.draw_animation{
    animation = CORE_HEAD_ANIM,
    target = core,
    surface = surface,
    render_layer = "higher-object-above",
  }
end

local function sync_core(st)
  local surface = game.surfaces[SUN_SURFACE]
  if not surface then
    return
  end

  local core = ensure_core(surface)
  if core then
    ensure_core_head(st, core, surface)
  end
end

-- Ядро ставит сам проход по тику (PASS_TICKS), а не on_init: в этом моде on_init
-- и on_nth_tick — «один обработчик на мод», и register здесь затёр бы чужие
-- (script/clouds.lua, script/ssc-turbine.lua). Проход же и так крутится всегда,
-- так что к первому заходу на sun ядро уже на месте.
script.on_nth_tick(PASS_TICKS, function()
  local st = get_state()

  -- Ядро должно существовать всегда: ставим/поправляем его до всех проверок —
  -- площадка может быть и пустой.
  sync_core(st)
end)
