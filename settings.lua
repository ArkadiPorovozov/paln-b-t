data:extend({
  {
    type = "bool-setting",
    name = "pcg-enabled",
    setting_type = "runtime-global",
    default_value = true,
    order = "a"
  },
  {
    type = "double-setting",
    name = "pcg-guard-radius",
    setting_type = "runtime-global",
    default_value = 14,
    minimum_value = 4,
    maximum_value = 64,
    order = "b"
  },
  {
    type = "int-setting",
    name = "pcg-respawn-seconds",
    setting_type = "runtime-global",
    default_value = 5,
    minimum_value = 1,
    maximum_value = 600,
    order = "c"
  }
})
