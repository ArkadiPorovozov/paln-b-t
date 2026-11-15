local shared = require("script.asteroid-test.shared")
local surface_module = require("script.asteroid-test.surface")

require("script.asteroid-test.cursor")
require("script.asteroid-test.steer")
require("script.asteroid-test.commands")

remote.add_interface("ast-test", {
  state = function()
    local state = shared.get_state()
    local surf = shared.get_surface(state)
    local parts = {
      "running=" .. tostring(state.running),
      "surface=platform",
      "steering=persist",
      "speed=" .. tostring(state.speed),
      "surface_valid=" .. tostring(surf ~= nil)
    }
    local valid = 0
    local positions = {}
    for _, record in ipairs(state.asteroids or {}) do
      local entity = record.entity
      if entity and entity.valid then
        valid = valid + 1
        positions[#positions + 1] = ("%s@%.1f,%.1f"):format(tostring(record.kind), entity.position.x, entity.position.y)
      end
    end
    parts[#parts + 1] = "asteroids=" .. valid
    if #positions > 0 then
      parts[#parts + 1] = "list=" .. table.concat(positions, "|")
    end
    if state.target then
      parts[#parts + 1] = ("target=%.3f,%.3f"):format(state.target.x, state.target.y)
    end
    parts[#parts + 1] = "create_error=" .. tostring(shared.last_create_error)
    return table.concat(parts, " ")
  end,
  cleanup = function()
    return surface_module.cleanup()
  end
})
