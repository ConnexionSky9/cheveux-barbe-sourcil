--[[
    Reprise des anciens inventaires : automatique.
    L'inventaire d'un personnage est lu dans players.inventory (même colonne que l'ancien
    inventaire du serveur) : à la première connexion, ses objets et armes sont repris tels quels.

    Commande console (facultative) :  elyzea_inventory_check
      liste les objets présents en base mais inconnus du catalogue (à ajouter dans data/items.lua).
]]

RegisterCommand('elyzea_inventory_check', function(source)
    if source ~= 0 then return end
    local rows = MySQL.query.await('SELECT `citizenid`, `inventory` FROM `players`') or {}
    local missing, total = {}, 0
    for _, row in ipairs(rows) do
        for _, it in ipairs(Shared.DecodeList(row.inventory)) do
            total = total + 1
            if it.name and not ResolveItemName(it.name) and not IgnoredItems[it.name] then
                missing[it.name] = (missing[it.name] or 0) + 1
            end
        end
    end
    print(('[elyzea_inventory] %d personnage(s), %d pile(s) d\'objets lues.'):format(#rows, total))
    local any = false
    for name, n in pairs(missing) do any = true print(('^3  objet inconnu : %s (%d fois)^0'):format(name, n)) end
    if not any then print('^2  Tous les objets sont connus du catalogue.^0') end
end, true)
