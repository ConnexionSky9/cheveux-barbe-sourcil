-- =====================================================================
--  ELYZEA BOÎTE DE NUIT - client : panneau d'administration (staff)
--  Ouvert par admin_menu › Boîtes de nuit ou /clubadmin. Chaque action
--  est revérifiée par le serveur (permissions « Boîtes de nuit » du menu admin).
-- =====================================================================
local C = CLC
local isOpen = false

local function Close()
    if not isOpen then return end
    isOpen = false
    C.Focus('admin', false)
    SendNUIMessage({ action = 'admin', show = false })
end
C.ui.admin = { close = Close }

local function Open()
    if isOpen then return end
    local r = C.Adm('data')
    if r.error then return C.Notify(r.error, 'error') end
    isOpen = true
    C.Focus('admin', true)
    SendNUIMessage({ action = 'admin', show = true, data = r })
end
RegisterNetEvent('club:client:openAdmin', Open)
RegisterCommand('clubadmin', Open, false)

-- Placer un point : il est pris à la position actuelle du staff (le panneau reste ouvert).
RegisterNUICallback('admReload', function(_, cb) cb(C.Adm('data')) end)
