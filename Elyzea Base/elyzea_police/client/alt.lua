-- =====================================================================
--  ELYZEA POLICE - client : menu ALT (pour tout le monde)
--  ALT maintenu : curseur ; clic sur la cible : actions possibles (pas de surbrillance : elle faisait planter le jeu).
--  Tout le monde : porter, coffre (ouvrir, se cacher, sortir quelqu'un).
--  Agents en service avec la permission « alt » : menottes, escorte, véhicule, amende, fourrière.
--  EMS en service (elyzea_ems) : examen, soins, réanimation, ambulance, facture, PPA.
--  Mécano en service (elyzea_meca) : réparer, nettoyer, retourner, historique, devis (exports AltOptions / AltSelect).
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

local function Help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
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
            if #opts > 0 then Help(('~INPUT_ATTACK~ %d action(s) : %s'):format(#opts, Title(ctx)))
            else Help('Visez une personne ou un véhicule') end
            if IsDisabledControlJustPressed(0, 24) and #opts > 0 then
                menuCtx, menuOpts = ctx, Options(ctx)
                Stop()
                menuOpen = true
                C.Focus('alt', true)
                local ui = {}
                for i, o in ipairs(menuOpts) do ui[i] = { key = i, label = o.label, desc = o.desc, disabled = o.disabled, icon = o.icon } end
                SendNUIMessage({ action = 'altMenu', show = true, title = Title(ctx), options = ui, x = GetControlNormal(0, 239), y = GetControlNormal(0, 240) })
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

