local shared = require("script.asteroid-test.shared")

script.on_event("ast-test-set-target", function(event)
  if event.in_gui then return end
  local player = shared.get_player(event)
  if not player then return end
  local state = storage.ast_test
  if not state or not state.running then return end
  local surf = shared.get_surface(state)
  if not (surf and surf.valid) or player.surface_index ~= surf.index then return end
  local pos = event.cursor_position
  if not pos then return end
  state.target = {x = pos.x, y = pos.y}
end)
