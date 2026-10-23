-- =====================================================================
--  ELYZEA DROGUES · scènes (client) : placement des objets, chaise, animations, objets tenus
--  Toutes les positions sont calculées avec les dimensions réelles des modèles (GetModelDimensions) :
--  un objet « sur le dessus » touche le plateau, un objet « au sol » touche le sol du poste.
-- =====================================================================
DrugScene = {}
local SC = DrugScene

local function loadModel(model)
    local h = type(model) == 'number' and model or GetHashKey(model or '')
    if not IsModelInCdimage(h) then return nil end
    RequestModel(h)
    local t = GetGameTimer() + 4000
    while not HasModelLoaded(h) and GetGameTimer() < t do Wait(0) end
    return HasModelLoaded(h) and h or nil
end
SC.LoadModel = loadModel

-- Premier modèle de la liste présent dans le jeu
function SC.FirstModel(list)
    for _, m in ipairs(list or {}) do if IsModelInCdimage(GetHashKey(m)) then return m end end
    return nil
end

-- Position locale (repère du poste) d'un objet de scène
local function localPos(stationEnt, spec, propHash)
    local smn, smx = GetModelDimensions(GetEntityModel(stationEnt))
    local pmn = propHash and select(1, GetModelDimensions(propHash)) or vector3(0.0, 0.0, 0.0)
    local cx, cy = (smn.x + smx.x) / 2, (smn.y + smx.y) / 2
    local hx, hy = (smx.x - smn.x) / 2, (smx.y - smn.y) / 2
    if spec.at == 'ground' then
        local out = spec.out or 0.35
        local lx = spec.fx >= 0.99 and (smx.x + out) or spec.fx <= -0.99 and (smn.x - out) or (cx + spec.fx * hx)
        local ly = spec.fy >= 0.99 and (smx.y + out) or spec.fy <= -0.99 and (smn.y - out) or (cy + spec.fy * hy)
        return lx, ly, smn.z - pmn.z
    end
    -- sur le dessus : on reste à 80 % de l'emprise pour ne pas déborder du plateau
    return cx + spec.fx * hx * 0.8, cy + spec.fy * hy * 0.8, smx.z - pmn.z + 0.005
end

-- Crée un objet de scène autour d'un poste. networked : visible des autres joueurs (objets temporaires)
function SC.Place(stationEnt, spec, networked)
    if not stationEnt or not DoesEntityExist(stationEnt) then return nil end
    local model = SC.FirstModel(spec.models)
    local h = model and loadModel(model)
    if not h or not DoesEntityExist(stationEnt) then return nil end
    local lx, ly, lz = localPos(stationEnt, spec, h)
    local p = GetOffsetFromEntityInWorldCoords(stationEnt, lx, ly, lz)
    local o = CreateObjectNoOffset(h, p.x, p.y, p.z, networked == true, networked == true, false)
    SetModelAsNoLongerNeeded(h)
    if not o or o == 0 then return nil end
    SetEntityRotation(o, 0.0, 0.0, GetEntityHeading(stationEnt) + (spec.h or 0.0), 2, true)
    FreezeEntityPosition(o, true)
    SetEntityInvincible(o, true)
    return o
end

-- Chaise du décor : devant le côté « avant » du poste (bord -Y), tournée vers lui
function SC.PlaceChair(stationEnt)
    local model = SC.FirstModel(Config.SceneModels.chair)
    local h = model and loadModel(model)
    if not h or not DoesEntityExist(stationEnt) then return nil end
    local smn = GetModelDimensions(GetEntityModel(stationEnt))
    local cmn, cmx = GetModelDimensions(h)
    local depth = (cmx.y - cmn.y) / 2
    local smn2, smx2 = GetModelDimensions(GetEntityModel(stationEnt))
    local p = GetOffsetFromEntityInWorldCoords(stationEnt, (smn2.x + smx2.x) / 2, smn.y - depth - 0.12, smn.z - cmn.z)
    local o = CreateObjectNoOffset(h, p.x, p.y, p.z, false, false, false)
    SetModelAsNoLongerNeeded(h)
    if not o or o == 0 then return nil end
    -- les chaises de GTA ont l'assise tournée vers -Y : +180° pour faire face au poste
    SetEntityRotation(o, 0.0, 0.0, GetEntityHeading(stationEnt) + 180.0, 2, true)
    FreezeEntityPosition(o, true)
    SetEntityInvincible(o, true)
    return o
end

-- ---------------------------------------------------------------- animations
local function loadDict(dict)
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
    return HasAnimDictLoaded(dict)
end

-- Joue l'animation (ou son repli). Renvoie la description réellement jouée (pour l'arrêter proprement)
-- Hauteur des pieds (le plus bas des deux)
local function feetZ(ped)
    local l, r = GetPedBoneCoords(ped, 14201, 0.0, 0.0, 0.0), GetPedBoneCoords(ped, 52301, 0.0, 0.0, 0.0)
    return math.min(l.z, r.z)
end

-- Joue l'animation (ou son repli). Garde-fou : si l'animation soulève le personnage (pieds à plus de
-- 20 cm de leur hauteur de départ — animations de scène de GTA prévues pour une autre position),
-- elle est arrêtée et le repli est joué. Renvoie la description réellement jouée.
function SC.PlayAnim(ped, spec)
    local s = spec
    local base = feetZ(ped)
    while s do
        if s.scenario then
            TaskStartScenarioInPlace(ped, s.scenario, 0, true)
            return s
        elseif s.dict and loadDict(s.dict) then
            TaskPlayAnim(ped, s.dict, s.clip, 3.0, 3.0, -1, s.flag or 1, 0, false, false, false)
            RemoveAnimDict(s.dict)
            Wait(450)
            if feetZ(ped) - base <= 0.2 or not s.fb then return s end
            print(('^3[elyzea_drogues] animation %s/%s : personnage soulevé, repli utilisé^0'):format(s.dict, s.clip))
            StopAnimTask(ped, s.dict, s.clip, 8.0)
        end
        s = s.fb
    end
    return nil
end
function SC.StopAnim(ped, played)
    if not played then return end
    if played.scenario then ClearPedTasks(ped) else StopAnimTask(ped, played.dict, played.clip, 1.5) end
end

-- ---------------------------------------------------------------- objet tenu en main
function SC.Hand(ped, spec, networked)
    local model = SC.FirstModel(spec.models)
    local h = model and loadModel(model)
    if not h then return nil end
    local c = GetEntityCoords(ped)
    local o = CreateObject(h, c.x, c.y, c.z + 0.2, networked == true, networked == true, false)
    SetModelAsNoLongerNeeded(h)
    if not o or o == 0 then return nil end
    local p, r = spec.pos or { 0.0, 0.0, 0.0 }, spec.rot or { 0.0, 0.0, 0.0 }
    AttachEntityToEntity(o, ped, GetPedBoneIndex(ped, spec.bone or 28422), p[1], p[2], p[3], r[1], r[2], r[3], true, true, false, true, 1, true)
    SetEntityCollision(o, false, false)
    return o
end

-- ---------------------------------------------------------------- placement du personnage
-- Point d'approche : milieu du côté du poste le plus proche du joueur, à 0,55 m du bord
function SC.ApproachPoint(stationEnt, ped)
    local mn, mx = GetModelDimensions(GetEntityModel(stationEnt))
    local cx, cy = (mn.x + mx.x) / 2, (mn.y + mx.y) / 2
    local pc = GetEntityCoords(ped)
    local best, bd
    for _, l in ipairs({ { cx, mn.y - 0.55 }, { cx, mx.y + 0.55 }, { mn.x - 0.55, cy }, { mx.x + 0.55, cy } }) do
        local w = GetOffsetFromEntityInWorldCoords(stationEnt, l[1], l[2], 0.0)
        local d = #(vector2(w.x, w.y) - vector2(pc.x, pc.y))
        if not bd or d < bd then best, bd = w, d end
    end
    local center = GetOffsetFromEntityInWorldCoords(stationEnt, cx, cy, 0.0)
    return best, GetHeadingFromVector_2d(center.x - best.x, center.y - best.y)
end

-- Marche jusqu'au point (4 s max), puis se tourne. Renvoie false si le joueur a bougé / annulé
function SC.WalkTo(ped, x, y, heading)
    local z = GetEntityCoords(ped).z
    if #(vector2(x, y) - GetEntityCoords(ped).xy) > 0.25 then
        TaskGoStraightToCoord(ped, x, y, z, 1.0, 4000, heading, 0.15)
        local t = GetGameTimer() + 4000
        while GetGameTimer() < t do
            Wait(50)
            if #(vector2(x, y) - GetEntityCoords(ped).xy) < 0.3 then break end
            if IsPedRagdoll(ped) or IsEntityDead(ped) then return false end
        end
    end
    ClearPedTasks(ped)
    SetEntityHeading(ped, heading)
    return true
end

-- Assise sur la chaise du décor : scénario « assis sur une chaise » de GTA placé sur l'assise.
-- Le jeu gère la posture complète : fessier sur la chaise, pieds au sol, buste vers la table.
-- (Avant : animation assise jouée debout, le personnage flottait.)  off = réglage du staff { x, y, z, h }.
SC.SEAT_SCENARIOS = { 'PROP_HUMAN_SEAT_COMPUTER', 'PROP_HUMAN_SEAT_CHAIR_MP_PLAYER' }   -- mains sur la table, sinon assis simple
SC.SEAT_HEIGHT = 0.5      -- hauteur de l'assise au-dessus du sol (m), réglable par /drogues_assise (Z)

function SC.SeatPose(chair, off)
    off = off or {}
    local cmn = GetModelDimensions(GetEntityModel(chair))
    local floorZ = GetEntityCoords(chair).z + cmn.z
    local p = GetOffsetFromEntityInWorldCoords(chair, off.x or 0.0, off.y or 0.0, 0.0)
    return vector3(p.x, p.y, floorZ + SC.SEAT_HEIGHT + (off.z or 0.0)), GetEntityHeading(chair) + 180.0 + (off.h or 0.0), floorZ
end

function SC.SitAt(ped, chair, off)
    local pos, heading = SC.SeatPose(chair, off)
    ClearPedTasksImmediately(ped)
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(ped, heading)
    -- assis = true, téléportation = true : installé directement, sans le geste d'entrée
    TaskStartScenarioAtPosition(ped, SC.SEAT_SCENARIOS[1], pos.x, pos.y, pos.z, heading, 0, true, true)
    Wait(150)
    if not IsPedUsingScenario(ped, SC.SEAT_SCENARIOS[1]) then
        TaskStartScenarioAtPosition(ped, SC.SEAT_SCENARIOS[2], pos.x, pos.y, pos.z, heading, 0, true, true)
    end
end

-- Directement assis : pas de marche jusqu'à la chaise ni de geste pour s'asseoir (téléporté sur l'assise)
function SC.Sit(ped, chair, off)
    local front = GetOffsetFromEntityInWorldCoords(chair, 0.0, -0.6, 0.0)    -- l'assise regarde vers -Y
    local heading = GetEntityHeading(chair) + 180.0
    local _, _, floorZ = SC.SeatPose(chair, off)
    local standZ = floorZ + math.max(0.9, math.min(1.1, GetEntityHeightAboveGround(ped)))   -- hauteur du personnage debout
    SC.SitAt(ped, chair, off)
    return { front = front, z = standZ, heading = heading, chair = chair, seated = true }
end

-- Se relever : directement debout devant la chaise (jamais coincé dans la chaise ni dans la table).
function SC.StandUp(ped, sat, quick)
    FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)      -- debout tout de suite, devant la chaise (pas de geste pour se lever)
    if sat then
        SetEntityCoordsNoOffset(ped, sat.front.x, sat.front.y, sat.z, false, false, false)
        SetEntityHeading(ped, sat.heading)
    end
end
