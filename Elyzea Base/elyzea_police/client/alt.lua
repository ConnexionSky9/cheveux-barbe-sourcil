-- =====================================================================
--  ELYZEA POLICE - client : menu ALT (pour tout le monde)
--  ALT maintenu : curseur ; la cible survolée qui a des actions s'allume aux couleurs Elyzea (violet néon) :
--  contour natif pour les véhicules et objets, cadre de visée lumineux pour les personnes et les animaux
--  (le contour natif fait planter le jeu sur les personnages) ; ALT + clic gauche : actions possibles.
--  Survol : UNIQUEMENT la surbrillance (aucun texte, aucune étiquette, aucune infobulle). Elle disparaît
--  dès qu'on quitte la cible, qu'on relâche ALT ou que le menu d'actions s'ouvre.
--  Optimisé : la cible est recherchée ~11 fois par seconde (rayons + ressources), pas à chaque image ;
--  les réponses des ressources sont mises en cache ; le dessin par image ne coûte que quelques appels.
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
    { res = 'elyzea_clothing', prefix = 'sac:' },                  -- sacs de shopping : ranger / reprendre dans le coffre, offrir à quelqu'un
}

-- Cible propre à une ressource (ex. bijoutier, sac de butin) : renvoie le fournisseur et le titre
-- Réponse mise en cache 800 ms par entité : survoler la même cible ne rappelle pas les ressources
local extCache = {}
local nearbyCache = { t = -1e9 }
local function ExtTarget(ent)
    local now = GetGameTimer()
    local c = extCache[ent]
    if c and now - c.t < 800 then return c.res, c.title end
    local fres, ftitle
    for _, prov in ipairs(ALT_PROVIDERS) do
        if prov.target and GetResourceState(prov.res) == 'started' then
            local ok, title = pcall(function() return exports[prov.res]:AltTarget(ent) end)
            if ok and title then fres, ftitle = prov.res, title break end
        end
    end
    extCache[ent] = { t = now, res = fres, title = ftitle }
    return fres, ftitle
end
local function ClearExtCache() extCache = {} nearbyCache = { t = -1e9 } end
-- Cible proche la plus proche, toutes ressources confondues (le bébé porté ou la poussette poussée gagnent : ils sont collés au joueur)
local function ExtNearby()
    local now = GetGameTimer()
    if now - nearbyCache.t < 300 then return nearbyCache[1], nearbyCache[2], nearbyCache[3], nearbyCache[4] end
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
    nearbyCache = { bRes, bEnt, bTitle, bD, t = now }   -- 300 ms : les ressources ne sont pas rappelées à chaque recherche
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
-- Surbrillance de la cible survolée, aux couleurs du logo Elyzea FA (violet néon) :
--   · véhicules et objets : contour natif du jeu (SetEntityDrawOutline), pile sur la forme réelle ;
--   · personnes et animaux : JAMAIS le contour natif (plantage du jeu sur les personnages :
--     https://github.com/citizenfx/fivem/issues/1425) ; un cadre de visée lumineux (4 coins) les entoure,
--     calculé avec 7 os (tête, mains, bassin, pieds) : quelques appels par image, aucun calcul lourd.
--   · aucun texte : la surbrillance seule indique que la cible est sélectionnable.
-- ---------------------------------------------------------------------
local KIND_COLOR = {   -- teinte d'accent par type (le violet Elyzea reste la couleur principale)
    player = { 155, 92, 255 }, carry = { 155, 92, 255 }, npc = { 255, 77, 109 },
    vehicle = { 181, 123, 255 }, ext = { 201, 166, 255 }, trunk = { 181, 123, 255 },
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

-- Points qui délimitent un personnage (tête, mains, bassin, pieds) ; un animal : coins de son modèle
local PED_BONES = { 31086, 18905, 57005, 11816, 14201, 52301, 24818 }
local function screenBox(ent)
    local x0, y0, x1, y1, n = 1, 1, 0, 0, 0
    local function add(w)
        local on, sx, sy = GetScreenCoordFromWorldCoord(w.x, w.y, w.z)
        if on then
            n = n + 1
            if sx < x0 then x0 = sx end if sx > x1 then x1 = sx end
            if sy < y0 then y0 = sy end if sy > y1 then y1 = sy end
        end
    end
    if IsPedHuman(ent) then
        for i = 1, #PED_BONES do add(GetPedBoneCoords(ent, PED_BONES[i], 0.0, 0.0, 0.0)) end
        local head = GetPedBoneCoords(ent, 31086, 0.0, 0.0, 0.0)
        add(vector3(head.x, head.y, head.z + 0.2))                       -- haut du crâne
    else
        local mn, mx = dims(ent)
        for _, c in ipairs({ { mn.x, mn.y, mn.z }, { mx.x, mx.y, mx.z }, { mn.x, mx.y, mx.z }, { mx.x, mn.y, mn.z } }) do
            add(GetOffsetFromEntityInWorldCoords(ent, c[1], c[2], c[3]))
        end
    end
    if n < 2 then return nil end
    return x0, y0, x1, y1
end

-- Cadre de visée : 4 coins lumineux qui « respirent », léger voile violet à l'intérieur
local function reticle(x0, y0, x1, y1, r, g, b, pulse)
    local aspect = GetAspectRatio(false)
    local pad = 0.012
    x0, x1, y0, y1 = x0 - pad / aspect, x1 + pad / aspect, y0 - pad, y1 + pad
    local w, h = x1 - x0, y1 - y0
    if w <= 0 or h <= 0 or w > 0.9 or h > 0.95 then return end
    local t = 0.0026                                 -- épaisseur (hauteur d'écran)
    local tx = t / aspect
    local lx, ly = math.min(w * 0.3, 0.035 / aspect), math.min(h * 0.22, 0.035)
    local a = math.floor(255 * pulse)
    DrawRect((x0 + x1) / 2, (y0 + y1) / 2, w, h, r, g, b, 14)    -- voile
    -- coins (horizontal + vertical)
    DrawRect(x0 + lx / 2, y0, lx, t, r, g, b, a) DrawRect(x0, y0 + ly / 2, tx, ly, r, g, b, a)
    DrawRect(x1 - lx / 2, y0, lx, t, r, g, b, a) DrawRect(x1, y0 + ly / 2, tx, ly, r, g, b, a)
    DrawRect(x0 + lx / 2, y1, lx, t, r, g, b, a) DrawRect(x0, y1 - ly / 2, tx, ly, r, g, b, a)
    DrawRect(x1 - lx / 2, y1, lx, t, r, g, b, a) DrawRect(x1, y1 - ly / 2, tx, ly, r, g, b, a)
    -- halo des coins
    local ha = math.floor(70 * pulse)
    DrawRect(x0 + lx / 2, y0, lx, t * 3, r, g, b, ha) DrawRect(x1 - lx / 2, y1, lx, t * 3, r, g, b, ha)
    DrawRect(x1 - lx / 2, y0, lx, t * 3, r, g, b, ha) DrawRect(x0 + lx / 2, y1, lx, t * 3, r, g, b, ha)
    return (x0 + x1) / 2, y0
end

local function Highlight(ent, kind)
    if not ent or ent == 0 or not DoesEntityExist(ent) then Outline(nil) return end
    local c = KIND_COLOR[kind] or KIND_COLOR.player
    if IsEntityAPed(ent) then
        Outline(nil)
        local x0, y0, x1, y1 = screenBox(ent)
        if x0 then reticle(x0, y0, x1, y1, c[1], c[2], c[3], 0.72 + 0.28 * math.abs(math.sin(GetGameTimer() / 320))) end
    else
        Outline(ent, c)
    end
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


-- Touche ALT réellement tenue ? (le jeu peut perdre le relâchement, par exemple après Alt+Tab)
local ALT_CONTROL = 19   -- INPUT_CHARACTER_WHEEL = ALT gauche par défaut
local function AltHeld() return IsControlPressed(0, ALT_CONTROL) or IsDisabledControlPressed(0, ALT_CONTROL) end

local SCAN_MS = 90          -- recherche de la cible (rayons, ressources) ~11 fois par seconde
local OPTIONS_MS = 1000     -- actions de la cible relues chaque seconde (menottes posées entre-temps…)

local function OpenMenu(ctx, x, y)
    menuCtx, menuOpts = ctx, Options(ctx)
    if #menuOpts == 0 then menuCtx, menuOpts = nil, nil return false end
    menuOpen = true
    C.Focus('alt', true)
    local ui = {}
    for i, o in ipairs(menuOpts) do ui[i] = { key = i, label = o.label, desc = o.desc, disabled = o.disabled, icon = o.icon } end
    SendNUIMessage({ action = 'altMenu', show = true, title = Title(ctx), kind = ctx.kind, options = ui, x = x, y = y })
    return true
end

-- Ouvre directement le menu ALT sur l'objet d'une ressource (ex. four à gâteaux avec E : elyzea_drogues)
exports('OpenFor', function(ent)
    if active or menuOpen or IsPauseMenuActive() or C.AnyOpen() then return false end
    if not ent or ent == 0 or not DoesEntityExist(ent) then return false end
    if (C.IsCuffed and C.IsCuffed()) or IsEntityDead(PlayerPedId()) or LocalPlayer.state.carriedBy or LocalPlayer.state.emsDown then return false end
    local res, title = ExtTarget(ent)
    if not res then return false end
    return OpenMenu({ kind = 'ext', entity = ent, provider = res, title = title }, 0.55, 0.45)
end)

local function Start()
    if active or menuOpen or IsPauseMenuActive() or C.AnyOpen() then return end
    if (C.IsCuffed and C.IsCuffed()) or IsEntityDead(PlayerPedId()) or LocalPlayer.state.carriedBy or LocalPlayer.state.emsDown then return end
    active = true
    ClearExtCache()
    CreateThread(function()
        local ctx, opts, lastKey = { kind = 'none' }, {}, nil
        local nextScan, nextOpts, released = 0, 0, 0
        -- si le joueur a gardé ALT, on surveille la touche elle-même ; s'il l'a changée, on se fie à la commande
        local seenAlt, frames = false, 0
        while active do
            SetMouseCursorActiveThisFrame()
            DisableControlAction(0, 1, true) DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true) DisableControlAction(0, 141, true) DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true) DisableControlAction(0, 263, true)
            -- sécurités : relâchement perdu (Alt+Tab), menu pause, joueur à terre / menotté
            frames = frames + 1
            if AltHeld() then seenAlt, released = true, 0
            elseif seenAlt then released = released + 1 end
            if seenAlt and released > 3 then break end
            if IsPauseMenuActive() or IsEntityDead(PlayerPedId()) or (C.IsCuffed and C.IsCuffed()) then break end
            local now = GetGameTimer()
            if now >= nextScan then
                nextScan = now + SCAN_MS
                ctx = Context()
                local key = ctx.kind .. ':' .. tostring(ctx.entity or '')
                if key ~= lastKey or now >= nextOpts then
                    opts, lastKey, nextOpts = Options(ctx), key, now + OPTIONS_MS
                end
            end
            if #opts > 0 and ctx.entity and DoesEntityExist(ctx.entity) then
                Highlight(ctx.entity, ctx.kind)
            else
                Outline(nil)
            end
            if IsDisabledControlJustPressed(0, 24) then
                -- le clic vise ce qui est sous le curseur à cet instant
                ctx = Context()
                if OpenMenu(ctx, GetControlNormal(0, 239), GetControlNormal(0, 240)) then
                    Outline(nil)
                    active = false
                    return
                end
            end
            Wait(0)
        end
        active = false
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
