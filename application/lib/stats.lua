local serialization = require("serialization")
local config        = require("lib/config")

local db = {}

local function load()
    local f = io.open(config.SAVE_FILE, "r")
    if f then
        local content = f:read("*a")
        f:close()
        if content and content ~= "" then
            local ok, data = pcall(serialization.unserialize, content)
            if ok and type(data) == "table" then
                db = data
                return
            end
        end
    end
    db = {}
end

local function save()
    local f = io.open(config.SAVE_FILE, "w")
    if f then
        f:write(serialization.serialize(db))
        f:close()
    end
end

local function add(key, amount)
    db[key] = (db[key] or 0) + amount
end

local function get(key)
    return db[key] or 0
end

return {
    load = load,
    save = save,
    add  = add,
    get  = get,
}
