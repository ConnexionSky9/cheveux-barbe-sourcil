-- =====================================================================
--  ELYZEA LASERGAME - ARGENT RP (mises PVP uniquement)
--  * Le serveur vérifie le solde réel, débite lui-même et écrit chaque somme dans lg_ledger.
--  * Une ligne passe de « held » à paid / refunded / lost UNE SEULE FOIS (UPDATE ... WHERE status='held'),
--    le crédit n'a lieu qu'après ce passage : rejouer un paiement ne verse jamais deux fois.
--  * Aucun argent n'est créé : les gains sont le pot réellement débité (moins la commission éventuelle).
-- =====================================================================
Economy = {}

local ACC = function() return Config.Account == 'cash' and 'cash' or 'bank' end

-- Débit serveur avec contrôle du solde réel
function Economy.Debit(src, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    if Bridge.GetMoney(src, ACC()) < amount then return false end
    return Bridge.RemoveMoney(src, amount, reason, ACC())
end

-- Crédit : au joueur connecté qui joue ce personnage, sinon mis de côté pour sa prochaine connexion
function Economy.Credit(cid, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    local s = Bridge.SourceByCid(cid)
    if s and Bridge.AddMoney(s, amount, reason, ACC()) then return true, s end
    MySQL.insert.await('INSERT INTO `lg_pending` (`citizenid`, `amount`, `account`, `reason`) VALUES (?, ?, ?, ?)',
        { cid, amount, ACC(), tostring(reason or ''):sub(1, 120) })
    return true, nil
end

-- Mise conservée dans le pot logique de la partie : débit puis ligne « held » (rendue si l'écriture échoue)
function Economy.Hold(src, id, uid, team, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return nil end
    if not Economy.Debit(src, amount, ('LaserGame : mise %s'):format(uid)) then return nil end
    local ok, rowId = pcall(function()
        return MySQL.insert.await('INSERT INTO `lg_ledger` (`match_uid`, `citizenid`, `name`, `team`, `amount`, `account`) VALUES (?, ?, ?, ?, ?, ?)',
            { uid, id.cid, id.name:sub(1, 80), team, amount, ACC() })
    end)
    if not ok or not rowId then
        Bridge.AddMoney(src, amount, 'LaserGame : annulation de la mise', ACC())
        Logs.Add('error', 'écriture de la mise impossible : remboursée', { uid = uid, amount = amount }, src)
        return nil
    end
    Logs.Add('money', ('mise de %d $ (partie %s, équipe %s)'):format(amount, uid, tostring(team)), { row = rowId }, src)
    return rowId
end

-- Règlement d'une ligne : status 'paid' | 'refunded' | 'lost'
function Economy.Settle(rowId, cid, status, payout, reason)
    payout = math.max(0, math.floor(tonumber(payout) or 0))
    local n = MySQL.update.await('UPDATE `lg_ledger` SET `status` = ?, `payout` = ?, `settled_at` = NOW() WHERE `id` = ? AND `status` = \'held\'',
        { status, payout, rowId })
    if n ~= 1 then return false end   -- déjà réglée : jamais deux fois
    if payout > 0 then Economy.Credit(cid, payout, reason) end
    Logs.Add('money', ('ligne %s réglée : %s, %d $'):format(rowId, status, payout), { cid = cid, reason = reason })
    return true
end

-- Remboursement d'une seule mise (joueur qui quitte le lobby, se remet « pas prêt », changement de mise)
function Economy.RefundRow(rowId, why)
    local r = MySQL.single.await('SELECT `id`, `citizenid`, `amount` FROM `lg_ledger` WHERE `id` = ? AND `status` = \'held\'', { rowId })
    if not r then return false end
    return Economy.Settle(r.id, r.citizenid, 'refunded', r.amount, 'LaserGame : remboursement (' .. (why or 'mise') .. ')')
end

-- Remboursement de tout ce qui est encore en jeu pour une partie (annulation, égalité, erreur, redémarrage)
function Economy.RefundMatch(uid, why)
    local rows = MySQL.query.await('SELECT `id`, `citizenid`, `amount` FROM `lg_ledger` WHERE `match_uid` = ? AND `status` = \'held\'', { uid }) or {}
    local n = 0
    for _, r in ipairs(rows) do
        if Economy.Settle(r.id, r.citizenid, 'refunded', r.amount, 'LaserGame : remboursement (' .. (why or uid) .. ')') then
            n = n + 1
            local s = Bridge.SourceByCid(r.citizenid)
            if s then TriggerClientEvent('elyzea_lasergame:notify', s, ('Mise remboursée : %d $ (%s).'):format(r.amount, why or 'annulation'), 'info') end
        end
    end
    return n
end

-- Paiement de fin de partie : le pot (lignes « held ») est partagé entre les gagnants éligibles
--   winners : liste de citizenid (ordre = priorité pour le reste de la division)
-- Renvoie { [cid] = gain }, pot total, commission
function Economy.PayWinners(uid, winners)
    local rows = MySQL.query.await('SELECT `id`, `citizenid`, `amount` FROM `lg_ledger` WHERE `match_uid` = ? AND `status` = \'held\'', { uid }) or {}
    local pot = 0
    for _, r in ipairs(rows) do pot = pot + r.amount end
    local result = {}
    if pot <= 0 then return result, 0, 0 end
    -- gagnants éligibles = gagnants qui ont réellement une mise dans ce pot (un par ligne)
    local rowOf, eligible = {}, {}
    for _, r in ipairs(rows) do rowOf[r.citizenid] = r end
    for _, cid in ipairs(winners) do if rowOf[cid] then eligible[#eligible + 1] = cid end end
    if #eligible == 0 then
        Economy.RefundMatch(uid, 'aucun gagnant')
        return result, pot, 0
    end
    local isWinner = {}
    for _, cid in ipairs(eligible) do isWinner[cid] = true end
    local shares, fee = LGU.SplitPot(pot, #eligible, Config.Stake.houseFeePct or 0)
    -- 1) les mises perdantes sont closes d'abord ; 2) puis chaque gagnant reçoit sa part sur SA ligne.
    -- Un crash entre les deux ne crée jamais d'argent : les lignes gagnantes encore « held » seraient
    -- seulement remboursées au redémarrage.
    for _, r in ipairs(rows) do
        if not isWinner[r.citizenid] then Economy.Settle(r.id, r.citizenid, 'lost', 0, 'LaserGame : mise perdue') end
    end
    for i, cid in ipairs(eligible) do
        local amount = shares[i] or 0
        if Economy.Settle(rowOf[cid].id, cid, 'paid', amount, 'LaserGame : gain de la partie ' .. uid) then result[cid] = amount end
    end
    return result, pot, fee
end

-- Sommes mises de côté : versées à la connexion (ligne supprimée AVANT le crédit : jamais deux fois)
function Economy.PayPending(src)
    local id = Bridge.Identity(src)
    if not id then return end
    local rows = MySQL.query.await('SELECT `id`, `amount`, `account`, `reason` FROM `lg_pending` WHERE `citizenid` = ?', { id.cid }) or {}
    for _, r in ipairs(rows) do
        if MySQL.update.await('DELETE FROM `lg_pending` WHERE `id` = ?', { r.id }) == 1 then
            if Bridge.AddMoney(src, r.amount, 'LaserGame', r.account) then
                TriggerClientEvent('elyzea_lasergame:notify', src, ('LaserGame : %d $ versés (%s).'):format(r.amount, r.reason), 'success')
                Logs.Add('money', ('versement différé de %d $'):format(r.amount), { reason = r.reason }, src)
            else
                MySQL.insert.await('INSERT INTO `lg_pending` (`citizenid`, `amount`, `account`, `reason`) VALUES (?, ?, ?, ?)', { id.cid, r.amount, r.account, r.reason })
            end
        end
    end
end

-- Démarrage : toute mise encore « held » appartient à une partie interrompue (crash, redémarrage) → remboursée
function Economy.RecoverOnStart()
    local held = MySQL.query.await('SELECT DISTINCT `match_uid` FROM `lg_ledger` WHERE `status` = \'held\'') or {}
    for _, r in ipairs(held) do
        local n = Economy.RefundMatch(r.match_uid, 'partie interrompue par un redémarrage')
        MySQL.update('UPDATE `lg_matches` SET `status` = \'aborted\', `ended_at` = NOW() WHERE `uid` = ? AND `status` = \'running\'', { r.match_uid })
        Logs.Add('money', ('partie %s interrompue : %d mise(s) remboursée(s)'):format(r.match_uid, n))
    end
    MySQL.update('UPDATE `lg_matches` SET `status` = \'aborted\', `ended_at` = NOW() WHERE `status` = \'running\'')
end
