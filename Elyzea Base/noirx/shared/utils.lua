NoirX = NoirX or {}

function NoirX.Debug(...)
    if Config.Debug then
        print(('^5[noirx]^7 %s'):format(table.concat({ ... }, ' ')))
    end
end

function NoirX.Warn(...)
    print(('^3[noirx]^7 %s'):format(table.concat({ ... }, ' ')))
end

function NoirX.Error(...)
    print(('^1[noirx]^7 %s'):format(table.concat({ ... }, ' ')))
end

function NoirX.Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

--- Liste des applications activées (copie sans fonctions, envoyable en NUI).
function NoirX.EnabledApps()
    local out = {}
    for _, app in ipairs(Config.Apps) do
        if app.enabled then
            out[#out + 1] = { id = app.id, label = app.label }
        end
    end
    return out
end
