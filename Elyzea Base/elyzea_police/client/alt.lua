-- =====================================================================
--  ELYZEA POLICE - client : menu ALT (pour tout le monde)
--  ALT maintenu : curseur ; le CONTOUR de la cible survolée qui a des actions s'illumine (silhouette dessinée,
--  pas le contour natif SetEntityDrawOutline qui faisait planter le jeu) ; ALT + clic gauche : actions possibles.
--  Tout le monde : porter, coffre (ouvrir, se cacher, sortir quelqu'un).
--  Agents en service avec la permission « alt » : menottes, escorte, véhicule, amende, fourrière.
--  EMS en service (elyzea_ems) : examen, soins, réanimation, ambulance, facture, PPA.
--  Mécano en service (elyzea_meca) : réparer, nettoyer, retourner, historique, devis (exports AltOptions / AltSelect).
--  Animations (elyzea_animations) : copier l'animation d'une personne, lui proposer une animation à deux.
--  Bébé (elyzea_bebe_modele) : prendre, poser, changer de prise, installer dans la poussette, pousser, garer.
--  Le menu reste ouvert après avoir lâché ALT ; Échap ou clic à côté pour le fermer.
-- =====================================================================
local C = PoliceC
local D = Config.Distances
local active, menuOpen = false, false
local menuCtx, menuOpts = nil, nil

-- Rayon de la caméra passant par un point de l'écran (0..1) ; par défaut, le curseur
local function CursorRay(sx, sy)
    sx, sy = sx or GetControlNormal(0, 239), sy or GetControlNormal(0, 240)
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local fwd = vector3(-math.sin(rz) * math.cos(rx), math.cos(rz) * math.cos(rx), math.sin(rx))
    local right = vector3(math.cos(rz), math.sin(rz), 0.0)
    local up = vector3(right.y * fwd.z - right.z * fwd.y, right.z * fwd.x - right.x * fwd.z, right.x * fwd.y - right.y * fwd.x)
    local t = math.tan(math.rad(GetGameplayCamFov()) / 2)
    local dir = fwd + right * ((sx * 2.0 - 1.0) * t * GetAspectRatio(false)) + up * (-(sy * 2.0 - 1.0) * t)
    return GetGameplayCamCoord(), dir / #dir
end

-- Personne la plus proche devant soi (secours si le curseur ne touche rien)
local function FacingPlayer()
    local me = PlayerPedId()
    local pc, fwd = GetEntityCoords(me), GetEntityForwardVector(me)
    local best, bestD
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local ped = GetPlayerPed(pid)
            local v = GetEntityCoords(ped) - pc
            local d = #v
            if d <= 2.5 and (d < 1.0 or (v.x * fwd.x + v.y * fwd.y) / d > 0.3) and (not bestD or d < bestD) then best, bestD = ped, d end
        end
    end
    return best
end

-- Ressources métier qui ajoutent leurs actions au menu ALT (exports AltOptions / AltSelect)
-- target = true : la ressource a ses propres cibles (PNJ, objets) via AltTarget(entité) / AltNearby()
local ALT_PROVIDERS = {
    { res = 'elyzea_ems', prefix = 'ems:' },
    { res = 'elyzea_meca', prefix = 'meca:' },
    { res = 'elyzea_famille', prefix = 'fam:' },
    { res = 'elyzea_animations', prefix = 'anim:' },  -- copier l'animation, proposer une animation (tout le monde)
    { res = 'elyzea_animaux', prefix = 'ani:', target = true },   -- animaux (les siens, ceux des autres, la ferme)
    { res = 'jewelry_heist', prefix = 'jewel:', target = true },
    { res = 'bank_heist', prefix = 'bank:', target = true },
    { res = 'elyzea_drogues', prefix = 'drg:', target = true },   -- postes, récolte, pots et plantes, acheteurs (objets et PNJ)
    { res = 'elyzea_bebe_modele', prefix = 'bebe:', target = true }, -- bébé (porter, poser, prises) et poussette (installer, pousser, garer)
}

-- Cible propre à une ressource (ex. bijoutier, sac de butin) : renvoie le fournisseur et le titre
local function ExtTarget(ent)
    for _, prov in ipairs(ALT_PROVIDERS) do
        if prov.target and GetResourceState(prov.res) == 'started' then
            local ok, title = pcall(function() return exports[prov.res]:AltTarget(ent) end)
            if ok and title then return prov.res, title end
        end
    end
end
-- Cible proche la plus proche, toutes ressources confondues (le bébé porté ou la poussette poussée gagnent : ils sont collés au joueur)
local function ExtNearby()
    local me = GetEntityCoords(PlayerPedId())
    local bRes, bEnt, bTitle, bD
    for _, prov in ipairs(ALT_PROVIDERS) do
        if prov.target and GetResourceState(prov.res) == 'started' then
            local ok, ent, title = pcall(function() return exports[prov.res]:AltNearby() end)
            if ok and ent and ent ~= 0 and DoesEntityExist(ent) then
                local d = #(GetEntityCoords(ent) - me)
                if not bD or d < bD then bRes, bEnt, bTitle, bD = prov.res, ent, title, d end
            end
        end
    end
    return bRes, bEnt, bTitle, bD
end

local function Context()
    if C.IsCarrying and C.IsCarrying() then return { kind = 'carry' } end
    if C.InTrunk and C.InTrunk() then return { kind = 'trunk' } end
    local me = PlayerPedId()
    local myPos = GetEntityCoords(me)
    local from, dir = CursorRay()
    local to = from + dir * 25.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 | 2 | 4 | 8, me, 7)
    local _, hit, _, _, ent = GetShapeTestResult(ray)
    local ctx = { kind = 'none' }
    if (hit == 1 or hit == true) and ent and ent ~= 0 and DoesEntityExist(ent) then
        local d = #(GetEntityCoords(ent) - myPos)
        if IsEntityAPed(ent) and IsPedAPlayer(ent) and d <= D.alt then
            ctx.kind, ctx.entity = 'player', ent
        elseif IsEntityAPed(ent) and not IsPedAPlayer(ent) and not IsPedInAnyVehicle(ent, false) and d <= D.alt and Entity(ent).state.drugThief then
            ctx.kind, ctx.entity = 'npc', ent      -- voleur de la vente de drogue (elyzea_illegal)
        elseif IsEntityAPed(ent) and not IsPedAPlayer(ent) and not IsPedInAnyVehicle(ent, false) and d <= D.alt + 1.5 then
            local prov, title = ExtTarget(ent)   -- un seul appel (avant : deux par image)
            if prov then ctx.kind, ctx.entity, ctx.provider, ctx.title = 'ext', ent, prov, title end
        elseif IsEntityAPed(ent) and IsPedInAnyVehicle(ent, false) and d <= D.vehicle then
            ctx.kind, ctx.entity = 'vehicle', GetVehiclePedIsIn(ent, false)
        elseif IsEntityAVehicle(ent) and d <= D.vehicle then
            ctx.kind, ctx.entity = 'vehicle', ent
        end
    end
    if ctx.kind == 'none' then
        -- Objets des ressources (postes, pots…) : second rayon qui touche aussi les objets,
        -- utilisé seulement si le premier n'a rien trouvé (comportement d'avant inchangé)
        local ray2 = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 16, me, 7)
        local _, hit2, _, _, ent2 = GetShapeTestResult(ray2)
        if (hit2 == 1 or hit2 == true) and ent2 and ent2 ~= 0 and DoesEntityExist(ent2) and not IsEntityAPed(ent2) and not IsEntityAVehicle(ent2)
            and #(GetEntityCoords(ent2) - myPos) <= D.alt + 1.5 then
            local res, title = ExtTarget(ent2)
            if res then ctx.kind, ctx.entity, ctx.provider, ctx.title = 'ext', ent2, res, title end
        end
    end
    if ctx.kind == 'none' then
        -- rien de visé : la plus proche entre la personne en face et une cible de ressource (bébé, poussette, sac…).
        -- Avant, la personne en face passait toujours en premier : un bébé à côté d'un joueur n'était jamais proposé.
        local f = FacingPlayer()
        local res, ent, title, dExt = ExtNearby()
        local dF = f and #(GetEntityCoords(f) - myPos) or nil
        if res and (not dF or dExt <= dF) then
            ctx.kind, ctx.entity, ctx.provider, ctx.title = 'ext', ent, res, title
        elseif f then
            ctx.kind, ctx.entity = 'player', f
        end
    end
    if ctx.kind == 'player' then
        if IsPedInAnyVehicle(ctx.entity, false) then
            ctx.sid = GetPlayerServerId(NetworkGetPlayerIndexFromPed(ctx.entity))
            ctx.inVehicle = true
        else
            ctx.sid = GetPlayerServerId(NetworkGetPlayerIndexFromPed(ctx.entity))
        end
    end
    return ctx
end

local function NameOf(sid) return ('Personne · ID %d'):format(sid) end

-- Actions possibles selon la cible, son état réel et les permissions
local function Options(ctx)
    local out = {}
    local police = C.OnDuty() and C.Can('alt')
    if not police then
        -- rien de la police
    elseif ctx.kind == 'player' and ctx.sid then
        local st = Player(ctx.sid).state
        local isCuffed = st.cuffed == true
        local me = GetPlayerServerId(PlayerId())
        if C.Can('cuff') then out[#out + 1] = { id = 'cuff', label = isCuffed and 'Démenotter' or 'Menotter', icon = 'cuff' } end
        if C.Can('escort') then
            out[#out + 1] = { id = 'escort', label = st.escortedBy == me and 'Arrêter l\'escorte' or 'Escorter', icon = 'escort',
                disabled = not isCuffed or ctx.inVehicle, desc = not isCuffed and 'La personne doit être menottée' or nil }
        end
        if C.Can('vehicle') then
            if ctx.inVehicle then
                out[#out + 1] = { id = 'takeOut', label = 'Sortir du véhicule', icon = 'out' }
            else
                local veh = C.ClosestVehicle(GetEntityCoords(PlayerPedId()), D.vehicle)
                out[#out + 1] = { id = 'putIn', label = 'Mettre dans le véhicule', icon = 'in', disabled = not isCuffed or not veh,
                    desc = not isCuffed and 'La personne doit être menottée' or (not veh and 'Aucun véhicule à proximité') or nil }
            end
        end
        if C.Can('fine') then out[#out + 1] = { id = 'fine', label = 'Mettre une amende', icon = 'fine', disabled = ctx.inVehicle } end
    elseif ctx.kind == 'vehicle' and C.Can('vehicle') then
        local veh = ctx.entity
        for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
            local ped = GetPedInVehicleSeat(veh, seat)
            if ped ~= 0 and IsPedAPlayer(ped) and ped ~= PlayerPedId() then
                local sid = GetPlayerServerId(NetworkGetPlayerIndexFromPed(ped))
                out[#out + 1] = { id = 'takeOut:' .. sid, label = ('Sortir %s'):format(NameOf(sid)), icon = 'out',
                    desc = Player(sid).state.cuffed and 'Menotté' or nil }
            end
        end
        -- Personne escortée : la mettre dans ce véhicule
        local me = GetPlayerServerId(PlayerId())
        for _, pid in ipairs(GetActivePlayers()) do
            local sid = GetPlayerServerId(pid)
            if Player(sid).state.escortedBy == me then
                out[#out + 1] = { id = 'putIn:' .. sid, label = ('Mettre %s dans ce véhicule'):format(NameOf(sid)), icon = 'in' }
            end
        end
    end
    if C.CitizenOptions and ctx.kind ~= 'ext' then C.CitizenOptions(ctx, out) end
    -- Actions des métiers (EMS, mécano) : options fournies par leur ressource, préfixées « ems: » / « meca: »
    for _, prov in ipairs(ALT_PROVIDERS) do
        if GetResourceState(prov.res) == 'started' and (((ctx.kind == 'player' or ctx.kind == 'vehicle') and not prov.target) or (ctx.kind == 'ext' and ctx.provider == prov.res)) then
            local ok, list = pcall(function()
                return exports[prov.res]:AltOptions({ kind = ctx.kind, sid = ctx.sid, inVehicle = ctx.inVehicle, entity = ctx.entity })
            end)
            if ok and type(list) == 'table' then
                for _, o in ipairs(list) do
                    if type(o) == 'table' and o.id then
                        out[#out + 1] = { id = prov.prefix .. tostring(o.id), label = o.label, icon = o.icon, desc = o.desc, disabled = o.disabled }
                    end
                end
            end
        end
    end
    return out
end

local function Title(ctx)
    if ctx.kind == 'player' then return NameOf(ctx.sid) end
    if ctx.kind == 'carry' then return 'Personne portée' end
    if ctx.kind == 'npc' then return 'Voleur' end
    if ctx.kind == 'trunk' then return 'Dans le coffre' end
    if ctx.kind == 'ext' then return ctx.title or 'Actions' end
    if ctx.kind == 'vehicle' then return ('Véhicule · %s'):format((GetVehicleNumberPlateText(ctx.entity) or ''):gsub('^%s+', ''):gsub('%s+$', '')) end
    return 'Actions'
end

-- ---------------------------------------------------------------------
-- Surbrillance de la cible survolée : seulement son CONTOUR, qui s'illumine (pas de boîte, pas de faces, pas de cercle).
-- La silhouette est calculée à l'écran : points du corps (os des personnages), profil de la carrosserie (véhicules)
-- ou volume de l'objet, puis enveloppe extérieure arrondie, dessinée en traits lumineux juste devant la cible.
-- Uniquement du dessin (DrawLine) : rien n'est modifié sur l'entité, aucun risque de plantage.
-- ---------------------------------------------------------------------
local KIND_COLOR = {
    player = { 96, 165, 250 }, carry = { 96, 165, 250 }, npc = { 239, 68, 68 },
    vehicle = { 245, 158, 11 }, ext = { 167, 139, 250 }, trunk = { 245, 158, 11 },
}
local boxCache = {}   -- [modèle] = { min, max } (GetModelDimensions n'est appelé qu'une fois par modèle)
local function dims(ent)
    local m = GetEntityModel(ent)
    local b = boxCache[m]
    if not b then
        local mn, mx = GetModelDimensions(m)
        b = { mn, mx }
        boxCache[m] = b
    end
    return b[1], b[2]
end

local function label3D(x, y, z, text, r, g, b)
    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(x, y, z)
    if not onScreen then return end
    SetTextFont(4) SetTextScale(0.0, 0.36) SetTextCentre(true) SetTextOutline()
    SetTextColour(255, 255, 255, 235)
    BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName(text) EndTextCommandDisplayText(sx, sy)
    local w = math.min(0.3, 0.0055 * #text + 0.012)
    DrawRect(sx, sy + 0.0135, w, 0.03, 8, 14, 26, 190)
    DrawRect(sx, sy + 0.0295, w, 0.0022, r, g, b, 230)
end

-- Os d'un personnage qui dessinent sa silhouette (tête, épaules, bras, mains, bassin, jambes, pieds)
local PED_BONES = { 31086, 39317, 64729, 10706, 45509, 40269, 61163, 28252, 18905, 57005, 24818, 11816, 58271, 51826, 63931, 36864, 14201, 52301, 20781, 2108 }

-- Points 3D (monde) qui forment le volume visible de l'entité, avec un rayon d'épaisseur (mètres) par point
local function silhouettePoints(ent)
    local pts = {}
    if IsEntityAPed(ent) then
        for _, b in ipairs(PED_BONES) do
            local c = GetPedBoneCoords(ent, b, 0.0, 0.0, 0.0)
            pts[#pts + 1] = { c, b == 31086 and 0.13 or 0.09 }
        end
        local h = GetPedBoneCoords(ent, 31086, 0.0, 0.0, 0.0)
        pts[#pts + 1] = { vector3(h.x, h.y, h.z + 0.1), 0.1 }      -- haut du crâne
        return pts
    end
    local mn, mx = dims(ent)
    local function at(x, y, z, r) pts[#pts + 1] = { GetOffsetFromEntityInWorldCoords(ent, x, y, z), r } end
    if IsEntityAVehicle(ent) then
        -- profil de carrosserie : bas de caisse sur toute la longueur, ceinture, toit sur la partie centrale
        local L, Wd = mx.y - mn.y, mx.x - mn.x
        local zb, zm, zt = mn.z + 0.12, mn.z + (mx.z - mn.z) * 0.55, mx.z
        local cy = (mn.y + mx.y) / 2
        for _, f in ipairs({ 0.0, 0.25, 0.5, 0.75, 1.0 }) do
            local y = mn.y + L * f
            for _, x in ipairs({ mn.x + Wd * 0.04, mx.x - Wd * 0.04 }) do
                at(x, y, zb, 0.06)
                at(x, y, zm, 0.06)
            end
        end
        for _, f in ipairs({ -0.28, -0.1, 0.1, 0.22 }) do
            local y = cy + L * f
            at(mn.x + Wd * 0.14, y, zt, 0.05) at(mx.x - Wd * 0.14, y, zt, 0.05)
        end
        return pts
    end
    -- objet : les huit coins de son volume (seule l'enveloppe extérieure est tracée)
    for _, x in ipairs({ mn.x, mx.x }) do for _, y in ipairs({ mn.y, mx.y }) do for _, z in ipairs({ mn.z, mx.z }) do at(x, y, z, 0.03) end end end
    return pts
end

-- Enveloppe convexe (chaîne monotone) de points 2D { x, y }
local function hull(P)
    table.sort(P, function(a, b) return a.x < b.x or (a.x == b.x and a.y < b.y) end)
    local function cross(o, a, b) return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x) end
    local lower, upper = {}, {}
    for _, p in ipairs(P) do
        while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], p) <= 0 do lower[#lower] = nil end
        lower[#lower + 1] = p
    end
    for i = #P, 1, -1 do
        local p = P[i]
        while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], p) <= 0 do upper[#upper] = nil end
        upper[#upper + 1] = p
    end
    lower[#lower] = nil upper[#upper] = nil
    for _, p in ipairs(upper) do lower[#lower + 1] = p end
    return lower
end

local RING = {}
for i = 0, 7 do RING[i + 1] = { math.cos(i * math.pi / 4), math.sin(i * math.pi / 4) } end

local function Highlight(ent, kind, text)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    local c = KIND_COLOR[kind] or KIND_COLOR.player
    local r, g, b = c[1], c[2], c[3]
    local pulse = 0.7 + 0.3 * math.abs(math.sin(GetGameTimer() / 280))
    local cam = GetGameplayCamCoord()
    local center = GetEntityCoords(ent)
    local dist = #(center - cam)
    if dist < 0.3 then return end
    local aspect = GetAspectRatio(false)
    local tanH = math.tan(math.rad(GetGameplayCamFov()) / 2)
    -- 1. silhouette à l'écran : chaque point devient un petit cercle (épaisseur du corps / de la carrosserie)
    local P2, minD = {}, dist
    for _, pt in ipairs(silhouettePoints(ent)) do
        local w = pt[1]
        local on, sx, sy = GetScreenCoordFromWorldCoord(w.x, w.y, w.z)
        if on then
            local d = math.max(0.5, #(w - cam))
            if d < minD then minD = d end
            local ry = pt[2] / (2 * d * tanH)          -- rayon en hauteur d'écran
            local rx = ry / aspect
            for _, k in ipairs(RING) do P2[#P2 + 1] = { x = sx + k[1] * rx, y = sy + k[2] * ry } end
        end
    end
    if #P2 < 3 then return end
    local H = hull(P2)
    if #H < 3 then return end
    -- 2. contour lumineux : trois traits concentriques (cœur net + halo), tracés juste devant la cible
    local cx, cy = 0, 0
    for _, p in ipairs(H) do cx, cy = cx + p.x, cy + p.y end
    cx, cy = cx / #H, cy / #H
    local depth = math.max(0.4, minD - 0.15)
    for layer, glow in ipairs({ { 0.0, 255 }, { 0.0022, 120 }, { 0.0045, 45 } }) do
        local grow, alpha = glow[1], math.floor(glow[2] * pulse)
        local W = {}
        for i, p in ipairs(H) do
            local dx, dy = (p.x - cx) * aspect, p.y - cy
            local l = math.sqrt(dx * dx + dy * dy)
            local ox, oy = 0, 0
            if l > 0 then ox, oy = (dx / l) * grow / aspect, (dy / l) * grow end
            local from, dir = CursorRay(p.x + ox, p.y + oy)
            W[i] = from + dir * depth
        end
        for i = 1, #W do
            local p, q = W[i], W[i % #W + 1]
            DrawLine(p.x, p.y, p.z, q.x, q.y, q.z, r, g, b, alpha)
        end
    end
    -- 3. petite étiquette au-dessus (nom de la cible et nombre d'actions)
    if text then
        local top = 1.0
        for _, p in ipairs(H) do if p.y < top then top = p.y end end
        local from, dir = CursorRay(cx, math.max(0.02, top - 0.035))
        local w = from + dir * depth
        label3D(w.x, w.y, w.z, text, r, g, b)
    end
end

local function CloseMenu()
    if not menuOpen then return end
    menuOpen, menuCtx, menuOpts = false, nil, nil
    C.Focus('alt', false)
    SendNUIMessage({ action = 'altMenu', show = false })
end
C.ui.alt = { close = CloseMenu }

local function Stop() active = false end

local function Start()
    if active or menuOpen or IsPauseMenuActive() or C.AnyOpen() then return end
    if (C.IsCuffed and C.IsCuffed()) or IsEntityDead(PlayerPedId()) or LocalPlayer.state.carriedBy or LocalPlayer.state.emsDown then return end
    active = true
    CreateThread(function()
        local ctx, opts, lastKey = nil, {}, nil
        while active do
            SetMouseCursorActiveThisFrame()
            DisableControlAction(0, 1, true) DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true) DisableControlAction(0, 141, true) DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true) DisableControlAction(0, 263, true)
            ctx = Context()
            local key = ctx.kind .. ':' .. tostring(ctx.entity or '')
            if key ~= lastKey then opts, lastKey = Options(ctx), key end
            -- plus de message en haut à gauche : la cible qui a des actions s'allume, ALT + clic gauche ouvre le menu
            if #opts > 0 and ctx.entity then
                Highlight(ctx.entity, ctx.kind, ('%s  ·  %d action%s'):format(Title(ctx), #opts, #opts > 1 and 's' or ''))
            end
            if IsDisabledControlJustPressed(0, 24) and #opts > 0 then
                menuCtx, menuOpts = ctx, Options(ctx)
                Stop()
                menuOpen = true
                C.Focus('alt', true)
                local ui = {}
                for i, o in ipairs(menuOpts) do ui[i] = { key = i, label = o.label, desc = o.desc, disabled = o.disabled, icon = o.icon } end
                SendNUIMessage({ action = 'altMenu', show = true, title = Title(ctx), kind = ctx.kind, options = ui, x = GetControlNormal(0, 239), y = GetControlNormal(0, 240) })
                return
            end
            Wait(0)
        end
        Stop()
    end)
end

RegisterNUICallback('altSelect', function(body, cb)
    cb({})
    local o = menuOpts and menuOpts[tonumber(body.key) or 0]
    local ctx = menuCtx
    CloseMenu()
    if not o or o.disabled or not ctx then return end
    for _, prov in ipairs(ALT_PROVIDERS) do
        if o.id:sub(1, #prov.prefix) == prov.prefix then
            local id = o.id:sub(#prov.prefix + 1)
            pcall(function()
                exports[prov.res]:AltSelect(id, { kind = ctx.kind, sid = ctx.sid, inVehicle = ctx.inVehicle, entity = ctx.entity })
            end)
            return
        end
    end
    local kind, sid = o.id:match('^(%a+):(%d+)$')
    CreateThread(function()
        if C.CitizenAct and C.CitizenAct(o.id, ctx) then return end
        if kind then C.Act(kind, tonumber(sid)) else C.Act(o.id, ctx.sid) end
    end)
end)
RegisterNUICallback('altClose', function(_, cb) cb({}) CloseMenu() end)

RegisterCommand('+police_alt', Start, false)
RegisterCommand('-police_alt', Stop, false)
RegisterKeyMapping('+police_alt', 'Interactions : porter, coffre, police (maintenir ALT, clic sur la cible)', 'keyboard', Config.Keys.alt)


-- Pour les tests hors du jeu (tests/alt_sim.lua)
C.AltContext, C.AltHighlight = Context, Highlight
