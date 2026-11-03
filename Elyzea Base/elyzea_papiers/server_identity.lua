-- =====================================================================
--  elyzea_papiers - IDENTITÉ : documents d'un joueur et suspensions
--  · GetIdentityDocs(src)            → carte d'identité, permis, PPA (+ états « suspendu »)
--  · CanSuspend(src)                 → policier en service ?
--  · SetSuspension(officer, target, what, on, reason)
--        what = 'car' | 'moto' | 'truck' | 'licence' (tout le permis) | 'ppa'
--  · IsSuspended(cid, what)
--  Les suspensions sont en base (table elyzea_doc_suspensions) : elles restent
--  après une déconnexion ou un redémarrage. Le permis concerné est aussi retiré
--  du personnage (metadata.licences) tant qu'il est suspendu.
-- =====================================================================
Ident = {}
local core = exports.elyzea_core
local inv = exports.elyzea_inventory
local I = Config.Identity
local KINDS = { car = true, moto = true, truck = true, ppa = true }
local function Notify(src, msg, kind) pcall(function() core:Notify(src, msg, kind or 'inform') end) end
local function Log(src, action, details)
    if GetResourceState('admin_menu') ~= 'started' then return end
    pcall(function() exports.admin_menu:AddLog(src, '[Identité] ' .. action, details) end)
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_doc_suspensions` (
        `citizenid` VARCHAR(64) NOT NULL,
        `kind` VARCHAR(10) NOT NULL,
        `reason` VARCHAR(160) NULL DEFAULT NULL,
        `officer_name` VARCHAR(80) NULL DEFAULT NULL,
        `officer_cid` VARCHAR(64) NULL DEFAULT NULL,
        `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`, `kind`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end)

function Ident.suspensions(cid)
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT `kind`, `reason`, `officer_name` FROM `elyzea_doc_suspensions` WHERE `citizenid` = ?', { cid }) or {}) do
        out[r.kind] = { reason = r.reason, by = r.officer_name }
    end
    return out
end
exports('IsSuspended', function(cid, what) return Ident.suspensions(cid)[what] ~= nil end)

local function slotsOf(src, item)
    local ok, list = pcall(function() return inv:Search(src, 'slots', item) end)
    return ok and type(list) == 'table' and list or {}
end
-- Document le plus récent au nom du joueur
local function ownItem(src, item, cid)
    local best
    for _, sl in ipairs(slotsOf(src, item)) do
        local m = sl.metadata
        if type(m) == 'table' and m.number and (not m.citizenid or m.citizenid == cid) then best = m end
    end
    return best
end

function Ident.docs(src)
    local p = core:GetPlayer(src)
    if not p then return nil end
    local cid, ci, md = p.PlayerData.citizenid, p.PlayerData.charinfo or {}, p.PlayerData.metadata or {}
    local susp = Ident.suspensions(cid)
    local base = { firstname = ci.firstname, lastname = ci.lastname, birthdate = ci.birthdate, gender = tonumber(ci.gender) or 0,
        nationality = ci.nationality or Config.IdCard.nationality, citizenid = cid }
    local docs = {}

    -- Carte d'identité : objet au nom du joueur, sinon le numéro enregistré dans le personnage
    local idm = ownItem(src, Config.Items.id, cid)
    if idm or md.idcard then
        local d = {}
        for k, v in pairs(base) do d[k] = v end
        d.number = idm and idm.number or md.idcard
        d.issued = idm and idm.issued or nil
        docs.id = { type = 'id', data = d }
    end

    -- Permis de conduire (elyzea_permis)
    if GetResourceState('elyzea_permis') == 'started' then
        local ok, l = pcall(function() return exports.elyzea_permis:GetLicenses(cid) end)
        if ok and type(l) == 'table' and type(l.licenses) == 'table' and next(l.licenses) then
            local d = {}
            for k, v in pairs(base) do d[k] = v end
            d.number = l.number
            d.categories = {}
            for _, c in ipairs(I.licence) do
                if l.licenses[c.key] then
                    d.categories[#d.categories + 1] = { key = c.key, short = c.short, label = c.label, date = l.licenses[c.key],
                        suspended = susp[c.key] ~= nil, reason = susp[c.key] and susp[c.key].reason or nil }
                end
            end
            docs.licence = { type = 'licence', data = d }
        end
    end

    -- PPA (civil ou forces de l'ordre) : objet au nom du joueur
    local pm = ownItem(src, Config.Items.ppa_fdo, cid) or ownItem(src, Config.Items.ppa, cid)
    if pm then
        local d = {}
        for k, v in pairs(pm) do d[k] = v end
        for k, v in pairs(base) do if d[k] == nil then d[k] = v end end
        docs.ppa = { type = 'ppa', sub = pm.kind == 'fdo' and 'fdo' or 'civil', data = d,
            suspended = susp.ppa ~= nil, suspendedReason = susp.ppa and susp.ppa.reason or nil }
    end
    return docs
end
exports('GetIdentityDocs', function(src) return Ident.docs(tonumber(src)) end)

function Ident.canSuspend(src)
    src = tonumber(src)
    if not src then return false end
    if GetResourceState('elyzea_police') == 'started' then
        local ok, cop = pcall(function() return exports.elyzea_police:IsPolice(src) end)
        local ok2, duty = pcall(function() return exports.elyzea_police:IsOnDuty(src) end)
        if ok and ok2 then return cop == true and duty == true end
    end
    local p = core:GetPlayer(src)
    local job = p and p.PlayerData.job
    if not job then return false end
    for _, j in ipairs(I.policeJobs) do
        if job.name == j then return job.onduty ~= false end
    end
    return false
end
exports('CanSuspend', function(src) return Ident.canSuspend(src) end)

-- Permis enregistrés dans le personnage (tablette de police, location de véhicules…)
local function setLicence(target, keys, value)
    local p = core:GetPlayer(target)
    if not p then return end
    local lic = p.PlayerData.metadata.licences or {}
    for _, k in ipairs(keys) do lic[k] = value end
    core:SetMetadata(target, 'licences', lic)
end

local LABEL = { car = 'permis voiture (B)', moto = 'permis moto (A)', truck = 'permis poids lourd (C)', licence = 'permis de conduire', ppa = 'permis de port d\'arme' }

-- Renvoie ok, message
function Ident.setSuspension(officer, target, what, on, reason)
    officer, target = tonumber(officer), tonumber(target)
    if not officer or not target or not GetPlayerName(target) then return false, 'Personne introuvable.' end
    if officer == target then return false, 'Tu ne peux pas modifier tes propres papiers.' end
    if not Ident.canSuspend(officer) then return false, 'Réservé à la police en service.' end
    if #(GetEntityCoords(GetPlayerPed(officer)) - GetEntityCoords(GetPlayerPed(target))) > I.suspendDistance then
        return false, 'La personne est trop loin.'
    end
    if what ~= 'licence' and not KINDS[what] then return false, 'Document inconnu.' end
    local p = core:GetPlayer(target)
    if not p then return false, 'Personne introuvable.' end
    local cid = p.PlayerData.citizenid
    local docs = Ident.docs(target) or {}
    -- On ne suspend que ce que la personne possède
    local kinds = {}
    if what == 'ppa' then
        if not docs.ppa then return false, 'Cette personne n\'a pas de PPA.' end
        kinds = { 'ppa' }
    else
        if not docs.licence then return false, 'Cette personne n\'a pas de permis de conduire.' end
        for _, c in ipairs(docs.licence.data.categories) do
            if what == 'licence' or c.key == what then kinds[#kinds + 1] = c.key end
        end
        if #kinds == 0 then return false, 'Cette personne n\'a pas ce permis.' end
    end
    reason = tostring(reason or ''):gsub('[%c]', ' '):sub(1, 160)
    local oname = core:GetCharName(officer)
    local ocid = core:GetCitizenId(officer)
    local licKeys = {}
    for _, k in ipairs(kinds) do
        if on then
            MySQL.insert.await([[INSERT INTO `elyzea_doc_suspensions` (`citizenid`, `kind`, `reason`, `officer_name`, `officer_cid`) VALUES (?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE `reason` = VALUES(`reason`), `officer_name` = VALUES(`officer_name`), `officer_cid` = VALUES(`officer_cid`), `created_at` = NOW()]],
                { cid, k, reason ~= '' and reason or nil, oname, ocid })
        else
            MySQL.update.await('DELETE FROM `elyzea_doc_suspensions` WHERE `citizenid` = ? AND `kind` = ?', { cid, k })
        end
        if k == 'ppa' then
            licKeys[#licKeys + 1] = Config.PPA.licence
            if docs.ppa.sub == 'fdo' then licKeys[#licKeys + 1] = 'weapon_fdo' end
        else
            for _, c in ipairs(I.licence) do if c.key == k then licKeys[#licKeys + 1] = c.license end end
        end
    end
    setLicence(target, licKeys, not on)
    local label = LABEL[what] or what
    if on then
        Notify(target, ('Votre %s a été suspendu par %s.%s'):format(label, oname, reason ~= '' and (' Motif : ' .. reason) or ''), 'error')
        Notify(officer, ('%s suspendu.'):format(label:gsub('^%l', string.upper)), 'success')
    else
        Notify(target, ('Votre %s a été rétabli par %s.'):format(label, oname), 'success')
        Notify(officer, ('%s rétabli.'):format(label:gsub('^%l', string.upper)), 'success')
    end
    Log(officer, on and 'Suspension' or 'Rétablissement', ('%s → %s [%d] (%s)%s'):format(label, core:GetCharName(target), target, cid, reason ~= '' and (' · ' .. reason) or ''))
    TriggerEvent('elyzea_papiers:suspensionChanged', cid, kinds, on)
    return true, on and 'Suspendu.' or 'Rétabli.'
end
exports('SetSuspension', function(officer, target, what, on, reason) return Ident.setSuspension(officer, target, what, on == true, reason) end)

-- État de suspension d'un document montré « en main » (papier de l'inventaire, permis) : pour afficher SUSPENDU
RegisterNetEvent('elyzea_papiers:docState', function(reqId, cid, licenceNumber)
    local src = source
    if type(reqId) ~= 'string' or #reqId > 40 then return end
    -- Anciens permis sans citizenid : retrouvé par le numéro du permis (table elyzea_permis)
    if (type(cid) ~= 'string' or cid == '') and type(licenceNumber) == 'string' and #licenceNumber <= 20 then
        local ok, r = pcall(MySQL.scalar.await, 'SELECT `citizenid` FROM `elyzea_permis` WHERE `number` = ? LIMIT 1', { licenceNumber })
        cid = ok and r or nil
    end
    if type(cid) ~= 'string' or cid == '' or #cid > 64 then return TriggerClientEvent('elyzea_papiers:docStateReply', src, reqId, {}) end
    local s = Ident.suspensions(cid)
    TriggerClientEvent('elyzea_papiers:docStateReply', src, reqId, {
        car = s.car ~= nil, moto = s.moto ~= nil, truck = s.truck ~= nil, ppa = s.ppa ~= nil,
        ppaReason = s.ppa and s.ppa.reason or nil,
    })
end)
