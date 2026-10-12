-- =====================================================================
--  ELYZEA MÉCANO - client : socle (état, requêtes, curseur, utilitaires)
-- =====================================================================
MecaC = { cfg = nil, ui = {} }
local C = MecaC

function C.Notify(msg, kind) exports.elyzea_core:Notify(msg, kind or 'inform') end

-- État publié par le serveur (affichage seulement)
function C.State() return LocalPlayer.state.meca end
function C.IsMeca() return C.State() ~= nil end
-- À terre (coma d'elyzea_ems) : pas d'action de mécanicien
function C.IsDown() return LocalPlayer.state.emsDown == true end
function C.OnDuty() local s = C.State() return s ~= nil and s.duty == true end
function C.Can(perm) local s = C.State() return s ~= nil and type(s.perms) == 'table' and s.perms[perm] == true end

-- Requête au serveur (permission et données revérifiées là-bas)
function C.Req(action, data)
    local ok, res = pcall(function() return Ely.callback.await('meca:req', false, action, data or {}) end)
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

-- Configuration publique (statuts, niveaux, appels…)
CreateThread(function()
    Wait(2000)
    local r = C.Req('init')
    if not r.error then
        C.cfg = r
        SendNUIMessage({ action = 'init', cfg = r })
    end
end)
AddStateBagChangeHandler('meca', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
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

-- Secours : /meca_debloquer rend toujours le curseur
RegisterCommand('meca_debloquer', function()
    for name, ui in pairs(C.ui) do if ui.close then ui.close(true) end end
    open = {}
    Refresh()
    SendNUIMessage({ action = 'closeAll' })
end, false)

-- ---------------------------------------------------------------------
-- Rue actuelle du mécanicien en service (carte de la tablette), envoyée quand elle change
-- ---------------------------------------------------------------------
CreateThread(function()
    local lastStreet = nil
    while true do
        if C.OnDuty() then
            local street = C.Street()
            if street ~= lastStreet then lastStreet = street LocalPlayer.state:set('mecaStreet', street, true) end
            Wait(4000)
        else
            if lastStreet then lastStreet = nil LocalPlayer.state:set('mecaStreet', nil, true) end
            Wait(3000)
        end
    end
end)

-- Véhicule le plus proche
function C.ClosestVehicle(pos, radius)
    local best, bestD
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(veh) - pos)
        if d <= radius and (not bestD or d < bestD) then best, bestD = veh, d end
    end
    return best
end

-- Progression avec animation (annulable si on bouge trop loin du patient). Renvoie true si terminée
function C.Progress(label, duration, anim, targetPed)
    local ped = PlayerPedId()
    if anim and C.LoadDict(anim[1]) then TaskPlayAnim(ped, anim[1], anim[2], 3.0, 3.0, -1, anim[3] or 1, 0, false, false, false) end
    SendNUIMessage({ action = 'progress', show = true, label = label, duration = duration })
    local stop = GetGameTimer() + duration
    local ok = true
    while GetGameTimer() < stop do
        DisableControlAction(0, 24, true) DisableControlAction(0, 25, true) DisableControlAction(0, 21, true)
        if IsControlJustPressed(0, 73) or IsPedRagdoll(ped) or C.IsDown()
            or (targetPed and (not DoesEntityExist(targetPed) or #(GetEntityCoords(targetPed) - GetEntityCoords(ped)) > Config.Distances.vehicle + 2.0)) then
            ok = false
            break
        end
        Wait(0)
    end
    SendNUIMessage({ action = 'progress', show = false })
    if anim then StopAnimTask(ped, anim[1], anim[2], 1.0) end
    ClearPedTasks(ped)
    return ok
end

-- Joueur le plus proche (client du devis)
function C.NearestPlayer(radius)
    local pc = GetEntityCoords(PlayerPedId())
    local best, bestD
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local d = #(GetEntityCoords(GetPlayerPed(pid)) - pc)
            if d <= radius and (not bestD or d < bestD) then best, bestD = GetPlayerServerId(pid), d end
        end
    end
    return best, bestD
end

function C.ModelLabel(veh)
    local name = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
    local label = GetLabelText(name)
    return (label and label ~= 'NULL' and label ~= '') and label or name
end
function C.Plate(veh) return ((GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

-- /meca_pos : position et cap au format de Config.Workshops (pour placer les points d'atelier)
RegisterCommand('meca_pos', function()
    local ped = PlayerPedId()
    local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    local txt = ('vector3(%.2f, %.2f, %.2f) -- cap %.1f'):format(c.x, c.y, c.z, h)
    print('[MECA] ' .. txt)
    C.Notify('Position copiée dans la console (F8) : ' .. txt, 'inform')
end, false)
