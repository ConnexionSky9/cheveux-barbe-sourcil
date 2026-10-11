-- =====================================================================
--  ELYZEA POLICE - client : socle (état, requêtes, curseur, utilitaires)
-- =====================================================================
PoliceC = { cfg = nil, ui = {} }
local C = PoliceC

function C.Notify(msg, kind) exports.elyzea_core:Notify(msg, kind or 'inform') end

-- État publié par le serveur (affichage seulement)
function C.State() return LocalPlayer.state.police end
function C.IsCop() return C.State() ~= nil end
function C.OnDuty() local s = C.State() return s ~= nil and s.duty == true end
function C.Can(perm) local s = C.State() return s ~= nil and type(s.perms) == 'table' and s.perms[perm] == true end

-- Requête au serveur (permission et données revérifiées là-bas)
function C.Req(action, data)
    local ok, res = pcall(function() return Ely.callback.await('police:req', false, action, data or {}) end)
    if not ok or type(res) ~= 'table' then return { error = 'Le serveur ne répond pas.' } end
    return res
end

-- Requête suivie d'une notification du résultat
function C.Do(action, data)
    local r = C.Req(action, data)
    if r.error then C.Notify(r.error, 'error') elseif r.message then C.Notify(r.message, 'success') end
    return r
end

function C.LoadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

function C.Street(c)
    c = c or GetEntityCoords(PlayerPedId())
    local s1, s2 = GetStreetNameAtCoord(c.x, c.y, c.z)
    local a, b = GetStreetNameFromHashKey(s1), s2 ~= 0 and GetStreetNameFromHashKey(s2) or ''
    local zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
    local street = a ~= '' and a or zone
    if b ~= '' then street = street .. ' / ' .. b end
    if zone ~= '' and zone ~= 'NULL' and street ~= zone then street = street .. ' · ' .. zone end
    return street
end

function C.PlayerFromServerId(sid)
    local pid = GetPlayerFromServerId(tonumber(sid) or -1)
    if pid == -1 then return nil end
    return pid, GetPlayerPed(pid)
end

-- ---------------------------------------------------------------------
-- Curseur : un seul gestionnaire pour tous les écrans (jamais bloqué)
--  keep = true : le joueur peut encore marcher (menu F6)
-- ---------------------------------------------------------------------
local open = {}
local function Refresh()
    local any, keep = false, true
    for _, o in pairs(open) do any = true if not o.keep then keep = false end end
    SetNuiFocus(any, any)
    SetNuiFocusKeepInput(any and keep)
end
function C.Focus(name, on, keepInput)
    if on then open[name] = { keep = keepInput == true } else open[name] = nil end
    Refresh()
end
function C.IsOpen(name) return open[name] ~= nil end
function C.AnyOpen() return next(open) ~= nil end

-- Pendant un écran « garder les touches » : on bloque la caméra, les tirs et Échap du jeu
CreateThread(function()
    while true do
        if next(open) then
            DisableControlAction(0, 1, true) DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true) DisableControlAction(0, 141, true) DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true) DisableControlAction(0, 263, true)
            DisableControlAction(0, 200, true) DisableControlAction(0, 199, true)
            DisableControlAction(0, 37, true)
            Wait(0)
        else
            Wait(250)
        end
    end
end)

-- Fermeture d'un écran demandée par l'interface (Échap, bouton ✕)
RegisterNUICallback('close', function(body, cb)
    cb({})
    local name = body and body.ui
    if name and C.ui[name] and C.ui[name].close then C.ui[name].close(true) else C.Focus(name or '', false) end
end)

-- Requête générique depuis l'interface (tablette, F6…)
RegisterNUICallback('req', function(body, cb)
    cb(C.Req(body.action, body.data))
end)

-- Configuration publique (offenses, statuts, niveaux…)
CreateThread(function()
    while not LocalPlayer.state.police and not C.cfg do Wait(1500) end
    local r = C.Req('init')
    if not r.error then
        C.cfg = r
        SendNUIMessage({ action = 'init', cfg = r })
    end
end)
AddStateBagChangeHandler('police', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    SendNUIMessage({ action = 'state', state = value })
    if value == nil then
        for name, ui in pairs(C.ui) do if ui.close then ui.close(true) end end
    end
end)

-- Arrêt de la ressource : curseur rendu, rien ne reste bloqué
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end)

-- Secours : /police_debloquer rend toujours le curseur
RegisterCommand('police_debloquer', function()
    for name, ui in pairs(C.ui) do if ui.close then ui.close(true) end end
    open = {}
    Refresh()
    SendNUIMessage({ action = 'closeAll' })
end, false)

-- ---------------------------------------------------------------------
-- État de l'agent en service pour la carte de la tablette :
-- à terre / mort et rue actuelle (envoyés seulement quand ils changent)
-- ---------------------------------------------------------------------
CreateThread(function()
    local lastLife, lastStreet, nextStreet = nil, nil, 0
    while true do
        local wait = 3000
        if C.OnDuty() then
            wait = 1000
            local ped, st = PlayerPedId(), LocalPlayer.state
            local life = 'ok'
            if IsEntityDead(ped) or IsPedFatallyInjured(ped) or st.isDead or st.dead then life = 'dead'
            elseif st.inLastStand or st.laststand or st.emsDown or IsPedDeadOrDying(ped, true) then life = 'down' end
            if life ~= lastLife then lastLife = life st:set('policeLife', life, true) end
            if GetGameTimer() >= nextStreet then
                nextStreet = GetGameTimer() + 4000
                local street = C.Street()
                if street ~= lastStreet then lastStreet = street st:set('policeStreet', street, true) end
            end
        elseif lastLife then
            lastLife, lastStreet = nil, nil
            LocalPlayer.state:set('policeLife', nil, true)
            LocalPlayer.state:set('policeStreet', nil, true)
        end
        Wait(wait)
    end
end)
