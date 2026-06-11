-- Добавляем lib/ в путь поиска модулей
package.path = "/home/cal/lib/?.lua;" .. package.path

local component = require("component")
local term      = require("term")
local event     = require("event")

local config    = require("lib/config")
local machines  = require("lib/machines")
local stats     = require("lib/stats")
local collector = require("lib/collector")
local renderer  = require("lib/renderer")

-- Инициализация рендереров: bind GPU к экрану и установка разрешения
local renderers = {}
local old_res   = {}

for i, mon in ipairs(config.MONITORS) do
    local ok, gpu_proxy = pcall(component.proxy, mon.gpu)
    if not ok or not gpu_proxy then
        print("Предупреждение: GPU " .. mon.gpu .. " не найден, пропускаем.")
    else
        -- Bind GPU к нужному экрану (персистентно на время сессии)
        local bind_ok, bind_err = pcall(gpu_proxy.bind, mon.screen)
        if not bind_ok then
            print("Предупреждение: не удалось привязать GPU к экрану: " .. tostring(bind_err))
        end

        local ow, oh = gpu_proxy.getResolution()
        old_res[#renderers + 1] = { ow, oh }

        local r = renderer.new(gpu_proxy)
        r.init()
        table.insert(renderers, r)
    end
end

if #renderers == 0 then
    print("Ошибка: ни один GPU не доступен.")
    return
end

machines.init()
stats.load()
term.clear()

local function cleanup()
    machines.shutdown()
    stats.save()
    for i, r in ipairs(renderers) do
        local ow, oh = old_res[i][1], old_res[i][2]
        r.restore(ow, oh)
    end
    local main_gpu = component.gpu
    main_gpu.setForeground(config.COLOR_WHITE)
    term.clear()
    print("Мониторинг остановлен, статы сохранены.")
end

while true do
    local all_machines   = machines.getAll()
    local total_machines = machines.count()

    local groups, free, to_remove, max_name_len, max_ratio_len =
        collector.collect(all_machines)

    for _, addr in ipairs(to_remove) do
        machines.removeMachine(addr)
    end

    -- Берём высоту с первого рендерера для пагинации
    local _, scrH = renderers[1].getResolution()
    local pages   = collector.paginate(groups, free, scrH, max_name_len, max_ratio_len)
    local total_pages = #pages

    for i, r in ipairs(renderers) do
        local page = pages[i]
        if page then
            r.drawPage(page, groups, free, total_machines, i, total_pages, max_name_len, max_ratio_len)
        else
            -- Монитор без контента — пустая страница
            r.drawPage(
                { techs = {}, has_free = false },
                free, total_machines, i, total_pages, max_name_len, max_ratio_len
            )
        end
    end

    local ev = event.pull(1, "interrupted")
    if ev == "interrupted" then
        cleanup()
        break
    end
end
