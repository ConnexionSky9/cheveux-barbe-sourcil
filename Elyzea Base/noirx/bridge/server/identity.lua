--[[
    NOIR X — Pont identité : elyzea_core
    Clé de persistance = citizenid du personnage joué (exports.elyzea_core:GetCitizenId),
    comme elyzea_illegal et elyzea_police. Chaque personnage a donc son propre téléphone,
    ses pseudos, ses conversations et ses blanchiments.

    Tant qu'un joueur n'a pas chargé de personnage, il n'a pas d'identité NOIR X :
    le téléphone ne s'ouvre pas (pas de repli sur la licence, pour ne jamais mélanger
    les données de deux personnages).
]]

Identity = {}

local RES = 'elyzea_core'

function Identity.GetAccountId(src)
    for _, kind in ipairs(Config.Identity.priority) do
        local id = GetPlayerIdentifierByType(src, kind)
        if id and id ~= '' then return id end
    end
    return nil
end

function Identity.GetCharacterId(src)
    if Config.Identity.provider == 'license' then return Identity.GetAccountId(src) end
    if GetResourceState(RES) ~= 'started' then return nil end
    local ok, cid = pcall(function() return exports[RES]:GetCitizenId(src) end)
    if ok and type(cid) == 'string' and cid ~= '' then return cid end
    return nil
end

--- Nom RP du personnage (utilisé uniquement côté staff / journaux, jamais montré aux autres joueurs).
function Identity.GetCharName(src)
    if GetResourceState(RES) == 'started' then
        local ok, name = pcall(function() return exports[RES]:GetCharName(src) end)
        if ok and type(name) == 'string' then return name end
    end
    return GetPlayerName(src) or ('#' .. tostring(src))
end

-- Changement / déconnexion de personnage : on oublie l'ancienne identité et on ferme le téléphone.
local function forget(src)
    src = tonumber(src)
    if not src then return end
    if Players then Players.Forget(src) end
    if Phone and Phone.ForceClose then Phone.ForceClose(src, 'character_changed') end
end
AddEventHandler('elyzea:server:playerUnloaded', function(src) forget(src) end)
AddEventHandler('elyzea:server:playerLoaded', function(src) forget(src) end)
