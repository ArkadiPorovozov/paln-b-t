-- Общие помощники для тайлов (prototype/tiles/*.lua).

local shared = {}

local graphics = "__paln-b-test__/graphics/terrain/"
shared.graphics = graphics

function shared.texture(name)
  return graphics .. name
end

-- Добавляет tile_name в to_tiles переходов заданной группы у ОДНОГО тайла.
-- Список to_tiles предварительно копируется (deepcopy): правка касается только
-- этого тайла и не меняет общие ванильные списки water_tile_type_names /
-- lava_tile_type_names / out_of_map_tile_type_names, на которые ссылаются
-- тайлы всех планет и других модов.
function shared.add_border_to(tile, transition_group_id, tile_name)
  if not tile then
    return
  end
  local function patch(list)
    for _, transition in ipairs(list or {}) do
      if transition.transition_group == transition_group_id then
        local to_tiles = table.deepcopy(transition.to_tiles) or {}
        local found = false
        for _, name in ipairs(to_tiles) do
          if name == tile_name then
            found = true
            break
          end
        end
        if not found then
          to_tiles[#to_tiles + 1] = tile_name
        end
        transition.to_tiles = to_tiles
      end
    end
  end
  patch(tile.transitions)
  patch(tile.transitions_between_transitions)
end

-- Настраиваем родной out-of-map переход копии так, чтобы движок сам рисовал
-- вулканическую кромку к тёмной воде. Спрайт и layout родные, цвет не трогаем;
-- в to_tiles ванильной записи перечислены
-- {"out-of-map", "empty-space", "oil-ocean-shallow"} — добавляем туда
-- "dark-deep-lake". Список принадлежит глубокой копии тайла, ванильные тайлы
-- не затрагиваются. Все остальные переходы (вода/лава/обычные тайлы) остаются
-- родными.
--
-- Слой: в ванили этот background лежит в "zero" — ниже воды, потому что сосед
-- там out-of-map без шейдера. У нас сосед — тёмная вода с водным шейдером,
-- который рисуется выше "zero" и полностью закрывает кромку. Поэтому кладём
-- background в "water-overlay": по описанию движка это группа для «переходов
-- к воде, которые должны быть под тайлами». Она выше водного шейдера и ниже
-- ground-natural, то есть кромка видна над водой и остаётся под плиткой —
-- так же, как выглядит ванильная кромка на Вулкане.
-- Кромка к тёмной воде рисуется родным спрайтом out-of-map перехода. Чтобы
-- она «растворялась» вниз (в воду), у спрайта-копии альфа background-колонки
-- притушена книзу: верх кромки непрозрачный, к дальнему краю уходит в 0.
-- (В спрайтшите видимую альфу даёт колонка background; колонка mask — жёсткая
-- маска только 0/255.) Копии лежат в graphics/terrain/volcanic-oom/; сами
-- спрайты готовятся из ванильных скриптом, здесь только подключаем.
local out_of_map_border_copies = {
  ["__space-age__/graphics/terrain/out-of-map-transition/volcanic-out-of-map-transition.png"] =
    graphics .. "volcanic-oom/volcanic-out-of-map-transition.png",
  ["__space-age__/graphics/terrain/out-of-map-transition/volcanic-out-of-map-transition-transition.png"] =
    graphics .. "volcanic-oom/volcanic-out-of-map-transition-transition.png",
}

local function apply_oom_border_copy(list)
  for _, transition in ipairs(list or {}) do
    local copy = out_of_map_border_copies[transition.spritesheet]
    if copy then
      transition.spritesheet = copy
    end
  end
end

function shared.apply_space_border(tile)
  apply_oom_border_copy(tile.transitions)
  apply_oom_border_copy(tile.transitions_between_transitions)
  for _, transition in ipairs(tile.transitions or {}) do
    if transition.transition_group == out_of_map_transition_group_id then
      local to_tiles = transition.to_tiles or {}

      local has_dark_lake = false
      for _, name in ipairs(to_tiles) do
        if name == "dark-deep-lake" then
          has_dark_lake = true
          break
        end
      end
      if not has_dark_lake then
        table.insert(to_tiles, "dark-deep-lake")
      end
      transition.to_tiles = to_tiles

      transition.background_layer_group = "water-overlay"
      transition.background_layer_offset = 1
      transition.offset_background_layer_by_tile_layer = true
    end
  end
end

return shared