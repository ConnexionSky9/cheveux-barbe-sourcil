-- =====================================================================
--  ELYZEA POLICE - client : menu ALT (pour tout le monde)
--  ALT maintenu : curseur ; le CONTOUR exact de la cible survolée qui a des actions s'illumine (contour natif
--  pour véhicules et objets ; contour calculé membre par membre pour les personnes, car le contour natif fait
--  planter le jeu sur les personnages) ; ALT + clic gauche : actions possibles.
--  Tout le monde : porter, coffre (ouvrir, se cacher, sortir quelqu'un).
--  Agents en service avec la permission « alt » : menottes, escorte, véhicule, amende, fourrière.
--  EMS en service (elyzea_ems) : examen, soins, réanimation, ambulance, facture, PPA.
--  Mécano en service (elyzea_meca) : réparer, nettoyer, retourner, historique, devis (exports AltOptions / AltSelect).
--  Animations (elyzea_animations) : copier l'animation d'une personne, lui proposer une animation à deux.
--  Bébé (elyzea_bebe_modele) : prendre, poser, changer de prise, installer dans la poussette, pousser, garer.
--  Journaliste en service (elyzea_presse) : proposer une interview ou une annonce payante.
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
    { res = 'elyzea_ems', prefix = 'emsb:', target = true },   -- brancards (cible propre : l'objet brancard)
    { res = 'elyzea_meca', prefix = 'meca:' },
    { res = 'elyzea_famille', prefix = 'fam:' },
    { res = 'elyzea_animations', prefix = 'anim:' },  -- copier l'animation, proposer une animation (tout le monde)
    { res = 'elyzea_presse', prefix = 'presse:' },      -- journaliste en service : interview, annonce payante
    { res = 'elyzea_animaux', prefix = 'ani:', target = true },   -- animaux (les siens, ceux des autres, la ferme)
    { res = 'jewelry_heist', prefix = 'jewel:', target = true },
    { res = 'bank_heist', prefix = 'bank:', target = true },
    { res = 'elyzea_drogues', prefix = 'drg:', target = true },   -- postes, récolte, pots et plantes, acheteurs (objets et PNJ)
    { res = 'elyzea_bebe_modele', prefix = 'bebe:', target = true }, -- bébé (porter, poser, prises) et poussette (installer, pousser, garer)
    { res = 'elyzea_tv', prefix = 'tv:', target = true },          -- télés à écran plat : télécommande YouTube, pause, volume, éteindre
    { res = 'elyzea_clothing', prefix = 'clo:', target = true },   -- chapeau / lunettes tombés au sol : ramasser, casser les lunettes
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
        if GetResourceState(prov.res) == 'started' and (((ctx.kind == 'player' or ctx.kind == 'vehicle') and not prov.target) or (ctx.kind == 'ext' and prov.target and ctx.provider == prov.res)) then
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
-- Surbrillance de la cible survolée : son CONTOUR exact s'illumine (pas de boîte, pas de faces, pas de cercle).
--   · véhicules et objets : contour natif du jeu (SetEntityDrawOutline), pile sur la forme réelle ;
--   · personnes et animaux : JAMAIS le contour natif (il fait planter le jeu sur les personnages :
--     https://github.com/citizenfx/fivem/issues/1425) ; leur contour est calculé membre par membre
--     (tête, buste, bras, mains, jambes, pieds) et tracé en traits lumineux autour du corps.
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

-- Contour natif : une seule entité à la fois, jamais un personnage, toujours retiré proprement
local outlined = nil
local function Outline(ent, c)
    if ent and (ent == 0 or not DoesEntityExist(ent) or IsEntityAPed(ent)) then ent = nil end
    if outlined ~= ent then
        if outlined and DoesEntityExist(outlined) then SetEntityDrawOutline(outlined, false) end
        outlined = ent
    end
    if ent then
        SetEntityDrawOutlineColor(c[1], c[2], c[3], 255)
        SetEntityDrawOutline(ent, true)
    end
end
C.ClearOutline = function() Outline(nil) end

-- Corps d'une personne : capsules entre os (os A, os B, rayon en mètres)
local BODY = {
    { 31086, 31086, 0.115, 0.07 },            -- tête (centrée un peu au-dessus de l'os)
    { 39317, 24818, 0.075 },                  -- cou → haut du buste
    { 24818, 11816, 0.155 },                  -- buste
    { 64729, 10706, 0.08 },                   -- épaules
    { 64729, 45509, 0.07 }, { 10706, 40269, 0.07 },
    { 45509, 61163, 0.062 }, { 40269, 28252, 0.062 },   -- bras
    { 61163, 18905, 0.05 }, { 28252, 57005, 0.05 },     -- avant-bras
    { 18905, 18905, 0.06 }, { 57005, 57005, 0.06 },     -- mains
    { 11816, 58271, 0.13 }, { 11816, 51826, 0.13 },     -- bassin
    { 58271, 63931, 0.09 }, { 51826, 36864, 0.09 },     -- cuisses
    { 63931, 14201, 0.066 }, { 36864, 52301, 0.066 },   -- mollets
    { 14201, 20781, 0.055 }, { 52301, 35502, 0.055 },   -- pieds
}

-- distance d'un point au segment [a, b] (coordonnées écran corrigées de l'aspect)
local function segDist(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local l = dx * dx + dy * dy
    local t = l > 0 and ((px - ax) * dx + (py - ay) * dy) / l or 0
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local qx, qy = ax + t * dx - px, ay + t * dy - py
    return math.sqrt(qx * qx + qy * qy)
end

-- Contour d'un corps fait de capsules (monde : point A, point B, rayon en mètres) :
-- champ de distance sur une grille à l'écran puis « marching squares » (lignes de niveau interpolées).
-- La ligne suit la silhouette : bras et jambes séparés, tête, mains, pieds.
local function capsuleContour(world, r, g, b, pulse)
    local cam = GetGameplayCamCoord()
    local aspect = GetAspectRatio(false)
    local tanH = math.tan(math.rad(GetGameplayCamFov()) / 2)
    local caps, minD, maxR = {}, 1e9, 0
    local x0, y0, x1, y1 = 1e9, 1e9, -1e9, -1e9
    local function proj(w)
        local on, sx, sy = GetScreenCoordFromWorldCoord(w.x, w.y, w.z)
        local d = #(w - cam)
        if d < minD then minD = d end
        return on and { sx * aspect, sy, d } or nil
    end
    for _, c in ipairs(world) do
        local A, B = proj(c[1]), proj(c[2])
        if A and B then
            local rs = c[3] / (2 * ((A[3] + B[3]) / 2) * tanH)
            caps[#caps + 1] = { A[1], A[2], B[1], B[2], rs }
            if rs > maxR then maxR = rs end
            x0, y0 = math.min(x0, A[1], B[1]), math.min(y0, A[2], B[2])
            x1, y1 = math.max(x1, A[1], B[1]), math.max(y1, A[2], B[2])
        end
    end
    if #caps == 0 or minD < 0.4 then return nil end
    local glow = 0.0028                                   -- épaisseur du halo (hauteur d'écran)
    local m = maxR + glow * 2 + 0.004
    x0, y0, x1, y1 = x0 - m, y0 - m, x1 + m, y1 + m
    local rows = 56
    local h = (y1 - y0) / rows
    local cols = math.max(8, math.min(56, math.ceil((x1 - x0) / h)))
    local wcell = (x1 - x0) / cols
    local F = {}
    for j = 0, rows do
        local py = y0 + j * h
        local row = {}
        for i = 0, cols do
            local px = x0 + i * wcell
            local best = 1e9
            for k = 1, #caps do
                local c = caps[k]
                local d = segDist(px, py, c[1], c[2], c[3], c[4]) - c[5]
                if d < best then best = d end
            end
            row[i] = best
        end
        F[j] = row
    end
    local depth = math.max(0.4, minD - 0.12)
    local lines = 0
    local function toWorld(x, y)
        local from, dir = CursorRay(x / aspect, y)
        return from + dir * depth
    end
    local function iso(level, alpha)
        local function lerp(va, vb) return (level - va) / (vb - va) end
        for j = 0, rows - 1 do
            local ya, yb = y0 + j * h, y0 + (j + 1) * h
            local r0, r1 = F[j], F[j + 1]
            for i = 0, cols - 1 do
                local a, bb, c, d = r0[i], r0[i + 1], r1[i + 1], r1[i]   -- haut-gauche, haut-droit, bas-droit, bas-gauche
                local idx = (a < level and 1 or 0) + (bb < level and 2 or 0) + (c < level and 4 or 0) + (d < level and 8 or 0)
                if idx ~= 0 and idx ~= 15 then
                    local xa, xb = x0 + i * wcell, x0 + (i + 1) * wcell
                    local P = {}
                    if (a < level) ~= (bb < level) then P[#P + 1] = { xa + lerp(a, bb) * wcell, ya } end
                    if (bb < level) ~= (c < level) then P[#P + 1] = { xb, ya + lerp(bb, c) * h } end
                    if (d < level) ~= (c < level) then P[#P + 1] = { xa + lerp(d, c) * wcell, yb } end
                    if (a < level) ~= (d < level) then P[#P + 1] = { xa, ya + lerp(a, d) * h } end
                    for k = 1, #P - 1, 2 do
                        local p, q = toWorld(P[k][1], P[k][2]), toWorld(P[k + 1][1], P[k + 1][2])
                        DrawLine(p.x, p.y, p.z, q.x, q.y, q.z, r, g, b, alpha)
                        lines = lines + 1
                    end
                end
            end
        end
    end
    iso(0.0, math.floor(255 * pulse))
    iso(glow, math.floor(90 * pulse))
    return { top = y0 + m, cx = (x0 + x1) / 2, depth = depth, aspect = aspect, lines = lines }
end

local function pedContour(ent, r, g, b, pulse)
    local world = {}
    if IsPedHuman(ent) then
        for _, c in ipairs(BODY) do
            local A = GetPedBoneCoords(ent, c[1], 0.0, 0.0, 0.0)
            local B = c[2] == c[1] and A or GetPedBoneCoords(ent, c[2], 0.0, 0.0, 0.0)
            if c[4] then A, B = vector3(A.x, A.y, A.z + c[4]), vector3(B.x, B.y, B.z + c[4]) end
            world[#world + 1] = { A, B, c[3] }
        end
    else
        -- animal : pas d'os humains ; corps = capsule le long du modèle (avant → arrière-train)
        local mn, mx = dims(ent)
        local rr = math.min(mx.x - mn.x, mx.z - mn.z) * 0.45
        local cz = (mn.z + mx.z) / 2
        world[1] = { GetOffsetFromEntityInWorldCoords(ent, 0.0, mx.y - rr, cz), GetOffsetFromEntityInWorldCoords(ent, 0.0, mn.y + rr, cz), rr }
    end
    return capsuleContour(world, r, g, b, pulse)
end

local function Highlight(ent, kind, text)
    if not ent or ent == 0 or not DoesEntityExist(ent) then Outline(nil) return end
    local c = KIND_COLOR[kind] or KIND_COLOR.player
    local r, g, b = c[1], c[2], c[3]
    local labelPos
    if IsEntityAPed(ent) then
        Outline(nil)
        local pulse = 0.75 + 0.25 * math.abs(math.sin(GetGameTimer() / 280))
        local res = pedContour(ent, r, g, b, pulse)
        if res and text then
            local from, dir = CursorRay(res.cx / res.aspect, math.max(0.02, res.top - 0.03))
            labelPos = from + dir * res.depth
        end
    else
        Outline(ent, c)
        if text then
            local _, mx = dims(ent)
            labelPos = GetOffsetFromEntityInWorldCoords(ent, 0.0, 0.0, mx.z + 0.25)
        end
    end
    if labelPos then label3D(labelPos.x, labelPos.y, labelPos.z, text, r, g, b) end
end

local function CloseMenu()
    if not menuOpen then return end
    menuOpen, menuCtx, menuOpts = false, nil, nil
    Outline(nil)
    C.Focus('alt', false)
    SendNUIMessage({ action = 'altMenu', show = false })
end
C.ui.alt = { close = CloseMenu }

local function Stop() active = false end

-- Ouvre directement le menu ALT sur l'objet d'une ressource (ex. four à gâteaux avec E : elyzea_drogues)
exports('OpenFor', function(ent)
    if active or menuOpen or IsPauseMenuActive() or C.AnyOpen() then return false end
    if not ent or ent == 0 or not DoesEntityExist(ent) then return false end
    if (C.IsCuffed and C.IsCuffed()) or IsEntityDead(PlayerPedId()) or LocalPlayer.state.carriedBy or LocalPlayer.state.emsDown then return false end
    local res, title = ExtTarget(ent)
    if not res then return false end
    local ctx = { kind = 'ext', entity = ent, provider = res, title = title }
    local opts = Options(ctx)
    if #opts == 0 then return false end
    menuCtx, menuOpts = ctx, opts
    menuOpen = true
    C.Focus('alt', true)
    local ui = {}
    for i, o in ipairs(opts) do ui[i] = { key = i, label = o.label, desc = o.desc, disabled = o.disabled, icon = o.icon } end
    SendNUIMessage({ action = 'altMenu', show = true, title = Title(ctx), kind = ctx.kind, options = ui, x = 0.55, y = 0.45 })
    return true
end)

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
            else
                Outline(nil)
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
        Outline(nil)
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


AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then Outline(nil) end end)

-- Pour les tests hors du jeu (tests/alt_sim.lua)
C.AltContext, C.AltHighlight = Context, Highlight
