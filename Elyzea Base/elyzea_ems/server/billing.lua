-- =====================================================================
--  ELYZEA EMS - serveur : facturation médicale (paiement toujours immédiat)
--  · Tarifs réglés par la direction (Finance › Facturation), gardés en base.
--  · Le montant est TOUJOURS recalculé ici à partir des actes enregistrés
--    (ems_treatments) : jamais à partir d'un montant envoyé par le client.
--  · Un acte facturé reçoit l'identifiant de la facture : il ne peut plus être
--    facturé une seconde fois. Facture refusée (fonds insuffisants) : les actes
--    restent à facturer.
--  · Prélèvement banque puis liquide ; argent versé sur le compte société.
--  · Remboursement / annulation tracés (facture + transaction).
-- =====================================================================
local P = Ems
local B = Config.Billing
local WINDOW = 360   -- minutes : actes récents pris en compte pour une facture

-- Réglages : { mode, flat, services = { [id] = { price, enabled } } }
function P.BillingSettings()
    local s = P.GetSetting('billing', {})
    local out = { mode = s.mode or B.mode, flat = tonumber(s.flat) or B.flat, services = {} }
    for _, def in ipairs(B.services) do
        local o = type(s.services) == 'table' and s.services[def.id] or nil
        out.services[#out.services + 1] = { id = def.id, label = def.label,
            price = o and tonumber(o.price) or def.price, enabled = (o and o.enabled ~= nil) and (o.enabled == true) or (o == nil and def.enabled ~= false) }
    end
    return out
end
local function ServiceDef(id)
    for _, s in ipairs(P.BillingSettings().services) do if s.id == id then return s end end
end

-- Actes non facturés du patient (fenêtre récente)
local function Unbilled(cid)
    return MySQL.query.await([[SELECT `id`, `service`, `ems_name`, `call_id`, UNIX_TIMESTAMP(`created_at`) AS t FROM `ems_treatments`
        WHERE `patient_cid` = ? AND `invoice_uid` IS NULL AND `created_at` >= DATE_SUB(NOW(), INTERVAL ? MINUTE) ORDER BY `id`]], { cid, WINDOW }) or {}
end

-- Calcul serveur : chaque prestation comptée une fois par intervention
local function Compute(cid, extras)
    local set = P.BillingSettings()
    local rows = Unbilled(cid)
    local seen, items, ids, total = {}, {}, {}, 0
    for _, r in ipairs(rows) do
        ids[#ids + 1] = r.id
        if not seen[r.service] then
            seen[r.service] = true
            local s = ServiceDef(r.service)
            if s and s.enabled then items[#items + 1] = { id = s.id, label = s.label, price = s.price, auto = true } end
        end
    end
    for _, id in ipairs(type(extras) == 'table' and extras or {}) do
        id = tostring(id)
        if not seen[id] then
            local s = ServiceDef(id)
            if s and s.enabled then seen[id] = true items[#items + 1] = { id = s.id, label = s.label, price = s.price, extra = true } end
        end
    end
    if set.mode == 'flat' then
        total = #items > 0 and set.flat or 0
    else
        for _, it in ipairs(items) do total = total + it.price end
        if set.mode == 'mixed' and #items > 0 then total = total + set.flat end
    end
    total = math.max(0, math.min(B.maxPrice * 10, math.floor(total)))
    return { items = items, treatmentIds = ids, total = total, mode = set.mode, flat = set.flat, services = set.services }
end

P.Actions.billPreview = { perm = 'billing', duty = true, fn = function(src, d)
    local t = tonumber(d.target)
    if not t or t == src or not GetPlayerName(t) then return { error = 'Patient introuvable.' } end
    if P.Dist(src, t) > Config.Distances.interact + 2.0 then return { error = 'Le patient est trop loin.' } end
    local cid = P.Cid(t)
    if not cid then return { error = 'Patient introuvable.' } end
    local c = Compute(cid, d.extras)
    c.patient = { id = t, name = P.Name(t) }
    return { bill = c }
end }

local billing = {}
P.Actions.billSend = { perm = 'billing', duty = true, fn = function(src, d)
    local t = tonumber(d.target)
    if not t or t == src or not GetPlayerName(t) then return { error = 'Patient introuvable.' } end
    if P.Dist(src, t) > Config.Distances.interact + 2.0 then return { error = 'Le patient est trop loin.' } end
    local cid = P.Cid(t)
    if not cid then return { error = 'Patient introuvable.' } end
    if billing[cid] then return { error = 'Une facture est déjà en cours pour ce patient.' } end
    billing[cid] = true
    local ok, res = pcall(function()
        -- Les prestations ajoutées à la main deviennent des actes enregistrés
        for _, id in ipairs(type(d.extras) == 'table' and d.extras or {}) do
            local s = ServiceDef(tostring(id))
            if s and s.enabled then P.AddTreatment(t, s.id, src) end
        end
        local c = Compute(cid, nil)
        if #c.items == 0 or c.total <= 0 then return { error = 'Aucun acte à facturer pour ce patient.' } end
        -- Montant vu par l'EMS dans l'aperçu : refus si les tarifs ont changé entre-temps
        if tonumber(d.expected) and tonumber(d.expected) ~= c.total then
            return { error = ('Le montant a changé (%d $) : vérifiez la facture.'):format(c.total), bill = c }
        end
        local uid = P.Uid('FAC')
        local method = P.Charge(t, c.total, ('Facture médicale %s'):format(uid))
        local status = method and 'paid' or 'failed'
        local txid
        if method then
            if not P.SocietyAdd(c.total, ('Facture %s · %s'):format(uid, P.Name(t))) then
                -- Société indisponible : le patient est remboursé, rien n'est facturé
                P.Refund(cid, c.total, method, 'Annulation facture ' .. uid)
                status, method = 'failed', nil
            else
                txid = P.Tx({ type = 'in', category = 'invoice', amount = c.total, reason = 'Facture médicale', actorCid = P.Cid(src), actorName = P.Name(src),
                    targetCid = cid, targetName = P.Name(t), ref = uid })
            end
        end
        MySQL.insert.await([[INSERT INTO `ems_invoices` (`uid`, `kind`, `patient_cid`, `patient_name`, `ems_cid`, `ems_name`, `items`, `mode`, `amount`, `status`, `method`, `txid`)
            VALUES (?, 'medical', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], { uid, cid, P.Name(t), P.Cid(src), P.Name(src), json.encode(c.items), c.mode, c.total, status, method, txid })
        if status ~= 'paid' then
            P.Notify(t, ('Facture médicale de %d $ refusée : fonds insuffisants.'):format(c.total), 'error')
            return { error = ('%s n\'a pas assez d\'argent (%d $). Facture %s refusée, les actes restent à facturer.'):format(P.Name(t), c.total, uid) }
        end
        if #c.treatmentIds > 0 then
            MySQL.update.await(('UPDATE `ems_treatments` SET `invoice_uid` = ? WHERE `id` IN (%s) AND `invoice_uid` IS NULL'):format(table.concat(c.treatmentIds, ',')), { uid })
        end
        P.Notify(t, ('Facture médicale %s : %d $ payés (%s).'):format(uid, c.total, method == 'cash' and 'liquide' or 'banque'), 'inform')
        P.Log(src, 'Facture médicale', ('%s · %d $ · %s'):format(P.Name(t), c.total, uid))
        return { ok = true, uid = uid, message = ('Facture %s payée : %d $.'):format(uid, c.total) }
    end)
    billing[cid] = nil
    if not ok then print(('^1[EMS] Facture : %s^0'):format(tostring(res))) return { error = 'Erreur pendant la facturation.' } end
    return res
end }

-- ---------------------------------------------------------------------
-- Gestion (Finance › Factures, Facturation)
-- ---------------------------------------------------------------------
local function CanSeeInvoices(src) return P.Can(src, 'billing_manage') or P.Can(src, 'finance') end

P.Actions.invoices = { perm = 'billing', fn = function(src, d)
    if not CanSeeInvoices(src) then return { error = 'Votre grade ne permet pas de voir les factures.' } end
    local where, args = {}, {}
    local st = tostring(d.status or '')
    if st:match('^%a+$') then where[#where + 1] = '`status` = ?' args[#args + 1] = st end
    local kind = tostring(d.kind or '')
    if kind == 'medical' or kind == 'ppa' then where[#where + 1] = '`kind` = ?' args[#args + 1] = kind end
    local q = P.Clean(d.q, 60):gsub('[%%_]', '')
    if q ~= '' then
        local like = '%' .. q .. '%'
        where[#where + 1] = '(`uid` LIKE ? OR `patient_name` LIKE ? OR `ems_name` LIKE ?)'
        args[#args + 1], args[#args + 2], args[#args + 3] = like, like, like
    end
    local rows = MySQL.query.await([[SELECT `uid`, `kind`, `patient_name`, `ems_name`, `items`, `mode`, `amount`, `status`, `method`, `txid`, `note`, `handled_by`,
        UNIX_TIMESTAMP(`created_at`) AS t FROM `ems_invoices`]] .. (#where > 0 and (' WHERE ' .. table.concat(where, ' AND ')) or '') .. ' ORDER BY `id` DESC LIMIT 150', args) or {}
    for _, r in ipairs(rows) do
        local okj, items = pcall(json.decode, r.items or '[]')
        r.items = okj and items or {}
    end
    return { list = rows, canManage = P.Can(src, 'billing_manage') }
end }

local refunding = {}
P.Actions.invoiceRefund = { perm = 'billing_manage', fn = function(src, d)
    local uid = tostring(d.uid or ''):sub(1, 40)
    if refunding[uid] then return { error = 'Opération déjà en cours.' } end
    refunding[uid] = true
    local ok, res = pcall(function()
        local inv = MySQL.single.await('SELECT * FROM `ems_invoices` WHERE `uid` = ?', { uid })
        if not inv then return { error = 'Facture introuvable.' } end
        local reason = P.Clean(d.reason, 160)
        if #reason < 3 then return { error = 'Indiquez le motif.' } end
        if inv.status == 'failed' then
            MySQL.update.await('UPDATE `ems_invoices` SET `status` = ?, `note` = ?, `handled_by` = ?, `updated_at` = NOW() WHERE `uid` = ?', { 'cancelled', reason, P.Name(src), uid })
            return { ok = true, message = 'Facture annulée (aucun argent n\'avait été pris).' }
        end
        if inv.status ~= 'paid' then return { error = 'Cette facture n\'est pas payée.' } end
        local amount = math.floor(tonumber(inv.amount) or 0)
        if not P.SocietyRemove(amount, ('Remboursement %s'):format(uid)) then return { error = ('Fonds insuffisants pour rembourser %d $.'):format(amount) } end
        local paid, target = P.Refund(inv.patient_cid, amount, inv.method, 'Remboursement facture ' .. uid)
        if not paid then
            P.SocietyAdd(amount, ('Annulation remboursement %s'):format(uid))
            return { error = 'Remboursement impossible sur le compte du patient : rien n\'a changé.' }
        end
        MySQL.update.await('UPDATE `ems_invoices` SET `status` = ?, `note` = ?, `handled_by` = ?, `updated_at` = NOW() WHERE `uid` = ?', { 'refunded', reason, P.Name(src), uid })
        P.Tx({ type = 'out', category = 'refund', amount = amount, reason = 'Remboursement : ' .. reason, actorCid = P.Cid(src), actorName = P.Name(src),
            targetCid = inv.patient_cid, targetName = inv.patient_name, ref = uid })
        if inv.kind == 'ppa' then MySQL.update('UPDATE `ems_ppa` SET `payment_status` = ?, `updated_at` = NOW() WHERE `invoice_uid` = ?', { 'refunded', uid }) end
        if target then P.Notify(target, ('Facture %s remboursée : %d $.'):format(uid, amount), 'success') end
        P.Log(src, 'Remboursement', ('%s · %d $ · %s'):format(uid, amount, reason))
        return { ok = true, message = ('Facture %s remboursée (%d $).'):format(uid, amount) }
    end)
    refunding[uid] = nil
    if not ok then print(('^1[EMS] Remboursement : %s^0'):format(tostring(res))) return { error = 'Erreur pendant le remboursement.' } end
    return res
end }

P.Actions.billingSettings = { perm = 'finance', fn = function(src)
    return { settings = P.BillingSettings(), canEdit = P.Can(src, 'billing_manage'), maxPrice = B.maxPrice }
end }

P.Actions.billingSave = { perm = 'billing_manage', fn = function(src, d)
    local mode = tostring(d.mode or '')
    if mode ~= 'service' and mode ~= 'flat' and mode ~= 'mixed' then return { error = 'Mode inconnu.' } end
    local flat = P.Int(d.flat, 0, B.maxPrice, nil)
    if not flat then return { error = 'Forfait invalide.' } end
    local services = {}
    local input = type(d.services) == 'table' and d.services or {}
    for _, def in ipairs(B.services) do
        local o = input[def.id]
        if type(o) == 'table' then
            local price = P.Int(o.price, 0, B.maxPrice, nil)
            if not price then return { error = ('Tarif invalide : %s.'):format(def.label) } end
            services[def.id] = { price = price, enabled = o.enabled == true }
        end
    end
    P.SetSetting('billing', { mode = mode, flat = flat, services = services })
    P.AddLog(src, nil, nil, 'Tarifs des soins', nil, nil, ('mode %s, forfait %d $'):format(mode, flat))
    return { ok = true, message = 'Tarifs enregistrés (appliqués aux prochaines factures).' }
end }
