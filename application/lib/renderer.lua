local config = require("lib/config")
local stats  = require("lib/stats")

local function new(gpu_proxy)
    local R   = {}
    local gpu = gpu_proxy
    local max_lines_printed = 0

    local function sortedCtypes(ctypes_map)
        local list = {}
        for ctype in pairs(ctypes_map) do table.insert(list, ctype) end
        table.sort(list, function(a, b)
            local oa = config.CIRCUIT_ORDER[a] or 99
            local ob = config.CIRCUIT_ORDER[b] or 99
            if oa ~= ob then return oa < ob end
            return a < b
        end)
        return list
    end

    function R.drawPage(page, groups, free, total_machines, page_num, total_pages, max_name_len, max_ratio_len)
        -- Читаем разрешение свежо каждый кадр
        local scrW, scrH = gpu.getResolution()
        local current_lines = 0

        local function smartPrint(text, color)
            if current_lines >= scrH then return end
            gpu.setForeground(color or config.COLOR_WHITE)
            local padded = text .. string.rep(" ", math.max(0, scrW - #text))
            gpu.set(1, current_lines + 1, padded:sub(1, scrW))
            current_lines = current_lines + 1
        end

        local border_heavy = string.rep("=", scrW)
        local border_thin  = string.rep("-", scrW)

        -- Шапка
        local page_str = total_pages > 1
            and string.format(" [%d/%d]", page_num, total_pages)
            or ""
        smartPrint(border_heavy, config.COLOR_GRAY)
        smartPrint(string.format(" МОНИТОРИНГ CAL (Онлайн: %d)%s", total_machines, page_str), config.COLOR_GOLD)
        smartPrint(border_heavy, config.COLOR_GRAY)
        smartPrint("", config.COLOR_WHITE)

        if total_machines == 0 then
            smartPrint(" Ожидание подключения линий...", config.COLOR_ORANGE)
        else
            local name_fmt  = string.format("%%-%ds", max_name_len)
            local ratio_fmt = string.format("%%-%ds", max_ratio_len)

            for _, tech in ipairs(page.techs) do
                smartPrint("== Техпроцесс: " .. tech .. " ==", config.COLOR_CYAN)

                for _, ctype in ipairs(sortedCtypes(groups[tech])) do
                    local data       = groups[tech][ctype]
                    local total_done = stats.get(data.full_circuit_key)

                    local name_str  = string.format(name_fmt, ctype)
                    local ratio_str = string.format(ratio_fmt,
                        string.format("%d/%d", data.active_crafts, data.count_machines))
                    local total_str = string.format("[Всего:%d]", total_done)

                    if data.active_crafts > 0 then
                        local speed = string.format("РАБОТА | %5.1f шт/м | %5.0f шт/ч",
                            data.total_chips_per_min, data.total_chips_per_hour)
                        smartPrint(string.format(" %s %s %s %s", name_str, ratio_str, speed, total_str),
                            config.COLOR_GREEN)
                    else
                        smartPrint(string.format(" %s %s %s %s", name_str, ratio_str,
                            "ЖДЁТ   |   0.0 шт/м |     0 шт/ч", total_str),
                            config.COLOR_ORANGE)
                    end
                end

                smartPrint(border_thin, config.COLOR_GRAY)
            end

            if page.has_free and free.count_machines > 0 then
                local name_part = "[Свободные]"
                local ratio_str = string.format("%d/%d", free.active_crafts, free.count_machines)
                local padding   = string.rep(" ", math.max(0, max_name_len - #name_part + 1))
                local ratio_pad = string.rep(" ", math.max(0, max_ratio_len - #ratio_str))
                smartPrint(string.format(" %s%s%s%s", name_part, padding, ratio_str, ratio_pad),
                    config.COLOR_GRAY)
                smartPrint(border_thin, config.COLOR_GRAY)
            end
        end

        -- Футер всегда последней строкой
        smartPrint("Выход: Ctrl + Alt + C", config.COLOR_GRAY)

        -- Затираем хвост от предыдущего кадра
        if current_lines < max_lines_printed then
            gpu.fill(1, current_lines + 1, scrW, max_lines_printed - current_lines, " ")
        end
        max_lines_printed = current_lines
    end

    function R.init()
        local maxW, maxH = gpu.maxResolution()
        local w = math.floor(maxW / config.SCALE)
        local h = math.floor(maxH / config.SCALE)
        gpu.setResolution(w, h)
        gpu.fill(1, 1, w, h, " ")
    end

    function R.restore(old_w, old_h)
        gpu.setForeground(config.COLOR_WHITE)
        gpu.setResolution(old_w, old_h)
        gpu.fill(1, 1, old_w, old_h, " ")
    end

    function R.getResolution()
        return gpu.getResolution()
    end

    return R
end

return { new = new }
