--[[
script.on_event(defines.events.on_player_mined_item, function(event)
    -- event.item_stack — это стек предмета (LuaItemStack)
    -- event.player_index — ID игрока, который это сделал
    
    local player = game.players[event.player_index]
    local item_name = event.item_stack.name

    if item_name == "iron-ore" then
        player.print("[eq")
    end
end)
]]

--[[
local function tech_unlock(event, name, message)
    if event.research.name == name then
        for _, player in pairs(event.research.force.players) do
            rendering.draw_text{
                text = message,
                surface = player.surface,
                target = player.character, -- привязка к игроку
                target_offset = {0, -2},    -- чуть выше головы
                players = {player},        -- видит только этот игрок
                time_to_live = 300,
                color = {1, 1, 0},
                alignment = "center",
                scale = 2
            }
        end
    end
end
]]
--[[
local function tech_unlock(event, name, message)
    if event.research.name == name then
        for _, player in pairs(event.research.force.players) do
            player.show_message_dialog{
                text = {"", "[font=heading-1]", message, "[/font]"},
                image = "technology/" .. name -- Покажет иконку технологии
            }
        end
    end
end



script.on_event(defines.events.on_research_finished, function(event)
    tech_unlock(event, "fast-inserter", "[color=255,0,0]fuck you[/color]: 123")
end)
]]

--[[
local function tech_unlock(event, name, message, color, time)
    if event.research.name == name then
        for _, player in pairs(event.research.force.players) do
            -- 1. Создаем "голый" текст без рамок
            local label = player.gui.screen.add{
                type = "label",
                name = "text_notify_" .. event.tick, -- уникальное имя
                caption = message
            }
            -- 2. Настраиваем внешний вид (размер и цвет)
            label.style.font = "heading-1" -- самый большой шрифт
            label.style.font_color = color  -- желтый
            label.force_auto_center() -- в центр экрана

            -- 3. Запоминаем, когда удалить (через 3 секунды = 180 тиков)
            storage.timers = storage.timers or {}
            storage.timers[label.name] = {
                player = player,
                destroy_at = event.tick + time
            }
        end
    end
end

script.on_nth_tick(30, function(event)
    if not storage.timers then return end

    for label_name, data in pairs(storage.timers) do
        if event.tick >= data.destroy_at then
            if data.player and data.player.valid then
                if data.player.gui.screen[label_name] then
                    data.player.gui.screen[label_name].destroy()
                end
            end
            storage.timers[label_name] = nil
        end
    end
end)

script.on_event(defines.events.on_research_finished, function(event)
    tech_unlock(event, "fast-inserter", "ТЕХНОЛОГИЯ ИЗУЧЕНА: МАНИПУЛЯТОРЫ", {1, 1, 0}, 180)
end)
]]





----

-- Функция для корректной обрезки UTF-8 строк
local function utf8_sub(str, char_count)
    local bytes = #str
    local current_char = 0
    local i = 1
    while i <= bytes and current_char < char_count do
        local c = string.byte(str, i)
        if c >= 0 and c <= 127 then i = i + 1
        elseif c >= 192 and c <= 223 then i = i + 2
        elseif c >= 224 and c <= 239 then i = i + 3
        elseif c >= 240 and c <= 247 then i = i + 4
        else i = i + 1 end
        current_char = current_char + 1
    end
    return string.sub(str, 1, i - 1), current_char
end


local function queue_tech_message(params)
    storage.msg_queue = storage.msg_queue or {}
    table.insert(storage.msg_queue, params)
end

-- Функция создания интерфейса
local function start_next_message()
    if not storage.msg_queue or #storage.msg_queue == 0 then return end

    local params = table.remove(storage.msg_queue, 1)
    local player = game.players[1] 
    if not player or not player.valid then return end

    local res = player.display_resolution
    local scale = player.display_scale

    local main_flow = player.gui.screen.add{
        type = "flow",
        name = "anim_container",
        ignored_by_interaction = true
    }

    -- НАСТРОЙКА ПОЗИЦИИ
    main_flow.style.width = res.width / scale
    main_flow.style.height = res.height / scale
    main_flow.style.horizontal_align = "center"
    main_flow.style.vertical_align = "top"
    main_flow.style.top_padding = 300
    main_flow.location = {0, 0}

    local words_flow = main_flow.add{
        type = "flow",
        direction = "horizontal"
    }

    local word_data = {}
    for i, w in ipairs(params.words) do
        local wrapper = words_flow.add{type = "flow"}

        local label = wrapper.add{
            type = "label",
            caption = (w.typewriter and "" or w.text)
        }
        label.style.font = "heading-1"
        label.style.font_color = {r=w.color.r, g=w.color.g, b=w.color.b, a=0}
        label.style.padding = 10

        table.insert(word_data, {
            label = label,
            config = w,
            current_chars = 0
        })
    end

    storage.active_anim = {
        player = player,
        flow = main_flow,
        words = word_data,
        start_tick = game.tick,
        duration = params.duration or 200,
        current_word_index = 1
    }
end

script.on_event(defines.events.on_tick, function(event)
    if not storage.active_anim then
        if storage.msg_queue and #storage.msg_queue > 0 then start_next_message() end
        return
    end

    local anim = storage.active_anim
    if not (anim.player.valid and anim.flow.valid) then
        storage.active_anim = nil
        return
    end

    local age = event.tick - anim.start_tick
    local progress = age / anim.duration

    if progress >= 1 then
        anim.flow.destroy()
        storage.active_anim = nil
        return
    end


    local current_word = anim.words[anim.current_word_index]
    if current_word then
        if not current_word.config.typewriter then
            anim.current_word_index = anim.current_word_index + 1
        else
            local speed = current_word.config.char_speed or 2
            if age % speed == 0 then
                current_word.current_chars = current_word.current_chars + 1
                local display_text = utf8_sub(current_word.config.text, current_word.current_chars)
                current_word.label.caption = display_text
                if #display_text >= #current_word.config.text then
                    anim.current_word_index = anim.current_word_index + 1
                end
            end
        end
    end


    for i, word in ipairs(anim.words) do
        local max_opacity = word.config.opacity or 1.0
        local alpha = max_opacity

        local f_in = word.config.fade_in or 0.2
        local f_out = word.config.fade_out or 0.2

        if progress < f_in then
            alpha = (progress / f_in) * max_opacity
        elseif progress > (1 - f_out) then
            alpha = ((1 - progress) / f_out) * max_opacity
        end

        -- Ограничиваем, чтобы не было ошибок
        alpha = math.max(0, math.min(max_opacity, alpha))

        local c = word.config.color
        word.label.style.font_color = {r=c.r, g=c.g, b=c.b, a=alpha}

        -- 2. ТРЯСКА
        if word.config.shake and word.config.shake > 0 and progress < (1 - f_out) then
            local s = word.config.shake
            local off_x = math.random(-s, s)
            local off_y = math.random(-s, s)
            word.label.style.left_padding = 10 + off_x
            word.label.style.right_padding = 10 - off_x
            word.label.style.top_padding = 10 + off_y
            word.label.style.bottom_padding = 10 - off_y
        else
            word.label.style.padding = 10
        end
    end
end)

local function words_text1(text, typewriter, char_speed, shake, color )
    return{
        text = text,
        color = color or {r=1, g=1, b=1},
        opacity = 0.9,
        fade_in = 0.3,
        shake = shake or 0,
        typewriter = typewriter or true,
        char_speed = char_speed or 10
    }
end

script.on_event(defines.events.on_research_finished, function(event)
    if event.research.name == "electronics" then
        queue_tech_message({
            duration = 500,
            words = {
                --words_text1("xyй", true),
                words_text1("aaaaaaaaaaa бля", true, 10, 3, {r=1, g=0, b=0}),
            }
        })
    end
    if event.research.name == "fast-inserter" then
        queue_tech_message({
            duration = 500,
            words = {
                words_text1("xyй", true),
                words_text1("ты еблан 123 suka", true, 10, 3, {r=1, g=0, b=0}),
            }
        })
    end

end)

-- ======================================================================================
-- СПРАВОЧНИК ПАРАМЕТРОВ (words):
-- = [ opacity ] : Прозрачность текста от 0.0 (невидимый) до 1.0 (яркий)
-- = [ text ]    : Текст слова
-- = [ color ]   : Таблица {r, g, b}
-- = [ fade_in ] : Процент времени на появление
-- = [ shake ]   : Сила тряски в пикселях
-- = [ typewriter ] : true/false
-- = [ char_speed ] : Скорость печати
-- ======================================================================================