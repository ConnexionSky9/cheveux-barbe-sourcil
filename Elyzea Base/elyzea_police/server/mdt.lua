-- =====================================================================
--  elyzea_police - serveur : tablette de l'agent (MDT)
-- =====================================================================
local P = Police
local M = {}   -- [action] = { perm, offDuty, fn(src, d) -> résultat }

local function GradeLabel(level)
    local g = P.Settings.job.grades[(tonumber(level) or 0) + 1]
    return g and g.name or ('Grade ' .. tostring(level))
end

local function MyPerms(src)
    local out = {}
    for perm in pairs(P.Settings.permGrades) do out[perm] = P.Can(src, perm, true) end
    return out
end

local function Me(src)
    local p = P.GetPlayer(src)
    local job = p.PlayerData.job
    return {
        id = src, name = P.Name(src), grade = job.grade.level, gradeLabel = job.grade.name,
        onduty = job.onduty == true, callsign = p.PlayerData.metadata.callsign, perms = MyPerms(src),
        jobLabel = job.label,
    }
end

local function Like(q)
    q = tostring(q or ''):lower():gsub('[%%_]', ''):sub(1, 50)
    return '%' .. q .. '%', q
end

-- ---------------------------------------------------------------------
-- Accueil
-- ---------------------------------------------------------------------
M.dashboard = { perm = 'mdt', offDuty = true, fn = function(src)
    local units = {}
    for _, c in ipairs(P.CopsOnDuty()) do
        local p = P.GetPlayer(c)
        units[#units + 1] = { id = c, name = P.Name(c), grade = p.PlayerData.job.grade.name,
            callsign = p.PlayerData.metadata.callsign }
    end
    table.sort(units, function(a, b) return (a.callsign or 'zz') < (b.callsign or 'zz') end)
    return {
        me = Me(src),
        units = units,
        calls = P.CallList(),
        warrants = MySQL.query.await('SELECT id, citizenid, name, reason, danger, officer, DATE_FORMAT(created_at, "%d/%m %H:%i") AS date FROM police_warrants WHERE active = 1 ORDER BY danger DESC, id DESC LIMIT 6') or {},
        records = MySQL.query.await('SELECT id, citizenid, name, title, officer, DATE_FORMAT(created_at, "%d/%m %H:%i") AS date FROM police_records ORDER BY id DESC LIMIT 6') or {},
        jailed = MySQL.scalar.await('SELECT COUNT(*) FROM police_jail') or 0,
    }
end }

M.toggleDuty = { perm = 'mdt', offDuty = true, fn = function(src)
    P.SetDuty(src)
    return { ok = true }
end }

M.setCallsign = { perm = 'mdt', offDuty = true, fn = function(src, d)
    local cs = tostring(d.callsign or ''):upper():gsub('[^%w%-]', ''):sub(1, 8)
    local p = P.GetPlayer(src)
    p.Functions.SetMetaData('callsign', cs ~= '' and cs or nil)
    return { ok = true, message = cs ~= '' and ('Indicatif : %s'):format(cs) or 'Indicatif retiré.' }
end }

-- ---------------------------------------------------------------------
-- Citoyens
-- ---------------------------------------------------------------------
M.searchCitizens = { perm = 'mdt', fn = function(_, d)
    local like, raw = Like(d.q)
    if #raw < 2 then return { list = {} } end
    local rows = MySQL.query.await([[SELECT citizenid, charinfo FROM players
        WHERE LOWER(CONCAT(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')), ' ', JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')))) LIKE ?
           OR LOWER(citizenid) LIKE ? OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.phone')) LIKE ?
        LIMIT 30]], { like, like, like }) or {}
    local list = {}
    for _, r in ipairs(rows) do
        local ci = json.decode(r.charinfo or '{}') or {}
        list[#list + 1] = { citizenid = r.citizenid, name = P.CharName(ci), birthdate = ci.birthdate, phone = ci.phone }
    end
    return { list = list }
end }

M.profile = { perm = 'mdt', fn = function(_, d)
    local cid = tostring(d.citizenid or '')
    local row = MySQL.single.await('SELECT citizenid, charinfo, metadata, job FROM players WHERE citizenid = ?', { cid })
    if not row then return { error = 'Citoyen introuvable.' } end
    local ci = json.decode(row.charinfo or '{}') or {}
    local meta = json.decode(row.metadata or '{}') or {}
    local job = json.decode(row.job or '{}') or {}
    local online = P.FindByCid(cid)
    local jail = MySQL.single.await('SELECT remaining, reason, officer FROM police_jail WHERE citizenid = ?', { cid })
    return {
        citizenid = cid, name = P.CharName(ci), birthdate = ci.birthdate, gender = ci.gender, phone = ci.phone,
        nationality = ci.nationality, job = job.label or job.name, online = online ~= nil, onlineId = online,
        licences = meta.licences or {},
        jail = jail,
        records = MySQL.query.await('SELECT id, title, content, charges, fine, jail, officer, DATE_FORMAT(created_at, "%d/%m/%Y %H:%i") AS date FROM police_records WHERE citizenid = ? ORDER BY id DESC', { cid }) or {},
        fines = MySQL.query.await('SELECT id, label, amount, paid, officer, DATE_FORMAT(created_at, "%d/%m/%Y") AS date FROM police_fines WHERE citizenid = ? ORDER BY id DESC LIMIT 50', { cid }) or {},
        warrants = MySQL.query.await('SELECT id, name, reason, danger, officer, DATE_FORMAT(created_at, "%d/%m/%Y") AS date FROM police_warrants WHERE citizenid = ? AND active = 1 ORDER BY id DESC', { cid }) or {},
        vehicles = MySQL.query.await('SELECT plate, vehicle FROM player_vehicles WHERE citizenid = ?', { cid }) or {},
    }
end }

M.setLicense = { perm = 'licenses', fn = function(src, d)
    local ok, msg = P.SetLicense(src, tostring(d.citizenid or ''), d.license, d.state == true)
    return { ok = ok, message = msg }
end }

-- ---------------------------------------------------------------------
-- Véhicules
-- ---------------------------------------------------------------------
M.searchVehicles = { perm = 'mdt', fn = function(_, d)
    local like, raw = Like(d.q)
    if #raw < 2 then return { list = {} } end
    local rows = MySQL.query.await([[SELECT pv.plate, pv.vehicle, pv.citizenid, p.charinfo FROM player_vehicles pv
        LEFT JOIN players p ON p.citizenid = pv.citizenid WHERE LOWER(pv.plate) LIKE ? LIMIT 30]], { like }) or {}
    local list = {}
    for _, r in ipairs(rows) do
        list[#list + 1] = { plate = r.plate, model = r.vehicle, citizenid = r.citizenid, owner = r.charinfo and P.CharName(r.charinfo) or '?' }
    end
    return { list = list }
end }

-- ---------------------------------------------------------------------
-- Rapports
-- ---------------------------------------------------------------------
M.saveRecord = { perm = 'records_write', fn = function(src, d)
    local cid = tostring(d.citizenid or '')
    local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { cid })
    if not row then return { error = 'Citoyen introuvable.' } end
    local title = tostring(d.title or ''):sub(1, 150)
    local content = tostring(d.content or ''):sub(1, 8000)
    if title == '' or content == '' then return { error = 'Titre et contenu obligatoires.' } end
    local charges, fine, jail = {}, 0, 0
    for _, id in ipairs(type(d.charges) == 'table' and d.charges or {}) do
        for _, f in ipairs(P.Settings.fines) do
            if f.id == id then
                charges[#charges + 1] = f.label
                fine = fine + (tonumber(f.amount) or 0)
                jail = jail + (tonumber(f.jail) or 0)
            end
        end
    end
    local p = P.GetPlayer(src)
    MySQL.insert.await('INSERT INTO police_records (citizenid, name, title, content, charges, fine, jail, officer, officer_cid) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { cid, P.CharName(row.charinfo), title, content, table.concat(charges, ', '), fine, jail, P.Name(src), p.PlayerData.citizenid })
    P.Log(src, 'Rapport', ('%s · %s'):format(P.CharName(row.charinfo), title))
    return { ok = true, message = 'Rapport enregistré.' }
end }

M.deleteRecord = { perm = 'records_delete', fn = function(src, d)
    MySQL.query.await('DELETE FROM police_records WHERE id = ?', { tonumber(d.id) })
    P.Log(src, 'Rapport supprimé', ('#%s'):format(tostring(d.id)))
    return { ok = true, message = 'Rapport supprimé.' }
end }

M.records = { perm = 'mdt', fn = function(_, d)
    local like = Like(d.q)
    return { list = MySQL.query.await([[SELECT id, citizenid, name, title, charges, officer, DATE_FORMAT(created_at, "%d/%m/%Y %H:%i") AS date
        FROM police_records WHERE LOWER(name) LIKE ? OR LOWER(title) LIKE ? OR LOWER(officer) LIKE ? ORDER BY id DESC LIMIT 60]], { like, like, like }) or {} }
end }

-- ---------------------------------------------------------------------
-- Avis de recherche
-- ---------------------------------------------------------------------
M.warrants = { perm = 'mdt', fn = function()
    return { list = MySQL.query.await('SELECT id, citizenid, name, reason, danger, officer, DATE_FORMAT(created_at, "%d/%m/%Y %H:%i") AS date FROM police_warrants WHERE active = 1 ORDER BY danger DESC, id DESC') or {} }
end }

M.createWarrant = { perm = 'warrants', fn = function(src, d)
    local name = tostring(d.name or ''):sub(1, 100)
    local cid = d.citizenid and tostring(d.citizenid) or nil
    if cid then
        local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { cid })
        if row then name = P.CharName(row.charinfo) else cid = nil end
    end
    local reason = tostring(d.reason or ''):sub(1, 2000)
    if name == '' or reason == '' then return { error = 'Nom et motif obligatoires.' } end
    local danger = math.max(1, math.min(3, tonumber(d.danger) or 1))
    MySQL.insert.await('INSERT INTO police_warrants (citizenid, name, reason, danger, officer) VALUES (?, ?, ?, ?, ?)',
        { cid, name, reason, danger, P.Name(src) })
    for _, c in ipairs(P.CopsOnDuty()) do
        P.Notify(c, ('Nouvel avis de recherche : %s'):format(name), danger == 3 and 'error' or 'warning')
    end
    P.Log(src, 'Avis de recherche', ('%s · %s'):format(name, reason))
    return { ok = true, message = 'Avis de recherche publié.' }
end }

M.closeWarrant = { perm = 'warrants', fn = function(src, d)
    MySQL.update.await('UPDATE police_warrants SET active = 0 WHERE id = ?', { tonumber(d.id) })
    P.Log(src, 'Avis de recherche levé', ('#%s'):format(tostring(d.id)))
    return { ok = true, message = 'Avis de recherche levé.' }
end }

-- ---------------------------------------------------------------------
-- Prison
-- ---------------------------------------------------------------------
M.jailed = { perm = 'mdt', fn = function()
    return { list = MySQL.query.await('SELECT citizenid, name, remaining, reason, officer FROM police_jail ORDER BY remaining DESC') or {} }
end }

M.release = { perm = 'jail', fn = function(src, d)
    P.ReleaseCid(tostring(d.citizenid or ''), P.Name(src))
    P.Log(src, 'Libération', tostring(d.citizenid))
    return { ok = true, message = 'Prisonnier libéré.' }
end }

-- ---------------------------------------------------------------------
-- Appels
-- ---------------------------------------------------------------------
M.calls = { perm = 'dispatch', fn = function() return { list = P.CallList() } end }

-- ---------------------------------------------------------------------
-- Point d'entrée
-- ---------------------------------------------------------------------
RegisterNetEvent('police:server:mdt', function(reqId, action, data)
    local src = source
    local a = M[action] or (PoliceMdtActions or {})[action]   -- + actions des modules PPA et scientifique
    local result
    if not a then
        result = { error = 'Action inconnue.' }
    elseif not P.IsCop(src) then
        result = { error = "Vous n'êtes pas policier." }
    elseif tostring(action):sub(1, 3) == 'sci' and not (Forensics and Forensics.ready) then
        result = { error = 'Police scientifique indisponible : la base de données n\'est pas prête (voir la console du serveur).' }
    elseif not P.Can(src, a.perm, a.offDuty) then
        result = { error = P.OnDuty(src) and "Votre grade ne permet pas cette action." or 'Prenez votre service pour utiliser cette fonction.' }
    else
        local ok, res = pcall(a.fn, src, type(data) == 'table' and data or {})
        if ok then result = res or {} else
            print('^1[Police] Erreur MDT « ' .. tostring(action) .. ' » : ' .. tostring(res) .. '^0')
            result = { error = 'Erreur serveur.' }
        end
    end
    TriggerClientEvent('police:client:mdtResponse', src, reqId, result)
end)
