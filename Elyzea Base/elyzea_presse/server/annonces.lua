-- =====================================================================
--  ELYZEA PRESSE - serveur : annonces commandées par les entreprises
--  · Commande (téléphone de service › « Annonce ») : une entreprise cliente choisit une
--    rédaction, écrit son texte (150 caractères), choisit fréquence et dates, voit le
--    récapitulatif et paie DEPUIS LE COMPTE DE SON ENTREPRISE (elyzea_core, droit bankAuth).
--    Nombre de diffusions et prix calculés ICI ; prix contractuel gardé dans la commande.
--  · Une commande = des diffusions (presse_ad_slots), chacune à une heure précise (heure du serveur).
--  · Planificateur : diffusion due → proposée aux journalistes en service de la rédaction
--    (téléphone › « Planning », commission) ; personne en service, ou délai dépassé → envoi automatique
--    (aucune commission). Trop en retard (serveur arrêté…) → annulée et remboursée.
--  · File d'attente UNIQUE pour tout le serveur : une seule annonce affichée à la fois ; la suivante
--    attend la fin de l'affichage. Reconstruite depuis la base au démarrage.
--  · Chaque changement d'état est une mise à jour conditionnelle (WHERE `status` = …) : deux
--    journalistes, deux clics ou un redémarrage ne peuvent jamais diffuser ou payer deux fois.
-- =====================================================================
local P = Presse
local core = exports.elyzea_core
local CFG = Config.Annonces

local FREQ = {}
for _, f in ipairs(CFG.frequencies) do FREQ[f.id] = f end
local FINAL = { sent = true, missed = true, cancelled = true }

-- ---------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------
P.Tables.presse_ad_orders = [[ (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `uid` VARCHAR(40) NOT NULL UNIQUE,
    `request_key` VARCHAR(64) NOT NULL UNIQUE,
    `job` VARCHAR(40) NOT NULL, `agency_label` VARCHAR(60) NULL,
    `client_key` VARCHAR(60) NOT NULL, `client_label` VARCHAR(80) NULL, `client_society` VARCHAR(60) NOT NULL,
    `client_cid` VARCHAR(50) NOT NULL, `client_name` VARCHAR(100) NULL,
    `text` VARCHAR(160) NOT NULL,
    `frequency` VARCHAR(4) NOT NULL,
    `start_date` VARCHAR(10) NOT NULL, `end_date` VARCHAR(10) NOT NULL,
    `unit_price` INT NOT NULL, `slots` INT NOT NULL, `total` INT NOT NULL,
    `refunded` INT NOT NULL DEFAULT 0,
    `status` VARCHAR(10) NOT NULL DEFAULT 'pending',
    `txid` VARCHAR(40) NULL, `note` VARCHAR(160) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX (`job`, `status`), INDEX (`client_key`) ) ]]
P.Tables.presse_ad_slots = [[ (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `order_id` INT NOT NULL,
    `job` VARCHAR(40) NOT NULL,
    `due_ts` INT NOT NULL,
    `status` VARCHAR(12) NOT NULL DEFAULT 'scheduled',
    `mode` VARCHAR(6) NULL,
    `sent_by_cid` VARCHAR(50) NULL, `sent_by_name` VARCHAR(100) NULL,
    `commission` INT NOT NULL DEFAULT 0, `commission_status` VARCHAR(8) NULL,
    `offered_ts` INT NULL, `queued_ts` INT NULL, `started_ts` INT NULL, `sent_ts` INT NULL,
    `attempts` INT NOT NULL DEFAULT 0, `last_error` VARCHAR(160) NULL,
    `refund_status` VARCHAR(8) NULL,
    UNIQUE KEY `order_due` (`order_id`, `due_ts`), INDEX `st_due` (`status`, `due_ts`), INDEX `job_st` (`job`, `status`) ) ]]
P.TableOrder[#P.TableOrder + 1] = 'presse_ad_orders'
P.TableOrder[#P.TableOrder + 1] = 'presse_ad_slots'

-- ---------------------------------------------------------------------
-- Texte : longueur en caractères VISIBLES (un emoji composé = 1), même règle que l'interface
-- (html/app.js · textLength). Les marques combinantes, sélecteurs de variante, modificateurs
-- de teinte, étiquettes et la partie après un « ZWJ » ne comptent pas ; deux indicateurs
-- régionaux (drapeau) comptent pour un. Renvoie nil si le texte n'est pas de l'UTF-8 valide.
-- ---------------------------------------------------------------------
local function Extend(cp)
    return (cp >= 0x0300 and cp <= 0x036F) or (cp >= 0x1AB0 and cp <= 0x1AFF) or (cp >= 0x1DC0 and cp <= 0x1DFF)
        or (cp >= 0x20D0 and cp <= 0x20FF) or (cp >= 0xFE00 and cp <= 0xFE0F) or (cp >= 0xFE20 and cp <= 0xFE2F)
        or (cp >= 0x1F3FB and cp <= 0x1F3FF) or (cp >= 0xE0020 and cp <= 0xE007F) or (cp >= 0xE0100 and cp <= 0xE01EF)
end
function P.TextLength(s)
    if type(s) ~= 'string' or not utf8.len(s) then return nil end
    local n, afterZwj, riOpen = 0, false, false
    for _, cp in utf8.codes(s) do
        if cp == 0x200D then afterZwj = true
        elseif Extend(cp) then -- rattaché au caractère précédent
        elseif afterZwj then afterZwj = false
        elseif cp >= 0x1F1E6 and cp <= 0x1F1FF then
            if riOpen then riOpen = false else riOpen = true n = n + 1 end
        else
            riOpen = false
            n = n + 1
        end
    end
    return n
end

-- Texte d'annonce : espaces, accents, caractères spéciaux et emojis gardés ; caractères de contrôle → espace
function P.CleanAdText(s)
    s = tostring(s or ''):gsub('[\0-\31\127]', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return s
end

-- ---------------------------------------------------------------------
-- Calendrier : heures de diffusion (heure du serveur) entre deux dates incluses
-- ---------------------------------------------------------------------
local function ParseDate(s)
    local y, m, d = tostring(s or ''):match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not y or m < 1 or m > 12 or d < 1 or d > 31 then return nil end
    local t = os.time({ year = y, month = m, day = d, hour = 12 })
    local back = os.date('*t', t)
    if back.year ~= y or back.month ~= m or back.day ~= d then return nil end   -- 31/02…
    return { year = y, month = m, day = d, noon = t }
end
P.ParseDate = ParseDate
local function DayKey(t) return os.date('%Y-%m-%d', t) end
local function FmtDate(s) local d = ParseDate(s) return d and os.date('%d/%m/%Y', d.noon) or s end

-- Renvoie la liste triée des heures (os.time) ou nil, message
function P.Schedule(freq, startS, endS, now)
    local f = FREQ[tostring(freq or '')]
    if not f then return nil, 'Fréquence inconnue.' end
    local a, b = ParseDate(startS), ParseDate(endS)
    if not a or not b then return nil, 'Dates invalides.' end
    now = now or os.time()
    if DayKey(a.noon) < DayKey(now) then return nil, 'La date de début est déjà passée.' end
    if DayKey(b.noon) < DayKey(a.noon) then return nil, 'La date de fin ne peut pas être avant la date de début.' end
    local list, seen = {}, {}
    local day = 0
    while true do
        local d = os.date('*t', os.time({ year = a.year, month = a.month, day = a.day + day, hour = 12 }))
        local key = ('%04d-%02d-%02d'):format(d.year, d.month, d.day)
        if key > DayKey(b.noon) then break end
        day = day + 1
        if day > CFG.maxDays then return nil, ('Une commande dure %d jours au maximum.'):format(CFG.maxDays) end
        local times = {}
        if f.daily then times[1] = { CFG.dailyHour, CFG.dailyMinute }
        else for h = 0, 23 do for m = 0, 59, f.minutes do times[#times + 1] = { h, m } end end end
        for _, hm in ipairs(times) do
            local ts = os.time({ year = d.year, month = d.month, day = d.day, hour = hm[1], min = hm[2], sec = 0 })
            -- Heure qui n'existe pas (changement d'heure) : normalisée par os.time ; jamais deux fois la même
            if ts >= now + CFG.minLeadSeconds and DayKey(ts) == key and not seen[ts] then
                seen[ts] = true
                list[#list + 1] = ts
            end
        end
    end
    if #list == 0 then return nil, 'Aucune diffusion possible sur cette période (heures déjà passées).' end
    if #list > CFG.maxSlots then return nil, ('Trop de diffusions (%d, maximum %d) : réduisez la période ou la fréquence.'):format(#list, CFG.maxSlots) end
    table.sort(list)
    return list
end

-- ---------------------------------------------------------------------
-- Réglages : globaux (admin_menu) et par rédaction (tablette)
-- ---------------------------------------------------------------------
function P.AnnSettings()
    local s = P.GetSetting('annonces', {})
    local out = {}
    for k, v in pairs(CFG.defaults) do
        if type(s) == 'table' and s[k] ~= nil then out[k] = s[k] else out[k] = v end
    end
    return out
end

function P.AdCfg(job)
    local s = P.GetSetting('adcfg:' .. tostring(job), {})
    s = type(s) == 'table' and s or {}
    return { price = math.floor(tonumber(s.price) or CFG.defaultPrice), enabled = s.enabled ~= false,
        commissions = type(s.commissions) == 'table' and s.commissions or {} }
end

-- Commission (montant fixe par diffusion manuelle) du grade, plafonnée au prix payé par le client
function P.AdCommission(job, gradeId, unitPrice)
    local c = math.floor(tonumber(P.AdCfg(job).commissions[tostring(gradeId)]) or 0)
    return math.max(0, math.min(c, math.floor(tonumber(unitPrice) or c)))
end

-- Rédactions qui prennent des commandes
local function Agencies()
    local st = P.AnnSettings()
    local out = {}
    for _, a in ipairs(P.agencyList) do
        local c = P.AdCfg(a.job)
        out[#out + 1] = { job = a.job, label = a.label, short = a.short, color = a.color, price = c.price, available = st.enabled and c.enabled }
    end
    return out
end

-- Entreprise du joueur (cliente) : métier du core, compte de société, droit de payer
local function ClientOf(src, res)
    local p = P.GetPlayer(src)
    local j = p and p.PlayerData.job
    if not j or not j.name or j.name == 'unemployed' then return nil end
    local c = { key = j.name, job = j.name, label = j.label or j.name, society = j.name, canPay = j.bankAuth == true or j.isboss == true }
    -- Concessions : plusieurs concessions possibles, chacune son compte
    if res == 'elyzea_concess' and GetResourceState('elyzea_concess') == 'started' then
        local ok, shop = pcall(function() return exports.elyzea_concess:GetShopOf(src) end)
        if ok and shop then c.key, c.label, c.society = 'concess:' .. tostring(shop.id), shop.name or c.label, shop.society or c.society end
    end
    local ag = P.agencies[j.name]
    if ag then c.label, c.society = ag.label, P.Society(j.name) end
    return c
end

-- Devis : tout recalculé à partir des données du client (jamais son prix)
local function Quote(src, d)
    if not P.AnnSettings().enabled then return nil, 'Les annonces sont désactivées sur le serveur.' end
    local job = tostring(d.job or '')
    local ag = P.agencies[job]
    if not ag then return nil, 'Cette entreprise de journalisme n\'existe plus.' end
    local cfg = P.AdCfg(job)
    if not cfg.enabled then return nil, ('%s ne prend pas de commandes pour le moment.'):format(ag.label) end
    local text = P.CleanAdText(d.text)
    local len = P.TextLength(text)
    if not len then return nil, 'Texte illisible.' end
    if len < 1 then return nil, 'Écrivez le texte de l\'annonce.' end
    if len > CFG.textMax then return nil, ('Texte trop long : %d caractères pour %d au maximum.'):format(len, CFG.textMax) end
    if #text > 640 then return nil, 'Texte trop long.' end
    local slots, why = P.Schedule(d.freq, d.start, d['end'])
    if not slots then return nil, why end
    local f = FREQ[d.freq]
    return {
        job = job, agency = ag.label, color = ag.color, text = text, length = len, freq = f.id,
        freqLabel = f.daily and ('Une fois par jour (%02dh%02d)'):format(CFG.dailyHour, CFG.dailyMinute) or f.label,
        start = d.start, ['end'] = d['end'], startLabel = FmtDate(d.start), endLabel = FmtDate(d['end']),
        count = #slots, unit = cfg.price, total = #slots * cfg.price,
        first = os.date('%d/%m/%Y %H:%M', slots[1]), last = os.date('%d/%m/%Y %H:%M', slots[#slots]),
    }, nil, slots
end

-- ---------------------------------------------------------------------
-- Commande et paiement (étapes tracées : pending → charged → credited → active ;
-- un arrêt du serveur au milieu est réparé au démarrage, voir RepairOrders)
-- ---------------------------------------------------------------------
local ordering = {}
local function SetOrder(id, status, note) MySQL.update.await('UPDATE `presse_ad_orders` SET `status` = ?, `note` = COALESCE(?, `note`) WHERE `id` = ?', { status, note, id }) end

local function InsertSlots(orderId, job, slots)
    for i = 1, #slots, 200 do
        local vals, args = {}, {}
        for k = i, math.min(#slots, i + 199) do
            vals[#vals + 1] = '(?, ?, ?, \'scheduled\')'
            args[#args + 1], args[#args + 2], args[#args + 3] = orderId, job, slots[k]
        end
        MySQL.insert.await('INSERT INTO `presse_ad_slots` (`order_id`, `job`, `due_ts`, `status`) VALUES ' .. table.concat(vals, ', '), args)
    end
    return MySQL.scalar.await('SELECT COUNT(*) FROM `presse_ad_slots` WHERE `order_id` = ?', { orderId }) == #slots
end

local function PlaceOrder(src, d, res)
    local client = ClientOf(src, res)
    if not client then return { error = 'Vous devez travailler pour une entreprise pour commander une annonce.' } end
    if not client.canPay then return { error = 'Seule la direction de votre entreprise (accès au compte) peut payer une annonce.' } end
    local q, why, slots = Quote(src, d)
    if not q then return { error = why } end
    if q.job == client.job then return { error = 'Votre rédaction ne peut pas se commander une annonce à elle-même.' } end
    -- Le client a validé un récapitulatif : refus si le prix ou le nombre a changé depuis
    if tonumber(d.expectedTotal) ~= q.total or tonumber(d.expectedCount) ~= q.count then
        return { error = ('Le récapitulatif a changé : %d diffusion(s), %d $. Vérifiez avant de payer.'):format(q.count, q.total), quote = q }
    end
    local key = tostring(d.requestKey or ''):match('^[%w%-]+$')
    if not key or #key < 8 or #key > 64 then return { error = 'Demande invalide, recommencez.' } end
    -- Même demande renvoyée (réseau, double clic) : la commande existante est renvoyée, rien n'est repayé
    local existing = MySQL.single.await('SELECT `uid`, `status` FROM `presse_ad_orders` WHERE `request_key` = ?', { key })
    if existing then
        if existing.status == 'active' or existing.status == 'completed' then return { ok = true, uid = existing.uid, already = true, message = 'Commande déjà enregistrée et payée.' } end
        return { error = 'Cette demande a déjà été traitée sans succès : recommencez la commande.' }
    end
    local uid = P.Uid('ANN')
    local okIns, orderId = pcall(MySQL.insert.await, [[INSERT INTO `presse_ad_orders` (`uid`, `request_key`, `job`, `agency_label`, `client_key`, `client_label`, `client_society`,
        `client_cid`, `client_name`, `text`, `frequency`, `start_date`, `end_date`, `unit_price`, `slots`, `total`, `status`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')]],
        { uid, key, q.job, q.agency, client.key, client.label, client.society, P.Cid(src), P.Name(src), q.text, q.freq, q.start, q['end'], q.unit, q.count, q.total })
    if not okIns or not orderId then
        local again = MySQL.single.await('SELECT `uid`, `status` FROM `presse_ad_orders` WHERE `request_key` = ?', { key })
        if again then return { ok = again.status == 'active', uid = again.uid, already = true, error = again.status ~= 'active' and 'Commande en cours de traitement.' or nil } end
        return { error = 'Commande impossible pour le moment.' }
    end
    local jsoc = P.Society(q.job)
    local why2 = ('Annonce %s · %s · %d diffusion(s)'):format(uid, q.agency, q.count)
    if q.total > 0 then
        if not core:RemoveSocietyMoney(client.society, q.total, why2) then
            SetOrder(orderId, 'failed', 'fonds insuffisants')
            local bal = tonumber(core:GetSocietyMoney(client.society)) or 0
            return { error = ('Paiement refusé : le compte de %s n\'a que %d $ pour %d $.'):format(client.label, bal, q.total), refused = true }
        end
        SetOrder(orderId, 'charged')
        if not core:AddSocietyMoney(jsoc, q.total, ('Annonce %s · %s'):format(uid, client.label)) then
            core:AddSocietyMoney(client.society, q.total, 'Annulation ' .. why2)
            SetOrder(orderId, 'failed', 'compte de la rédaction indisponible')
            return { error = 'Le compte de la rédaction est indisponible : rien n\'a été payé.' }
        end
        SetOrder(orderId, 'credited')
    end
    local okSlots, done = pcall(InsertSlots, orderId, q.job, slots)
    if not okSlots or not done then
        MySQL.update.await('DELETE FROM `presse_ad_slots` WHERE `order_id` = ?', { orderId })
        if q.total > 0 and core:RemoveSocietyMoney(jsoc, q.total, 'Annulation ' .. uid) then core:AddSocietyMoney(client.society, q.total, 'Annulation ' .. why2) end
        SetOrder(orderId, 'failed', 'planning non enregistré')
        print(('^1[PRESSE] Commande %s : diffusions non enregistrées (%s)^0'):format(uid, tostring(done)))
        return { error = 'Erreur pendant l\'enregistrement : la commande est annulée et rien n\'est payé.' }
    end
    local txid = q.total > 0 and P.Tx({ job = q.job, type = 'in', category = 'ad', amount = q.total, reason = ('%d diffusion(s) × %d $'):format(q.count, q.unit),
        actorCid = P.Cid(src), actorName = P.Name(src), targetName = client.label, ref = uid }) or nil
    MySQL.update.await("UPDATE `presse_ad_orders` SET `status` = 'active', `txid` = ? WHERE `id` = ?", { txid, orderId })
    P.Log(src, 'Annonce commandée', ('%s · %s → %s · %d × %d $'):format(uid, client.label, q.agency, q.count, q.unit))
    for _, id in ipairs(P.CrewOnDuty('ads', q.job)) do P.Notify(id, ('Nouvelle commande d\'annonce : %s (%d diffusion(s)).'):format(client.label, q.count), 'inform') end
    return { ok = true, uid = uid, quote = q, message = ('Commande %s payée : %d diffusion(s), %d $.'):format(uid, q.count, q.total) }
end

-- Réparation au démarrage d'une commande interrompue au milieu du paiement
local function RepairOrders()
    for _, o in ipairs(MySQL.query.await("SELECT * FROM `presse_ad_orders` WHERE `status` IN ('pending', 'charged', 'credited')") or {}) do
        if o.status == 'charged' then core:AddSocietyMoney(o.client_society, o.total, 'Annulation annonce ' .. o.uid) end
        if o.status == 'credited' then
            MySQL.update.await('DELETE FROM `presse_ad_slots` WHERE `order_id` = ?', { o.id })
            if core:RemoveSocietyMoney(P.Society(o.job), o.total, 'Annulation annonce ' .. o.uid) then core:AddSocietyMoney(o.client_society, o.total, 'Annulation annonce ' .. o.uid) end
        end
        SetOrder(o.id, 'failed', 'interrompue par un arrêt du serveur')
        print(('^3[PRESSE] Commande %s interrompue (%s) : annulée, argent rendu.^0'):format(o.uid, o.status))
    end
end

-- ---------------------------------------------------------------------
-- Remboursement de diffusions non faites (annulation, retard, rédaction supprimée)
-- ---------------------------------------------------------------------
local CANCELLABLE = "'scheduled', 'offered', 'queued', 'failed'"
local function Refund(order, n, reason)
    local amount = n * (tonumber(order.unit_price) or 0)
    if amount <= 0 then return true end
    if not core:RemoveSocietyMoney(P.Society(order.job), amount, ('Remboursement %s · %s'):format(order.uid, reason)) then return false end
    core:AddSocietyMoney(order.client_society, amount, ('Remboursement annonce %s · %s'):format(order.uid, reason))
    MySQL.update.await('UPDATE `presse_ad_orders` SET `refunded` = `refunded` + ? WHERE `id` = ?', { amount, order.id })
    P.Tx({ job = order.job, type = 'out', category = 'refund', amount = amount, reason = ('Annonce : %s'):format(reason), actorName = 'Système', targetName = order.client_label, ref = order.uid })
    return true
end

-- Passe des diffusions à un état final (missed / cancelled) et rembourse celles qui ont vraiment changé d'état
local function CloseSlots(order, ids, status, reason)
    local n = 0
    local changed = {}
    for _, id in ipairs(ids) do
        local c = MySQL.update.await(('UPDATE `presse_ad_slots` SET `status` = ?, `last_error` = ? WHERE `id` = ? AND `status` IN (%s)'):format(CANCELLABLE), { status, reason, id })
        if c and c > 0 then n = n + 1 changed[#changed + 1] = id end
    end
    if n == 0 then return 0, true end
    local ok = Refund(order, n, reason)
    if #changed > 0 then
        MySQL.update.await(('UPDATE `presse_ad_slots` SET `refund_status` = ? WHERE `id` IN (%s)'):format(table.concat(changed, ',')), { ok and 'done' or 'failed' })
    end
    return n, ok
end
P.CloseAdSlots = CloseSlots

local function LoadOrder(id) return MySQL.single.await('SELECT * FROM `presse_ad_orders` WHERE `id` = ?', { tonumber(id) or 0 }) end

-- Annuler toutes les diffusions restantes d'une commande (direction de la rédaction ou staff)
function P.CancelOrder(id, actor, reason, job)
    local o = LoadOrder(id)
    if not o or (job and o.job ~= job) then return { error = 'Commande introuvable.' } end
    if o.status ~= 'active' then return { error = 'Cette commande n\'est plus active.' } end
    local ids = {}
    for _, r in ipairs(MySQL.query.await(('SELECT `id` FROM `presse_ad_slots` WHERE `order_id` = ? AND `status` IN (%s)'):format(CANCELLABLE), { o.id }) or {}) do ids[#ids + 1] = r.id end
    local need = #ids * o.unit_price
    if need > 0 and (tonumber(core:GetSocietyMoney(P.Society(o.job))) or 0) < need then
        return { error = ('Fonds insuffisants sur le compte de la rédaction pour rembourser %d $.'):format(need) }
    end
    local n, ok = CloseSlots(o, ids, 'cancelled', 'annulation : ' .. reason)
    MySQL.update.await("UPDATE `presse_ad_orders` SET `status` = 'cancelled', `note` = ? WHERE `id` = ?", { ('Annulée par %s : %s'):format(actor, reason), o.id })
    return { ok = true, message = ('Commande %s annulée : %d diffusion(s) non faite(s) remboursée(s) (%d $)%s. Les diffusions déjà faites restent dues.')
        :format(o.uid, n, n * o.unit_price, ok and '' or ' — remboursement EN ÉCHEC, à relancer dans admin_menu') }
end

-- ---------------------------------------------------------------------
-- File d'attente centrale : une seule annonce à l'écran à la fois
-- ---------------------------------------------------------------------
P.adCurrent = nil   -- { id, endsAt }

local function PayCommission(slot, order)
    local amount = math.floor(tonumber(slot.commission) or 0)
    if slot.mode ~= 'manual' or amount <= 0 or not slot.sent_by_cid then return end
    -- Verrou en base : une seule fois, même si deux traitements se croisent
    local c = MySQL.update.await("UPDATE `presse_ad_slots` SET `commission_status` = 'paying' WHERE `id` = ? AND `commission_status` IS NULL", { slot.id })
    if not c or c < 1 then return end
    local why = ('Prime d\'annonce %s · diffusion n° %d'):format(order.uid, slot.id)
    local okPay = false
    if P.SocietyRemove(amount, why, order.job) then
        local paid, s = P.PayBank(slot.sent_by_cid, amount, why)
        if paid then
            okPay = true
            P.Tx({ job = order.job, type = 'out', category = 'commission', amount = amount, reason = why, actorName = 'Système', targetCid = slot.sent_by_cid, targetName = slot.sent_by_name, ref = order.uid })
            if s then P.Notify(s, ('Prime d\'annonce reçue en banque : %d $.'):format(amount), 'success') end
        else
            P.SocietyAdd(amount, 'Annulation : ' .. why, order.job)
        end
    end
    MySQL.update.await('UPDATE `presse_ad_slots` SET `commission_status` = ? WHERE `id` = ?', { okPay and 'paid' or 'failed', slot.id })
    if not okPay then print(('^3[PRESSE] Prime non versée (fonds de la rédaction insuffisants) : %s^0'):format(why)) end
end

local function Fail(slot, err)
    local st = P.AnnSettings()
    local status = (tonumber(slot.attempts) or 0) >= st.maxAttempts and 'failed' or 'queued'
    MySQL.update.await("UPDATE `presse_ad_slots` SET `status` = ?, `last_error` = ? WHERE `id` = ? AND `status` = 'broadcasting'", { status, tostring(err):sub(1, 160), slot.id })
    print(('^1[PRESSE] Diffusion %d : %s (%s)^0'):format(slot.id, tostring(err), status == 'failed' and 'en échec, à relancer' or 'nouvel essai'))
end

-- Prend la prochaine diffusion de la file, l'affiche chez tout le monde, attend la fin, la marque envoyée
local function ProcessNext()
    local st = P.AnnSettings()
    if not st.enabled or st.queuePaused then return false end
    local slot = MySQL.single.await("SELECT * FROM `presse_ad_slots` WHERE `status` = 'queued' ORDER BY `queued_ts`, `due_ts`, `id` LIMIT 1")
    if not slot then return false end
    local now = os.time()
    local c = MySQL.update.await("UPDATE `presse_ad_slots` SET `status` = 'broadcasting', `attempts` = `attempts` + 1, `started_ts` = ? WHERE `id` = ? AND `status` = 'queued'", { now, slot.id })
    if not c or c < 1 then return true end
    slot.attempts = (tonumber(slot.attempts) or 0) + 1
    local order = LoadOrder(slot.order_id)
    if not order or order.status ~= 'active' then
        MySQL.update.await("UPDATE `presse_ad_slots` SET `status` = 'cancelled', `last_error` = 'commande inactive' WHERE `id` = ? AND `status` = 'broadcasting'", { slot.id })
        return true
    end
    local ag = P.agencies[order.job]
    local seconds = math.floor(st.displaySeconds)
    local ok, err = pcall(function()
        TriggerClientEvent('presse:client:annonce', -1, { id = slot.id, agency = ag and ag.label or order.agency_label, color = ag and ag.color or nil,
            text = order.text, seconds = seconds })
    end)
    if not ok then Fail(slot, err) return true end
    P.adCurrent = { id = slot.id, agency = ag and ag.label or order.agency_label, text = order.text, endsAt = now + seconds, mode = slot.mode }
    Wait(seconds * 1000 + math.floor(st.gapMs))   -- la suivante attend que celle-ci ait disparu de tous les écrans
    P.adCurrent = nil
    local done = MySQL.update.await("UPDATE `presse_ad_slots` SET `status` = 'sent', `sent_ts` = ? WHERE `id` = ? AND `status` = 'broadcasting'", { os.time(), slot.id })
    if done and done > 0 then
        PayCommission(slot, order)
        if slot.sent_by_cid then
            local s = core:GetSourceByCitizenId(slot.sent_by_cid)
            if s then TriggerClientEvent('elyzea_jobphone:client:push', s, 'planning') end
        end
    end
    return true
end
P.ProcessAdQueue = ProcessNext

-- ---------------------------------------------------------------------
-- Planificateur : diffusions dues → journalistes en service ou envoi automatique
-- ---------------------------------------------------------------------
local function PushPlanning(job)
    for _, id in ipairs(P.CrewOnDuty('ads', job)) do TriggerClientEvent('elyzea_jobphone:client:push', id, 'planning') end
end

function P.AdTick()
    local st = P.AnnSettings()
    if not st.enabled then return end
    local now = os.time()
    -- 1. Trop en retard (serveur arrêté, système coupé) ou rédaction supprimée : annulées et remboursées
    local byOrder = {}
    for _, r in ipairs(MySQL.query.await("SELECT `id`, `order_id`, `job` FROM `presse_ad_slots` WHERE `status` IN ('scheduled', 'offered') AND (`due_ts` < ?)",
        { now - st.maxLate }) or {}) do
        byOrder[r.order_id] = byOrder[r.order_id] or { ids = {}, why = 'diffusion manquée (trop de retard)', status = 'missed' }
        table.insert(byOrder[r.order_id].ids, r.id)
    end
    for _, r in ipairs(MySQL.query.await("SELECT `id`, `order_id`, `job` FROM `presse_ad_slots` WHERE `status` IN ('scheduled', 'offered', 'queued') AND `due_ts` <= ?", { now }) or {}) do
        if not P.agencies[r.job] then
            byOrder[r.order_id] = byOrder[r.order_id] or { ids = {}, why = 'rédaction supprimée', status = 'cancelled' }
            table.insert(byOrder[r.order_id].ids, r.id)
        end
    end
    for oid, x in pairs(byOrder) do
        local o = LoadOrder(oid)
        if o then CloseSlots(o, x.ids, x.status, x.why) end
    end
    -- 2. Diffusions arrivées à l'heure
    local touched = {}
    for _, r in ipairs(MySQL.query.await("SELECT `id`, `job` FROM `presse_ad_slots` WHERE `status` = 'scheduled' AND `due_ts` <= ? ORDER BY `due_ts`, `id` LIMIT 300", { now }) or {}) do
        if P.agencies[r.job] then
            if #P.CrewOnDuty('ads', r.job) > 0 then
                local c = MySQL.update.await("UPDATE `presse_ad_slots` SET `status` = 'offered', `offered_ts` = ? WHERE `id` = ? AND `status` = 'scheduled'", { now, r.id })
                if c and c > 0 then touched[r.job] = true end
            else
                MySQL.update.await("UPDATE `presse_ad_slots` SET `status` = 'queued', `mode` = 'auto', `queued_ts` = ? WHERE `id` = ? AND `status` = 'scheduled'", { now, r.id })
            end
        end
    end
    -- 3. Proposées aux journalistes : plus personne en service, ou délai dépassé → automatique (sans commission)
    for _, r in ipairs(MySQL.query.await("SELECT `id`, `job`, `offered_ts` FROM `presse_ad_slots` WHERE `status` = 'offered'") or {}) do
        if #P.CrewOnDuty('ads', r.job) == 0 or now - (tonumber(r.offered_ts) or now) >= st.manualWindow then
            MySQL.update.await("UPDATE `presse_ad_slots` SET `status` = 'queued', `mode` = 'auto', `queued_ts` = ? WHERE `id` = ? AND `status` = 'offered'", { now, r.id })
            touched[r.job] = true
        end
    end
    for job in pairs(touched) do
        PushPlanning(job)
        for _, id in ipairs(P.CrewOnDuty('ads', job)) do P.Notify(id, 'Planning : une ou plusieurs annonces sont à envoyer.', 'inform') end
    end
    -- 4. Commandes terminées
    MySQL.update.await([[UPDATE `presse_ad_orders` o SET o.`status` = 'completed' WHERE o.`status` = 'active' AND NOT EXISTS
        (SELECT 1 FROM `presse_ad_slots` s WHERE s.`order_id` = o.`id` AND s.`status` NOT IN ('sent', 'missed', 'cancelled'))]])
end

-- Démarrage : commandes interrompues réparées ; diffusion coupée par l'arrêt → remise en file (jamais comptée comme faite)
function P.AdRecover()
    RepairOrders()
    MySQL.update.await("UPDATE `presse_ad_slots` SET `status` = 'queued', `last_error` = 'arrêt du serveur pendant l''affichage' WHERE `status` = 'broadcasting'")
end
P.OnReady = P.OnReady or {}
P.OnReady[#P.OnReady + 1] = function()
    P.AdRecover()
    CreateThread(function()
        while true do
            local ok, err = pcall(P.AdTick)
            if not ok then print(('^1[PRESSE] Planificateur : %s^0'):format(tostring(err))) end
            Wait(math.floor(P.AnnSettings().tickSeconds) * 1000)
        end
    end)
    CreateThread(function()
        while true do
            local ok, busy = pcall(ProcessNext)
            if not ok then print(('^1[PRESSE] File des annonces : %s^0'):format(tostring(busy))) end
            Wait(ok and busy and 50 or 1000)
        end
    end)
end

-- ---------------------------------------------------------------------
-- Planning (journalistes) et commandes (entreprises) : téléphone de service
-- ---------------------------------------------------------------------
local LATE = 300   -- secondes : au-delà, une diffusion proposée est marquée « en retard »

local function SlotView(r, now)
    local v = { id = r.id, due = r.due_ts, dueLabel = os.date('%d/%m %H:%M', r.due_ts), status = r.status, mode = r.mode, by = r.sent_by_name,
        sent = r.sent_ts, sentLabel = r.sent_ts and os.date('%d/%m %H:%M', r.sent_ts) or nil, commission = r.commission, commissionStatus = r.commission_status,
        text = r.text, client = r.client_label, unit = r.unit_price, orderTotal = r.total, uid = r.uid }
    v.available = (r.status == 'offered' or r.status == 'scheduled') and r.due_ts <= now
    v.late = v.available and now - r.due_ts > LATE
    return v
end

local SLOT_SELECT = [[SELECT s.*, o.`text`, o.`client_label`, o.`unit_price`, o.`total`, o.`uid` FROM `presse_ad_slots` s JOIN `presse_ad_orders` o ON o.`id` = s.`order_id`]]

P.Actions.planning = { perm = 'ads', fn = function(src)
    local job, now = P.MyJob(src), os.time()
    local g = P.Grade(src)
    local mine = {}
    local function Q(where, args, order, limit)
        local out = {}
        for _, r in ipairs(MySQL.query.await(('%s WHERE s.`job` = ? AND %s ORDER BY %s LIMIT %d'):format(SLOT_SELECT, where, order, limit), args) or {}) do out[#out + 1] = SlotView(r, now) end
        return out
    end
    local dayEnd = os.time({ year = tonumber(os.date('%Y', now)), month = tonumber(os.date('%m', now)), day = tonumber(os.date('%d', now)), hour = 23, min = 59, sec = 59 })
    local due = Q("s.`status` IN ('offered', 'scheduled') AND s.`due_ts` <= ?", { job, now }, 's.`due_ts`, s.`id`', 50)
    local today = Q("s.`status` = 'scheduled' AND s.`due_ts` > ? AND s.`due_ts` <= ?", { job, now, dayEnd }, 's.`due_ts`', 60)
    local next = Q("s.`status` = 'scheduled' AND s.`due_ts` > ?", { job, dayEnd }, 's.`due_ts`', 30)
    local queued = Q("s.`status` IN ('queued', 'broadcasting')", { job }, 's.`queued_ts`, s.`id`', 30)
    local sent = Q("s.`status` = 'sent'", { job }, 's.`sent_ts` DESC', 30)
    for _, list in ipairs({ due, today, next }) do for _, v in ipairs(list) do v.myCommission = P.AdCommission(job, g and g.id, v.unit) end end
    mine.duty = P.OnDuty(src)
    mine.enabled = P.AnnSettings().enabled
    mine.agency = P.AgencyLabel(job)
    return { due = due, today = today, next = next, queued = queued, sent = sent, me = mine, displaySeconds = P.AnnSettings().displaySeconds }
end }

-- « Envoyer l'annonce » : seul le premier qui la prend la diffuse et touchera la prime
P.Actions.planSend = { perm = 'ads', duty = true, fn = function(src, d)
    if not P.AnnSettings().enabled then return { error = 'Les annonces sont désactivées sur le serveur.' } end
    local id = tonumber(d.id)
    local job, now = P.MyJob(src), os.time()
    local slot = id and MySQL.single.await(SLOT_SELECT .. ' WHERE s.`id` = ?', { id })
    if not slot or slot.job ~= job then return { error = 'Annonce introuvable dans le planning de votre rédaction.' } end
    if slot.due_ts > now then return { error = ('Pas encore l\'heure : diffusion prévue le %s.'):format(os.date('%d/%m à %H:%M', slot.due_ts)) } end
    local g = P.Grade(src)
    local commission = P.AdCommission(job, g and g.id, slot.unit_price)
    local c = MySQL.update.await([[UPDATE `presse_ad_slots` SET `status` = 'queued', `mode` = 'manual', `sent_by_cid` = ?, `sent_by_name` = ?, `commission` = ?, `queued_ts` = ?
        WHERE `id` = ? AND `job` = ? AND `status` IN ('offered', 'scheduled') AND `due_ts` <= ?]], { P.Cid(src), P.Name(src), commission, now, id, job, now })
    if not c or c < 1 then
        local cur = MySQL.single.await('SELECT `status`, `sent_by_name`, `mode` FROM `presse_ad_slots` WHERE `id` = ?', { id })
        if cur and (cur.status == 'queued' or cur.status == 'broadcasting' or cur.status == 'sent') then
            return { error = cur.mode == 'manual' and ('Déjà envoyée par %s.'):format(cur.sent_by_name or 'un collègue') or 'Déjà partie en diffusion automatique.' }
        end
        return { error = 'Cette annonce ne peut plus être envoyée.' }
    end
    local ahead = MySQL.scalar.await("SELECT COUNT(*) FROM `presse_ad_slots` WHERE `status` IN ('queued', 'broadcasting') AND `id` <> ?", { id }) or 0
    P.Log(src, 'Annonce envoyée', ('diffusion %d · %s'):format(id, slot.uid))
    PushPlanning(job)
    return { ok = true, message = ahead > 0 and ('Annonce envoyée : elle passera après %d annonce(s) déjà en file. Prime : %d $ une fois diffusée.'):format(ahead, commission)
        or ('Annonce envoyée. Prime : %d $ une fois diffusée.'):format(commission) }
end }

-- Tablette › Annonces (rédaction) : tarif, commissions par grade, commandes
P.Actions.adSettings = { perm = 'tablet', fn = function(src)
    if not P.Can(src, 'ads') and not P.Can(src, 'ads_manage') then return { error = 'Votre grade ne gère pas les annonces.' } end
    local job = P.MyJob(src)
    local cfg = P.AdCfg(job)
    local grades = {}
    for _, g in ipairs(P.SortedGrades(job)) do grades[#grades + 1] = { id = g.id, name = g.name, level = g.level, commission = math.floor(tonumber(cfg.commissions[tostring(g.id)]) or 0) } end
    local orders = MySQL.query.await([[SELECT o.`id`, o.`uid`, o.`client_label`, o.`client_name`, o.`text`, o.`frequency`, o.`start_date`, o.`end_date`, o.`unit_price`, o.`slots`, o.`total`,
        o.`refunded`, o.`status`, o.`note`, UNIX_TIMESTAMP(o.`created_at`) AS t,
        (SELECT COUNT(*) FROM `presse_ad_slots` s WHERE s.`order_id` = o.`id` AND s.`status` = 'sent') AS sent
        FROM `presse_ad_orders` o WHERE o.`job` = ? AND o.`status` IN ('active', 'completed', 'cancelled') ORDER BY o.`id` DESC LIMIT 60]], { job }) or {}
    local freq = {}
    for _, f in ipairs(CFG.frequencies) do freq[f.id] = f.label end
    for _, o in ipairs(orders) do o.freqLabel = freq[o.frequency] or o.frequency o.start = FmtDate(o.start_date) o['end'] = FmtDate(o.end_date) end
    return { price = cfg.price, enabled = cfg.enabled, grades = grades, orders = orders, canManage = P.Can(src, 'ads_manage'), maxPrice = CFG.maxPrice,
        system = P.AnnSettings().enabled }
end }

P.Actions.adSettingsSave = { perm = 'ads_manage', fn = function(src, d)
    local job = P.MyJob(src)
    local price = P.Int(d.price, 0, CFG.maxPrice, nil)
    if not price then return { error = ('Tarif invalide (0 à %d $).'):format(CFG.maxPrice) } end
    local cfg = P.AdCfg(job)
    local com = {}
    for _, g in ipairs(P.SortedGrades(job)) do
        local v = type(d.commissions) == 'table' and d.commissions[tostring(g.id)]
        local n = v ~= nil and P.Int(v, 0, CFG.maxPrice, nil) or math.floor(tonumber(cfg.commissions[tostring(g.id)]) or 0)
        if not n then return { error = ('Prime invalide pour %s.'):format(g.name) } end
        if n > 0 then com[tostring(g.id)] = n end
    end
    local old = cfg.price
    P.SetSetting('adcfg:' .. job, { price = price, enabled = d.enabled ~= false, commissions = com })
    P.AddLog(src, nil, nil, 'Annonces : tarif et primes', nil, nil, ('%d $ → %d $ par annonce'):format(old, price))
    return { ok = true, message = ('Tarif enregistré : %d $ par annonce (les commandes déjà payées gardent leur prix).'):format(price) }
end }

P.Actions.adOrderCancel = { perm = 'ads_manage', fn = function(src, d)
    local reason = P.Clean(d.reason, 120)
    if #reason < 3 then return { error = 'Indiquez le motif.' } end
    local r = P.CancelOrder(d.id, P.Name(src), reason, P.MyJob(src))
    if r.ok then P.AddLog(src, nil, nil, 'Annonce annulée', nil, nil, reason) end
    return r
end }

-- ---------------------------------------------------------------------
-- Pont du téléphone de service (elyzea_jobphone) : « Annonce » pour toutes les entreprises,
-- « Planning » pour les journalistes. Mêmes contrôles que « presse:req ».
-- ---------------------------------------------------------------------
local function Run(src, name, data)
    local a = P.Actions[name]
    if not P.ready or not a then return { error = 'Indisponible.' } end
    if not P.IsPresse(src) then return { error = 'Réservé aux journalistes.' } end
    if a.perm and not P.Can(src, a.perm) then return { error = 'Votre grade ne permet pas cette action.' } end
    if a.duty and not P.OnDuty(src) then return { error = 'Prenez votre service pour faire cela.' } end
    local ok, res = pcall(a.fn, src, data)
    if not ok then print(('^1[PRESSE] %s : %s^0'):format(name, tostring(res))) return { error = 'Erreur serveur.' } end
    return res or {}
end

local API = {}
function API.agencies(src, d, res)
    local client = ClientOf(src, res)
    local list = Agencies()
    return { list = list, client = client and { label = client.label, canPay = client.canPay, job = client.job,
            balance = client.canPay and (tonumber(core:GetSocietyMoney(client.society)) or 0) or nil } or nil,
        frequencies = CFG.frequencies, textMax = CFG.textMax, daily = ('%02dh%02d'):format(CFG.dailyHour, CFG.dailyMinute), maxDays = CFG.maxDays,
        today = os.date('%Y-%m-%d'), enabled = P.AnnSettings().enabled }
end
function API.quote(src, d, res)
    local client = ClientOf(src, res)
    if not client then return { error = 'Vous devez travailler pour une entreprise pour commander une annonce.' } end
    local q, why = Quote(src, d)
    if not q then return { error = why } end
    q.client = client.label
    q.canPay = client.canPay
    return { quote = q }
end
function API.order(src, d, res)
    local client = ClientOf(src, res)
    local lock = client and client.society or ('src' .. src)
    if ordering[lock] then return { error = 'Une commande de votre entreprise est déjà en cours de paiement.' } end
    ordering[lock] = true
    local ok, r = pcall(PlaceOrder, src, d, res)
    ordering[lock] = nil
    if not ok then print(('^1[PRESSE] Commande : %s^0'):format(tostring(r))) return { error = 'Erreur pendant la commande.' } end
    return r
end
function API.myOrders(src, d, res)
    local client = ClientOf(src, res)
    if not client then return { list = {} } end
    local rows = MySQL.query.await([[SELECT o.`uid`, o.`agency_label`, o.`text`, o.`slots`, o.`total`, o.`refunded`, o.`status`, o.`start_date`, o.`end_date`,
        (SELECT COUNT(*) FROM `presse_ad_slots` s WHERE s.`order_id` = o.`id` AND s.`status` = 'sent') AS sent,
        (SELECT MIN(s.`due_ts`) FROM `presse_ad_slots` s WHERE s.`order_id` = o.`id` AND s.`status` IN ('scheduled', 'offered', 'queued')) AS nextTs
        FROM `presse_ad_orders` o WHERE o.`client_key` = ? AND o.`status` IN ('active', 'completed', 'cancelled') ORDER BY o.`id` DESC LIMIT 20]], { client.key }) or {}
    for _, r in ipairs(rows) do r.start = FmtDate(r.start_date) r['end'] = FmtDate(r.end_date) r.next = r.nextTs and os.date('%d/%m %H:%M', r.nextTs) or nil end
    return { list = rows }
end
function API.planning(src) return Run(src, 'planning', {}) end
function API.planSend(src, d) return Run(src, 'planSend', d) end

exports('AnnonceApi', function(op, src, data, res)
    src = tonumber(src)
    local f = API[tostring(op)]
    if not f or not src or not P.ready then return { error = 'Annonces indisponibles.' } end
    local ok, r = pcall(f, src, type(data) == 'table' and data or {}, res)
    if not ok then print(('^1[PRESSE] Annonce %s : %s^0'):format(tostring(op), tostring(r))) return { error = 'Erreur serveur.' } end
    return r
end)

-- ---------------------------------------------------------------------
-- admin_menu › Annonces presse (permission « presse_manage », revérifiée ici)
-- ---------------------------------------------------------------------
local LIMITS = CFG.limits
function P.AnnonceAdminData()
    local st = P.AnnSettings()
    local counts = {}
    for _, r in ipairs(MySQL.query.await('SELECT `status`, COUNT(*) AS n FROM `presse_ad_slots` GROUP BY `status`') or {}) do counts[r.status] = tonumber(r.n) or 0 end
    local agencies = {}
    for _, a in ipairs(Agencies()) do
        a.orders = MySQL.scalar.await("SELECT COUNT(*) FROM `presse_ad_orders` WHERE `job` = ? AND `status` = 'active'", { a.job }) or 0
        a.revenue = MySQL.scalar.await("SELECT COALESCE(SUM(`total` - `refunded`), 0) FROM `presse_ad_orders` WHERE `job` = ? AND `status` IN ('active', 'completed', 'cancelled')", { a.job }) or 0
        agencies[#agencies + 1] = a
    end
    local orders = MySQL.query.await([[SELECT `id`, `uid`, `agency_label`, `client_label`, `client_name`, `text`, `frequency`, `start_date`, `end_date`, `unit_price`, `slots`, `total`, `refunded`, `status`, `note`,
        UNIX_TIMESTAMP(`created_at`) AS t FROM `presse_ad_orders` ORDER BY `id` DESC LIMIT 60]]) or {}
    local sent = MySQL.query.await(SLOT_SELECT .. " WHERE s.`status` = 'sent' ORDER BY s.`sent_ts` DESC LIMIT 60") or {}
    local pending = MySQL.query.await(SLOT_SELECT .. " WHERE s.`status` IN ('broadcasting', 'queued', 'offered', 'failed') ORDER BY FIELD(s.`status`, 'broadcasting', 'queued', 'offered', 'failed'), s.`queued_ts`, s.`due_ts` LIMIT 80") or {}
    local upcoming = MySQL.query.await(SLOT_SELECT .. " WHERE s.`status` = 'scheduled' ORDER BY s.`due_ts` LIMIT 40") or {}
    local refundsFailed = MySQL.scalar.await("SELECT COUNT(*) FROM `presse_ad_slots` WHERE `refund_status` = 'failed'") or 0
    local function lab(list) for _, r in ipairs(list) do r.dueLabel = os.date('%d/%m %H:%M', r.due_ts) r.sentLabel = r.sent_ts and os.date('%d/%m %H:%M:%S', r.sent_ts) or nil end return list end
    return { available = true, settings = st, limits = LIMITS, counts = counts, agencies = agencies, orders = orders, sent = lab(sent), pending = lab(pending), upcoming = lab(upcoming),
        current = P.adCurrent, refundsFailed = refundsFailed, now = os.time(), serverTime = os.date('%d/%m/%Y %H:%M') }
end

local ADMIN = {}
function ADMIN.save(src, d)
    local s = P.AnnSettings()
    local function num(k)
        local v = P.Int(d[k], LIMITS[k][1], LIMITS[k][2], nil)
        if v then s[k] = v end
    end
    for k in pairs(LIMITS) do num(k) end
    if d.enabled ~= nil then s.enabled = d.enabled == true end
    P.SetSetting('annonces', s)
    return true, ('Réglages enregistrés : affichage %d s, planificateur %d s.'):format(s.displaySeconds, s.tickSeconds)
end
function ADMIN.pause(_, d)
    local s = P.AnnSettings()
    s.queuePaused = d.on == true
    P.SetSetting('annonces', s)
    return true, s.queuePaused and 'File d\'attente en pause (l\'annonce affichée se termine).' or 'File d\'attente relancée.'
end
function ADMIN.retry(_, d)
    local c = MySQL.update.await("UPDATE `presse_ad_slots` SET `status` = 'queued', `attempts` = 0, `queued_ts` = ? WHERE `id` = ? AND `status` = 'failed'", { os.time(), tonumber(d.id) or 0 })
    return c and c > 0, c and c > 0 and 'Diffusion remise dans la file.' or 'Diffusion introuvable ou pas en échec.'
end
function ADMIN.cancelSlot(_, d)
    local slot = MySQL.single.await('SELECT `id`, `order_id` FROM `presse_ad_slots` WHERE `id` = ?', { tonumber(d.id) or 0 })
    local o = slot and LoadOrder(slot.order_id)
    if not o then return false, 'Diffusion introuvable.' end
    local n, ok = CloseSlots(o, { slot.id }, 'cancelled', 'annulée par le staff')
    if n == 0 then return false, 'Cette diffusion ne peut plus être annulée (déjà envoyée ou en cours d\'affichage).' end
    return true, ok and ('Diffusion annulée, %d $ remboursés au client.'):format(o.unit_price) or 'Diffusion annulée ; remboursement en échec (fonds de la rédaction), à relancer.'
end
function ADMIN.cancelOrder(src, d)
    local reason = P.Clean(d.reason, 120)
    if #reason < 3 then return false, 'Indiquez le motif.' end
    local r = P.CancelOrder(d.id, 'Staff · ' .. (GetPlayerName(src) or '?'), reason)
    return r.ok == true, r.message or r.error
end
function ADMIN.refundRetry()
    local done, fail = 0, 0
    local byOrder = {}
    for _, r in ipairs(MySQL.query.await("SELECT `id`, `order_id` FROM `presse_ad_slots` WHERE `refund_status` = 'failed'") or {}) do
        byOrder[r.order_id] = byOrder[r.order_id] or {}
        table.insert(byOrder[r.order_id], r.id)
    end
    for oid, ids in pairs(byOrder) do
        local o = LoadOrder(oid)
        if o and Refund(o, #ids, 'remboursement relancé') then
            MySQL.update.await(("UPDATE `presse_ad_slots` SET `refund_status` = 'done' WHERE `id` IN (%s)"):format(table.concat(ids, ',')))
            done = done + #ids
        else fail = fail + #ids end
    end
    return done > 0 or fail == 0, ('%d remboursement(s) faits, %d encore en échec.'):format(done, fail)
end

exports('AnnonceAdminData', function() if not P.ready then return { available = false } end return P.AnnonceAdminData() end)
exports('AnnonceAdminAction', function(src, name, data)
    src = tonumber(src)
    if not src or not P.IsStaff(src) then return false, 'Permission « presse_manage » requise.' end
    local f = ADMIN[tostring(name)]
    if not f then return false, 'Action inconnue.' end
    local ok, done, msg = pcall(f, src, type(data) == 'table' and data or {})
    if not ok then print(('^1[PRESSE] Admin annonces : %s^0'):format(tostring(done))) return false, 'Erreur serveur.' end
    if done then P.Log(src, 'Admin annonces : ' .. tostring(name), msg) end
    return done, msg
end)

