-- =====================================================================
--  ELYZEA PRESSE - client : affichage des annonces commandées (tous les joueurs)
--  Le serveur envoie UNE annonce à la fois (file d'attente centrale) ; elle s'affiche
--  juste au-dessus de la mini-carte (rectangle réel donné par admin_menu) pendant la
--  durée réglée dans admin_menu, puis disparaît.
-- =====================================================================
local function MinimapRect()
    if GetResourceState('admin_menu') == 'started' then
        local ok, r = pcall(function() return exports.admin_menu:GetMinimapRect() end)
        if ok and type(r) == 'table' and tonumber(r.x) and tonumber(r.y) and tonumber(r.w) then return { x = r.x, y = r.y, w = r.w, h = r.h } end
    end
    return nil   -- position par défaut de l'interface (bas gauche)
end

RegisterNetEvent('presse:client:annonce', function(a)
    if type(a) ~= 'table' then return end
    SendNUIMessage({ action = 'annonce', show = true, agency = a.agency, color = a.color, text = a.text, seconds = tonumber(a.seconds) or 10, rect = MinimapRect() })
end)
