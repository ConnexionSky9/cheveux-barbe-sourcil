-- =====================================================================
--  elyzea_lscustom - client : néons animés (tous les joueurs)
--  L'effet d'un véhicule est dans son « state bag » (neonFx) : chaque
--  joueur proche anime la couleur chez lui, tout le monde le voit.
-- =====================================================================
local L = LSC
local Preview = {}   -- [véhicule] = effet en aperçu dans le menu de personnalisation
local Active = {}    -- véhicules proches avec un effet

-- Pendant la personnalisation, l'aperçu prime (false = couleur fixe choisie)
function L.NeonFxOf(veh)
    local p = Preview[veh]
    if p ~= nil then return p or nil end
    return Entity(veh).state.neonFx
end

function L.SetPreviewFx(veh, fx) Preview[veh] = fx end

-- Couleur à l'instant t
local function HsvToRgb(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    local sectors = { { v, t, p }, { q, v, p }, { p, v, t }, { p, q, v }, { t, p, v }, { v, p, q } }
    local c = sectors[i % 6 + 1]
    return math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255)
end

local ELYZEA = { { 59, 111, 224 }, { 217, 181, 106 }, { 224, 67, 59 } }
local function Lerp(a, b, t) return math.floor(a + (b - a) * t) end

local function ColorFor(fx, time)
    if fx == 'rainbow' then
        return HsvToRgb((time * (Config.NeonSpeed or 0.12)) % 1.0, 1.0, 1.0)
    elseif fx == 'elyzea' then
        local pos = (time * 0.35) % #ELYZEA
        local i = math.floor(pos)
        local a, b = ELYZEA[i + 1], ELYZEA[(i + 1) % #ELYZEA + 1]
        local t = pos - i
        return Lerp(a[1], b[1], t), Lerp(a[2], b[2], t), Lerp(a[3], b[3], t)
    end
end

-- Recherche des véhicules à animer (1 fois par seconde)
CreateThread(function()
    while true do
        local pc = GetEntityCoords(PlayerPedId())
        local list = {}
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            local fx = L.NeonFxOf(veh)
            if fx and #(GetEntityCoords(veh) - pc) < (Config.NeonViewDistance or 120.0) then list[#list + 1] = { veh = veh, fx = fx } end
        end
        for veh in pairs(Preview) do if not DoesEntityExist(veh) then Preview[veh] = nil end end
        Active = list
        Wait(1000)
    end
end)

-- Animation (environ 30 images par seconde)
CreateThread(function()
    while true do
        if #Active > 0 then
            local time = GetGameTimer() / 1000.0
            for _, a in ipairs(Active) do
                if DoesEntityExist(a.veh) and IsVehicleNeonLightEnabled(a.veh, 0) then
                    local r, g, b = ColorFor(a.fx, time)
                    if r then SetVehicleNeonLightsColour(a.veh, r, g, b) end
                end
            end
            Wait(33)
        else
            Wait(500)
        end
    end
end)

-- ---------------------------------------------------------------------
-- Allumer / éteindre ses néons au volant (/neons ou touche à assigner)
-- ---------------------------------------------------------------------
local function HasNeons(veh)
    for i = 0, 3 do if IsVehicleNeonLightEnabled(veh, i) then return true end end
    return false
end

RegisterCommand('neons', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return L.Notify('Mets-toi au volant.', 'error') end
    local st = Entity(veh).state
    local on = HasNeons(veh)
    if not on and not st.neonOff then return L.Notify('Ce véhicule n\'a pas de néons : passe chez LsCustom.', 'error') end
    -- Le conducteur contrôle le véhicule : l'allumage est vu par tous
    for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, not on) end
    TriggerServerEvent('lscustom:server:neonOff', NetworkGetNetworkIdFromEntity(veh), on)
    L.Notify(on and 'Néons éteints.' or 'Néons allumés.', 'inform')
end, false)
RegisterKeyMapping('neons', 'Véhicule : allumer / éteindre les néons', 'keyboard', Config.Keys.neons or '')
