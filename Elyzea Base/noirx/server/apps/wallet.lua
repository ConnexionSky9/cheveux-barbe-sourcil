--[[
    NOIR X — Portefeuille
    Affiche sur le téléphone l'argent sale (item d'inventaire) et l'argent propre,
    ainsi que les gains en attente de versement.
]]

Rpc.Register('wallet.get', { db = false, rate = { 10, 5 } }, function(src, ctx)
    if DB.driver ~= 'none' then Payouts.Deliver(src) end
    local w = Wallet.Get(src)
    return {
        dirty = w.dirty,
        clean = w.clean,
        pending = Payouts.Pending(ctx.charId),
        linked = { inventory = Inventory.IsConfigured(), economy = Economy.IsConfigured() },
    }
end)

--- Les autres ressources peuvent demander au téléphone de rafraîchir le portefeuille
--- (par ex. après un achat hors NOIR X).
exports('RefreshWallet', function(src)
    Push.ToSrc(tonumber(src), 'wallet:changed', {})
end)
