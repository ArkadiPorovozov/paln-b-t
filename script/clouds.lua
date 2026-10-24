-- Облака над ресурсами генерирует сама карта — autoplace в data-final-fixes.lua.
-- Скрипт их НЕ создаёт и не двигает: облако ставится ровно на тайлы ресурса
-- (та же probability_expression, что и у руды), поэтому совпадение с рудой
-- достигается без runtime.
--
-- Здесь остаётся только разовая чистка старых сейвов: раньше «атмосферные»
-- облака (q-cloud-black) ставил скрипт, и в сохранённых играх они могли
-- остаться. Новые облака (resource-cloud-*) скрипт не трогает — иначе они бы
-- съехали с руды.

-- Атмосферные облака q-cloud-black скрипт больше не создаёт. Прототип оставлен
-- только чтобы старые сейвы с уже созданными облаками загружались; тут же один
-- раз убираем всё, что успело появиться в сейве.
local function remove_random_clouds()
  -- отдельный флаг: старый ssc_random_clouds_removed мог остаться в сейве
  if storage.ssc_random_clouds_removed2 then
    return
  end
  storage.ssc_random_clouds_removed2 = true
  -- служебные поля старой версии с генерацией
  storage.ssc_atmospheric_padded = nil
  storage.ssc_padded_chunks = nil

  for _, surface in pairs(game.surfaces) do
    for _, cloud in pairs(surface.find_entities_filtered{name = "q-cloud-black"}) do
      if cloud.valid then
        cloud.destroy()
      end
    end
  end
end

script.on_init(remove_random_clouds)
script.on_configuration_changed(remove_random_clouds)
-- При обычной загрузке сейва on_configuration_changed не срабатывает, поэтому
-- один раз проверяем на 50-м тике (15/30/60 заняты другими скриптами мода).
script.on_nth_tick(50, remove_random_clouds)
