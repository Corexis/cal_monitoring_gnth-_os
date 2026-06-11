local config = {}

-- Пары GPU -> Screen в порядке страниц
-- Страница 1 -> MONITORS[1], Страница 2 -> MONITORS[2]
config.MONITORS = {
    {
        gpu    = "a11284b1-6293-46d6-b341-cdd7fa3bc154",
        screen = "1f535934-87cb-452d-babf-5bd86288db5d",
    },
    {
        gpu    = "4e2ecd4c-c4ad-4855-9fa4-2d009abab9eb",
        screen = "5fd6904f-f26c-47dc-947e-5f17e4a54be1",
    },
}

-- Масштаб экрана (2 = крупный шрифт)
config.SCALE = 2

-- Файл сохранения статистики
config.SAVE_FILE = "/home/cal_total_stats.txt"

-- Порядок типов плат внутри техпроцесса
config.CIRCUIT_ORDER = {
    ["Processor"]     = 1,
    ["Assembly"]      = 2,
    ["Supercomputer"] = 3,
    ["SuperComputer"] = 3,
    ["Mainframe"]     = 4,
}

-- Цвета
config.COLOR_GOLD   = 0xFFD700
config.COLOR_GREEN  = 0x00FF00
config.COLOR_ORANGE = 0xFF8C00
config.COLOR_WHITE  = 0xFFFFFF
config.COLOR_GRAY   = 0x808080
config.COLOR_CYAN   = 0x00FFFF

return config
