--probably memory leaks

local GetDebugId = game.GetDebugId
local get_thread_identity = syn.get_thread_identity
local set_thread_identity = syn.set_thread_identity

local module = {}

local spoofTable = {}

if issignalhooked(game.ItemChanged) then
    error("[Signal Spoofer] game.ItemChanged is already hooked. Signal Spoofer cannot continue.")
end
hooksignal(game.ItemChanged, function(info, item, property)
    local identity = get_thread_identity()
    set_thread_identity(7)
    local itemId = GetDebugId(item)
    set_thread_identity(identity)

    local spoof = spoofTable[itemId]
    if spoof then
        for _, v in spoof do
            if v[property] == false then
                return false
            end
        end
    end
    return true, item, property
end)

local getIndex = function(item)
    if not game:IsLoaded() then
        game.Loaded:Wait() --some debug ids change while the game is loading
    end
    local id = GetDebugId(item)
    local found = spoofTable[id]
    if found then
        return found
    end
    local spoof = setmetatable({}, {
        __index = {
            ActivePropertySpoofs = {}
        }
    })

    if issignalhooked(item.Changed) then
        error("[Signal Spoofer] " .. item:GetFullName() .. ".Changed is already hooked. Signal Spoofer cannot continue.")
    end
    hooksignal(item.Changed, function(info, property)
        for _, v in pairs(spoof) do
            if v[property] == false then
                return false
            end
        end
        return true, property
    end)

    spoofTable[id] = spoof
    return spoof
end

module.GetSpoofTable = function(item, id)
    local main = getIndex(item)
    local activeSpoofs = main.ActivePropertySpoofs
    local found = main[id]
    if found then
        return found
    end
    local index = {}
    local spoof = setmetatable({}, {
        __index = index,
        __newindex = function(t, k, v)
            local valid, result = pcall(function()
                return item[k]
            end)
            if valid then
                index[k] = v
                if not activeSpoofs[k] then
                    if typeof(result) == "RBXScriptSignal" then
                        if issignalhooked(result) then
                            return error("[Signal Spoofer] " .. item:GetFullName() .. "." .. k .. ") is already hooked. Signal Spoofer cannot continue.")
                        end
                        hooksignal(result, function(info, ...)
                            for _, v in main do
                                if v[k] == false then
                                    return false
                                end
                            end
                            return true, ...
                        end)
                    else
                        if issignalhooked(item:GetPropertyChangedSignal(k)) then
                            return error("[Signal Spoofer] " .. item:GetFullName() .. ":GetPropertyChangedSignal(" .. k .. ") is already hooked. Signal Spoofer cannot continue.")
                        end
                        hooksignal(item:GetPropertyChangedSignal(k), function(info, ...)
                            for _, v in main do
                                if v[k] == false then
                                    return false
                                end
                            end
                            return true, ...
                        end)
                    end
                    activeSpoofs[k] = true
                end
            else
                return error("[Signal Spoofer] Invalid property name: " .. tostring(k))
            end
        end
    })
    main[id] = spoof
    return spoof
end

return module