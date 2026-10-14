--[[
    NOIR X — Verrous mémoire
    Empêche qu'une même opération sensible (paiement, transfert, résolution de duel…)
    s'exécute deux fois en parallèle pour la même clé, par exemple si un client
    renvoie la même requête très vite.
      local ok = Locks.Run('pay:' .. charId, function() ... end)
      → false, 'busy' si la clé est déjà verrouillée
]]

Locks = { held = {} }

function Locks.Run(key, fn, ...)
    if Locks.held[key] then return false, 'busy' end
    Locks.held[key] = true
    local results = table.pack(pcall(fn, ...))
    Locks.held[key] = nil
    if not results[1] then
        NoirX.Error(('Erreur sous verrou %s : %s'):format(key, tostring(results[2])))
        return false, 'error'
    end
    return true, table.unpack(results, 2, results.n)
end
