-- =====================================================================
--  ELYZEA EMS - client : brancards
--  L'état (qui tient, qui est dessus, quel véhicule) vient du serveur
--  (GlobalState.emsStretchers). Ce client :
--   · déplace le brancard qu'il tient (au sol, devant lui, il est au bout) ;
--   · le pose dans un véhicule chargé / le sort ;
--   · s'allonge dessus s'il est le patient ;
--   · propose les actions ALT (sur le brancard, le patient, le véhicule).
-- =====================================================================
local C = EmsC
local ST = Config.Stretcher or {}
local VH = ST.vehicle or {}
if not ST.enabled then return end

local function Me() return GetPlayerServerId(PlayerId()) end
local function List() local g = GlobalState.emsStretchers return type(g) == 'table' and g or {} end
local function Ent(net)
    net = tonumber(net)
    if net and NetworkDoesNetworkIdExist(net) then
        local e = NetworkGetEntityFromNetworkId(net)
        if e and e ~= 0 and DoesEntityExist(e) then return e end
    end
    return nil
end
local function Find(fn) for _, s in ipairs(List()) do if fn(s) then return s end end end
local function Mine() local me = Me() return Find(function(s) return s.holder == me end) end
local function OfEntity(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) or not NetworkGetEntityIsNetworked(ent) then return nil end
    local net = NetworkGetNetworkIdFromEntity(ent)
    return Find(function(s) return s.net == net end)
end
local function InVeh(vnet) return Find(function(s) return s.veh == vnet end) end

-- Brancard le plus proche (hors véhicule), filtre facultatif
local function Nearest(maxD, filter)
    local me = GetEntityCoords(PlayerPedId())
    local best, bestE, bestD
    for _, s in ipairs(List()) do
        if not s.veh and (not filter or filter(s)) then
            local e = Ent(s.net)
            if e then
                local d = #(GetEntityCoords(e) - me)
                if d <= maxD and (not bestD or d < bestD) then best, bestE, bestD = s, e, d end
            end
        end
    end
    return best, bestE, bestD
end

-- ---------------------------------------------------------------------
-- Géométrie et placement
-- ---------------------------------------------------------------------
local GEO = {}
local function Geometry(model)
    if GEO[model] then return GEO[model] end
    local mn, mx = GetModelDimensions(model)
    local lx, ly = mx.x - mn.x, mx.y - mn.y
    GEO[model] = { long = math.max(lx, ly), extra = lx > ly and 90.0 or 0.0, bottom = mn.z }
    return GEO[model]
end

local function GroundZ(x, y, z, def)
    local ok, gz = GetGroundZFor_3dCoord(x, y, z + 1.5, false)
    if ok and gz and gz > z - 4.0 then return gz end
    return def
end

-- Au sol devant l'EMS (il est au bout), incliné selon la pente, tourne progressivement
local function PlaceStretcher(obj, ped, geo, state)
    local cfg = ST.stretcher or {}
    local target = GetEntityHeading(ped) + (cfg.heading or 0.0)
    local k = math.max(0.01, math.min(1.0, cfg.turnSmooth or 0.12))
    if not state.h then state.h = target end
    local d = ((target - state.h + 540.0) % 360.0) - 180.0
    state.h = (state.h + d * k) % 360.0
    local rad = math.rad(state.h)
    local fx, fy = -math.sin(rad), math.cos(rad)
    local me = GetEntityCoords(ped)
    local half = geo.long / 2.0
    local dist = (cfg.gap or 0.25) + half
    local cx, cy = me.x + fx * dist, me.y + fy * dist
    local zc = GroundZ(cx, cy, me.z, me.z - 1.0)
    local zn = GroundZ(cx - fx * half, cy - fy * half, me.z, zc)
    local zf = GroundZ(cx + fx * half, cy + fy * half, me.z, zc)
    local pitch = math.deg(math.atan(zf - zn, geo.long))
    SetEntityCoordsNoOffset(obj, cx, cy, zc - geo.bottom + (cfg.height or 0.0), false, false, false)
    SetEntityRotation(obj, pitch, 0.0, state.h + geo.extra, 2, true)
end

-- Dans un véhicule : à l'arrière, dans l'axe, posé sur le plancher
local function AttachToVehicle(obj, veh)
    local geo = Geometry(GetEntityModel(obj))
    local mn = GetModelDimensions(GetEntityModel(veh))
    local y = mn.y + (VH.inset or 0.30) + geo.long / 2.0
    local z = mn.z + (VH.floor or 0.55) - geo.bottom
    AttachEntityToEntity(obj, veh, 0, (VH.side or 0.0) + 0.0, y, z, 0.0, 0.0, geo.extra + (VH.heading or 0.0),
        false, false, false, false, 2, true)
end

local function Control(ent, ms)
    if NetworkHasControlOfEntity(ent) then return true end
    local t = GetGameTimer() + (ms or 1500)
    repeat
        NetworkRequestControlOfEntity(ent)
        if NetworkHasControlOfEntity(ent) then return true end
        Wait(0)
    until GetGameTimer() >= t
    return NetworkHasControlOfEntity(ent)
end

local function Model()
    for _, m in ipairs(ST.models or {}) do
        local h = type(m) == 'number' and m or GetHashKey(m)
        if IsModelInCdimage(h) then
            RequestModel(h)
            local t = GetGameTimer() + 5000
            while not HasModelLoaded(h) and GetGameTimer() < t do Wait(10) end
            if HasModelLoaded(h) then return h end
        end
    end
    return nil
end

-- Sortir un brancard : créé devant l'EMS puis enregistré par le serveur (qui peut le refuser)
local function Spawn()
    local h = Model()
    if not h then C.Notify('Aucun brancard disponible (modèle introuvable).', 'error') return nil end
    local me = PlayerPedId()
    local c = GetOffsetFromEntityInWorldCoords(me, 0.0, 1.5, 0.0)
    local obj = CreateObject(h, c.x, c.y, c.z, true, true, false)
    SetModelAsNoLongerNeeded(h)
    if not obj or obj == 0 then C.Notify('Impossible de sortir un brancard.', 'error') return nil end
    SetEntityCollision(obj, false, false)
    FreezeEntityPosition(obj, true)
    local net = NetworkGetNetworkIdFromEntity(obj)
    SetNetworkIdExistsOnAllMachines(net, true)
    SetNetworkIdCanMigrate(net, false)
    local r = C.Req('stretcherRegister', { net = net })
    if r.error then
        C.Notify(r.error, 'error')
        if DoesEntityExist(obj) then DeleteEntity(obj) end
        return nil
    end
    return net
end

-- ---------------------------------------------------------------------
-- Boucle : brancard tenu, brancards chargés / posés, patient allongé
-- ---------------------------------------------------------------------
local place, holdingNet, holdAnim = {}, nil, false
local leftNet, leftUntil = nil, 0       -- je viens de descendre de ce brancard : ne pas me rattacher
local lying = false

local function StopHold()
    if holdAnim then
        local a = ST.emsAnim
        if a then StopAnimTask(PlayerPedId(), a[1], a[2], 1.0) end
        holdAnim = false
    end
    holdingNet, place = nil, {}
end

CreateThread(function()
    local nextSlow = 0
    while true do
        local wait = 500
        local me = Me()
        local ped = PlayerPedId()
        local now = GetGameTimer()

        -- 1. Le brancard que je tiens : je le fais rouler devant moi
        local mine = Mine()
        local ent = mine and Ent(mine.net)
        if mine and ent then
            wait = 0
            if holdingNet ~= mine.net then holdingNet, place = mine.net, {} end
            if NetworkHasControlOfEntity(ent) then
                SetNetworkIdCanMigrate(mine.net, false)
                if IsEntityAttached(ent) then DetachEntity(ent, true, false) end
                FreezeEntityPosition(ent, true)
                PlaceStretcher(ent, ped, Geometry(GetEntityModel(ent)), place)
            else
                NetworkRequestControlOfEntity(ent)
            end
            if now >= nextSlow then
                nextSlow = now + 500
                local a = ST.emsAnim
                if a and not IsEntityPlayingAnim(ped, a[1], a[2], 3) and C.LoadDict(a[1]) then
                    TaskPlayAnim(ped, a[1], a[2], 8.0, -8.0, -1, a[3] or 49, 0, false, false, false)
                end
                holdAnim = true
                -- dans un véhicule ou à terre : on lâche le brancard (il reste là, avec le patient)
                if IsPedInAnyVehicle(ped, false) or C.IsDown() then C.Req('stretcherDrop', { net = mine.net }) end
            end
            if ST.noSprint then DisableControlAction(0, 21, true) end   -- courir
            DisableControlAction(0, 22, true)   -- sauter
            DisableControlAction(0, 23, true)   -- entrer dans un véhicule (ALT › charger le brancard)
            DisableControlAction(0, 24, true)   -- attaquer
            DisableControlAction(0, 25, true)   -- viser
        elseif holdingNet then
            StopHold()
        end

        -- 2. Brancards que je contrôle sans les tenir : chargés (attachés au véhicule) ou posés (figés, cédés à qui en a besoin)
        do
            for _, s in ipairs(List()) do
                if s.holder ~= me then
                    local e = Ent(s.net)
                    if e and NetworkHasControlOfEntity(e) then
                        if s.veh then
                            local veh = Ent(s.veh)
                            if veh and not IsEntityAttachedToEntity(e, veh) then AttachToVehicle(e, veh) end
                        elseif IsEntityAttached(e) then
                            DetachEntity(e, true, false)
                        end
                        if not s.holder then SetNetworkIdCanMigrate(s.net, true) end
                    end
                end
            end
        end

        -- 3. Je suis le patient : allongé sur le brancard
        local on = Find(function(s) return s.patient == me end)
        if on and not (leftNet == on.net and now < leftUntil) then
            local e = Ent(on.net)
            if e then
                wait = math.min(wait, 250)
                if not IsEntityAttachedToEntity(ped, e) then
                    local p, r = ST.patient.pos, ST.patient.rot
                    AttachEntityToEntity(ped, e, 0, p[1] + 0.0, p[2] + 0.0, p[3] + 0.0, r[1] + 0.0, r[2] + 0.0, r[3] + 0.0,
                        false, false, false, false, 2, true)
                end
                local a = ST.patientAnim
                if a and not IsEntityPlayingAnim(ped, a[1], a[2], 3) and C.LoadDict(a[1]) then
                    TaskPlayAnim(ped, a[1], a[2], 8.0, -8.0, -1, a[3] or 1, 0, false, false, false)
                end
                lying = true
            end
        elseif lying and not on then
            -- filet de sécurité : le serveur ne me compte plus sur un brancard (événement manqué) → je descends sur place
            lying = false
            DetachEntity(ped, true, false)
            local a = ST.patientAnim
            if a then StopAnimTask(ped, a[1], a[2], 1.0) end
        end
        Wait(wait)
    end
end)

-- Je descends du brancard : posé à côté de l'endroit où il est (position donnée par le serveur)
RegisterNetEvent('ems:client:offStretcher', function(net, c)
    local ped = PlayerPedId()
    leftNet, leftUntil = tonumber(net), GetGameTimer() + 3000
    lying = false
    DetachEntity(ped, true, false)
    local a = ST.patientAnim
    if a then StopAnimTask(ped, a[1], a[2], 1.0) end
    if type(c) == 'table' and c.x then
        local rad = math.rad(c.h or 0.0)
        local x, y = c.x + math.cos(rad) * 1.0, c.y + math.sin(rad) * 1.0   -- 1 m sur le côté du brancard
        local z = GroundZ(x, y, c.z, c.z)
        SetEntityCoords(ped, x, y, z, false, false, false, false)
        SetEntityHeading(ped, c.h or 0.0)
    end
end)

RegisterNetEvent('ems:client:onStretcher', function(net)
    if leftNet == tonumber(net) then leftNet, leftUntil = nil, 0 end
end)

-- ---------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------
local function Lay(sid)
    local s = Mine()
    local net = s and s.net
    if not net then
        local f = Nearest(ST.reach or 3.0, function(x) return not x.patient and not x.holder end)
        net = f and f.net
    end
    if not net then
        net = Spawn()
        if not net then return end
        Wait(300)
    end
    C.Do('stretcherPut', { net = net, target = sid })
end

local function VehicleNear()
    local veh = C.ClosestVehicle(GetEntityCoords(PlayerPedId()), VH.reach or 6.0)
    return veh
end

-- Options ALT sur un joueur (appelé par client/medical.lua)
function C.StretcherPlayerOptions(sid, ctx, out)
    if not C.Can('escort') then return end
    if Player(sid).state.emsOnStretcher then
        out[#out + 1] = { id = 'st_offp', label = 'Retirer du brancard', icon = 'out' }
    elseif not ctx.inVehicle then
        local desc = Mine() and 'Sur le brancard que vous tenez'
            or (Nearest(ST.reach or 3.0, function(x) return not x.patient and not x.holder end) and 'Sur le brancard à côté')
            or 'Un brancard est sorti'
        out[#out + 1] = { id = 'st_lay', label = 'Allonger sur le brancard', icon = 'escort', desc = desc }
    end
end

-- Options ALT sur un véhicule
function C.StretcherVehicleOptions(veh, out)
    if not C.Can('escort') or not veh or not NetworkGetEntityIsNetworked(veh) then return end
    local loaded = InVeh(VehToNet(veh))
    if loaded then
        out[#out + 1] = { id = 'st_unload', label = 'Sortir le brancard du véhicule', icon = 'out', desc = loaded.patient and 'Le patient reste dessus' or nil }
    elseif Mine() then
        out[#out + 1] = { id = 'st_load', label = 'Charger le brancard dans ce véhicule', icon = 'in', desc = Mine().patient and 'Avec le patient' or nil }
    end
end

-- Options ALT sur le brancard visé
function C.StretcherExtOptions(ent, out)
    local s = OfEntity(ent)
    if not s or not C.Can('escort') then return end
    local me = Me()
    if s.holder == me then
        out[#out + 1] = { id = 'st_drop', label = 'Lâcher le brancard', icon = 'out', desc = s.patient and 'Le patient reste dessus' or nil }
        local veh = VehicleNear()
        out[#out + 1] = { id = 'st_load', label = 'Charger dans le véhicule', icon = 'in', disabled = not veh, desc = not veh and 'Aucun véhicule à proximité' or nil }
    elseif not s.holder then
        out[#out + 1] = { id = 'st_grab', label = 'Prendre le brancard', icon = 'escort' }
    end
    if s.patient then
        out[#out + 1] = { id = 'st_off', label = 'Retirer le patient du brancard', icon = 'out' }
    else
        -- joueurs proches du brancard : les allonger dessus
        local c = GetEntityCoords(ent)
        for _, pid in ipairs(GetActivePlayers()) do
            local sid = GetPlayerServerId(pid)
            local p = GetPlayerPed(pid)
            if sid ~= me and p ~= 0 and not IsPedInAnyVehicle(p, false) and #(GetEntityCoords(p) - c) <= (ST.reach or 3.0) + 1.0 then
                out[#out + 1] = { id = 'st_put:' .. sid, label = ('Allonger ID %d sur le brancard'):format(sid), icon = 'escort' }
            end
        end
        if not s.holder or s.holder == me then out[#out + 1] = { id = 'st_store', label = 'Ranger le brancard', icon = 'out' } end
    end
end

-- Choix (renvoie true si l'action est un brancard)
function C.StretcherSelect(id, ctx)
    id = tostring(id or '')
    if id:sub(1, 3) ~= 'st_' then return false end
    local s = ctx and ctx.kind == 'ext' and OfEntity(ctx.entity) or nil
    local net = s and s.net
    local act, arg = id:match('^(st_%a+):?(%d*)$')
    CreateThread(function()
        if act == 'st_lay' and ctx and ctx.sid then Lay(ctx.sid)
        elseif act == 'st_offp' and ctx and ctx.sid then C.Do('stretcherOff', { target = ctx.sid })
        elseif act == 'st_unload' and ctx and ctx.entity then C.Do('stretcherUnload', { veh = VehToNet(ctx.entity) })
        elseif act == 'st_load' then
            local veh = (ctx and ctx.kind == 'vehicle' and ctx.entity) or VehicleNear()
            if not veh then return C.Notify('Aucun véhicule à proximité.', 'error') end
            C.Do('stretcherLoad', { veh = VehToNet(veh) })
        elseif act == 'st_grab' and net then
            local e = Ent(net)
            if e then Control(e) end
            C.Do('stretcherGrab', { net = net })
        elseif act == 'st_drop' and net then C.Do('stretcherDrop', { net = net })
        elseif act == 'st_off' and net then C.Do('stretcherOff', { net = net })
        elseif act == 'st_store' and net then
            local e = Ent(net)
            if e then Control(e, 800) end
            C.Do('stretcherStore', { net = net })
        elseif act == 'st_put' and net and tonumber(arg) then C.Do('stretcherPut', { net = net, target = tonumber(arg) })
        elseif act == 'st_new' then Spawn() end
    end)
    return true
end

-- Cible ALT propre (le brancard) : appelée par elyzea_police/client/alt.lua
exports('AltTarget', function(ent)
    if not C.OnDuty() or not C.Can('escort') then return nil end
    local s = OfEntity(ent)
    if not s then return nil end
    return s.patient and 'Brancard · patient allongé' or 'Brancard'
end)

exports('AltNearby', function()
    if not C.OnDuty() or not C.Can('escort') then return nil end
    local mine = Mine()
    if mine then local e = Ent(mine.net) if e then return e, 'Brancard (tenu)' end end
    local s, e = Nearest(2.5)
    if s then return e, s.patient and 'Brancard · patient allongé' or 'Brancard' end
    return nil
end)

-- Réglage des positions en jeu (seulement pour toi, à recopier ensuite dans config.lua › Config.Stretcher)
-- /brancard_reglage brancard <écart> <hauteur> <rotation>       ex. /brancard_reglage brancard 0.25 0 0
-- /brancard_reglage patient <x> <y> <z> <rx> <ry> <rz>           ex. /brancard_reglage patient 0 0 1.05 0 0 180
-- /brancard_reglage vehicule <plancher> <recul> <rotation> <côté> ex. /brancard_reglage vehicule 0.55 0.30 0 0
RegisterCommand('brancard_reglage', function(_, args)
    local s, pa = ST.stretcher or {}, ST.patient or {}
    if args[1] == 'brancard' then
        local g, hgt, rot = tonumber(args[2]), tonumber(args[3]), tonumber(args[4])
        if not (g and hgt and rot) then return C.Notify('Usage : /brancard_reglage brancard <écart> <hauteur> <rotation>', 'error') end
        s.gap, s.height, s.heading = g, hgt, rot
        ST.stretcher = s
        return C.Notify(('Brancard : écart %.2f, hauteur %.2f, rotation %.0f'):format(g, hgt, rot), 'success')
    end
    if args[1] == 'patient' then
        local n = {}
        for i = 2, 7 do n[#n + 1] = tonumber(args[i]) end
        if #n ~= 6 then return C.Notify('Usage : /brancard_reglage patient x y z rx ry rz', 'error') end
        pa.pos, pa.rot = { n[1], n[2], n[3] }, { n[4], n[5], n[6] }
        ST.patient = pa
        if lying then DetachEntity(PlayerPedId(), false, false) end   -- la boucle rattache aussitôt
        return C.Notify(('Patient : position %s, rotation %s'):format(json.encode(pa.pos), json.encode(pa.rot)), 'success')
    end
    if args[1] == 'vehicule' then
        local f, i, rot, side = tonumber(args[2]), tonumber(args[3]), tonumber(args[4]), tonumber(args[5])
        if not (f and i and rot and side) then return C.Notify('Usage : /brancard_reglage vehicule <plancher> <recul> <rotation> <côté>', 'error') end
        VH.floor, VH.inset, VH.heading, VH.side = f, i, rot, side
        for _, x in ipairs(List()) do
            local e = x.veh and Ent(x.net)
            if e and NetworkHasControlOfEntity(e) then DetachEntity(e, false, false) end   -- rattaché aussitôt avec les nouvelles valeurs
        end
        return C.Notify(('Véhicule : plancher %.2f, recul %.2f, rotation %.0f, côté %.2f'):format(f, i, rot, side), 'success')
    end
    C.Notify(('Brancard : écart %.2f, hauteur %.2f, rotation %.0f · patient : %s %s · véhicule : plancher %.2f, recul %.2f'):format(
        s.gap or 0, s.height or 0, s.heading or 0, json.encode(pa.pos), json.encode(pa.rot), VH.floor or 0, VH.inset or 0), 'inform')
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    StopHold()
    if lying then DetachEntity(PlayerPedId(), true, false) end
end)
