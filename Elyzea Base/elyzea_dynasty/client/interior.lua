-- =====================================================================
--  ELYZEA DYNASTY 8 - client : intérieur des biens
--  · Entrée / sortie (fondu, IPL de l'intérieur, sol).
--  · Cercles : ROUGE sortie, BLEU gestion, ORANGE coffre ; garage : places et véhicules.
--  · Véhicules du garage et décoration : objets locaux recréés à chaque entrée à partir
--    des données du serveur (rien n'est gardé côté client).
--  · Sonnette, invitation de visite, offre de vente / location : fenêtres d'acceptation.
-- =====================================================================
local C = D8C
local core = exports.elyzea_core
local COL = Config.Points.colors
local I = nil               -- intérieur courant { pid, area, kind, points, rights, role }
local shown = { vehicles = {}, deco = {} }

local function Fade(out)
    if out then DoScreenFadeOut(350) local t = GetGameTimer() + 1000 while not IsScreenFadedOut() and GetGameTimer() < t do Wait(0) end
    else DoScreenFadeIn(450) end
end

local function Teleport(p)
    local ped = PlayerPedId()
    RequestCollisionAtCoord(p.x + 0.0, p.y + 0.0, p.z + 0.0)
    SetEntityCoords(ped, p.x + 0.0, p.y + 0.0, p.z + 0.0, false, false, false, false)
    if p.h then SetEntityHeading(ped, p.h + 0.0) end
    local t = GetGameTimer() + 2500
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do Wait(0) end
end

-- ---------------------------------------------------------------------
-- Objets locaux : véhicules garés, décoration
-- ---------------------------------------------------------------------
local function Clear(list)
    for _, e in pairs(list) do if DoesEntityExist(e.ent or e) then DeleteEntity(e.ent or e) end end
end
local function LoadModel(m)
    if not IsModelInCdimage(m) then return false end
    RequestModel(m)
    local t = GetGameTimer() + 4000
    while not HasModelLoaded(m) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(m)
end

local function ShowVehicles()
    Clear(shown.vehicles) shown.vehicles = {}
    if not I or I.area ~= 'garage' then return end
    local r = C.Pub('garageList', { pid = I.pid })
    I.slots = r.slots or I.points.slots or {}
    for _, v in ipairs(r.list or {}) do
        local s = I.slots[v.slot]
        local model = joaat(v.model)
        if s and LoadModel(model) then
            local veh = CreateVehicle(model, s.x + 0.0, s.y + 0.0, s.z + 0.0, (s.h or 0.0) + 0.0, false, false)
            SetEntityAsMissionEntity(veh, true, true)
            SetVehicleOnGroundProperly(veh)
            core:SetVehicleProperties(veh, v.props or {})
            SetVehicleNumberPlateText(veh, v.plate or '')
            FreezeEntityPosition(veh, true)
            SetVehicleDoorsLocked(veh, 2)
            SetEntityInvincible(veh, true)
            SetModelAsNoLongerNeeded(model)
            shown.vehicles[#shown.vehicles + 1] = { ent = veh, id = v.id, mine = v.mine, plate = v.plate, model = v.model,
                bike = IsThisModelABike(model), heli = IsThisModelAHeli(model), boat = IsThisModelABoat(model) }
        end
    end
end
RegisterNetEvent('d8:client:garageRefresh', function() if I and I.area == 'garage' then ShowVehicles() end end)
RegisterNetEvent('d8:client:points', function(points)
    if not I or type(points) ~= 'table' then return end
    I.points = points
    if points.slots then I.slots = points.slots end
end)

local function ShowDeco()
    Clear(shown.deco) shown.deco = {}
    if not I or I.area ~= 'home' then return end
    local r = C.Pub('decoList', { pid = I.pid })
    for _, o in ipairs(r.list or {}) do
        local m = joaat(o.model)
        if LoadModel(m) then
            local obj = CreateObjectNoOffset(m, o.x + 0.0, o.y + 0.0, o.z + 0.0, false, false, false)
            SetEntityRotation(obj, (o.rx or 0) + 0.0, (o.ry or 0) + 0.0, (o.rz or 0) + 0.0, 2, true)
            FreezeEntityPosition(obj, true)
            SetModelAsNoLongerNeeded(m)
            shown.deco[#shown.deco + 1] = { ent = obj, id = o.id, model = o.model }
        end
    end
end
RegisterNetEvent('d8:client:decoRefresh', function() if I and I.area == 'home' then ShowDeco() end end)
function C.DecoShown() return shown.deco end
function C.Inside() return I end

-- ---------------------------------------------------------------------
-- Entrée / sortie (ordonnées par le serveur)
-- ---------------------------------------------------------------------
RegisterNetEvent('d8:client:enter', function(d)
    Fade(true)
    for _, ipl in ipairs(d.ipls or {}) do RequestIpl(ipl) end
    Teleport(d.spawn)
    I = { pid = d.pid, area = d.area, kind = d.kind, points = d.points or {}, rights = d.rights or {}, role = d.role, name = d.name, admin = d.admin }
    C.insideData = I
    if d.area == 'garage' then ShowVehicles() elseif d.area == 'home' then ShowDeco() end
    Fade(false)
    C.Notify(d.area == 'garage' and ('Garage · %s'):format(d.name) or d.area == 'test' and ('Test de l\'intérieur « %s » : /d8sortir pour revenir.'):format(d.name)
        or ('Bienvenue · %s'):format(d.name), 'inform')
end)

RegisterNetEvent('d8:client:exit', function(p, reason)
    if C.DecoCancel then C.DecoCancel() end
    Fade(true)
    Clear(shown.vehicles) Clear(shown.deco)
    shown = { vehicles = {}, deco = {} }
    I = nil
    C.insideData = nil
    if p then Teleport(p) end
    Fade(false)
    if reason then C.Notify(reason, 'inform') end
end)

-- Sortie d'un véhicule du garage : on monte au volant dès que le véhicule existe
RegisterNetEvent('d8:client:garageOut', function(netId, props, sp)
    Fade(true)
    Clear(shown.vehicles) Clear(shown.deco)
    shown = { vehicles = {}, deco = {} }
    I = nil
    C.insideData = nil
    Teleport({ x = sp.x, y = sp.y, z = sp.z + 1.0, h = sp.h })
    local t = GetGameTimer() + 6000
    while not NetworkDoesNetworkIdExist(netId) and GetGameTimer() < t do Wait(50) end
    local veh = NetworkDoesNetworkIdExist(netId) and NetToVeh(netId) or 0
    if veh ~= 0 then
        local t2 = GetGameTimer() + 2000
        while not NetworkHasControlOfEntity(veh) and GetGameTimer() < t2 do NetworkRequestControlOfEntity(veh) Wait(0) end
        core:SetVehicleProperties(veh, props or {})
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    end
    Fade(false)
end)

-- ---------------------------------------------------------------------
-- Cercles intérieurs et touche E
-- ---------------------------------------------------------------------
local function NearVehicle(pc)
    local best, bd
    for _, v in ipairs(shown.vehicles) do
        if DoesEntityExist(v.ent) then
            local d = #(pc - GetEntityCoords(v.ent))
            if d < 3.2 and (not bd or d < bd) then best, bd = v, d end
        end
    end
    return best
end

local function Label3D(p, text)
    SetDrawOrigin(p.x + 0.0, p.y + 0.0, p.z + 0.2, 0)
    SetTextScale(0.32, 0.32) SetTextFont(4) SetTextCentre(true) SetTextOutline()
    BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName(text) EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

CreateThread(function()
    while true do
        if not I or C.AnyOpen() or (C.DecoEditing and C.DecoEditing()) then Wait(300) else
            local pc = GetEntityCoords(PlayerPedId())
            local prompt, action
            local pts = I.points
            local function circle(p, color, label, fn, allowed)
                if not p or p.on == false then return end
                C.Circle(p, color, p.r)
                if I.admin then Label3D(p, label) end
                if allowed ~= false and #(pc - C.Vec(p)) <= (p.r or 1.2) + 0.3 then prompt, action = '~INPUT_CONTEXT~ ' .. label, fn end
            end
            if I.area == 'home' then
                circle(pts.exit, COL.exit, 'Sortir', function() C.Show(C.Pub('exit')) end)
                circle(pts.manage, COL.manage, 'Gestion du logement', function() if C.OpenManage then C.OpenManage(I.pid) end end, I.role ~= nil or I.admin)
                circle(pts.stash, COL.stash, 'Coffre', function() C.Show(C.Pub('stash', { pid = I.pid })) end, (I.rights and I.rights.stash) == true)
            elseif I.area == 'garage' then
                circle(pts.exit, COL.garage_exit, 'Sortir du garage', function() C.Show(C.Pub('exit')) end)
                if I.admin then
                    for i, s in ipairs(I.slots or pts.slots or {}) do
                        DrawMarker(43, s.x, s.y, s.z - 0.95, 0, 0, 0, 0, 0, (s.h or 0.0) + 0.0, 2.4, 5.0, 0.2, 59, 130, 246, 60, false, false, 2, false, nil, nil, false)
                        Label3D(s, ('Place %d'):format(i))
                    end
                end
                local v = NearVehicle(pc)
                if v then
                    Label3D(GetEntityCoords(v.ent) + vector3(0, 0, 1.0), ('%s · %s'):format(v.model, v.plate or ''))
                    if v.mine then prompt, action = ('~INPUT_CONTEXT~ Sortir ce véhicule (%s)'):format(v.plate or ''), function()
                        local vtype = v.bike and 'bike' or v.heli and 'heli' or v.boat and 'boat' or 'automobile'
                        C.Show(C.Pub('garageTake', { pid = I.pid, id = v.id, vtype = vtype }))
                    end end
                end
            elseif I.area == 'test' then
                C.Help('Test d\'intérieur : /d8sortir pour revenir.')
            end
            if prompt then
                C.Help(prompt)
                if IsControlJustPressed(0, Config.Keys.interact) then action() end
            end
            Wait(0)
        end
    end
end)

-- ---------------------------------------------------------------------
-- Sonnette (résident) · invitation de visite (client) · offre de contrat (client)
-- ---------------------------------------------------------------------
RegisterNetEvent('d8:client:bell', function(b)
    PlaySoundFrontend(-1, 'DOOR_BUZZ', 'MP_PLAYER_APARTMENT', true)
    SendNUIMessage({ action = 'bell', bell = b })
end)
RegisterNetEvent('d8:client:bellClosed', function(id) SendNUIMessage({ action = 'bellClosed', id = id }) end)
RegisterNUICallback('bellAnswer', function(body, cb) cb({}) TriggerServerEvent('d8:server:bellAnswer', tonumber(body.id), body.accept == true) end)

local prompt = nil   -- fenêtre d'acceptation en cours : 'invite' | 'offer'
local function ClosePrompt()
    if not prompt then return end
    prompt = nil
    C.Focus('prompt', false)
    SendNUIMessage({ action = 'prompt', show = false })
end
C.ui.prompt = { close = function()
    if prompt == 'invite' then TriggerServerEvent('d8:server:visitAnswer', false)
    elseif type(prompt) == 'table' then TriggerServerEvent('d8:server:offerAnswer', prompt.uid, false) end
    ClosePrompt()
end }

RegisterNetEvent('d8:client:visitInvite', function(d)
    if prompt then ClosePrompt() end
    prompt = 'invite'
    C.Focus('prompt', true)
    SendNUIMessage({ action = 'prompt', show = true, kind = 'invite', data = d })
    SetTimeout((d.timeout or 30) * 1000, function() if prompt == 'invite' then ClosePrompt() end end)
end)
RegisterNetEvent('d8:client:offer', function(d)
    if prompt then ClosePrompt() end
    prompt = { uid = d.uid }
    C.Focus('prompt', true)
    SendNUIMessage({ action = 'prompt', show = true, kind = 'offer', data = d })
    SetTimeout((d.timeout or 60) * 1000, function() if type(prompt) == 'table' and prompt.uid == d.uid then ClosePrompt() end end)
end)
RegisterNUICallback('promptAnswer', function(body, cb)
    cb({})
    if prompt == 'invite' then TriggerServerEvent('d8:server:visitAnswer', body.accept == true)
    elseif type(prompt) == 'table' then TriggerServerEvent('d8:server:offerAnswer', prompt.uid, body.accept == true) end
    ClosePrompt()
end)

-- Visite commerciale (agent) : GPS vers l'entrée
RegisterNetEvent('d8:client:visit', function(v)
    C.visit = v
    if v and v.enter then SetNewWaypoint(v.enter.x + 0.0, v.enter.y + 0.0) end
    SendNUIMessage({ action = 'visit', visit = v })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    Clear(shown.vehicles) Clear(shown.deco)
    if IsScreenFadedOut() then DoScreenFadeIn(0) end
end)
