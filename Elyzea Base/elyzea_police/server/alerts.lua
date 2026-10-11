-- =====================================================================
--  ELYZEA POLICE - serveur : alertes
--  · Alerte agent (F6) : niveau faible / moyen / urgent ; position relevée par le serveur ;
--    le GPS de la bonne couleur est posé automatiquement chez tous les agents en service.
--  · Alerte générale (coups de feu, vol de véhicule, braquage, appel…) : chaque agent
--    valide (GPS + prise en charge visible par tous) ou décline (masquée pour lui seul).
--  Les clients ne reçoivent que des ajouts / retraits ponctuels, jamais un flux continu.
-- =====================================================================
local P = Police
local AA, GA = Config.AgentAlerts, Config.Alerts

P.AgentAlerts = {}     -- [id] = alerte agent active
P.GeneralAlerts = {}   -- [id] = alerte générale active
local lastAgentAlert, lastCall, lastAuto = {}, {}, {}

local function Receivers()
    return P.CopsOnDuty('alerts_receive')
end
local function SendTo(list, event, ...)
    for _, id in ipairs(list) do TriggerClientEvent(event, id, ...) end
end

local function Round(c) return { x = math.floor(c.x * 100) / 100, y = math.floor(c.y * 100) / 100, z = math.floor(c.z * 100) / 100 } end

-- ---------------------------------------------------------------------
-- Alertes agent
-- ---------------------------------------------------------------------
local function PublicAgent(a)
    return { id = a.id, level = a.level, x = a.x, y = a.y, z = a.z, street = a.street, author = a.authorName, matricule = a.matricule,
        authorId = a.author, t = a.t }
end

function P.AgentAlertList()
    local list = {}
    for _, a in pairs(P.AgentAlerts) do list[#list + 1] = PublicAgent(a) end
    table.sort(list, function(a, b) return a.t > b.t end)
    return list
end

P.Actions.agentAlert = { perm = 'alert_agent', duty = true, fn = function(src, d)
    local lvl = AA.levels[d.level] and d.level or nil
    if not lvl then return { error = 'Niveau d\'alerte inconnu.' } end
    local now = os.time()
    if lastAgentAlert[src] and now - lastAgentAlert[src] < AA.cooldown then
        return { error = ('Patientez %d s avant une nouvelle alerte.'):format(AA.cooldown - (now - lastAgentAlert[src])) }
    end
    local c = P.Coords(src)
    if not c then return { error = 'Position introuvable.' } end
    lastAgentAlert[src] = now
    local e = P.Employee(src)
    local street = P.Clean(d.street, 120)
    local id = MySQL.insert.await([[INSERT INTO `police_alerts` (`kind`, `type`, `title`, `x`, `y`, `z`, `street`, `author_cid`, `author_name`)
        VALUES ('agent', ?, ?, ?, ?, ?, ?, ?, ?)]], { lvl, 'Alerte agent · ' .. AA.levels[lvl].label, c.x, c.y, c.z, street, P.Cid(src), P.Name(src) })
    if not id then return { error = 'Enregistrement impossible.' } end
    local pos = Round(c)
    local a = { id = id, level = lvl, x = pos.x, y = pos.y, z = pos.z, street = street, author = src, authorCid = P.Cid(src),
        authorName = P.Name(src), matricule = e and e.matricule or '?', t = now }
    P.AgentAlerts[id] = a
    SendTo(Receivers(), 'police:client:agentAlert', PublicAgent(a))
    P.Log(src, 'Alerte agent', ('%s · %s'):format(AA.levels[lvl].label, street))
    return { ok = true, message = ('Alerte %s envoyée à %d agent(s).'):format(AA.levels[lvl].label:lower(), #Receivers()), id = id }
end }

function P.CloseAgentAlert(id, byName)
    local a = P.AgentAlerts[id]
    if not a then return false end
    P.AgentAlerts[id] = nil
    MySQL.update('UPDATE `police_alerts` SET `status` = \'closed\', `closed_by` = ?, `closed_at` = NOW() WHERE `id` = ?', { byName, id })
    -- Retrait chez tous ceux qui ont pu la recevoir (aussi ceux qui ont quitté le service entre-temps)
    TriggerClientEvent('police:client:agentAlertClosed', -1, id, byName)
    return true
end

P.Actions.closeAgentAlert = { perm = nil, fn = function(src, d)
    local a = P.AgentAlerts[tonumber(d.id) or 0]
    if not a then return { error = 'Cette alerte est déjà clôturée.' } end
    if a.authorCid ~= P.Cid(src) and not P.Can(src, 'alert_close') then return { error = 'Seul l\'auteur ou un gradé habilité peut la clôturer.' } end
    P.CloseAgentAlert(a.id, P.Name(src))
    P.Log(src, 'Alerte agent clôturée', ('#%d'):format(a.id))
    return { ok = true, message = 'Alerte clôturée.' }
end }

-- L'auteur quitte le serveur : règle configurable
function P.AuthorLeft(src)
    for id, a in pairs(P.AgentAlerts) do
        if a.author == src then
            if AA.onAuthorLeave == 'close' then
                P.CloseAgentAlert(id, 'Système (auteur déconnecté)')
            else
                a.author = nil
                a.leftAt = os.time()
            end
        end
    end
end

-- ---------------------------------------------------------------------
-- Alertes générales
-- ---------------------------------------------------------------------
local function PublicGeneral(g)
    local takers = {}
    for _, t in pairs(g.takers) do takers[#takers + 1] = t end
    return { id = g.id, type = g.type, label = GA.types[g.type].label, title = g.title, description = g.description,
        x = g.x, y = g.y, z = g.z, street = g.street, t = g.t, count = g.count, takers = takers,
        sprite = GA.types[g.type].sprite, color = GA.types[g.type].color, radius = g.radius or GA.types[g.type].radius }
end

function P.GeneralAlertList()
    local list = {}
    for _, g in pairs(P.GeneralAlerts) do list[#list + 1] = PublicGeneral(g) end
    table.sort(list, function(a, b) return a.t > b.t end)
    return list
end

-- Crée (ou regroupe) une alerte générale. coords = vector3 / table ; renvoie l'id
function P.CreateGeneral(kind, coords, title, description, street, opts)
    if not GA.types[kind] then kind = 'other' end
    local c = vector3(tonumber(coords.x) or 0.0, tonumber(coords.y) or 0.0, tonumber(coords.z) or 0.0)
    local now = os.time()
    for _, g in pairs(P.GeneralAlerts) do
        if g.type == kind and now - g.t < 60 and #(vector3(g.x, g.y, g.z) - c) < GA.mergeRadius then
            g.count = g.count + 1
            g.t = now
            SendTo(Receivers(), 'police:client:generalUpdate', PublicGeneral(g))
            return g.id
        end
    end
    title = P.Clean(title ~= nil and title ~= '' and title or GA.types[kind].label, 100)
    description = P.Clean(description, 255)
    street = P.Clean(street, 120)
    local id = MySQL.insert.await([[INSERT INTO `police_alerts` (`kind`, `type`, `title`, `description`, `x`, `y`, `z`, `street`)
        VALUES ('general', ?, ?, ?, ?, ?, ?, ?)]], { kind, title, description, c.x, c.y, c.z, street })
    if not id then return nil end
    local pos = Round(c)
    local g = { id = id, type = kind, title = title, description = description, x = pos.x, y = pos.y, z = pos.z, street = street,
        t = now, created = now, count = 1, takers = {},
        radius = type(opts) == 'table' and tonumber(opts.radius) and math.max(0, math.min(2000, tonumber(opts.radius))) or nil }
    P.GeneralAlerts[id] = g
    SendTo(Receivers(), 'police:client:generalAlert', PublicGeneral(g))
    return id
end

local function CloseGeneral(id, byName)
    local g = P.GeneralAlerts[id]
    if not g then return false end
    P.GeneralAlerts[id] = nil
    MySQL.update('UPDATE `police_alerts` SET `status` = \'closed\', `closed_by` = ?, `closed_at` = NOW() WHERE `id` = ?', { byName, id })
    TriggerClientEvent('police:client:generalClosed', -1, id)
    return true
end

-- VALIDER : prise en charge (ou rejoindre une intervention déjà prise)
P.Actions.acceptAlert = { perm = 'alerts_receive', duty = true, fn = function(src, d)
    local g = P.GeneralAlerts[tonumber(d.id) or 0]
    if not g then return { error = 'Cette alerte n\'est plus active.' } end
    local cid = P.Cid(src)
    if g.takers[cid] then return { ok = true, alert = PublicGeneral(g) } end
    local e = P.Employee(src)
    local first = next(g.takers) == nil
    g.takers[cid] = ('%s (%s)'):format(P.Name(src), e and e.matricule or '?')
    P.status[src] = 'busy'
    P.PushState(src)
    SendTo(Receivers(), 'police:client:generalUpdate', PublicGeneral(g))
    MySQL.update('UPDATE `police_alerts` SET `author_name` = COALESCE(`author_name`, ?) WHERE `id` = ?', { P.Name(src), g.id })
    return { ok = true, alert = PublicGeneral(g), message = first and 'Intervention prise en charge.' or 'Vous rejoignez l\'intervention.' }
end }

-- Fin d'intervention : un agent qui l'a prise en charge, ou un gradé habilité
P.Actions.closeGeneral = { perm = 'alerts_receive', fn = function(src, d)
    local g = P.GeneralAlerts[tonumber(d.id) or 0]
    if not g then return { error = 'Cette alerte est déjà clôturée.' } end
    if not g.takers[P.Cid(src)] and not P.Can(src, 'alert_close') then return { error = 'Prenez d\'abord l\'intervention en charge.' } end
    CloseGeneral(g.id, P.Name(src))
    if P.status[src] == 'busy' then P.status[src] = 'available' P.PushState(src) end
    return { ok = true, message = 'Intervention terminée.' }
end }

P.Actions.alerts = { perm = 'alerts_receive', fn = function()
    return { agent = P.AgentAlertList(), general = P.GeneralAlertList(), now = os.time() }
end }

-- Agent qui prend son service : il reçoit les alertes en cours
function P.SyncAlertsTo(src)
    if not P.Can(src, 'alerts_receive') then return end
    TriggerClientEvent('police:client:syncAlerts', src, P.AgentAlertList(), P.GeneralAlertList())
end

-- ---------------------------------------------------------------------
-- Signalements automatiques (clients) et appels des citoyens
-- ---------------------------------------------------------------------
RegisterNetEvent('police:server:autoReport', function(kind, street)
    local src = source
    local t = GA.types[kind]
    if not t or not t.auto then return end
    if P.OnDuty(src) then return end
    local key = src .. ':' .. kind
    local now = os.time()
    if lastAuto[key] and now - lastAuto[key] < (t.cooldown or 30) then return end
    lastAuto[key] = now
    if math.random(100) > (t.chance or 100) then return end
    local c = P.Coords(src)
    if not c then return end
    P.CreateGeneral(kind, c, t.label, kind == 'shots' and 'Des tirs ont été entendus dans le secteur.' or 'Un vol de véhicule est en cours.', street)
end)

RegisterCommand(GA.callCommand, function(src, args)
    if src == 0 then return end
    local now = os.time()
    if lastCall[src] and now - lastCall[src] < GA.callCooldown then
        return P.Notify(src, ('Patientez %d s avant un nouvel appel.'):format(GA.callCooldown - (now - lastCall[src])), 'error')
    end
    local msg = P.Clean(table.concat(args, ' '), 200)
    if #msg < 4 then return P.Notify(src, ('Utilisation : /%s <message>'):format(GA.callCommand), 'error') end
    local c = P.Coords(src)
    if not c then return end
    lastCall[src] = now
    TriggerClientEvent('police:client:streetFor', src, 'distress', msg)
end, false)

-- Le client renvoie le nom de sa rue pour l'appel
RegisterNetEvent('police:server:distress', function(msg, street)
    local src = source
    if not lastCall[src] or os.time() - lastCall[src] > 10 then return end
    local c = P.Coords(src)
    if not c then return end
    P.CreateGeneral('distress', c, 'Appel de détresse', ('%s : « %s »'):format(P.Name(src), P.Clean(msg, 200)), street)
    local n = #Receivers()
    P.Notify(src, n > 0 and 'Votre appel a été transmis à la police.' or 'Aucun agent en service pour le moment : votre appel est enregistré.', n > 0 and 'success' or 'inform')
end)

-- ---------------------------------------------------------------------
-- Nettoyage : alertes oubliées, auteurs partis, alertes non prises en charge
-- ---------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for id, a in pairs(P.AgentAlerts) do
            if (a.leftAt and now - a.leftAt > AA.keepMinutes * 60) or now - a.t > AA.maxMinutes * 60 then
                P.CloseAgentAlert(id, 'Système')
            end
        end
        for id, g in pairs(P.GeneralAlerts) do
            local stale = next(g.takers) == nil and now - g.t > GA.lifetime
            if stale or now - g.created > AA.maxMinutes * 60 then CloseGeneral(id, 'Système') end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastAgentAlert[src], lastCall[src] = nil, nil
    for key in pairs(lastAuto) do if key:find('^' .. src .. ':') then lastAuto[key] = nil end end
end)
