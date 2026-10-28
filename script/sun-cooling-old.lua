-- =====================================================================
-- СТАРЫЙ ФАЙЛ (НЕ ПОДКЛЮЧАЕТСЯ). Это прежняя механика планеты sun: урон от
-- солнца по постройкам, плавление тайлов платформы в лаву, облака нагрева и
-- охлаждения и сетка теплообменников. Механика отключена: файл оставлен только
-- как справка и не вызывается из control.lua. Живой код — script/sun-cooling.lua
-- (там осталось лишь ядро стартовой площадки).
-- =====================================================================
--
-- Плавление и охлаждение на планете sun.
--
-- Охлаждает только теплообменник (sun-heat-exchanger): пока машина работает,
-- то есть пока в неё залита вода (она её постоянно тратит), всё в радиусе
-- COOLING_RADIUS тайлов не плавится. Трубы больше не охлаждают: это такие же
-- постройки, как и всё остальное, и без теплообменника они плавятся.
--
-- Всё остальное в этом файле — про то, чтобы механика стоила почти ничего:
--   * реестр в storage наполняется событиями постройки; никаких
--     find_entities_filtered по площади и проходов по чанкам;
--   * один on_nth_tick на весь мод (PASS_TICKS: 60 уже занят asm45-corp-site,
--     а on_nth_tick заменяет обработчик того же тика, поэтому берём 59);
--   * теплообменники раскладываются по сетке с клеткой = радиусу охлаждения,
--     поэтому «охлаждено?» — это 9 хэш-лукапов, а не перебор всех машин;
--   * невалидные записи выбрасываются прямо в проходе, обработчиков сноса и
--     смерти нет вовсе.
--
-- Время плавления не зависит от HP и качества: урон за проход равен
-- max_health * PASS_TICKS / (60 * MELT_SECONDS), то есть ровно
-- 1/MELT_SECONDS максимального здоровья в секунду.
--
-- Сущности ищутся по имени и позиции (surface.find_entity), а не по
-- unit_number: game.get_entity_by_unit_number работает только для прототипов с
-- флагом "get-by-unit-number", а он есть далеко не у всех (в ваниле — только у
-- персонажа).

local SUN_SURFACE = "sun"
local EXCHANGER = "sun-heat-exchanger"
local PLATFORM_TILE = "sun-platform-foundation"
local LAVA_TILE = "sun-surface"

-- Внутренний теплообменник: часть планеты, стоит в центре стартовой площадки и
-- охлаждает её всегда — см. ensure_core() и CORE_RADIUS ниже.
local CORE = "sun-core-exchanger"
local CORE_HEAD_ANIM = "sun-core-turret-head"

local COOLING_RADIUS = 8
local COOLING_RADIUS_SQ = COOLING_RADIUS * COOLING_RADIUS

-- Радиус стартовой площадки: ровно тот круг, который генерирует
-- prototype/planet/noise-data.lua (sun_landing_pad_prob, ~14 тайлов вокруг 0,0).
-- Внутри него охлаждает ядро — всегда и без воды.
local CORE_RADIUS = 14
local CORE_RADIUS_SQ = CORE_RADIUS * CORE_RADIUS
local CORE_POSITION = {x = 0, y = 0}
local MELT_SECONDS = 60
local PASS_TICKS = 59
local TILE_CHECK_EVERY = 2
-- TILE_CHECK_EVERY проходов по PASS_TICKS тиков даёт ~1.97 с на проверку,
-- поэтому 31 проверка — это ~61 с; постройка к этому моменту уже разрушена
-- уроном, так что тайл уходит в лаву пустым.
local TILE_HEAT_MAX = 31

-- Клетка сетки теплообменников равна радиусу охлаждения: любая машина в радиусе
-- гарантированно попадает в свою клетку или в одну из восьми соседних.
local CELL = COOLING_RADIUS
-- Ключ клетки/тайла — одно целое число, чтобы не плодить строки в таблицах.
-- 2^18 и 2^21 заведомо больше возможных координат карты, а double хранит такие
-- произведения точно.
local CELL_STRIDE = 262144
local TILE_STRIDE = 2097152

local DAMAGE_FRACTION = PASS_TICKS / (60 * MELT_SECONDS)

-- Визуал: облака из graphics/clouds/orange (нагрев) и graphics/clouds/white
-- (охлаждение) — те же спрайты, что и у атмосферных облаков планеты. В каждой
-- папке 10 вариантов, лист 8×8 кадров по 128 px. Масштаб 0.5: кадр 128 px ->
-- 64 px = 2 тайла.
--
-- Оранжевое облако — нагрев, белое — охлаждение. Белое НЕ горит постоянно:
-- постройка должна сначала нагреться. У каждой постройки копится «жар»: пока её
-- не охлаждают, жар растёт (оранжевое облако); как только её накрыл
-- теплообменник — жар падает, и это показывает белое облако; на нуле эффект
-- пропадает совсем. Постройка, которую охлаждают с самого начала, не нагрета и
-- не рисует вообще ничего.
--
-- Эффект рисуется на КАЖДЫЙ тайл постройки, поэтому облака соседних тайлов
-- перекрываются. Чтобы это не превращалось в яркое пятно, цвет приглушён, а
-- альфа маленькая (0.15) — суммарно получается едва заметная дымка.
--
-- Оба эффекта рисуются НАД постройкой: слой "floor" лежит ниже построек
-- (порядок RenderLayer: ... above-tiles -> floor -> object -> higher-object-*),
-- и оранжевая дымка пряталась под самой машиной — видно было только то, что
-- вылезало по краям. Поэтому нагрев поднят до "higher-object-under" (выше
-- построек, но ниже охлаждения), а охлаждение — "higher-object-above".
--
-- Плавящиеся тайлы платформы получают такое же оранжевое облако (см.
-- melt_tiles): раньше нагревающиеся тайлы внешне ничем не отличались от целых.
--
-- Радиус охлаждения скрипт не рисует: это штатная визуализация движка
-- (radius_visualisation_specification в prototype/entity/sun-heat-exchanger.lua),
-- она появляется только когда игрок навёл курсор на машину или держит её
-- в курсоре, и стоит ноль, пока ничего не наведено.
local COOLING_ANIMS = {}
local MELTING_ANIMS = {}
-- Прототипы лежат в prototype/sun-cooling.lua: sun-cooling-cloud-01..10 и
-- sun-melting-cloud-01..10.
for i = 1, 10 do
  COOLING_ANIMS[i] = string.format("sun-cooling-cloud-%02d", i)
  MELTING_ANIMS[i] = string.format("sun-melting-cloud-%02d", i)
end
local EFFECT_SCALE = 0.35    -- 128 px * 0.35 ≈ 45 px ≈ 1.4 тайла
-- Тусклый серый цвет гасит и оранжевую, и белую текстуру, альфа 0.08 делает
-- дымку полупрозрачной. Белое «остывание» на ярких печах при 0.15 выглядело
-- слишком светлым, поэтому альфа снижена.
local EFFECT_TINT = {r = 0.6, g = 0.6, b = 0.6, a = 0.08}
local COOLING_LAYER = "higher-object-above"   -- над постройками
local MELTING_LAYER = "higher-object-under"   -- тоже над постройками, но ниже охлаждения
-- Прореживание анимации: 64 кадра при 0.8 кадра/тик — цикл примерно 80 тиков
-- (1.3 с), так облака не мельтешат, но и не тянутся слишком долго.
local ANIMATION_SPEED = 0.8
-- Потолок числа облаков на одну постройку. Для обычных 1x1..4x4 это ровно
-- «облако на каждый тайл», а у гигантских машин шаг по сетке растёт, чтобы не
-- наплодить сотни отрисовок.
local MAX_EFFECT_TILES = 16
-- Сколько построек за один проход может получить облака. После загрузки сейва
-- отрисовок нет, и создавать их разом для всего завода — заметный фриз; поэтому
-- первые проходы досоздают по нескольку построек, дальше бюджет не тратится
-- вовсе (облака уже есть).
local VISUAL_BUDGET = 16

-- Сколько проходов копится «жар» постройки. Постройка под охлаждением не
-- нагревается вовсе; нагретая остывает на 1 за проход, пока белый эффект
-- (охлаждение) не пропадёт.
local BUILDING_HEAT_MAX = 8

-- Облака над плавящимися тайлами платформы: страховочный потолок и сколько
-- можно создать за один проход. Плавится вся платформа вне зоны охлаждения,
-- то есть тайлов может быть много тысяч, и потолок 128/512 показывал эффект
-- лишь на случайной их части (выборка идёт по хэш-порядку pairs) — поэтому
-- «появлялись медленно». Потолок поднят так, чтобы накрыть всю реальную
-- платформу, а бюджет раскидывает создание по проходам, чтобы не вбить кадр.
local MAX_TILE_FX = 4096
local TILE_FX_BUDGET = 1024

-- Переиспользуемый запрос для find_entity: не создаём по таблице на каждую
-- сущность каждый проход.
local query = {x = 0, y = 0}

-- Тайлы, которые занимает постройка (центры тайлов). Считается один раз при
-- постройке/первом проходе и лежит в записи, чтобы не трогать bounding_box
-- каждый проход.
local function footprint_tiles(entity)
  local box = entity.bounding_box
  local x1 = math.floor(box.left_top.x)
  local y1 = math.floor(box.left_top.y)
  local x2 = math.ceil(box.right_bottom.x) - 1
  local y2 = math.ceil(box.right_bottom.y) - 1

  local step = 1
  while math.ceil((x2 - x1 + 1) / step) * math.ceil((y2 - y1 + 1) / step) > MAX_EFFECT_TILES do
    step = step + 1
  end

  local tiles = {}
  for y = y1, y2, step do
    for x = x1, x2, step do
      tiles[#tiles + 1] = {x = x + 0.5, y = y + 0.5}
    end
  end
  return tiles
end

-- Умножение двух 32-битных чисел, которое остаётся точным в double: результат
-- собирается из 16-битных половин (произведения не выходят за 2^48).
local function mul32(a, b)
  local lo = bit32.band(a, 0xffff)
  local hi = bit32.rshift(a, 16)
  return bit32.band(lo * b + bit32.lshift(bit32.band(hi * b, 0xffff), 16), 0xffffffff)
end

-- Детерминированный хэш по координатам: для одного и того же тайла всегда одно
-- значение, но у соседей оно хаотичное.
-- Что было не так раньше и почему теперь так:
--   (x * 3 + y * 7) % 10      — чисто линейно, диагональные полосы;
--   sin(x*a + y*b)            — плоская волна, полосы;
--   LCG ((h * k + c) % MOD)   — тоже линейно по x и y, полосы;
-- Всё это линейные функции координат, а любые линии уровня линейной функции —
-- это прямые, то есть тот самый «чёткий паттерн». Поэтому здесь 32-битный хэш
-- с лавиной (финализатор murmur3 fmix32): одно изменение бита входа меняет
-- примерно половину бит выхода, и никаких линий уровня не остаётся.
local function noise(x, y, salt)
  local h = bit32.bxor(
    mul32(math.floor(x * 2), 0x9e3779b1),
    mul32(math.floor(y * 2), 0x85ebca6b),
    mul32(salt, 0xc2b2ae35)
  )
  h = bit32.bxor(h, bit32.rshift(h, 16))
  h = mul32(h, 0x85ebca6b)
  h = bit32.bxor(h, bit32.rshift(h, 13))
  h = mul32(h, 0xc2b2ae35)
  h = bit32.bxor(h, bit32.rshift(h, 16))
  return h / 4294967296
end

-- Одно облако над тайлом. Общая функция для построек и для плавящихся тайлов
-- платформы.
local function draw_cloud(animation, position, surface, layer)
  -- Небольшой разброс размера и положения, чтобы сетка тайлов не читалась как
  -- ровные ряды одинаковых пятен.
  local size = EFFECT_SCALE * (0.8 + noise(position.x, position.y, 2) * 0.45)
  local jitter = 0.35
  return rendering.draw_animation{
    animation = animation,
    target = {
      x = position.x + (noise(position.x, position.y, 4) - 0.5) * jitter,
      y = position.y + (noise(position.x, position.y, 5) - 0.5) * jitter,
    },
    surface = surface,
    x_scale = size,
    y_scale = size,
    -- Случайный поворот на произвольный угол: одинаковые текстуры больше не
    -- читаются как ряд.
    orientation = noise(position.x, position.y, 6) * 6.283185307179586,
    animation_speed = ANIMATION_SPEED,
    -- Своё смещение кадра у каждого тайла, чтобы облака не пульсировали
    -- синхронно.
    animation_offset = math.floor(noise(position.x, position.y, 3) * 64),
    tint = EFFECT_TINT,
    render_layer = layer,
  }
end

-- Вариант облака для конкретной позиции: соседние тайлы берут разные текстуры,
-- но для одного и того же тайла вариант всегда один и тот же (переключение
-- режима не пересчитывается каждый проход).
local function animation_for(mode, x, y)
  local list = (mode == "cool") and COOLING_ANIMS or MELTING_ANIMS
  return list[math.floor(noise(x, y, 1) * #list) + 1]
end

local function layer_for(mode)
  return (mode == "cool") and COOLING_LAYER or MELTING_LAYER
end

-- Создаёт облака по одному на тайл. Вызывается один раз при входе в состояние
-- (и ещё раз после загрузки сейва, потому что отрисовки в сейв не попадают).
local function draw_building_clouds(building, surface, mode)
  local tiles = building.tiles
  local layer = layer_for(mode)
  local clouds = {}

  for i = 1, #tiles do
    local position = tiles[i]
    clouds[i] = draw_cloud(animation_for(mode, position.x, position.y), position, surface, layer)
  end

  building.clouds = clouds
end

local function destroy_building_clouds(building)
  local clouds = building.clouds
  if not clouds then
    return
  end
  for i = 1, #clouds do
    clouds[i].destroy()
  end
  building.clouds = nil
end

-- Поддерживает облака постройки в нужном состоянии:
--   mode = "melt" — греется (оранжевое);
--   mode = "cool" — остывает под охлаждением (белое);
--   mode = nil    — всё остыло, эффекта нет вовсе.
-- В обычном проходе, когда состояние не менялось, не делается ничего кроме
-- сравнения двух полей — ни создания объектов, ни пересчёта тайлов.
-- Возвращает остаток бюджета на создание новых облаков в этом проходе.
local function update_building_clouds(building, entity, surface, mode, budget)
  if not building.tiles then
    -- Запись из старого сейва: тайлов ещё нет.
    building.tiles = footprint_tiles(entity)
  end

  local clouds = building.clouds
  if clouds and (not clouds[1] or not clouds[1].valid) then
    -- После загрузки сейва отрисовки пропадают — создаём заново.
    building.clouds = nil
    clouds = nil
  end

  if not mode then
    -- Постройка остыла: белое облако больше не нужно.
    if clouds then
      destroy_building_clouds(building)
    end
    building.mode = nil
    return budget
  end

  if not clouds then
    if budget <= 0 then
      -- Бюджет прохода кончился: эту постройку доделаем в следующий раз.
      return 0
    end
    draw_building_clouds(building, surface, mode)
    building.mode = mode
    return budget - 1
  end

  if building.mode ~= mode then
    local layer = layer_for(mode)
    local tiles = building.tiles
    for i = 1, #clouds do
      local position = tiles[i]
      local cloud = clouds[i]
      cloud.animation = animation_for(mode, position.x, position.y)
      cloud.render_layer = layer
    end
    building.mode = mode
  end

  return budget
end

-- Версия структуры storage. Растёт при каждом изменении полей, чтобы старые
-- сейвы (например, с трубным охлаждением) не падали на отсутствующем поле.
local STATE_VERSION = 5

local function get_state()
  local st = storage.sun_cooling
  if not st then
    st = {}
    storage.sun_cooling = st
  end

  if st.version ~= STATE_VERSION then
    -- Сейв от старой версии мода: полей может не быть вовсе (именно из-за этого
    -- падало «get length of field 'exchangers'»). Досоздаём недостающее.
    st.version = STATE_VERSION
    -- все постройки с здоровьем: и теплообменники, и трубы, и всё остальное
    st.buildings = st.buildings or {}
    -- name:x:y -> запись (чтобы не регистрировать дважды)
    st.by_key = st.by_key or {}
    -- ключ позиции -> {x, y, heat}
    st.tiles = st.tiles or {}
    st.pass = st.pass or 0
    -- Радиус по наведению больше не рисуется скриптом (его рисует движок),
    -- поэтому старые записи отрисовок просто выбрасываем.
    st.overlays = nil

    -- Список теплообменников строится заново из общего реестра построек: старый
    -- список труб (если он был) больше не нужен — трубы не охлаждают.
    st.exchangers = {}
    st.pipes = nil
    for i = 1, #st.buildings do
      local building = st.buildings[i]
      if building and building.name == EXCHANGER then
        st.exchangers[#st.exchangers + 1] = building
      end
    end
  end

  return st
end

-----------------------------------------------------------------------------
-- Регистрация
-----------------------------------------------------------------------------

local function register_entity(entity)
  if not entity or not entity.valid then
    return
  end
  if entity.surface.name ~= SUN_SURFACE then
    return
  end
  -- Призраки и прочие сущности без здоровья плавить нечего.
  if not entity.health then
    return
  end

  local position = entity.position
  local key = entity.name .. ":" .. position.x .. ":" .. position.y

  local st = get_state()
  if st.by_key[key] then
    return
  end

  local entry = {key = key, name = entity.name, x = position.x, y = position.y,
    -- Тайлы постройки считаем сразу: облако на каждый тайл (см. визуал выше).
    tiles = footprint_tiles(entity)}
  st.by_key[key] = entry
  st.buildings[#st.buildings + 1] = entry

  -- Теплообменник — тоже постройка (без воды он плавится как всё остальное),
  -- но дополнительно он охлаждает соседей. Облако над ним появится в проходе.
  if entity.name == EXCHANGER then
    st.exchangers[#st.exchangers + 1] = entry
  end
end

local function register_tile(st, x, y)
  local key = x * TILE_STRIDE + y
  if not st.tiles[key] then
    st.tiles[key] = {x = x, y = y, heat = 0}
  end
end

local function register_tiles(surface_index, positions, tile_name)
  if tile_name ~= PLATFORM_TILE then
    return
  end
  local surface = game.surfaces[surface_index]
  if not surface or surface.name ~= SUN_SURFACE then
    return
  end

  local st = get_state()
  for i = 1, #positions do
    local position = positions[i].position
    register_tile(st, position.x, position.y)
  end
end

local function on_entity_built(event)
  register_entity(event.entity)
end

script.on_event({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
}, on_entity_built)

script.on_event(defines.events.on_entity_cloned, function(event)
  register_entity(event.destination)
end)

local function on_built_tile(event)
  register_tiles(event.surface_index, event.tiles, event.tile and event.tile.name)
end

script.on_event({
  defines.events.on_player_built_tile,
  defines.events.on_robot_built_tile,
}, on_built_tile)

-- Тайлы, поставленные скриптом (другие моды, редактор): у них имя лежит в
-- каждой записи, а не в event.tile.
script.on_event(defines.events.script_raised_set_tiles, function(event)
  local surface = game.surfaces[event.surface_index]
  if not surface or surface.name ~= SUN_SURFACE then
    return
  end

  local st = get_state()
  local tiles = event.tiles
  for i = 1, #tiles do
    local tile = tiles[i]
    if tile.name == PLATFORM_TILE then
      local position = tile.position
      register_tile(st, position.x, position.y)
    end
  end
end)

-----------------------------------------------------------------------------
-- Проход
-----------------------------------------------------------------------------

-- Собирает работающие (то есть с водой) теплообменники в сетку.
local function build_cooling_grid(st, surface)
  local grid = {}
  local exchangers = st.exchangers

  for i = #exchangers, 1, -1 do
    local exchanger = exchangers[i]
    query.x = exchanger.x
    query.y = exchanger.y
    local entity = surface.find_entity(exchanger.name, query)

    if not entity or not entity.valid then
      exchangers[i] = exchangers[#exchangers]
      exchangers[#exchangers] = nil
    elseif entity.status == defines.entity_status.working then
      -- «Работает» = в машине есть вода и она её тратит. Сухая машина
      -- не охлаждает даже сама себя.
      local key = math.floor(exchanger.x / CELL) * CELL_STRIDE + math.floor(exchanger.y / CELL)
      local cell = grid[key]
      if not cell then
        cell = {}
        grid[key] = cell
      end
      cell[#cell + 1] = exchanger
    end
  end

  return grid
end

local function is_cooled(grid, x, y)
  -- Стартовую площадку ядро охлаждает всегда: ни воды, ни электричества ему не
  -- нужно, поэтому проверка стоит первой и дешевле всего (два умножения).
  if x * x + y * y <= CORE_RADIUS_SQ then
    return true
  end

  local cx = math.floor(x / CELL)
  local cy = math.floor(y / CELL)

  for dx = -1, 1 do
    for dy = -1, 1 do
      local cell = grid[(cx + dx) * CELL_STRIDE + (cy + dy)]
      if cell then
        for i = 1, #cell do
          local exchanger = cell[i]
          local ddx = exchanger.x - x
          local ddy = exchanger.y - y
          if ddx * ddx + ddy * ddy <= COOLING_RADIUS_SQ then
            return true
          end
        end
      end
    end
  end

  return false
end

local function damage_buildings(st, grid, surface)
  local buildings = st.buildings
  local budget = VISUAL_BUDGET

  for i = #buildings, 1, -1 do
    local building = buildings[i]
    query.x = building.x
    query.y = building.y
    local entity = surface.find_entity(building.name, query)
    local max_health = entity and entity.valid and entity.max_health

    if not max_health then
      destroy_building_clouds(building)
      st.by_key[building.key] = nil
      buildings[i] = buildings[#buildings]
      buildings[#buildings] = nil
    else
      local cooled = is_cooled(grid, building.x, building.y)
      local heat = building.heat or 0
      local mode

      if cooled then
        if heat > 0 then
          -- Постройка остывает: показываем белое облако, пока жар не ушёл.
          mode = "cool"
          heat = heat - 1
          if heat < 0 then
            heat = 0
          end
        end
        -- heat == 0 и охлаждена — эффекта нет вообще (не «горит» постоянно).
      else
        heat = heat + 1
        if heat > BUILDING_HEAT_MAX then
          heat = BUILDING_HEAT_MAX
        end
        mode = "melt"
        if max_health > 0 then
          entity.damage(max_health * DAMAGE_FRACTION, "neutral", "sun-heat")
        end
      end

      building.heat = heat
      -- Оранжевую/белую дымку по тайлам меняем только при смене состояния.
      budget = update_building_clouds(building, entity, surface, mode, budget)
    end
  end
end

-- Радиус охлаждения рисует движок (radius_visualisation_specification у
-- sun-heat-exchanger): он сам показывает его по наведению и убирает, когда
-- курсор ушёл. Скрипту здесь делать нечего — ни отрисовок, ни событий.

-- Убирает облако нагрева над тайлом (если оно было).
local function destroy_tile_fx(tile)
  local fx = tile.fx
  if fx then
    if fx.valid then
      fx.destroy()
    end
    tile.fx = nil
  end
end

local function melt_tiles(st, grid, surface)
  local tiles = st.tiles
  local melted

  for key, tile in pairs(tiles) do
    local show_heat = true

    if surface.get_tile(tile.x, tile.y).name ~= PLATFORM_TILE then
      -- Тайл уже не платформа (снесли, заменили): сторожить нечего.
      tiles[key] = nil
      show_heat = false
    elseif is_cooled(grid, tile.x + 0.5, tile.y + 0.5) then
      tile.heat = 0
      show_heat = false
    else
      tile.heat = tile.heat + 1
      if tile.heat >= TILE_HEAT_MAX then
        tiles[key] = nil
        melted = melted or {}
        melted[#melted + 1] = {name = LAVA_TILE, position = {tile.x, tile.y}}
        show_heat = false
      end
    end

    if tile.fx and not show_heat then
      -- Тайл остыл или расплавился: подсветка больше не нужна.
      destroy_tile_fx(tile)
    end
  end

  if melted then
    -- Один вызов на все расплавившиеся тайлы: движок сам уберёт то, что на них
    -- стояло (постройка к этому моменту уже разрушена уроном).
    surface.set_tiles(melted)
  end
end

-- Досоздаёт подсветку над плавящимися тайлами. Вызывается КАЖДЫЙ проход (а
-- плавление/heat считаются раз в TILE_CHECK_EVERY проходов), чтобы облака
-- появлялись сразу, а не порциями. Потолок MAX_TILE_FX и бюджет
-- TILE_FX_BUDGET на проход не дают огромной плите создать всё разом в один тик.
local function update_tile_fx(st, surface)
  local tiles = st.tiles
  local fx_count = 0

  for _, tile in pairs(tiles) do
    local fx = tile.fx
    if fx then
      if fx.valid then
        fx_count = fx_count + 1
      else
        -- Отрисовки не переживают загрузку сейва: старый хэндл протух.
        tile.fx = nil
      end
    end
  end

  if fx_count >= MAX_TILE_FX then
    return
  end

  local budget = TILE_FX_BUDGET
  for _, tile in pairs(tiles) do
    if budget <= 0 or fx_count >= MAX_TILE_FX then
      break
    end
    if not tile.fx and tile.heat > 0 then
      local position = {x = tile.x + 0.5, y = tile.y + 0.5}
      tile.fx = draw_cloud(animation_for("melt", position.x, position.y),
        position, surface, MELTING_LAYER)
      fx_count = fx_count + 1
      budget = budget - 1
    end
  end
end

--------------------------------------------------------------------------------
-- Внутренний теплообменник (ядро стартовой площадки)
--------------------------------------------------------------------------------

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

  local surface = game.surfaces[SUN_SURFACE]
  if not surface then
    return
  end

  -- Ядро должно существовать всегда: ставим/поправляем его до всех проверок —
  -- площадка может быть и пустой, а стартовая зона охлаждается всё равно.
  sync_core(st)

  if #st.buildings == 0 and next(st.tiles) == nil then
    return
  end

  local grid = build_cooling_grid(st, surface)
  damage_buildings(st, grid, surface)
  st.pass = st.pass + 1
  if st.pass >= TILE_CHECK_EVERY then
    st.pass = 0
    melt_tiles(st, grid, surface)
  end
  -- Подсветку досоздаём каждый проход: тогда она не «догоняет» плавление.
  update_tile_fx(st, surface)
end)
