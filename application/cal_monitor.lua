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

-- Инициализация рендереров для каждого GPU
local renderers  = {}
local old_res    = {}

for i, gpu_addr in ipairs(config.GPUS) do
    local ok, gpu_proxy = pcall(component.proxy, gpu_addr)
    if ok and gpu_proxy then
        local r = renderer.new(gpu_proxy)
        local ow, oh = gpu_proxy.getResolution()
        old_res[i] = { ow, oh }
        r.init()
        table.insert(renderers, r)
    else
        print("Предупреждение: GPU " .. gpu_addr .. " не найден, пропускаем.")
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
        local ow, oh = table.unpack(old_res[i])
        r.restore(ow, oh)
    end
    -- Восстанавливаем основной терминал
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

    -- Берём высоту экрана с первого рендерера для пагинации
    local _, scrH = renderers[1].getResolution()

    local pages, _ = collector.paginate(groups, free, scrH, max_name_len, max_ratio_len)
    local total_pages = #pages

    -- Распределяем страницы по мониторам
    -- Монитор 1 -> страница 1, Монитор 2 -> страница 2, и т.д.
    -- Если страниц больше чем мониторов — остаток на последнем мониторе
    for i, r in ipairs(renderers) do
        local page = pages[i]
        if page then
            r.drawPage(page, groups, free, total_machines, i, total_pages, max_name_len, max_ratio_len)
        else
            -- Монитор без страницы — показываем заглушку
            local _, scrH2 = r.getResolution()
            local scrW2, _ = r.getResolution()
            -- Пустой экран с подписью
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
