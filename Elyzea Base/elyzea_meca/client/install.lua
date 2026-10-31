-- =====================================================================
--  ELYZEA MÉCANO - client : installation d'un devis payé (points d'intervention + mini-jeux)
--
--  Remplace l'ancienne intervention animée (le mécanicien ne court plus partout tout seul).
--  1. « Installer » (devis payé) : le serveur verrouille le point et donne les lignes du devis.
--  2. Les lignes sont regroupées en interventions (pare-chocs avant, roues et pneus, peinture…).
--     Chaque intervention a son point autour du véhicule : une flèche le montre.
--  3. Le mécanicien y va lui-même et appuie sur E : le serveur remet les propriétés des pièces,
--     le mini-jeu s'ouvre, le personnage joue l'animation adaptée.
--  4. Mini-jeu réussi : la pièce est posée sur le véhicule, relue, confirmée au serveur.
--     Peinture : la couleur change au fur et à mesure du mini-jeu. Roues : les 4 roues sont
--     changées l'une après l'autre dans UN seul mini-jeu (ou une seule si un seul pneu).
--  5. Tout est posé : facture, puis le mécanicien remet les clés au client (E à côté de lui).
--  Interruption (X maintenu, mort, éloignement, véhicule déplacé…) : scène remise en état,
--  le devis reste payé, « Installer » reprend la suite. Rien n'est posé sans paiement :
--  le serveur refuse les pièces d'un devis non payé.
-- =====================================================================
local C = MecaC
local K = Config.Install or {}
local LC = (Config.Interventions or {}).lift or {}

local I = {
    running = false, veh = nil, uid = nil, net = nil, base = nil, dim = nil,
    jobs = {}, lines = {}, lift = false,
    props = {}, burst = {}, doors = {}, liftH = 0.0, lockWas = nil,
    game = nil,          -- mini-jeu ouvert { id, job, result, progress, stages… }
    handover = nil,      -- remise des clés en attente { uid, customer, name, veh }
    seq = 0,
}

local function Log(msg) if K.debug then print('^5[MECA installation]^7 ' .. msg) end end

-- ---------------------------------------------------------------------
-- Utilitaires
-- ---------------------------------------------------------------------
local function Control(veh)
    if not veh or not DoesEntityExist(veh) then return false end
    if NetworkHasControlOfEntity(veh) then return true end
    NetworkRequestControlOfEntity(veh)
    local t = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < t do Wait(0) NetworkRequestControlOfEntity(veh) end
    return NetworkHasControlOfEntity(veh)
end

local function LoadModel(name)
    local h = type(name) == 'number' and name or GetHashKey(name)
    if not IsModelInCdimage(h) or not IsModelValid(h) then return nil end
    RequestModel(h)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(h) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(h) and h or nil
end

local function DeleteProp(obj)
    if obj and DoesEntityExist(obj) then
        SetEntityAsMissionEntity(obj, true, true)
        DeleteObject(obj)
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
end
local function ClearProps() for i = #I.props, 1, -1 do DeleteProp(I.props[i]) end I.props = {} end

-- Objet en main (clé, bombe de peinture, clés du véhicule) : en réseau, tout le monde le voit
local function HandProp(spec, ped)
    if type(spec) ~= 'table' or not spec.model then return nil end
    local h = LoadModel(spec.model)
    if not h then Log('modèle absent : ' .. tostring(spec.model)) return nil end
    ped = ped or PlayerPedId()
    local c = GetEntityCoords(ped)
    local obj = CreateObject(h, c.x, c.y, c.z + 0.2, true, true, false)
    SetModelAsNoLongerNeeded(h)
    local p, r = spec.pos or { 0, 0, 0 }, spec.rot or { 0, 0, 0 }
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, spec.bone or 57005), p[1], p[2], p[3], r[1], r[2], r[3], true, true, false, true, 1, true)
    I.props[#I.props + 1] = obj
    return obj
end

-- Animation en boucle du type demandé (le premier dictionnaire qui existe), sinon le scénario
local function PlayWork(kind, pos, heading)
    local ped = PlayerPedId()
    for _, a in ipairs((K.anims or {})[kind] or {}) do
        if type(a) == 'table' and a[1] and DoesAnimDictExist(a[1]) and C.LoadDict(a[1]) then
            TaskPlayAnim(ped, a[1], a[2], 3.0, 3.0, -1, a[3] or 1, 0, false, false, false)
            return 'anim'
        end
    end
    local sc = (K.scenarios or {})[kind] or (K.scenarios or {}).stand
    if sc then
        if pos then TaskStartScenarioAtPosition(ped, sc, pos.x, pos.y, pos.z, heading or GetEntityHeading(ped), 0, true, false)
        else TaskStartScenarioInPlace(ped, sc, 0, true) end
        return 'scenario'
    end
end

-- Repères du véhicule : coordonnées locales (x à droite, y vers l'avant) → monde, au niveau du sol
local function Ground() return I.base.ground end
local function Around(x, y)
    local p = GetOffsetFromEntityInWorldCoords(I.veh, x + 0.0, y + 0.0, 0.0)
    return vector3(p.x, p.y, Ground() + 1.0)
end
-- Cap du personnage pour regarder le véhicule depuis un côté
local function Facing(side)
    local h = I.base.heading
    if side == 'front' then return (h + 180.0) % 360.0 end
    if side == 'rear' then return h % 360.0 end
    if side == 'left' then return (h - 90.0) % 360.0 end
    if side == 'right' then return (h + 90.0) % 360.0 end
    return h
end

-- Marche courte (sous le pont / pour en sortir) : jamais de téléportation, 4 s au plus
local function WalkTo(pos, heading)
    local ped = PlayerPedId()
    TaskGoStraightToCoord(ped, pos.x, pos.y, pos.z, 1.0, 4000, heading or GetEntityHeading(ped), 0.1)
    local t = GetGameTimer() + 4000
    while GetGameTimer() < t and #(GetEntityCoords(ped).xy - pos.xy) > 0.35 do Wait(50) end
    ClearPedTasks(ped)
    if heading then SetEntityHeading(ped, heading) end
end

-- Roues du véhicule : n° de pneu GTA (0, 1 à l'avant, 4, 5 à l'arrière), position locale
local WHEEL_BONES = { { 'wheel_lf', 0, 'avant gauche' }, { 'wheel_rf', 1, 'avant droite' }, { 'wheel_lr', 4, 'arrière gauche' }, { 'wheel_rr', 5, 'arrière droite' } }
local function Wheels(veh)
    local out = {}
    for _, w in ipairs(WHEEL_BONES) do
        local b = GetEntityBoneIndexByName(veh, w[1])
        if b ~= -1 then
            local wp = GetWorldPositionOfEntityBone(veh, b)
            local o = GetOffsetFromEntityGivenWorldCoords(veh, wp.x, wp.y, wp.z)
            out[#out + 1] = { idx = w[2], label = w[3], x = o.x, y = o.y }
        end
    end
    return out
end

-- ---------------------------------------------------------------------
-- Interventions : chaque ligne du devis → un type de travail → une intervention
-- ---------------------------------------------------------------------
local KEYWORK = {
    modTransmission = 'under', modSuspension = 'under', modHydrolic = 'under', modExhaust = 'under', modBrakes = 'brakes',
    modFrontWheels = 'wheels', wheels = 'wheels', modBackWheels = 'wheels', modCustomTiresF = 'wheels', modCustomTiresR = 'wheels',
    driftTyres = 'wheels', tyresNew = 'wheels', modSmokeEnabled = 'wheels', tyreSmokeColor = 'wheels', wheelColor = 'wheels',
    modEngine = 'engine', modTurbo = 'engine', modEngineBlock = 'engine', modAirFilter = 'engine', modStruts = 'engine', modHood = 'hood',
    modArmor = 'armor',
    modFrontBumper = 'front', modGrille = 'front', modRearBumper = 'rear', modSpoilers = 'trunk', modTrunk = 'trunk',
    modSideSkirt = 'left', modFender = 'left', modRightFender = 'right', modArchCover = 'left', modTrimB = 'left', modTank = 'left',
    modDoorR = 'left', modRoof = 'roof', modFrame = 'roof', modAerials = 'roof', modLightbar = 'lights', modWindows = 'tint',
    windowTint = 'tint', color1 = 'paint', color2 = 'paint', paintType1 = 'paint', paintType2 = 'paint', pearlescentColor = 'paint',
    modLivery = 'paint', modRoofLivery = 'paint',
    neonEnabled = 'neon', neonColor = 'neon', modXenon = 'lights', xenonColor = 'lights', modHorns = 'lights',
    plateIndex = 'plate', modPlateHolder = 'plate', modVanityPlate = 'plate',
    interiorColor = 'interior', dashboardColor = 'interior', modTrimA = 'interior', modOrnaments = 'interior', modDashboard = 'interior',
    modDial = 'interior', modDoorSpeaker = 'interior', modSeats = 'interior', modSteeringWheel = 'interior', modShifterLeavers = 'interior',
    modAPlate = 'interior', modSpeakers = 'interior', extras = 'roof',
}
-- game : mini-jeu de l'interface · spot : point d'intervention (chacun le sien) · anim : geste · door : porte ouverte
local JOBS = {
    under    = { label = 'Dessous de caisse (transmission, suspension, échappement)', game = 'gauge', spot = 'under', anim = 'under', icon = 'lift' },
    brakes   = { label = 'Freins', game = 'gauge', spot = 'wheelR', anim = 'kneel', tyreOff = true, icon = 'brake' },
    wheels   = { label = 'Roues et pneus', game = 'wheels', spot = 'wheel', anim = 'kneel', icon = 'wheel' },
    engine   = { label = 'Moteur', game = 'gauge', spot = 'hood', anim = 'hood', door = 4, icon = 'engine' },
    hood     = { label = 'Capot', game = 'bolts', spot = 'hood', anim = 'hood', door = 4, icon = 'hood' },
    armor    = { label = 'Blindage', game = 'bolts', spot = 'armor', anim = 'stand', icon = 'shield' },
    front    = { label = 'Pare-chocs avant', game = 'align', spot = 'front', anim = 'kneel', part = 'front', icon = 'front' },
    rear     = { label = 'Pare-chocs arrière', game = 'align', spot = 'rear', anim = 'kneel', part = 'rear', icon = 'rear' },
    trunk    = { label = 'Coffre et aileron', game = 'bolts', spot = 'trunk', anim = 'stand', door = 5, icon = 'trunk' },
    left     = { label = 'Carrosserie côté gauche', game = 'bolts', spot = 'left', anim = 'stand', icon = 'side' },
    right    = { label = 'Carrosserie côté droit', game = 'bolts', spot = 'right', anim = 'stand', icon = 'side' },
    roof     = { label = 'Toit et accessoires', game = 'bolts', spot = 'roof', anim = 'stand', icon = 'roof' },
    paint    = { label = 'Peinture', game = 'paint', spot = 'paint', anim = 'spray', icon = 'paint' },
    tint     = { label = 'Vitres teintées', game = 'film', spot = 'tint', anim = 'stand', icon = 'glass' },
    lights   = { label = 'Éclairage et klaxon', game = 'wires', spot = 'lights', anim = 'hood', door = 4, icon = 'light' },
    neon     = { label = 'Néons', game = 'wires', spot = 'neon', anim = 'kneel', icon = 'neon' },
    plate    = { label = 'Plaque', game = 'bolts', spot = 'plate', anim = 'kneel', icon = 'plate' },
    interior = { label = 'Intérieur', game = 'bolts', spot = 'door', anim = 'inside', door = 0, icon = 'seat' },
}
local ORDER = { 'under', 'brakes', 'wheels', 'engine', 'hood', 'armor', 'front', 'rear', 'trunk', 'left', 'right', 'roof',
    'paint', 'tint', 'lights', 'neon', 'plate', 'interior' }
C.InstallJobs, C.InstallOrder = JOBS, ORDER   -- (tests)

local function WorkOf(line)
    if line.kind == 'service' or line.kind == 'custom' then return nil end
    if line.plate then return 'plate' end
    local best, bestRank
    for _, k in ipairs(line.keys or {}) do
        local w = KEYWORK[k]
        if w then
            local rank
            for r, o in ipairs(ORDER) do if o == w then rank = r break end end
            if rank and (not bestRank or rank < bestRank) then best, bestRank = w, rank end
        end
    end
    return best or 'roof'
end
C.InstallWorkOf = WorkOf

-- Point d'intervention : position au sol et cap du personnage. Chaque intervention a son propre point
-- (au moins ~0,8 m d'écart) : la flèche et la touche E désignent toujours la bonne pièce.
--   avant : capot / moteur / éclairage à gauche, pare-chocs au centre · arrière : pare-chocs, plaque, coffre
--   gauche : néons, portière, blindage, carrosserie, toit (de l'avant vers l'arrière), peinture plus loin
--   droite : freins (roue avant), carrosserie, dessous de caisse, vitres
local function Spot(job)
    local min, max = I.dim.min, I.dim.max
    local s = job.spot
    if s == 'front' then return Around(0.0, max.y + 0.75), Facing('front') end
    if s == 'hood' then return Around(min.x * 0.75, max.y + 0.6), Facing('front') end
    if s == 'lights' then return Around(max.x * 0.75, max.y + 0.6), Facing('front') end
    if s == 'rear' then return Around(0.0, min.y - 0.75), Facing('rear') end
    if s == 'plate' then return Around(min.x * 0.75, min.y - 0.6), Facing('rear') end
    if s == 'trunk' then return Around(max.x * 0.75, min.y - 0.6), Facing('rear') end
    if s == 'neon' then return Around(min.x - 0.65, max.y * 0.55), Facing('left') end
    if s == 'armor' then return Around(min.x - 0.65, min.y * 0.25), Facing('left') end
    if s == 'left' then return Around(min.x - 0.65, min.y * 0.55), Facing('left') end
    if s == 'roof' then return Around(min.x - 0.65, min.y * 0.85), Facing('left') end
    if s == 'paint' then return Around(min.x - 1.7, max.y * 0.1), Facing('left') end
    if s == 'right' then return Around(max.x + 0.65, max.y * 0.25), Facing('right') end
    if s == 'tint' then return Around(max.x + 0.65, min.y * 0.7), Facing('right') end
    if s == 'wheel' then
        for _, w in ipairs(Wheels(I.veh)) do if w.idx == 0 then return Around(w.x - 0.75, w.y), Facing('left') end end
        return Around(min.x - 0.7, max.y * 0.6), Facing('left')
    end
    if s == 'wheelR' then   -- roue avant droite (freins)
        for _, w in ipairs(Wheels(I.veh)) do if w.idx == 1 then return Around(w.x + 0.75, w.y), Facing('right') end end
        return Around(max.x + 0.7, max.y * 0.6), Facing('right')
    end
    if s == 'door' then
        local y = 0.4
        local d = GetEntityBoneIndexByName(I.veh, 'door_dside_f')
        if d ~= -1 then
            local wp = GetWorldPositionOfEntityBone(I.veh, d)
            y = GetOffsetFromEntityGivenWorldCoords(I.veh, wp.x, wp.y, wp.z).y - 0.45
        end
        return Around(min.x - 0.75, y), Facing('left')
    end
    if s == 'under' then
        -- Pont roulant : E sur le côté, puis le mécanicien passe sous le véhicule levé ;
        -- sans pont : allongé sur le côté droit, tête sous la caisse
        if I.lift then return Around(max.x + 0.7, min.y * 0.3), Facing('right') end
        return Around(max.x + 0.35, min.y * 0.3), (Facing('right') + 180.0) % 360.0
    end
    return Around(min.x - 0.7, 0.0), Facing('left')
end

-- ---------------------------------------------------------------------
-- Scène : portes, pneus retirés, levage, remise en état
-- ---------------------------------------------------------------------
local function OpenDoor(d)
    if not I.veh or GetIsDoorValid and not GetIsDoorValid(I.veh, d) then return end
    SetVehicleDoorOpen(I.veh, d, false, false)
    I.doors[d] = true
end
local function ShutDoors()
    if not I.veh or not DoesEntityExist(I.veh) then I.doors = {} return end
    for d in pairs(I.doors) do SetVehicleDoorShut(I.veh, d, false) end
    I.doors = {}
end
local function TyreOff(idx)
    if not I.veh or IsVehicleTyreBurst(I.veh, idx, false) then return end
    SetVehicleTyreBurst(I.veh, idx, true, 1000.0)
    I.burst[idx] = true
end
local function TyreOn(idx)
    if not I.veh then return end
    SetVehicleTyreFixed(I.veh, idx)
    I.burst[idx] = nil
end
local function TyresBack() for idx in pairs(I.burst) do TyreOn(idx) end I.burst = {} end

-- Levage au pont roulant (véhicule figé, monté / descendu en douceur)
local function LiftTo(h, ms)
    local veh = I.veh
    if not veh or not DoesEntityExist(veh) then return false end
    local from, t0 = I.liftH, GetGameTimer()
    ms = math.max(200, ms or 2000)
    pcall(function() Entity(veh).state:set('mecaLift', h > 0.01, true) end)   -- bras du pont sous la voiture (client/lift.lua)
    while true do
        local k = math.min(1.0, (GetGameTimer() - t0) / ms)
        local z = from + (h - from) * k
        Control(veh)
        SetEntityCoordsNoOffset(veh, I.base.pos.x, I.base.pos.y, I.base.pos.z + z, false, false, false)
        SetEntityRotation(veh, I.base.rot.x, I.base.rot.y, I.base.rot.z, 2, true)
        I.liftH = z
        if k >= 1.0 then break end
        Wait(0)
    end
    return true
end

local function SceneState()
    local nets = {}
    for _, o in ipairs(I.props) do if DoesEntityExist(o) and NetworkGetEntityIsNetworked(o) then nets[#nets + 1] = ObjToNet(o) end end
    local tyres = {}
    for t in pairs(I.burst) do tyres[#tyres + 1] = t end
    return { props = nets, tyres = tyres, hood = false, lifted = I.liftH > 0.01 }
end

-- Fin d'une intervention (réussie ou non) : personnage libre, objets rangés, portes fermées, pneus remis
local function EndWorkScene()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    ClearProps()
    ShutDoors()
    TyresBack()
    if I.paintFx then StopParticleFxLooped(I.paintFx, false) I.paintFx = nil end
end

-- Remise en état complète (fin ou interruption) ; keepFrozen = le véhicule attend la remise des clés
local function CleanScene(keepFrozen)
    EndWorkScene()
    local veh = I.veh
    if veh and DoesEntityExist(veh) then
        Control(veh)
        if I.liftH > 0.001 then
            -- Sous le véhicule levé : le mécanicien sort sur le côté avant la descente
            local ped = PlayerPedId()
            local pc = GetEntityCoords(ped)
            local o = GetOffsetFromEntityGivenWorldCoords(veh, pc.x, pc.y, pc.z)
            local min, max = I.dim.min, I.dim.max
            if o.x > min.x - 0.4 and o.x < max.x + 0.4 and o.y > min.y - 0.4 and o.y < max.y + 0.4 then
                local out = Around(min.x - 1.1, o.y)
                ClearPedTasksImmediately(ped)
                SetEntityCoordsNoOffset(ped, out.x, out.y, out.z, false, false, false)
            end
            LiftTo(0.0, 1200)
        end
        pcall(function() Entity(veh).state:set('mecaLift', false, true) end)
        SetEntityCoordsNoOffset(veh, I.base.pos.x, I.base.pos.y, I.base.pos.z, false, false, false)
        SetEntityRotation(veh, I.base.rot.x, I.base.rot.y, I.base.rot.z, 2, true)
        if not keepFrozen then
            SetVehicleDoorsLocked(veh, I.lockWas or 1)
            FreezeEntityPosition(veh, false)
        end
    end
    I.liftH = 0.0
end

-- ---------------------------------------------------------------------
-- Peinture progressive : la couleur passe de l'ancienne à la nouvelle avec l'avancement du mini-jeu
-- ---------------------------------------------------------------------
local function CurrentRGB(veh, slot)
    if slot == 1 and GetIsVehiclePrimaryColourCustom(veh) then return { GetVehicleCustomPrimaryColour(veh) } end
    if slot == 2 and GetIsVehicleSecondaryColourCustom(veh) then return { GetVehicleCustomSecondaryColour(veh) } end
    local p, s = GetVehicleColours(veh)
    return C.PaletteRGB(veh, slot == 1 and p or s)
end
-- Couleur réelle d'un n° de la palette du jeu (lue sur le véhicule, état remis dans la même image)
function C.PaletteRGB(veh, idx)
    local p, s = GetVehicleColours(veh)
    local custom = GetIsVehiclePrimaryColourCustom(veh)
    local cr, cg, cb = GetVehicleCustomPrimaryColour(veh)
    ClearVehicleCustomPrimaryColour(veh)
    SetVehicleColours(veh, idx, s)
    local r, g, b = GetVehicleColor(veh)
    SetVehicleColours(veh, p, s)
    if custom then SetVehicleCustomPrimaryColour(veh, cr, cg, cb) end
    return { r or 0, g or 0, b or 0 }
end
local function TargetRGB(veh, v) if type(v) == 'table' then return { v[1], v[2], v[3] } end return C.PaletteRGB(veh, v) end

local function PaintPlan(lines)
    local plan = {}
    for _, l in ipairs(lines) do
        local p = l.patch or {}
        if p.color1 ~= nil then plan[1] = { from = CurrentRGB(I.veh, 1), to = TargetRGB(I.veh, p.color1) } end
        if p.color2 ~= nil then plan[2] = { from = CurrentRGB(I.veh, 2), to = TargetRGB(I.veh, p.color2) } end
    end
    return next(plan) and plan or nil
end
local function PaintAt(plan, k)
    if not plan or not I.veh or not DoesEntityExist(I.veh) then return end
    Control(I.veh)
    for slot, c in pairs(plan) do
        local r = math.floor(c.from[1] + (c.to[1] - c.from[1]) * k + 0.5)
        local g = math.floor(c.from[2] + (c.to[2] - c.from[2]) * k + 0.5)
        local b = math.floor(c.from[3] + (c.to[3] - c.from[3]) * k + 0.5)
        if slot == 1 then SetVehicleCustomPrimaryColour(I.veh, r, g, b) else SetVehicleCustomSecondaryColour(I.veh, r, g, b) end
    end
end
local function Hex(c) return c and ('#%02x%02x%02x'):format(c[1] or 0, c[2] or 0, c[3] or 0) or nil end

-- ---------------------------------------------------------------------
-- Interface : liste des interventions (sans curseur) et mini-jeux (curseur)
-- ---------------------------------------------------------------------
local function Pending(job) return not job.done end
local function NextJob()
    for _, key in ipairs(ORDER) do
        for _, j in ipairs(I.jobs) do if j.key == key and Pending(j) then return j end end
    end
end
local function Hud()
    if not I.running then SendNUIMessage({ action = 'install', show = false }) return end
    local nx = NextJob()
    local list = {}
    for _, j in ipairs(I.jobs) do
        list[#list + 1] = { key = j.key, label = j.label, icon = j.icon, done = j.done == true, failed = j.failed, next = nx == j,
            lines = (function() local t = {} for _, l in ipairs(j.lines) do t[#t + 1] = { label = l.label, done = l.done == true, failed = l.failed == true } end return t end)() }
    end
    SendNUIMessage({ action = 'install', show = true, jobs = list, plate = C.Plate(I.veh), active = I.game and I.game.job.key or nil })
end

-- Signe de vie + avancement pour le suivi du client
local function Beat(job, progress, active)
    C.Req('quoteInstallBeat', { uid = I.uid, scene = SceneState(), job = job and { label = job.label, progress = progress or 0, active = active == true } or nil })
end

-- ---------------------------------------------------------------------
-- Pose des pièces d'une intervention : propriétés demandées au serveur AU DÉBUT du mini-jeu,
-- posées et relues À LA FIN (réussite) ; abandon : rien n'est posé, la ligne reste à faire.
-- ---------------------------------------------------------------------
local function Grant(job)
    local granted = {}
    for _, l in ipairs(job.lines) do
        if not l.done and not l.failed then
            local r = C.Req('quoteInstallStep', { uid = I.uid, i = l.i, scene = SceneState() })
            if r.error then
                if r.error:find('déjà posée') then l.done = true
                else
                    for _, g in ipairs(granted) do C.Req('quoteInstallStepDone', { uid = I.uid, i = g.i, ok = false, scene = SceneState() }) end
                    return nil, r.error
                end
            else
                l.patch = r.patch or {}
                granted[#granted + 1] = l
            end
        end
    end
    return granted
end

local function Release(granted)
    for _, l in ipairs(granted) do C.Req('quoteInstallStepDone', { uid = I.uid, i = l.i, ok = false, scene = SceneState() }) l.patch = nil end
end

local function Commit(granted)
    local veh = I.veh
    local nOk = 0
    for _, l in ipairs(granted) do
        local patch = l.patch or {}
        -- Couleur de la palette : la couleur provisoire de la peinture progressive est retirée avant la pose
        if type(patch.color1) == 'number' then ClearVehicleCustomPrimaryColour(veh) end
        if type(patch.color2) == 'number' then ClearVehicleCustomSecondaryColour(veh) end
        local ok = C.WsApplyPatch(veh, patch) == true
        C.Req('quoteInstallStepDone', { uid = I.uid, i = l.i, ok = ok, scene = SceneState() })
        if ok then l.done = true nOk = nOk + 1
        else
            -- Pièce refusée par le véhicule (modèle incompatible…) : elle ne sera pas facturée
            l.failed = true
            C.Notify(('« %s » ne se pose pas sur ce véhicule : elle ne sera pas facturée.'):format(l.label or '?'), 'error')
        end
        l.patch = nil
    end
    return nOk
end

-- ---------------------------------------------------------------------
-- Mini-jeu d'une intervention
-- ---------------------------------------------------------------------
local Abort   -- défini plus bas

local function VehicleOk()
    local veh = I.veh
    if not veh or not DoesEntityExist(veh) then return false, 'véhicule disparu' end
    if IsEntityDead(veh) or GetVehicleEngineHealth(veh) < -3000 then return false, 'véhicule détruit' end
    local pos = GetEntityCoords(veh)
    local dz = I.liftH
    if #(vector3(pos.x, pos.y, pos.z - dz) - I.base.pos) > 1.0 then return false, 'véhicule déplacé' end
    return true
end

local function RunJob(job)
    if I.game then return end
    local ok, why = VehicleOk()
    if not ok then return Abort(why) end
    local ped = PlayerPedId()
    local pos, heading = Spot(job)
    local granted, err = Grant(job)
    if not granted then C.Notify(err, 'error') return end
    if #granted == 0 then job.done = true Hud() return end

    I.seq = I.seq + 1
    local g = { id = I.seq, job = job, result = nil, progress = 0.0, t = GetGameTimer() }
    I.game = g
    -- Le personnage se tourne vers la pièce ; scène de l'intervention
    ClearPedTasks(ped)
    TaskAchieveHeading(ped, heading, 600)
    Wait(450)
    Control(I.veh)
    if job.door then OpenDoor(job.door) end
    if job.key == 'under' and I.lift then
        -- Véhicule monté sur le pont, puis le mécanicien passe dessous (debout, bras levés)
        LiftTo(C.LiftHeightFor and C.LiftHeightFor(I.veh) or (LC.clearance or 1.95), (LC.liftTime or 2.5) * 1000)
        WalkTo(Around(0.0, 0.0), I.base.heading)
    end
    local stages
    if job.key == 'wheels' then
        stages = {}
        local want
        for _, l in ipairs(granted) do
            local p = l.patch or {}
            if p.tyresNew and not (p.modFrontWheels or p.driftTyres ~= nil or p.modCustomTiresF ~= nil) then
                want = want or {}
                for _, w in ipairs(p.tyresNew) do want[w] = true end
            else want = 'all' break end
        end
        for _, w in ipairs(Wheels(I.veh)) do
            if want == 'all' or want == nil or want[w.idx] then stages[#stages + 1] = { idx = w.idx, label = w.label } end
        end
        if #stages == 0 then stages = { { idx = 0, label = 'avant gauche' } } end
    end
    if job.tyreOff then for _, w in ipairs(Wheels(I.veh)) do if w.idx == 0 or w.idx == 1 then TyreOff(w.idx) end end end
    local plan = job.key == 'paint' and PaintPlan(granted) or nil
    g.plan = plan
    g.stages = stages
    local animKind = (job.key == 'under' and not I.lift) and 'under-lying' or job.anim
    if animKind == 'under-lying' then
        TaskStartScenarioAtPosition(ped, (K.scenarios or {}).under or 'WORLD_HUMAN_VEHICLE_MECHANIC', pos.x, pos.y, pos.z, heading, 0, true, false)
    else
        PlayWork(job.anim, nil, heading)
        if job.key == 'paint' then
            local can = HandProp((K.props or {}).spray)
            if can and K.paintFx ~= false then
                RequestNamedPtfxAsset('scr_playerlamgraff')
                local t = GetGameTimer() + 1500
                while not HasNamedPtfxAssetLoaded('scr_playerlamgraff') and GetGameTimer() < t do Wait(10) end
                if HasNamedPtfxAssetLoaded('scr_playerlamgraff') then
                    UseParticleFxAssetNextCall('scr_playerlamgraff')
                    I.paintFx = StartNetworkedParticleFxLoopedOnEntity('scr_lamgraff_paint_spray', can, 0.0, 0.0, 0.08, 0.0, 0.0, 0.0, 1.0, false, false, false)
                    local to = plan and (plan[1] or plan[2]).to
                    if I.paintFx and to then SetParticleFxLoopedColour(I.paintFx, to[1] / 255.0, to[2] / 255.0, to[3] / 255.0, false) end
                end
            end
        elseif job.game ~= 'wires' and job.game ~= 'film' then
            HandProp((K.props or {}).wrench)
        end
    end

    -- Ouverture du mini-jeu (curseur)
    local labels = {}
    for _, l in ipairs(granted) do labels[#labels + 1] = l.label end
    local paintTo = plan and (plan[1] or plan[2]).to
    local paintFrom = plan and (plan[1] or plan[2]).from
    SendNUIMessage({ action = 'minigame', show = true, id = g.id, game = job.game, label = job.label, icon = job.icon, parts = labels,
        stages = stages, part = job.part, from = Hex(paintFrom), to = Hex(paintTo), timeout = K.gameTimeout or 120 })
    C.Focus('minigame', true)
    Beat(job, 0, true)

    -- Attente du résultat : jamais plus de gameTimeout ; interruption si la scène n'est plus valable
    local limit = GetGameTimer() + (K.gameTimeout or 120) * 1000
    local lastBeat = GetGameTimer()
    while I.game == g and g.result == nil do
        Wait(100)
        if GetGameTimer() > limit then g.result = false g.reason = 'temps écoulé' break end
        local vOk, vWhy = VehicleOk()
        if not vOk then g.result = false g.reason = vWhy g.abort = true break end
        if IsEntityDead(PlayerPedId()) or C.IsDown() or not C.OnDuty() then g.result = false g.reason = 'mécanicien indisponible' g.abort = true break end
        if job.key ~= 'under' and #(GetEntityCoords(PlayerPedId()) - pos) > 4.0 then g.result = false g.reason = 'trop loin de la pièce' break end
        if GetGameTimer() - lastBeat > 1000 then lastBeat = GetGameTimer() Beat(job, g.progress, true) end
    end
    SendNUIMessage({ action = 'minigame', show = false, id = g.id })
    C.Focus('minigame', false)
    if I.game ~= g then return end   -- intervention arrêtée pendant le mini-jeu (déjà nettoyée)

    if g.result == true then
        if plan then PaintAt(plan, 1.0) end
        local n = Commit(granted)
        job.done = true
        for _, l in ipairs(job.lines) do if not l.done and not l.failed then job.done = false end end
        if n > 0 then PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true) end
        C.Notify(('%s : terminé.'):format(job.label), 'success')
    else
        -- Rien n'est posé : couleur d'origine remise, la ligne reste à faire (E pour recommencer)
        if plan then PaintAt(plan, 0.0) end
        Release(granted)
        if not g.abort then C.Notify(('%s : %s. Rien n\'a été posé, recommencez (E).'):format(job.label, g.reason or 'annulé'), 'error') end
    end
    EndWorkScene()
    if job.key == 'under' and I.liftH > 0.01 then
        WalkTo(pos, heading)   -- il ressort sur le côté avant la descente
        LiftTo(0.0, (LC.liftTime or 2.5) * 1000)
    end
    I.game = nil
    Beat(job, g.result == true and 1 or 0, false)
    Hud()
    if g.abort then Abort(g.reason) end
end

-- Résultats du mini-jeu (interface)
RegisterNUICallback('mgDone', function(body, cb)
    cb({})
    local g = I.game
    if not g or tonumber(body.id) ~= g.id or g.result ~= nil then return end
    g.result = body.ok == true
    if not g.result then g.reason = body.reason == 'timeout' and 'temps écoulé' or 'annulé' end
end)
RegisterNUICallback('mgProgress', function(body, cb)
    cb({})
    local g = I.game
    if not g or tonumber(body.id) ~= g.id then return end
    local p = math.max(0.0, math.min(1.0, tonumber(body.p) or 0.0))
    if p < g.progress then return end   -- l'avancement ne recule pas
    g.progress = p
    if g.plan then PaintAt(g.plan, p) end
end)
-- Roues : pneu retiré au début de chaque roue, remis (neuf) à la fin
RegisterNUICallback('mgStage', function(body, cb)
    cb({})
    local g = I.game
    if not g or tonumber(body.id) ~= g.id or not g.stages then return end
    local st = g.stages[tonumber(body.stage) or 0]
    if not st then return end
    Control(I.veh)
    if body.phase == 'off' then TyreOff(st.idx) else TyreOn(st.idx) end
end)

-- ---------------------------------------------------------------------
-- Boucle : flèches sur les points, E pour lancer, X maintenu pour interrompre
-- ---------------------------------------------------------------------
local function Help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function Finish()
    local n, total = 0, 0
    for _, j in ipairs(I.jobs) do for _, l in ipairs(j.lines) do total = total + 1 if l.done then n = n + 1 end end end
    SendNUIMessage({ action = 'install', show = false })
    local r = C.Req('quoteInstallDone', { uid = I.uid })
    local veh = I.veh
    if r.error then
        C.Notify(r.error, 'error')
        CleanScene(false)
        I.running = false
        return
    end
    -- Contrôle final : chaque pièce a été relue sur le véhicule ; le serveur ne facture que celles-là
    CleanScene(r.handover ~= nil)
    I.running = false
    C.Notify(r.message or 'Intervention terminée.', (r.failed or 0) > 0 and 'inform' or 'success')
    if r.handover then
        I.handover = { uid = r.handover.uid, customer = r.handover.customer, name = r.handover.name, veh = veh, net = I.net, t = GetGameTimer() }
        SendNUIMessage({ action = 'handover', show = true, name = r.handover.name, plate = C.Plate(veh), done = n, total = total })
    end
    Log(('fin : %d/%d pièce(s) posée(s)'):format(n, total))
end

local BLOCKED = { 24, 25, 37, 44, 45, 140, 141, 142, 257, 263 }
local function Loop()
    CreateThread(function()
        local xHeld, lastCheck, lastBeat = nil, 0, GetGameTimer()
        while I.running do
            Wait(0)
            for _, c in ipairs(BLOCKED) do DisableControlAction(0, c, true) end
            if not I.veh or not DoesEntityExist(I.veh) then
                if not I.game then Abort('véhicule disparu') break end
            elseif not I.game and not I.starting then
                local ped = PlayerPedId()
                local pp = GetEntityCoords(ped)
                local nx = NextJob()
                local near
                local bob = math.sin(GetGameTimer() / 300.0) * 0.12
                for _, j in ipairs(I.jobs) do
                    if Pending(j) then
                        local p = Spot(j)
                        local isNext = j == nx
                        local r, g, b = 245, 158, 11
                        if isNext then r, g, b = 56, 189, 248 end
                        -- Flèche au-dessus du point et cercle au sol
                        DrawMarker(2, p.x, p.y, p.z + 0.6 + bob, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.32, 0.32, 0.32, r, g, b, isNext and 220 or 120, false, true, 2, false, nil, nil, false)
                        DrawMarker(25, p.x, p.y, p.z - 0.97, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.1, 1.1, 1.0, r, g, b, isNext and 160 or 70, false, false, 2, false, nil, nil, false)
                        local d = #(pp - p)
                        if d <= (K.reach or 1.4) and (not near or d < near.d) then near = { job = j, d = d } end
                    end
                end
                if near then
                    Help(('~INPUT_CONTEXT~ %s · lancer l\'installation~n~~INPUT_VEH_DUCK~ maintenir : interrompre'):format(near.job.label))
                    if IsControlJustPressed(0, 38) and not IsPedInAnyVehicle(ped, false) then
                        local job = near.job
                        I.starting = true   -- un seul mini-jeu à la fois (double appui ignoré)
                        CreateThread(function()
                            local ok, err = pcall(RunJob, job)
                            if not ok then
                                print(('^1[MECA] Intervention « %s » : %s^0'):format(job.label, tostring(err)))
                                if I.game then I.game = nil SendNUIMessage({ action = 'minigame', show = false }) C.Focus('minigame', false) end
                                EndWorkScene()
                            end
                            I.starting = false
                        end)
                    end
                end
                -- X maintenu 1 seconde : interrompre (reprise possible)
                if IsControlPressed(0, 73) or IsDisabledControlPressed(0, 73) then
                    xHeld = xHeld or GetGameTimer()
                    if GetGameTimer() - xHeld > 1000 then xHeld = nil Abort('interrompue par le mécanicien') end
                else xHeld = nil end
                if I.running and not NextJob() then Finish() break end
            end
            if I.running and GetGameTimer() - lastCheck > 500 then
                lastCheck = GetGameTimer()
                local vOk, why = VehicleOk()
                if not vOk and not I.game then Abort(why)
                elseif not I.game and (IsEntityDead(PlayerPedId()) or C.IsDown() or not C.OnDuty()) then Abort('mécanicien indisponible')
                elseif not I.game and I.veh and #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(I.veh)) > (K.maxDistance or 25.0) then Abort('trop loin du véhicule') end
            end
            if I.running and not I.game and GetGameTimer() - lastBeat > (K.beat or 15) * 1000 then
                lastBeat = GetGameTimer()
                CreateThread(function() Beat(nil) end)
            end
        end
    end)
end

-- Interruption : scène remise en état, devis toujours payé (reprise par « Installer »)
Abort = function(reason)
    if not I.running then return end
    local uid = I.uid
    if I.game then
        local g = I.game
        I.game = nil
        SendNUIMessage({ action = 'minigame', show = false, id = g.id })
        C.Focus('minigame', false)
        if g.plan then PaintAt(g.plan, 0.0) end
        for _, l in ipairs(g.job.lines) do if l.patch then C.Req('quoteInstallStepDone', { uid = uid, i = l.i, ok = false }) l.patch = nil end end
    end
    I.running = false
    SendNUIMessage({ action = 'install', show = false })
    CleanScene(false)
    local a = C.Req('quoteInstallAbort', { uid = uid, reason = reason, cleaned = true })
    C.Notify(('Intervention interrompue (%s). %s'):format(reason or '?', a.message or ''), 'error')
    I.veh, I.uid = nil, nil
end

-- ---------------------------------------------------------------------
-- Lancement (atelier › Installer, devis payé)
-- ---------------------------------------------------------------------
local function Occupied(veh)
    for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do if not IsVehicleSeatFree(veh, seat) then return true end end
    return false
end

function C.StartInstall(veh, uid, netId)
    if I.running then return { error = 'Une intervention est déjà en cours.' } end
    if I.handover then return { error = 'Remettez d\'abord les clés du véhicule précédent à son client.' } end
    if not veh or not DoesEntityExist(veh) then return { error = 'Véhicule introuvable.' } end
    if IsEntityUpsidedown(veh) or math.abs(GetEntityRoll(veh)) > 15.0 then return { error = 'Le véhicule doit être sur ses roues.' } end
    if GetEntitySpeed(veh) > 0.3 then return { error = 'Le véhicule doit être à l\'arrêt.' } end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
        local t = GetGameTimer() + 5000
        while IsPedInAnyVehicle(ped, false) and GetGameTimer() < t do Wait(50) end
        if IsPedInAnyVehicle(ped, false) then return { error = 'Sortez du véhicule.' } end
    end
    local r = C.Req('quoteInstallStart', { uid = uid, net = netId })
    if r.error then return r end

    I.running, I.veh, I.uid, I.net, I.game = true, veh, uid, netId, nil
    I.props, I.burst, I.doors, I.liftH, I.lift = {}, {}, {}, 0.0, r.lift == true
    local min, max = GetModelDimensions(GetEntityModel(veh))
    local pos = GetEntityCoords(veh)
    I.dim = { min = min, max = max }
    I.base = { pos = pos, rot = GetEntityRotation(veh, 2), heading = GetEntityHeading(veh), ground = pos.z - GetEntityHeightAboveGround(veh) }

    -- Véhicule vide, verrouillé, immobilisé et moteur coupé pendant tout le travail
    Control(veh)
    local t = GetGameTimer() + 8000
    while Occupied(veh) and GetGameTimer() < t do Wait(200) end
    if Occupied(veh) then
        I.running = false
        C.Req('quoteInstallAbort', { uid = uid, reason = 'véhicule occupé', cleaned = true })
        return { error = 'Le véhicule doit être vide.' }
    end
    I.lockWas = GetVehicleDoorLockStatus(veh)
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleEngineOn(veh, false, true, true)
    FreezeEntityPosition(veh, true)

    -- Interventions à faire (les lignes déjà posées lors d'un passage précédent sont ignorées)
    local byKey = {}
    I.jobs = {}
    for _, l in ipairs(r.lines or {}) do
        local w = WorkOf(l)
        if w and not l.done then
            local j = byKey[w]
            if not j then
                local def = JOBS[w]
                j = { key = w, label = def.label, game = def.game, spot = def.spot, anim = def.anim, door = def.door, part = def.part, icon = def.icon,
                    tyreOff = def.tyreOff, lines = {} }
                byKey[w] = j
                I.jobs[#I.jobs + 1] = j
            end
            j.lines[#j.lines + 1] = { i = l.i, label = l.label, keys = l.keys, wheels = l.wheels }
        end
    end
    table.sort(I.jobs, function(a, b)
        local ra, rb = 0, 0
        for r2, k in ipairs(ORDER) do if k == a.key then ra = r2 end if k == b.key then rb = r2 end end
        return ra < rb
    end)
    if #I.jobs == 0 then
        -- Rien à poser (prestations seules ou tout est déjà posé) : clôture directe
        Finish()
        return { ok = true }
    end
    Hud()
    Loop()
    C.Notify(('Intervention : %d étape(s). Suivez les flèches autour du véhicule et appuyez sur E.'):format(#I.jobs), 'inform')
    return { ok = true }
end

function C.InstallRunning() return I.running or I.handover ~= nil end
function C.InstallDebug() return I, Spot end   -- (tests hors jeu)

-- ---------------------------------------------------------------------
-- Remise des clés au client : E à côté de lui, animation des deux côtés
-- ---------------------------------------------------------------------
local function ReleaseVehicle(veh)
    if not veh or not DoesEntityExist(veh) then return end
    Control(veh)
    pcall(function() Entity(veh).state:set('mecaLift', false, true) end)
    for d = 0, 5 do SetVehicleDoorShut(veh, d, false) end
    SetVehicleDoorsLocked(veh, 1)
    FreezeEntityPosition(veh, false)
end

CreateThread(function()
    while true do
        local sleep = 500
        local h = I.handover
        if h then
            sleep = 0
            local _, cped = C.PlayerFromServerId(h.customer)
            if cped and DoesEntityExist(cped) then
                local cp = GetEntityCoords(cped)
                DrawMarker(2, cp.x, cp.y, cp.z + 1.25 + math.sin(GetGameTimer() / 300.0) * 0.08, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.28, 0.28, 0.28, 34, 197, 94, 220, false, true, 2, false, nil, nil, false)
                local d = #(GetEntityCoords(PlayerPedId()) - cp)
                if d <= (K.handoverRange or 3.0) then
                    Help(('~INPUT_CONTEXT~ Remettre les clés à %s'):format(h.name or 'votre client'))
                    if IsControlJustPressed(0, 38) and not h.busy then
                        h.busy = true
                        CreateThread(function()
                            local r = C.Req('handoverGive', { uid = h.uid })
                            if r.error then C.Notify(r.error, 'error') end
                            h.busy = false
                        end)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('meca:client:handoverAnim', function(role, other)
    local ped = PlayerPedId()
    local _, oped = C.PlayerFromServerId(other)
    if oped and DoesEntityExist(oped) then TaskTurnPedToFaceEntity(ped, oped, 700) Wait(700) end
    local a = (K.anims or {})[role == 'give' and 'give' or 'take']
    local keys = role == 'give' and HandProp((K.props or {}).keys) or nil
    if a and C.LoadDict(a[1]) then TaskPlayAnim(ped, a[1], a[2], 4.0, 4.0, 1600, a[3] or 48, 0, false, false, false) end
    Wait(1500)
    if keys then
        DeleteProp(keys)
        for i = #I.props, 1, -1 do if I.props[i] == keys then table.remove(I.props, i) end end
    end
    if role == 'take' then PlaySoundFrontend(-1, 'Keys_Collect', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true) end
end)

RegisterNetEvent('meca:client:handoverClosed', function(uid, how)
    local h = I.handover
    if not h or h.uid ~= uid then return end
    ReleaseVehicle(h.veh)
    I.handover = nil
    SendNUIMessage({ action = 'handover', show = false })
    C.Notify(how == 'keys' and 'Clés remises : intervention clôturée.' or 'Véhicule rendu au client : intervention clôturée.', 'success')
end)

-- Le serveur demande au joueur qui contrôle le véhicule de le libérer (mécanicien parti, délai…)
RegisterNetEvent('meca:client:vehicleRelease', function(net)
    local veh = NetworkDoesNetworkIdExist(net) and NetToVeh(net) or 0
    if veh ~= 0 then ReleaseVehicle(veh) end
end)

-- Le mécanicien commence : les occupants descendent
RegisterNetEvent('meca:client:leaveVehicle', function(net)
    local veh = NetworkDoesNetworkIdExist(net) and NetToVeh(net) or 0
    local ped = PlayerPedId()
    if veh ~= 0 and GetVehiclePedIsIn(ped, false) == veh then
        C.Notify('Le mécanicien commence l\'intervention : descendez du véhicule.', 'inform')
        TaskLeaveVehicle(ped, veh, 0)
    end
end)

-- Le mécanicien a quitté le serveur en pleine intervention : ce client contrôle le véhicule et le remet en état
RegisterNetEvent('meca:client:interventionRestore', function(net, base, scene)
    local veh = NetworkDoesNetworkIdExist(net) and NetToVeh(net) or 0
    if veh == 0 or not DoesEntityExist(veh) or type(base) ~= 'table' then return end
    if not NetworkHasControlOfEntity(veh) then NetworkRequestControlOfEntity(veh) Wait(300) end
    if type(scene) == 'table' then
        for _, t in ipairs(type(scene.tyres) == 'table' and scene.tyres or {}) do SetVehicleTyreFixed(veh, tonumber(t) or 0) end
    end
    if tonumber(base.x) then SetEntityCoordsNoOffset(veh, base.x + 0.0, base.y + 0.0, base.z + 0.0, false, false, false) end
    ReleaseVehicle(veh)
end)

-- ---------------------------------------------------------------------
-- Client : suivi en direct de l'intervention sur son véhicule
-- ---------------------------------------------------------------------
RegisterNetEvent('meca:client:jobFeed', function(data)
    if type(data) ~= 'table' then return end
    SendNUIMessage({ action = 'watch', data = data })
end)

-- ---------------------------------------------------------------------
-- Pneus DRIFT : appliqués par le conducteur, seulement sur les véhicules équipés
-- (état du véhicule « mecaDrift » posé par le serveur à l'installation, ou lu sur la carte grise)
-- ---------------------------------------------------------------------
CreateThread(function()
    if (Config.Drift or {}).enabled == false or not SetDriftTyresEnabled then return end
    local asked, n = {}, 0
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and NetworkGetEntityIsNetworked(veh) then
            local st = Entity(veh).state.mecaDrift
            if st == nil then
                local net = VehToNet(veh)
                if not asked[net] then
                    asked[net] = true
                    n = n + 1
                    if n > 500 then asked, n = { [net] = true }, 1 end
                    TriggerServerEvent('meca:server:driftSync', net)
                end
            else
                local cur = GetDriftTyresEnabled(veh)
                if (cur == true or cur == 1) ~= (st == true) then SetDriftTyresEnabled(veh, st == true) end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if I.game then SendNUIMessage({ action = 'minigame', show = false }) end
    if I.running then
        I.running = false
        I.game = nil
        CleanScene(false)
    end
    if I.handover then ReleaseVehicle(I.handover.veh) I.handover = nil end
end)
