local q = "__test12__"

local function make_pipe_layers(main_path, w, h, shift)
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
    }
  }
end

local function e1_pipe_pictures()
  return {
    north = make_pipe_layers(
      "/graphics/pipe_picture/assembling-machine-pipe-N.png", --main_path
      71,                                                     --w
      38,                                                     --h
      util.by_pixel_hr(3, 27)                                 --shift
    ),

    east = make_pipe_layers(
      "/graphics/pipe_picture/assembling-machine-pipe-E.png",
      42,
      76,
      util.by_pixel_hr(-47, 2)
    ),

    south = make_pipe_layers(
      "/graphics/pipe_picture/assembling-machine-pipe-S.png",
      88,
      61,
      util.by_pixel_hr(0, -62.5)
    ),

    west = make_pipe_layers(
      "/graphics/pipe_picture/assembling-machine-pipe-W.png",
      39,
      73,
      util.by_pixel_hr(47, 2)
    ),
  }
end

return {
  e1_pipe_pictures = e1_pipe_pictures
}