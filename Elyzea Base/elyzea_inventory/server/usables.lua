-- Objets utilisables de base. Depuis une autre ressource :
--   exports.elyzea_inventory:RegisterUsableItem('objet', function(source, item) ... return true end)
-- Retourner true consomme 1 unité ; false ou rien ne consomme pas.
-- Les objets avec « client = { status = ... } » (nourriture, boissons) sont gérés automatiquement.

RegisterUsableItem('bandage', function(src)
    TriggerClientEvent('elyzea_inv:effect', src, 'heal', 20)
    return true
end)

RegisterUsableItem('firstaid', function(src)
    TriggerClientEvent('elyzea_inv:effect', src, 'heal', 60)
    return true
end)

RegisterUsableItem('armour', function(src)
    TriggerClientEvent('elyzea_inv:effect', src, 'armour', 100)
    return true
end)

RegisterUsableItem('parachute', function(src)
    TriggerClientEvent('elyzea_inv:effect', src, 'parachute')
    return true
end)
