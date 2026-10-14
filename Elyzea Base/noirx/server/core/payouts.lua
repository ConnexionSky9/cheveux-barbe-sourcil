--[[
    NOIR X — File de paiements « exactement une fois »
    Tout gain (fin de blanchiment, butin de piratage, remboursement…) est d'abord écrit
    dans noirx_payouts (statut 'pending'), puis versé via les adaptateurs.

    Cycle d'un paiement :
      pending ──(réservation atomique)──► processing ──(adaptateur OK)──► paid
                                              └──(adaptateur refuse)──► pending (nouvel essai plus tard)
    Si le serveur s'arrête pendant 'processing', la ligne reste 'processing' et est
    signalée au staff (AdminListStuckPayouts) au lieu d'être rejouée : on préfère une
    vérification manuelle à un double paiement.

    Les paiements en attente sont versés quand le joueur ouvre son téléphone, consulte
    son portefeuille, ou toutes les 60 s s'il est connecté.
]]

Payouts = {}

--- Enregistre un paiement puis tente de le verser immédiatement si le joueur est connecté.
--- @param currency 'dirty'|'clean'
--- @return number|nil id du paiement
function Payouts.Queue(charId, currency, amount, reason, ref)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or not charId then return nil end
    if currency ~= 'dirty' and currency ~= 'clean' then return nil end
    local id = DB.Insert(
        'INSERT INTO noirx_payouts (owner, currency, amount, reason, ref, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { charId, currency, amount, reason, ref, 'pending', os.time() })
    Audit.Log(0, 'payout.queued', { owner = charId, currency = currency, amount = amount, reason = reason, ref = ref })
    local src = Players.SrcOf(charId)
    if src then Payouts.Deliver(src) end
    return id
end

--- Verse tous les paiements en attente du joueur. Retourne le nombre versé.
function Payouts.Deliver(src)
    local charId = Players.CharOf(src)
    if not charId or DB.driver == 'none' then return 0 end
    local ok, count = Locks.Run('payout:' .. charId, function()
        local rows = DB.Query('SELECT id, currency, amount, reason FROM noirx_payouts WHERE owner = ? AND status = ? ORDER BY id ASC LIMIT 25',
            { charId, 'pending' })
        local paid = 0
        for _, row in ipairs(rows) do
            local claimed = DB.Execute('UPDATE noirx_payouts SET status = ? WHERE id = ? AND status = ?',
                { 'processing', row.id, 'pending' })
            if claimed == 1 then
                if Wallet.Credit(src, row.currency, row.amount, row.reason) then
                    DB.Execute('UPDATE noirx_payouts SET status = ?, paid_at = ? WHERE id = ?', { 'paid', os.time(), row.id })
                    Audit.Log(src, 'payout.paid', { id = row.id, currency = row.currency, amount = row.amount })
                    paid = paid + 1
                else
                    DB.Execute('UPDATE noirx_payouts SET status = ? WHERE id = ?', { 'pending', row.id })
                end
            end
        end
        return paid
    end)
    if ok and count and count > 0 then
        Push.ToSrc(src, 'wallet:changed', {})
    end
    return (ok and count) or 0
end

--- Total en attente par devise, pour l'affichage.
function Payouts.Pending(charId)
    local out = { dirty = 0, clean = 0 }
    if not charId or DB.driver == 'none' then return out end
    local rows = DB.Query('SELECT currency, SUM(amount) AS total FROM noirx_payouts WHERE owner = ? AND status = ? GROUP BY currency',
        { charId, 'pending' })
    for _, r in ipairs(rows) do
        if out[r.currency] then out[r.currency] = math.floor(tonumber(r.total) or 0) end
    end
    return out
end

CreateThread(function()
    while true do
        Wait(60000)
        if DB.driver ~= 'none' then
            for src in pairs(Players.cache) do
                if GetPlayerName(src) then Payouts.Deliver(src) end
            end
        end
    end
end)
