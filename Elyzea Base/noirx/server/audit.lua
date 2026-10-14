--[[
    NOIR X — Journal d'audit
    Écrit dans la table noirx_audit si une base est disponible, sinon dans la console.
]]

Audit = {}

function Audit.Log(src, action, details)
    local charId = src and src > 0 and Identity.GetCharacterId(src) or 'system'
    local payload = details and json.encode(details) or nil
    if DB.driver ~= 'none' then
        CreateThread(function()
            DB.Insert('INSERT INTO noirx_audit (actor, action, details) VALUES (?, ?, ?)',
                { charId or 'unknown', action, payload })
        end)
    end
    NoirX.Debug(('[audit] %s %s %s'):format(tostring(charId), action, payload or ''))
end
