-- =====================================================================
--  ELYZEA MÉCANO - client : interventions animées à l'installation d'un devis
--
--  Quand le mécanicien clique « Installer » (devis accepté et payé), au lieu de poser
--  toutes les pièces d'un coup, il réalise réellement le travail :
--   · pont / chandelles, travail allongé sous le véhicule (transmission, échappement,
--     suspension, freins), roues démontées une à une (cric, pneu retiré, nouvelle roue) ;
--   · capot ouvert pour le moteur et le turbo ; capot démonté puis remonté ;
--   · pare-chocs, ailes, aileron, portes, peinture, vitres, éclairage, plaque, intérieur, CarPlay.
--  Chaque pièce est demandée au serveur AU MOMENT de sa pose (quoteInstallStep), posée,
--  relue sur le véhicule, puis confirmée (quoteInstallStepDone) : la facture reste celle
--  du système existant (seules les lignes posées sont facturées).
--
--  Tout est réseau (véhicule contrôlé par le mécanicien, objets en réseau, animations du
--  personnage) : le client et les joueurs autour voient la même scène.
--  Interruption (X, mort, véhicule déplacé ou détruit, éloignement, fin de service) :
--  objets supprimés, véhicule redescendu, capot / pneus remis, contrôles rendus ;
--  le devis reste payé et la suite peut être reprise.
--
--  Animations et modèles : uniquement des noms du jeu ; chaque dictionnaire et chaque
--  modèle est vérifié au chargement (absent → l'étape continue sans lui, rien ne bloque).
-- =====================================================================
local C = MecaC
local IC = Config.Interventions or {}

local I = {
    running = false,     -- une seule séquence à la fois pour ce mécanicien
    veh = nil, uid = nil, base = nil,
    props = {},          -- objets temporaires créés
    liftH = 0.0,         -- hauteur actuelle du véhicule au-dessus de sa position d'origine
    hood = false,        -- capot démonté (à remettre)
    burst = {},          -- pneus retirés pour l'animation (à remettre)
    doors = {},          -- portes / capot / coffre ouverts par l'animation (à refermer)
    lockWas = nil,
    abort = nil,         -- raison de l'interruption
}

-- ---------------------------------------------------------------------
-- Utilitaires
-- ---------------------------------------------------------------------
local function D(key, def) return math.floor(((IC.durations or {})[key] or def) * (IC.speed or 1.0)) end
local function Log(msg) if IC.debug then print('^5[MECA intervention]^7 ' .. msg) end end

local function Control(veh)
    if not veh or not DoesEntityExist(veh) then return false end
    if NetworkHasControlOfEntity(veh) then return true end
    NetworkRequestControlOfEntity(veh)
    local t = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < t do Wait(0) NetworkRequestControlOfEntity(veh) end
    return NetworkHasControlOfEntity(veh)
end

-- Premier modèle existant d'une liste (nil si aucun : l'étape continue sans objet)
local function LoadModel(list)
    for _, name in ipairs(type(list) == 'table' and list or { list }) do
        local h = type(name) == 'number' and name or GetHashKey(name)
        if IsModelInCdimage(h) and IsModelValid(h) then
            RequestModel(h)
            local t = GetGameTimer() + 3000
            while not HasModelLoaded(h) and GetGameTimer() < t do Wait(10) end
            if HasModelLoaded(h) then return h end
        end
        Log(('modèle absent ou non chargé : %s'):format(tostring(name)))
    end
    return nil
end

local function Track(obj) I.props[#I.props + 1] = obj return obj end
local function DeleteProp(obj)
    if obj and DoesEntityExist(obj) then
        DetachEntity(obj, true, false)
        SetEntityAsMissionEntity(obj, true, true)
        DeleteObject(obj)
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    for i = #I.props, 1, -1 do if I.props[i] == obj then table.remove(I.props, i) end end
end
local function ClearProps() for i = #I.props, 1, -1 do DeleteProp(I.props[i]) end I.props = {} end

-- Objet posé dans le décor (au sol, sans collision pour ne bousculer ni le véhicule ni le joueur)
local function SpawnProp(list, pos, heading)
    local h = LoadModel(list)
    if not h then return nil end
    local obj = CreateObject(h, pos.x, pos.y, pos.z, true, true, false)
    SetModelAsNoLongerNeeded(h)
    if not obj or obj == 0 then return nil end
    SetEntityHeading(obj, heading or 0.0)
    SetEntityCollision(obj, false, false)
    FreezeEntityPosition(obj, true)
    return Track(obj)
end

-- Objet tenu en main : spec = { models, bone, pos = {x,y,z}, rot = {x,y,z} } (config.lua)
local function HandProp(spec)
    if not spec then return nil end
    local h = LoadModel(spec.models)
    if not h then return nil end
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local obj = CreateObject(h, c.x, c.y, c.z + 0.2, true, true, false)
    SetModelAsNoLongerNeeded(h)
    if not obj or obj == 0 then return nil end
    SetEntityCollision(obj, false, false)
    local p, r = spec.pos or { 0.0, 0.0, 0.0 }, spec.rot or { 0.0, 0.0, 0.0 }
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, spec.bone or 57005), p[1], p[2], p[3], r[1], r[2], r[3], true, true, false, true, 1, true)
    return Track(obj)
end

-- Hauteur du sol sous un point (repli : sol d'origine sous le véhicule)
local function Ground(pos)
    local ok, z = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 1.5, false)
    if ok and math.abs(z - I.base.ground) < 1.5 then return z end
    return I.base.ground
end

-- Point autour du véhicule : décalage dans le repère du véhicule à sa position d'ORIGINE (le pont ne le déplace pas)
local function Around(x, y)
    local h = math.rad(I.base.heading)
    local wx = I.base.pos.x + x * math.cos(h) - y * math.sin(h)
    local wy = I.base.pos.y + x * math.sin(h) + y * math.cos(h)
    local p = vector3(wx, wy, I.base.pos.z)
    return vector3(wx, wy, Ground(p))
end
-- Cap pour regarder le véhicule depuis un côté : 'left' | 'right' | 'front' | 'rear', ou vers l'extérieur
local function Facing(side, outward)
    local H = I.base.heading
    local f = ({ right = H + 90.0, left = H - 90.0, front = H + 180.0, rear = H })[side] or H
    if outward then f = f + 180.0 end
    return f % 360.0
end

-- Roues du véhicule : os, index GTA du pneu, position locale
local WHEELS = {
    { bone = 'wheel_lf', tyre = 0, side = 'left', label = 'avant gauche' },
    { bone = 'wheel_rf', tyre = 1, side = 'right', label = 'avant droite' },
    { bone = 'wheel_lr', tyre = 4, side = 'left', label = 'arrière gauche' },
    { bone = 'wheel_rr', tyre = 5, side = 'right', label = 'arrière droite' },
}
local function Wheels(veh)
    local out = {}
    for _, w in ipairs(WHEELS) do
        local b = GetEntityBoneIndexByName(veh, w.bone)
        if b ~= -1 then
            local wp = GetWorldPositionOfEntityBone(veh, b)
            local l = GetOffsetFromEntityGivenWorldCoords(veh, wp.x, wp.y, wp.z)
            out[#out + 1] = { bone = w.bone, tyre = w.tyre, side = l.x < 0 and 'left' or 'right', label = w.label, x = l.x, y = l.y }
        end
    end
    return out
end

-- ---------------------------------------------------------------------
-- Interruption : conditions vérifiées à chaque image pendant une étape
-- ---------------------------------------------------------------------
local function Check()
    if I.abort then return false end
    local ped = PlayerPedId()
    local veh = I.veh
    local why
    if not DoesEntityExist(veh) then why = 'le véhicule a disparu'
    elseif IsEntityDead(veh) or GetVehicleEngineHealth(veh) < -3000.0 then why = 'le véhicule est détruit'
    elseif IsEntityDead(ped) or C.IsDown() then why = 'le mécanicien est à terre'
    elseif not C.OnDuty() then why = 'fin de service'
    elseif #(GetEntityCoords(ped) - I.base.pos) > (IC.maxDistance or 12.0) then why = 'le mécanicien s\'est éloigné'
    else
        local vp = GetEntityCoords(veh)
        local flat = vector3(vp.x - I.base.pos.x, vp.y - I.base.pos.y, 0.0)
        if #flat > 0.75 then why = 'le véhicule a été déplacé' end
    end
    if not why and IsDisabledControlJustPressed(0, 73) then why = 'annulée par le mécanicien' end
    if why then I.abort = why return false end
    return true
end

-- Attente de ms millisecondes avec barre de progression (fn = appelée à chaque image)
local function Hold(ms, label, fn)
    if label then SendNUIMessage({ action = 'progress', show = true, label = label .. '  ·  X : interrompre', duration = ms }) end
    local stop = GetGameTimer() + ms
    while GetGameTimer() < stop do
        if not Check() then break end
        if fn then fn() end
        Wait(0)
    end
    if label then SendNUIMessage({ action = 'progress', show = false }) end
    return I.abort == nil
end

local function Stop()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    for i = #I.props, 1, -1 do
        local o = I.props[i]
        if DoesEntityExist(o) and IsEntityAttachedToEntity(o, ped) then DeleteProp(o) end
    end
end

-- ---------------------------------------------------------------------
-- Déplacements : le mécanicien CONTOURNE le véhicule (jamais de téléportation)
-- ---------------------------------------------------------------------
-- Coordonnées dans le repère du véhicule à sa position d'origine
local function ToLocal(p)
    local h = math.rad(I.base.heading)
    local dx, dy = p.x - I.base.pos.x, p.y - I.base.pos.y
    return dx * math.cos(h) + dy * math.sin(h), -dx * math.sin(h) + dy * math.cos(h)
end

-- Le segment a→b traverse-t-il le rectangle [x0,x1]×[y0,y1] ? (Liang-Barsky)
local function SegHitsBox(ax, ay, bx, by, x0, x1, y0, y1)
    local t0, t1 = 0.0, 1.0
    local dx, dy = bx - ax, by - ay
    for _, e in ipairs({ { -dx, ax - x0 }, { dx, x1 - ax }, { -dy, ay - y0 }, { dy, y1 - ay } }) do
        local pp, q = e[1], e[2]
        if pp == 0 then
            if q < 0 then return false end
        else
            local r = q / pp
            if pp < 0 then if r > t1 then return false elseif r > t0 then t0 = r end
            else if r < t0 then return false elseif r < t1 then t1 = r end end
        end
    end
    return t0 <= t1
end

-- Le véhicule est-il assez haut sur le pont pour passer dessous ?
local function CanWalkUnder() return I.liftMode == 'lift' and I.liftH >= (I.liftTop or 99) - 0.05 end

-- Points de passage autour du véhicule (coins d'un rectangle élargi), par le chemin le plus court
local function Route(target)
    local min, max = I.dim.min, I.dim.max
    local px, py = ToLocal(GetEntityCoords(PlayerPedId()))
    local tx, ty = ToLocal(target)
    local pad = IC.collisionPad or 0.3
    if CanWalkUnder() or not SegHitsBox(px, py, tx, ty, min.x - pad, max.x + pad, min.y - pad, max.y + pad) then return { target } end
    local m = IC.walkMargin or 0.85
    local X0, X1, Y0, Y1 = min.x - m, max.x + m, min.y - m, max.y + m
    local e1, e2 = X1 - X0, Y1 - Y0
    local L = 2 * (e1 + e2)
    local corners = { { X0, Y1, 0.0 }, { X1, Y1, e1 }, { X1, Y0, e1 + e2 }, { X0, Y0, 2 * e1 + e2 } }
    -- Position d'un point sur le tour (bord le plus proche)
    local function S(x, y)
        x, y = math.max(X0, math.min(X1, x)), math.max(Y0, math.min(Y1, y))
        local d = { Y1 - y, X1 - x, y - Y0, x - X0 }
        local k, best = 1, d[1]
        for i = 2, 4 do if d[i] < best then k, best = i, d[i] end end
        if k == 1 then return x - X0 elseif k == 2 then return e1 + (Y1 - y) elseif k == 3 then return e1 + e2 + (X1 - x) end
        return 2 * e1 + e2 + (y - Y0)
    end
    local sp, st = S(px, py), S(tx, ty)
    local cw = (st - sp) % L
    local out = {}
    if cw <= L - cw then
        for _, c in ipairs(corners) do
            local d = (c[3] - sp) % L
            if d > 0.01 and d < cw - 0.01 then out[#out + 1] = { d, c } end
        end
    else
        for _, c in ipairs(corners) do
            local d = (sp - c[3]) % L
            if d > 0.01 and d < (L - cw) - 0.01 then out[#out + 1] = { d, c } end
        end
    end
    table.sort(out, function(a, b) return a[1] < b[1] end)
    local pts = {}
    for _, o in ipairs(out) do pts[#pts + 1] = Around(o[2][1], o[2][2]) end
    pts[#pts + 1] = target
    return pts
end

-- Marche jusqu'à un point (fn : appelée à chaque image, ex. garder une pièce en main)
local function WalkTo(pos, heading, fn, final)
    local ped = PlayerPedId()
    local reach = final and 0.3 or 0.55
    TaskGoStraightToCoord(ped, pos.x, pos.y, pos.z, IC.walkSpeed or 1.6, 20000, heading or 0.0, 0.2)
    local last, lastT, navmesh = GetEntityCoords(ped), GetGameTimer(), false
    local deadline = GetGameTimer() + 20000
    while GetGameTimer() < deadline do
        if not Check() then return false end
        if fn then fn() end
        local cur = GetEntityCoords(ped)
        if #(cur.xy - pos.xy) < reach then return true end
        if GetGameTimer() - lastT > 1500 then
            if #(cur.xy - last.xy) < 0.15 then
                if navmesh then
                    -- Toujours bloqué : on accepte une fin de trajet proche, sinon on arrête proprement
                    if #(cur.xy - pos.xy) < 0.7 then return true end
                    I.abort = 'chemin bloqué autour du véhicule'
                    return false
                end
                navmesh = true
                TaskFollowNavMeshToCoord(ped, pos.x, pos.y, pos.z, IC.walkSpeed or 1.6, 8000, 0.25, 0, heading or 0.0)
            end
            last, lastT = cur, GetGameTimer()
        end
        Wait(0)
    end
    return #(GetEntityCoords(ped).xy - pos.xy) < 0.7
end

-- Recalage fin : la marche s'arrête à quelques dizaines de cm du point ; le mécanicien glisse
-- doucement (pas à pas, jamais de saut) jusqu'au point exact et prend l'orientation exacte,
-- pour que l'animation tombe pile sur la roue / le capot / le dessous de caisse.
local function AngleLerp(a, b, t)
    local d = ((b - a + 540.0) % 360.0) - 180.0
    return (a + d * t) % 360.0
end
local function Settle(pos, heading, fn)
    local ped = PlayerPedId()
    local start = GetEntityCoords(ped)
    local dist = #(start.xy - pos.xy)
    if dist > (IC.settleMax or 0.9) then return true end   -- trop loin : on ne force rien
    local h0 = GetEntityHeading(ped)
    local ms = math.max(150, math.floor(dist / (IC.settleSpeed or 1.2) * 1000))
    ClearPedTasks(ped)
    local t0 = GetGameTimer()
    while true do
        if not Check() then return false end
        local k = math.min(1.0, (GetGameTimer() - t0) / ms)
        local z = GetEntityCoords(ped).z
        SetEntityCoordsNoOffset(ped, start.x + (pos.x - start.x) * k, start.y + (pos.y - start.y) * k, z, false, false, false)
        if heading then SetEntityHeading(ped, AngleLerp(h0, heading, k)) end
        if fn then fn() end
        if k >= 1.0 then break end
        Wait(0)
    end
    return true
end

-- Se rendre à un point en faisant le tour du véhicule, puis s'orienter
local function GoTo(pos, heading, fn)
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    local pts = Route(pos)
    for i, p in ipairs(pts) do
        if not WalkTo(p, i == #pts and heading or nil, fn, i == #pts) then return false end
    end
    if heading then
        TaskAchieveHeading(ped, heading, 500)
        local t = GetGameTimer() + 500
        while GetGameTimer() < t do
            if not Check() then return false end
            if fn then fn() end
            Wait(0)
        end
        if not Settle(pos, heading, fn) then return false end
    end
    return Check()
end

-- Sortir de sous le véhicule avant de le descendre (rien ne doit être écrasé)
local function EnsureClear()
    local min, max = I.dim.min, I.dim.max
    local px, py = ToLocal(GetEntityCoords(PlayerPedId()))
    local pad = (IC.collisionPad or 0.3) + 0.25
    if px > min.x - pad and px < max.x + pad and py > min.y - pad and py < max.y + pad then
        ClearPedTasks(PlayerPedId())
        local side = px < 0 and min.x - 1.1 or max.x + 1.1
        return GoTo(Around(side, math.max(min.y + 0.3, math.min(max.y - 0.3, py))), nil)
    end
    return true
end

-- Pose des lignes au milieu d'un geste (le geste continue, il n'est pas coupé)
local ApplyAll   -- défini plus bas
local function HoldApply(ms, label, lines, frac, fn)
    if not lines then return Hold(ms, label, fn) end
    if label then SendNUIMessage({ action = 'progress', show = true, label = label .. '  ·  X : interrompre', duration = ms }) end
    local ok = Hold(ms * (frac or 0.6), nil, fn)
    if ok then ok = ApplyAll(lines) end
    if ok then ok = Hold(ms * (1.0 - (frac or 0.6)), nil, fn) end
    if label then SendNUIMessage({ action = 'progress', show = false }) end
    return ok and I.abort == nil
end

-- Animation en boucle pendant ms (spec = { dict, name, flag }) ; dictionnaire absent → simple attente
local function Anim(spec, ms, label, extra, lines)
    local ped = PlayerPedId()
    local ok = spec and C.LoadDict(spec[1])
    if spec and not ok then Log(('animation absente : %s / %s'):format(spec[1], spec[2])) end
    if ok then TaskPlayAnim(ped, spec[1], spec[2], 3.0, 3.0, -1, spec[3] or 1, 0, false, false, false) end
    local res = HoldApply(ms, label, lines, 0.6, function()
        if ok and not IsEntityPlayingAnim(ped, spec[1], spec[2], 3) then TaskPlayAnim(ped, spec[1], spec[2], 3.0, 3.0, -1, spec[3] or 1, 0, false, false, false) end
        if extra then extra() end
    end)
    if ok then StopAnimTask(ped, spec[1], spec[2], 1.0) end
    return res
end

-- Scénario du jeu à une position (le jeu gère ses propres accessoires, ex. chariot de mécanicien)
-- lines : posées au milieu du scénario, sans que le personnage se relève
local function Scenario(name, pos, heading, ms, label, lines)
    local ped = PlayerPedId()
    local names = type(name) == 'table' and name or { name }
    local here = GetEntityCoords(ped)
    if #(here.xy - pos.xy) < 0.6 then pos = here end   -- déjà placé : le scénario démarre exactement là
    for i, n in ipairs(names) do
        TaskStartScenarioAtPosition(ped, n, pos.x, pos.y, pos.z, heading, 0, false, false)   -- jamais de téléportation
        local t = GetGameTimer() + 1500
        while GetGameTimer() < t and not IsPedUsingScenario(ped, n) do Wait(50) end
        if IsPedUsingScenario(ped, n) or i == #names then break end
        Log(('scénario indisponible : %s'):format(n))
        ClearPedTasks(ped)
    end
    local res = HoldApply(ms, label, lines)
    ClearPedTasks(ped)
    Wait(350)
    return res
end

local A = IC.anims or {}
local PROPS = IC.props or {}

-- Outil en main pendant une animation
local function WithTool(spec, ms, label, toolSpec, lines)
    local tool = HandProp(toolSpec or PROPS.wrench)
    local ok = Anim(spec, ms, label, nil, lines)
    if tool then DeleteProp(tool) end
    return ok
end

-- Porter une pièce jusqu'à un point puis revenir (pièce démontée → établi, nouvelle pièce → véhicule),
-- en faisant le tour du véhicule si besoin
local function Carry(partSpec, to, back, backHeading, label)
    local ped = PlayerPedId()
    local carry = A.carry
    local okDict = carry and C.LoadDict(carry[1])
    local part = HandProp(partSpec)
    local function keep()
        if okDict and not IsEntityPlayingAnim(ped, carry[1], carry[2], 3) then TaskPlayAnim(ped, carry[1], carry[2], 3.0, 3.0, -1, 49, 0, false, false, false) end
    end
    keep()
    SendNUIMessage({ action = 'progress', show = true, label = (label or 'Pièce') .. '  ·  X : interrompre', duration = D('carry', 5000) })
    local ok = GoTo(to, nil, keep)
    if ok then ok = Hold(500, nil, keep) end
    if ok then ok = GoTo(back, backHeading, keep) end
    SendNUIMessage({ action = 'progress', show = false })
    if okDict then StopAnimTask(ped, carry[1], carry[2], 1.0) end
    if part then DeleteProp(part) end
    return ok
end

-- ---------------------------------------------------------------------
-- Véhicule : levage (pont ou chandelles), portes, capot, pneus
-- ---------------------------------------------------------------------
local lift = { props = {} }

-- Monte / descend le véhicule de façon progressive jusqu'à h mètres (position et inclinaison d'origine gardées)
local function LiftTo(h, ms)
    local veh = I.veh
    if not Control(veh) then return false end
    local from = I.liftH
    if math.abs(from - h) < 0.01 then return true end
    if h < from and not I.abort and not EnsureClear() then return false end   -- personne sous le véhicule quand il descend
    local t0 = GetGameTimer()
    local b = I.base
    local moving = lift.platform
    local ok = true
    while true do
        local k = math.min(1.0, (GetGameTimer() - t0) / ms)
        local e = k * k * (3.0 - 2.0 * k)
        local z = from + (h - from) * e
        NetworkRequestControlOfEntity(veh)
        SetEntityCoordsNoOffset(veh, b.pos.x, b.pos.y, b.pos.z + z, false, false, false)
        SetEntityRotation(veh, b.rot.x, b.rot.y, b.rot.z, 2, true)
        if moving and DoesEntityExist(moving) then
            SetEntityCoordsNoOffset(moving, lift.platformPos.x, lift.platformPos.y, lift.platformPos.z + z, false, false, false)
        end
        I.liftH = z
        if k >= 1.0 then break end
        if not DoesEntityExist(veh) then ok = false break end
        Wait(0)
    end
    return ok
end

-- Installe le pont (modèle configuré) ou, à défaut, les chandelles / crics sous les roues
local function LiftSetup(hasLift)
    local L = IC.lift or {}
    if hasLift then
        -- Pont roulant installé sur ce point (objet « Pont roulant ») : dessiné par client/lift.lua,
        -- le véhicule monte assez haut pour que le mécanicien tienne debout dessous
        return C.LiftHeightFor(I.veh), 'lift'
    end
    if L.model then
        local pos = vector3(I.base.pos.x, I.base.pos.y, I.base.ground + (L.offsetZ or 0.0))
        local obj = SpawnProp({ L.model }, pos, (I.base.heading + (L.heading or 0.0)) % 360.0)
        if obj then
            lift.props[#lift.props + 1] = obj
            if L.platformMoves then lift.platform, lift.platformPos = obj, pos end
            return L.height or 1.6, 'lift'
        end
        Log('modèle du pont introuvable : chandelles utilisées')
    end
    for _, w in ipairs(Wheels(I.veh)) do
        local inward = w.x < 0 and 0.35 or -0.35
        local p = Around(w.x + inward, w.y)
        local obj = SpawnProp(PROPS.jack, p, I.base.heading)
        if obj then lift.props[#lift.props + 1] = obj end
    end
    return L.standsHeight or 0.5, 'stands'
end
local function LiftTeardown()
    for _, o in ipairs(lift.props) do DeleteProp(o) end
    lift = { props = {} }
end

-- Bras du pont roulant sous la voiture (vu par tous : état partagé du véhicule)
local function LiftArms(on)
    if not I.veh or not DoesEntityExist(I.veh) then return end
    pcall(function() Entity(I.veh).state:set('mecaLift', on == true, true) end)
end

local function OpenDoor(i)
    local veh = I.veh
    if GetIsDoorValid(veh, i) and not I.doors[i] then
        Control(veh)
        SetVehicleDoorOpen(veh, i, false, false)
        I.doors[i] = true
        Wait(700)
    end
end
local function ShutDoor(i)
    if I.doors[i] and DoesEntityExist(I.veh) then
        Control(I.veh)
        SetVehicleDoorShut(I.veh, i, false)
        I.doors[i] = nil
    end
end

-- Remet en état ce que l'animation a démonté, SANS réparer gratuitement autre chose :
-- SetVehicleFixed n'est utilisé que si la carrosserie était intacte (vérifié avant de démonter)
local function RefitHood()
    local veh = I.veh
    if not I.hood or not DoesEntityExist(veh) then I.hood = false return end
    Control(veh)
    local eng, tank, body, dirt = GetVehicleEngineHealth(veh), GetVehiclePetrolTankHealth(veh), GetVehicleBodyHealth(veh), GetVehicleDirtLevel(veh)
    local burst = {}
    for t = 0, 7 do if IsVehicleTyreBurst(veh, t, false) then burst[#burst + 1] = { t, IsVehicleTyreBurst(veh, t, true) } end end
    SetVehicleFixed(veh)
    SetVehicleEngineHealth(veh, eng) SetVehiclePetrolTankHealth(veh, tank) SetVehicleBodyHealth(veh, body) SetVehicleDirtLevel(veh, dirt)
    for _, b in ipairs(burst) do SetVehicleTyreBurst(veh, b[1], b[2], 1000.0) end
    I.hood = false
end
local function CanDetachHood(veh)
    return IC.detachHood ~= false and GetIsDoorValid(veh, 4) and not IsVehicleDoorDamaged(veh, 4)
        and GetVehicleBodyHealth(veh) >= 995.0 and not IsVehicleDamaged(veh)
end
local function RemoveTyre(w)
    local veh = I.veh
    if IC.removeTyres == false or I.burst[w.tyre] or IsVehicleTyreBurst(veh, w.tyre, false) or not GetVehicleTyresCanBurst(veh) then return end
    Control(veh)
    SetVehicleTyreBurst(veh, w.tyre, true, 1000.0)
    I.burst[w.tyre] = true
end
local function RefitTyre(w)
    if not I.burst[w.tyre] or not DoesEntityExist(I.veh) then return end
    Control(I.veh)
    SetVehicleTyreFixed(I.veh, w.tyre)
    I.burst[w.tyre] = nil
end

-- Remise en état complète de la scène (fin normale ou interruption)
local function CleanScene()
    local ped = PlayerPedId()
    SendNUIMessage({ action = 'progress', show = false })
    ClearPedTasks(ped)
    ClearProps()
    LiftTeardown()
    local veh = I.veh
    if veh and DoesEntityExist(veh) then
        Control(veh)
        RefitHood()
        for t in pairs(I.burst) do SetVehicleTyreFixed(veh, t) end
        if I.liftH > 0.001 then
            -- Interruption avec le mécanicien sous le véhicule : il est sorti sur le côté avant la descente
            local px, py = ToLocal(GetEntityCoords(ped))
            local min, max = I.dim.min, I.dim.max
            if px > min.x - 0.4 and px < max.x + 0.4 and py > min.y - 0.4 and py < max.y + 0.4 then
                local out = Around(px < 0 and min.x - 1.1 or max.x + 1.1, py)
                ClearPedTasksImmediately(ped)
                SetEntityCoordsNoOffset(ped, out.x, out.y, out.z + 1.0, false, false, false)
            end
            LiftTo(0.0, 1200)
        end
        LiftArms(false)
        SetEntityCoordsNoOffset(veh, I.base.pos.x, I.base.pos.y, I.base.pos.z, false, false, false)
        SetEntityRotation(veh, I.base.rot.x, I.base.rot.y, I.base.rot.z, 2, true)
        for d in pairs(I.doors) do SetVehicleDoorShut(veh, d, false) end
        if I.lockWas then SetVehicleDoorsLocked(veh, I.lockWas) end
    end
    I.burst, I.doors, I.liftH, I.hood = {}, {}, 0.0, false
end

-- État de la scène pour le serveur (remise en état si le mécanicien se déconnecte)
local function SceneState()
    local nets = {}
    for _, o in ipairs(I.props) do
        if DoesEntityExist(o) and NetworkGetEntityIsNetworked(o) then nets[#nets + 1] = ObjToNet(o) end
    end
    local tyres = {}
    for t in pairs(I.burst) do tyres[#tyres + 1] = t end
    return { props = nets, tyres = tyres, hood = I.hood, lifted = I.liftH > 0.01 }
end

-- ---------------------------------------------------------------------
-- Pose d'une ligne au bon moment de l'animation (serveur → véhicule → relecture → serveur)
-- ---------------------------------------------------------------------
local function Apply(line)
    if line.applied ~= nil then return line.applied end
    local r = C.Req('quoteInstallStep', { uid = I.uid, i = line.i, scene = SceneState() })
    if r.error then
        C.Notify(r.error, 'error')
        if r.error:find('déjà posée') then line.applied = true return true end
        I.abort = r.error
        return false
    end
    local ok = true
    if r.patch then ok = C.WsApplyPatch(I.veh, r.patch) == true end
    line.applied = ok
    C.Req('quoteInstallStepDone', { uid = I.uid, i = line.i, ok = ok, scene = SceneState() })
    Log(('ligne %d « %s » : %s'):format(line.i, line.label or '?', ok and 'posée' or 'NON posée'))
    if not ok then C.Notify(('« %s » ne s\'est pas posée : elle ne sera pas facturée.'):format(line.label or '?'), 'error') end
    return ok
end
ApplyAll = function(lines) for _, l in ipairs(lines) do if not Apply(l) and I.abort then return false end end return true end

-- ---------------------------------------------------------------------
-- Travaux : chaque type d'intervention a ses déplacements, ses gestes et ses pièces
-- ---------------------------------------------------------------------
local function dims() return I.dim.min, I.dim.max end

-- Allongé sous le véhicule (chandelles) ou debout sous le pont
local function UnderCar(lines, y, label, ms)
    local min, max = dims()
    if I.liftMode == 'lift' then
        -- Véhicule en haut du pont : le mécanicien passe dessous et travaille debout, bras levés
        if I.liftH < (I.liftTop or 0) - 0.05 and not LiftTo(I.liftTop, D('liftUp', 4000)) then return false end
        local p = Around(0.0, y)
        if not GoTo(p, I.base.heading) then return false end
        -- Bras levés, clé en main, comme s'il réparait le dessous de caisse au-dessus de sa tête
        for _, spec in ipairs(IC.underLiftAnims or {}) do
            if C.LoadDict(spec[1]) then return WithTool(spec, ms, label, PROPS.wrench, lines) end
            Log(('animation absente : %s / %s'):format(spec[1], spec[2]))
        end
        return Scenario(IC.underLiftScenarios or { 'PROP_HUMAN_MOVIE_BULB' }, p, I.base.heading, ms, label, lines)
    end
    -- Le mécanicien se met dos au véhicule, puis s'allonge : la tête et le buste passent dessous
    local side = IC.underSide or 'left'
    local x = (side == 'left' and min.x or max.x) + (side == 'left' and -(IC.underOffset or 0.35) or (IC.underOffset or 0.35))
    local p = Around(x, y)
    local h = (Facing(side, true) + (IC.underHeadingOffset or 0.0)) % 360.0
    if not GoTo(p, h) then return false end
    return Scenario('WORLD_HUMAN_VEHICLE_MECHANIC', p, h, ms, label, lines)
end

-- Travail à une roue (agenouillé, clé en main) ; fn(w) appelée au moment du remontage
local function AtWheel(w, label, ms, fn)
    local out = w.x < 0 and -0.75 or 0.75
    local p = Around(w.x + out, w.y)
    if not GoTo(p, Facing(w.side)) then return false end
    if not WithTool(A.kneelWork, ms * 0.5, ('%s · roue %s'):format(label, w.label)) then return false end
    if fn and not fn(w, p) then return false end
    return WithTool(A.kneelWork, ms * 0.5, ('%s · roue %s · serrage'):format(label, w.label))
end

-- Roue changée : desserrage, pneu retiré, roue portée à l'établi, nouvelle roue, serrage
local function WheelSwap(lines, label)
    local ws = Wheels(I.veh)
    if #ws == 0 then return ApplyAll(lines) end
    local jack = I.liftH < 0.05   -- pas de pont : cric roue par roue
    local min, max = dims()
    for n, w in ipairs(ws) do
        local jackProp
        if jack then
            jackProp = SpawnProp(PROPS.jack, Around(w.x + (w.x < 0 and 0.25 or -0.25), w.y), I.base.heading)
            if not LiftTo(IC.jackHeight or 0.12, 1200) then return false end
        end
        local ok = AtWheel(w, label, D('wheel', 9000), function(wh, here)
            RemoveTyre(wh)
            local bench = Around((wh.x < 0 and min.x or max.x) + (wh.x < 0 and -2.0 or 2.0), wh.y)
            if not Carry(PROPS.wheel, bench, here, Facing(wh.side), ('Roue %s : ancienne roue à l\'établi, nouvelle roue'):format(wh.label)) then return false end
            -- GTA pose la même jante sur toutes les roues : elle est appliquée à la première roue remontée
            if n == 1 and not ApplyAll(lines) then return false end
            RefitTyre(wh)
            return true
        end)
        if jackProp then DeleteProp(jackProp) end
        if jack then LiftTo(0.0, 1000) end
        if not ok then return false end
        if IC.allWheels == false and n >= 1 then break end
    end
    return true
end

-- Freins : intervention aux roues avant (et arrière si configuré), étriers en main
local function Brakes(lines)
    local ws = Wheels(I.veh)
    local list = {}
    for _, w in ipairs(ws) do if IC.brakesRear or w.bone == 'wheel_lf' or w.bone == 'wheel_rf' then list[#list + 1] = w end end
    if #list == 0 then list = ws end
    for n, w in ipairs(list) do
        local ok = AtWheel(w, 'Freins', D('brakes', 8000), function(wh)
            RemoveTyre(wh)
            local cal = HandProp(PROPS.caliper)
            local done = Anim(A.kneelWork, D('brakesSwap', 3000), ('Freins · roue %s · étrier et disques'):format(wh.label))
            if cal then DeleteProp(cal) end
            if not done then return false end
            if n == 1 and not ApplyAll(lines) then return false end
            RefitTyre(wh)
            return true
        end)
        if not ok then return false end
    end
    if #list == 0 then return ApplyAll(lines) end
    return true
end

-- Sous le capot (moteur, turbo, pièces du compartiment moteur)
local function UnderHood(lines, label, ms, tool)
    local _, max = dims()
    local p = Around(0.0, max.y + 0.55)
    if not GoTo(p, Facing('front')) then return false end
    OpenDoor(4)
    return WithTool(A.hoodWork, ms, label, tool, lines)
end

-- Capot : ouverture, démontage, ancien capot à l'établi, nouveau capot, remontage, fermeture
local function HoodSwap(lines)
    local veh = I.veh
    local _, max = dims()
    local p = Around(0.0, max.y + 0.6)
    if not GoTo(p, Facing('front')) then return false end
    OpenDoor(4)
    if not WithTool(A.hoodWork, D('hood', 12000) * 0.3, 'Capot · démontage des charnières') then return false end
    if CanDetachHood(veh) then
        Control(veh)
        SetVehicleDoorBroken(veh, 4, true)      -- l'ancien capot disparaît du véhicule
        I.hood = true
        I.doors[4] = nil
    end
    local bench = Around(I.dim.max.x + 2.2, max.y - 0.5)
    if not Carry(PROPS.hood, bench, p, Facing('front'), 'Capot · ancien capot à l\'établi, nouveau capot') then return false end
    if I.hood then RefitHood() end              -- le capot réapparaît…
    if not ApplyAll(lines) then return false end -- … avec la nouvelle pièce
    OpenDoor(4)
    if not WithTool(A.hoodWork, D('hood', 12000) * 0.3, 'Capot · fixation') then return false end
    ShutDoor(4)
    return true
end

-- Pièce extérieure (pare-chocs, aileron, aile…) : démontage, pièce à l'établi, montage, fixation
local function PanelSwap(lines, where, label, partSpec, low)
    local min, max = dims()
    local pts = {
        front = { Around(0.0, max.y + 0.6), Facing('front'), Around(max.x + 2.2, max.y) },
        rear = { Around(0.0, min.y - 0.6), Facing('rear'), Around(max.x + 2.2, min.y) },
        left = { Around(min.x - 0.6, max.y * 0.45), Facing('left'), Around(min.x - 2.5, 0.0) },
        right = { Around(max.x + 0.6, max.y * 0.45), Facing('right'), Around(max.x + 2.5, 0.0) },
        leftMid = { Around(min.x - 0.6, 0.0), Facing('left'), Around(min.x - 2.5, 0.0) },
    }
    local pt = pts[where] or pts.front
    if not GoTo(pt[1], pt[2]) then return false end
    local work = low and A.kneelWork or A.standWork
    if not WithTool(work, D('panel', 10000) * 0.35, label .. ' · démontage') then return false end
    if partSpec and not Carry(partSpec, pt[3], pt[1], pt[2], label .. ' · ancienne pièce à l\'établi, nouvelle pièce') then return false end
    if not ApplyAll(lines) then return false end
    return WithTool(work, D('panel', 10000) * 0.35, label .. ' · fixation')
end

-- Poste fixe (une seule position, une animation) : éclairage, plaque, néons…
local function Simple(lines, pos, heading, anim, label, ms, toolSpec)
    if not GoTo(pos, heading) then return false end
    return WithTool(anim, ms, label, toolSpec, lines)
end

-- Tour du véhicule (peinture, vitres) : un scénario à chaque point, pose à la fin
local function Around4(lines, scenario, label, ms)
    local min, max = dims()
    local pts = {
        { Around(min.x - 0.7, max.y * 0.4), Facing('left') }, { Around(0.0, min.y - 0.8), Facing('rear') },
        { Around(max.x + 0.7, max.y * 0.4), Facing('right') }, { Around(0.0, max.y + 0.8), Facing('front') },
    }
    for n, pt in ipairs(pts) do
        if not GoTo(pt[1], pt[2]) then return false end
        if not Scenario(scenario, pt[1], pt[2], ms / #pts, ('%s (%d/%d)'):format(label, n, #pts)) then return false end
    end
    return ApplyAll(lines)
end

-- Portière conducteur ouverte (intérieur, CarPlay)
local function AtDoor(lines, label, ms, anim, toolSpec)
    local veh = I.veh
    local min, max = dims()
    local d = GetEntityBoneIndexByName(veh, 'door_dside_f')
    local y = 0.4
    if d ~= -1 then
        local wp = GetWorldPositionOfEntityBone(veh, d)
        y = GetOffsetFromEntityGivenWorldCoords(veh, wp.x, wp.y, wp.z).y - 0.4
    end
    local p = Around(min.x - 0.75, y)
    if not GoTo(p, Facing('left')) then return false end
    OpenDoor(0)
    local ok = Simple(lines, p, Facing('left'), anim, label, ms, toolSpec)
    ShutDoor(0)
    return ok
end

-- ---------------------------------------------------------------------
-- Classement des lignes : propriété modifiée → type de travail
-- ---------------------------------------------------------------------
local KEYWORK = {
    modTransmission = 'transmission', modSuspension = 'suspension', modHydrolic = 'suspension', modExhaust = 'exhaust', modBrakes = 'brakes',
    modFrontWheels = 'wheels', wheels = 'wheels', modBackWheels = 'wheels', modCustomTiresF = 'tyres', modCustomTiresR = 'tyres',
    modSmokeEnabled = 'smoke', tyreSmokeColor = 'smoke', wheelColor = 'wheelpaint',
    modEngine = 'engine', modTurbo = 'turbo', modEngineBlock = 'enginebay', modAirFilter = 'enginebay', modStruts = 'enginebay', modHood = 'hood',
    modArmor = 'armor',
    modFrontBumper = 'front', modGrille = 'front', modHorns = 'front', modRearBumper = 'rear', modSpoilers = 'spoiler', modTrunk = 'trunk',
    modSideSkirt = 'skirt', modFender = 'fender_l', modRightFender = 'fender_r', modArchCover = 'skirt', modTrimB = 'skirt', modTank = 'skirt',
    modDoorR = 'doors', modRoof = 'roof', modFrame = 'roof', modAerials = 'roof', modLightbar = 'roof', modWindows = 'windows',
    windowTint = 'tint', color1 = 'paint', color2 = 'paint', paintType1 = 'paint', paintType2 = 'paint', pearlescentColor = 'paint',
    modLivery = 'paint', modRoofLivery = 'paint',
    neonEnabled = 'neon', neonColor = 'neon', modXenon = 'lights', xenonColor = 'lights',
    plateIndex = 'plate', modPlateHolder = 'plate', modVanityPlate = 'plate',
    interiorColor = 'interior', dashboardColor = 'interior', modTrimA = 'interior', modOrnaments = 'interior', modDashboard = 'interior',
    modDial = 'interior', modDoorSpeaker = 'interior', modSeats = 'interior', modSteeringWheel = 'interior', modShifterLeavers = 'interior',
    modAPlate = 'interior', modSpeakers = 'interior', extras = 'extras',
}
-- Ordre logique : tout ce qui se fait levé (une seule montée), puis capot, carrosserie, finitions
local ORDER = { 'transmission', 'exhaust', 'suspension', 'brakes', 'wheels', 'tyres', 'wheelpaint', 'smoke',
    'engine', 'turbo', 'enginebay', 'hood', 'armor', 'front', 'rear', 'trunk', 'spoiler', 'fender_l', 'fender_r', 'skirt', 'doors',
    'roof', 'extras', 'paint', 'windows', 'tint', 'lights', 'neon', 'plate', 'interior', 'carplay' }
local LIFT_WORK = { transmission = true, exhaust = true, suspension = true, brakes = true }
local HOOD_WORK = { engine = true, turbo = true, enginebay = true }

local function WorkOf(line)
    if line.kind == 'carplay' then return 'carplay' end
    if line.plate then return 'plate' end
    if line.kind == 'service' or line.kind == 'custom' then return nil end
    local best, bestRank
    for _, k in ipairs(line.keys or {}) do
        local w = KEYWORK[k]
        if w then
            local rank
            for r, o in ipairs(ORDER) do if o == w then rank = r break end end
            if rank and (not bestRank or rank < bestRank) then best, bestRank = w, rank end
        end
    end
    return best or 'extras'
end

local function RunWork(work, lines)
    local min, max = dims()
    local L = ('%s'):format(lines[1].label or work)
    if work == 'transmission' then return UnderCar(lines, 0.0, 'Transmission · boîte et cardan', D('transmission', 14000))
    elseif work == 'exhaust' then return UnderCar(lines, min.y * 0.55, 'Échappement · ligne et silencieux', D('exhaust', 12000))
    elseif work == 'suspension' then return UnderCar(lines, max.y * 0.45, 'Suspension · amortisseurs et ressorts', D('suspension', 12000))
    elseif work == 'brakes' then return Brakes(lines)
    elseif work == 'wheels' then return WheelSwap(lines, 'Jantes')
    elseif work == 'tyres' then return WheelSwap(lines, 'Pneus')
    elseif work == 'wheelpaint' or work == 'smoke' then
        local w = Wheels(I.veh)[work == 'smoke' and 3 or 1] or Wheels(I.veh)[1]
        if not w then return ApplyAll(lines) end
        return AtWheel(w, L, D('wheelpaint', 7000), function() return ApplyAll(lines) end)
    elseif work == 'engine' then return UnderHood(lines, 'Moteur · culasse et injection', D('engine', 14000))
    elseif work == 'turbo' then return UnderHood(lines, 'Turbo · turbocompresseur et durites', D('turbo', 14000), PROPS.turboPart or PROPS.wrench)
    elseif work == 'enginebay' then return UnderHood(lines, L, D('enginebay', 10000))
    elseif work == 'hood' then return HoodSwap(lines)
    elseif work == 'armor' then
        if not GoTo(Around(min.x - 0.7, 0.0), Facing('left')) then return false end
        if not Scenario('WORLD_HUMAN_WELDING', Around(min.x - 0.7, 0.0), Facing('left'), D('armor', 14000) / 2, 'Blindage · soudure côté gauche') then return false end
        if not GoTo(Around(max.x + 0.7, 0.0), Facing('right')) then return false end
        if not Scenario('WORLD_HUMAN_WELDING', Around(max.x + 0.7, 0.0), Facing('right'), D('armor', 14000) / 2, 'Blindage · soudure côté droit') then return false end
        return ApplyAll(lines)
    elseif work == 'front' then return PanelSwap(lines, 'front', 'Pare-chocs avant', PROPS.frontBumper, true)
    elseif work == 'rear' then return PanelSwap(lines, 'rear', 'Pare-chocs arrière', PROPS.rearBumper, true)
    elseif work == 'spoiler' then return PanelSwap(lines, 'rear', 'Aileron', PROPS.spoiler, false)
    elseif work == 'trunk' then
        OpenDoor(5)
        local ok = PanelSwap(lines, 'rear', 'Coffre', nil, false)
        ShutDoor(5)
        return ok
    elseif work == 'fender_l' then return PanelSwap(lines, 'left', 'Aile gauche', PROPS.panel, false)
    elseif work == 'fender_r' then return PanelSwap(lines, 'right', 'Aile droite', PROPS.panel, false)
    elseif work == 'skirt' then return PanelSwap(lines, 'leftMid', L, PROPS.panel, true)
    elseif work == 'doors' then
        OpenDoor(0) OpenDoor(1)
        local ok = PanelSwap(lines, 'leftMid', 'Portières', PROPS.door, false)
        ShutDoor(0) ShutDoor(1)
        return ok
    elseif work == 'roof' or work == 'extras' then return Simple(lines, Around(min.x - 0.7, 0.0), Facing('left'), A.standWork, L, D('roof', 9000))
    elseif work == 'paint' then return Around4(lines, IC.paintScenario or 'WORLD_HUMAN_MAID_CLEAN', 'Peinture · préparation et application', D('paint', 16000))
    elseif work == 'windows' or work == 'tint' then
        local pts = { { Around(min.x - 0.7, 0.2), Facing('left') }, { Around(max.x + 0.7, 0.2), Facing('right') } }
        for n, pt in ipairs(pts) do
            if not GoTo(pt[1], pt[2]) then return false end
            if not Scenario(IC.paintScenario or 'WORLD_HUMAN_MAID_CLEAN', pt[1], pt[2], D('tint', 9000) / 2, ('Vitres · film et pose (%d/2)'):format(n)) then return false end
        end
        return ApplyAll(lines)
    elseif work == 'lights' then
        OpenDoor(4)
        local ok = Simple(lines, Around(max.x * 0.6, max.y + 0.6), Facing('front'), A.hoodWork, 'Éclairage · phares', D('lights', 8000))
        ShutDoor(4)
        return ok
    elseif work == 'neon' then return Simple(lines, Around(min.x - 0.7, 0.0), Facing('left'), A.kneelWork, 'Néons · bandeaux et câblage', D('neon', 9000), PROPS.wrench)
    elseif work == 'plate' then return Simple(lines, Around(0.0, min.y - 0.6), Facing('rear'), A.kneel, 'Plaque · démontage et pose', D('plate', 7000), PROPS.wrench)
    elseif work == 'interior' then return AtDoor(lines, 'Intérieur · démontage et pose', D('interior', 10000), A.interior)
    elseif work == 'carplay' then return AtDoor(lines, 'CarPlay · installation et appairage', D('carplay', 10000), A.tablet, PROPS.tablet)
    end
    return ApplyAll(lines)
end

-- ---------------------------------------------------------------------
-- Séquence complète
-- ---------------------------------------------------------------------
local BLOCKED_CONTROLS = { 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 44, 75, 140, 141, 142, 257, 263 }   -- créée une seule fois
local function DisableControls()
    CreateThread(function()
        while I.running do
            for _, c in ipairs(BLOCKED_CONTROLS) do DisableControlAction(0, c, true) end
            DisableControlAction(0, 73, true)   -- X : lu par Check() pour interrompre
            Wait(0)
        end
    end)
    -- Sécurité anti-chute : le personnage ne peut pas passer sous le sol ni tomber dans le vide.
    -- Dernière position sûre mémorisée en continu ; en cas de chute, il y est remis (seul cas de replacement).
    CreateThread(function()
        local ped = PlayerPedId()
        local g = I.base.ground
        I.safe = GetEntityCoords(ped)
        SetPedCanRagdoll(ped, false)
        local fallingSince
        while I.running do
            ped = PlayerPedId()
            RequestCollisionAtCoord(I.base.pos.x, I.base.pos.y, I.base.pos.z)
            local p = GetEntityCoords(ped)
            local falling = IsPedFalling(ped) or IsEntityInAir(ped)
            if not falling and math.abs(p.z - (g + 1.0)) < 1.2 then I.safe, fallingSince = p, nil end
            if falling then fallingSince = fallingSince or GetGameTimer() end
            if p.z < g - 0.8 or (fallingSince and GetGameTimer() - fallingSince > 700) or p.z > g + 3.5 then
                ClearPedTasksImmediately(ped)
                SetEntityVelocity(ped, 0.0, 0.0, 0.0)
                SetEntityCoordsNoOffset(ped, I.safe.x, I.safe.y, I.safe.z, false, false, false)
                fallingSince = nil
                Log('chute évitée : personnage replacé')
            end
            Wait(0)
        end
        SetPedCanRagdoll(PlayerPedId(), true)
    end)
    -- Le serveur sait que le mécanicien est toujours là pendant les longues étapes
    CreateThread(function()
        while I.running do
            Wait(15000)
            if I.running then C.Req('quoteInstallBeat', { uid = I.uid, scene = SceneState() }) end
        end
    end)
end

local function LeaveVehicle(veh)
    local ped = PlayerPedId()
    if GetVehiclePedIsIn(ped, false) ~= veh and not IsPedInAnyVehicle(ped, false) then return true end
    TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
    local t = GetGameTimer() + 5000
    while IsPedInAnyVehicle(ped, false) and GetGameTimer() < t do Wait(50) end
    return not IsPedInAnyVehicle(ped, false)
end

local function Occupied(veh)
    for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
        if not IsVehicleSeatFree(veh, seat) then return true end
    end
    return false
end

-- Lance l'intervention d'un devis accepté. Renvoie le résultat final (facture) ou { aborted = true, message }.
function C.RunIntervention(veh, uid, netId)
    if I.running then return { error = 'Une intervention est déjà en cours.' } end
    if IsEntityUpsidedown(veh) or math.abs(GetEntityRoll(veh)) > 15.0 then return { error = 'Le véhicule doit être sur ses roues.' } end
    if GetEntitySpeed(veh) > 0.3 then return { error = 'Le véhicule doit être à l\'arrêt.' } end
    local ped = PlayerPedId()
    if not LeaveVehicle(veh) then return { error = 'Sortez du véhicule.' } end

    local r = C.Req('quoteInstallStart', { uid = uid, net = netId })
    if r.error then return r end

    I.running, I.veh, I.uid, I.abort = true, veh, uid, nil
    I.props, I.burst, I.doors, I.liftH, I.hood, I.liftMode = {}, {}, {}, 0.0, false, nil
    local min, max = GetModelDimensions(GetEntityModel(veh))
    local pos = GetEntityCoords(veh)
    I.dim = { min = min, max = max }
    I.base = { pos = pos, rot = GetEntityRotation(veh, 2), heading = GetEntityHeading(veh), ground = pos.z - GetEntityHeightAboveGround(veh) }
    DisableControls()

    -- Personne dans le véhicule, portes verrouillées pendant le travail
    Control(veh)
    local t = GetGameTimer() + 8000
    while Occupied(veh) and GetGameTimer() < t do Wait(200) end
    if Occupied(veh) then I.abort = 'le véhicule doit être vide' end
    if not I.abort then
        I.lockWas = GetVehicleDoorLockStatus(veh)
        SetVehicleDoorsLocked(veh, 2)
        SetVehicleEngineOn(veh, false, true, true)
    end

    -- Plan : une ligne → un type de travail ; ordre logique, sans chevauchement
    local byWork = {}
    for _, l in ipairs(r.lines or {}) do
        local w = WorkOf(l)
        if w and not l.done then byWork[w] = byWork[w] or {} table.insert(byWork[w], l) end
    end
    local needLift = false
    for w in pairs(byWork) do if LIFT_WORK[w] then needLift = true end end

    -- 1. Travaux levés : une seule montée du véhicule pour tout ce qui se fait dessous et aux roues
    if not I.abort and needLift then
        local h, mode = LiftSetup(r.lift == true)
        I.liftMode, I.liftTop = mode, h
        if mode == 'lift' then
            -- Les 4 bras pivotent sous les points de levage avant la montée
            LiftArms(true)
            Hold(D('liftArms', 1200), 'Pont roulant : bras sous la voiture')
        end
        SendNUIMessage({ action = 'progress', show = true, label = mode == 'lift' and 'Montée sur le pont élévateur' or 'Mise sur chandelles', duration = D('liftUp', 4000) })
        LiftTo(h, D('liftUp', 4000))
        SendNUIMessage({ action = 'progress', show = false })
        for _, w in ipairs(ORDER) do
            if I.abort then break end
            if byWork[w] and (LIFT_WORK[w] or w == 'wheels' or w == 'tyres' or w == 'wheelpaint' or w == 'smoke') then
                -- Sur le pont : travaux de dessous en haut, puis le véhicule redescend à hauteur des roues
                if mode == 'lift' and not (w == 'transmission' or w == 'exhaust' or w == 'suspension') and I.liftH > (IC.lift and IC.lift.wheelHeight or 0.5) + 0.05 then
                    Stop()
                    if not LiftTo((IC.lift and IC.lift.wheelHeight) or 0.5, D('liftDown', 3500)) then break end
                end
                if not RunWork(w, byWork[w]) then break end
                byWork[w] = nil
            end
        end
        if not I.abort then
            Stop()
            SendNUIMessage({ action = 'progress', show = true, label = 'Descente du véhicule', duration = D('liftDown', 3500) })
            if not LiftTo(0.0, D('liftDown', 3500)) and not I.abort then I.abort = 'descente impossible' end
            LiftArms(false)
            SendNUIMessage({ action = 'progress', show = false })
            LiftTeardown()
        end
    end
    -- 2. Le reste, dans l'ordre (le capot reste ouvert entre moteur, turbo et compartiment moteur)
    for _, w in ipairs(ORDER) do
        if I.abort then break end
        if byWork[w] then
            Stop()
            if not RunWork(w, byWork[w]) then break end
            byWork[w] = nil
            local nextHood = false
            for _, n in ipairs(ORDER) do if byWork[n] and HOOD_WORK[n] then nextHood = true break end end
            if HOOD_WORK[w] and not nextHood then ShutDoor(4) end
        end
    end
    -- Toute ligne restée sans travail (aucune ne devrait) est posée sans animation
    if not I.abort then for _, ls in pairs(byWork) do ApplyAll(ls) end end

    -- Fin : scène remise en état dans tous les cas
    local aborted = I.abort
    CleanScene()
    if not aborted then
        local anim = A.finish
        if anim and C.LoadDict(anim[1]) then TaskPlayAnim(ped, anim[1], anim[2], 3.0, 3.0, 1500, 48, 0, false, false, false) Wait(1200) end
    end
    ClearPedTasks(ped)
    I.running = false
    SetPedCanRagdoll(PlayerPedId(), true)

    if aborted then
        local a = C.Req('quoteInstallAbort', { uid = uid, reason = aborted, cleaned = true })
        I.veh, I.uid = nil, nil
        return { aborted = true, message = ('Intervention interrompue (%s). %s'):format(aborted, a.message or '') }
    end
    local done = C.Req('quoteInstallDone', { uid = uid })
    I.veh, I.uid = nil, nil
    return done
end

function C.InterventionRunning() return I.running end

-- ---------------------------------------------------------------------
-- Événements du serveur
-- ---------------------------------------------------------------------
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
        if scene.hood then   -- capot démonté par l'animation (carrosserie vérifiée intacte avant)
            local eng, tank, body, dirt = GetVehicleEngineHealth(veh), GetVehiclePetrolTankHealth(veh), GetVehicleBodyHealth(veh), GetVehicleDirtLevel(veh)
            SetVehicleFixed(veh)
            SetVehicleEngineHealth(veh, eng) SetVehiclePetrolTankHealth(veh, tank) SetVehicleBodyHealth(veh, body) SetVehicleDirtLevel(veh, dirt)
        end
        for _, t in ipairs(type(scene.tyres) == 'table' and scene.tyres or {}) do SetVehicleTyreFixed(veh, tonumber(t) or 0) end
    end
    if tonumber(base.x) then SetEntityCoordsNoOffset(veh, base.x + 0.0, base.y + 0.0, base.z + 0.0, false, false, false) end
    for d = 0, 5 do SetVehicleDoorShut(veh, d, false) end
    SetVehicleDoorsLocked(veh, 1)
    FreezeEntityPosition(veh, false)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not I.running then return end
    I.abort = 'arrêt de la ressource'
    CleanScene()
    I.running = false
    SetPedCanRagdoll(PlayerPedId(), true)
end)
