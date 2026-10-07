-- =====================================================================
--  elyzea_farm - client : PNJ, tenue, récolte (ALT dans les zones)
-- =====================================================================
local Farms = {}          -- réglages publics envoyés par le serveur
local working = nil       -- métier de farm en cours
local civilian = nil      -- vêtements avant la tenue de travail
local busy = false
local blips = {}
local uiOpen = false

local COMPS = { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local PROPS = { 0, 1, 2, 6, 7 }
local MALE, FEMALE = `mp_m_freemode_01`, `mp_f_freemode_01`

local function Notify(msg, kind) Ely.notify({ description = msg, type = kind or 'inform' }) end

-- ---------------------------------------------------------------------
-- Tenue
-- ---------------------------------------------------------------------
local function gender()
    local m = GetEntityModel(PlayerPedId())
    if m == FEMALE then return 'female' end
    return 'male'
end

local function snapshot()
    local ped = PlayerPedId()
    local o = { c = {}, p = {} }
    for _, c in ipairs(COMPS) do o.c[tostring(c)] = { GetPedDrawableVariation(ped, c), GetPedTextureVariation(ped, c) } end
    for _, p in ipairs(PROPS) do o.p[tostring(p)] = { GetPedPropIndex(ped, p), GetPedPropTextureIndex(ped, p) } end
    return o
end

local function apply(o)
    if type(o) ~= 'table' then return end
    local ped = PlayerPedId()
    for k, v in pairs(o.c or {}) do SetPedComponentVariation(ped, tonumber(k), v[1], v[2], 0) end
    for k, v in pairs(o.p or {}) do
        if v[1] == -1 then ClearPedProp(ped, tonumber(k)) else SetPedPropIndex(ped, tonumber(k), v[1], v[2], true) end
    end
end

-- Vêtements d'origine gardés aussi sur le PC du joueur (crash, redémarrage)
local function kvpKey()
    local ok, cid = pcall(function() return (exports.elyzea_core:GetPlayerData() or {}).citizenid end)
    return 'farm_civilian_' .. tostring(ok and cid or 'default')
end

local function putOn(outfit)
    if not civilian then
        civilian = snapshot()
        SetResourceKvp(kvpKey(), json.encode(civilian))
    end
    apply(outfit and outfit[gender()])
end

local function takeOff()
    local o = civilian
    if not o then
        local raw = GetResourceKvpString(kvpKey())
        o = raw and json.decode(raw) or nil
    end
    apply(o)
    civilian = nil
    DeleteResourceKvp(kvpKey())
end

-- Exporté pour le menu admin : copier la tenue portée
exports('CaptureOutfit', function() return snapshot(), gender() end)

-- ---------------------------------------------------------------------
-- Zones (icônes sur la carte pendant le travail)
-- ---------------------------------------------------------------------
local function clearBlips()
    for _, b in ipairs(blips) do RemoveBlip(b) end
    blips = {}
end

local function refreshBlips()
    clearBlips()
    local f = working and Farms[working]
    if not f then return end
    for _, z in ipairs(f.zones or {}) do
        if z.enabled ~= false then
            local r = AddBlipForRadius(z.x, z.y, z.z, (z.radius or 30.0) + 0.0)
            SetBlipColour(r, 25)
            SetBlipAlpha(r, 90)
            local b = AddBlipForCoord(z.x, z.y, z.z)
            SetBlipSprite(b, 85)
            SetBlipColour(b, 25)
            SetBlipScale(b, 0.8)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(('%s : %s'):format(f.label, z.label or 'zone'))
            EndTextCommandSetBlipName(b)
            blips[#blips + 1] = r
            blips[#blips + 1] = b
        end
    end
end

RegisterNetEvent('elyzea_farm:sync', function(data)
    Farms = type(data) == 'table' and data or {}
    refreshBlips()
end)

AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then TriggerServerEvent('elyzea_farm:requestSync') end
end)

-- Début / fin du travail
RegisterNetEvent('elyzea_farm:working', function(farm, outfit)
    if farm then
        working = farm
        putOn(outfit)
    else
        working = nil
        takeOff()
        Ely.hideTextUI()
    end
    refreshBlips()
end)

-- Personnage changé / déconnexion : la tenue est rendue
RegisterNetEvent('elyzea:client:playerUnloaded', function()
    if working then working = nil takeOff() refreshBlips() end
end)

-- Au chargement : vêtements restés en tenue de travail après un crash
RegisterNetEvent('elyzea:client:playerLoaded', function()
    SetTimeout(6000, function()
        if not working and GetResourceKvpString(kvpKey()) then takeOff() end
    end)
end)

-- ---------------------------------------------------------------------
-- Récolte
-- ---------------------------------------------------------------------
local ModelHashes = {}
for farm, cfg in pairs(Config.Farms) do
    ModelHashes[farm] = {}
    for _, m in ipairs(cfg.targetModels or {}) do ModelHashes[farm][#ModelHashes[farm] + 1] = joaat(m) end
end

local function inZone(f, c)
    for _, z in ipairs(f.zones or {}) do
        if z.enabled ~= false and #(vector2(c.x, c.y) - vector2(z.x, z.y)) <= (z.radius or 30.0) and math.abs(c.z - z.z) < 60.0 then return z end
    end
end

-- Cible devant le joueur : arbre posé à la main, ou arbre de la carte du jeu
local function findTarget(farm, f, c)
    local cfg = Config.Farms[farm]
    local dist = cfg.targetDistance or 3.0
    for _, p in ipairs(f.points or {}) do
        if #(c - vector3(p.x, p.y, p.z)) <= dist then return vector3(p.x, p.y, p.z) end
    end
    for _, h in ipairs(ModelHashes[farm]) do
        local obj = GetClosestObjectOfType(c.x, c.y, c.z, dist, h, false, false, false)
        if obj and obj ~= 0 then return GetEntityCoords(obj) end
    end
    if not f.requireTarget then return c + GetEntityForwardVector(PlayerPedId()) end
end

local function harvest(farm, f, target)
    busy = true
    Ely.hideTextUI()
    local cfg = Config.Farms[farm]
    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, target.x, target.y, target.z, 600)
    Wait(600)
    local done = Ely.progressBar({
        duration = math.floor((f.time or 8) * 1000), label = f.progress or cfg.progress, canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = cfg.anim, prop = cfg.prop,
    })
    ClearPedTasks(ped)
    if done then TriggerServerEvent('elyzea_farm:harvest') else Notify('Action annulée.', 'error') end
    Wait(300)
    busy = false
end

RegisterNetEvent('elyzea_farm:harvested', function(n)
    local cfg = working and Config.Farms[working]
    Notify(('+%d %s'):format(n, cfg and cfg.item == 'buche_bois' and (n > 1 and 'bûches de bois' or 'bûche de bois') or 'récolte'), 'success')
end)

CreateThread(function()
    local shown = false
    while true do
        local sleep = 800
        local f = working and Farms[working]
        if f and not busy and f.enabled ~= false and not uiOpen then
            local ped = PlayerPedId()
            local c = GetEntityCoords(ped)
            if not IsPedInAnyVehicle(ped, false) and not IsEntityDead(ped) and inZone(f, c) then
                local target = findTarget(working, f, c)
                if target then
                    sleep = 0
                    if not shown then
                        Ely.showTextUI(('[%s] %s'):format(Config.ActionKeyLabel, f.action or 'Récolter'))
                        shown = true
                    end
                    DisableControlAction(0, Config.ActionControl, true)
                    if IsDisabledControlJustPressed(0, Config.ActionControl) then
                        shown = false
                        harvest(working, f, target)
                    end
                else
                    sleep = 300
                end
            end
            if sleep ~= 0 and shown then Ely.hideTextUI() shown = false end
        elseif shown then
            Ely.hideTextUI()
            shown = false
        end
        Wait(sleep)
    end
end)

-- ---------------------------------------------------------------------
-- PNJ : fenêtre Elyzea (commencer / arrêter / vendre)
-- ---------------------------------------------------------------------
RegisterNetEvent('elyzea_farm:npc', function(data)
    if type(data) ~= 'table' then return end
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'npc', data = data })
end)
RegisterNetEvent('elyzea_farm:npcData', function(data)
    if uiOpen and type(data) == 'table' then SendNUIMessage({ action = 'npcData', data = data }) end
end)
RegisterNUICallback('work', function(body, cb) TriggerServerEvent('elyzea_farm:setWorking', body.state == true) cb('ok') end)
RegisterNUICallback('sell', function(_, cb) TriggerServerEvent('elyzea_farm:sell') cb('ok') end)
RegisterNUICallback('close', function(_, cb)
    uiOpen = false
    SetNuiFocus(false, false)
    TriggerServerEvent('elyzea_farm:close')
    cb('ok')
end)

RegisterNetEvent('elyzea_farm:teleport', function(z)
    DoScreenFadeOut(300)
    Wait(350)
    SetEntityCoords(PlayerPedId(), z.x + 0.0, z.y + 0.0, z.z + 0.0, false, false, false, false)
    Wait(300)
    DoScreenFadeIn(300)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearBlips()
    Ely.hideTextUI()
    if uiOpen then SetNuiFocus(false, false) end
    if working then takeOff() end
end)
