--[[
    NOIR X — Correspondance joueur connecté ↔ personnage
    Players.CharOf(src)   → charId (mis en cache)
    Players.SrcOf(charId) → server id du joueur connecté, ou nil
    Si ton serveur permet de changer de personnage sans se déconnecter, appelle
    exports.noirx:RefreshPlayer(src) après chaque changement.
]]

Players = { cache = {} }

function Players.CharOf(src)
    src = tonumber(src)
    if not src then return nil end
    local c = Players.cache[src]
    if c then return c end
    if not GetPlayerName(src) then return nil end
    c = Identity.GetCharacterId(src)
    Players.cache[src] = c
    return c
end

function Players.SrcOf(charId)
    if not charId then return nil end
    for src, c in pairs(Players.cache) do
        if c == charId then
            if GetPlayerName(src) then return src end
            Players.cache[src] = nil
        end
    end
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        if src and Players.CharOf(src) == charId then return src end
    end
    return nil
end

function Players.Forget(src)
    Players.cache[tonumber(src) or -1] = nil
end

exports('RefreshPlayer', function(src)
    Players.Forget(src)
    if Phone and Phone.ForceClose then Phone.ForceClose(tonumber(src), 'character_changed') end
end)

AddEventHandler('playerDropped', function()
    Players.Forget(source)
end)
