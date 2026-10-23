-- =====================================================================
--  ELYZEA BÉBÉ - client : poussette qui roule (physique simulée) et roues qui tournent (V6)
--  · Simulation : le serveur la confie à UN joueur proche (« simuler »). Ce client prend le contrôle de l'objet,
--    attache le bébé à la poussette, calcule le mouvement (shared/physique.lua) avec le vrai sol et les vrais
--    obstacles de GTA, déplace l'objet (tout le monde le voit), puis renvoie la position d'arrêt au serveur.
--  · Roues : chaque joueur crée LOCALEMENT 4 roues accrochées à chaque poussette proche et les fait tourner
--    selon le déplacement (rien de plus à synchroniser).
-- =====================================================================
local PO = Config.Poussette
local B = BebeClient
local simulations = {}       -- [pid] = 'en_cours' | 'fin' (frein serré : renvoyer la position) | 'abandon' (rattrapée)

-- Sol sous un point : le plus haut sol / toit / trottoir sous (x, y), en partant un peu au-dessus de zRef
local function sol(x, y, zRef)
    local ok, z = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, zRef + 1.2, false)
    if ok and z > zRef - 4.0 then return z end
    return nil
end

local function obstacleFn(ent)
    return function(x, y, z, dx, dy, dist)
        for _, off in ipairs({ -0.22, 0.22 }) do
            local ox, oy = x + dy * off, y - dx * off
            -- murs et décor (1), véhicules (2), personnages (8), objets (16)
            local h = StartExpensiveSynchronousShapeTestLosProbe(ox, oy, z + 0.30, ox + dx * dist, oy + dy * dist, z + 0.30, 1 + 2 + 8 + 16, ent, 7)
            local _, touche = GetShapeTestResult(h)
            if touche == 1 or touche == true then return true end
        end
        return false
    end
end

RegisterNetEvent('elyzea_bebe_modele:poussette:stopsim', function(pid, renvoyer)
    if simulations[pid] then simulations[pid] = renvoyer and 'fin' or 'abandon' end
end)

RegisterNetEvent('elyzea_bebe_modele:poussette:simuler', function(pid, net, nets, st0, params)
    if simulations[pid] or type(st0) ~= 'table' then return end
    simulations[pid] = 'en_cours'
    local st = { x = st0.x + 0.0, y = st0.y + 0.0, z = st0.z + 0.0, cap = (st0.cap or 0.0) + 0.0, v = 0.0, frein = false }
    local function fin(renversee)
        if simulations[pid] ~= 'abandon' then
            TriggerServerEvent('elyzea_bebe_modele:poussette:fin', pid, vector3(st.x, st.y, st.z), st.cap, renversee == true)
        end
        simulations[pid] = nil
    end
    local e = net and B.entite(net)
    if not e or not B.controle(e) then return fin(false) end
    -- V8 : collision COUPÉE pendant le roulement. En V7 elle restait active : la mesure du sol sous les roues
    -- (GetGroundZFor_3dCoord) pouvait rencontrer la collision de la poussette elle-même, qui « montait » alors sur
    -- elle-même à chaque image et s'envolait (puis restait en l'air une fois le frein serré). Elle s'arrête quand même
    -- devant les joueurs, véhicules et objets (détection d'obstacle). Garée, elle redevient solide (objet recréé).
    SetEntityCollision(e, false, false)
    FreezeEntityPosition(e, true)
    local bebeAttache = type(nets) ~= 'table' or B.attacherPieces(nets, PO.nacelle.pos, PO.nacelle.rot, e)
    local prochainEssai = GetGameTimer() + 500
    local P = {}
    for k, v in pairs(Physique.defaut) do P[k] = v end
    for k, v in pairs(type(params) == 'table' and params or {}) do if P[k] ~= nil and type(v) == type(P[k]) then P[k] = v end end
    local obstacle = obstacleFn(e)
    local debut, immobile, renversee = GetGameTimer(), 0.0, false
    while simulations[pid] == 'en_cours' do
        if not DoesEntityExist(e) then break end
        if not NetworkHasControlOfEntity(e) then NetworkRequestControlOfEntity(e) end
        -- bébé pas encore attaché (contrôle de l'objet pas obtenu) : nouvel essai, sinon il resterait sur place
        if not bebeAttache and GetGameTimer() > prochainEssai then
            prochainEssai = GetGameTimer() + 500
            CreateThread(function() bebeAttache = B.attacherPieces(nets, PO.nacelle.pos, PO.nacelle.rot, e) or bebeAttache end)
        end
        local dt = math.min(0.05, math.max(0.001, GetFrameTime()))
        local ev
        st, ev = Physique.pas(st, dt, P, sol, obstacle)
        if ev == 'hors_sol' then break end
        SetEntityCoordsNoOffset(e, st.x, st.y, st.z, false, false, false)
        SetEntityRotation(e, st.tangage or 0.0, st.roulis or 0.0, st.cap, 2, true)
        if ev == 'renversee' then renversee = true break end
        if ev == 'arret' then immobile = immobile + dt else immobile = 0.0 end
        if immobile >= 0.6 or GetGameTimer() - debut > 85000 then break end
        Wait(0)
    end
    fin(renversee)
end)

-- ─────────── Poussettes garées : figées pour tous (V8) ───────────
-- Le serveur crée une poussette garée figée, mais ce réglage n'est pas garanti chez tous les joueurs (propriétaire de
-- l'objet qui change) ; depuis la V7 elle a une vraie collision : non figée, un choc pouvait la projeter. Chaque joueur
-- fige donc localement toute poussette garée ou renversée proche (jamais celle qui est poussée ou qui roule).
CreateThread(function()
    while true do
        local pc = GetEntityCoords(PlayerPedId())
        for _, obj in ipairs(GetGamePool('CObject')) do
            local st = Entity(obj).state
            if st.bebePoussette and (st.bebeEtat == 'garee' or st.bebeEtat == 'renversee') and not IsEntityAttached(obj)
                and #(GetEntityCoords(obj) - pc) < 80.0 then
                FreezeEntityPosition(obj, true)
            end
        end
        Wait(500)
    end
end)

-- ─────────── Roues locales ───────────

local GEO = BebeModeles.equipements and BebeModeles.equipements.geo and BebeModeles.equipements.geo.poussette
local ROUES = GEO and GEO.roues
local roues = {}             -- [objet poussette] = { objs = { {ent, x, y, z, r} … }, last, angle }

local function modeleRoue(cote, coloris)
    local M = BebeModeles.equipements and BebeModeles.equipements['roue_' .. cote] or {}
    return M[coloris] or M[PO.coloris] or select(2, next(M))
end

local function supprimerRoues(r)
    for _, w in ipairs(r.objs) do if DoesEntityExist(w.ent) then DeleteObject(w.ent) end end
end

local function creerRoues(obj, coloris)
    local r = { objs = {}, last = GetEntityCoords(obj), angle = 0.0 }
    for cote, def in pairs(ROUES) do
        local nom = modeleRoue(cote, coloris)
        local h = nom and joaat(nom)
        if not h then return nil end
        RequestModel(h)
        local t = GetGameTimer() + 3000
        while not HasModelLoaded(h) and GetGameTimer() < t do Wait(0) end
        if not HasModelLoaded(h) then return nil end
        for _, sx in ipairs({ 1.0, -1.0 }) do
            local c = GetEntityCoords(obj)
            local w = CreateObjectNoOffset(h, c.x, c.y, c.z, false, false, false)     -- local : jamais envoyé aux autres
            SetEntityCollision(w, false, false)
            local wr = { ent = w, x = sx * def[1], y = def[2], z = def[3], r = def[4] }
            AttachEntityToEntity(w, obj, 0, wr.x, wr.y, wr.z, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
            r.objs[#r.objs + 1] = wr
        end
        SetModelAsNoLongerNeeded(h)
    end
    return r
end

local function tournerRoues(obj, r)
    local c = GetEntityCoords(obj)
    local f = GetEntityForwardVector(obj)
    local d = (c.x - r.last.x) * f.x + (c.y - r.last.y) * f.y + (c.z - r.last.z) * f.z
    r.last = c
    if math.abs(d) < 0.0005 or math.abs(d) > 2.0 then return end          -- immobile, ou téléportée
    for _, w in ipairs(r.objs) do
        w.angle = ((w.angle or 0.0) - math.deg(d / w.r)) % 360.0
        AttachEntityToEntity(w.ent, obj, 0, w.x, w.y, w.z, w.angle, 0.0, 0.0, false, false, false, false, 2, true)
    end
end

if ROUES and PO.roues ~= false then
    CreateThread(function()
        while true do
            -- liste des poussettes proches (toutes les 0,5 s)
            local pc = GetEntityCoords(PlayerPedId())
            local vues = {}
            local actives = (GlobalState.bebeReglages or {}).roues ~= false     -- désactivables dans le menu admin
            for _, obj in ipairs(actives and GetGamePool('CObject') or {}) do
                local st = Entity(obj).state
                if st.bebePoussette and #(GetEntityCoords(obj) - pc) < 60.0 then
                    vues[obj] = true
                    if not roues[obj] then roues[obj] = creerRoues(obj, st.bebeColoris) or { objs = {}, last = GetEntityCoords(obj) } end
                end
            end
            for obj, r in pairs(roues) do
                if not vues[obj] or not DoesEntityExist(obj) then supprimerRoues(r) roues[obj] = nil end
            end
            Wait(500)
        end
    end)
    CreateThread(function()
        while true do
            local n = 0
            for obj, r in pairs(roues) do
                if DoesEntityExist(obj) and #r.objs > 0 then tournerRoues(obj, r) n = n + 1 end
            end
            Wait(n > 0 and 0 or 500)
        end
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, r in pairs(roues) do supprimerRoues(r) end
    for pid in pairs(simulations) do simulations[pid] = 'abandon' end
end)
