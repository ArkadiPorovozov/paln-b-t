-- Стройплощадка asm45_corp: ассемблер с фиксированным рецептом.
--
-- Всё, что касается входа, задано в данных (prototype/entity/asm45-corp-site.lua):
-- рецепт "asm45-corp-site-build" требует по 1 единице каждого ресурса, ничего не
-- производит и идёт 2 секунды.
--
-- На скрипте четыре вещи:
--   * надпись «10 / сколько уже сделано» над площадкой;
--   * каркасы: на первой скрафченной партии они поднимаются и стоят до конца
--     постройки, при превращении в готовый завод — сворачиваются;
--   * искры сварки, пока площадка реально крафтит;
--   * после 10 отработанных партий заменить площадку на assembling-machine-45-corp,
--     а всё, что осталось в машине сверх этих партий, сжечь.
--
-- Каркасы рисуются так же, как в script/carkas.lua (см. platform_anim): на каждый
-- тайл площадки — пара штатных mb-panim-* (верх и тело). Подъём и сворачивание —
-- это mb-panim-* с нужным animation_offset и временем жизни; «стоящий» каркас —
-- отдельный одномоментный прототип asm45-scaffold-* из того же кадра (сам
-- animation_speed анимацию не останавливает).
--
-- Состояние нигде у себя не храним:
--   * что завезено — инвентарь самой площадки;
--   * сколько партий сделано — products_finished;
--   * сколько идёт крафт — is_crafting();
--   * надпись — render object, привязанный к Thing (Things сам убирает его,
--     когда площадка исчезает).
--
-- В скрипте нет ни одного глобального имени — только local.

local THINGS    = "things"
local THINGS_RO = "things-render-object-v1"

local SITE   = "asm45-corp-site"
local RESULT = "assembling-machine-45-corp"

local IN  = defines.inventory.crafter_input
local OUT = defines.inventory.crafter_output

local RO_KEY    = "asm45-progress"
local FRAME_KEY = "asm45-frame-"

-- Сколько раз рецепт должен отработать.
local CRAFTS = 10

-- Вспышка искр сварки (штатное «искровое» взрыв-эффект-энтити базы).
-- Сами искры — частицы: создаются один раз и живут своей жизнью.
local SPARK = "spark-explosion-higher"

-- Каркасы: те же анимации, что и у MultiBuild (script/carkas.lua) —
-- "mb-panim-<угол>-<слой>", по одному углу на тайл. Стоящий каркас — отдельный
-- прототип "asm45-scaffold-<угол>-<слой>" из одного кадра (см. data-final-fixes.lua).
local ANIM_PREFIX  = "mb-panim-"
local STAND_PREFIX = "asm45-scaffold-"
local FRAME_COUNT  = 32   -- кадров в листе каркаса
local TICKS_PER_FRAME = 2 -- столько тиков идёт один кадр
local PAUSE_FRAME  = 15   -- на этом кадре каркас стоит, пока идёт постройка
local FOLD_FRAME   = 16   -- с этого кадра начинается сворачивание

-- time_to_live у render object — это тики, а не секунды.
local RAISE_TTL = PAUSE_FRAME * TICKS_PER_FRAME
local FOLD_TTL  = (FRAME_COUNT - FOLD_FRAME) * TICKS_PER_FRAME

-- Площадки и их каркасы. Список площадок обновляется раз в секунду, каркасы
-- живут по unit_number площадки.
local sites = {}
local scaffolds = {}
-- Какая цифра уже висит над площадкой: надпись перерисовываем только когда
-- число отработанных партий меняется.
local labels = {}

local function each_site(callback)
  for _, site in pairs(sites) do
    if site.valid then
      callback(site)
    end
    -- найдём заново при следующем обновлении списка
  end
end

-- Площадка должна быть Thing: тогда работают «самоубирающиеся» надписи
-- и каркас умирает вместе с ней.
local function ensure_thing(entity)
  local _, id = remote.call(THINGS, "get_thing_id", entity)
  if id then return true end
  local _, summary = remote.call(THINGS, "create_thing", {entity = entity})
  return summary ~= nil
end

-- Надпись над площадкой: «10 / 1» — сколько всего партий и сколько уже сделано.
-- Привязана к Thing, поэтому вручную её не удаляем: Things уничтожит её вместе
-- с площадкой.
local function show_label(entity, text)
  local ok, object = pcall(rendering.draw_text,
  {
    text = text,
    surface = entity.surface,
    target = entity,
    target_offset = {0, -4.6},
    color = {1, 1, 1},
    alignment = "center",
    scale = 0.9,
    scale_with_zoom = false
  })
  if not ok or not object then return end

  local err = remote.call(THINGS_RO, "attach_render_object", entity, RO_KEY, object)
  if err then
    object.destroy()
  end
end

-- ===== каркасы =====

-- Тайлы, которые занимает площадка, — по её selection_box (4x4).
local SITE_BOX = (function()
  local proto = prototypes.entity[SITE]
  local box = proto and proto.selection_box
  local left_top, right_bottom = box and (box.left_top or box[1]), box and (box.right_bottom or box[2])
  if not left_top or not right_bottom then return nil end

  local x1, y1 = left_top.x or left_top[1], left_top.y or left_top[2]
  local x2, y2 = right_bottom.x or right_bottom[1], right_bottom.y or right_bottom[2]
  return {left = x1, top = y1, width = x2 - x1, height = y2 - y1}
end)()

local function site_tiles(site)
  local tiles = {}
  if not SITE_BOX then return tiles end

  local left = math.floor(site.position.x + SITE_BOX.left)
  local top  = math.floor(site.position.y + SITE_BOX.top)
  for y = top, top + SITE_BOX.height - 1 do
    for x = left, left + SITE_BOX.width - 1 do
      tiles[#tiles + 1] = {x = x + 0.5, y = y + 0.5}
    end
  end

  return tiles
end

-- Какая угловая часть каркаса стоит на тайле (как в platform_anim).
local function tile_piece(position, center)
  if position.x > center.x then
    return position.y < center.y and "back_right" or "front_right"
  end
  return position.y < center.y and "back_left" or "front_left"
end

-- Каркас на всех тайлах площадки. prefix — какой прототип рисовать
-- ("mb-panim-" для подъёма и сворачивания, "asm45-scaffold-" для стоящего).
-- attached = true — объекты привязываются к Thing и исчезают вместе с площадкой.
local function draw_scaffold(site, prefix, offset, speed, ttl, attached)
  local center = site.position
  local objects = {}

  for _, tile in ipairs(site_tiles(site)) do
    local piece = tile_piece(tile, center)
    local back = piece == "back_left" or piece == "back_right"

    local layers =
    {
      {"top",  "higher-object-above"},
      {"body", back and "lower-object-above-shadow" or "object"}
    }

    for _, layer in ipairs(layers) do
      local ok, object = pcall(rendering.draw_animation,
      {
        animation = prefix .. piece .. "-" .. layer[1],
        surface = site.surface,
        target = tile,
        animation_offset = offset,
        animation_speed = speed,
        render_layer = layer[2],
        time_to_live = ttl
      })
      if not ok then
        log("[asm45] frame " .. prefix .. piece .. "-" .. layer[1] .. ": " .. tostring(object))
      elseif object then
        if attached then
          local err = remote.call(THINGS_RO, "attach_render_object", site,
            FRAME_KEY .. prefix .. layer[1] .. "-" .. tile.x .. "-" .. tile.y, object)
          if err then
            object.destroy()
            object = nil
          end
        end
        if object then
          objects[#objects + 1] = object
        end
      end
    end
  end

  return objects
end

-- Подъём: 15 кадров, дальше объекты заканчиваются сами (time_to_live — в тиках),
-- а на их месте появляется стоящий каркас.
local function raise_scaffold(site)
  local offset = -(game.tick * 0.5) % FRAME_COUNT
  draw_scaffold(site, ANIM_PREFIX, offset, 1, RAISE_TTL, true)
  scaffolds[site.unit_number] =
  {
    site = site,
    state = "raising",
    pause_at = game.tick + RAISE_TTL
  }
end

-- Каркас стоит: в прототипе один кадр, проигрывать нечего.
local function stand_scaffold(site)
  draw_scaffold(site, STAND_PREFIX, 0, 0, nil, true)
end

-- Сворачивание: кадры 16..32, объекты живут ровно столько, сколько идёт
-- сворачивание, и исчезают уже без площадки — на её месте стоит завод.
local function fold_scaffold(site)
  local offset = -(game.tick * 0.5) % FRAME_COUNT + FOLD_FRAME
  draw_scaffold(site, ANIM_PREFIX, offset, 1, FOLD_TTL, false)
end

-- ===== превращение в готовый завод =====

-- Площадка построена: убираем её и ставим готовый ассемблер.
-- Всё, что осталось во входе сверх 10 партий, сгорает — на землю ничего не падает.
local function finish(site)
  local surface  = site.surface
  local position = site.position
  local force    = site.force

  local burned = 0

  local input = site.get_inventory(IN)
  if input then
    for index = 1, #input do
      local stack = input[index]
      if stack.valid_for_read then
        burned = burned + stack.count
        stack.clear()
      end
    end
  end

  local output = site.get_inventory(OUT)
  if output then
    for index = 1, #output do
      local stack = output[index]
      if stack.valid_for_read then
        stack.clear()
      end
    end
  end

  -- каркас сворачивается, пока площадка уступает место готовому заводу
  scaffolds[site.unit_number] = nil
  fold_scaffold(site)

  site.destroy()

  local built = surface.create_entity
  {
    name = RESULT,
    position = position,
    force = force,
    raise_built = true
  }

  if not built then return end

  if burned > 0 then
    pcall(force.print, force, {"other.asm45-site-burned"})
  end

  pcall(force.print, force, {"other.asm45-site-done"})
end

-- ===== поиск площадок =====

-- Площадки ищем раз в секунду и запоминаем: дальше по тикам бегаем только по
-- своему списку и не трогаем find_entities_filtered на каждой проверке.
local function refresh_sites()
  local found = {}
  for _, surface in pairs(game.surfaces) do
    for _, site in pairs(surface.find_entities_filtered({name = SITE})) do
      if site.valid then
        found[site.unit_number] = site
      end
    end
  end
  sites = found

  -- площадку убрали раньше срока — её каркас привязан к Thing и умирает сам,
  -- так что достаточно забыть запись
  for unit_number in pairs(scaffolds) do
    if not found[unit_number] then
      scaffolds[unit_number] = nil
    end
  end

  for unit_number in pairs(labels) do
    if not found[unit_number] then
      labels[unit_number] = nil
    end
  end
end

script.on_nth_tick(60, refresh_sites)

-- Подъём доиграл — ставим на его место стоящий каркас (один кадр).
script.on_nth_tick(2, function()
  for unit_number, state in pairs(scaffolds) do
    if state.state == "raising" and game.tick >= state.pause_at then
      if state.site and state.site.valid then
        state.state = "standing"
        state.pause_at = nil
        stand_scaffold(state.site)
      else
        scaffolds[unit_number] = nil
      end
    end
  end
end)

-- Раз в 15 тиков: надпись, каркасы и проверка готовности площадки.
-- Важно: внутри одного мода на каждый интервал может быть только один
-- обработчик — эта регистрация затирает любой другой on_nth_tick(15).
-- Поэтому турбины (script/ssc-turbine.lua) обновляются на тике 30.
script.on_nth_tick(15, function()
  each_site(function(site)
    local produced = site.products_finished or 0

    if produced >= CRAFTS then
      labels[site.unit_number] = nil
      finish(site)
      return
    end

    if produced < 1 then
      -- искры сварки идут с первой же партии, ещё до появления надписи
    else
      -- Надпись перерисовываем только когда цифра поменялась.
      if labels[site.unit_number] ~= produced and ensure_thing(site) then
        show_label(site, CRAFTS .. " / " .. produced)
        labels[site.unit_number] = produced
      end

      -- Первая скрафченная партия — каркасы поднимаются и дальше стоят.
      if not scaffolds[site.unit_number] and ensure_thing(site) then
        raise_scaffold(site)
      end
    end

    -- Искры сварки, пока площадка реально крафтит. Частицы живут сами,
    -- поэтому, когда крафт встал, новые просто не появляются.
    if site.is_crafting() then
      site.surface.create_entity
      {
        name = SPARK,
        position =
        {
          site.position.x + (math.random() * 2 - 1) * 1.5,
          site.position.y + (math.random() * 2.6 - 1.6)
        },
        force = site.force
      }
    end
  end)
end)
