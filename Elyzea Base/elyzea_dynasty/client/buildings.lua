-- =====================================================================
--  ELYZEA DYNASTY 8 - client : immeubles
--  E sur le point d'un immeuble → interface (DA Elyzea) avec tous ses appartements :
--  entrer (propriétaire, locataire, accès donné), saisir le code, sonner, entrée staff.
--  Tout est vérifié par le serveur (server/buildings.lua → server/access.lua).
-- =====================================================================
local C = D8C
local BCFG = Config.Buildings or {}
local current = nil      -- immeuble ouvert

local function Close()
    if not current then return end
    current = nil
    C.Focus('building', false)
    SendNUIMessage({ action = 'building', show = false })
end
C.ui.building = { close = Close }

function C.OpenBuilding(b)
    if current or C.insideData then return end
    local r = C.Pub('building', { id = b.id })
    if r.error then return C.Notify(r.error, 'error') end
    current = { id = b.id, pos = vector3(b.x + 0.0, b.y + 0.0, b.z + 0.0), r = b.r or 1.6 }
    C.Focus('building', true)
    SendNUIMessage({ action = 'building', show = true, data = r })
end

RegisterNUICallback('building', function(body, cb)
    if not current then return cb({ error = 'Fermé.' }) end
    local a = tostring(body.do_ or '')
    if a == 'refresh' then
        local r = C.Pub('building', { id = current.id })
        if r.error then Close() end
        return cb(r)
    end
    local r = C.Pub('buildingDo', { id = current.id, pid = tonumber(body.pid), do_ = a, code = tostring(body.code or '') })
    if r.ok and (a == 'enter' or a == 'code' or a == 'staff') then Close() end
    if r.ok and a == 'bell' and r.message then C.Notify(r.message, 'inform') end
    cb(r)
end)

-- Fermeture si le joueur s'éloigne de la porte de l'immeuble
CreateThread(function()
    while true do
        if current then
            if #(GetEntityCoords(PlayerPedId()) - current.pos) > current.r + 4.0 or C.insideData then Close() end
            Wait(400)
        else Wait(1000) end
    end
end)

-- Blips des immeubles
local blips = {}
function C.RefreshBuildingBlips()
    for _, x in ipairs(blips) do if DoesBlipExist(x) then RemoveBlip(x) end end
    blips = {}
    local bc = BCFG.blip or {}
    for _, b in ipairs(C.buildings or {}) do
        if b.blip then
            local x = AddBlipForCoord(b.x + 0.0, b.y + 0.0, b.z + 0.0)
            SetBlipSprite(x, bc.sprite or 475) SetBlipColour(x, bc.color or 27) SetBlipScale(x, bc.scale or 0.75) SetBlipAsShortRange(x, true)
            BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(b.name) EndTextCommandSetBlipName(x)
            blips[#blips + 1] = x
        end
    end
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, x in ipairs(blips) do if DoesBlipExist(x) then RemoveBlip(x) end end
end)
