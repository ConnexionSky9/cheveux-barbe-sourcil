-- =====================================================================
--  JEWELRY HEIST - client : alerte police interne (si elyzea_police n'est pas utilisé)
--  Envoyée par le serveur aux seuls policiers en service : notification + blip + zone.
-- =====================================================================
local C = JHC

RegisterNetEvent('jh:client:policeAlert', function(a)
    if type(a) ~= 'table' or not a.coords then return end
    local b = a.blip or {}
    local x, y, z = a.coords.x + 0.0, a.coords.y + 0.0, a.coords.z + 0.0
    if a.notify ~= false then
        C.Notify(('%s\n%s'):format(a.title or 'Braquage de bijouterie', a.desc or ''), 'error')
        PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
    end
    local blip = AddBlipForCoord(x, y, z)
    SetBlipSprite(blip, b.sprite or 617) SetBlipColour(blip, b.color or 1) SetBlipScale(blip, (b.scale or 1.2) + 0.0)
    SetBlipFlashes(blip, b.flash ~= false)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(a.title or 'Braquage de bijouterie') EndTextCommandSetBlipName(blip)
    local radius
    if (b.radius or 0) > 0 then
        radius = AddBlipForRadius(x, y, z, b.radius + 0.0)
        SetBlipColour(radius, b.radiusColor or 1) SetBlipAlpha(radius, 90)
    end
    SetNewWaypoint(x, y)
    SetTimeout(math.floor((b.duration or 180) * 1000), function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        if radius and DoesBlipExist(radius) then RemoveBlip(radius) end
    end)
end)
