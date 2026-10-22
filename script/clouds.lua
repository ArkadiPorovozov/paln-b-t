-- Облака над атмосферной рудой.
-- Ставим их скриптом после генерации чанка: если делать это через autoplace,
-- облака занимают тайлы раньше руды и руда под ними не появляется.
-- Облака статичны (не двигаются), просто проигрывают свою анимацию.
--
-- Облако ставится на КАЖДЫЙ тайл руды: спрайт 2x2 тайла, соседние облака
-- перекрываются, поэтому пятно руды закрыто без дырок.
--
-- Прозрачность при "скрыть высокие объекты" делает сам движок:
-- у прототипа облака стоит tall = true.

local cloud_for_ore = {
  ["q1-ore"] = "q1-cloud-white",
  ["q2-ore"] = "q2-cloud-orange",
}

script.on_event(defines.events.on_chunk_generated, function(event)
  local surface = event.surface
  local area = event.area

  for ore_name, cloud_name in pairs(cloud_for_ore) do
    for _, ore in pairs(surface.find_entities_filtered{area = area, name = ore_name}) do
      surface.create_entity{
        name = cloud_name,
        position = ore.position,
        force = "neutral",
      }
    end
  end
end)
