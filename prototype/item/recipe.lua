local item_sounds = require("__base__.prototypes.item_sounds")
local item_tints = require("__base__.prototypes.item-tints")
local space_age_item_sounds = require("__space-age__.prototypes.item_sounds")


















--[[ -- not use (test//1)
local q = "__glass-furnace__"

local function make_hr_pipe_layers(main_path, w, h, shift)
  return {
    layers = {
      {
        filename = q .. main_path,
        priority = "extra-high",
        width = w,
        height = h,
        shift = shift or {0, 0},
        scale = 0.5,
      },

    --  {
    --    filename = q .. shadow_path,
    --    priority = "extra-high",
    --    width = 88,
    --    height = 64,
    --    shift = shadow_shift or shift or {0, 0},
    --    scale = 0.5,
    --    draw_as_shadow = true,
    --  }

    }
  }
end

local function glass_furnace_pipe_pictures()
  return {
    north = make_hr_pipe_layers(
      "/graphics/pipe_picture/assembling-machine-pipe-N.png", --main_path
      71,                                                     --w
      38,                                                     --h
      {0, 0}                                                  --shift
    ),

    east = make_hr_pipe_layers(
      "/graphics/pipe_picture/assembling-machine-pipe-E.png",
      42,
      76,
      util.by_pixel_hr(-47, 2)
    ),

    south = make_hr_pipe_layers(
      "/graphics/pipe_picture/assembling-machine-pipe-S.png",
      88,
      61,
      util.by_pixel_hr(0, -62.5)
    ),

    west = make_hr_pipe_layers(
      "/graphics/pipe_picture/assembling-machine-pipe-W.png",
      39,
      73,
      util.by_pixel_hr(47, 2)
    ),
  }
end

return {
  glass_furnace_pipe_pictures = glass_furnace_pipe_pictures
}
]]


