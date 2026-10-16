require ("util")

local q = "__planet-colors__"

local b = 1

local function conduit_animation()
  return
  {
    layers =
    {
      util.sprite_load(q .. "/graphics/entity/conduit/conduit-animation",
      {
        priority = "high",
        scale = 0.5,
        animation_speed = b,
        frame_count = 60,
      }),
      util.sprite_load(q .. "/graphics/entity/conduit/conduit-hr-shadow",
      {
        priority = "high",
        draw_as_shadow = true,
        scale = 0.5,
        repeat_count = 60,
      }),
-- -- -- -- -- -- -- -- -- -- --
      util.sprite_load(q .. "/graphics/entity/conduit/conduit-color1",
      {
        priority = "high",
        blend_mode = "additive",
        scale = 0.5,
        animation_speed = b,
        frame_count = 60,
        tint = { r = 0.596078431372549, g = 0.0392156862745098, b = 0, a = 1 },
      }),
    }
  }
end

local function conduit_working()
  return
  {

    fadeout = true,
    effect = "flicker",
    animation =
    {
    layers =
    {
      util.sprite_load(q .. "/graphics/entity/conduit/conduit-emission",
      {
        priority = "high",
        blend_mode = "additive",
        scale = 0.5,
        animation_speed = b,
        frame_count = 60,
      }),
      util.sprite_load(q .. "/graphics/entity/conduit/conduit-emission",
      {
        blend_mode = "additive",
        draw_as_light = true,
        scale = 0.5,
        animation_speed = b,
        frame_count = 60,
      }),
    }},
  }
end

local function conduit_color_animation()
  return
  {
    layers =
    {
      util.sprite_load(q .. "/graphics/entity/conduit/conduit-color2",
      {
        priority = "high",
        blend_mode = "additive",
        scale = 0.5,
        animation_speed = b,
        frame_count = 60,
        tint = { r = 1, g = 1, b = 1, a = 1 },
      }),
    }
  }
end

local function assembler_graphics_set()
  return
  {
    layers =
    {
      util.sprite_load("__base__/graphics/entity/assembling-machine-1/assembling-machine-1-base",
      {
        priority = "high",
        frame_count = 1,
        repeat_count = 64,
        scale = 0.5,
      }),
      util.sprite_load("__base__/graphics/entity/assembling-machine-1/assembling-machine-1-anim",
      {
        priority = "high",
        frame_count = 64,
        scale = 0.5,
      }),
      util.sprite_load(q .. "/graphics/entity/sa123",
      {
        priority = "high",
        frame_count = 1,
        repeat_count = 64,
        scale = 0.5,
        width = 253,
        height = 275,
        shift = util.by_pixel( 0, 0),
      }),
      util.sprite_load("__base__/graphics/entity/assembling-machine-1/assembling-machine-1-shadow",
      {
        priority = "high",
        frame_count = 1,
        repeat_count = 64,
        scale = 0.5,
        draw_as_shadow = true,
      }),
    }
  }
end

return
{
    conduit_graphics_set = {
    animation = conduit_animation(),
    working_visualisations = {
      conduit_working(),
      conduit_color_animation(),
    },
  },
  assembler4_graphics_set = {
    animation = assembler_graphics_set(),
  }
}
--conduit

