-- =========================================================
--  GESTION IMMOBILIÈRE (DYNASTY 8) - CLIENT
--  Bouton de l'onglet 🏠 du menu : ferme le menu et ouvre le panneau
--  d'administration de la ressource elyzea_dynasty (qui revérifie la
--  permission « property_manage » à chaque action).
-- =========================================================
RegisterNUICallback('d8_open', function(_, cb)
    cb('ok')
    if GetResourceState('elyzea_dynasty') ~= 'started' then
        return Notify('La ressource « elyzea_dynasty » n\'est pas démarrée.', 'error')
    end
    CloseMenu()
    Wait(150)
    TriggerEvent('d8:client:openAdmin')
end)

-- Nouveau logement créé depuis l'onglet : l'assistant de placement s'ouvre dessus
RegisterNetEvent('admin_menu:client:d8Select', function(id) SendNUIMessage({ action = 'd8Select', id = id }) end)

-- Rue actuelle (adresse proposée à la création d'un logement)
RegisterNUICallback('d8_street', function(_, cb)
    local c = GetEntityCoords(PlayerPedId())
    local s1, s2 = GetStreetNameAtCoord(c.x, c.y, c.z)
    local a, b = GetStreetNameFromHashKey(s1), s2 ~= 0 and GetStreetNameFromHashKey(s2) or ''
    local zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
    local street = a ~= '' and a or zone
    if b ~= '' then street = street .. ' / ' .. b end
    if zone ~= '' and zone ~= 'NULL' and street ~= zone then street = street .. ', ' .. zone end
    cb({ street = street })
end)
