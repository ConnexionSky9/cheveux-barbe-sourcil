-- =====================================================================
--  ELYZEA LASERGAME - STAFF (client)
--  /lgadmin ouvre l'onglet staff de l'interface (le serveur revérifie la permission à chaque action).
--  Aperçu d'une arène (zone + apparitions pendant 60 s) : client/maps.lua › adminShowArena.
-- =====================================================================
RegisterNetEvent('elyzea_lasergame:openAdmin', function()
    if C.uiOpen then C.UI('tab', 'admin') return end
    C.OpenUI('admin', true)
end)

RegisterNetEvent('elyzea_lasergame:adminTeleport', function(p)
    if C.inGame then return end
    C.CloseUI()
    C.Fade(true, 300)
    C.PlaceAt(p, p.h)
    C.Fade(false, 400)
end)
