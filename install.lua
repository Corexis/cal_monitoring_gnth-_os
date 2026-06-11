local component = require("component")
local internet  = require("internet")
local fs        = require("filesystem")

local REPO     = "https://raw.githubusercontent.com/Corexis/cal_monitoring_gnth-_os/dev"
local DEST     = "/home/cal"

local FILES = {
    { src = "application/cal_monitor.lua",      dst = DEST .. "/cal_monitor.lua" },
    { src = "application/lib/config.lua",       dst = DEST .. "/lib/config.lua" },
    { src = "application/lib/machines.lua",     dst = DEST .. "/lib/machines.lua" },
    { src = "application/lib/stats.lua",        dst = DEST .. "/lib/stats.lua" },
    { src = "application/lib/collector.lua",    dst = DEST .. "/lib/collector.lua" },
    { src = "application/lib/renderer.lua",     dst = DEST .. "/lib/renderer.lua" },
}

local function download(url, path)
    local dir = path:match("^(.*)/[^/]+$")
    if dir and not fs.exists(dir) then
        fs.makeDirectory(dir)
    end

    local response, err = internet.request(url)
    if not response then
        return false, "Нет ответа от сервера: " .. tostring(err)
    end

    local data = ""
    local ok, read_err = pcall(function()
        for chunk in response do
            data = data .. chunk
        end
    end)

    if not ok then
        return false, "Ошибка чтения: " .. tostring(read_err)
    end

    if #data == 0 then
        return false, "Пустой ответ (файл не найден?)"
    end

    local f, open_err = io.open(path, "w")
    if not f then
        return false, "Не удалось открыть файл для записи: " .. tostring(open_err)
    end
    f:write(data)
    f:close()
    return true
end

print("=== Установка CAL Monitor ===")
print("Репозиторий: " .. REPO)
print("Назначение:  " .. DEST)
print("")

local failed = false
for _, file in ipairs(FILES) do
    local url = REPO .. "/" .. file.src
    io.write("Скачиваю " .. file.dst .. " ... ")
    local ok, err = download(url, file.dst)
    if ok then
        print("OK")
    else
        print("ОШИБКА: " .. tostring(err))
        failed = true
    end
end

print("")
if failed then
    print("Установка завершена с ошибками. Проверь подключение к сети.")
else
    print("Установка успешна!")
    print("Запуск: lua /home/cal/cal_monitor.lua")
end
