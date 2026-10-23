-- =====================================================================
--  ELYZEA PRESSE - serveur : objets du métier (elyzea_inventory) et cartes de presse
--  · Micro, caméra, appareil photo, bloc-notes : « Utiliser » = le sortir / le ranger
--    (micro et caméras tenus en main), viseur et prise de vue, notes d'interview.
--    Réservés aux journalistes en service ayant la permission : vérifié ici.
--  · Matériel de service : pris gratuitement au point « Matériel », un de chaque,
--    marqué « service » ; il se rend au même point.
--  · Carte de presse : délivrée par la direction, nominative ; « Utiliser » la montre aux
--    personnes proches avec sa validité vérifiée par le serveur (fiche d'employé + registre).
-- =====================================================================
local P = Presse
local core = exports.elyzea_core
local IT = Config.Items
local INV = 'elyzea_inventory'
local function inv() return exports[INV] end

-- ---------------------------------------------------------------------
-- Objets utilisables
-- ---------------------------------------------------------------------
local USE = {
    [IT.mic] = { kind = 'mic', perm = 'interview' },
    [IT.camera] = { kind = 'camera', perm = 'media' },
    [IT.photo] = { kind = 'photo', perm = 'media' },
    [IT.notes] = { kind = 'notes', perm = 'interview' },
}

local function OnUse(src, item)
    local u = USE[item.name]
    if not u then return false end
    if not P.IsPresse(src) or not P.OnDuty(src) then P.Notify(src, 'Matériel réservé aux journalistes en service.', 'error') return false end
    if not P.Can(src, u.perm) then P.Notify(src, 'Votre grade ne permet pas d\'utiliser ce matériel.', 'error') return false end
    TriggerClientEvent('presse:client:use', src, u.kind)
    return false   -- jamais consommé
end

-- Carte de presse : registre + fiche d'employé = validité
local function CardStatus(md)
    if type(md) ~= 'table' or not md.number then return { valid = false, why = 'Carte illisible.' } end
    local row = MySQL.single.await('SELECT * FROM `presse_cards` WHERE `number` = ?', { tostring(md.number) })
    if not row then return { valid = false, why = 'Carte inconnue du registre de la presse.' } end
    if row.revoked_at then return { valid = false, why = 'Carte révoquée' .. (row.revoke_reason and (' : ' .. row.revoke_reason) or '') .. '.' } end
    local e = P.employees[row.citizenid]
    if not e or e.job ~= row.job then return { valid = false, why = 'Le titulaire ne fait plus partie de la rédaction.' } end
    local g = P.grades[e.grade_id]
    return { valid = true, grade = g and g.name or nil, row = row }
end

local function OnCard(src, item)
    local md = item.metadata or {}
    local st = CardStatus(md)
    local holderCid = P.Cid(src)
    local card = { number = md.number, name = md.name, matricule = md.matricule, agency = md.agency, issued = md.issued,
        grade = st.grade, valid = st.valid, why = st.why, bearerMismatch = md.cid ~= holderCid, shownBy = P.Name(src) }
    local list = { src }
    local c = P.Coords(src)
    if c then
        for id in pairs(core:GetPlayers()) do
            if id ~= src then
                local tc = P.Coords(id)
                if tc and #(tc - c) <= 3.0 then list[#list + 1] = id end
            end
        end
    end
    for _, id in ipairs(list) do TriggerClientEvent('presse:client:card', id, card, id == src) end
    if #list == 1 then P.Notify(src, 'Personne à côté de vous : vous regardez votre carte.', 'inform') end
    return false
end

local function RegisterUsables()
    if GetResourceState(INV) ~= 'started' then return end
    for name in pairs(USE) do pcall(function() inv():RegisterUsableItem(name, OnUse) end) end
    pcall(function() inv():RegisterUsableItem(IT.card, OnCard) end)
end
AddEventHandler('elyzea_inventory:ready', RegisterUsables)
AddEventHandler('onResourceStart', function(res) if res == INV then SetTimeout(1500, RegisterUsables) end end)
P.OnReady = P.OnReady or {}
P.OnReady[#P.OnReady + 1] = RegisterUsables

-- ---------------------------------------------------------------------
-- Matériel de service (point « Matériel »)
-- ---------------------------------------------------------------------
local function GearDefs()
    local out = {}
    for _, g in ipairs(Config.Gear) do
        local def
        pcall(function() def = inv():Items(g.item) end)
        out[#out + 1] = { item = g.item, minLevel = g.minLevel or 1, label = def and def.label or g.item, exists = def ~= nil }
    end
    return out
end
local function GearDef(name) for _, g in ipairs(GearDefs()) do if g.item == name then return g end end end

P.Actions.gearList = { perm = 'gear', duty = true, fn = function(src)
    if not P.NearPoint(src, 'gear', 3.0) then return { error = 'Vous n\'êtes pas au point matériel de la rédaction.' } end
    local lvl = P.Grade(src).level
    local list = {}
    for _, g in ipairs(GearDefs()) do
        local n = 0
        pcall(function() n = inv():GetItemCount(src, g.item) or 0 end)
        local service = 0
        pcall(function() service = inv():GetItemCount(src, g.item, { service = true }) or 0 end)
        list[#list + 1] = { item = g.item, label = g.label, exists = g.exists, locked = lvl < g.minLevel, minLevel = g.minLevel, has = n > 0, service = service > 0 }
    end
    return { list = list }
end }

P.Actions.gearTake = { perm = 'gear', duty = true, fn = function(src, d)
    if not P.NearPoint(src, 'gear', 3.0) then return { error = 'Vous n\'êtes pas au point matériel.' } end
    local g = GearDef(tostring(d.item or ''))
    if not g or not g.exists then return { error = 'Matériel inconnu.' } end
    if P.Grade(src).level < g.minLevel then return { error = 'Votre grade ne permet pas de prendre ce matériel.' } end
    local n = 0
    pcall(function() n = inv():GetItemCount(src, g.item) or 0 end)
    if n > 0 then return { error = 'Vous en avez déjà un.' } end
    local md = { service = true, job = P.MyJob(src), label = g.label .. ' (service)', description = ('Matériel de service · %s · à rendre au point matériel'):format(P.AgencyLabel(P.MyJob(src))) }
    if not inv():CanCarryItem(src, g.item, 1, md) then return { error = 'Inventaire plein ou trop lourd.' } end
    if not inv():AddItem(src, g.item, 1, md) then return { error = 'Impossible de vous donner ce matériel.' } end
    P.Log(src, 'Matériel pris', g.label)
    return { ok = true, message = ('%s pris.'):format(g.label) }
end }

P.Actions.gearReturn = { perm = 'gear', fn = function(src, d)
    if not P.NearPoint(src, 'gear', 3.0) then return { error = 'Rendez le matériel au point matériel.' } end
    local g = GearDef(tostring(d.item or ''))
    if not g then return { error = 'Matériel inconnu.' } end
    if not inv():RemoveItem(src, g.item, 1, { service = true }) then return { error = 'Vous n\'avez pas ce matériel de service sur vous.' } end
    TriggerClientEvent('presse:client:stopHold', src)
    return { ok = true, message = ('%s rendu.'):format(g.label) }
end }

-- ---------------------------------------------------------------------
-- Cartes de presse (permission « cards_manage »)
-- ---------------------------------------------------------------------
local function NextNumber(job)
    local a = P.Agency(job)
    local prefix = (a and a.short or 'PRESSE'):upper():gsub('[^%w]', ''):sub(1, 6)
    local n = (MySQL.scalar.await('SELECT COUNT(*) FROM `presse_cards`') or 0) + 1
    local num
    repeat
        num = ('%s-%s-%04d'):format(prefix, os.date('%y'), n)
        n = n + 1
    until not MySQL.scalar.await('SELECT `id` FROM `presse_cards` WHERE `number` = ?', { num })
    return num
end

local function Revoke(cid, reason, job)
    return MySQL.update.await('UPDATE `presse_cards` SET `revoked_at` = NOW(), `revoke_reason` = ? WHERE `citizenid` = ? AND `revoked_at` IS NULL' .. (job and ' AND `job` = ?' or ''),
        job and { reason, cid, job } or { reason, cid }) or 0
end

P.Actions.cards = { perm = 'cards_manage', fn = function(src)
    local job = P.MyJob(src)
    local list = MySQL.query.await([[SELECT `number`, `citizenid`, `name`, `matricule`, `issued_by`, `revoke_reason`, UNIX_TIMESTAMP(`issued_at`) AS t, UNIX_TIMESTAMP(`revoked_at`) AS r
        FROM `presse_cards` WHERE `job` = ? ORDER BY `id` DESC LIMIT 150]], { job }) or {}
    local emps = {}
    for cid, e in pairs(P.employees) do
        if e.job == job then emps[#emps + 1] = { cid = cid, name = e.name, matricule = e.matricule, online = core:GetSourceByCitizenId(cid) ~= nil } end
    end
    table.sort(emps, function(a, b) return a.name < b.name end)
    return { list = list, employees = emps }
end }

P.Actions.cardIssue = { perm = 'cards_manage', fn = function(src, d)
    local cid = tostring(d.cid or '')
    local e = P.employees[cid]
    local job = P.MyJob(src)
    if not e or e.job ~= job then return { error = 'Employé introuvable.' } end
    local t = core:GetSourceByCitizenId(cid)
    if not t then return { error = 'L\'employé doit être connecté pour recevoir sa carte.' } end
    local number = NextNumber(job)
    local ag = P.AgencyLabel(job)
    local md = { number = number, cid = cid, name = e.name, matricule = e.matricule, agency = ag, job = job, issued = os.date('%d/%m/%Y'),
        label = ('Carte de presse · %s'):format(e.name), description = ('%s · %s · n° %s'):format(ag, e.matricule, number) }
    if not inv():CanCarryItem(t, IT.card, 1, md) then return { error = 'Inventaire de l\'employé plein.' } end
    local old = Revoke(cid, 'remplacée par ' .. number, job)
    MySQL.insert.await('INSERT INTO `presse_cards` (`number`, `job`, `citizenid`, `name`, `matricule`, `issued_by`) VALUES (?, ?, ?, ?, ?, ?)',
        { number, job, cid, e.name, e.matricule, P.Name(src) })
    if not inv():AddItem(t, IT.card, 1, md) then
        MySQL.update.await("UPDATE `presse_cards` SET `revoked_at` = NOW(), `revoke_reason` = 'non remise (inventaire)' WHERE `number` = ?", { number })
        return { error = 'Carte non remise (inventaire).' }
    end
    P.AddLog(src, cid, e.name, 'Carte de presse délivrée', nil, nil, number)
    P.Notify(t, ('Carte de presse n° %s reçue.'):format(number), 'success')
    return { ok = true, message = ('Carte %s délivrée à %s.%s'):format(number, e.name, old > 0 and ' L\'ancienne carte est révoquée.' or '') }
end }

P.Actions.cardRevoke = { perm = 'cards_manage', fn = function(src, d)
    local number = tostring(d.number or ''):sub(1, 24)
    local reason = P.Clean(d.reason, 120)
    if #reason < 3 then return { error = 'Indiquez le motif.' } end
    local n = MySQL.update.await('UPDATE `presse_cards` SET `revoked_at` = NOW(), `revoke_reason` = ? WHERE `number` = ? AND `job` = ? AND `revoked_at` IS NULL',
        { reason, number, P.MyJob(src) })
    if not n or n < 1 then return { error = 'Carte introuvable ou déjà révoquée.' } end
    P.AddLog(src, nil, nil, 'Carte de presse révoquée', nil, nil, ('%s · %s'):format(number, reason))
    return { ok = true, message = ('Carte %s révoquée : elle s\'affiche « invalide » partout.'):format(number) }
end }

-- Départ de la rédaction : ses cartes deviennent invalides (le registre le dit à chaque présentation)
local remove = P.Remove
P.Remove = function(cid, ...)
    local e = P.employees[cid]
    local r = remove(cid, ...)
    if r and e then Revoke(cid, 'départ de la rédaction', e.job) end
    return r
end
