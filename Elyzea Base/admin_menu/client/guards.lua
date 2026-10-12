-- =========================================================
--  GARDES DU CORPS - CLIENT (permission « guards »)
--  PNJ créés par le staff (propriétaire réseau, pas de migration).
--  F11 : menu des ordres. La cible (personne / véhicule) est celle
--  visée ou la plus proche devant soi au moment d'ouvrir le menu.
-- =========================================================
local GC = Config.Guards
local Guards = {}          -- liste de { ped, netId, mode, veh, target, post }
local Defense = { on = false, radius = GC.defendRadius }
local DriveMode = 'normal'
local DefenseTargets = nil   -- personnes dans le rayon de défense (recalculé à chaque tour)
local REL = nil

local function Rel()
    if REL then return REL end
    local _, h = AddRelationshipGroup('ELY_STAFF_GUARDS')
    REL = h
    SetRelationshipBetweenGroups(1, REL, `PLAYER`)
    SetRelationshipBetweenGroups(1, `PLAYER`, REL)
    SetRelationshipBetweenGroups(0, REL, REL)
    return REL
end

local function Note(msg, kind) if Notify then Notify(msg, kind or 'info') end end
local function Me() return PlayerPedId() end
local function IsGuard(ped) for _, g in ipairs(Guards) do if g.ped == ped then return g end end end
local function Alive(g) return g and DoesEntityExist(g.ped) and not IsPedDeadOrDying(g.ped, true) end

local function LoadModel(model)
    local h = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(h) then return nil end
    RequestModel(h)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(h) and GetGameTimer() < t do Wait(20) end
    return HasModelLoaded(h) and h or nil
end
local function LoadDict(d)
    RequestAnimDict(d)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(d) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(d)
end

local function Register(add, remove)
    TriggerServerEvent('adminmenu:action', 'guards', { name = 'register', data = { add = add, remove = remove } })
end

-- Gardes vivants, les plus proches de moi d'abord ; n = nombre voulu (0 = tous)
local function Pick(n, filter)
    local me = GetEntityCoords(Me())
    local list = {}
    for _, g in ipairs(Guards) do
        if Alive(g) and (not filter or filter(g)) then list[#list + 1] = g end
    end
    table.sort(list, function(a, b) return #(GetEntityCoords(a.ped) - me) < #(GetEntityCoords(b.ped) - me) end)
    if n and n > 0 then while #list > n do table.remove(list) end end
    return list
end

local function Drive() return GC.driving[DriveMode] or GC.driving.normal end

-- ---------------------------------------------------------
--  Apparition
-- ---------------------------------------------------------
-- Copie de ma tenue (vêtements, accessoires, coiffure) : même modèle de personnage requis
local function CopyOutfit(ped)
    local me = Me()
    for c = 0, 11 do SetPedComponentVariation(ped, c, GetPedDrawableVariation(me, c), GetPedTextureVariation(me, c), GetPedPaletteVariation(me, c)) end
    for pr = 0, 7 do
        local idx = GetPedPropIndex(me, pr)
        if idx == -1 then ClearPedProp(ped, pr) else SetPedPropIndex(ped, pr, idx, GetPedPropTextureIndex(me, pr), true) end
    end
    SetPedHairColor(ped, GetPedHairColor(me), GetPedHairHighlightColor(me))
end

local function Setup(ped, cfg)
    SetEntityAsMissionEntity(ped, true, true)
    local netId = NetworkGetNetworkIdFromEntity(ped)
    SetNetworkIdCanMigrate(netId, false)
    SetPedRelationshipGroupHash(ped, Rel())
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)   -- se bat toujours
    SetPedCombatAttributes(ped, 5, true)
    SetPedCombatAbility(ped, 2)
    SetPedCombatRange(ped, 2)
    SetPedAccuracy(ped, 65)
    SetPedKeepTask(ped, true)
    SetPedDropsWeaponsWhenDead(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetPedSuffersCriticalHits(ped, false)
    SetPedConfigFlag(ped, 281, true)        -- pas d'écriture « blessé » au sol
    if cfg.armor then SetPedArmour(ped, 100) end
    if cfg.invincible then SetEntityInvincible(ped, true) end
    local weapon = (cfg.weapon and cfg.weapon ~= '') and joaat(cfg.weapon) or nil
    if weapon then
        GiveWeaponToPed(ped, weapon, 9999, false, true)
        SetCurrentPedWeapon(ped, cfg.holster and `WEAPON_UNARMED` or weapon, true)
    end
    return netId, weapon
end

RegisterNetEvent('adminmenu:guards:spawn', function(cfg)
    local mine = cfg.model == '__me__'
    local h = mine and GetEntityModel(Me()) or LoadModel(cfg.model)
    if mine then h = LoadModel(h) end
    if not h then return Note(('Modèle « %s » introuvable.'):format(tostring(cfg.model)), 'error') end
    local me = Me()
    local base, heading = GetEntityCoords(me), GetEntityHeading(me)
    local added = {}
    for i = 1, cfg.count do
        local a = (i / cfg.count) * math.pi * 2
        local r = 2.0 + math.floor((i - 1) / 8) * 1.5
        local x, y = base.x + math.cos(a) * r, base.y + math.sin(a) * r
        local ok, z = GetGroundZFor_3dCoord(x, y, base.z + 2.0, false)
        local ped = CreatePed(4, h, x, y, ok and z or base.z, heading, true, true)
        if DoesEntityExist(ped) then
            if mine then CopyOutfit(ped) end
            local netId, weapon = Setup(ped, cfg)
            Guards[#Guards + 1] = { ped = ped, netId = netId, mode = 'follow', armed = weapon ~= nil, weapon = weapon, holster = cfg.holster == true,
                cfg = { weapon = cfg.weapon, armor = cfg.armor, invincible = cfg.invincible } }
            added[#added + 1] = netId
        end
    end
    SetModelAsNoLongerNeeded(h)
    if #added > 0 then Register(added) end
    Note(('%d garde(s) du corps à tes côtés. F11 pour leur donner des ordres.'):format(#added), 'success')
end)

local function Delete(list)
    local removed = {}
    for _, g in ipairs(list) do
        if DoesEntityExist(g.ped) then DeleteEntity(g.ped) end
        removed[#removed + 1] = g.netId
        for i = #Guards, 1, -1 do if Guards[i] == g then table.remove(Guards, i) end end
    end
    if #removed > 0 then Register(nil, removed) end
end

RegisterNetEvent('adminmenu:guards:clear', function() Delete({ table.unpack(Guards) }) end)

-- ---------------------------------------------------------
--  Ordres
-- ---------------------------------------------------------
local function Reset(g)
    g.target, g.post, g.veh, g.seat, g.drive, g.aiming = nil, nil, nil, nil, nil, nil
    SetBlockingOfNonTemporaryEvents(g.ped, false)
    ClearPedTasks(g.ped)
end

local function Follow(g)
    Reset(g)
    g.mode = 'follow'
    if IsPedInAnyVehicle(g.ped, false) then TaskLeaveVehicle(g.ped, GetVehiclePedIsIn(g.ped, false), 0) end
end

local function FreeSeats(veh)
    local seats = {}
    if GetPedInVehicleSeat(veh, -1) == 0 then seats[#seats + 1] = -1 end
    for s = 0, GetVehicleMaxNumberOfPassengers(veh) - 1 do
        if IsVehicleSeatFree(veh, s) then seats[#seats + 1] = s end
    end
    return seats
end

local function WaypointCoords()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return nil end
    local c = GetBlipInfoIdCoord(blip)
    local ok, z = GetGroundZFor_3dCoord(c.x, c.y, 1000.0, false)
    return vector3(c.x, c.y, ok and z or 30.0)
end

local function DriverOf(g)
    if not IsPedInAnyVehicle(g.ped, false) then return nil end
    local veh = GetVehiclePedIsIn(g.ped, false)
    return GetPedInVehicleSeat(veh, -1) == g.ped and veh or nil
end

local function DriverSetup(ped)
    local d = Drive()
    SetDriverAbility(ped, 1.0)
    SetDriverAggressiveness(ped, DriveMode == 'fast' and 1.0 or 0.2)
    return d
end

local Orders = {}

function Orders.follow(list) for _, g in ipairs(list) do Follow(g) end return ('%d garde(s) te suivent.'):format(#list) end
function Orders.stay(list)
    for _, g in ipairs(list) do Reset(g) g.mode = 'stay' TaskGuardCurrentPosition(g.ped, 6.0, 6.0, true) end
    return ('%d garde(s) restent en position.'):format(#list)
end
function Orders.come(list)
    for _, g in ipairs(list) do Follow(g) TaskGoToEntity(g.ped, Me(), -1, 2.0, 3.0, 1073741824, 0) end
    return ('%d garde(s) reviennent vers toi.'):format(#list)
end

-- Protéger la zone : cercle de rayon r autour de moi, surveillance sans tirer
function Orders.zone(list, r)
    r = tonumber(r) or 20
    local c = GetEntityCoords(Me())
    for i, g in ipairs(list) do
        Reset(g)
        local a = (i / #list) * math.pi * 2
        local x, y = c.x + math.cos(a) * r, c.y + math.sin(a) * r
        local ok, z = GetGroundZFor_3dCoord(x, y, c.z + 5.0, false)
        g.mode, g.post = 'zone', { x = x, y = y, z = ok and z or c.z, h = math.deg(a) - 90.0, center = c, arrived = false }
        SetBlockingOfNonTemporaryEvents(g.ped, true)
        if IsPedInAnyVehicle(g.ped, false) then TaskLeaveVehicle(g.ped, GetVehiclePedIsIn(g.ped, false), 0) end
        TaskFollowNavMeshToCoord(g.ped, x, y, g.post.z, 2.0, -1, 1.0, true, 0)
    end
    return ('%d garde(s) protègent la zone (%d m, sans tirer).'):format(#list, r)
end

function Orders.defense(_, r)
    if r == 'off' then Defense.on = false return 'Mode défense coupé.' end
    Defense.on, Defense.radius = true, tonumber(r) or GC.defendRadius
    return ('Mode défense : tir sur toute personne (joueur ou PNJ, même en véhicule) à moins de %d m.'):format(Defense.radius)
end

function Orders.myveh(list)
    local me = Me()
    local veh = GetVehiclePedIsIn(me, false)
    if veh == 0 then veh = GetVehiclePedIsIn(me, true) end
    if veh == 0 or not DoesEntityExist(veh) then return nil, 'Tu n\'as pas de véhicule.' end
    -- Places passagers seulement : la place du conducteur reste pour moi
    local seats = {}
    for _, st in ipairs(FreeSeats(veh)) do if st ~= -1 then seats[#seats + 1] = st end end
    local n = 0
    for _, g in ipairs(list) do
        local seat = table.remove(seats, 1)
        if not seat then break end
        Reset(g)
        g.mode, g.veh, g.seat = 'vehicle', veh, seat
        TaskEnterVehicle(g.ped, veh, 15000, seat, 2.0, 1, 0)
        n = n + 1
    end
    if n == 0 then return nil, 'Plus de place dans ton véhicule.' end
    return ('%d garde(s) montent dans ton véhicule.'):format(n)
end

function Orders.takeveh(list, _, veh)
    if not veh or not DoesEntityExist(veh) then return nil, 'Aucun véhicule choisi.' end
    local seats = FreeSeats(veh)
    table.sort(seats)   -- conducteur (-1) d'abord
    -- À pied : la place passager avant reste libre pour moi (s'il y a plus d'une place)
    if not IsPedInAnyVehicle(Me(), false) and #seats > 1 then
        for i, st in ipairs(seats) do if st == 0 then table.remove(seats, i) break end end
    end
    -- Déverrouillé par le serveur (clés comprises) pour que je puisse monter aussi
    TriggerServerEvent('adminmenu:action', 'guards', { name = 'unlock', data = { netId = NetworkGetNetworkIdFromEntity(veh) } })
    local n = 0
    for _, g in ipairs(list) do
        local seat = table.remove(seats, 1)
        if not seat then break end
        Reset(g)
        g.mode, g.veh, g.seat = 'vehicle', veh, seat
        TaskEnterVehicle(g.ped, veh, 20000, seat, 2.0, 1, 0)
        n = n + 1
    end
    if n == 0 then return nil, 'Aucune place libre dans ce véhicule.' end
    return ('%d garde(s) prennent le véhicule (%s).'):format(n, (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

function Orders.exitveh(list)
    for _, g in ipairs(list) do Follow(g) end
    return ('%d garde(s) descendent.'):format(#list)
end

-- Conducteurs : aller à mon point GPS
function Orders.gps(list)
    local wp = WaypointCoords()
    if not wp then return nil, 'Pose d\'abord un point GPS sur ta carte.' end
    local n = 0
    for _, g in ipairs(list) do
        local veh = DriverOf(g)
        if veh then
            local d = DriverSetup(g.ped)
            g.mode, g.veh, g.drive = 'vehicle', veh, { kind = 'gps', to = wp }
            TaskVehicleDriveToCoordLongrange(g.ped, veh, wp.x, wp.y, wp.z, d.speed, d.style, 15.0)
            n = n + 1
        end
    end
    if n == 0 then return nil, 'Aucun garde au volant (ordre « Prendre le véhicule visé » d\'abord).' end
    return ('%d conducteur(s) en route vers ton point GPS (%s).'):format(n, DriveMode == 'fast' and 'grande vitesse' or 'conduite normale')
end

-- Convoi : chaque véhicule suit le précédent ; le premier suit mon véhicule (ou moi à pied, ou le conducteur « GPS »)
function Orders.convoy(list)
    local drivers = {}
    for _, g in ipairs(list) do
        local veh = DriverOf(g)
        if veh and not (g.drive and g.drive.kind == 'gps') then drivers[#drivers + 1] = { g = g, veh = veh } end
    end
    if #drivers == 0 then return nil, 'Aucun garde au volant à mettre en convoi.' end
    local me = Me()
    local leadVeh = IsPedInAnyVehicle(me, false) and GetVehiclePedIsIn(me, false) or nil
    if not leadVeh then
        for _, g in ipairs(Guards) do if Alive(g) and g.drive and g.drive.kind == 'gps' and DriverOf(g) then leadVeh = DriverOf(g) break end end
    end
    local prev = leadVeh
    for _, e in ipairs(drivers) do
        local d = DriverSetup(e.g.ped)
        e.g.mode, e.g.veh, e.g.drive = 'vehicle', e.veh, { kind = 'convoy', lead = prev }
        if prev then TaskVehicleEscort(e.g.ped, e.veh, prev, -1, d.speed, d.style, 10.0, 0, 25.0)
        else TaskVehicleFollow(e.g.ped, e.veh, me, d.speed, d.style, 12) end
        prev = e.veh
    end
    return ('Convoi de %d véhicule(s) (%s).'):format(#drivers, DriveMode == 'fast' and 'grande vitesse' or 'conduite normale')
end

function Orders.drivemode(_, mode)
    DriveMode = mode == 'fast' and 'fast' or 'normal'
    -- Les ordres de conduite en cours sont relancés avec le nouveau mode
    local gps, convoy = {}, {}
    for _, g in ipairs(Guards) do
        if Alive(g) and g.drive and DriverOf(g) then
            if g.drive.kind == 'gps' then gps[#gps + 1] = g else convoy[#convoy + 1] = g end
        end
    end
    if #gps > 0 then Orders.gps(gps) end
    if #convoy > 0 then Orders.convoy(convoy) end
    return DriveMode == 'fast' and 'Conduite : grande vitesse (feux grillés, dépassements).' or 'Conduite : normale (code de la route).'
end

local function TargetOk(t)
    if not t or not DoesEntityExist(t) or IsPedDeadOrDying(t, true) then return nil, 'Aucune personne choisie.' end
    return t
end

function Orders.aim(list, _, target)
    local t, err = TargetOk(target)
    if not t then return nil, err end
    local n = 0
    for _, g in ipairs(list) do
        if g.armed then
            Reset(g)
            SetCurrentPedWeapon(g.ped, g.weapon, true)
            g.mode, g.target = 'aim', t
            SetBlockingOfNonTemporaryEvents(g.ped, true)
            if IsPedInAnyVehicle(g.ped, false) then TaskLeaveVehicle(g.ped, GetVehiclePedIsIn(g.ped, false), 0) end
            TaskGoToEntityWhileAimingAtEntity(g.ped, t, t, 2.0, false, 5.0, 0.5, true, false, `FIRING_PATTERN_FULL_AUTO`)
            n = n + 1
        end
    end
    if n == 0 then return nil, 'Aucun garde armé.' end
    return ('%d garde(s) braquent la cible (sans tirer).'):format(n)
end

function Orders.attack(list, _, target)
    local t, err = TargetOk(target)
    if not t then return nil, err end
    for _, g in ipairs(list) do
        Reset(g)
        g.mode, g.target = 'attack', t
        TaskCombatPed(g.ped, t, 0, 16)
    end
    return ('%d garde(s) ouvrent le feu sur la cible.'):format(#list)
end

-- Menotter / démenotter : le garde le plus proche s'en charge
function Orders.cuff(list, on, target)
    local t, err = TargetOk(target)
    if not t then return nil, err end
    local g = list[1]
    if not g then return nil, 'Aucun garde disponible.' end
    on = on ~= 'off'
    Reset(g)
    g.mode = 'busy'
    SetBlockingOfNonTemporaryEvents(g.ped, true)
    CreateThread(function()
        if IsPedInAnyVehicle(g.ped, false) then TaskLeaveVehicle(g.ped, GetVehiclePedIsIn(g.ped, false), 0) Wait(1500) end
        TaskGoToEntity(g.ped, t, -1, 0.9, 3.0, 1073741824, 0)
        local untilT = GetGameTimer() + 20000
        while Alive(g) and DoesEntityExist(t) and #(GetEntityCoords(g.ped) - GetEntityCoords(t)) > 1.4 and GetGameTimer() < untilT do Wait(200) end
        if not Alive(g) or not DoesEntityExist(t) or #(GetEntityCoords(g.ped) - GetEntityCoords(t)) > 1.8 then
            Note('Le garde n\'a pas pu atteindre la personne.', 'error')
            return Follow(g)
        end
        TaskTurnPedToFaceEntity(g.ped, t, 600) Wait(600)
        if LoadDict('mp_arresting') then TaskPlayAnim(g.ped, 'mp_arresting', 'a_uncuff', 8.0, -8.0, 2200, 48, 0, false, false, false) end
        Wait(2200)
        if IsPedAPlayer(t) then
            local sid = GetPlayerServerId(NetworkGetPlayerIndexFromPed(t))
            TriggerServerEvent('adminmenu:action', 'guards', { name = 'cuff', data = { target = sid, on = on, guard = g.netId } })
        else
            NetworkRequestControlOfEntity(t)
            local tt = GetGameTimer() + 1500
            while not NetworkHasControlOfEntity(t) and GetGameTimer() < tt do Wait(50) NetworkRequestControlOfEntity(t) end
            if on then
                ClearPedTasksImmediately(t)
                SetBlockingOfNonTemporaryEvents(t, true)
                SetEnableHandcuffs(t, true)
                if LoadDict('mp_arresting') then TaskPlayAnim(t, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false) end
                SetPedKeepTask(t, true)
            else
                SetEnableHandcuffs(t, false)
                StopAnimTask(t, 'mp_arresting', 'idle', 1.0)
                SetBlockingOfNonTemporaryEvents(t, false)
                ClearPedTasks(t)
            end
            Note(on and 'PNJ menotté.' or 'PNJ démenotté.', 'success')
        end
        Follow(g)
    end)
    return on and 'Un garde va menotter la cible.' or 'Un garde va démenotter la cible.'
end

-- Même tenue que moi, à l'identique : un garde d'un autre modèle est remplacé par mon modèle
function Orders.outfit(list)
    local me = Me()
    local model = GetEntityModel(me)
    if not LoadModel(model) then return nil, 'Ton modèle de personnage est introuvable.' end
    local added, removed = {}, {}
    for _, g in ipairs(list) do
        if GetEntityModel(g.ped) == model then
            CopyOutfit(g.ped)
        elseif not IsPedInAnyVehicle(g.ped, false) then
            local c, h = GetEntityCoords(g.ped), GetEntityHeading(g.ped)
            local ped = CreatePed(4, model, c.x, c.y, c.z - 1.0, h, true, true)
            if DoesEntityExist(ped) then
                CopyOutfit(ped)
                local netId = Setup(ped, { weapon = g.cfg and g.cfg.weapon, armor = g.cfg and g.cfg.armor, invincible = g.cfg and g.cfg.invincible, holster = g.holster })
                removed[#removed + 1] = g.netId
                DeleteEntity(g.ped)
                g.ped, g.netId = ped, netId
                added[#added + 1] = netId
                Follow(g)
            end
        end
    end
    SetModelAsNoLongerNeeded(model)
    if #added > 0 or #removed > 0 then Register(added, removed) end
    return ('%d garde(s) portent ta tenue (les gardes en véhicule d\'un autre modèle sont ignorés).'):format(#list)
end

-- Armes en main ou rangées
function Orders.weapons(list, opt)
    local holster = opt == 'holster'
    for _, g in ipairs(list) do
        g.holster = holster
        if g.weapon then SetCurrentPedWeapon(g.ped, holster and `WEAPON_UNARMED` or g.weapon, true) end
    end
    return holster and ('%d garde(s) rangent leur arme.'):format(#list) or ('%d garde(s) gardent l\'arme en main.'):format(#list)
end

function Orders.delete(list)
    Delete(list)
    return ('%d garde(s) supprimé(s).'):format(#list)
end

-- ---------------------------------------------------------
--  Boucle : suivre, rester en poste, défense, nettoyage
-- ---------------------------------------------------------
local function Engage(attacker)
    if not attacker or attacker == 0 or attacker == Me() or IsGuard(attacker) or not DoesEntityExist(attacker) then return end
    for _, g in ipairs(Guards) do
        if Alive(g) and (g.mode == 'follow' or g.mode == 'stay') and g.target ~= attacker then
            g.prevMode = g.prevMode or g.mode
            g.mode, g.target = 'attack', attacker
            TaskCombatPed(g.ped, attacker, 0, 16)
        end
    end
end

-- Quelqu'un attaque le staff ou un garde : riposte (sauf gardes en surveillance de zone)
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' or #Guards == 0 then return end
    local victim, attacker = args[1], args[2]
    if victim == Me() or IsGuard(victim) then
        if attacker and attacker ~= 0 and IsEntityAPed(attacker) then Engage(attacker) end
    end
end)

CreateThread(function()
    while true do
        local wait = 1500
        if #Guards > 0 then
            wait = 500
            local me = Me()
            local mc = GetEntityCoords(me)
            local dead = {}
            DefenseTargets = nil
            if Defense.on then
                DefenseTargets = {}
                for _, p in ipairs(GetGamePool('CPed')) do
                    if p ~= me and not IsGuard(p) and not IsPedDeadOrDying(p, true) and #(GetEntityCoords(p) - mc) < Defense.radius then
                        DefenseTargets[#DefenseTargets + 1] = p
                    end
                end
                table.sort(DefenseTargets, function(x, y) return #(GetEntityCoords(x) - mc) < #(GetEntityCoords(y) - mc) end)
            end
            for i, g in ipairs(Guards) do
                if not DoesEntityExist(g.ped) then
                    dead[#dead + 1] = i
                elseif not IsPedDeadOrDying(g.ped, true) then
                    local pc = GetEntityCoords(g.ped)
                    local dist = #(pc - mc)
                    if g.mode == 'follow' then
                        if IsPedInAnyVehicle(me, false) then
                            -- je roule : ils attendent sur place
                        elseif not IsPedInAnyVehicle(g.ped, false) and dist > 4.0 and (not g.lastFollow or GetGameTimer() - g.lastFollow > 2500) then
                            g.lastFollow = GetGameTimer()
                            local a = (i % 8) / 8 * math.pi * 2
                            TaskFollowToOffsetOfEntity(g.ped, me, math.cos(a) * 1.8, math.sin(a) * 1.8 - 1.0, 0.0, dist > 15.0 and 3.0 or 1.8, -1, 1.5, true)
                        end
                    elseif g.mode == 'zone' and g.post then
                        local p = g.post
                        if not p.arrived and #(pc - vector3(p.x, p.y, p.z)) < 2.0 then
                            p.arrived = true
                            SetEntityHeading(g.ped, p.h)
                            TaskStartScenarioInPlace(g.ped, 'WORLD_HUMAN_GUARD_STAND', 0, true)
                        end
                    elseif g.mode == 'attack' then
                        if not g.target or not DoesEntityExist(g.target) or IsPedDeadOrDying(g.target, true) then
                            local back = g.prevMode
                            g.prevMode = nil
                            if back == 'stay' then Reset(g) g.mode = 'stay' TaskGuardCurrentPosition(g.ped, 6.0, 6.0, true)
                            elseif back == 'vehicle' and IsPedInAnyVehicle(g.ped, false) then g.mode, g.target = 'vehicle', nil
                            else Follow(g) end
                        end
                    elseif g.mode == 'aim' then
                        if not g.target or not DoesEntityExist(g.target) then Follow(g)
                        elseif not g.aiming and #(pc - GetEntityCoords(g.target)) < 6.0 then
                            g.aiming = true
                            TaskAimGunAtEntity(g.ped, g.target, -1, false)
                        end
                    end
                    -- Armes en main ou rangées (hors combat)
                    if g.weapon and (g.mode == 'follow' or g.mode == 'stay' or g.mode == 'zone') and not IsPedInCombat(g.ped, 0) then
                        local want = g.holster and `WEAPON_UNARMED` or g.weapon
                        if GetSelectedPedWeapon(g.ped) ~= want then SetCurrentPedWeapon(g.ped, want, true) end
                    end
                    -- Mode défense : chaque garde (sauf conducteurs et surveillance de zone) tire sur
                    -- toute personne dans le rayon : joueurs et PNJ, à pied ou en véhicule
                    if Defense.on and (g.mode == 'follow' or g.mode == 'stay' or (g.mode == 'vehicle' and not DriverOf(g))) then
                        local t = DefenseTargets and DefenseTargets[1]
                        if t then
                            -- La cible la moins visée, pour se répartir les menaces
                            local best, bestN
                            for _, p in ipairs(DefenseTargets) do
                                local n = 0
                                for _, o in ipairs(Guards) do if o.target == p then n = n + 1 end end
                                if not bestN or n < bestN then best, bestN = p, n end
                            end
                            g.prevMode = g.mode
                            g.mode, g.target = 'attack', best
                            TaskCombatPed(g.ped, best, 0, 16)
                        end
                    end
                end
            end
            if #dead > 0 then
                local removed = {}
                for k = #dead, 1, -1 do removed[#removed + 1] = Guards[dead[k]].netId table.remove(Guards, dead[k]) end
                Register(nil, removed)
            end
        end
        Wait(wait)
    end
end)

-- ---------------------------------------------------------
--  Menu F11
-- ---------------------------------------------------------
local menuOpen = false

-- Sélection à la flèche : regarder la cible, E ou clic gauche pour choisir, clic droit / Retour pour annuler
local function Help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function RayDir()
    local rot = GetFinalRenderedCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    return vector3(-math.sin(rz) * math.cos(rx), math.cos(rz) * math.cos(rx), math.sin(rx))
end

local function NameOf(ent)
    if IsEntityAVehicle(ent) then
        return ('%s · %s'):format(GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(ent))), (GetVehicleNumberPlateText(ent) or ''):gsub('^%s+', ''):gsub('%s+$', ''))
    end
    if IsPedAPlayer(ent) then
        local pid = NetworkGetPlayerIndexFromPed(ent)
        return ('%s [%d]'):format(GetPlayerName(pid), GetPlayerServerId(pid))
    end
    return ('PNJ à %d m'):format(math.floor(#(GetEntityCoords(ent) - GetEntityCoords(Me()))))
end

-- kind = 'vehicle' ou 'ped' ; renvoie l'entité choisie ou nil
local function SelectEntity(kind, verb)
    local me = Me()
    local myVeh = GetVehiclePedIsIn(me, false)
    local chosen, outlined = nil, nil
    local untilT = GetGameTimer() + 45000
    while GetGameTimer() < untilT do
        local from, dir = GetFinalRenderedCamCoord(), RayDir()
        local best, bestScore
        for _, e in ipairs(kind == 'vehicle' and GetGamePool('CVehicle') or GetGamePool('CPed')) do
            local ok = kind == 'vehicle' and e ~= myVeh
                or (kind == 'ped' and e ~= me and not IsGuard(e) and not IsPedDeadOrDying(e, true) and GetPedType(e) ~= 28)
            if ok then
                local v = GetEntityCoords(e) - from
                local t = v.x * dir.x + v.y * dir.y + v.z * dir.z
                if t > 1.0 and t < 120.0 then
                    local perp = #(v - dir * t)
                    local tol = (kind == 'vehicle' and 2.8 or 1.2) + t * 0.02
                    if perp < tol and (not bestScore or perp + t * 0.01 < bestScore) then best, bestScore = e, perp + t * 0.01 end
                end
            end
        end
        if best ~= outlined then
            if outlined and DoesEntityExist(outlined) then SetEntityDrawOutline(outlined, false) end
            outlined = best
            if best then SetEntityDrawOutlineColor(217, 181, 106, 255) SetEntityDrawOutline(best, true) end
        end
        DisableControlAction(0, 24, true) DisableControlAction(0, 25, true) DisableControlAction(0, 257, true)
        DisableControlAction(0, 140, true) DisableControlAction(0, 141, true) DisableControlAction(0, 142, true)
        DisablePlayerFiring(PlayerId(), true)
        if best then
            local c = GetEntityCoords(best)
            local top = kind == 'vehicle' and 2.2 or 1.4
            DrawMarker(0, c.x, c.y, c.z + top, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.6, 0.6, 0.6, 217, 181, 106, 220, true, true, 2, false, nil, nil, false)
            Help(('%s : ~y~%s~s~~n~~INPUT_CONTEXT~ / clic gauche : choisir · clic droit : annuler'):format(verb, NameOf(best)))
            if IsControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 24) then chosen = best break end
        else
            Help(('%s : regarde %s~n~clic droit : annuler'):format(verb, kind == 'vehicle' and 'un véhicule' or 'une personne'))
        end
        if IsDisabledControlJustPressed(0, 25) or IsControlJustPressed(0, 177) then break end
        Wait(0)
    end
    if outlined and DoesEntityExist(outlined) then SetEntityDrawOutline(outlined, false) end
    return chosen
end

local function Describe()
    local alive, inVeh, drivers = 0, 0, 0
    for _, g in ipairs(Guards) do
        if Alive(g) then
            alive = alive + 1
            if IsPedInAnyVehicle(g.ped, false) then inVeh = inVeh + 1 end
            if DriverOf(g) then drivers = drivers + 1 end
        end
    end
    local holstered = 0
    for _, g in ipairs(Guards) do if Alive(g) and g.holster then holstered = holstered + 1 end end
    return { holstered = holstered, alive = alive, inVehicle = inVeh, drivers = drivers, max = GC.max,
        defense = Defense.on and Defense.radius or false, drive = DriveMode, inMyVeh = IsPedInAnyVehicle(Me(), false), waypoint = WaypointCoords() ~= nil }
end

function OpenGuardsMenu()
    if not HasPerm('guards') then return end
    if menuOpen then return end
    if #Guards == 0 then return Note('Aucun garde du corps : fais-en apparaître dans le menu (Mes outils › Gardes du corps).', 'error') end
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'guardsMenu', show = true, data = Describe() })
end

local function CloseGuardsMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'guardsMenu', show = false })
end

RegisterNUICallback('guardsClose', function(_, cb) cb('ok') CloseGuardsMenu() end)

RegisterNUICallback('guardsOrder', function(body, cb)
    local fn = Orders[tostring(body and body.order or '')]
    if not fn then return cb({ error = 'Ordre inconnu.' }) end
    local n = math.floor(tonumber(body.count) or 0)
    local order = tostring(body.order)
    local list
    if order == 'gps' or order == 'convoy' then list = Pick(n, function(g) return DriverOf(g) ~= nil end)
    elseif order == 'takeveh' or order == 'myveh' then list = Pick(n, function(g) return not IsPedInAnyVehicle(g.ped, false) end)   -- ceux déjà en véhicule ne bougent pas
    else list = Pick(n) end
    if #list == 0 and body.order ~= 'defense' and body.order ~= 'drivemode' then
        local why = (order == 'takeveh' or order == 'myveh') and 'Aucun garde à pied disponible.' or 'Aucun garde disponible.'
        Note(why, 'error')
        return cb({ error = why })
    end
    -- Ordres qui demandent de choisir un véhicule ou une personne : le menu se ferme, flèche sur la cible
    local SELECT = { takeveh = { 'vehicle', 'Véhicule à prendre' }, aim = { 'ped', 'Personne à braquer' }, attack = { 'ped', 'Personne à abattre' },
        cuff = { 'ped', body.opt == 'off' and 'Personne à démenotter' or 'Personne à menotter' } }
    local sel = SELECT[order]
    if sel then
        cb({ ok = true, closed = true })
        CloseGuardsMenu()
        CreateThread(function()
            local ent = SelectEntity(sel[1], sel[2])
            if not ent then return Note('Ordre annulé.', 'inform') end
            local m, e = fn(list, body.opt, ent)
            if e then Note(e, 'error') else Note(m, 'success') end
        end)
        return
    end
    local msg, err = fn(list, body.opt)
    if err then Note(err, 'error') else Note(msg, 'success') end
    cb({ ok = err == nil, data = Describe() })
    if body.close and not err then CloseGuardsMenu() end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, g in ipairs(Guards) do if DoesEntityExist(g.ped) then DeleteEntity(g.ped) end end
end)

-- Monter dans un véhicule de mes gardes : F (entrer) prend la première place libre
-- (passager avant d'abord) au lieu d'essayer de sortir le garde au volant
CreateThread(function()
    while true do
        local wait = 1000
        if #Guards > 0 and not IsPedInAnyVehicle(Me(), false) then
            wait = 0
            if IsControlJustPressed(0, 23) then
                local me = Me()
                local mc = GetEntityCoords(me)
                local best, bestD
                for _, g in ipairs(Guards) do
                    local v = Alive(g) and (IsPedInAnyVehicle(g.ped, false) and GetVehiclePedIsIn(g.ped, false) or (g.mode == 'vehicle' and g.veh)) or nil
                    if v and DoesEntityExist(v) then
                        local d = #(GetEntityCoords(v) - mc)
                        if d < 6.0 and (not bestD or d < bestD) then best, bestD = v, d end
                    end
                end
                if best then
                    local seat
                    if IsVehicleSeatFree(best, 0) then seat = 0
                    else for st = 1, GetVehicleMaxNumberOfPassengers(best) - 1 do if IsVehicleSeatFree(best, st) then seat = st break end end end
                    if not seat and IsVehicleSeatFree(best, -1) then seat = -1 end
                    if seat then
                        ClearPedTasks(me)
                        TaskEnterVehicle(me, best, 8000, seat, 2.0, 1, 0)
                    else
                        Note('Plus de place dans ce véhicule.', 'error')
                    end
                end
            end
        end
        Wait(wait)
    end
end)

-- Touche F11 : enregistrée uniquement chez un staff qui a la permission « guards »
-- (pour les autres joueurs, la commande et la touche n'existent pas)
CreateThread(function()
    while not HasPerm('guards') do Wait(5000) end
    RegisterCommand('admin_guards', function() if HasPerm('guards') then OpenGuardsMenu() end end, false)
    RegisterKeyMapping('admin_guards', 'Staff - Ordres aux gardes du corps', 'keyboard', GC.key or 'F11')
end)
