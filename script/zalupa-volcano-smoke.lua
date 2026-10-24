-- Небольшой тёмный дым над лавой.
--
-- Дым не является сущностью и не хранится в сейве: это короткоживущие
-- trivial-smoke облачка. Раз в пару секунд берём случайный лавовый тайл
-- рядом с игроком и выпускаем дымок. Так на далёких островах не крутится
-- лишняя симуляция, а рядом с вулканом дым выглядит живым.

local SMOKE_NAME = "magma-eruption-dark-smoke"
local FALLBACK_SMOKE = "smoke"
local SEARCH_RADIUS = 48
local EMIT_INTERVAL = 240

local function smoke_name()
  if prototypes and prototypes.trivial_smoke and prototypes.trivial_smoke[SMOKE_NAME] then
    return SMOKE_NAME
  end
  return FALLBACK_SMOKE
end

local function emit_smoke(surface, tile, name)
  if not surface or not tile or not tile.valid then return end

  local position = tile.position
  pcall(function()
    surface.create_trivial_smoke{
      name = name,
      position = {
        position.x + (math.random() - 0.5) * 0.7,
        position.y + (math.random() - 0.5) * 0.7
      },
      vertical_speed = 0.012 + math.random() * 0.012
    }
  end)
end

script.on_nth_tick(EMIT_INTERVAL, function()
  local name = smoke_name()

  for _, player in pairs(game.connected_players) do
    if player.valid and player.surface and player.surface.name == "zalupa" then
      local tiles = player.surface.find_tiles_filtered{
        position = player.position,
        radius = SEARCH_RADIUS,
        name = { "lava", "lava-hot" }
      }

      if #tiles > 0 then
        emit_smoke(player.surface, tiles[math.random(#tiles)], name)

        -- Изредка добавляем второй дымок, чтобы над большим лавовым
        -- пятном не было ощущения одной одинокой струйки.
        if #tiles > 2 and math.random() < 0.3 then
          emit_smoke(player.surface, tiles[math.random(#tiles)], name)
        end
      end
    end
  end
end)
