local component = require("component")
local event     = require("event")

local machines = {}
local _handlers = {}

local function addMachine(addr)
    if component.type(addr) == "gt_machine" and not machines[addr] then
        machines[addr] = {
            proxy                = component.proxy(addr),
            last_known_circuit   = nil,
            is_working_last_tick = false,
            current_recipe_duration = 0,
        }
    end
end

local function removeMachine(addr)
    machines[addr] = nil
end

local function onComponentChange(evt, addr, comp_type)
    if evt == "component_added" and comp_type == "gt_machine" then
        addMachine(addr)
    elseif evt == "component_removed" then
        removeMachine(addr)
    end
end

local function init()
    for addr in component.list("gt_machine") do
        addMachine(addr)
    end
    event.listen("component_added",   onComponentChange)
    event.listen("component_removed", onComponentChange)
    _handlers = { onComponentChange }
end

local function shutdown()
    event.ignore("component_added",   onComponentChange)
    event.ignore("component_removed", onComponentChange)
end

local function getAll()
    return machines
end

local function count()
    local n = 0
    for _ in pairs(machines) do n = n + 1 end
    return n
end

return {
    init         = init,
    shutdown     = shutdown,
    getAll       = getAll,
    count        = count,
    removeMachine = removeMachine,
}
