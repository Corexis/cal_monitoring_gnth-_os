local config = {}

-- Адреса GPU в порядке страниц
-- Страница 1 -> GPUS[1], Страница 2 -> GPUS[2]
config.GPUS = {
    "a11284b1-6293-46d6-b341-cdd7fa3bc154",
    "4e2ecd4c-c4ad-4855-9fa4-2d009abab9eb",
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
config.COLOR_RED    = 0xFF4444

return config
