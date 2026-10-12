-- =====================================================================
--  ELYZEA MÉCANO - serveur : demandes de dépannage + statistiques
--  Demandes des joueurs (app Urgences du téléphone › Dépannage, /depannage) :
--  pending → accepted → enroute → onsite → diagnostic → quote → repair → done (ou cancelled).
--  Chaque changement est journalisé (meca_tow_log). Pas de renfort entre employés.
-- =====================================================================
local P = Meca
local T = Config.Tow

P.tows = {}
local FINAL = { done = true, cancelled = true }

local function View(c)
    local crew = {}
    for s in pairs(c.crew) do if GetPlayerName(s) then crew[#crew + 1] = P.Name(s) end end
    table.sort(crew)
    return { id = c.id, reason = c.reason, description = c.description, street = c.street, client = c.clientName, phone = c.phone,
        vehicle = c.vehicle, plate = c.plate, status = c.status, crew = crew, assigned = c.assignedName,
        x = math.floor(c.x * 10) / 10, y = math.floor(c.y * 10) / 10, z = math.floor(c.z * 10) / 10, t = c.t }
end

function P.TowList(src)
    local list = {}
    for _, c in pairs(P.tows) do local v = View(c) v.mine = src ~= nil and c.crew[src] == true list[#list + 1] = v end
    table.sort(list, function(a, b) return a.t < b.t end)
    return list
end

local function Receivers() return P.CrewOnDuty('tow') end
local function Broadcast(ev, data) for _, s in ipairs(Receivers()) do TriggerClientEvent(ev, s, data) end end
local function Log(c, status, actor) MySQL.insert('INSERT INTO `meca_tow_log` (`tow_id`, `status`, `actor_name`) VALUES (?, ?, ?)', { c.id, status, actor }) end

-- Création (téléphone, commande, exports)
function P.CreateTow(src, message, coords, opts)
    opts = opts or {}
    if not coords and src then coords = P.Coords(src) end
    if not coords then return nil end
    local c = { source = tostring(opts.source or 'player'):sub(1, 20), reason = P.Clean(message ~= '' and message or 'Demande de dépannage', 150),
        description = opts.description and P.Clean(opts.description, 255) or nil, x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0,
        street = opts.street and P.Clean(opts.street, 120) or nil, clientSrc = src, clientCid = src and P.Cid(src) or nil,
        clientName = src and P.Name(src) or (opts.name and P.Clean(opts.name, 100) or nil), phone = opts.phone and P.Clean(opts.phone, 20) or nil,
        vehicle = opts.vehicle and P.Clean(opts.vehicle, 80) or nil, plate = opts.plate and P.CleanPlate(opts.plate) or nil,
        status = 'pending', crew = {}, t = os.time() }
    c.id = MySQL.insert.await([[INSERT INTO `meca_tow` (`source`, `reason`, `description`, `x`, `y`, `z`, `street`, `client_cid`, `client_name`, `client_phone`, `vehicle`, `plate`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], { c.source, c.reason, c.description, c.x, c.y, c.z, c.street, c.clientCid, c.clientName, c.phone, c.vehicle, c.plate })
    if not c.id then return nil end
    P.tows[c.id] = c
    Log(c, 'pending', c.clientName or 'Système')
    for _, s in ipairs(Receivers()) do
        local v = View(c)
        v.distance = math.floor(#(vector3(c.x, c.y, c.z) - (P.Coords(s) or vector3(0, 0, 0))))
        TriggerClientEvent('meca:client:tow', s, v)
    end
    return c.id, #Receivers()
end

local function Close(c, status, actor)
    c.status = status
    P.tows[c.id] = nil
    MySQL.update('UPDATE `meca_tow` SET `status` = ?, `closed_at` = NOW() WHERE `id` = ?', { status, c.id })
    Log(c, status, actor)
    Broadcast('meca:client:towRemove', c.id)
    if c.clientSrc and GetPlayerName(c.clientSrc) then
        P.Notify(c.clientSrc, status == 'done' and 'Dépannage terminé.' or 'Votre demande de dépannage est clôturée.', status == 'done' and 'success' or 'inform')
    end
end

local function Get(id) return P.tows[tonumber(id) or 0] end

P.Actions.tows = { perm = 'tow', fn = function(src)
    return { list = P.TowList(src), history = MySQL.query.await([[SELECT `id`, `reason`, `street`, `client_name`, `vehicle`, `plate`, `status`, `assigned_name`,
        UNIX_TIMESTAMP(`created_at`) AS t, UNIX_TIMESTAMP(`closed_at`) AS c FROM `meca_tow` WHERE `status` IN ('done', 'cancelled') ORDER BY `id` DESC LIMIT 40]]) or {},
        canManage = P.Can(src, 'tow_manage') }
end }

P.Actions.towInfo = { perm = 'tow', fn = function(src, d)
    local id = tonumber(d.id) or 0
    local row = MySQL.single.await([[SELECT `id`, `source`, `reason`, `description`, `street`, `client_name`, `client_phone`, `vehicle`, `plate`, `status`, `assigned_name`,
        UNIX_TIMESTAMP(`created_at`) AS t, UNIX_TIMESTAMP(`closed_at`) AS c FROM `meca_tow` WHERE `id` = ?]], { id })
    if not row then return { error = 'Demande introuvable.' } end
    row.log = MySQL.query.await('SELECT `status`, `actor_name`, UNIX_TIMESTAMP(`created_at`) AS t FROM `meca_tow_log` WHERE `tow_id` = ? ORDER BY `id`', { id }) or {}
    local c = P.tows[id]
    if c then row.live = View(c) row.live.mine = c.crew[src] == true end
    return { tow = row }
end }

P.Actions.towAccept = { perm = 'tow', duty = true, fn = function(src, d)
    local c = Get(d.id)
    if not c then return { error = 'Cette demande est terminée.' } end
    c.crew[src] = true
    if not c.assignedCid then
        c.assignedCid, c.assignedName = P.Cid(src), P.Name(src)
        MySQL.update('UPDATE `meca_tow` SET `assigned_cid` = ?, `assigned_name` = ? WHERE `id` = ?', { c.assignedCid, c.assignedName, c.id })
    end
    if c.status == 'pending' then
        c.status = 'accepted'
        MySQL.update('UPDATE `meca_tow` SET `status` = ? WHERE `id` = ?', { 'accepted', c.id })
        Log(c, 'accepted', P.Name(src))
    else
        Log(c, c.status, P.Name(src) .. ' (rejoint)')
    end
    P.status[src] = 'enroute'
    P.PushState(src)
    Broadcast('meca:client:towUpdate', View(c))
    if c.clientSrc and GetPlayerName(c.clientSrc) then P.Notify(c.clientSrc, 'Un mécanicien a accepté votre demande et arrive.', 'success') end
    return { ok = true, tow = View(c), message = 'Dépannage accepté : itinéraire tracé.' }
end }

P.Actions.towLeave = { perm = 'tow', fn = function(src, d)
    local c = Get(d.id)
    if not c or not c.crew[src] then return { error = 'Vous ne faites pas partie de cette intervention.' } end
    c.crew[src] = nil
    Log(c, c.status, P.Name(src) .. ' (quitte)')
    Broadcast('meca:client:towUpdate', View(c))
    return { ok = true, message = 'Vous avez quitté l\'intervention.' }
end }

P.Actions.towStatus = { perm = 'tow', duty = true, fn = function(src, d)
    local c = Get(d.id)
    if not c then return { error = 'Cette demande est terminée.' } end
    local st = tostring(d.status or '')
    if not T.statuses[st] or st == 'pending' then return { error = 'Statut inconnu.' } end
    local manage = P.Can(src, 'tow_manage')
    if not c.crew[src] and not manage then return { error = 'Acceptez la demande avant de changer son statut.' } end
    if st == 'cancelled' and not manage and c.assignedCid ~= P.Cid(src) then return { error = 'Seul le responsable ou un gradé peut annuler.' } end
    if FINAL[st] then
        Close(c, st, P.Name(src))
        for s in pairs(c.crew) do if GetPlayerName(s) and P.OnDuty(s) then P.status[s] = 'available' P.PushState(s) end end
        return { ok = true, message = st == 'done' and 'Intervention terminée.' or 'Intervention annulée.' }
    end
    c.crew[src] = true
    c.status = st
    MySQL.update('UPDATE `meca_tow` SET `status` = ? WHERE `id` = ?', { st, c.id })
    Log(c, st, P.Name(src))
    for s in pairs(c.crew) do if GetPlayerName(s) and P.OnDuty(s) then P.status[s] = (st == 'accepted' or st == 'enroute') and 'enroute' or 'busy' P.PushState(s) end end
    Broadcast('meca:client:towUpdate', View(c))
    if c.clientSrc and GetPlayerName(c.clientSrc) and (st == 'onsite' or st == 'quote') then
        P.Notify(c.clientSrc, st == 'onsite' and 'Le mécanicien est sur place.' or 'Le mécanicien prépare votre devis.', 'inform')
    end
    return { ok = true, message = ('Statut : %s.'):format(T.statuses[st]) }
end }

function P.SyncTowsTo(src)
    TriggerClientEvent('meca:client:syncTows', src, P.Can(src, 'tow') and P.TowList(src) or {})
end

function P.ReleaseAll(src)
    for _, c in pairs(P.tows) do
        if c.crew[src] then c.crew[src] = nil Broadcast('meca:client:towUpdate', View(c)) end
    end
end

-- /depannage <message> : tout le monde
local last = {}
RegisterNetEvent('meca:server:publicTow', function(msg, street, vehicle, plate)
    local src = source
    local now = os.time()
    if last[src] and now - last[src] < T.commandCooldown then
        return P.Notify(src, ('Patientez %d s avant une nouvelle demande.'):format(T.commandCooldown - (now - last[src])), 'error')
    end
    msg = P.Clean(msg, 150)
    if #msg < 3 then return P.Notify(src, ('Utilisation : /%s <message>'):format(T.command), 'error') end
    last[src] = now
    local _, n = P.CreateTow(src, msg, nil, { street = street, vehicle = vehicle, plate = plate, source = 'commande' })
    P.Notify(src, (n or 0) > 0 and 'Demande de dépannage transmise.' or 'Aucun mécanicien en service : votre demande est enregistrée.', 'success')
end)
RegisterCommand(T.command, function(src, args)
    if src <= 0 then return end
    TriggerClientEvent('meca:client:publicTow', src, table.concat(args, ' '))
end, false)

AddEventHandler('playerDropped', function()
    local src = source
    last[src] = nil
    for _, c in pairs(P.tows) do if c.clientSrc == src then c.clientSrc = nil end end
end)

CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for _, c in pairs(P.tows) do
            if c.status == 'pending' and now - c.t > T.lifetime then Close(c, 'cancelled', 'Système (expirée)') end
        end
    end
end)

P.OnReady = P.OnReady or {}
P.OnReady[#P.OnReady + 1] = function()
    MySQL.update.await("UPDATE `meca_tow` SET `status` = 'cancelled', `closed_at` = NOW() WHERE `status` NOT IN ('done', 'cancelled')")
end

-- ---------------------------------------------------------------------
-- Statistiques
-- ---------------------------------------------------------------------
P.Actions.stats = { perm = 'stats_view', fn = function(_, d)
    local days = P.Int(d.days, 1, 90, 7)
    local s = MySQL.single.await([[SELECT
        (SELECT COUNT(*) FROM `meca_invoices` WHERE `status` = 'paid' AND `created_at` >= DATE_SUB(NOW(), INTERVAL ? DAY)) AS invoices,
        (SELECT COALESCE(SUM(`amount`), 0) FROM `meca_invoices` WHERE `status` = 'paid' AND `created_at` >= DATE_SUB(NOW(), INTERVAL ? DAY)) AS revenue,
        (SELECT COUNT(*) FROM `meca_carplay` WHERE `installed_at` >= DATE_SUB(NOW(), INTERVAL ? DAY)) AS carplay,
        (SELECT COUNT(*) FROM `meca_tow` WHERE `created_at` >= DATE_SUB(NOW(), INTERVAL ? DAY)) AS tows,
        (SELECT COALESCE(SUM(`amount`), 0) FROM `meca_transactions` WHERE `type` = 'out' AND `category` = 'parts' AND `created_at` >= DATE_SUB(NOW(), INTERVAL ? DAY)) AS parts,
        (SELECT COALESCE(SUM(`amount`), 0) FROM `meca_transactions` WHERE `type` = 'out' AND `category` = 'salary' AND `created_at` >= DATE_SUB(NOW(), INTERVAL ? DAY)) AS salaries,
        (SELECT COALESCE(SUM(`amount`), 0) FROM `meca_transactions` WHERE `type` = 'out' AND `category` = 'refund' AND `created_at` >= DATE_SUB(NOW(), INTERVAL ? DAY)) AS refunds,
        (SELECT COUNT(*) FROM `meca_vehicle_history` WHERE `created_at` >= DATE_SUB(NOW(), INTERVAL ? DAY)) AS interventions]],
        { days, days, days, days, days, days, days, days }) or {}
    local top, byKind = {}, {}
    for _, r in ipairs(MySQL.query.await([[SELECT `items` FROM `meca_invoices` WHERE `status` = 'paid' AND `created_at` >= DATE_SUB(NOW(), INTERVAL ? DAY)]], { days }) or {}) do
        local ok, items = pcall(json.decode, r.items or '[]')
        for _, l in ipairs(ok and items or {}) do
            local k = l.name or l.code
            top[k] = top[k] or { name = k, n = 0, total = 0 }
            top[k].n = top[k].n + (tonumber(l.qty) or 1)
            top[k].total = top[k].total + (tonumber(l.total) or 0)
            byKind[l.kind or 'service'] = (byKind[l.kind or 'service'] or 0) + (tonumber(l.total) or 0)
        end
    end
    local list = {}
    for _, v in pairs(top) do list[#list + 1] = v end
    table.sort(list, function(a, b) return a.n > b.n end)
    while #list > 10 do table.remove(list) end
    local workers = MySQL.query.await([[SELECT `mechanic_name` AS name, COUNT(*) AS n FROM `meca_vehicle_history` WHERE `created_at` >= DATE_SUB(NOW(), INTERVAL ? DAY)
        AND `mechanic_name` IS NOT NULL GROUP BY `mechanic_cid`, `mechanic_name` ORDER BY n DESC LIMIT 10]], { days }) or {}
    return { days = days, totals = s, top = list, byKind = byKind, workers = workers }
end }
