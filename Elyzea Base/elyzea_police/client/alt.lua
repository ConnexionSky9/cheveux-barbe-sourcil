-- =====================================================================
--  ELYZEA POLICE - client : menu ALT (pour tout le monde)
--  ALT maintenu : curseur ; la cible survolée qui a des actions est en surbrillance (boîte lumineuse dessinée,
--  pas le contour natif SetEntityDrawOutline qui faisait planter le jeu) ; ALT + clic gauche : actions possibles.
--  Tout le monde : porter, coffre (ouvrir, se cacher, sortir quelqu'un).
--  Agents en service avec la permission « alt » : menottes, escorte, véhicule, amende, fourrière.
--  EMS en service (elyzea_ems) : examen, soins, réanimation, ambulance, facture, PPA.
--  Mécano en service (elyzea_meca) : réparer, nettoyer, retourner, historique, devis (exports AltOptions / AltSelect).
--  Animations (elyzea_animations) : copier l'animation d'une personne, lui proposer une animation à deux.
--  Le menu reste ouvert après avoir lâché ALT ; Échap ou clic à côté pour le fermer.
-- =====================================================================
local C = PoliceC
local D = Config.Distances
local active, menuOpen = false, false
local menuCtx, menuOpts = nil, nil

local function CursorRay()
    local sx, sy = GetControlNormal(0, 239), GetControlNormal(0, 240)
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
local function ExtNearby()
    for _, prov in ipairs(ALT_PROVIDERS) do
        if prov.target and GetResourceState(prov.res) == 'started' then
            local ok, ent, title = pcall(function() return exports[prov.res]:AltNearby() end)
            if ok and ent then return prov.res, ent, title end
        end
    end
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
        elseif IsEntityAPed(ent) and not IsPedAPlayer(ent) and not IsPedInAnyVehicle(ent, false) and d <= D.alt + 1.5 and ExtTarget(ent) then
            ctx.kind, ctx.entity = 'ext', ent
            ctx.provider, ctx.title = ExtTarget(ent)
        elseif IsEntityAPed(ent) and IsPedInAnyVehicle(ent, false) and d <= D.vehicle then
            ctx.kind, ctx.entity = 'vehicle', GetVehiclePedIsIn(ent, false)
        elseif IsEntityAVehicle(ent) and d <= D.vehicle then
            ctx.kind, ctx.entity = 'vehicle', ent
        end
    end
    if ctx.kind == 'none' then
        local f = FacingPlayer()
        if f then ctx.kind, ctx.entity = 'player', f end
    end
    if ctx.kind == 'none' then
        -- rien de visé : cible proche d'une ressource (sac posé au sol, PNJ)
        local res, ent, title = ExtNearby()
        if res then ctx.kind, ctx.entity, ctx.provider, ctx.title = 'ext', ent, res, title end
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
-- Surbrillance de la cible survolée : boîte aux contours lumineux, faces légèrement teintées,
-- cercle au sol et étiquette. Uniquement du dessin (DrawLine / DrawPoly / DrawMarker / texte) :
-- rien n'est modifié sur l'entité, aucun risque de plantage.
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

local function Highlight(ent, kind, text)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    local c = KIND_COLOR[kind] or KIND_COLOR.player
    local r, g, b = c[1], c[2], c[3]
    local pulse = 0.65 + 0.35 * math.abs(math.sin(GetGameTimer() / 260))
    local mn, mx = dims(ent)
    local pad = IsEntityAPed(ent) and 0.06 or 0.04
    local x0, y0, z0, x1, y1, z1 = mn.x - pad, mn.y - pad, mn.z - pad, mx.x + pad, mx.y + pad, mx.z + pad
    if IsEntityAPed(ent) then x0, x1, y0, y1 = math.max(x0, -0.45), math.min(x1, 0.45), math.max(y0, -0.35), math.min(y1, 0.35) end
    local P = {}
    local k = 0
    for _, z in ipairs({ z0, z1 }) do
        for _, xy in ipairs({ { x0, y0 }, { x1, y0 }, { x1, y1 }, { x0, y1 } }) do
            k = k + 1
            P[k] = GetOffsetFromEntityInWorldCoords(ent, xy[1], xy[2], z)
        end
    end
    local a = math.floor(255 * pulse)
    local E = { { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 }, { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 5 }, { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 } }
    for _, e in ipairs(E) do
        local p, q = P[e[1]], P[e[2]]
        DrawLine(p.x, p.y, p.z, q.x, q.y, q.z, r, g, b, a)
    end
    -- faces teintées (des deux côtés pour être visibles sous tous les angles)
    local F = { { 1, 2, 6, 5 }, { 2, 3, 7, 6 }, { 3, 4, 8, 7 }, { 4, 1, 5, 8 }, { 5, 6, 7, 8 } }
    local fa = math.floor(34 * pulse)
    for _, f in ipairs(F) do
        local A, B, C, D = P[f[1]], P[f[2]], P[f[3]], P[f[4]]
        DrawPoly(A.x, A.y, A.z, B.x, B.y, B.z, C.x, C.y, C.z, r, g, b, fa)
        DrawPoly(A.x, A.y, A.z, C.x, C.y, C.z, D.x, D.y, D.z, r, g, b, fa)
        DrawPoly(C.x, C.y, C.z, B.x, B.y, B.z, A.x, A.y, A.z, r, g, b, fa)
        DrawPoly(D.x, D.y, D.z, C.x, C.y, C.z, A.x, A.y, A.z, r, g, b, fa)
    end
    -- cercle au sol
    local base = GetOffsetFromEntityInWorldCoords(ent, 0.0, 0.0, z0)
    local rad = math.max(x1 - x0, y1 - y0) * 0.75
    DrawMarker(25, base.x, base.y, base.z + 0.03, 0, 0, 0, 0, 0, 0, rad * 2, rad * 2, 1.0, r, g, b, math.floor(150 * pulse), false, false, 2, false, nil, nil, false)
    -- étiquette au-dessus
    if text then
        local top = GetOffsetFromEntityInWorldCoords(ent, 0.0, 0.0, z1 + 0.25)
        label3D(top.x, top.y, top.z, text, r, g, b)
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

