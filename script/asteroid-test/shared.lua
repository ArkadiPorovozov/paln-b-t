local shared = {}

shared.surface_name = "ast-test"
-- Астероиды живут только на поверхности космической платформы,
-- поэтому тестовая "поверхность" — это платформа.
shared.platform_name = "ast-test-platform"
shared.platform_planet = "nauvis"
shared.starter_pack = "space-platform-starter-pack"
shared.default_speed = 0.15
shared.default_turn = 0.15
shared.last_create_error = nil

-- 4 больших астероида разных видов (ванильные типы Space Age).
shared.asteroid_size = "big"
shared.asteroid_types = {"metallic", "carbonic", "oxide", "promethium"}
shared.asteroid_offsets = {
  {x = -12, y = -12},
  {x = 12, y = -12},
  {x = 12, y = 12},
  {x = -12, y = 12},
}

-- Имя прототипа астероида для вида; big, если он есть, иначе small.
function shared.asteroid_entity_name(kind)
  local big = shared.asteroid_size .. "-" .. kind .. "-asteroid"
  if prototypes.entity[big] then return big end
  local small = "small-" .. kind .. "-asteroid"
  if prototypes.entity[small] then return small end
  return big
end

function shared.get_state()
  local state = storage.ast_test
  if not state then
    state = {
      running = false,
      speed = shared.default_speed,
      turn = shared.default_turn,
      vel = {x = 0, y = 0},
      asteroids = {}
    }
    storage.ast_test = state
  end
  return state
end

function shared.get_player(event)
  if not event or not event.player_index then return nil end
  local player = game.get_player(event.player_index)
  if player and player.valid then return player end
  return nil
end

function shared.get_surface(state)
  local platform = storage.ast_test_platform
  if platform and platform.valid and platform.surface then
    return platform.surface
  end
  return game.get_surface(state.surface_index or shared.surface_name)
end

return shared