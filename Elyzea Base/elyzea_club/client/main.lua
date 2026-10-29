-- =====================================================================
--  ELYZEA BOÎTE DE NUIT - client : socle (état, requêtes, curseur, utilitaires)
-- =====================================================================
CLC = { cfg = nil, ui = {} }
local C = CLC

function C.Notify(msg, kind) exports.elyzea_core:Notify(msg, kind or 'inform') end

-- État publié par le serveur (affichage seulement)
function C.State() return LocalPlayer.state.club end
function C.IsMember() return C.State() ~= nil end
-- À terre (coma d'elyzea_ems) : pas d'action de employé
function C.IsDown() return LocalPlayer.state.emsDown == true end
function C.OnDuty() local s = C.State() return s ~= nil and s.duty == true end
function C.Can(perm) local s = C.State() return s ~= nil and type(s.perms) == 'table' and s.perms[perm] == true end

-- Requête au serveur (permission et données revérifiées là-bas)
function C.Req(action, data)
    local ok, res = pcall(function() return Ely.callback.await('club:req', false, action, data or {}) end)
    if not ok or type(res) ~= 'table' then return { error = 'Le serveur ne répond pas.' } end
    return res
end

-- Requêtes publiques (tous les joueurs : entrée, carte, commande) et staff (administration)
function C.Pub(action, data)
    local ok, res = pcall(function() return Ely.callback.await('club:pub', false, action, data or {}) end)
    if not ok or type(res) ~= 'table' then return { error = 'Le serveur ne répond pas.' } end
    return res
end
function C.Adm(action, data)
    local ok, res = pcall(function() return Ely.callback.await('club:admin', false, action, data or {}) end)
    if not ok or type(res) ~= 'table' then return { error = 'Le serveur ne répond pas.' } end
    return res
end
function C.Show(r)
    if r.error then C.Notify(r.error, 'error') elseif r.message then C.Notify(r.message, r.warning and 'inform' or 'success') end
    return r
end

function C.Help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end
function C.Vec(p) return p and vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0) or nil end
-- Cercle au sol aux couleurs du point
function C.Circle(p, color, r)
    r = (tonumber(r) or 1.2)
    DrawMarker(25, p.x, p.y, p.z - 0.97, 0, 0, 0, 0, 0, 0, r * 2.0, r * 2.0, 1.0, color[1], color[2], color[3], 170, false, false, 2, false, nil, nil, false)
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
RegisterNUICallback('pub', function(body, cb) cb(C.Pub(body.action, body.data)) end)
RegisterNUICallback('adm', function(body, cb) cb(C.Adm(body.action, body.data)) end)
RegisterNUICallback('gps', function(body, cb)
    cb({})
    if tonumber(body.x) and tonumber(body.y) then SetNewWaypoint(tonumber(body.x) + 0.0, tonumber(body.y) + 0.0) C.Notify('Itinéraire tracé.', 'success') end
end)

-- Configuration publique (statuts, niveaux, appels…)
CreateThread(function()
    Wait(2000)
    local r = C.Pub('init')
    if not r.error then
        C.cfg = r
        SendNUIMessage({ action = 'init', cfg = r })
    end
end)
AddStateBagChangeHandler('club', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
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

-- Secours : /club_debloquer rend toujours le curseur
RegisterCommand('club_debloquer', function()
    for name, ui in pairs(C.ui) do if ui.close then ui.close(true) end end
    open = {}
    Refresh()
    SendNUIMessage({ action = 'closeAll' })
end, false)

-- Joueur le plus proche
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

-- /club_pos : position et cap (aide)
RegisterCommand('club_pos', function()
    local ped = PlayerPedId()
    local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    local txt = ('vector3(%.2f, %.2f, %.2f) -- cap %.1f'):format(c.x, c.y, c.z, h)
    print('[CLUB] ' .. txt)
    C.Notify('Position copiée dans la console (F8) : ' .. txt, 'inform')
end, false)

