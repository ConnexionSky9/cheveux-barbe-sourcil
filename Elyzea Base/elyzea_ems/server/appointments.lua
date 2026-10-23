-- =====================================================================
--  ELYZEA EMS - serveur : rendez-vous
--  · Le joueur demande un rendez-vous dans l'application Santé d'Elyzea Aura
--    (consultation médicale, psychiatrique, prise de sang, suivi de grossesse).
--  · Les EMS en service le voient dans l'application « Rendez-vous » du
--    téléphone de service et l'acceptent ; le joueur est prévenu :
--    « L'EMS Prénom a accepté votre rendez-vous ».
--  · Non accepté au bout du délai : annulé, le joueur est prévenu.
--  · Joueur absent au moment de la réponse : prévenu à sa prochaine connexion.
-- =====================================================================
local P = Ems
local HR = HealthRules
local core = exports.elyzea_core
local KEY = 'appointments'

P.Tables.ems_appointments = [[ (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `phone` VARCHAR(20) NULL,
    `type` VARCHAR(20) NOT NULL,
    `reason` VARCHAR(200) NULL,
    `status` VARCHAR(12) NOT NULL DEFAULT 'pending',
    `ems_cid` VARCHAR(50) NULL,
    `ems_name` VARCHAR(100) NULL,
    `created_at` INT UNSIGNED NOT NULL,
    `accepted_at` INT UNSIGNED NULL,
    `closed_at` INT UNSIGNED NULL,
    `notice` VARCHAR(255) NULL,
    INDEX (`citizenid`), INDEX (`status`) ) ]]
P.TableOrder[#P.TableOrder + 1] = 'ems_appointments'

-- Réglages : config + ce que le staff a changé (admin_menu › Santé)
function P.ApptSettings()
    local base, s = Config.Appointments, P.GetSetting(KEY, {})
    local out = {
        enabled = (s.enabled == nil and base.enabled ~= false) or s.enabled == true,
        expireMinutes = math.floor(HR.Num(s.expireMinutes or base.expireMinutes, 5, 10080, 120)),
        acceptedHours = math.floor(HR.Num(s.acceptedHours or base.acceptedHours, 1, 720, 24)),
        maxOpen = math.floor(HR.Num(s.maxOpen or base.maxOpen, 1, 10, 2)),
        cooldown = math.floor(HR.Num(base.cooldown, 0, 3600, 60)),
        keepDays = math.floor(HR.Num(base.keepDays, 1, 365, 30)),
        types = {},
    }
    local off = type(s.typesOff) == 'table' and s.typesOff or {}
    for _, t in ipairs(base.types or {}) do
        out.types[#out.types + 1] = { id = t.id, label = t.label, icon = t.icon, enabled = off[t.id] ~= true }
    end
    return out
end
function P.ApptSaveSettings(d)
    d = type(d) == 'table' and d or {}
    local s = {
        enabled = d.enabled ~= false,
        expireMinutes = math.floor(HR.Num(d.expireMinutes, 5, 10080, 120)),
        acceptedHours = math.floor(HR.Num(d.acceptedHours, 1, 720, 24)),
        maxOpen = math.floor(HR.Num(d.maxOpen, 1, 10, 2)),
        typesOff = {},
    }
    for _, t in ipairs(Config.Appointments.types or {}) do
        if type(d.typesOff) == 'table' and d.typesOff[t.id] == true then s.typesOff[t.id] = true end
    end
    P.SetSetting(KEY, s)
end

local function TypeLabel(id) local t = HR.ApptType(Config.Appointments, id) return t and t.label or id end

local function View(r)
    return { id = r.id, type = r.type, typeLabel = TypeLabel(r.type), reason = r.reason, status = r.status, statusLabel = HR.APPT_STATUS[r.status] or r.status,
        created = tonumber(r.created_at), accepted = tonumber(r.accepted_at), closed = tonumber(r.closed_at), ems = r.ems_name, name = r.name, phone = r.phone }
end

-- Prévient le joueur (téléphone Elyzea Aura + notification du jeu)
local function Tell(src, text)
    if GetResourceState('elyzea_aura') == 'started' then
        pcall(function() exports.elyzea_aura:SendNotification(src, 'Santé', text, 'sante') end)
    end
    P.Notify(src, text, 'inform')
end
-- Message gardé si le joueur est absent : remis à sa prochaine connexion
local function Inform(r, text)
    local s = core:GetSourceByCitizenId(r.citizenid)
    if s then
        Tell(s, text)
        MySQL.update('UPDATE `ems_appointments` SET `notice` = NULL WHERE `id` = ?', { r.id })
    else
        MySQL.update('UPDATE `ems_appointments` SET `notice` = ? WHERE `id` = ?', { text:sub(1, 255), r.id })
    end
end

-- Téléphones de service EMS ouverts : liste à rafraîchir
local function PushPhones() TriggerEvent('elyzea_jobphone:pushRes', GetCurrentResourceName(), 'rdv') end

-- ---------------------------------------------------------------------
-- Côté patient (appelé par Elyzea Aura, application Santé)
-- ---------------------------------------------------------------------
local lastAsk = {}
function P.ApptCreate(src, d)
    local cfg = P.ApptSettings()
    if not cfg.enabled then return { error = 'Les rendez-vous sont fermés pour le moment.' } end
    local cid = P.Cid(src)
    if not cid then return { error = 'Personnage non chargé.' } end
    d = type(d) == 'table' and d or {}
    local t
    for _, x in ipairs(cfg.types) do if x.id == d.type and x.enabled then t = x end end
    if not t then return { error = 'Type de rendez-vous indisponible.' } end
    local now = os.time()
    if lastAsk[cid] and now - lastAsk[cid] < cfg.cooldown then return { error = 'Patientez un peu avant une nouvelle demande.' } end
    local open = tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM `ems_appointments` WHERE `citizenid` = ? AND `status` IN ('pending', 'accepted')", { cid })) or 0
    if open >= cfg.maxOpen then return { error = ('Vous avez déjà %d demande(s) en cours.'):format(open) } end
    local reason = HR.Clean(d.reason, 200)
    local phone
    if GetResourceState('elyzea_aura') == 'started' then pcall(function() phone = exports.elyzea_aura:GetPhoneNumber(src) end) end
    local id = MySQL.insert.await([[INSERT INTO `ems_appointments` (`citizenid`, `name`, `phone`, `type`, `reason`, `status`, `created_at`) VALUES (?, ?, ?, ?, ?, 'pending', ?)]],
        { cid, P.Name(src), phone and tostring(phone):sub(1, 20) or nil, t.id, reason ~= '' and reason or nil, now })
    if not id then return { error = 'Demande impossible, réessayez.' } end
    lastAsk[cid] = now
    -- EMS en service : petite alerte
    for _, e in ipairs(P.CrewOnDuty and P.CrewOnDuty() or {}) do
        local es = type(e) == 'table' and (e.src or e.id) or e
        if tonumber(es) then P.Notify(tonumber(es), ('📅 Nouvelle demande de rendez-vous : %s.'):format(t.label), 'inform') end
    end
    PushPhones()
    return { ok = true, id = id, message = ('Demande envoyée : %s. Vous serez prévenu dès qu\'un EMS l\'accepte.'):format(t.label) }
end

function P.ApptCancel(src, id)
    local cid = P.Cid(src)
    local r = cid and MySQL.single.await('SELECT * FROM `ems_appointments` WHERE `id` = ? AND `citizenid` = ?', { tonumber(id) or 0, cid })
    if not r then return { error = 'Rendez-vous introuvable.' } end
    if r.status ~= 'pending' and r.status ~= 'accepted' then return { error = 'Ce rendez-vous est déjà clos.' } end
    MySQL.update.await("UPDATE `ems_appointments` SET `status` = 'cancelled', `closed_at` = ? WHERE `id` = ?", { os.time(), r.id })
    if r.status == 'accepted' and r.ems_cid then
        local es = core:GetSourceByCitizenId(r.ems_cid)
        if es then P.Notify(es, ('Rendez-vous #%d annulé par %s.'):format(r.id, r.name), 'inform') end
    end
    PushPhones()
    return { ok = true, message = 'Rendez-vous annulé.' }
end

function P.ApptMine(src)
    local cid = P.Cid(src)
    if not cid then return { error = 'Personnage non chargé.' } end
    local list = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `ems_appointments` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 30', { cid }) or {}) do list[#list + 1] = View(r) end
    local cfg = P.ApptSettings()
    local types = {}
    for _, t in ipairs(cfg.types) do if t.enabled then types[#types + 1] = { id = t.id, label = t.label, icon = t.icon } end end
    return { ok = true, enabled = cfg.enabled, types = types, list = list, expireMinutes = cfg.expireMinutes, maxOpen = cfg.maxOpen }
end

-- Historique pour le dossier médical (poste des dossiers)
function P.ApptHistory(cid)
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `ems_appointments` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 20', { cid }) or {}) do out[#out + 1] = View(r) end
    return out
end

-- ---------------------------------------------------------------------
-- Côté EMS (téléphone de service › Rendez-vous)
-- ---------------------------------------------------------------------
P.Actions.apptList = { perm = 'medical', duty = true, fn = function(src)
    local cid = P.Cid(src)
    local pending, mine, others = {}, {}, {}
    for _, r in ipairs(MySQL.query.await("SELECT * FROM `ems_appointments` WHERE `status` IN ('pending', 'accepted') ORDER BY `created_at` ASC LIMIT 100") or {}) do
        local v = View(r)
        v.online = core:GetSourceByCitizenId(r.citizenid) ~= nil
        if r.status == 'pending' then
            v.expiresIn = math.max(0, r.created_at + P.ApptSettings().expireMinutes * 60 - os.time())
            pending[#pending + 1] = v
        elseif r.ems_cid == cid then mine[#mine + 1] = v
        else others[#others + 1] = v end
    end
    return { ok = true, pending = pending, mine = mine, others = others }
end }

P.Actions.apptAccept = { perm = 'medical', duty = true, fn = function(src, d)
    local id = tonumber(d.id) or 0
    local now = os.time()
    -- Une seule acceptation possible (la mise à jour ne passe que si la demande est encore en attente)
    local n = MySQL.update.await("UPDATE `ems_appointments` SET `status` = 'accepted', `ems_cid` = ?, `ems_name` = ?, `accepted_at` = ? WHERE `id` = ? AND `status` = 'pending'",
        { P.Cid(src), P.Name(src), now, id })
    if n ~= 1 then return { error = 'Ce rendez-vous a déjà été pris ou annulé.' } end
    local r = MySQL.single.await('SELECT * FROM `ems_appointments` WHERE `id` = ?', { id })
    if r then
        Inform(r, ("L'EMS %s a accepté votre rendez-vous (%s)."):format(HR.FirstName(P.Name(src)), TypeLabel(r.type)))
        P.Log(src, 'Rendez-vous accepté', ('#%d %s · %s'):format(id, r.name, TypeLabel(r.type)))
    end
    PushPhones()
    return { ok = true, message = ('Rendez-vous accepté : %s.'):format(r and r.name or ('#' .. id)), phone = r and r.phone }
end }

P.Actions.apptDone = { perm = 'medical', duty = true, fn = function(src, d)
    local id = tonumber(d.id) or 0
    local n = MySQL.update.await("UPDATE `ems_appointments` SET `status` = 'done', `closed_at` = ? WHERE `id` = ? AND `status` = 'accepted'", { os.time(), id })
    if n ~= 1 then return { error = 'Rendez-vous introuvable.' } end
    PushPhones()
    return { ok = true, message = 'Rendez-vous terminé.' }
end }

-- ---------------------------------------------------------------------
-- Expiration automatique, messages en attente
-- ---------------------------------------------------------------------
CreateThread(function()
    while not P.ready do Wait(1000) end
    while true do
        local ok, err = pcall(function()
            local now, cfg = os.time(), P.ApptSettings()
            local changed = false
            for _, r in ipairs(MySQL.query.await("SELECT * FROM `ems_appointments` WHERE `status` IN ('pending', 'accepted')") or {}) do
                local nxt = HR.ApptNext({ status = r.status, created = tonumber(r.created_at), accepted = tonumber(r.accepted_at) }, now, cfg)
                if nxt then
                    local n = MySQL.update.await('UPDATE `ems_appointments` SET `status` = ?, `closed_at` = ? WHERE `id` = ? AND `status` = ?', { nxt, now, r.id, r.status })
                    if n == 1 then
                        changed = true
                        if nxt == 'expired' then
                            Inform(r, ('Votre demande de rendez-vous (%s) n\'a été prise par aucun EMS : elle est annulée. Vous pouvez en refaire une.'):format(TypeLabel(r.type)))
                        end
                    end
                end
            end
            if changed then PushPhones() end
            MySQL.query('DELETE FROM `ems_appointments` WHERE `status` NOT IN (\'pending\', \'accepted\') AND `closed_at` < ?', { now - cfg.keepDays * 86400 })
        end)
        if not ok then print(('^1[EMS] Rendez-vous : %s^0'):format(tostring(err))) end
        Wait(60000)
    end
end)

-- Messages gardés pendant l'absence du joueur
AddEventHandler('elyzea:server:playerLoaded', function(src)
    SetTimeout(8000, function()
        local cid = P.Cid(src)
        if not cid then return end
        for _, r in ipairs(MySQL.query.await('SELECT `id`, `notice` FROM `ems_appointments` WHERE `citizenid` = ? AND `notice` IS NOT NULL', { cid }) or {}) do
            Tell(src, r.notice)
            MySQL.update('UPDATE `ems_appointments` SET `notice` = NULL WHERE `id` = ?', { r.id })
        end
    end)
end)

-- ---------------------------------------------------------------------
-- Exports (Elyzea Aura, admin_menu)
-- ---------------------------------------------------------------------
exports('AppointmentsMine', function(src) return P.ApptMine(tonumber(src)) end)
exports('AppointmentCreate', function(src, d) return P.ApptCreate(tonumber(src), d) end)
exports('AppointmentCancel', function(src, id) return P.ApptCancel(tonumber(src), id) end)
