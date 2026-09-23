-- MultiBuild: универсальный каркас 1x1 + кастомное меню с 1 слотом инвентаря
-- + платформенная анимация космической платформы
-- + зелёный фрейм-сундук запроса для дронов (без зоны/радиуса, оплата впритык или из фрейма)
-- + возможность класть предметы во фрейм (лимит 1 шт.), постройка только при наличии предмета,
-- + если предмета нет — постройка ставится в очередь (план) с иконкой, а фреймы остаются на месте!
-- + логистические запросы для дронов при планировке (в зелёный сундук и/или прямо в каркас!)
-- + компактное прозрачное меню (только 1 слот для предмета, без громоздкого инвентаря)
-- + невидимые сущности плана mb-plan-* с нативным выделением игры (без Lua-рендера!)
-- + план автоматически ставит под собой призраки каркаса (ghost mb-frame)
-- + нативное копирование (Ctrl+C), чертежи, пипетка (Q) и Shift-клик для зданий впритык

local shared = (pcall(require, "shared") and require("shared")) or require("script/shared")
local platform_anim = (pcall(require, "platform_anim") and require("platform_anim")) or require("script/platform_anim")

local FRAME = shared.FRAME_NAME
local STORAGE = shared.STORAGE_NAME
local SELECTOR = shared.SELECTOR_NAME
local COST_FROM_INVENTORY = shared.COST_FROM_INVENTORY
local POLL_TICKS = shared.PENDING_POLL_TICKS or 10

-- ===== кэш размеров целевых зданий =====
local sizes_cache
local function target_sizes()
  if sizes_cache then return sizes_cache end
  sizes_cache = {}
  for _, name in ipairs(shared.TARGETS) do
    local proto = prototypes.entity[name]
    local box = (proto and proto.selection_box) or (proto and proto.collision_box)
    local w, h
    if box then
      local lt = box.left_top or box[1]
      local rb = box.right_bottom or box[2]
      if lt and rb then
        local x1, y1 = (lt.x or lt[1]), (lt.y or lt[2])
        local x2, y2 = (rb.x or rb[1]), (rb.y or rb[2])
        w = math.floor(x2 - x1 + 0.5)
        h = math.floor(y2 - y1 + 0.5)
      end
    end
    if w and w > 0 and h and h > 0 then
      sizes_cache[name] = {w = w, h = h, area = w * h}
    else
      log("multibuild: прототип '" .. name .. "' не найден, пропущен")
    end
  end
  return sizes_cache
end

-- ===== утилиты =====
local function tile_key(x, y) return x .. ":" .. y end

local function is_east_west(dir)
  if not dir then return false end
  return (dir == defines.direction.east or dir == defines.direction.west
       or dir == 4 or dir == 12 or dir == 2 or dir == 6)
end

local function get_entity_recipe(ent, event_tags)
  if not (ent and ent.valid) then return nil end
  local recipe = nil
  pcall(function()
    if ent.get_recipe then
      local r = ent.get_recipe()
      if r then
        recipe = (type(r) == "table" and r.name) or (type(r) == "string" and r) or r.name
      end
    end
  end)
  if not recipe and event_tags and event_tags.mb_recipe then
    recipe = event_tags.mb_recipe
  end
  return recipe
end

local function clear_selection(player)
  if storage.sel and player then
    storage.sel[player.index] = nil
  end
end

local function ftext(surface, position, text, color)
  if not storage.debug_enabled then return end
  for _, player in pairs(game.connected_players) do
    if player.surface == surface then
      player.create_local_flying_text{
        position = position,
        text = text,
        color = color or {r = 1, g = 0.85, b = 0.3},
      }
    end
  end
end

local function flash_light(surface, position, radius, intensity, ttl)
  pcall(rendering.draw_light, {
    sprite = "utility/light_medium",
    target = position,
    surface = surface,
    scale = radius,
    intensity = intensity,
    color = {r = 0.35, g = 0.8, b = 1},
    time_to_live = ttl,
    minimum_darkness = 0.2,
  })
end

local function rects_overlap(a, b)
  return a.minx < b.minx + b.w and b.minx < a.minx + a.w
     and a.miny < b.miny + b.h and b.miny < a.miny + a.h
end

local function same_rect(a, b)
  return a.minx == b.minx and a.miny == b.miny and a.w == b.w and a.h == b.h
end

-- ===== проверка очереди планов =====
local function find_pending_for_rect(surface, rect)
  for i, p in ipairs(storage.pendings or {}) do
    if p.surface == surface and same_rect(p.rect, rect) then
      return p, i
    end
  end
  return nil
end

local function find_pending_at(surface, tx, ty)
  for i, p in ipairs(storage.pendings or {}) do
    if p.surface == surface and tx >= p.rect.minx and tx < p.rect.minx + p.rect.w
       and ty >= p.rect.miny and ty < p.rect.miny + p.rect.h then
      return p, i
    end
  end
  return nil
end

local function is_frame_in_active_job(surface, tx, ty)
  for _, j in ipairs(storage.jobs or {}) do
    if j.surface == surface and j.rect then
      if tx >= j.rect.minx and tx < j.rect.minx + j.rect.w
         and ty >= j.rect.miny and ty < j.rect.miny + j.rect.h then
        return true
      end
    end
  end
  return false
end

-- ===== УПРАВЛЕНИЕ ЗАПРОСАМИ ДРОНОВ (Factorio 2.0+ Logistic Sections & Point) =====
local function set_entity_request(entity, item_name, count)
  if not (entity and entity.valid) then return end
  count = count or 1

  local set_done = false
  -- 1) Factorio 2.0/2.1: entity.get_logistic_sections()
  pcall(function()
    local sections = entity.get_logistic_sections and entity.get_logistic_sections()
    if sections then
      local sec = nil
      if sections.sections_count and sections.sections_count > 0 then
        sec = sections.get_section(1)
      end
      if not sec then
        sec = sections.add_section()
      end
      if sec then
        local filters = {
          {value = {type = "item", name = item_name, quality = "normal"}, min = count, max = count},
          {value = {name = item_name, quality = "normal"}, min = count, max = count},
          {value = {type = "item", name = item_name}, min = count, max = count},
          {value = item_name, min = count, max = count},
          {value = {type = "item", name = item_name, quality = "normal"}, min = count},
          {value = item_name, min = count},
        }
        for _, flt in ipairs(filters) do
          local ok = pcall(sec.set_slot, 1, flt)
          if ok then
            set_done = true
            break
          end
        end
      end
    end
  end)

  if set_done then return end

  -- 2) Factorio 2.0/2.1: entity.get_requester_point()
  pcall(function()
    local pt = entity.get_requester_point and entity.get_requester_point()
    if pt then
      local sec = nil
      if pt.sections_count and pt.sections_count > 0 then
        sec = pt.get_section(1)
      end
      if not sec then
        sec = pt.add_section()
      end
      if sec then
        local filters = {
          {value = {type = "item", name = item_name, quality = "normal"}, min = count, max = count},
          {value = {name = item_name, quality = "normal"}, min = count, max = count},
          {value = {type = "item", name = item_name}, min = count, max = count},
          {value = item_name, min = count, max = count},
          {value = item_name, min = count},
        }
        for _, flt in ipairs(filters) do
          local ok = pcall(sec.set_slot, 1, flt)
          if ok then
            set_done = true
            break
          end
        end
      end
    end
  end)

  if set_done then return end

  -- 3) Legacy Factorio (1.1 и обратная совместимость)
  pcall(function()
    if entity.set_request_slot then
      entity.set_request_slot({name = item_name, count = count}, 1)
    end
  end)
end

local function clear_entity_request(entity)
  if not (entity and entity.valid) then return end

  pcall(function()
    local sections = entity.get_logistic_sections and entity.get_logistic_sections()
    if sections and sections.sections_count and sections.sections_count > 0 then
      local sec = sections.get_section(1)
      if sec then
        pcall(sec.clear_slot, 1)
      end
    end
  end)

  pcall(function()
    local pt = entity.get_requester_point and entity.get_requester_point()
    if pt and pt.sections_count and pt.sections_count > 0 then
      local sec = pt.get_section(1)
      if sec then
        pcall(sec.clear_slot, 1)
      end
    end
  end)

  pcall(function()
    if entity.clear_request_slot then
      entity.clear_request_slot(1)
    end
  end)
end

local function get_touching_storages(surface, rect)
  local search_area = {
    {rect.minx - 1.5, rect.miny - 1.5},
    {rect.minx + rect.w + 0.5, rect.miny + rect.h + 0.5},
  }
  local list = {}
  for _, e in ipairs(surface.find_entities_filtered{name = STORAGE, area = search_area}) do
    local stx = math.floor(e.position.x)
    local sty = math.floor(e.position.y)
    if stx >= rect.minx - 1 and stx <= rect.minx + rect.w
       and sty >= rect.miny - 1 and sty <= rect.miny + rect.h then
      list[#list + 1] = e
    end
  end
  return list
end

local function update_pending_requests(surface, rect, target)
  if not (surface and surface.valid and rect and target) then return end

  -- Прилегающие зелёные сундуки
  local storages = get_touching_storages(surface, rect)
  for _, st in ipairs(storages) do
    set_entity_request(st, target, 1)
  end

  -- Центральный (или первый) фрейм постройки
  local cx = math.floor(rect.minx + rect.w / 2)
  local cy = math.floor(rect.miny + rect.h / 2)
  local target_frame = surface.find_entity(FRAME, {cx + 0.5, cy + 0.5})
  if not target_frame then
    for x = rect.minx, rect.minx + rect.w - 1 do
      for y = rect.miny, rect.miny + rect.h - 1 do
        local f = surface.find_entity(FRAME, {x + 0.5, y + 0.5})
        if f then
          target_frame = f
          break
        end
      end
      if target_frame then break end
    end
  end

  if target_frame then
    set_entity_request(target_frame, target, 1)
  end
end

local function clear_pending_requests(surface, rect)
  if not (surface and surface.valid and rect) then return end

  for _, st in ipairs(get_touching_storages(surface, rect)) do
    clear_entity_request(st)
  end

  for x = rect.minx, rect.minx + rect.w - 1 do
    for y = rect.miny, rect.miny + rect.h - 1 do
      local f = surface.find_entity(FRAME, {x + 0.5, y + 0.5})
      if f then
        clear_entity_request(f)
      end
    end
  end
end

-- ===== скан кластера блоков каркаса =====
-- Фреймы, уже занятые ДРУГИМ активным планом (pending) или стройкой (job),
-- исключаются из сканирования. Это позволяет зданиям стоять ВПРИТЫК друг к другу!
local function cluster_info(surface, tx, ty)
  local target_plan = find_pending_at(surface, tx, ty)

  local nearby = surface.find_entities_filtered{
    name = FRAME,
    position = {tx + 0.5, ty + 0.5},
    radius = 16,
  }
  if #nearby == 0 then return nil end

  local tiles, entities = {}, {}
  for _, e in pairs(nearby) do
    local ex, ey = math.floor(e.position.x), math.floor(e.position.y)
    local p = find_pending_at(surface, ex, ey)
    local is_other_plan = p and (p ~= target_plan)
    local is_in_job = is_frame_in_active_job(surface, ex, ey)

    if not is_other_plan and not is_in_job then
      tiles[tile_key(ex, ey)] = true
      entities[tile_key(ex, ey)] = e
    end
  end

  if not tiles[tile_key(tx, ty)] then
    return nil
  end

  local cluster, seen, stack = {}, {}, {tile_key(tx, ty)}
  while #stack > 0 do
    local k = table.remove(stack)
    if tiles[k] and not seen[k] then
      seen[k] = true
      local xs, ys = string.match(k, "^(-?%d+):(-?%d+)$")
      local x, y = tonumber(xs), tonumber(ys)
      cluster[#cluster + 1] = {tx = x, ty = y}
      stack[#stack + 1] = tile_key(x + 1, y)
      stack[#stack + 1] = tile_key(x - 1, y)
      stack[#stack + 1] = tile_key(x, y + 1)
      stack[#stack + 1] = tile_key(x, y - 1)
    end
  end

  local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
  for _, t in ipairs(cluster) do
    if t.tx < minx then minx = t.tx end
    if t.ty < miny then miny = t.ty end
    if t.tx > maxx then maxx = t.tx end
    if t.ty > maxy then maxy = t.ty end
  end
  local w, h = maxx - minx + 1, maxy - miny + 1
  local complete = (w * h == #cluster)

  local candidates = {}
  if complete then
    for name, s in pairs(target_sizes()) do
      if (s.w == w and s.h == h) or (s.w == h and s.h == w) then
        candidates[#candidates + 1] = name
      end
    end
    table.sort(candidates)
  end

  return {
    count = #cluster, w = w, h = h,
    minx = minx, miny = miny,
    complete = complete,
    cluster = cluster, entities = entities,
    candidates = candidates,
  }
end

local function rect_info(surface, rect)
  local cluster, entities, missing = {}, {}, 0
  for x = rect.minx, rect.minx + rect.w - 1 do
    for y = rect.miny, rect.miny + rect.h - 1 do
      cluster[#cluster + 1] = {tx = x, ty = y}
      local pos = {x + 0.5, y + 0.5}
      local e = surface.find_entity(FRAME, pos) or surface.find_entity(STORAGE, pos)
      if e then
        entities[tile_key(x, y)] = e
      else
        missing = missing + 1
      end
    end
  end
  return {
    count = #cluster,
    w = rect.w, h = rect.h,
    minx = rect.minx, miny = rect.miny,
    complete = (missing == 0),
    cluster = cluster, entities = entities,
    missing = missing,
  }
end

-- Поиск точного прямоугольника под целевое здание заданного размера,
-- даже если каркасы стоят впритык друг к другу на общем поле!
local function find_building_rect_at(surface, dx, dy, target_building)
  local s = target_sizes()[target_building]
  if not s then return nil end

  local variants = (s.w == s.h) and {{s.w, s.h}} or {{s.w, s.h}, {s.h, s.w}}
  local this_pending = find_pending_at(surface, dx, dy)

  for _, dims in ipairs(variants) do
    local fw, fh = dims[1], dims[2]

    local candidate_rects = {}
    for ox = dx - fw + 1, dx do
      for oy = dy - fh + 1, dy do
        table.insert(candidate_rects, {minx = ox, miny = oy, w = fw, h = fh})
      end
    end

    table.sort(candidate_rects, function(a, b)
      local a_cx = a.minx + fw / 2
      local a_cy = a.miny + fh / 2
      local b_cx = b.minx + fw / 2
      local b_cy = b.miny + fh / 2
      local da = math.abs(a_cx - (dx + 0.5)) + math.abs(a_cy - (dy + 0.5))
      local db = math.abs(b_cx - (dx + 0.5)) + math.abs(b_cy - (dy + 0.5))
      if da ~= db then return da < db end
      if a.miny ~= b.miny then return a.miny < b.miny end
      return a.minx < b.minx
    end)

    for _, r in ipairs(candidate_rects) do
      local valid = true
      for x = r.minx, r.minx + r.w - 1 do
        for y = r.miny, r.miny + r.h - 1 do
          local pos = {x + 0.5, y + 0.5}
          local f = surface.find_entity(FRAME, pos) or surface.find_entity(STORAGE, pos)
          -- Допускаются также клетки, где стоит призрак каркаса (entity-ghost)
          if not f then
            local g = surface.find_entity("entity-ghost", pos)
            if not (g and g.ghost_name == FRAME) then
              valid = false
              break
            end
          end
          local p = find_pending_at(surface, x, y)
          if p and p ~= this_pending then
            valid = false
            break
          end
          if is_frame_in_active_job(surface, x, y) then
            valid = false
            break
          end
        end
        if not valid then break end
      end

      if valid then
        return rect_info(surface, r)
      end
    end
  end

  return nil
end

local function find_subrect_at(info, ctx_tx, ctx_ty)
  local sizes = target_sizes()
  local set = {}
  for _, t in ipairs(info.cluster) do
    set[tile_key(t.tx, t.ty)] = true
  end

  local order = {}
  for name in pairs(sizes) do order[#order + 1] = name end
  table.sort(order, function(a, b)
    return sizes[a].area > sizes[b].area
  end)

  for _, name in ipairs(order) do
    local s = sizes[name]
    local variants = (s.w == s.h) and {{s.w, s.h}} or {{s.w, s.h}, {s.h, s.w}}
    for _, dims in ipairs(variants) do
      local fw, fh = dims[1], dims[2]

      local candidate_rects = {}
      for ox = ctx_tx - fw + 1, ctx_tx do
        for oy = ctx_ty - fh + 1, ctx_ty do
          if ox >= info.minx and oy >= info.miny
            and ox + fw - 1 <= info.minx + info.w - 1
            and oy + fh - 1 <= info.miny + info.h - 1
          then
            local all = true
            for x = ox, ox + fw - 1 do
              for y = oy, oy + fh - 1 do
                if not set[tile_key(x, y)] then
                  all = false
                  break
                end
              end
              if not all then break end
            end
            if all then
              table.insert(candidate_rects, {minx = ox, miny = oy, w = fw, h = fh})
            end
          end
        end
      end

      if #candidate_rects > 0 then
        table.sort(candidate_rects, function(a, b)
          local a_align = ((a.minx - info.minx) % fw == 0) and ((a.miny - info.miny) % fh == 0)
          local b_align = ((b.minx - info.minx) % fw == 0) and ((b.miny - info.miny) % fh == 0)
          if a_align ~= b_align then return a_align end
          local da = math.abs(a.minx - ctx_tx) + math.abs(a.miny - ctx_ty)
          local db = math.abs(b.minx - ctx_tx) + math.abs(b.miny - ctx_ty)
          return da < db
        end)
        return candidate_rects[1]
      end
    end
  end
  return nil
end

local function subinfo_from(info, rect)
  local cluster, entities = {}, {}
  for x = rect.minx, rect.minx + rect.w - 1 do
    for y = rect.miny, rect.miny + rect.h - 1 do
      cluster[#cluster + 1] = {tx = x, ty = y}
      entities[tile_key(x, y)] = info.entities[tile_key(x, y)]
    end
  end
  return {
    count = rect.w * rect.h,
    w = rect.w, h = rect.h,
    minx = rect.minx, miny = rect.miny,
    complete = true,
    cluster = cluster, entities = entities,
  }
end

local function candidates_for_size(w, h)
  local c = {}
  for name, s in pairs(target_sizes()) do
    if (s.w == w and s.h == h) or (s.w == h and s.h == w) then
      c[#c + 1] = name
    end
  end
  table.sort(c)
  return c
end

local function resolve_area(surface, tx, ty)
  local info = cluster_info(surface, tx, ty)
  if not info then return nil, nil, nil end

  if info.complete and #info.candidates > 0 then
    return info, info.candidates, info
  end

  local rect = find_subrect_at(info, tx, ty)
  if rect then
    local subinfo = subinfo_from(info, rect)
    return subinfo, candidates_for_size(subinfo.w, subinfo.h), info
  end

  return nil, nil, info
end

-- ===== поиск и списание ресурса =====
local function find_resource_source(surface, rect, target, player)
  -- 1) Фреймы внутри постройки
  for x = rect.minx, rect.minx + rect.w - 1 do
    for y = rect.miny, rect.miny + rect.h - 1 do
      local pos = {x + 0.5, y + 0.5}
      local entities = surface.find_entities_filtered{
        position = pos,
        name = {FRAME, STORAGE},
      }
      for _, e in ipairs(entities) do
        local inv = e.get_inventory(defines.inventory.chest)
        if inv and inv.get_item_count(target) >= 1 then
          return {kind = "frame", entity = e, inv = inv}
        end
      end
    end
  end

  -- 2) Зелёные хранилища "впритык"
  for _, e in ipairs(get_touching_storages(surface, rect)) do
    local inv = e.get_inventory(defines.inventory.chest)
    if inv and inv.get_item_count(target) >= 1 then
      return {kind = "storage", entity = e, inv = inv}
    end
  end

  -- 3) Инвентарь игрока (только если игрок явно вызвал постройку через меню/панель)
  if COST_FROM_INVENTORY and player and player.valid then
    local inv = player.get_main_inventory()
    if inv and inv.get_item_count(target) >= 1 then
      return {kind = "player", player = player, inv = inv}
    end
  end

  return nil
end

local function begin_payment(surface, rect, target, player)
  if not COST_FROM_INVENTORY then return {kind = "free"} end

  local source = find_resource_source(surface, rect, target, player)
  if source then
    source.inv.remove({name = target, count = 1})
    return {
      kind = source.kind,
      entity = source.entity,
      player = source.player,
    }
  end

  return nil
end

local function end_payment_refund(surface, position, payer, target)
  if not COST_FROM_INVENTORY or not payer or payer.kind == "free" then return end
  if payer.entity and payer.entity.valid then
    local inv = payer.entity.get_inventory(defines.inventory.chest)
    if inv then inv.insert({name = target, count = 1}) return end
  elseif payer.player and payer.player.valid then
    local inv = payer.player.get_main_inventory()
    if inv then inv.insert({name = target, count = 1}) return end
  end
  surface.spill_item_stack{position = position, stack = {name = target, count = 1}, enable_looted = true}
end

-- ===== работа с каркасом =====
local function restore_frames(surface, info, force)
  local lost = 0
  for _, t in ipairs(info.cluster) do
    local ok, e = pcall(function()
      return surface.create_entity{
        name = FRAME,
        position = {t.tx + 0.5, t.ty + 0.5},
        force = force,
        raise_built = false,
      }
    end)
    if not (ok and e) then lost = lost + 1 end
  end
  if lost > 0 then
    local msg = "MultiBuild: кадров каркаса не вернулось на место: " .. lost
    log(msg)
    if storage.debug_enabled then
      game.print("[color=red]" .. msg .. "[/color]")
    end
  end
end

local function destroy_frames_at(surface, tiles)
  for _, t in ipairs(tiles) do
    local pos = {t.tx + 0.5, t.ty + 0.5}
    local e = surface.find_entity(FRAME, pos) or surface.find_entity(STORAGE, pos)
    if e and e.valid then e.destroy() end
  end
end

-- ===== СИСТЕМА ПЛАНОВ С СУЩНОСТЯМИ mb-plan-* =====
-- Невидимые сущности плана имеют нативный selection_box из игры (без Lua-рендера!)
-- и автоматически ставят под собой призраки каркаса (ghost mb-frame).
-- Отрисовка плана и нативного selection_box выполняется самим движком Factorio через сущность плана на слое "air-object".

local function drop_pending(i)
  local p = storage.pendings[i]
  if p then
    if p.render_obj and p.render_obj.valid then
      p.render_obj.destroy()
      p.render_obj = nil
    end
    if p.plan_entity and p.plan_entity.valid then
      p.plan_entity.destroy()
      p.plan_entity = nil
    end
    if p.surface and p.surface.valid and p.rect then
      clear_pending_requests(p.surface, p.rect)
    end
  end
  table.remove(storage.pendings, i)
end

local function add_pending(surface, info, target, force, player, recipe, direction)
  local rect = {minx = info.minx, miny = info.miny, w = info.w, h = info.h}
  local cx = rect.minx + rect.w / 2
  local cy = rect.miny + rect.h / 2
  local s = target_sizes()[target]

  -- Определяем направление: если не задано, проверяем соотношение сторон
  local dir = direction
  if not dir and s then
    if s.w ~= s.h and info.w == s.h and info.h == s.w then
      dir = defines.direction.east
    else
      dir = defines.direction.north
    end
  end
  dir = dir or defines.direction.north

  local plan_name = "mb-plan-" .. target

  -- Удаляем любые устаревшие сущности плана на этом месте
  local old_plans = surface.find_entities_filtered{
    area = {{rect.minx, rect.miny}, {rect.minx + rect.w, rect.miny + rect.h}},
  }
  local plan_ent = nil
  for _, pe in ipairs(old_plans) do
    if pe.valid and string.sub(pe.name, 1, 8) == "mb-plan-" then
      if pe.name == plan_name and math.abs(pe.position.x - cx) < 0.1 and math.abs(pe.position.y - cy) < 0.1 then
        plan_ent = pe
      else
        pe.destroy()
      end
    end
  end

  -- 1) Создаем сущность плана с точным направлением (Factorio сам повернет selection_box и иконку без дублирования!)
  if not (plan_ent and plan_ent.valid) then
    if prototypes.entity[plan_name] then
      plan_ent = surface.create_entity{
        name = plan_name,
        position = {cx, cy},
        direction = dir,
        force = force or (player and player.force) or "player",
        create_build_effect_smoke = false,
        raise_built = false,
      }
    end
  elseif plan_ent.valid and dir then
    plan_ent.direction = dir
  end

  -- 2) "ставили под собой призрак каркаса для постройки самого здания"
  for x = rect.minx, rect.minx + rect.w - 1 do
    for y = rect.miny, rect.miny + rect.h - 1 do
      local pos = {x + 0.5, y + 0.5}
      local existing = surface.find_entity(FRAME, pos) or surface.find_entity(STORAGE, pos)
      local ghost = surface.find_entity("entity-ghost", pos)
      if not existing and not ghost then
        surface.create_entity{
          name = "entity-ghost",
          inner_name = FRAME,
          position = pos,
          force = force or (player and player.force) or "player",
        }
      end
    end
  end

  -- 3) Запись в реестр планов
  local existing, idx = find_pending_for_rect(surface, rect)
  if existing then
    if existing.render_obj and existing.render_obj.valid then
      existing.render_obj.destroy()
    end
    existing.render_obj = nil
    if existing.plan_entity and existing.plan_entity.valid and existing.plan_entity ~= plan_ent then
      existing.plan_entity.destroy()
    end
    existing.target = target
    existing.force = force or existing.force
    existing.recipe = recipe or existing.recipe
    existing.direction = dir or existing.direction
    existing.player_index = player and player.index or existing.player_index
    existing.plan_entity = plan_ent
    update_pending_requests(surface, rect, target)
    return
  end

  storage.pendings[#storage.pendings + 1] = {
    surface = surface,
    rect = rect,
    target = target,
    force = force or (player and player.force) or "player",
    recipe = recipe,
    direction = dir,
    player_index = player and player.index or nil,
    plan_entity = plan_ent,
  }

  -- 4) Логистический запрос для дронов
  update_pending_requests(surface, rect, target)

  ftext(surface, {cx, cy},
    {"multibuild.pending-target", {"entity-name." .. target}},
    {r = 1, g = 0.8, b = 0.35})
end

-- предварительные объявления
local start_build
local close_custom_frame_menu
local open_custom_frame_menu

local function poll_pendings()
  local pendings = storage.pendings
  if not pendings or #pendings == 0 then return end

  for i = #pendings, 1, -1 do
    local p = pendings[i]
    if not (p.surface and p.surface.valid) then
      drop_pending(i)
    else
      -- Удаляем устаревшие render_obj, если остались из прошлых версий
      if p.render_obj and p.render_obj.valid then
        p.render_obj.destroy()
        p.render_obj = nil
      end

      -- Проверяем наличие сущности плана, если вдруг исчезла
      if not (p.plan_entity and p.plan_entity.valid) then
        local plan_name = "mb-plan-" .. p.target
        if prototypes.entity[plan_name] then
          local cx = p.rect.minx + p.rect.w / 2
          local cy = p.rect.miny + p.rect.h / 2
          p.plan_entity = p.surface.create_entity{
            name = plan_name,
            position = {cx, cy},
            direction = p.direction or defines.direction.north,
            force = p.force,
            create_build_effect_smoke = false,
            raise_built = false,
          }
        end
      end

      local info = rect_info(p.surface, p.rect)
      -- Все ли каркасы готовы?
      if info.complete then
        -- Проверяем появление предмета здания (принесён дроном или положен игроком)
        local source = find_resource_source(p.surface, p.rect, p.target, nil)
        if source then
          local target = p.target
          local force = p.force
          local recipe = p.recipe
          local dir = p.direction
          -- Удаляем сущность плана перед началом постройки
          if p.plan_entity and p.plan_entity.valid then
            p.plan_entity.destroy()
            p.plan_entity = nil
          end
          drop_pending(i)
          start_build(p.surface, target, info, force, nil, recipe, dir)
        end
      end
    end
  end
end

-- ===== запуск постройки =====
start_build = function(surface, target, info, force, player, recipe, direction)
  local s = target_sizes()[target]
  if not s then return end

  local rect = {minx = info.minx, miny = info.miny, w = info.w, h = info.h}
  local cx, cy = info.minx + info.w / 2, info.miny + info.h / 2

  local existing, idx = find_pending_for_rect(surface, rect)

  local dir = direction or (existing and existing.direction)
  if not dir then
    if s.w ~= s.h and info.w == s.h and info.h == s.w then
      dir = defines.direction.east
    else
      dir = defines.direction.north
    end
  end

  -- 1) Не запускаем повторно, если на этих клетках уже строится здание
  for _, j in pairs(storage.jobs or {}) do
    if j.surface == surface and j.rect and rects_overlap(rect, j.rect) then
      return
    end
  end

  -- Проверяем рецепт из сохранённых при копировании
  local target_recipe = recipe
  if not target_recipe and storage.pending_recipes then
    local k = tile_key(info.minx, info.miny)
    target_recipe = storage.pending_recipes[k]
    storage.pending_recipes[k] = nil
  end

  -- 2) Проверяем наличие предмета
  local payer = begin_payment(surface, rect, target, player)
  if not payer then
    -- Предмета нет: ставим в план mb-plan-* и призраки каркаса под ним
    add_pending(surface, info, target, force, player, target_recipe, dir)
    return
  end

  -- 3) Предмет ЕСТЬ и списан:
  if existing then
    if not target_recipe then target_recipe = existing.recipe end
    if not dir then dir = existing.direction end
    if existing.render_obj and existing.render_obj.valid then
      existing.render_obj.destroy()
      existing.render_obj = nil
    end
    if existing.plan_entity and existing.plan_entity.valid then
      existing.plan_entity.destroy()
      existing.plan_entity = nil
    end
    drop_pending(idx)
  end

  -- Удаляем любые сущности плана, если остались на месте
  local old_plans = surface.find_entities_filtered{
    area = {{rect.minx, rect.miny}, {rect.minx + rect.w, rect.miny + rect.h}},
  }
  for _, pe in ipairs(old_plans) do
    if pe.valid and string.sub(pe.name, 1, 8) == "mb-plan-" then
      pe.destroy()
    end
  end

  -- Закрываем открытые кастомные меню каркаса у игроков
  for _, p in pairs(game.connected_players) do
    if p.gui.screen.mb_frame_menu then
      close_custom_frame_menu(p)
    end
    if p.opened and p.opened.valid and p.opened.name == FRAME then
      local ox = math.floor(p.opened.position.x)
      local oy = math.floor(p.opened.position.y)
      if ox >= rect.minx and ox < rect.minx + rect.w and oy >= rect.miny and oy < rect.miny + rect.h then
        p.opened = nil
      end
    end
  end

  -- Платформенная строительная анимация
  local area = {
    left_top = {x = info.minx, y = info.miny},
    right_bottom = {x = info.minx + info.w, y = info.miny + info.h},
  }
  local up_at, down_at
  local ok, err = pcall(function()
    up_at, down_at = platform_anim.play(surface, area, {x = cx, y = cy})
  end)
  if not ok then
    end_payment_refund(surface, {cx, cy}, payer, target)
    local msg = "MultiBuild: платформенная анимация не запустилась: " .. tostring(err)
    log(msg)
    if storage.debug_enabled then
      game.print("[color=red]" .. msg .. "[/color]")
    end
    ftext(surface, {cx, cy}, {"multibuild.anim-failed"}, {r = 1, g = 0.4, b = 0.4})
    return
  end

  storage.jobs[#storage.jobs + 1] = {
    surface = surface, cx = cx, cy = cy, direction = dir,
    target = target, force = force,
    up_at = up_at, down_at = down_at, placed = false,
    rect = rect,
    tiles = info.cluster,
    count = info.count,
    size = math.max(info.w, info.h),
    payer = payer,
    player_index = player and player.index or nil,
    recipe = target_recipe,
  }
end

-- ===== проверка предметов во фреймах (лимит 1 шт. + триггер постройки) =====
local function enforce_frame_limit_and_check(frame_entity, player)
  if not (frame_entity and frame_entity.valid) then return end
  local inv = frame_entity.get_inventory(defines.inventory.chest)
  if not inv then return end

  local item_name = nil
  for i = 1, #inv do
    local stack = inv[i]
    if stack and stack.valid_for_read then
      if stack.count > 1 then
        local excess = stack.count - 1
        stack.count = 1
        if player and player.valid then
          local inserted = player.insert{name = stack.name, count = excess}
          excess = excess - inserted
        end
        if excess > 0 then
          frame_entity.surface.spill_item_stack{
            position = frame_entity.position,
            stack = {name = stack.name, count = excess},
            enable_looted = true,
          }
        end
      end
      if not item_name then
        item_name = stack.name
      end
    end
  end

  if not item_name then return end

  local surface = frame_entity.surface
  local tx = math.floor(frame_entity.position.x)
  local ty = math.floor(frame_entity.position.y)

  -- 1) Проверяем, есть ли уже план для этой площадки
  local p, p_idx = find_pending_at(surface, tx, ty)
  if p then
    if p.target == item_name then
      local info = rect_info(surface, p.rect)
      if info.complete then
        local force = p.force
        local recipe = p.recipe
        local p_dir = p.direction
        drop_pending(p_idx)
        start_build(surface, item_name, info, force, player, recipe, p_dir)
      end
    else
      ftext(surface, frame_entity.position, {"multibuild.plan-mismatch", {"entity-name." .. p.target}}, {r = 1, g = 0.5, b = 0.3})
    end
    return
  end

  -- 2) Если плана не было, проверяем подходящее здание
  local build_info = find_building_rect_at(surface, tx, ty, item_name)
  if not build_info then
    local b_info, candidates = resolve_area(surface, tx, ty)
    if b_info and b_info.complete then
      for _, c in ipairs(candidates or {}) do
        if c == item_name then
          build_info = b_info
          break
        end
      end
    end
  end

  if build_info and build_info.complete then
    local s = target_sizes()[item_name]
    local b_dir = defines.direction.north
    if s and build_info.w == s.h and build_info.h == s.w then
      b_dir = defines.direction.east
    end
    start_build(surface, item_name, build_info, frame_entity.force, player, nil, b_dir)
  else
    local all_sizes = target_sizes()
    if all_sizes[item_name] then
      ftext(surface, frame_entity.position, {"multibuild.size-mismatch"}, {r = 1, g = 0.5, b = 0.3})
    end
  end
end

-- ===== КОМПАКТНОЕ ПРОЗРАЧНОЕ МЕНЮ С 1 СЛОТОМ ДЛЯ ФРЕЙМА =====

local function add_close_button(parent, name)
  local sprite = "utility/close"
  if helpers and helpers.is_valid_sprite_path then
    if helpers.is_valid_sprite_path("utility/close_white") then
      sprite = "utility/close_white"
    end
  end
  return parent.add{
    type = "sprite-button",
    name = name,
    style = "frame_action_button",
    sprite = sprite,
    tooltip = {"gui.close"},
  }
end

close_custom_frame_menu = function(player)
  if not (player and player.valid) then return end

  local data = storage.opened_frames and storage.opened_frames[player.index]
  if data and data.entity and data.entity.valid then
    enforce_frame_limit_and_check(data.entity, player)
  end

  if storage.opened_frames then
    storage.opened_frames[player.index] = nil
  end

  local win = player.gui.screen.mb_frame_menu
  if win and win.valid then
    win.destroy()
  end

  if player.opened and player.opened == win then
    player.opened = nil
  end
end

open_custom_frame_menu = function(player, entity)
  close_custom_frame_menu(player)

  local tx = math.floor(entity.position.x)
  local ty = math.floor(entity.position.y)
  local build_info, candidates = resolve_area(entity.surface, tx, ty)
  local raw_info = cluster_info(entity.surface, tx, ty) or {count = 1, w = 1, h = 1, complete = true}
  local w = build_info and build_info.w or raw_info.w
  local h = build_info and build_info.h or raw_info.h

  storage.opened_frames = storage.opened_frames or {}
  storage.opened_frames[player.index] = {
    entity = entity,
    tx = tx,
    ty = ty,
    surface_index = entity.surface.index,
  }

  local win = player.gui.screen.add{
    type = "frame",
    name = "mb_frame_menu",
    style = "mb_transparent_frame",
    direction = "vertical",
  }
  win.auto_center = true

  -- 1) Заголовок окна с кнопкой закрытия
  local titlebar = win.add{type = "flow", direction = "horizontal"}
  pcall(function()
    titlebar.style.vertical_align = "center"
    titlebar.style.horizontal_spacing = 8
  end)

  titlebar.add{
    type = "label",
    caption = {"multibuild.panel-title", w, h},
    style = "frame_title",
    ignored_by_interaction = true,
  }

  local drag_filler = titlebar.add{
    type = "empty-widget",
    style = "draggable_space_header",
    ignored_by_interaction = true,
  }
  pcall(function()
    drag_filler.style.horizontally_stretchable = true
    drag_filler.style.height = 20
    drag_filler.drag_target = win
  end)

  add_close_button(titlebar, "mb_frame_menu_close")

  -- 2) Активный план / очередь (если уже есть)
  local existing_plan = find_pending_at(entity.surface, tx, ty)
  if existing_plan then
    local plan_box = win.add{type = "flow", direction = "horizontal"}
    pcall(function()
      plan_box.style.vertical_align = "center"
      plan_box.style.horizontal_spacing = 8
    end)

    local sprite = "item/" .. existing_plan.target
    if helpers and helpers.is_valid_sprite_path and not helpers.is_valid_sprite_path(sprite) then
      sprite = "entity/" .. existing_plan.target
    end
    plan_box.add{type = "sprite", sprite = sprite}
    local plan_flow = plan_box.add{type = "flow", direction = "vertical"}
    plan_flow.add{
      type = "label",
      caption = {"multibuild.current-plan", {"entity-name." .. existing_plan.target}},
      style = "bold_label",
    }
    local cancel_btn = plan_box.add{
      type = "button",
      name = "mb_frame_menu_cancel_plan",
      caption = {"multibuild.cancel-plan"},
    }
    cancel_btn.tags = {mb_tx = tx, mb_ty = ty, mb_surface = entity.surface.index}
  end

  -- 3) Единственный слот предмета для каркаса (1 слот инвентаря)
  local slot_flow = win.add{type = "flow", direction = "horizontal"}
  pcall(function()
    slot_flow.style.vertical_align = "center"
    slot_flow.style.horizontal_spacing = 8
  end)

  local chest_inv = entity.get_inventory(defines.inventory.chest)
  pcall(function()
    local inv_elem = slot_flow.add{
      type = "inventory",
      name = "mb_frame_inventory_widget",
      slots_per_row = 1,
    }
    if chest_inv then
      inv_elem.inventory = chest_inv
    end
  end)

  slot_flow.add{
    type = "label",
    caption = {"multibuild.frame-slot-title"},
  }

  -- 4) Выбор здания для планирования (компактные кнопки-слоты)
  if candidates and #candidates > 0 then
    local cand_flow = win.add{type = "flow", direction = "vertical"}
    pcall(function() cand_flow.style.vertical_spacing = 4 end)

    cand_flow.add{
      type = "label",
      caption = {"multibuild.choose-building-title"},
      style = "bold_label",
    }
    local grid = cand_flow.add{
      type = "table",
      column_count = 6,
    }
    for _, name in ipairs(candidates) do
      local sprite = "entity/" .. name
      if helpers and helpers.is_valid_sprite_path and not helpers.is_valid_sprite_path(sprite) then
        sprite = "item/" .. name
      end
      local b = grid.add{
        type = "sprite-button",
        sprite = sprite,
        style = "slot_button",
        tooltip = {"entity-name." .. name},
      }
      b.tags = {
        mb_custom_target = name,
        mb_tx = tx,
        mb_ty = ty,
        mb_surface = entity.surface.index,
      }
    end
  elseif raw_info and not raw_info.complete then
    win.add{
      type = "label",
      caption = {"multibuild.not-rectangle", raw_info.count, raw_info.w, raw_info.h},
    }
  else
    win.add{
      type = "label",
      caption = {"multibuild.no-candidate", w, h},
    }
  end

  local bflow = win.add{type = "flow", direction = "horizontal"}
  bflow.add{
    type = "button",
    name = "mb_frame_menu_close",
    caption = {"multibuild.menu-close"},
  }

  player.opened = win
end

-- ===== взаимодействие с кастомным инвентарём (2.0+) =====
if defines.events.on_gui_inventory_action then
  script.on_event(defines.events.on_gui_inventory_action, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    local opened_data = storage.opened_frames and storage.opened_frames[player.index]
    if not (opened_data and opened_data.entity and opened_data.entity.valid) then return end

    local ent = opened_data.entity
    local ent_inv = ent.get_inventory(defines.inventory.chest)
    if not ent_inv then return end

    enforce_frame_limit_and_check(ent, player)
  end)
end

-- отслеживание быстрой передачи предметов игроком (Ctrl + клик в мире)
if defines.events.on_player_fast_transferred then
  script.on_event(defines.events.on_player_fast_transferred, function(event)
    local entity = event.entity
    if entity and entity.valid and entity.name == FRAME then
      local player = event.player_index and game.get_player(event.player_index) or nil
      enforce_frame_limit_and_check(entity, player)
    end
  end)
end

-- отслеживание сброса предмета в фрейм (Z в мире)
if defines.events.on_player_dropped_item_into_entity then
  script.on_event(defines.events.on_player_dropped_item_into_entity, function(event)
    local entity = event.entity
    if entity and entity.valid and entity.name == FRAME then
      local player = event.player_index and game.get_player(event.player_index) or nil
      enforce_frame_limit_and_check(entity, player)
    end
  end)
end

-- ===== КОПИРОВАНИЕ ЗАПЛАНИРОВАННОГО ЗДАНИЯ (Shift+ПКМ -> Shift+ЛКМ) =====
local function handle_paste_settings(event)
  local source = event.source
  local destination = event.destination
  local player = event.player_index and game.get_player(event.player_index)
  if not (destination and destination.valid) then return end
  if not (source and source.valid) then return end

  local is_dest_frame = (destination.name == FRAME)
  local is_dest_plan = (string.sub(destination.name, 1, 8) == "mb-plan-")
  if not (is_dest_frame or is_dest_plan) then return end

  local target_building = nil
  local source_recipe = nil
  local source_dir = source.direction or defines.direction.north

  if string.sub(source.name, 1, 8) == "mb-plan-" then
    target_building = string.sub(source.name, 9)
    if string.sub(target_building, -4) == "-rot" then
      target_building = string.sub(target_building, 1, -5)
      source_dir = defines.direction.east
    end
    local sx, sy = math.floor(source.position.x), math.floor(source.position.y)
    local p = find_pending_at(source.surface, sx, sy)
    if p then
      source_recipe = p.recipe
      if p.direction then source_dir = p.direction end
    end
  elseif source.name == FRAME then
    local sx, sy = math.floor(source.position.x), math.floor(source.position.y)
    local p = find_pending_at(source.surface, sx, sy)
    if p then
      target_building = p.target
      source_recipe = p.recipe
      if p.direction then source_dir = p.direction end
    else
      local sinv = source.get_inventory(defines.inventory.chest)
      if sinv and not sinv.is_empty() and sinv[1] and sinv[1].valid_for_read then
        target_building = sinv[1].name
      end
    end
  else
    target_building = source.name
    source_recipe = get_entity_recipe(source, nil)
  end

  if not target_building then return end

  local dx, dy = math.floor(destination.position.x), math.floor(destination.position.y)
  local build_info = find_building_rect_at(destination.surface, dx, dy, target_building)

  if not build_info then
    local s = target_sizes()[target_building]
    if s then
      local is_rot = is_east_west(source_dir)
      local fw = is_rot and s.h or s.w
      local fh = is_rot and s.w or s.h
      local minx = dx - math.floor((fw - 1) / 2)
      local miny = dy - math.floor((fh - 1) / 2)
      build_info = {
        minx = minx, miny = miny, w = fw, h = fh,
        count = fw * fh, complete = false, cluster = {},
      }
    end
  end

  if not build_info then return end

  if source_recipe then
    storage.pending_recipes = storage.pending_recipes or {}
    storage.pending_recipes[tile_key(build_info.minx, build_info.miny)] = source_recipe
  end

  start_build(destination.surface, target_building, build_info, player and player.force or destination.force, player, source_recipe, source_dir)

  ftext(destination.surface, {build_info.minx + build_info.w / 2, build_info.miny + build_info.h / 2},
    {"multibuild.plan-pasted", {"entity-name." .. target_building}}, {r = 0.4, g = 1, b = 0.5})
end

if defines.events.on_entity_settings_pasted then
  script.on_event(defines.events.on_entity_settings_pasted, handle_paste_settings)
end

-- ===== ПИПЕТКА (КЛАВИША Q НА ЗАПЛАНИРОВАННОМ КАРКАСЕ ИЛИ СУЩНОСТИ ПЛАНА) =====
if defines.events.on_player_pipette then
  script.on_event(defines.events.on_player_pipette, function(event)
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end
    local sel = player.selected
    if not (sel and sel.valid) then return end

    local target = nil
    local is_plan = false
    if string.sub(sel.name, 1, 8) == "mb-plan-" then
      target = string.sub(sel.name, 9)
      if string.sub(target, -4) == "-rot" then
        target = string.sub(target, 1, -5)
      end
      is_plan = true
    elseif sel.name == FRAME then
      local tx, ty = math.floor(sel.position.x), math.floor(sel.position.y)
      local p = find_pending_at(sel.surface, tx, ty)
      target = p and p.target
      if not target then
        local inv = sel.get_inventory(defines.inventory.chest)
        if inv and not inv.is_empty() and inv[1] and inv[1].valid_for_read then
          target = inv[1].name
        end
      end
    end

    if target then
      local plan_item = "mb-plan-" .. target
      local pinv = player.get_main_inventory()
      if is_plan then
        local ok = pcall(function() player.cursor_ghost = plan_item end)
        if not ok then
          pcall(function() player.cursor_ghost = target end)
        end
      else
        if pinv and pinv.get_item_count(target) >= 1 then
          player.clear_cursor()
          local stack = pinv.find_item_stack(target)
          if stack then player.cursor_stack.transfer_stack(stack) end
        else
          local ok = pcall(function() player.cursor_ghost = plan_item end)
          if not ok then
            pcall(function() player.cursor_ghost = target end)
          end
        end
      end
    end
  end)
end

-- ===== РОТАЦИЯ СУЩНОСТИ ПЛАНА (КЛАВИША R В МИРЕ) =====
if defines.events.on_player_rotated_entity then
  script.on_event(defines.events.on_player_rotated_entity, function(event)
    local e = event.entity
    if not (e and e.valid) then return end
    if string.sub(e.name, 1, 8) ~= "mb-plan-" then return end

    local target_name = string.sub(e.name, 9)
    if string.sub(target_name, -4) == "-rot" then
      target_name = string.sub(target_name, 1, -5)
    end

    local s = target_sizes()[target_name]
    if not s or s.w == s.h then return end

    for i, p in ipairs(storage.pendings or {}) do
      if p.plan_entity == e or (p.surface == e.surface and rects_overlap(p.rect, {
        minx = math.floor(e.position.x - 2),
        miny = math.floor(e.position.y - 2),
        w = 4, h = 4,
      })) then
        local new_dir = e.direction or defines.direction.north
        local is_rot = is_east_west(new_dir)
        local new_w = is_rot and s.h or s.w
        local new_h = is_rot and s.w or s.h
        local cx = e.position.x
        local cy = e.position.y
        local new_minx = math.floor(cx - new_w / 2 + 0.001)
        local new_miny = math.floor(cy - new_h / 2 + 0.001)

        clear_pending_requests(p.surface, p.rect)
        for x = p.rect.minx, p.rect.minx + p.rect.w - 1 do
          for y = p.rect.miny, p.rect.miny + p.rect.h - 1 do
            local ghosts = p.surface.find_entities_filtered{name = "entity-ghost", position = {x + 0.5, y + 0.5}}
            for _, g in ipairs(ghosts) do
              if g.ghost_name == FRAME then g.destroy() end
            end
          end
        end

        if p.render_obj and p.render_obj.valid then
          p.render_obj.destroy()
          p.render_obj = nil
        end

        p.rect = {minx = new_minx, miny = new_miny, w = new_w, h = new_h}
        p.direction = new_dir
        p.plan_entity = e

        for x = new_minx, new_minx + new_w - 1 do
          for y = new_miny, new_miny + new_h - 1 do
            local pos = {x + 0.5, y + 0.5}
            local existing = p.surface.find_entity(FRAME, pos) or p.surface.find_entity(STORAGE, pos)
            local ghost = p.surface.find_entity("entity-ghost", pos)
            if not existing and not ghost then
              p.surface.create_entity{
                name = "entity-ghost",
                inner_name = FRAME,
                position = pos,
                force = p.force,
              }
            end
          end
        end

        update_pending_requests(p.surface, p.rect, p.target)
        break
      end
    end
  end)
end

-- ===== ДЕМОНТАЖ СУЩНОСТИ ПЛАНА (ПРАВЫЙ КЛИК / Alt+D) =====
local function on_plan_entity_removed(event)
  local e = event.entity
  if not (e and e.valid) then return end
  if string.sub(e.name, 1, 8) ~= "mb-plan-" then return end

  for i = #(storage.pendings or {}), 1, -1 do
    local p = storage.pendings[i]
    if p.plan_entity == e or (p.surface == e.surface and rects_overlap(p.rect, {
      minx = math.floor(e.position.x - 2),
      miny = math.floor(e.position.y - 2),
      w = 4,
      h = 4,
    })) then
      drop_pending(i)
      ftext(e.surface, e.position, {"multibuild.plan-cancelled"}, {r = 1, g = 0.5, b = 0.5})
      break
    end
  end
end

script.on_event(defines.events.on_player_mined_entity, on_plan_entity_removed)
script.on_event(defines.events.on_robot_mined_entity, on_plan_entity_removed)
script.on_event(defines.events.on_entity_died, on_plan_entity_removed)

-- ===== обработчик тика =====
local function on_tick()
  platform_anim.on_tick(game.tick)

  -- Проверка открытых меню каркасов
  if storage.opened_frames then
    for p_index, data in pairs(storage.opened_frames) do
      local p = game.get_player(p_index)
      local ent = data.entity
      if not (p and p.valid and ent and ent.valid) then
        storage.opened_frames[p_index] = nil
        if p and p.valid and p.gui.screen.mb_frame_menu then
          p.gui.screen.mb_frame_menu.destroy()
        end
      else
        if p.character and p.character.valid then
          local ppos = p.character.position
          local epos = ent.position
          local dist_sq = (ppos.x - epos.x)^2 + (ppos.y - epos.y)^2
          if dist_sq > 100 then
            close_custom_frame_menu(p)
          end
        end

        local inv = ent.get_inventory(defines.inventory.chest)
        if inv and not inv.is_empty() then
          enforce_frame_limit_and_check(ent, p)
        end
      end
    end
  end

  local jobs = storage.jobs
  if jobs and #jobs > 0 then
    for i = #jobs, 1, -1 do
      local job = jobs[i]
      local surface = job.surface
      if not (surface and surface.valid) then
        table.remove(jobs, i)
      else
        if not job.placed and game.tick >= job.up_at then
          job.placed = true
          destroy_frames_at(surface, job.tiles)

          -- Удаляем сущности плана на месте постройки
          local plans = surface.find_entities_filtered{
            area = {{job.rect.minx, job.rect.miny}, {job.rect.minx + job.rect.w, job.rect.miny + job.rect.h}},
          }
          for _, pe in ipairs(plans) do
            if pe.valid and string.sub(pe.name, 1, 8) == "mb-plan-" then
              pe.destroy()
            end
          end

          if surface.can_place_entity{name = job.target, position = {job.cx, job.cy}, direction = job.direction} then
            local player = job.player_index and game.get_player(job.player_index) or nil
            local ent = surface.create_entity{
              name = job.target,
              position = {job.cx, job.cy},
              direction = job.direction,
              force = job.force,
              raise_built = true,
              create_build_effect_smoke = false,
              player = player,
            }
            if ent and ent.valid and job.recipe then
              pcall(ent.set_recipe, job.recipe)
            end
          else
            restore_frames(surface, {cluster = job.tiles}, job.force)
            job.aborted = "blocked"
          end
        end

        if game.tick >= job.down_at then
          if job.aborted == "blocked" then
            end_payment_refund(surface, {job.cx, job.cy}, job.payer, job.target)
            ftext(surface, {job.cx, job.cy}, {"multibuild.blocked"}, {r = 1, g = 0.4, b = 0.4})
          else
            flash_light(surface, {job.cx, job.cy}, job.size * 1.5, 1, 25)
            ftext(surface, {job.cx, job.cy - job.size / 2}, {"multibuild.built", {"entity-name." .. job.target}}, {r = 0.4, g = 1, b = 0.5})
          end
          table.remove(jobs, i)
        end
      end
    end
  end

  if game.tick % POLL_TICKS == 0 then
    poll_pendings()
  end
end
script.on_event(defines.events.on_tick, on_tick)

-- ===== автосборка при достройке контура фреймов =====
local function try_auto_build(e, player)
  local ex = math.floor(e.position.x)
  local ey = math.floor(e.position.y)

  -- Проверяем: привязан ли этот фрейм к активному плану mb-plan-*?
  local p, p_idx = find_pending_at(e.surface, ex, ey)
  if p then
    local info = rect_info(e.surface, p.rect)
    if info.complete then
      local source = find_resource_source(e.surface, p.rect, p.target, nil)
      if source then
        local target = p.target
        local force = p.force
        local recipe = p.recipe
        local p_dir = p.direction
        drop_pending(p_idx)
        start_build(e.surface, target, info, force, nil, recipe, p_dir)
      else
        update_pending_requests(e.surface, p.rect, p.target)
      end
    end
    return
  end

  -- Скан свободного кластера фреймов
  local info = cluster_info(e.surface, ex, ey)
  if not (info and info.complete and #info.candidates > 0) then
    local sub_info = resolve_area(e.surface, ex, ey)
    if sub_info and sub_info.complete then
      info = sub_info
    else
      return
    end
  end

  local rect = {minx = info.minx, miny = info.miny, w = info.w, h = info.h}

  -- Лежит ли уже предмет здания в фрейме или сундуке?
  local found_target
  for _, name in ipairs(info.candidates or {}) do
    if find_resource_source(e.surface, rect, name, nil) then
      found_target = name
      break
    end
  end

  if found_target then
    local s = target_sizes()[found_target]
    local b_dir = defines.direction.north
    if s and info.w == s.h and info.h == s.w then
      b_dir = defines.direction.east
    end
    start_build(e.surface, found_target, info, e.force, nil, nil, b_dir)
  elseif info.candidates and #info.candidates == 1 then
    local cand = info.candidates[1]
    local s = target_sizes()[cand]
    local b_dir = defines.direction.north
    if s and info.w == s.h and info.h == s.w then
      b_dir = defines.direction.east
    end
    add_pending(e.surface, info, cand, e.force, player, nil, b_dir)
  elseif player then
    ftext(e.surface, e.position, {"multibuild.auto-hint"}, {r = 0.6, g = 0.9, b = 1})
  end
end

-- ===== обработчики постройки сущностей =====
local function on_entity_placed(event)
  local e = event.entity
  if not (e and e.valid) then return end

  -- 1) Призрак сущности плана из чертежа (Ctrl+V) или из курсора
  if e.name == "entity-ghost" and string.sub(e.ghost_name, 1, 8) == "mb-plan-" then
    local target_name = string.sub(e.ghost_name, 9)
    if string.sub(target_name, -4) == "-rot" then
      target_name = string.sub(target_name, 1, -5)
    end
    local s = target_sizes()[target_name]
    if s then
      local dir = e.direction or defines.direction.north
      local is_rot = is_east_west(dir)
      local fw = is_rot and s.h or s.w
      local fh = is_rot and s.w or s.h
      local cx, cy = e.position.x, e.position.y
      local minx = math.floor(cx - fw / 2 + 0.001)
      local miny = math.floor(cy - fh / 2 + 0.001)
      local force = e.force
      local surface = e.surface
      local recipe = get_entity_recipe(e, event.tags)

      e.destroy()

      add_pending(surface, {minx = minx, miny = miny, w = fw, h = fh}, target_name, force, event.player_index and game.get_player(event.player_index), recipe, dir)
      return
    end
  end

  -- 1.5) Призрак обычного здания, поставленный на готовые фреймы MultiBuild
  if e.name == "entity-ghost" and target_sizes()[e.ghost_name] then
    local target_name = e.ghost_name
    local s = target_sizes()[target_name]
    local dir = e.direction or defines.direction.north
    local is_rot = is_east_west(dir)
    local fw = is_rot and s.h or s.w
    local fh = is_rot and s.w or s.h
    local cx, cy = e.position.x, e.position.y
    local minx = math.floor(cx - fw / 2 + 0.001)
    local miny = math.floor(cy - fh / 2 + 0.001)
    local surface = e.surface

    -- Проверяем, есть ли под призраком фреймы (готовые или призраки каркаса)
    local has_frame = false
    for x = minx, minx + fw - 1 do
      for y = miny, miny + fh - 1 do
        local pos = {x + 0.5, y + 0.5}
        if surface.find_entity(FRAME, pos) or surface.find_entity(STORAGE, pos) then
          has_frame = true
          break
        end
        local ghosts = surface.find_entities_filtered{name = "entity-ghost", position = pos}
        for _, g in ipairs(ghosts) do
          if g.ghost_name == FRAME then
            has_frame = true
            break
          end
        end
        if has_frame then break end
      end
      if has_frame then break end
    end

    if has_frame then
      local force = e.force
      local recipe = get_entity_recipe(e, event.tags)
      e.destroy()
      add_pending(surface, {minx = minx, miny = miny, w = fw, h = fh}, target_name, force, event.player_index and game.get_player(event.player_index), recipe, dir)
      return
    end
  end

  -- 2) Сама сущность плана mb-plan-*
  if string.sub(e.name, 1, 8) == "mb-plan-" then
    local target_name = string.sub(e.name, 9)
    if string.sub(target_name, -4) == "-rot" then
      target_name = string.sub(target_name, 1, -5)
    end
    local s = target_sizes()[target_name]
    if s then
      local dir = e.direction or defines.direction.north
      local is_rot = is_east_west(dir)
      local fw = is_rot and s.h or s.w
      local fh = is_rot and s.w or s.h
      local minx = math.floor(e.position.x - fw / 2 + 0.001)
      local miny = math.floor(e.position.y - fh / 2 + 0.001)
      add_pending(e.surface, {minx = minx, miny = miny, w = fw, h = fh}, target_name, e.force, event.player_index and game.get_player(event.player_index), nil, dir)
    end
    return
  end

  -- 3) Зелёный сундук запроса
  if e.name == STORAGE then
    local stx = math.floor(e.position.x)
    local sty = math.floor(e.position.y)
    for _, p in ipairs(storage.pendings or {}) do
      if p.surface == e.surface then
        if stx >= p.rect.minx - 1 and stx <= p.rect.minx + p.rect.w
           and sty >= p.rect.miny - 1 and sty <= p.rect.miny + p.rect.h then
          set_entity_request(e, p.target, 1)
        end
      end
    end
    return
  end

  if e.name ~= FRAME then return end

  try_auto_build(e, event.player_index and game.get_player(event.player_index) or nil)
end

script.on_event(defines.events.on_built_entity, on_entity_placed)
script.on_event(defines.events.on_robot_built_entity, on_entity_placed)
if defines.events.on_space_platform_built_entity then
  script.on_event(defines.events.on_space_platform_built_entity, on_entity_placed)
end

-- разборка каркаса отменяет план и закрывает открытые меню
local function on_frame_or_storage_removed(event)
  local e = event.entity
  if not (e and e.valid) then return end
  if e.name ~= FRAME and e.name ~= STORAGE then return end

  if storage.opened_frames then
    for p_index, data in pairs(storage.opened_frames) do
      if data.entity == e or not (data.entity and data.entity.valid) then
        local p = game.get_player(p_index)
        if p and p.valid then
          close_custom_frame_menu(p)
        end
      end
    end
  end

  local ex = math.floor(e.position.x)
  local ey = math.floor(e.position.y)
  local pendings = storage.pendings or {}
  for i = #pendings, 1, -1 do
    local p = pendings[i]
    if p.surface == e.surface then
      if ex >= p.rect.minx and ex < p.rect.minx + p.rect.w
         and ey >= p.rect.miny and ey < p.rect.miny + p.rect.h then
        drop_pending(i)
      end
    end
  end
end

script.on_event(defines.events.on_player_mined_entity, on_frame_or_storage_removed)
script.on_event(defines.events.on_robot_mined_entity, on_frame_or_storage_removed)
script.on_event(defines.events.on_entity_died, on_frame_or_storage_removed)

-- ===== GUI: полноэкранное прозрачное меню (для маркера области) =====
local function close_menu(player)
  local gui = player.gui.screen.mb_menu
  if gui then gui.destroy() end
  storage.menus[player.index] = nil
end

local function open_menu(player, ctx, candidates, current_plan)
  close_menu(player)
  storage.menus[player.index] = ctx

  local frame = player.gui.screen.add{
    type = "frame",
    name = "mb_menu",
    style = "mb_transparent_frame",
    direction = "vertical",
  }
  frame.auto_center = true
  frame.add{type = "label", caption = {"multibuild.menu-title"}, style = "frame_title"}

  if current_plan then
    frame.add{
      type = "label",
      caption = {"multibuild.current-plan", {"entity-name." .. current_plan}},
      style = "bold_label",
    }
  end

  local grid = frame.add{type = "table", column_count = 6}
  for _, name in ipairs(candidates) do
    local b = grid.add{
      type = "sprite-button",
      sprite = "entity/" .. name,
      style = "slot_button",
      tooltip = {"entity-name." .. name},
    }
    b.tags = {mb_target = name}
  end

  if COST_FROM_INVENTORY then
    frame.add{type = "label", caption = {"multibuild.cost-hint"}}
  end

  local bflow = frame.add{type = "flow", direction = "horizontal"}
  bflow.add{type = "button", name = "mb_menu_close", caption = {"multibuild.menu-close"}}
  if current_plan then
    bflow.add{type = "button", name = "mb_menu_cancel_plan", caption = {"multibuild.cancel-plan"}}
  end

  player.opened = frame
end

local function click_flow(surface, tx, ty, player, force)
  local build_info, candidates, raw = resolve_area(surface, tx, ty)
  if not raw then return end
  local pos = {tx + 0.5, ty + 0.5}

  if not candidates or #candidates == 0 then
    if raw.complete then
      ftext(surface, pos, {"multibuild.no-candidate", raw.w, raw.h})
    else
      ftext(surface, pos, {"multibuild.not-rectangle", raw.count, raw.w, raw.h})
    end
    return
  end

  local existing_plan = find_pending_at(surface, tx, ty)
  local current_target = existing_plan and existing_plan.target or nil

  if #candidates == 1 then
    local target = candidates[1]
    local s = target_sizes()[target]
    local b_dir = defines.direction.north
    if s and build_info.w == s.h and build_info.h == s.w then
      b_dir = defines.direction.east
    end
    start_build(surface, target, build_info, force, player, nil, b_dir)
  else
    open_menu(player, {mode = "frame", surface_index = surface.index, tx = tx, ty = ty}, candidates, current_target)
  end
end

-- Клик по блоку каркаса:
-- если с маркером SELECTOR в руках -> меню маркера
-- без маркера -> открывается прозрачное компактное меню каркаса с 1 слотом
script.on_event(defines.events.on_gui_opened, function(event)
  local entity = event.entity
  if not (entity and entity.valid) then return end
  local player = game.get_player(event.player_index)
  if not player then return end

  if entity.name == FRAME then
    local cs = player.cursor_stack
    if cs and cs.valid_for_read and cs.name == SELECTOR then
      player.opened = nil
      click_flow(entity.surface, math.floor(entity.position.x), math.floor(entity.position.y), player, entity.force)
      return
    end

    open_custom_frame_menu(player, entity)
    return
  end

  if string.sub(entity.name, 1, 8) == "mb-plan-" then
    -- Клик по сущности плана: открываем меню для отмены или замены плана
    local target = string.sub(entity.name, 9)
    if string.sub(target, -4) == "-rot" then
      target = string.sub(target, 1, -5)
    end
    local s = target_sizes()[target]
    if s then
      local is_rot = is_east_west(entity.direction)
      local fw = is_rot and s.h or s.w
      local fh = is_rot and s.w or s.h
      local tx = math.floor(entity.position.x - fw / 2 + 0.001)
      local ty = math.floor(entity.position.y - fh / 2 + 0.001)
      local cx_frame = tx + math.floor((fw - 1) / 2)
      local cy_frame = ty + math.floor((fh - 1) / 2)
      local f = entity.surface.find_entity(FRAME, {cx_frame + 0.5, cy_frame + 0.5})
      if not f then
        f = entity.surface.find_entity(FRAME, {tx + 0.5, ty + 0.5})
      end
      if f then
        open_custom_frame_menu(player, f)
      end
    end
  end
end)

script.on_event(defines.events.on_gui_click, function(event)
  local el = event.element
  if not (el and el.valid) then return end
  local player = game.get_player(event.player_index)
  if not player then return end

  -- Кнопки кастомного меню каркаса
  if el.name == "mb_frame_menu_close" then
    close_custom_frame_menu(player)
    return
  end

  if el.name == "mb_frame_menu_cancel_plan" then
    local tags = el.tags or {}
    local surface = tags.mb_surface and game.get_surface(tags.mb_surface) or player.surface
    if surface and tags.mb_tx and tags.mb_ty then
      local p, idx = find_pending_at(surface, tags.mb_tx, tags.mb_ty)
      if p then
        drop_pending(idx)
        ftext(player.surface, player.position, {"multibuild.plan-cancelled"}, {r = 1, g = 0.5, b = 0.5})
      end
    end
    local data = storage.opened_frames and storage.opened_frames[player.index]
    if data and data.entity and data.entity.valid then
      open_custom_frame_menu(player, data.entity)
    else
      close_custom_frame_menu(player)
    end
    return
  end

  if el.tags and el.tags.mb_custom_target then
    local target = el.tags.mb_custom_target
    local tags = el.tags
    local surface = tags.mb_surface and game.get_surface(tags.mb_surface) or player.surface
    if not surface then return end

    local build_info = find_building_rect_at(surface, tags.mb_tx, tags.mb_ty, target)
    if not build_info then
      build_info = resolve_area(surface, tags.mb_tx, tags.mb_ty)
    end

    local s = target_sizes()[target]
    local b_dir = defines.direction.north
    if build_info and s then
      if build_info.w == s.h and build_info.h == s.w then
        b_dir = defines.direction.east
      end
    end

    if not (build_info and build_info.complete) then
      if s then
        local minx = tags.mb_tx - math.floor((s.w - 1) / 2)
        local miny = tags.mb_ty - math.floor((s.h - 1) / 2)
        build_info = {
          minx = minx, miny = miny, w = s.w, h = s.h,
          count = s.w * s.h, complete = false, cluster = {},
        }
      end
    end

    local opened_data = storage.opened_frames and storage.opened_frames[player.index]
    local ent = opened_data and opened_data.entity

    start_build(surface, target, build_info, player.force, player, nil, b_dir)

    if ent and ent.valid and player.gui.screen.mb_frame_menu then
      open_custom_frame_menu(player, ent)
    end
    return
  end

  -- Кнопки полноэкранного меню маркера
  if el.name == "mb_menu_close" then
    close_menu(player)
    clear_selection(player)
    return
  end

  local ctx = storage.menus[player.index]

  if el.name == "mb_menu_cancel_plan" then
    close_menu(player)
    clear_selection(player)
    if ctx then
      local surface = game.get_surface(ctx.surface_index)
      if surface then
        local rect = ctx.rect
        if not rect and ctx.tx and ctx.ty then
          local p, idx = find_pending_at(surface, ctx.tx, ctx.ty)
          if p then drop_pending(idx) end
        elseif rect then
          local p, idx = find_pending_for_rect(surface, rect)
          if p then drop_pending(idx) end
        end
        ftext(player.surface, player.position, {"multibuild.plan-cancelled"}, {r = 1, g = 0.5, b = 0.5})
      end
    end
    return
  end

  local target = el.tags and el.tags.mb_target
  if not target then return end

  close_menu(player)
  clear_selection(player)
  if not ctx then return end
  local surface = game.get_surface(ctx.surface_index)
  if not surface then return end

  local build_info
  if ctx.mode == "rect" then
    build_info = rect_info(surface, ctx.rect)
    if not build_info.complete then
      ftext(surface, {ctx.rect.minx + 0.5, ctx.rect.miny + 0.5}, {"multibuild.rect-missing", build_info.missing})
      return
    end
  else
    build_info = find_building_rect_at(surface, ctx.tx, ctx.ty, target) or resolve_area(surface, ctx.tx, ctx.ty)
    if not build_info then
      ftext(player.surface, player.position, {"multibuild.gone"})
      return
    end
  end

  local s = target_sizes()[target]
  if not (s and ((s.w == build_info.w and s.h == build_info.h) or (s.w == build_info.h and s.h == build_info.w))) then
    ftext(player.surface, player.position, {"multibuild.size-mismatch"})
    return
  end
  local b_dir = defines.direction.north
  if s and build_info.w == s.h and build_info.h == s.w then
    b_dir = defines.direction.east
  end
  start_build(surface, target, build_info, player.force, player, nil, b_dir)
end)

script.on_event(defines.events.on_gui_closed, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end

  if event.element and event.element.valid and event.element.name == "mb_frame_menu" then
    close_custom_frame_menu(player)
    return
  end

  if event.element and event.element.valid and event.element.name == "mb_menu" then
    event.element.destroy()
    storage.menus[event.player_index] = nil
    clear_selection(player)
    return
  end

  if event.entity and event.entity.valid and event.entity.name == FRAME then
    enforce_frame_limit_and_check(event.entity, player)
  end
end)

-- ===== маркер области =====
local function toggle_area_tool(player)
  local cs = player.cursor_stack
  if cs and cs.valid_for_read and cs.name == SELECTOR then
    cs.clear()
    clear_selection(player)
    return
  end
  if not player.clear_cursor() then
    ftext(player.surface, player.position, {"multibuild.cursor-busy"}, {r = 1, g = 0.6, b = 0.4})
    return
  end
  player.cursor_stack.set_stack({name = SELECTOR, count = 1})
  clear_selection(player)
end

script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name ~= "mb-area-toggle" then return end
  local player = game.get_player(event.player_index)
  if player then toggle_area_tool(player) end
end)

script.on_event("mb-area-toggle", function(event)
  local player = game.get_player(event.player_index)
  if player then toggle_area_tool(player) end
end)

local function rect_from_area(area)
  local lt, rb = area.left_top, area.right_bottom
  local lx, ly = (lt.x or lt[1]), (lt.y or lt[2])
  local rx, ry = (rb.x or rb[1]), (rb.y or rb[2])
  if lx > rx then lx, rx = rx, lx end
  if ly > ry then ly, ry = ry, ly end
  local minx, miny = math.floor(lx), math.floor(ly)
  local maxx, maxy = math.ceil(rx) - 1, math.ceil(ry) - 1
  if maxx < minx then maxx = minx end
  if maxy < miny then maxy = miny end
  return {minx = minx, miny = miny, w = maxx - minx + 1, h = maxy - miny + 1}
end

script.on_event(defines.events.on_player_selected_area, function(event)
  if event.item ~= SELECTOR then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  local surface = player.surface
  local rect = rect_from_area(event.area)
  clear_selection(player)

  if rect.w == 1 and rect.h == 1 then
    click_flow(surface, rect.minx, rect.miny, player, player.force)
    return
  end

  local info = rect_info(surface, rect)
  local candidates = candidates_for_size(rect.w, rect.h)
  if #candidates == 0 then
    ftext(surface, {rect.minx + rect.w / 2, rect.miny + rect.h / 2}, {"multibuild.no-candidate", rect.w, rect.h})
    return
  end

  local existing_plan = find_pending_for_rect(surface, rect)
  local current_target = existing_plan and existing_plan.target or nil

  if #candidates == 1 then
    local target = candidates[1]
    local s = target_sizes()[target]
    local b_dir = defines.direction.north
    if s and rect.w == s.h and rect.h == s.w then
      b_dir = defines.direction.east
    end
    start_build(surface, target, info, player.force, player, nil, b_dir)
  else
    open_menu(player, {mode = "rect", surface_index = surface.index, rect = rect}, candidates, current_target)
  end
end)

script.on_event(defines.events.on_player_alt_selected_area, function(event)
  if event.item ~= SELECTOR then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  clear_selection(player)

  local rect = rect_from_area(event.area)
  local pendings = storage.pendings or {}
  local cancelled = 0
  for i = #pendings, 1, -1 do
    local p = pendings[i]
    if p.surface == player.surface and rects_overlap(rect, p.rect) then
      drop_pending(i)
      cancelled = cancelled + 1
    end
  end
  if cancelled > 0 then
    ftext(player.surface, {rect.minx + rect.w / 2, rect.miny + rect.h / 2},
      {"multibuild.plan-cancelled"}, {r = 1, g = 0.5, b = 0.5})
  end
end)

script.on_event(defines.events.on_player_left_game, function(event)
  if storage.opened_frames then
    storage.opened_frames[event.player_index] = nil
  end
  if storage.menus then
    storage.menus[event.player_index] = nil
  end
  if storage.sel then
    storage.sel[event.player_index] = nil
  end
end)

-- ===== storage & commands =====
commands.add_command("mb-debug", {"multibuild.debug-help"}, function(event)
  storage.debug_enabled = not storage.debug_enabled
  local player = event.player_index and game.get_player(event.player_index)
  local msg = storage.debug_enabled
    and "[MultiBuild] Режим отладки ВКЛЮЧЁН: текстовые сообщения на карте активны."
    or "[MultiBuild] Режим отладки ВЫКЛЮЧЁН: текстовые сообщения на карте скрыты."
  if player then
    player.print(msg)
  else
    game.print(msg)
  end
end)

commands.add_command("multibuild-debug", {"multibuild.debug-help"}, function(event)
  storage.debug_enabled = not storage.debug_enabled
  local player = event.player_index and game.get_player(event.player_index)
  local msg = storage.debug_enabled
    and "[MultiBuild] Режим отладки ВКЛЮЧЁН: текстовые сообщения на карте активны."
    or "[MultiBuild] Режим отладки ВЫКЛЮЧЁН: текстовые сообщения на карте скрыты."
  if player then
    player.print(msg)
  else
    game.print(msg)
  end
end)

script.on_init(function()
  storage.jobs = {}
  storage.menus = {}
  storage.panim_tasks = {}
  storage.sel = {}
  storage.pendings = {}
  storage.opened_frames = {}
  storage.ghost_plans = {}
  storage.pending_recipes = {}
  storage.debug_enabled = false
  pcall(function() rendering.clear("multibuild") end)
end)

script.on_configuration_changed(function()
  storage.jobs = storage.jobs or {}
  storage.menus = storage.menus or {}
  storage.panim_tasks = storage.panim_tasks or {}
  storage.sel = storage.sel or {}
  storage.pendings = storage.pendings or {}
  storage.opened_frames = storage.opened_frames or {}
  storage.ghost_plans = storage.ghost_plans or {}
  storage.pending_recipes = storage.pending_recipes or {}
  if storage.debug_enabled == nil then
    storage.debug_enabled = false
  end
  pcall(function() rendering.clear("multibuild") end)
  if storage.pendings then
    for _, p in ipairs(storage.pendings) do
      if p.render_obj and p.render_obj.valid then
        p.render_obj.destroy()
      end
      p.render_obj = nil
    end
  end
  if storage.storages then
    for _, z in pairs(storage.storages) do
      if z.fill then pcall(rendering.destroy, z.fill) end
      if z.line then pcall(rendering.destroy, z.line) end
    end
    storage.storages = nil
  end
end)
