--[[
    ELYZEA CORE — client
    Événements diffusés aux autres ressources :
      elyzea:client:playerLoaded (PlayerData)   personnage apparu en jeu
      elyzea:client:playerUnloaded               retour à la sélection des personnages
      elyzea:client:setPlayerData (PlayerData)   données mises à jour
      elyzea:client:onJobUpdate (job)  elyzea:client:onGangUpdate (gang)  elyzea:client:setDuty (bool)
      elyzea:client:onMoneyChange (type, montant, 'add'|'remove', raison)
]]

PlayerData = {}
local loaded = false

RegisterNetEvent('elyzea:client:setPlayerData', function(data)
    if type(data) ~= 'table' then return end
    PlayerData = data
end)

RegisterNetEvent('elyzea:client:playerLoaded', function(data)
    if type(data) == 'table' then PlayerData = data end
    loaded = true
end)

RegisterNetEvent('elyzea:client:playerUnloaded', function()
    loaded = false
    PlayerData = {}
end)

RegisterNetEvent('elyzea:client:onJobUpdate', function(job) if PlayerData then PlayerData.job = job end end)
RegisterNetEvent('elyzea:client:onGangUpdate', function(gang) if PlayerData then PlayerData.gang = gang end end)
RegisterNetEvent('elyzea:client:setDuty', function(state) if PlayerData and PlayerData.job then PlayerData.job.onduty = state end end)

exports('GetPlayerData', function() return PlayerData end)
exports('IsLoggedIn', function() return loaded end)
exports('GetJob', function() return PlayerData.job end)
exports('GetGang', function() return PlayerData.gang end)
exports('GetMoney', function(kind) return PlayerData.money and PlayerData.money[kind or 'cash'] or 0 end)
exports('GetCitizenId', function() return PlayerData.citizenid end)
exports('HasGroup', function(name, minGrade)
    local j, g = PlayerData.job, PlayerData.gang
    if j and j.name == name and (j.grade.level or 0) >= (minGrade or 0) then return true end
    if g and g.name == name and (g.grade.level or 0) >= (minGrade or 0) then return true end
    return false
end)

-- Liste des métiers (labels, grades) pour l'affichage
exports('GetJobs', function() return GlobalState.elyzeaJobs or {} end)

-- Redémarrage de la ressource avec un joueur déjà connecté
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    if NetworkIsSessionStarted() then TriggerServerEvent('elyzea:server:requestPlayerData') end
end)

-- ─────────── Apparition (remplace spawnmanager) ───────────

local function loadModel(model)
    model = type(model) == 'string' and joaat(model) or model
    if not model or not IsModelInCdimage(model) then return nil end
    RequestModel(model)
    local t = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
    return HasModelLoaded(model) and model or nil
end

-- SpawnPlayer({ x, y, z, w }, modèle facultatif) : place et réanime le joueur proprement
function SpawnPlayer(coords, model)
    local x, y, z = coords.x + 0.0, coords.y + 0.0, coords.z + 0.0
    local h = (coords.w or coords.h or coords.heading or 0.0) + 0.0
    local pid = PlayerId()
    if model then
        local m = loadModel(model)
        if m and GetEntityModel(PlayerPedId()) ~= m then
            SetPlayerModel(pid, m)
            SetModelAsNoLongerNeeded(m)
        end
    end
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    NetworkResurrectLocalPlayer(x, y, z, h, true, true)
    ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    ClearPlayerWantedLevel(pid)
    SetEntityHeading(ped, h)
    local t = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do Wait(0) end
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    if GetIsLoadingScreenActive() then
        ShutdownLoadingScreen()
        ShutdownLoadingScreenNui()
    end
    return ped
end
exports('SpawnPlayer', SpawnPlayer)

-- Signale au serveur que le personnage est en jeu (appelé par ely_creator après l'apparition)
exports('SetPlayerLoaded', function() TriggerServerEvent('elyzea:server:onPlayerLoaded') end)

RegisterNetEvent('elyzea:client:restoreStatus', function(health, armor)
    local ped = PlayerPedId()
    health = tonumber(health)
    if health and health > 100 and health <= GetEntityMaxHealth(ped) then SetEntityHealth(ped, health) end
    if tonumber(armor) then SetPedArmour(ped, math.floor(armor)) end
end)

-- ─────────── Faim / soif ───────────

RegisterNetEvent('elyzea:client:needs', function(hunger, thirst)
    if PlayerData.metadata then
        PlayerData.metadata.hunger = hunger
        PlayerData.metadata.thirst = thirst
    end
    TriggerEvent('hud:client:UpdateNeeds', hunger, thirst)
end)

RegisterNetEvent('elyzea:client:starving', function(damage)
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return end
    SetEntityHealth(ped, math.max(0, GetEntityHealth(ped) - (tonumber(damage) or 0)))
end)

-- ─────────── Monde ───────────

CreateThread(function()
    local pid = PlayerId()
    while true do
        if Config.DisableWantedLevel then
            if GetPlayerWantedLevel(pid) ~= 0 then
                SetPlayerWantedLevel(pid, 0, false)
                SetPlayerWantedLevelNow(pid, false)
            end
        end
        Wait(1000)
    end
end)

CreateThread(function()
    if Config.DisableDispatch then
        for i = 1, 15 do EnableDispatchService(i, false) end
        SetAudioFlag('PoliceScannerDisabled', true)
    end
    SetMaxWantedLevel(Config.DisableWantedLevel and 0 or 5)
    if Config.DisableHealthRegen then SetPlayerHealthRechargeMultiplier(PlayerId(), 0.0) end
    NetworkSetFriendlyFireOption(Config.PvP)
    SetCanAttackFriendly(PlayerPedId(), Config.PvP, false)
end)
