-- =====================================================================
--  ELYZEA DYNASTY 8 - serveur : accès aux biens
--  · Chaque bien a sa propre instance (routing bucket) : deux biens qui utilisent le même
--    intérieur ne se croisent jamais.
--  · Droits (vérifiés ici, jamais par le client) :
--      titulaire du contrat (propriétaire / locataire principal) : tout ;
--      locataires ajoutés : entrée + droits accordés (coffre, gestion, garage) ;
--      code / sonnette : entrée seule, temporaire ; visite commerciale : entrée seule ;
--      staff (property_manage) : configuration.
--  · Déconnexion à l'intérieur : à la reconnexion, le joueur ressort devant l'entrée.
-- =====================================================================
local P = Dynasty
local core = exports.elyzea_core

P.inside = {}       -- [src] = { pid, area = 'home' | 'garage' | 'test', kind = 'resident'|'tenant'|'guest'|'visit'|'staff' }
P.grants = {}       -- [pid] = { [src] = { kind, expires } } : entrées temporaires (code, sonnette)
P.visits = {}       -- [pid] = { id, agent, agentName, clients = { [src] = true }, started, expires }

local function Bucket(pid) return Config.BucketBase + pid end
local function TestBucket(src) return Config.BucketBase - 1000 - src end
local pos = P.PosOf

-- ---------------------------------------------------------------------
-- Droits
-- ---------------------------------------------------------------------
-- Rôle d'un joueur sur un bien : 'holder' | 'tenant' | nil, et ses droits
function P.RoleOf(src, pid)
    local cid = P.Cid(src)
    if not cid then return nil end
    local c = P.Contract and P.Contract(pid)
    if not c then return nil end
    if c.holder_cid == cid then return 'holder', { stash = true, manage = true, garage = true, extend = true, holder = true } end
    local a = c.access and c.access[cid]
    if a then return 'tenant', { stash = a.can_stash, manage = a.can_manage, garage = a.can_garage } end
    return nil
end

local function GrantValid(pid, src)
    local g = P.grants[pid] and P.grants[pid][src]
    if not g then return false end
    if os.time() > g.expires then P.grants[pid][src] = nil return false end
    return true
end
local function InVisit(pid, src)
    local v = P.visits[pid]
    return v ~= nil and (v.agent == src or v.clients[src] == true)
end

function P.InsideCount(pid, area)
    local n = 0
    for _, i in pairs(P.inside) do if i.pid == pid and (not area or i.area == area) then n = n + 1 end end
    return n
end

-- ---------------------------------------------------------------------
-- Entrer / sortir
-- ---------------------------------------------------------------------
local function InteriorPoints(pr, area)
    if area == 'garage' then
        local g = pr.garage or {}
        return { exit = g.points and g.points.exit, inside = g.points and g.points.inside, slots = g.slots or {} }
    end
    return { exit = pr.points.exit, manage = pr.points.manage, stash = pr.points.stash }
end

P.InteriorPoints = InteriorPoints

local function SpawnFor(pr, area)
    if area == 'garage' then
        local g = pr.garage
        local i = g and P.interiors[g.interiorId or 0]
        local p = g and g.points and g.points.inside
        if p then return p, i end
        return i and { x = i.x, y = i.y, z = i.z, h = i.h } or nil, i
    end
    local i = P.interiors[pr.interiorId or 0]
    if not i then return nil end
    -- Arrivée : à côté de la sortie si elle est placée, sinon au point de l'intérieur
    local e = pr.points.exit
    if e then return { x = e.x, y = e.y, z = e.z, h = e.h or i.h }, i end
    return { x = i.x, y = i.y, z = i.z, h = i.h }, i
end

-- Place le joueur dans l'instance du bien et l'y téléporte
function P.PutInside(src, pr, area, kind)
    local spawn, interior = SpawnFor(pr, area)
    if not spawn then return false, area == 'garage' and 'Le garage de ce bien n\'est pas configuré.' or 'L\'intérieur de ce bien n\'est pas configuré.' end
    local outside = area == 'garage' and pr.garage and pr.garage.points and pr.garage.points.enter or pr.points.enter
    P.inside[src] = { pid = pr.id, area = area, kind = kind, since = os.time() }
    SetPlayerRoutingBucket(src, Bucket(pr.id))
    pcall(function() core:SetMetadata(src, 'd8_inside', { pid = pr.id, x = outside and outside.x, y = outside and outside.y, z = outside and outside.z }) end)
    Player(src).state:set('d8In', { pid = pr.id, area = area }, true)
    local role, rights = P.RoleOf(src, pr.id)
    TriggerClientEvent('d8:client:enter', src, {
        pid = pr.id, name = pr.name, area = area, kind = kind, spawn = spawn, ipls = interior and interior.ipls or {},
        points = InteriorPoints(pr, area), role = role, rights = rights or {}, admin = kind == 'staff',
    })
    return true
end

function P.PutOutside(src, reason)
    local i = P.inside[src]
    local pr = i and P.props[i.pid]
    P.inside[src] = nil
    SetPlayerRoutingBucket(src, 0)
    Player(src).state:set('d8In', nil, true)
    pcall(function() core:SetMetadata(src, 'd8_inside', nil) end)
    local out
    if pr then
        out = (i.area == 'garage' and pr.garage and pr.garage.points and pr.garage.points.enter) or pr.points.enter
    elseif i and i.back then out = i.back end
    TriggerClientEvent('d8:client:exit', src, out, reason)
    return true
end

-- Tout le monde dehors (expiration, vente, désactivation)
function P.EvictAll(pid, reason, keepRole)
    for src, i in pairs(P.inside) do
        if i.pid == pid and not (keepRole and P.RoleOf(src, pid)) then
            P.PutOutside(src, reason)
            if reason then P.Notify(src, reason, 'inform') end
        end
    end
end

local function NearPoint(src, p, extra)
    if not p then return false end
    local c = P.Coords(src)
    return c ~= nil and #(c - pos(p)) <= (tonumber(p.r) or 1.2) + (extra or 2.5)
end
P.NearPoint = NearPoint

-- Que peut faire ce joueur devant la porte ? (menu E)
P.Pub.doorInfo = { fn = function(src, d)
    local pr = P.props[tonumber(d.pid) or 0]
    if not pr or not pr.enabled then return { error = 'Bien indisponible.' } end
    local area = d.area == 'garage' and 'garage' or 'home'
    local point = area == 'garage' and pr.garage and pr.garage.points and pr.garage.points.enter or pr.points.enter
    if not NearPoint(src, point, 3.0) and not NearPoint(src, pr.points.bell, 3.0) then return { error = 'Approchez-vous de la porte.' } end
    local role, rights = P.RoleOf(src, pr.id)
    local agent = P.IsDynasty(src) and P.OnDuty(src)
    local v = P.visits[pr.id]
    return {
        name = pr.name, address = pr.address, category = pr.category, status = pr.status, area = area,
        canEnter = (role ~= nil and (area == 'home' or rights.garage)) or GrantValid(pr.id, src) or InVisit(pr.id, src),
        role = role, hasCode = pr.code ~= nil and area == 'home', occupied = pr.contractId ~= nil and area == 'home',
        visit = v and (v.agent == src and 'agent' or v.clients[src] and 'client') or nil,
        canVisit = agent and P.Can(src, 'visits') and pr.status == 'available' and not pr.contractId,
        staff = P.IsStaffAdmin(src),
    }
end }

P.Pub.enter = { fn = function(src, d)
    local pr = P.props[tonumber(d.pid) or 0]
    if not pr or not pr.enabled then return { error = 'Bien indisponible.' } end
    if P.inside[src] then return { error = 'Vous êtes déjà dans un bien.' } end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return { error = 'Descendez du véhicule.' } end
    local area = d.area == 'garage' and 'garage' or 'home'
    if area == 'home' and pr.category == 'garage' then return { error = 'Ce bien est un garage.' } end
    if area == 'garage' and not (pr.garage and pr.garage.enabled) then return { error = 'Ce bien n\'a pas de garage.' } end
    local point = area == 'garage' and pr.garage.points and pr.garage.points.enter or pr.points.enter
    if not NearPoint(src, point, 3.0) and not (area == 'home' and NearPoint(src, pr.points.bell, 3.0)) then return { error = 'Approchez-vous de la porte.' } end
    local role, rights = P.RoleOf(src, pr.id)
    local kind
    if role and (area == 'home' or rights.garage) then kind = role == 'holder' and 'resident' or 'tenant'
    elseif InVisit(pr.id, src) then kind = 'visit'
    elseif area == 'home' and GrantValid(pr.id, src) then kind = 'guest'
    elseif d.staff == true and P.IsStaffAdmin(src) then kind = 'staff'
    else return { error = area == 'garage' and 'Vous n\'avez pas accès à ce garage.' or 'Porte fermée : entrez le code ou sonnez.' } end
    local ok, why = P.PutInside(src, pr, area, kind)
    if not ok then return { error = why } end
    return { ok = true }
end }

P.Pub.exit = { fn = function(src)
    if not P.inside[src] then return { error = 'Vous n\'êtes pas dans un bien.' } end
    local i = P.inside[src]
    local pr = P.props[i.pid]
    if pr and i.area ~= 'test' then
        local p = i.area == 'garage' and pr.garage and pr.garage.points and pr.garage.points.exit or pr.points.exit
        if p and not NearPoint(src, p, 2.5) and i.kind ~= 'staff' then return { error = 'Allez au point de sortie (cercle rouge).' } end
    end
    P.PutOutside(src)
    return { ok = true }
end }

-- Code de la porte : entrée seule (aucun droit sur le coffre ni la gestion)
local tries = {}
P.Pub.code = { fn = function(src, d)
    local pr = P.props[tonumber(d.pid) or 0]
    if not pr or not pr.enabled then return { error = 'Bien indisponible.' } end
    if not NearPoint(src, pr.points.enter, 3.0) then return { error = 'Approchez-vous de la porte.' } end
    local t = tries[src] or { n = 0, t = os.time() }
    if os.time() - t.t > 60 then t = { n = 0, t = os.time() } end
    if t.n >= 5 then return { error = 'Trop d\'essais : patientez une minute.' } end
    t.n = t.n + 1
    tries[src] = t
    if not pr.code or tostring(d.code or '') ~= pr.code then
        P.PropLog(pr.id, 'Code erroné', P.Name(src), 'Système')
        return { error = 'Code incorrect.' }
    end
    tries[src] = nil
    P.grants[pr.id] = P.grants[pr.id] or {}
    P.grants[pr.id][src] = { kind = 'code', expires = os.time() + 60 }
    local ok, why = P.PutInside(src, pr, 'home', 'guest')
    if not ok then return { error = why } end
    return { ok = true }
end }

-- ---------------------------------------------------------------------
-- Sonnette : les résidents connectés acceptent ou refusent ; la première réponse compte
-- ---------------------------------------------------------------------
local bells = {}         -- [id] = { pid, visitor, expires, answered, notified = {src} }
local bellSeq, lastBell = 0, {}
P.Pub.bell = { fn = function(src, d)
    local pr = P.props[tonumber(d.pid) or 0]
    if not pr or not pr.enabled then return { error = 'Bien indisponible.' } end
    if not NearPoint(src, pr.points.bell or pr.points.enter, 3.0) and not NearPoint(src, pr.points.enter, 3.0) then return { error = 'Approchez-vous de la porte.' } end
    if lastBell[src] and os.time() - lastBell[src] < Config.Bell.cooldown then return { error = 'Patientez avant de sonner à nouveau.' } end
    local c = P.Contract and P.Contract(pr.id)
    if not c then return { error = 'Personne n\'habite ici.' } end
    lastBell[src] = os.time()
    local residents = {}
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        if s ~= src and P.RoleOf(s, pr.id) then residents[#residents + 1] = s end
    end
    if #residents == 0 then return { ok = true, message = 'Vous sonnez… personne ne répond.' } end
    bellSeq = bellSeq + 1
    local b = { id = bellSeq, pid = pr.id, visitor = src, expires = os.time() + Config.Bell.timeout, notified = residents }
    bells[b.id] = b
    for _, s in ipairs(residents) do
        TriggerClientEvent('d8:client:bell', s, { id = b.id, visitor = P.Name(src), property = pr.name, t = os.time(), timeout = Config.Bell.timeout })
    end
    SetTimeout(Config.Bell.timeout * 1000, function()
        local x = bells[b.id]
        if x and not x.answered then
            bells[b.id] = nil
            for _, s in ipairs(x.notified) do TriggerClientEvent('d8:client:bellClosed', s, x.id) end
            if GetPlayerName(x.visitor) then P.Notify(x.visitor, 'Personne n\'a ouvert.', 'error') end
        end
    end)
    return { ok = true, message = 'Vous avez sonné : attendez la réponse des résidents.' }
end }

RegisterNetEvent('d8:server:bellAnswer', function(id, accept)
    local src = source
    local b = bells[tonumber(id) or 0]
    if not b or b.answered or os.time() > b.expires then return end
    if not P.RoleOf(src, b.pid) then return end
    b.answered = true
    bells[b.id] = nil
    for _, s in ipairs(b.notified) do if s ~= src then TriggerClientEvent('d8:client:bellClosed', s, b.id) end end
    local pr = P.props[b.pid]
    if not GetPlayerName(b.visitor) or not pr then return end
    if accept ~= true then
        P.Notify(b.visitor, 'Le résident a refusé de vous ouvrir.', 'error')
        P.Notify(src, 'Visiteur refusé.', 'inform')
        return
    end
    P.grants[b.pid] = P.grants[b.pid] or {}
    P.grants[b.pid][b.visitor] = { kind = 'bell', expires = os.time() + Config.Bell.accessMinutes * 60 }
    P.Notify(src, ('Vous avez ouvert à %s.'):format(P.Name(b.visitor)), 'success')
    if NearPoint(b.visitor, pr.points.enter, 4.0) or NearPoint(b.visitor, pr.points.bell, 4.0) then
        local ok = P.PutInside(b.visitor, pr, 'home', 'guest')
        if ok then P.Notify(b.visitor, ('%s vous a ouvert.'):format(P.Name(src)), 'success') end
    else
        P.Notify(b.visitor, 'Le résident vous a ouvert : revenez à la porte pour entrer.', 'success')
    end
end)

-- ---------------------------------------------------------------------
-- Visites commerciales (biens disponibles uniquement, aucun droit permanent)
-- ---------------------------------------------------------------------
local function EndVisit(pid, reason)
    local v = P.visits[pid]
    if not v then return end
    P.visits[pid] = nil
    MySQL.update('UPDATE `d8_visits` SET `ended_at` = NOW(), `end_reason` = ? WHERE `id` = ?', { reason, v.id })
    for src, i in pairs(P.inside) do
        if i.pid == pid and i.kind == 'visit' then
            P.PutOutside(src)
            P.Notify(src, ('Visite terminée%s.'):format(reason and (' : ' .. reason) or ''), 'inform')
        end
    end
    if GetPlayerName(v.agent) then
        if P.status[v.agent] == 'visit' then P.status[v.agent] = 'available' P.PushState(v.agent) end
        TriggerClientEvent('d8:client:visit', v.agent, nil)
    end
end
P.EndVisit = EndVisit
function P.EndVisitsFor(pid, reason) EndVisit(pid, reason) end
function P.ReleaseAll(src)
    for pid, v in pairs(P.visits) do if v.agent == src then EndVisit(pid, 'fin de service de l\'agent') end end
end

P.Actions.visitStart = { perm = 'visits', duty = true, fn = function(src, d)
    local pr = P.props[tonumber(d.pid) or 0]
    if not pr or not pr.enabled then return { error = 'Bien indisponible.' } end
    if pr.status ~= 'available' or pr.contractId then return { error = 'Seuls les biens disponibles peuvent être visités.' } end
    for pid, v in pairs(P.visits) do if v.agent == src then return { error = ('Vous avez déjà une visite en cours (bien #%d).'):format(pid) } end end
    if P.visits[pr.id] then return { error = ('%s fait déjà visiter ce bien.'):format(P.visits[pr.id].agentName) } end
    local id = MySQL.insert.await('INSERT INTO `d8_visits` (`property_id`, `employee_cid`, `employee_name`) VALUES (?, ?, ?)', { pr.id, P.Cid(src), P.Name(src) })
    P.visits[pr.id] = { id = id, agent = src, agentName = P.Name(src), clients = {}, names = {}, started = os.time(), expires = os.time() + Config.Visit.maxMinutes * 60 }
    P.status[src] = 'visit'
    P.PushState(src)
    TriggerClientEvent('d8:client:visit', src, { pid = pr.id, name = pr.name, enter = pr.points.enter, garage = pr.garage and pr.garage.enabled and pr.garage.points and pr.garage.points.enter or nil })
    P.Log(src, 'Visite commencée', ('#%d %s'):format(pr.id, pr.name))
    return { ok = true, message = ('Visite de « %s » ouverte (%d min) : GPS tracé vers l\'entrée.'):format(pr.name, Config.Visit.maxMinutes), enter = pr.points.enter }
end }

-- Invite un client proche : il accepte sur son écran puis entre avec l'agent
local invites = {}
P.Actions.visitInvite = { perm = 'visits', duty = true, fn = function(src, d)
    local pid
    for id, v in pairs(P.visits) do if v.agent == src then pid = id end end
    if not pid then return { error = 'Aucune visite en cours.' } end
    local t = tonumber(d.target)
    if not t or t == src or not GetPlayerName(t) or P.Dist(src, t) > Config.Visit.inviteDistance then return { error = 'Le client doit être à côté de vous.' } end
    if P.visits[pid].clients[t] then return { error = 'Ce client participe déjà à la visite.' } end
    invites[t] = { pid = pid, agent = src, expires = os.time() + 30 }
    TriggerClientEvent('d8:client:visitInvite', t, { agent = P.Name(src), property = P.props[pid].name, timeout = 30 })
    return { ok = true, message = 'Invitation envoyée.' }
end }

RegisterNetEvent('d8:server:visitAnswer', function(accept)
    local src = source
    local inv = invites[src]
    invites[src] = nil
    if not inv or os.time() > inv.expires then return end
    local v = P.visits[inv.pid]
    local pr = P.props[inv.pid]
    if not v or v.agent ~= inv.agent or not pr or pr.status ~= 'available' or pr.contractId then return P.Notify(src, 'La visite n\'est plus possible.', 'error') end
    if accept ~= true then return P.Notify(inv.agent, ('%s a décliné la visite.'):format(P.Name(src)), 'inform') end
    v.clients[src] = true
    v.names[#v.names + 1] = P.Name(src)
    MySQL.update('UPDATE `d8_visits` SET `clients` = ? WHERE `id` = ?', { table.concat(v.names, ', '):sub(1, 255), v.id })
    P.Notify(inv.agent, ('%s participe à la visite.'):format(P.Name(src)), 'success')
    -- L'agent est déjà dedans : le client le rejoint ; sinon il entrera avec lui par la porte
    local ai = P.inside[inv.agent]
    if ai and ai.pid == pr.id and not P.inside[src] then P.PutInside(src, pr, ai.area, 'visit')
    else P.Notify(src, 'Entrez avec l\'agent par la porte (E).', 'inform') end
end)

P.Actions.visitEnd = { perm = 'visits', fn = function(src)
    for pid, v in pairs(P.visits) do if v.agent == src then EndVisit(pid, 'clôturée par l\'agent') return { ok = true, message = 'Visite terminée.' } end end
    return { error = 'Aucune visite en cours.' }
end }

P.Actions.visits = { perm = 'tablet', fn = function()
    return { list = MySQL.query.await([[SELECT v.`id`, v.`property_id`, p.`name`, v.`employee_name`, v.`clients`, UNIX_TIMESTAMP(v.`started_at`) AS s, UNIX_TIMESTAMP(v.`ended_at`) AS e, v.`end_reason`
        FROM `d8_visits` v LEFT JOIN `d8_properties` p ON p.`id` = v.`property_id` ORDER BY v.`id` DESC LIMIT 60]]) or {} }
end }

-- ---------------------------------------------------------------------
-- Coffre privé (orange) : le système d'inventaire du serveur, un coffre par contrat
-- ---------------------------------------------------------------------
local function StashId(pid, contractId) return ('d8:%d:%d'):format(pid, contractId) end
P.StashId = StashId

function P.CanStash(src, pid)
    local i = P.inside[src]
    if not i or i.pid ~= pid or i.area ~= 'home' then return false end
    local _, rights = P.RoleOf(src, pid)
    return rights ~= nil and rights.stash == true
end

local function RegisterStashOf(pr, c)
    local id = StashId(pr.id, c.id)
    exports.elyzea_inventory:RegisterStash(id, ('Coffre · %s'):format(pr.name), pr.stashSlots, pr.stashWeight * 1000)
    return id
end
P.RegisterStashOf = RegisterStashOf

P.Pub.stash = { fn = function(src, d)
    local pr = P.props[tonumber(d.pid) or 0]
    if not pr then return { error = 'Bien introuvable.' } end
    if GetResourceState('elyzea_inventory') ~= 'started' then return { error = 'Inventaire indisponible.' } end
    if not P.CanStash(src, pr.id) then return { error = 'Vous n\'avez pas accès à ce coffre.' } end
    if not NearPoint(src, pr.points.stash, 2.0) then return { error = 'Approchez-vous du coffre (cercle orange).' } end
    local c = P.Contract(pr.id)
    if not c then return { error = 'Aucun contrat actif.' } end
    if pr.stashSlots <= 0 then return { error = 'Ce bien n\'a pas de coffre.' } end
    local id = RegisterStashOf(pr, c)
    if not exports.elyzea_inventory:OpenInventory(src, 'stash', id) then return { error = 'Ouverture du coffre impossible.' } end
    return { ok = true }
end }

-- Toute ouverture d'un coffre « d8: » par l'inventaire est revérifiée ici
CreateThread(function()
    while GetResourceState('elyzea_inventory') ~= 'started' do Wait(2000) end
    pcall(function()
        exports.elyzea_inventory:RegisterStashAccess('d8:', function(src, stashId)
            local pid, cid = tostring(stashId):match('^d8:(%d+):(%d+)$')
            pid, cid = tonumber(pid), tonumber(cid)
            local c = pid and P.Contract and P.Contract(pid)
            return c ~= nil and c.id == cid and P.CanStash(src, pid)
        end)
    end)
end)

-- ---------------------------------------------------------------------
-- Staff : aller dans un bien / tester un intérieur
-- ---------------------------------------------------------------------
P.Admin.teleport = { fn = function(src, d)
    local pr = P.props[tonumber(d.id) or 0]
    if not pr then return { error = 'Bien introuvable.' } end
    local area = d.area == 'garage' and 'garage' or (d.area == 'outside' and 'outside' or 'home')
    if P.inside[src] then P.PutOutside(src) Wait(600) end
    if area == 'outside' then
        local p = pr.points.enter or (pr.garage and pr.garage.points and pr.garage.points.enter)
        if not p then return { error = 'Aucun point extérieur placé.' } end
        TriggerClientEvent('d8:client:exit', src, p)
        return { ok = true, message = 'Téléporté devant le bien.' }
    end
    local ok, why = P.PutInside(src, pr, area, 'staff')
    if not ok then return { error = why } end
    return { ok = true, message = area == 'garage' and 'Vous êtes dans le garage du bien (mode staff).' or 'Vous êtes dans le bien (mode staff).' }
end }

function P.EnterTest(src, i)
    local c = P.Coords(src)
    P.inside[src] = { pid = 0, area = 'test', kind = 'staff', back = c and { x = c.x, y = c.y, z = c.z } }
    SetPlayerRoutingBucket(src, TestBucket(src))
    TriggerClientEvent('d8:client:enter', src, { pid = 0, name = i.label, area = 'test', kind = 'staff', spawn = { x = i.x, y = i.y, z = i.z, h = i.h },
        ipls = i.ipls or {}, points = {}, admin = true })
end
RegisterCommand('d8sortir', function(src)
    if src > 0 and P.inside[src] and (P.inside[src].area == 'test' or P.inside[src].kind == 'staff') then P.PutOutside(src) end
end, false)

-- ---------------------------------------------------------------------
-- Déconnexion, reconnexion, redémarrage de la ressource
-- ---------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    P.inside[src] = nil
    invites[src] = nil
    tries[src] = nil
    lastBell[src] = nil
    for pid, g in pairs(P.grants) do g[src] = nil end
    for pid, v in pairs(P.visits) do
        if v.agent == src then EndVisit(pid, 'agent déconnecté') else v.clients[src] = nil end
    end
end)

-- Reconnexion dans un intérieur : retour devant l'entrée du bien (jamais coincé sous la carte)
AddEventHandler('elyzea:server:playerLoaded', function(src)
    local ok, md = pcall(function() return core:GetMetadata(src, 'd8_inside') end)
    if ok and type(md) == 'table' and md.x then
        SetPlayerRoutingBucket(src, 0)
        pcall(function() core:SetMetadata(src, 'd8_inside', nil) end)
        SetTimeout(2500, function()
            if GetPlayerName(src) then TriggerClientEvent('d8:client:exit', src, { x = md.x, y = md.y, z = md.z }, 'Vous étiez dans un logement : vous êtes devant l\'entrée.') end
        end)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src, i in pairs(P.inside) do
        local pr = P.props[i.pid]
        local out = pr and ((i.area == 'garage' and pr.garage and pr.garage.points and pr.garage.points.enter) or pr.points.enter) or i.back
        SetPlayerRoutingBucket(src, 0)
        pcall(function() core:SetMetadata(src, 'd8_inside', nil) end)
        if out then SetEntityCoords(GetPlayerPed(src), out.x + 0.0, out.y + 0.0, out.z + 0.0, false, false, false, false) end
    end
end)

-- Visites et entrées temporaires expirées
CreateThread(function()
    while true do
        Wait(15000)
        local now = os.time()
        for pid, v in pairs(P.visits) do
            local pr = P.props[pid]
            if now > v.expires then EndVisit(pid, 'durée maximale atteinte')
            elseif not pr or pr.status ~= 'available' or pr.contractId or not pr.enabled then EndVisit(pid, 'le bien n\'est plus disponible') end
        end
        for pid, g in pairs(P.grants) do for s, x in pairs(g) do if now > x.expires then g[s] = nil end end end
    end
end)
