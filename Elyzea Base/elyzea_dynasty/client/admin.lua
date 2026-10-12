-- =====================================================================
--  ELYZEA DYNASTY 8 - client : Gestion immobilière (staff)
--  Ouverte depuis admin_menu (rubrique « Gestion immobilière ») ou /d8admin.
--  Le serveur revérifie la permission « property_manage » à chaque action.
--  Aperçu : tous les points des biens proches sont affichés avec leur nom.
-- =====================================================================
local C = D8C
local isOpen, preview = false, false

local function Close()
    if not isOpen then return end
    isOpen = false
    C.Focus('admin', false)
    SendNUIMessage({ action = 'admin', show = false })
end
C.ui.admin = { close = Close }

local function Open()
    if isOpen then return Close() end
    local r = C.Adm('data')
    if r.error then return C.Notify(r.error, 'error') end
    isOpen = true
    C.Focus('admin', true)
    SendNUIMessage({ action = 'admin', show = true, data = r, preview = preview })
end
RegisterNetEvent('d8:client:openAdmin', Open)
RegisterCommand('d8admin', Open, false)

RegisterNUICallback('adminPreview', function(body, cb) preview = body.on == true cb({ on = preview }) end)
-- Après une action qui demande de se déplacer (aller dans le bien, tester) : le panneau se ferme
RegisterNUICallback('adminHide', function(_, cb) cb({}) Close() end)

local function Label3D(p, text, col)
    SetDrawOrigin(p.x + 0.0, p.y + 0.0, p.z + 0.4, 0)
    SetTextScale(0.3, 0.3) SetTextFont(4) SetTextCentre(true) SetTextOutline()
    SetTextColour(col[1], col[2], col[3], 255)
    BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName(text) EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end
CreateThread(function()
    local COL = Config.Points.colors
    while true do
        if not preview or C.insideData then Wait(500) else
            local pc = GetEntityCoords(PlayerPedId())
            for _, pr in ipairs(C.props or {}) do
                local pts = { { pr.enter, 'Entrée', COL.enter }, { pr.bell, 'Sonnette', COL.bell }, { pr.garage and pr.garage.enter, 'Garage', COL.garage_enter } }
                for _, x in ipairs(pts) do
                    local p = x[1]
                    if p and #(pc - C.Vec(p)) < 60.0 then
                        C.Circle(p, x[3], p.r)
                        Label3D(p, ('#%d %s · %s%s'):format(pr.id, pr.name, x[2], p.on == false and ' (désactivé)' or ''), x[3])
                    end
                end
            end
            Wait(0)
        end
    end
end)
