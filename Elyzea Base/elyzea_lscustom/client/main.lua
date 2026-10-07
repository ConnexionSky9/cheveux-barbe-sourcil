-- =====================================================================
--  elyzea_lscustom - client : état commun et zones
-- =====================================================================
LSC = { cfg = nil, busy = false }
local L = LSC
local blips = {}

local ZONE_COLORS = {}
for _, z in ipairs(Config.ZoneTypes) do ZONE_COLORS[z.key] = z.color end

function L.Notify(msg, kind)
    lib.notify({ description = msg, type = kind == 'inform' and 'inform' or kind or 'inform' })
end

function L.Job()
    local pd = exports.qbx_core:GetPlayerData()
    return pd and pd.job or nil
end

function L.IsMechanic()
    local j = L.Job()
    return j ~= nil and L.cfg ~= nil and j.name == L.cfg.job.name
end

function L.OnDuty()
    local j = L.Job()
    return L.IsMechanic() and j.onduty == true
end

function L.Grade()
    local j = L.Job()
    return j and j.grade and j.grade.level or 0
end

function L.Can(perm)
    if not L.cfg or not L.cfg.enabled or not L.OnDuty() then return false end
    local p = L.cfg.perms[tostring(L.Grade())] or {}
    return p[perm] == true
end

function L.Plate(veh)
    local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '')
    return plate
end

-- Véhicule le plus proche (le sien s'il est dedans)
function L.ClosestVehicle(max)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return GetVehiclePedIsIn(ped, false) end
    local veh = lib.getClosestVehicle(GetEntityCoords(ped), max or 5.0, false)
    return veh
end

-- Prendre le contrôle réseau du véhicule (nécessaire pour le modifier)
function L.Control(veh)
    if NetworkHasControlOfEntity(veh) then return true end
    NetworkRequestControlOfEntity(veh)
    local t = GetGameTimer()
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() - t < 2000 do
        Wait(50)
        NetworkRequestControlOfEntity(veh)
    end
    return NetworkHasControlOfEntity(veh)
end

-- Personnalisation : le mécano peut être AU VOLANT (il contrôle alors le véhicule),
-- sinon le véhicule doit être vide
function L.CanModifyFrom(veh)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        if GetVehiclePedIsIn(ped, false) ~= veh or GetPedInVehicleSeat(veh, -1) ~= ped then
            L.Notify('Mets-toi au volant du véhicule pour le personnaliser.', 'error')
            return false
        end
        return true
    end
    return L.EmptyForWork(veh)
end

-- Le véhicule doit être vide (sauf le mécanicien lui-même)
function L.EmptyForWork(veh)
    for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
        local p = GetPedInVehicleSeat(veh, seat)
        if p ~= 0 and p ~= PlayerPedId() then
            L.Notify('Fais descendre les occupants du véhicule avant de travailler dessus.', 'error')
            return false
        end
    end
    if not L.Control(veh) then
        L.Notify('Impossible de prendre la main sur ce véhicule, réessaie.', 'error')
        return false
    end
    return true
end

-- ---------------------------------------------------------------------
-- Synchronisation
-- ---------------------------------------------------------------------
local function RefreshBlips()
    for _, b in ipairs(blips) do RemoveBlip(b) end
    blips = {}
    if not L.cfg or not L.cfg.settings.showBlips then return end
    for _, z in ipairs(L.cfg.zones) do
        if z.type == 'modification' and z.enabled ~= false then
            local b = AddBlipForCoord(z.x, z.y, z.z)
            SetBlipSprite(b, 72)
            SetBlipColour(b, L.cfg.enabled and 47 or 39)
            SetBlipScale(b, 0.8)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(L.cfg.job.label .. (L.cfg.enabled and '' or ' (fermé)'))
            EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
    end
end

RegisterNetEvent('lscustom:client:sync', function(cfg)
    L.cfg = cfg
    RefreshBlips()
    TriggerEvent('lscustom:client:configChanged')
end)

RegisterNetEvent('lscustom:client:notify', function(msg, kind) L.Notify(msg, kind) end)

RegisterNetEvent('lscustom:client:teleport', function(z)
    DoScreenFadeOut(300)
    Wait(350)
    SetEntityCoords(PlayerPedId(), z.x + 0.0, z.y + 0.0, z.z + 0.0, false, false, false, false)
    if z.h then SetEntityHeading(PlayerPedId(), z.h + 0.0) end
    Wait(300)
    DoScreenFadeIn(300)
end)

AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then TriggerServerEvent('lscustom:server:requestSync') end
end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() TriggerServerEvent('lscustom:server:requestSync') end)

-- ---------------------------------------------------------------------
-- Zones : marqueurs et touche E
-- ---------------------------------------------------------------------
local function Help(text)
    lib.showTextUI(text, { position = 'left-center' })
end

local HELP = {
    service = function() return L.OnDuty() and '[E] Terminer le service' or '[E] Prendre le service' end,
    vestiaire = function() return '[E] Vestiaire' end,
    garage = function() return L.Can('garage') and '[E] Véhicules de service' or nil end,
    parking = function() return (IsPedInAnyVehicle(PlayerPedId(), false) and L.OnDuty()) and '[E] Ranger le véhicule' or nil end,
    modification = function()
        if L.busy or not L.Can('modify') or not L.ClosestVehicle(5.0) then return nil end
        return '[E] Personnaliser le véhicule'
    end,
    reparation = function()
        if L.busy or not L.Can('repair') or not L.ClosestVehicle(5.0) then return nil end
        return '[E] Réparer le véhicule'
    end,
    nettoyage = function()
        if L.busy or not L.Can('clean') or not L.ClosestVehicle(5.0) then return nil end
        return '[E] Nettoyer le véhicule'
    end,
}

local shown = nil
CreateThread(function()
    while true do
        local sleep = 1000
        local text = nil
        local zone = nil
        if L.cfg and L.IsMechanic() then
            local pc = GetEntityCoords(PlayerPedId())
            for _, z in ipairs(L.cfg.zones) do
                if z.enabled ~= false then
                    local d = #(pc - vector3(z.x, z.y, z.z))
                    if d < 30.0 and (L.OnDuty() or z.type == 'service' or z.type == 'vestiaire') then
                        sleep = 0
                        local c = ZONE_COLORS[z.type] or { 255, 255, 255 }
                        local r = (z.radius or 2.0) * 2.0
                        DrawMarker(1, z.x, z.y, z.z - 0.98, 0, 0, 0, 0, 0, 0, r, r, 0.35, c[1], c[2], c[3], 70, false, false, 2, false, nil, nil, false)
                        if d <= (z.radius or 2.0) + 0.5 and not text and HELP[z.type] then
                            text = HELP[z.type]()
                            if text then zone = z end
                        end
                    end
                end
            end
        end
        if text ~= shown then
            if text then Help(text) else lib.hideTextUI() end
            shown = text
        end
        if zone and IsControlJustPressed(0, 38) then TriggerEvent('lscustom:client:zoneAction', zone) Wait(400) end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then lib.hideTextUI() end
end)
