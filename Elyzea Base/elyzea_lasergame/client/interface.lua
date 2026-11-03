-- =====================================================================
--  ELYZEA LASERGAME - INTERFACE (pont NUI <-> serveur)
--  L'interface n'appelle le serveur que par la liste blanche ci-dessous ; le serveur revérifie tout.
--  NUI suspendue quand elle est fermée : aucune boucle, aucun message envoyé.
-- =====================================================================
local ALLOWED = {
    ['ui:init'] = true, ['profile:get'] = true, ['history:get'] = true, ['lb:get'] = true, ['list:get'] = true,
    ['pvp:create'] = true, ['pvp:update'] = true, ['pvp:join'] = true, ['pvp:quick'] = true, ['pvp:team'] = true, ['pvp:weapon'] = true,
    ['pvp:ready'] = true, ['pvp:invite'] = true, ['pvp:kick'] = true, ['pvp:start'] = true, ['lobby:leave'] = true, ['lobby:nearby'] = true,
    ['zb:create'] = true, ['zb:join'] = true, ['zb:ready'] = true, ['zb:start'] = true, ['zb:kick'] = true, ['zb:invite'] = true,
    ['spectate:join'] = true,
    ['admin:open'] = true, ['admin:games'] = true, ['admin:set'] = true, ['admin:map'] = true, ['admin:npc'] = true, ['admin:game'] = true,
    ['admin:players.search'] = true, ['admin:players.get'] = true, ['admin:players.set'] = true, ['admin:logs'] = true, ['admin:stats'] = true,
}
-- Actions avant lesquelles l'apparence RP est envoyée au serveur (sauvegarde des vêtements)
local SEND_LOOK = { ['pvp:ready'] = true, ['zb:ready'] = true, ['zb:create'] = true, ['spectate:join'] = true, ['pvp:start'] = true, ['zb:start'] = true }

function C.OpenUI(tab, admin)
    if C.inGame and not admin then return end
    if C.uiOpen then return end
    if IsPauseMenuActive() then return end
    local ok, data = RPC.Call('ui:init')
    if not ok then return C.Notify(data or 'LaserGame indisponible.', 'error') end
    C.uiOpen = true
    SetNuiFocus(true, true)
    C.UI('open', { init = data, tab = tab or 'home', admin = admin == true, settings = C.settings })
    RPC.Call('ui:watch', true)
    C.Sound('open', 0.6)
end

function C.CloseUI()
    if not C.uiOpen then return end
    C.uiOpen = false
    SetNuiFocus(false, false)
    C.UI('close')
    CreateThread(function() RPC.Call('ui:watch', false) end)
end

RegisterNUICallback('close', function(_, cb) cb(1) C.CloseUI() end)

RegisterNUICallback('rpc', function(d, cb)
    local name = type(d) == 'table' and d.name or nil
    if not ALLOWED[name] then return cb({ ok = false, err = 'Action refusée.' }) end
    if SEND_LOOK[name] then C.SendLook() Wait(150) end
    local args = type(d.args) == 'table' and d.args or {}
    local res = table.pack(RPC.Call(name, table.unpack(args, 1, 6)))
    cb({ ok = res[1] == true, data = res[2], extra = res[3], err = res[1] ~= true and (res[2] or 'Erreur.') or nil })
end)

RegisterNUICallback('settings', function(d, cb)
    cb(1)
    if type(d) ~= 'table' then return end
    C.settings.volume = LGU.Clamp(tonumber(d.volume) or C.settings.volume, 0, 1)
    C.settings.effects = d.effects ~= false
    C.settings.hudScale = LGU.Clamp(tonumber(d.hudScale) or 1, 0.7, 1.4)
    SetResourceKvp('lg_settings', json.encode(C.settings))
end)

CreateThread(function()
    local raw = GetResourceKvpString('lg_settings')
    if raw then
        local ok, s = pcall(json.decode, raw)
        if ok and type(s) == 'table' then for k, v in pairs(s) do C.settings[k] = v end end
    end
end)

-- Ouverture depuis un PNJ de l'éditeur de map (admin_menu) ou une autre ressource
AddEventHandler('elyzea_lasergame:client:open', function() C.OpenUI('home') end)
exports('OpenUI', function(tab) C.OpenUI(tab) end)

-- ---------------------------------------------------------------- données en direct
RegisterNetEvent('elyzea_lasergame:list', function(list) if C.uiOpen then C.UI('list', list) end end)
RegisterNetEvent('elyzea_lasergame:lobby', function(view) C.UI('lobby', view) end)
RegisterNetEvent('elyzea_lasergame:lobbyClosed', function(uid, reason)
    C.UI('lobbyClosed', { uid = uid, reason = reason })
end)
RegisterNetEvent('elyzea_lasergame:gameClosed', function(uid) if C.uiOpen then C.UI('gameClosed', { uid = uid }) end end)

-- Invitation : l'acceptation passe par l'interface (et exige d'être auprès d'un PNJ LaserGame)
RegisterNetEvent('elyzea_lasergame:invite', function(inv)
    C.UI('invite', inv)
    C.Sound('invite', 0.8)
end)
RegisterNUICallback('acceptInvite', function(d, cb)
    cb(1)
    if type(d) ~= 'table' or not d.uid then return end
    if not C.uiOpen then C.OpenUI(d.mode == 'zombie' and 'zombie' or 'pvp') end
    C.UI('acceptInvite', d)
end)
