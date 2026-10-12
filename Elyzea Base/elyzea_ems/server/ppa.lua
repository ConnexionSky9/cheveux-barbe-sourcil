-- =====================================================================
--  ELYZEA EMS - serveur : délivrance des PPA (civil / force de l'ordre)
--  · Deux catégories seulement (Config.PPA.types). Prix et activation en base
--    (Finance › Gestion des PPA) ; un changement de prix ne touche que les
--    prochaines délivrances (le prix est copié dans chaque délivrance).
--  · Grades autorisés : permissions « ppa_civil » / « ppa_fdo ».
--  · Ordre : vérifications → paiement immédiat → remise du papier
--    (elyzea_papiers:GivePpa) → en cas d'échec de la remise, remboursement.
--    Un identifiant unique relie délivrance, facture et transaction.
-- =====================================================================
local P = Ems
local C = Config.PPA
local PERM = { civil = 'ppa_civil', fdo = 'ppa_fdo' }

function P.PpaSettings()
    local s = P.GetSetting('ppa', {})
    local out = {}
    for kind, def in pairs(C.types) do
        local o = type(s[kind]) == 'table' and s[kind] or {}
        out[kind] = { kind = kind, label = def.label, price = tonumber(o.price) or def.price, enabled = (o.enabled == nil) and def.enabled ~= false or o.enabled == true }
    end
    return out
end

local function Papiers() return GetResourceState('elyzea_papiers') == 'started' end

-- Vérifications communes (aperçu et délivrance). Renvoie target, type, erreur, avertissements
local function Check(src, d)
    local kind = tostring(d.kind or '')
    local def = C.types[kind]
    if not def then return nil, nil, 'Type de PPA inconnu.' end
    if not P.Can(src, PERM[kind]) then return nil, nil, ('Votre grade ne permet pas de délivrer le %s.'):format(def.label) end
    if C.requireDuty and not P.OnDuty(src) then return nil, nil, 'Prenez votre service pour délivrer un PPA.' end
    local t = tonumber(d.target)
    if not t or t == src or not GetPlayerName(t) or not P.GetPlayer(t) then return nil, nil, 'Bénéficiaire introuvable.' end
    if P.Dist(src, t) > Config.Distances.interact + 2.0 then return nil, nil, 'Le bénéficiaire est trop loin.' end
    if P.IsDown(t) then return nil, nil, 'Le bénéficiaire est inconscient.' end
    local set = P.PpaSettings()[kind]
    if not set.enabled then return nil, nil, ('La délivrance du %s est désactivée par la direction.'):format(def.label) end
    if not Papiers() then return nil, nil, 'Le système de papiers (elyzea_papiers) n\'est pas démarré.' end
    local cond = C.conditions or {}
    if kind == 'fdo' and type(cond.fdoJobs) == 'table' and #cond.fdoJobs > 0 then
        local job = P.GetPlayer(t).PlayerData.job
        local okJob = false
        for _, j in ipairs(cond.fdoJobs) do if job and job.name == j then okJob = true end end
        if not okJob then return nil, nil, 'Le PPA force de l\'ordre est réservé aux métiers autorisés (forces de l\'ordre).' end
    end
    if cond.noDuplicate then
        local ok, has = pcall(function() return exports.elyzea_papiers:HasPpa(t, kind) end)
        if ok and has then return nil, nil, ('Cette personne a déjà un %s sur elle.'):format(def.label) end
    end
    if cond.requireIdCard and cond.idCardItem then
        local ok, n = pcall(function() return exports.elyzea_inventory:Search(t, 'count', cond.idCardItem) end)
        if not ok or (tonumber(n) or 0) < 1 then return nil, nil, 'La personne doit avoir sa carte d\'identité sur elle.' end
    end
    return t, set
end

P.Actions.ppaPreview = { perm = nil, fn = function(src, d)
    local t, set, err = Check(src, d)
    if not t then return { error = err } end
    local g = P.Grade(src)
    return { recap = { target = t, name = P.Name(t), kind = set.kind, label = set.label, price = set.price, ems = P.Name(src), grade = g and g.name or '?',
        conditions = { duty = P.OnDuty(src), distance = true, enabled = set.enabled } } }
end }

local delivering = {}
P.Actions.ppaDeliver = { perm = nil, fn = function(src, d)
    local t, set, err = Check(src, d)
    if not t then return { error = err } end
    local cid = P.Cid(t)
    if delivering[cid] then return { error = 'Une délivrance est déjà en cours pour cette personne.' } end
    if tonumber(d.expected) and tonumber(d.expected) ~= set.price then
        return { error = ('Le prix a changé (%d $) : rouvrez le récapitulatif.'):format(set.price) }
    end
    delivering[cid] = true
    local ok, res = pcall(function()
        local uid = P.Uid('PPA')
        local name, g = P.Name(t), P.Grade(src)
        MySQL.insert.await([[INSERT INTO `ems_ppa` (`uid`, `citizenid`, `name`, `type`, `ems_cid`, `ems_name`, `ems_grade`, `price`, `payment_status`, `delivery_status`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', 'pending')]], { uid, cid, name, set.kind, P.Cid(src), P.Name(src), g and g.name, set.price })
        local function Upd(pay, del, extra)
            MySQL.update.await(('UPDATE `ems_ppa` SET `payment_status` = ?, `delivery_status` = ?, `updated_at` = NOW()%s WHERE `uid` = ?'):format(extra or ''), { pay, del, uid })
        end

        -- 1. Paiement immédiat
        local method, txid
        if set.price > 0 then
            method = P.Charge(t, set.price, ('%s %s'):format(set.label, uid))
            if not method then
                Upd('failed', 'cancelled')
                MySQL.insert.await([[INSERT INTO `ems_invoices` (`uid`, `kind`, `patient_cid`, `patient_name`, `ems_cid`, `ems_name`, `items`, `amount`, `status`)
                    VALUES (?, 'ppa', ?, ?, ?, ?, ?, ?, 'failed')]], { uid, cid, name, P.Cid(src), P.Name(src), json.encode({ { id = set.kind, label = set.label, price = set.price } }), set.price })
                P.Notify(t, ('%s : paiement refusé (%d $).'):format(set.label, set.price), 'error')
                return { error = ('%s n\'a pas assez d\'argent (%d $). Rien n\'a été délivré.'):format(name, set.price) }
            end
            if not P.SocietyAdd(set.price, ('%s %s · %s'):format(set.label, uid, name)) then
                P.Refund(cid, set.price, method, 'Annulation ' .. uid)
                Upd('refunded', 'cancelled')
                return { error = 'Compte de l\'entreprise indisponible : le bénéficiaire a été remboursé, rien n\'a été délivré.' }
            end
            txid = P.Tx({ type = 'in', category = 'ppa', amount = set.price, reason = set.label, actorCid = P.Cid(src), actorName = P.Name(src),
                targetCid = cid, targetName = name, ref = uid })
        end
        MySQL.insert.await([[INSERT INTO `ems_invoices` (`uid`, `kind`, `patient_cid`, `patient_name`, `ems_cid`, `ems_name`, `items`, `amount`, `status`, `method`, `txid`)
            VALUES (?, 'ppa', ?, ?, ?, ?, ?, ?, ?, ?, ?)]], { uid, cid, name, P.Cid(src), P.Name(src), json.encode({ { id = set.kind, label = set.label, price = set.price } }),
            set.price, set.price > 0 and 'paid' or 'free', method, txid })
        Upd(set.price > 0 and 'paid' or 'free', 'pending', ', `invoice_uid` = `uid`')

        -- 2. Remise du papier
        local okGive, given, msg, number = pcall(function() return exports.elyzea_papiers:GivePpa(src, t, set.kind) end)
        if not okGive or not given then
            local why = okGive and msg or 'erreur du système de papiers'
            -- 3. Compensation : remboursement intégral
            if set.price > 0 then
                local back = P.SocietyRemove(set.price, ('Remboursement %s (remise impossible)'):format(uid))
                local refunded = back and P.Refund(cid, set.price, method, 'Remboursement ' .. uid)
                if back and not refunded then P.SocietyAdd(set.price, ('Annulation remboursement %s'):format(uid)) end
                if refunded then
                    P.Tx({ type = 'out', category = 'refund', amount = set.price, reason = set.label .. ' non remis', actorName = 'Système', targetCid = cid, targetName = name, ref = uid })
                    MySQL.update.await('UPDATE `ems_invoices` SET `status` = ?, `note` = ?, `updated_at` = NOW() WHERE `uid` = ?', { 'refunded', P.Clean(why, 160), uid })
                    Upd('refunded', 'failed')
                else
                    Upd('paid', 'failed')
                    P.Log(src, 'PPA non remis, remboursement à faire', ('%s · %s · %d $'):format(uid, name, set.price))
                end
            else
                Upd('free', 'failed')
            end
            MySQL.update('UPDATE `ems_ppa` SET `reason` = ? WHERE `uid` = ?', { P.Clean(why, 160), uid })
            return { error = ('PPA non remis : %s%s'):format(tostring(why), set.price > 0 and ' Le paiement a été remboursé.' or '') }
        end
        MySQL.update.await('UPDATE `ems_ppa` SET `delivery_status` = ?, `number` = ?, `updated_at` = NOW() WHERE `uid` = ?', { 'delivered', number and tostring(number):sub(1, 20) or nil, uid })
        P.Log(src, 'PPA délivré', ('%s · %s · %d $ · %s'):format(name, set.label, set.price, uid))
        return { ok = true, uid = uid, number = number, message = ('%s remis à %s%s (%s).'):format(set.label, name, set.price > 0 and (' pour ' .. set.price .. ' $') or '', uid) }
    end)
    delivering[cid] = nil
    if not ok then print(('^1[EMS] PPA : %s^0'):format(tostring(res))) return { error = 'Erreur pendant la délivrance.' } end
    return res
end }

-- Historique (recherche)
P.Actions.ppaHistory = { perm = nil, fn = function(src, d)
    if not (P.Can(src, 'ppa_manage') or P.Can(src, 'finance') or P.Can(src, 'stats_view')) then return { error = 'Votre grade ne permet pas de voir l\'historique des PPA.' } end
    local where, args = {}, {}
    local kind = tostring(d.kind or '')
    if C.types[kind] then where[#where + 1] = '`type` = ?' args[#args + 1] = kind end
    local q = P.Clean(d.q, 60):gsub('[%%_]', '')
    if q ~= '' then
        local like = '%' .. q .. '%'
        where[#where + 1] = '(`uid` LIKE ? OR `name` LIKE ? OR `ems_name` LIKE ? OR `number` LIKE ?)'
        for _ = 1, 4 do args[#args + 1] = like end
    end
    return { list = MySQL.query.await([[SELECT `uid`, `name`, `type`, `ems_name`, `ems_grade`, `price`, `payment_status`, `delivery_status`, `number`, `reason`, `invoice_uid`,
        UNIX_TIMESTAMP(`created_at`) AS t FROM `ems_ppa`]] .. (#where > 0 and (' WHERE ' .. table.concat(where, ' AND ')) or '') .. ' ORDER BY `id` DESC LIMIT 150', args) or {} }
end }

P.Actions.ppaSettings = { perm = nil, fn = function(src)
    local list = {}
    for _, s in pairs(P.PpaSettings()) do list[#list + 1] = s end
    table.sort(list, function(a, b) return a.kind < b.kind end)
    local allowed = {}
    for _, g in ipairs(P.SortedGrades()) do
        allowed[#allowed + 1] = { name = g.name, level = g.level, civil = g.perms.ppa_civil == true, fdo = g.perms.ppa_fdo == true }
    end
    return { list = list, grades = allowed, canEdit = P.Can(src, 'ppa_manage'), canCivil = P.Can(src, 'ppa_civil'), canFdo = P.Can(src, 'ppa_fdo'),
        conditions = C.conditions, maxPrice = C.maxPrice, papiers = Papiers() }
end }

P.Actions.ppaSave = { perm = 'ppa_manage', fn = function(src, d)
    local out = {}
    for kind, def in pairs(C.types) do
        local o = type(d[kind]) == 'table' and d[kind] or {}
        local price = P.Int(o.price, 0, C.maxPrice, nil)
        if not price then return { error = ('Prix invalide : %s.'):format(def.label) } end
        out[kind] = { price = price, enabled = o.enabled == true }
    end
    P.SetSetting('ppa', out)
    P.AddLog(src, nil, nil, 'Réglages PPA', nil, nil, ('civil %d $ (%s), FDO %d $ (%s)'):format(out.civil.price, out.civil.enabled and 'actif' or 'inactif',
        out.fdo.price, out.fdo.enabled and 'actif' or 'inactif'))
    return { ok = true, message = 'Réglages PPA enregistrés (prochaines délivrances).' }
end }
