-- =====================================================================
--  ELYZEA FUEL - la pompe (client)
--  1. À une pompe : E → le joueur prend le pistolet (tuyau relié à la pompe).
--  2. Près de la trappe à essence d'un véhicule (moteur coupé) : E → le pistolet est inséré.
--  3. Clic droit maintenu → l'essence coule ; on lâche quand on veut. Le petit écran montre
--     l'argent qui monte, les litres et le réservoir qui se remplit.
--  4. Réservoir plein et on continue → l'essence déborde et coule au sol (tache inflammable).
--  5. E → on reprend le pistolet (le plein est payé), E à la pompe → on le raccroche.
--  Tout est validé et facturé par le serveur ; ce fichier ne fait que l'affichage et les intentions.
--  Le tuyau, le pistolet et le débordement des autres joueurs sont visibles (état « fuelHose »).
-- =====================================================================
local P, K = Config.Pump, Config.Controls
local NOZZLE = joaat(P.nozzle)
local PUMPS = {}
for _, m in ipairs(P.models) do PUMPS[#PUMPS + 1] = joaat(m) end
local VIRTUAL_PUMP = joaat('prop_vintage_pump')

-- état local du joueur
local L = { mode = nil, pump = nil, st = nil, info = nil, veh = nil, session = nil, view = nil, pressing = false, lastSend = 0, busy = false }
FuelPump = L

-- ---------------------------------------------------------------------
-- Utilitaires
-- ---------------------------------------------------------------------
local function LoadModel(hash, timeout)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local t = GetGameTimer() + (timeout or 3000)
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(0) end
    return HasModelLoaded(hash)
end

local function LoadDict(dict, timeout)
    RequestAnimDict(dict)
    local t = GetGameTimer() + (timeout or 2000)
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
    return HasAnimDictLoaded(dict)
end

local function UI(action, data) SendNUIMessage({ action = action, data = data }) end

local function Notify(msg, kind)
    if Ely and Ely.notify then return Ely.notify({ description = msg, type = kind or 'inform' }) end
    BeginTextCommandThefeedPost('STRING') AddTextComponentSubstringPlayerName(msg) EndTextCommandThefeedPostTicker(false, false)
end

-- Position de la trappe à essence (os du modèle), sinon arrière gauche du véhicule
local CAP_BONES = { 'petrolcap', 'petroltank', 'petroltank_l', 'petroltank_r', 'hub_lr', 'wheel_lr' }
function FuelCapPos(veh)
    for i = 1, 4 do
        local b = GetEntityBoneIndexByName(veh, CAP_BONES[i])
        if b ~= -1 then return GetWorldPositionOfEntityBone(veh, b), b end
    end
    local mn, mx = GetModelDimensions(GetEntityModel(veh))
    return GetOffsetFromEntityInWorldCoords(veh, mn.x + 0.05, mn.y * 0.55, 0.15), -1
end

-- ---------------------------------------------------------------------
-- Pompes
-- ---------------------------------------------------------------------
-- Pompe du jeu la plus proche (objet + point de départ du tuyau)
local function ClosestPump(pos, radius)
    local best, bestD
    for _, h in ipairs(PUMPS) do
        local o = GetClosestObjectOfType(pos.x, pos.y, pos.z, radius, h, false, false, false)
        if o ~= 0 then
            local d = #(GetEntityCoords(o) - pos)
            if not bestD or d < bestD then best, bestD = o, d end
        end
    end
    return best, bestD
end

-- Stations ajoutées en jeu sans pompe du jeu : une pompe locale est posée au point de la station
local virtual = {}       -- [stationId] = { obj, checked }
local function StationHasPumps(st)
    local v = virtual[st.id]
    if v and v.checked then return v.has end
    local o = ClosestPump(vector3(st.x, st.y, st.z), (st.radius or Config.DefaultRadius) + 4.0)
    virtual[st.id] = { checked = true, has = o ~= nil }
    return o ~= nil
end

local function VirtualPump(st)
    local v = virtual[st.id]
    if v and v.obj and DoesEntityExist(v.obj) then return v.obj end
    if not LoadModel(VIRTUAL_PUMP, 3000) then return nil end
    local ok, gz = GetGroundZFor_3dCoord(st.x + 0.0, st.y + 0.0, st.z + 1.5, false)
    local obj = CreateObjectNoOffset(VIRTUAL_PUMP, st.x + 0.0, st.y + 0.0, (ok and gz or st.z - 1.0) + 0.0, false, false, false)
    SetModelAsNoLongerNeeded(VIRTUAL_PUMP)
    if obj == 0 then return nil end
    SetEntityHeading(obj, st.h or 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    virtual[st.id] = { checked = true, has = false, obj = obj }
    return obj
end

-- Pompe virtuelle créée / supprimée selon la distance (aucun coût au loin)
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for _, st in ipairs(FuelSettings().stations or {}) do
            local d = #(pos - vector3(st.x, st.y, st.z))
            if d < 80.0 and not StationHasPumps(st) then VirtualPump(st)
            elseif d > 100.0 and virtual[st.id] and virtual[st.id].obj then
                if DoesEntityExist(virtual[st.id].obj) then DeleteEntity(virtual[st.id].obj) end
                virtual[st.id].obj = nil
            end
        end
        Wait(2500)
    end
end)

-- Objet pompe le plus proche d'un point (pour accrocher le tuyau chez tout le monde)
local function PumpObjectAt(p)
    local o = ClosestPump(p, 1.5)
    if o then return o end
    for _, v in pairs(virtual) do
        if v.obj and DoesEntityExist(v.obj) and #(GetEntityCoords(v.obj) - p) < 2.0 then return v.obj end
    end
    return nil
end

-- ---------------------------------------------------------------------
-- Tuyaux visibles (le mien et ceux des autres) : pistolet local + corde entre la pompe et le pistolet
-- ---------------------------------------------------------------------
local Hoses = {}         -- [serverId] = { want = {...}, nozzle, rope, pumpObj, ptfx, nextDecal }
local ropeTextures = false

local function RopeReady()
    if ropeTextures then return true end
    RopeLoadTextures()
    local t = GetGameTimer() + 1500
    while not RopeAreTexturesLoaded() and GetGameTimer() < t do Wait(0) end
    ropeTextures = RopeAreTexturesLoaded()
    return ropeTextures
end

local function ClearHose(h)
    if h.ptfx then StopParticleFxLooped(h.ptfx, false) h.ptfx = nil end
    if h.rope and DoesRopeExist(h.rope) then DeleteRope(h.rope) end
    h.rope = nil
    if h.nozzle and DoesEntityExist(h.nozzle) then DetachEntity(h.nozzle, false, false) DeleteEntity(h.nozzle) end
    h.nozzle, h.attached = nil, nil
end

local function PedOf(serverId)
    local pl = GetPlayerFromServerId(serverId)
    if pl == -1 then return nil end
    local ped = GetPlayerPed(pl)
    return ped ~= 0 and DoesEntityExist(ped) and ped or nil
end

-- Pistolet dans la main droite
local function AttachToHand(nozzle, ped)
    AttachEntityToEntity(nozzle, ped, GetPedBoneIndex(ped, 18905), 0.13, 0.04, 0.01, -42.0, -115.0, -63.42, false, true, false, true, 0, true)
end

-- Pistolet planté dans la trappe, orienté vers l'intérieur du véhicule (réglages : Config.Pump.inCar)
local function AttachToCar(nozzle, veh)
    local cap = FuelCapPos(veh)
    local loc = GetOffsetFromEntityGivenWorldCoords(veh, cap.x, cap.y, cap.z)
    local side = loc.x >= 0 and 1.0 or -1.0
    local o = P.inCar or { out = 0.08, up = 0.06, pitch = -35.0 }
    AttachEntityToEntity(nozzle, veh, 0, loc.x + side * (o.out or 0.08), loc.y, loc.z + (o.up or 0.06),
        o.pitch or -35.0, 0.0, side > 0 and 90.0 or -90.0, false, true, false, false, 0, true)
end

-- Bout du pistolet (sortie de l'essence) en coordonnées du monde
local function NozzleTip(h)
    if h.nozzle and DoesEntityExist(h.nozzle) then return GetOffsetFromEntityInWorldCoords(h.nozzle, 0.0, 0.12, -0.05) end
end

local function BuildHose(serverId, h)
    local w = h.want
    local pumpPos = vector3(w.pump.x, w.pump.y, w.pump.z)
    if not LoadModel(NOZZLE, 3000) then return end
    local nozzle = CreateObject(NOZZLE, pumpPos.x, pumpPos.y, pumpPos.z + 1.0, false, false, false)
    if nozzle == 0 then return end
    SetEntityCollision(nozzle, false, false)
    h.nozzle = nozzle
    h.pumpObj = PumpObjectAt(pumpPos)
    if RopeReady() then
        local start = h.pumpObj and GetOffsetFromEntityInWorldCoords(h.pumpObj, 0.0, 0.0, P.hoseHeight) or (pumpPos + vector3(0, 0, P.hoseHeight))
        local rope = AddRope(start.x, start.y, start.z, 0.0, 0.0, 0.0, P.hoseLength, 1, P.hoseLength, 1.0, 0.0, false, false, false, 1.0, false)
        if rope and rope ~= 0 then
            h.rope = rope
            h.ropeStart = start
        end
    end
end

-- Remet chaque tuyau dans l'état voulu (main / trappe), relie la corde, gère le débordement
local function UpdateHose(serverId, h)
    local w = h.want
    local ped = PedOf(serverId)
    if not ped then
        ClearHose(h)
        if GetPlayerFromServerId(serverId) == -1 then Hoses[serverId] = nil end   -- joueur parti
        return
    end
    if not h.nozzle then BuildHose(serverId, h) if not h.nozzle then return end end
    local target = w.mode
    local veh = (target == 'car' and w.veh and NetworkDoesNetworkIdExist(w.veh)) and NetToVeh(w.veh) or 0
    if target == 'car' and veh == 0 then target = 'hand' end
    local key = target .. ':' .. tostring(veh)
    if h.attached ~= key then
        DetachEntity(h.nozzle, false, false)
        if target == 'car' then AttachToCar(h.nozzle, veh) else AttachToHand(h.nozzle, ped) end
        h.attached = key
        if h.rope and DoesRopeExist(h.rope) then
            local tip = GetOffsetFromEntityInWorldCoords(h.nozzle, 0.0, -0.033, -0.195)
            if h.pumpObj and DoesEntityExist(h.pumpObj) then
                AttachEntitiesToRope(h.rope, h.pumpObj, h.nozzle, h.ropeStart.x, h.ropeStart.y, h.ropeStart.z, tip.x, tip.y, tip.z, P.hoseLength, false, false, nil, nil)
            else
                AttachRopeToEntity(h.rope, h.nozzle, tip.x, tip.y, tip.z, false)
                PinRopeVertex(h.rope, 0, h.ropeStart.x, h.ropeStart.y, h.ropeStart.z)
            end
        end
    end
    -- débordement : essence qui coule du pistolet + tache au sol (inflammable, comme dans GTA)
    if w.spill and target == 'car' then
        if not h.ptfx then
            RequestNamedPtfxAsset('core')
            local t = GetGameTimer() + 1500
            while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < t do Wait(0) end
            if HasNamedPtfxAssetLoaded('core') then
                UseParticleFxAssetNextCall('core')
                h.ptfx = StartParticleFxLoopedOnEntity('ent_sht_petrol', h.nozzle, 0.0, 0.1, -0.05, 0.0, 0.0, 0.0, 0.9, false, false, false)
            end
        end
        local now = GetGameTimer()
        if not h.nextDecal or now >= h.nextDecal then
            h.nextDecal = now + (P.spillDecalEvery or 450)
            h.spillSize = math.min(2.6, (h.spillSize or 0.5) + 0.12)
            local tip = NozzleTip(h)
            if tip then
                local ok, gz = GetGroundZFor_3dCoord(tip.x, tip.y, tip.z + 0.5, false)
                AddPetrolDecal(tip.x, tip.y, ok and gz or (tip.z - 0.8), 2.0, h.spillSize, 1.0)
            end
        end
    elseif h.ptfx then
        StopParticleFxLooped(h.ptfx, false)
        h.ptfx = nil
    end
end

-- Données de tuyau d'un joueur (état répliqué « fuelHose »)
local function SetWant(serverId, w)
    local h = Hoses[serverId]
    if not w then
        if h then ClearHose(h) Hoses[serverId] = nil end
        return
    end
    if not h then h = {} Hoses[serverId] = h end
    if h.want and h.want.pump and (math.abs(h.want.pump.x - w.pump.x) > 0.05 or math.abs(h.want.pump.y - w.pump.y) > 0.05) then ClearHose(h) end
    h.want = w
end

AddStateBagChangeHandler('fuelHose', nil, function(bagName, _, value)
    local ply = GetPlayerFromStateBagName(bagName)
    if not ply or ply == 0 then return end
    local sid = GetPlayerServerId(ply)
    SetWant(sid, type(value) == 'table' and type(value.pump) == 'table' and value or nil)
end)

-- Entretien des tuyaux visibles (proches seulement)
CreateThread(function()
    while true do
        local near = false
        local pos = GetEntityCoords(PlayerPedId())
        for sid, h in pairs(Hoses) do
            local w = h.want
            if w and #(pos - vector3(w.pump.x, w.pump.y, w.pump.z)) < 60.0 then
                near = true
                UpdateHose(sid, h)
            elseif h.nozzle then ClearHose(h) end
        end
        Wait(near and 0 or 500)
    end
end)

-- Joueurs déjà avec un pistolet quand on arrive (états reçus avant le chargement)
CreateThread(function()
    Wait(3000)
    for _, ply in ipairs(GetActivePlayers()) do
        local sid = GetPlayerServerId(ply)
        local v = Player(sid).state.fuelHose
        if type(v) == 'table' and type(v.pump) == 'table' then SetWant(sid, v) end
    end
end)

-- ---------------------------------------------------------------------
-- Actions du joueur
-- ---------------------------------------------------------------------
local myId = GetPlayerServerId(PlayerId())

local function ResetLocal()
    L.mode, L.pump, L.st, L.info, L.veh, L.session, L.view, L.pressing = nil, nil, nil, nil, nil, nil, nil, false
    local ped = PlayerPedId()
    if L.anim then StopAnimTask(ped, 'timetable@gardener@filling_can', 'gar_ig_5_filling_can', 1.0) L.anim = false end
    SetWant(myId, nil)
    UI('hide')
end

local function PlayGrab()
    local ped = PlayerPedId()
    if LoadDict('anim@am_hold_up@male', 1500) then
        TaskPlayAnim(ped, 'anim@am_hold_up@male', 'shoplift_high', 6.0, -6.0, 650, 48, 0.0, false, false, false)
    end
end

local function Take(pumpPos, st)
    L.busy = true
    local ped = PlayerPedId()
    SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true)
    TaskTurnPedToFaceCoord(ped, pumpPos.x, pumpPos.y, pumpPos.z, 600)
    local ok, info = Ely.callback.await('elyzea_fuel:take', false, { x = pumpPos.x, y = pumpPos.y, z = pumpPos.z })
    L.busy = false
    if not ok then return Notify(info or 'Impossible de prendre le pistolet.', 'error') end
    PlayGrab()
    L.mode, L.pump, L.st, L.info = 'hand', pumpPos, st, info
    SetWant(myId, { pump = { x = pumpPos.x, y = pumpPos.y, z = pumpPos.z }, mode = 'hand' })
    UI('open', { station = info.label, price = info.price, flowRate = info.flowRate, chargeSpill = info.chargeSpill, mode = 'hand' })
end

local function Insert(veh)
    if GetIsVehicleEngineRunning(veh) then return Notify('Coupe le moteur avant de faire le plein.', 'error') end
    if not UsesFuel(veh) then return Notify('Ce véhicule ne roule pas à l\'essence.', 'error') end
    if not NetworkGetEntityIsNetworked(veh) then return Notify('Ce véhicule ne peut pas être rempli.', 'error') end
    L.busy = true
    local ped = PlayerPedId()
    local cap = FuelCapPos(veh)
    TaskTurnPedToFaceCoord(ped, cap.x, cap.y, cap.z, 600)
    PlayGrab()
    local ok, view, info = Ely.callback.await('elyzea_fuel:insert', false, VehToNet(veh), TankOf(veh))
    L.busy = false
    if not ok then return Notify(view or 'Impossible d\'insérer le pistolet.', 'error') end
    L.mode, L.veh, L.session, L.view = 'car', veh, view.id, view
    SetWant(myId, { pump = { x = L.pump.x, y = L.pump.y, z = L.pump.z }, mode = 'car', veh = VehToNet(veh) })
    UI('state', { mode = 'car', view = view, station = info and info.label, price = view.price })
end

local function StopPumping()
    if L.pressing then
        L.pressing = false
        TriggerServerEvent('elyzea_fuel:pump', L.session, false)
    end
    if L.anim then
        StopAnimTask(PlayerPedId(), 'timetable@gardener@filling_can', 'gar_ig_5_filling_can', 1.0)
        L.anim = false
    end
    UI('pumping', false)
end

local function Remove()
    StopPumping()
    L.busy = true
    PlayGrab()
    Ely.callback.await('elyzea_fuel:remove', false)   -- le ticket arrive par « elyzea_fuel:receipt »
    L.busy = false
    L.mode, L.veh, L.session = 'hand', nil, nil
    SetWant(myId, { pump = { x = L.pump.x, y = L.pump.y, z = L.pump.z }, mode = 'hand' })
    UI('state', { mode = 'hand' })
end

local function Hang()
    StopPumping()
    L.busy = true
    local ok, err = Ely.callback.await('elyzea_fuel:hang', false)
    L.busy = false
    if not ok then return Notify(err or 'Ramène le pistolet à la pompe.', 'error') end
    PlayGrab()
    ResetLocal()
end

-- Le serveur a fermé le plein (tuyau arraché, trop loin, véhicule disparu…)
RegisterNetEvent('elyzea_fuel:dropped', function(msg)
    if msg then Notify(msg, 'error') end
    StopPumping()
    ResetLocal()
end)

-- Débit reçu du serveur (toutes les 250 ms pendant le remplissage)
RegisterNetEvent('elyzea_fuel:flow', function(v)
    if type(v) ~= 'table' or v.id ~= L.session then return end
    L.view = v
    UI('flow', v)
    if v.engine then Notify('Moteur allumé : la pompe s\'arrête.', 'error') end
end)

RegisterNetEvent('elyzea_fuel:receipt', function(r)
    if type(r) == 'table' then UI('receipt', r) end
    if r and r.paid == false then Notify('Paiement refusé : le réservoir est revenu à son niveau d\'avant.', 'error') end
end)

-- ---------------------------------------------------------------------
-- Boucle principale : invites, touches, contrôles bloqués, animation
-- ---------------------------------------------------------------------
local prompt = nil
local function ShowPrompt(key, text)
    local sig = key .. text
    if prompt == sig then return end
    prompt = sig
    UI('prompt', { key = key, text = text })
end
local function HidePrompt() if prompt then prompt = nil UI('prompt', false) end end

-- Véhicule dont la trappe est à portée (et sa distance)
local function NearbyVehicle(pos)
    local best, bestD
    for _, v in ipairs(GetGamePool('CVehicle')) do
        if #(GetEntityCoords(v) - pos) < 8.0 then
            local cap = FuelCapPos(v)
            local d = #(cap - pos)
            if d <= P.insertDistance and (not bestD or d < bestD) then best, bestD = v, d end
        end
    end
    return best, bestD
end

CreateThread(function()
    local scanAt, nearPump, nearSt, nearVeh, vehDist = 0, nil, nil, nil, nil
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local stations = FuelSettings().stations or {}
        if L.mode then
            sleep = 0
            -- pistolet en main : pas d'arme, pas de course, pas de saut, pas de voiture
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true) DisableControlAction(0, 37, true)
            DisableControlAction(0, 140, true) DisableControlAction(0, 141, true) DisableControlAction(0, 142, true)
            DisableControlAction(0, 21, true) DisableControlAction(0, 22, true) DisableControlAction(0, 23, true)
            DisableControlAction(0, 44, true)
            if IsEntityDead(ped) or IsPedRagdoll(ped) or GetVehiclePedIsIn(ped, false) ~= 0 then
                TriggerServerEvent('elyzea_fuel:drop', 'pistolet lâché')
                StopPumping()
                ResetLocal()
            elseif L.pump and #(pos - L.pump) > P.hoseLength + 0.5 and L.mode == 'hand' then
                -- tuyau tendu au maximum : le pistolet échappe des mains et revient à la pompe
                TriggerServerEvent('elyzea_fuel:drop', 'trop loin de la pompe')
                Notify('Le tuyau est trop court : le pistolet est revenu à la pompe.', 'error')
                ResetLocal()
            elseif not L.busy then
                local now = GetGameTimer()
                if now >= scanAt then
                    scanAt = now + 200
                    if L.mode == 'hand' then nearVeh, vehDist = NearbyVehicle(pos) else nearVeh, vehDist = nil, nil end
                end
                if L.mode == 'hand' then
                    -- voiture garée contre la pompe : la trappe gagne si elle est plus proche que la pompe
                    local pumpDist = L.pump and #(pos - L.pump) or math.huge
                    local atPump = pumpDist <= P.reach + 0.4 and not (nearVeh and vehDist < pumpDist)
                    if atPump then ShowPrompt('E', 'Raccrocher le pistolet')
                    elseif nearVeh then ShowPrompt('E', 'Insérer le pistolet dans le réservoir')
                    else ShowPrompt('', 'Approche-toi de la trappe à essence du véhicule') end
                    if IsControlJustPressed(0, K.interact) then
                        if atPump then Hang() elseif nearVeh then Insert(nearVeh) end
                    end
                elseif L.mode == 'car' and L.veh then
                    local close = DoesEntityExist(L.veh) and #(GetEntityCoords(L.veh) - pos) <= P.pumpDistance + 0.3
                    if close then HidePrompt() else ShowPrompt('', 'Reviens près du véhicule pour pomper') end
                    local want = close and IsDisabledControlPressed(0, K.pump)
                    if want then
                        if not L.pressing then
                            L.pressing = true
                            L.lastSend = 0
                            local cap = FuelCapPos(L.veh)
                            TaskTurnPedToFaceCoord(ped, cap.x, cap.y, cap.z, 400)
                            UI('pumping', true)
                        end
                        if not L.anim and LoadDict('timetable@gardener@filling_can', 1000) then
                            TaskPlayAnim(ped, 'timetable@gardener@filling_can', 'gar_ig_5_filling_can', 2.0, 8.0, -1, 50, 0.0, false, false, false)
                            L.anim = true
                        end
                        if now - L.lastSend >= 250 then
                            L.lastSend = now
                            TriggerServerEvent('elyzea_fuel:pump', L.session, true)
                        end
                    elseif L.pressing then
                        StopPumping()
                    end
                    if IsControlJustPressed(0, K.interact) and close then Remove() end
                end
            end
        elseif #stations > 0 and not IsPedInAnyVehicle(ped, false) and not L.busy then
            local st = FuelStationNear(pos, 4.0)
            if st then
                sleep = 0
                local now = GetGameTimer()
                if now >= scanAt then
                    scanAt = now + 250
                    nearSt = st
                    local o, d = ClosestPump(pos, P.reach + 0.6)
                    nearPump = nil
                    if o then
                        nearPump = GetOffsetFromEntityInWorldCoords(o, 0.0, 0.0, 0.0)
                    else
                        local v = virtual[st.id]
                        if v and v.obj and DoesEntityExist(v.obj) and #(GetEntityCoords(v.obj) - pos) <= P.reach + 0.6 then nearPump = GetEntityCoords(v.obj) end
                    end
                end
                if nearPump and not IsEntityDead(ped) then
                    ShowPrompt('E', ('Prendre le pistolet · %s $/L'):format(tostring(nearSt.price)))
                    if IsControlJustPressed(0, K.interact) then HidePrompt() Take(nearPump, nearSt) end
                else
                    HidePrompt()
                end
            else
                HidePrompt()
                sleep = 400
            end
        elseif #stations > 0 and IsPedInAnyVehicle(ped, false) and FuelStationNear(pos, 0.0) then
            -- au volant dans une station : on rappelle comment faire le plein
            local veh = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(veh, -1) == ped and UsesFuel(veh) and GetEntitySpeed(veh) < 1.0 and (GetFuel(veh) or 100) < 98 then
                ShowPrompt('', 'Coupe le moteur et descends : le pistolet est à la pompe')
            else
                HidePrompt()
            end
        else
            HidePrompt()
        end
        Wait(sleep)
    end
end)

-- Interface : les touches du clavier restent au jeu (aucun focus), l'écran ne fait qu'afficher
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, h in pairs(Hoses) do ClearHose(h) end
    for _, v in pairs(virtual) do if v.obj and DoesEntityExist(v.obj) then DeleteEntity(v.obj) end end
end)
