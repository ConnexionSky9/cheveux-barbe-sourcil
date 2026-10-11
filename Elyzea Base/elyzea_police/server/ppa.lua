-- =====================================================================
--  elyzea_police - serveur : procédure PPA depuis la tablette et retrait du PPA
--  Le test et la délivrance sont ceux d'elyzea_papiers (aucun système parallèle).
--  L'identité est vérifiée par nom + prénom (et date de naissance si homonymes) :
--  la proximité ne sert jamais à choisir la personne, seulement à valider qu'elle est là.
-- =====================================================================
local P = Police
local core = exports.elyzea_core
local PPA_DISTANCE = 5.0
local last = {}

CreateThread(function()
    Wait(1000)
    pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `police_ppa` (
            `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NOT NULL,
            `kind` VARCHAR(20) NOT NULL DEFAULT 'civil',
            `status` VARCHAR(20) NOT NULL,
            `officer` VARCHAR(100) NOT NULL, `officer_cid` VARCHAR(50) NULL,
            `details` VARCHAR(255) NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX (`citizenid`)) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    end)
end)

local function Papiers() return GetResourceState('elyzea_papiers') == 'started' end

local function Norm(s)
    s = tostring(s or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
    local map = { ['é'] = 'e', ['è'] = 'e', ['ê'] = 'e', ['ë'] = 'e', ['à'] = 'a', ['â'] = 'a', ['ä'] = 'a', ['î'] = 'i', ['ï'] = 'i',
        ['ô'] = 'o', ['ö'] = 'o', ['ù'] = 'u', ['û'] = 'u', ['ü'] = 'u', ['ç'] = 'c' }
    for k, v in pairs(map) do s = s:gsub(k, v) end
    return s
end

-- Joueurs connectés dont l'identité correspond exactement
local function FindByIdentity(first, last_, birth)
    local out = {}
    for src, p in pairs(core:GetPlayers()) do
        local ci = p.PlayerData.charinfo or {}
        if Norm(ci.firstname) == Norm(first) and Norm(ci.lastname) == Norm(last_) and (not birth or birth == '' or tostring(ci.birthdate or '') == birth) then
            out[#out + 1] = { src = src, cid = p.PlayerData.citizenid, name = ('%s %s'):format(ci.firstname or '', ci.lastname or ''), birth = ci.birthdate }
        end
    end
    return out
end

local STATUS = {
    requested = 'Demande envoyée', test = 'Test en cours', passed = 'Test réussi', failed = 'Test échoué',
    issued = 'PPA délivré', refused = 'Refusée / expirée', revoked = 'PPA retiré',
}

-- Met à jour le statut d'une procédure avec l'état réel côté elyzea_papiers
local function LiveStatus(row)
    if row.status ~= 'requested' and row.status ~= 'test' and row.status ~= 'passed' then return row.status end
    local src = core:GetSourceByCitizenId(row.citizenid)
    if not src or not Papiers() then return row.status end
    local ok, st = pcall(function() return exports.elyzea_papiers:PpaState(src) end)
    if not ok or type(st) ~= 'table' then return row.status end
    local new = row.status
    if st.state == 'offer' then new = 'requested'
    elseif st.state == 'test' then new = 'test'
    elseif st.state == 'passed' then new = 'passed'
    elseif st.state == 'failed' then new = 'failed'
    elseif st.state == 'none' and row.status == 'requested' and (os.time() - (tonumber(row.t) or os.time())) > 60 then new = 'refused' end
    if new ~= row.status then
        MySQL.update('UPDATE `police_ppa` SET `status` = ?, `details` = ? WHERE `id` = ?',
            { new, st.score and ('%d/%d'):format(st.score, st.total or 0) or row.details, row.id })
        row.status = new
        if st.score then row.details = ('%d/%d'):format(st.score, st.total or 0) end
    end
    return new
end

-- Actions de la tablette (enregistrées dans le MDT via PoliceMdtActions)
PoliceMdtActions = PoliceMdtActions or {}

PoliceMdtActions.ppaList = { perm = 'ppa', fn = function()
    local rows = MySQL.query.await([[SELECT `id`, `citizenid`, `name`, `kind`, `status`, `officer`, `details`, UNIX_TIMESTAMP(`created_at`) AS t
        FROM `police_ppa` ORDER BY `id` DESC LIMIT 30]]) or {}
    for _, r in ipairs(rows) do
        r.status = LiveStatus(r)
        r.statusLabel = STATUS[r.status] or r.status
        r.online = core:GetSourceByCitizenId(r.citizenid) ~= nil
    end
    return { list = rows, papiers = Papiers(), distance = PPA_DISTANCE }
end }

PoliceMdtActions.ppaStart = { perm = 'ppa', fn = function(src, d)
    if not Papiers() then return { error = 'Le système des papiers (elyzea_papiers) n\'est pas démarré.' } end
    local now = GetGameTimer()
    if last[src] and now - last[src] < 4000 then return { error = 'Patientez quelques secondes.' } end
    last[src] = now
    local first, lastName = tostring(d.firstname or ''), tostring(d.lastname or '')
    if #Norm(first) < 2 or #Norm(lastName) < 2 or #first > 40 or #lastName > 40 then return { error = 'Indiquez le nom et le prénom.' } end
    local birth = tostring(d.birthdate or ''):match('^%d%d%d%d%-%d%d%-%d%d$') or nil
    local kind = d.kind == 'fdo' and 'fdo' or 'civil'
    local found = FindByIdentity(first, lastName, birth)
    if #found == 0 then return { error = 'Aucune personne connectée ne porte cette identité.' } end
    if #found > 1 then return { error = 'Plusieurs personnes portent ce nom : précisez la date de naissance.', ambiguous = true } end
    local t = found[1]
    if t.src == src then return { error = 'Vous ne pouvez pas lancer votre propre PPA.' } end
    if P.Dist(src, t.src) > PPA_DISTANCE then return { error = ('%s doit être près de vous (moins de %d m).'):format(t.name, PPA_DISTANCE) } end
    local ok, ret, msg = pcall(function() return exports.elyzea_papiers:PpaRequest(src, t.src, kind) end)
    if not ok then return { error = 'Le système des papiers ne répond pas.' } end
    if not ret then return { error = msg or 'Procédure impossible.' } end
    MySQL.insert.await('INSERT INTO `police_ppa` (`citizenid`, `name`, `kind`, `status`, `officer`, `officer_cid`) VALUES (?, ?, ?, ?, ?, ?)',
        { t.cid, t.name, kind, 'requested', P.Name(src), P.Cid(src) })
    P.Log(src, 'PPA lancé', ('%s · %s'):format(t.name, kind))
    return { ok = true, message = ('Demande envoyée à %s : il doit accepter et passer le test.'):format(t.name) }
end }

PoliceMdtActions.ppaIssue = { perm = 'ppa', fn = function(src, d)
    if not Papiers() then return { error = 'Le système des papiers n\'est pas démarré.' } end
    local row = MySQL.single.await('SELECT `id`, `citizenid`, `name`, `status` FROM `police_ppa` WHERE `id` = ?', { tonumber(d.id) or 0 })
    if not row then return { error = 'Procédure introuvable.' } end
    local target = core:GetSourceByCitizenId(row.citizenid)
    if not target then return { error = ('%s n\'est pas connecté.'):format(row.name) } end
    local ok, ret, msg = pcall(function() return exports.elyzea_papiers:PpaIssue(src, target) end)
    if not ok then return { error = 'Le système des papiers ne répond pas.' } end
    if not ret then return { error = msg or 'Délivrance impossible.' } end
    MySQL.update.await('UPDATE `police_ppa` SET `status` = ?, `officer` = ?, `officer_cid` = ? WHERE `id` = ?', { 'issued', P.Name(src), P.Cid(src), row.id })
    P.Log(src, 'PPA délivré', row.name)
    return { ok = true, message = msg }
end }

-- Retrait du PPA (menu ALT) : permis désactivé et documents PPA retirés
RegisterNetEvent('police:server:ppaRevoke', function(target)
    local src = source
    target = tonumber(target)
    if not P.Can(src, 'ppa_revoke') then return P.Notify(src, 'Votre grade ne permet pas de retirer un PPA.', 'error') end
    if not target or not P.GetPlayer(target) or target == src then return end
    if P.Dist(src, target) > 4.0 then return P.Notify(src, 'La personne est trop loin.', 'error') end
    local p = P.GetPlayer(target)
    local lic = p.PlayerData.metadata.licences or {}
    if not lic.weapon and not lic.weapon_fdo then
        local hasItem = false
        if GetResourceState('elyzea_inventory') == 'started' then
            for _, item in ipairs({ 'ppa', 'ppa_fdo' }) do
                local ok, n = pcall(function() return exports.elyzea_inventory:Search(target, 'count', item) end)
                if ok and (tonumber(n) or 0) > 0 then hasItem = true end
            end
        end
        if not hasItem then return P.Notify(src, 'Cette personne n\'a pas de PPA.', 'error') end
    end
    P.SetLicense(src, p.PlayerData.citizenid, 'weapon', false)
    P.SetLicense(src, p.PlayerData.citizenid, 'weapon_fdo', false)
    local removed = 0
    if GetResourceState('elyzea_inventory') == 'started' then
        for _, item in ipairs({ 'ppa', 'ppa_fdo' }) do
            local ok, n = pcall(function() return exports.elyzea_inventory:Search(target, 'count', item) end)
            n = ok and tonumber(n) or 0
            if n > 0 and exports.elyzea_inventory:RemoveItem(target, item, n) then removed = removed + n end
        end
    end
    local ci = p.PlayerData.charinfo or {}
    local name = ('%s %s'):format(ci.firstname or '', ci.lastname or '')
    MySQL.insert('INSERT INTO `police_ppa` (`citizenid`, `name`, `kind`, `status`, `officer`, `officer_cid`, `details`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { p.PlayerData.citizenid, name, 'civil', 'revoked', P.Name(src), P.Cid(src), ('%d document(s) retiré(s)'):format(removed) })
    P.Notify(src, ('PPA de %s retiré.'):format(name), 'success')
    P.Notify(target, 'Votre permis de port d\'arme vous a été retiré par la police.', 'error')
    P.Log(src, 'PPA retiré', name)
end)

AddEventHandler('playerDropped', function() last[source] = nil end)
