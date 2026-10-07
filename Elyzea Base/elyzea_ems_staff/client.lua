-- Tablette staff : configuration du métier EMS (réservée au staff du serveur)
local reqId, pending = 0, {}
local function rpc(name, ...)
    reqId = reqId + 1
    local id, p = reqId, promise.new()
    pending[id] = p
    TriggerServerEvent('elyzea_ems:rpc', 'elyzea_ems_staff:rpcResult', id, name, { ... })
    SetTimeout(10000, function() if pending[id] then pending[id] = nil; p:resolve(nil) end end)
    return Citizen.Await(p)
end
RegisterNetEvent('elyzea_ems_staff:rpcResult', function(id, res)
    local p = pending[id]; if p then pending[id] = nil; p:resolve(res) end
end)

local function feed(msg)
    BeginTextCommandThefeedPost('STRING'); AddTextComponentSubstringPlayerName(msg); EndTextCommandThefeedPostTicker(false, false)
end

RegisterCommand('ems_staff', function()
    if GetResourceState('elyzea_ems') ~= 'started' then
        return feed(('~r~La ressource elyzea_ems n\'est pas démarrée~s~ (état : %s). Vérifie server.cfg : ensure elyzea_ems avant ensure elyzea_ems_staff.'):format(GetResourceState('elyzea_ems')))
    end
    local data = rpc('staff_open')
    if not data then return feed('~r~Le serveur ne répond pas.~s~ La ressource elyzea_ems est-elle démarrée ?') end
    if data.denied == 'rp' then return feed('~o~Tu es en mode RP.~s~ Reprends ton service staff (menu admin) pour ouvrir la tablette.') end
    if data.denied then
        return feed(data.viaMenu and '~r~Accès refusé.~s~ Demande la permission « Tablette staff EMS » dans le menu admin.'
            or '~r~Tablette réservée au staff.~s~ Voir le LISEZ-MOI pour obtenir l\'accès.')
    end
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', config = data.config, framework = data.framework })
end)
TriggerEvent('chat:addSuggestion', '/ems_staff', 'Ouvrir la tablette staff EMS')

RegisterNUICallback('close', function(_, cb) SetNuiFocus(false, false); cb({}) end)
RegisterNUICallback('getCoords', function(_, cb)
    local ped = PlayerPedId(); local c = GetEntityCoords(ped)
    cb({ x = c.x, y = c.y, z = c.z - 1.0, h = GetEntityHeading(ped) })
end)
-- Copie la tenue portée (pour l'onglet Tenues)
local PARTS = { { 'tshirt', 8 }, { 'torso', 11 }, { 'decals', 10 }, { 'arms', 3 }, { 'pants', 4 }, { 'shoes', 6 },
    { 'chain', 7 }, { 'bproof', 9 }, { 'mask', 1 }, { 'bags', 5 }, { 'helmet', 'p0' } }
RegisterNUICallback('getOutfit', function(_, cb)
    local ped, o = PlayerPedId(), {}
    for _, part in ipairs(PARTS) do
        if part[2] == 'p0' then o[part[1]] = { GetPedPropIndex(ped, 0), math.max(0, GetPedPropTextureIndex(ped, 0)) }
        else o[part[1]] = { GetPedDrawableVariation(ped, part[2]), GetPedTextureVariation(ped, part[2]) } end
    end
    cb(o)
end)
RegisterNUICallback('save', function(data, cb) TriggerServerEvent('elyzea_ems:save', data); cb({ ok = true }) end)
RegisterNUICallback('openStash', function(data, cb)
    cb({}); SetNuiFocus(false, false)
    TriggerServerEvent('elyzea_ems:openStashById', data.id)
end)
RegisterNUICallback('rpc', function(data, cb) cb(rpc(data.name, table.unpack(data.args or {}))) end)
