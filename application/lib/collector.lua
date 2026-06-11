local config   = require("lib/config")
local stats    = require("lib/stats")

-- Опрашивает все машины, возвращает:
--   groups       -- { [tech_process] = { [circuit_type] = { ... } } }
--   free         -- { count_machines, active_crafts }
--   to_remove    -- список адресов с ошибкой для удаления из реестра
local function collect(machines)
    local groups    = {}
    local free      = { count_machines = 0, active_crafts = 0 }
    local to_remove = {}
    local stats_changed = false

    local max_name_len  = 0
    local max_ratio_len = 0

    for addr, mData in pairs(machines) do
        local ok, info = pcall(mData.proxy.getSensorInformation)

        if not ok or not info then
            table.insert(to_remove, addr)
        else
            local found_imprint = nil
            local has_meta_id   = false

            for _, line in ipairs(info) do
                local clean = line:gsub("§.", "")
                if clean:find("Imprinted with:") then
                    found_imprint = clean:gsub("Imprinted with: ", ""):match("^%s*(.-)%s*$")
                    break
                elseif clean:find("Meta%-ID:") or clean:find("Recipe:") then
                    has_meta_id = true
                end
            end

            if found_imprint and found_imprint ~= "" then
                mData.last_known_circuit = found_imprint
            elseif not has_meta_id then
                mData.last_known_circuit = nil
            end

            local full_name = mData.last_known_circuit

            local work_ok, is_working = pcall(mData.proxy.hasWork)
            local working = work_ok and is_working

            local chips_min, chips_hour = 0, 0
            if working then
                local prog_ok, max_prog = pcall(mData.proxy.getWorkMaxProgress)
                if prog_ok and max_prog and max_prog > 0 then
                    local dur = max_prog / 20
                    chips_min  = (60   / dur) * 16
                    chips_hour = (3600 / dur) * 16
                    mData.current_recipe_duration = dur
                end
                mData.is_working_last_tick = true
            else
                if mData.is_working_last_tick and full_name then
                    stats.add(full_name, 16)
                    stats_changed = true
                end
                mData.is_working_last_tick = false
            end

            if not full_name then
                free.count_machines = free.count_machines + 1
                if working then free.active_crafts = free.active_crafts + 1 end
            else
                local tech, ctype = full_name:match("^(.+)%s+(%a+)$")
                if not tech or not ctype then
                    tech  = "Other"
                    ctype = full_name
                end

                if not groups[tech] then groups[tech] = {} end
                if not groups[tech][ctype] then
                    groups[tech][ctype] = {
                        count_machines       = 0,
                        active_crafts        = 0,
                        total_chips_per_min  = 0,
                        total_chips_per_hour = 0,
                        full_circuit_key     = full_name,
                    }
                end

                local item = groups[tech][ctype]
                item.count_machines = item.count_machines + 1
                if working then
                    item.active_crafts        = item.active_crafts + 1
                    item.total_chips_per_min  = item.total_chips_per_min  + chips_min
                    item.total_chips_per_hour = item.total_chips_per_hour + chips_hour
                end

                local ratio_str = string.format("%d/%d", item.active_crafts, item.count_machines)
                if #ctype     > max_name_len  then max_name_len  = #ctype     end
                if #ratio_str > max_ratio_len then max_ratio_len = #ratio_str end
            end
        end
    end

    if stats_changed then stats.save() end

    return groups, free, to_remove, max_name_len, max_ratio_len
end

-- Разбивает groups на постраничные куски под конкретную высоту экрана.
-- Возвращает список страниц: { { techs = {...}, ... }, ... }
-- Каждая страница содержит список техпроцессов которые в неё влезают.
local function paginate(groups, free, scrH, max_name_len, max_ratio_len)
    -- Считаем строки нужные на один техпроцесс
    local function linesForTech(tech, ctypes)
        local n = 1  -- заголовок "== Техпроцесс =="
        for _ in pairs(ctypes) do n = n + 1 end
        n = n + 1    -- разделитель
        return n
    end

    -- Сортировка техпроцессов
    local sorted_tech = {}
    for tech in pairs(groups) do
        if tech ~= "Other" then table.insert(sorted_tech, tech) end
    end
    table.sort(sorted_tech)
    if groups["Other"] then table.insert(sorted_tech, "Other") end

    local HEADER_LINES = 4  -- шапка + пустая строка
    local FOOTER_LINES = 1  -- "Выход: Ctrl+Alt+C"
    local FREE_LINES   = free.count_machines > 0 and 2 or 0
    local available    = scrH - HEADER_LINES - FOOTER_LINES

    local pages   = {}
    local current = { techs = {}, lines_used = 0 }

    for _, tech in ipairs(sorted_tech) do
        local needed = linesForTech(tech, groups[tech])
        -- Если не влезает и страница не пустая — новая страница
        if current.lines_used + needed > available and #current.techs > 0 then
            table.insert(pages, current)
            current = { techs = {}, lines_used = 0 }
        end
        table.insert(current.techs, tech)
        current.lines_used = current.lines_used + needed
    end

    -- Свободные машины добавляем на последнюю страницу
    if free.count_machines > 0 then
        if current.lines_used + FREE_LINES > available and #current.techs > 0 then
            table.insert(pages, current)
            current = { techs = {}, lines_used = 0 }
        end
        current.has_free = true
        current.lines_used = current.lines_used + FREE_LINES
    end

    if #current.techs > 0 or current.has_free then
        table.insert(pages, current)
    end

    if #pages == 0 then
        table.insert(pages, { techs = {}, lines_used = 0 })
    end

    return pages, sorted_tech
end

return {
    collect  = collect,
    paginate = paginate,
}
