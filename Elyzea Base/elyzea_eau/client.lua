-- /eau_ajouter [taille] [hauteur] : debout au milieu de l'endroit qui doit avoir de l'eau
-- /eau_annuler : retire la dernière zone ajoutée   /eau_liste : zones ajoutées
RegisterCommand('eau_ajouter', function(_, args)
    local c = GetEntityCoords(PlayerPedId())
    local ok, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 2.0, false)
    TriggerServerEvent('elyzea_eau:add', tonumber(args[1]), tonumber(args[2]), ok and gz or nil)
end, false)
RegisterCommand('eau_annuler', function() TriggerServerEvent('elyzea_eau:undo') end, false)
RegisterCommand('eau_liste', function() TriggerServerEvent('elyzea_eau:list') end, false)
