--[[
    GO FAST - Récompenses & framework (serveur uniquement)
    * Bridge : ESX / QBCore (Qbox via compat qb-core) / standalone
    * Stockage XP : KVP (sans base) ou oxmysql
    * Calcul de la récompense finale : base, niveau, rapidité, checkpoints, dégâts
]]

local U = GoFast.Utils

-- =========================================================================
-- BRIDGE FRAMEWORK
-- =========================================================================
Bridge = { framework = 'standalone' }
local ESX, QBCore = nil, nil

do
    local framework = Config.Framework
    if framework == 'auto' then
        if GetResourceState('es_extended') == 'started' then
            framework = 'esx'
        elseif GetResourceState('qb-core') == 'started' or GetResourceState('qbx_core') == 'started' then
            framework = 'qbcore'
        else
            framework = 'standalone'
        end
    end

    if framework == 'esx' then
        local ok, object = pcall(function() return exports['es_extended']:getSharedObject() end)
        if ok and object then
            ESX = object
        else
            print('^1[gofast] es_extended introuvable : passage en standalone^0')
            framework = 'standalone'
        end
    elseif framework == 'qbcore' then
        local ok, object = pcall(function() return exports['qb-core']:GetCoreObject() end)
        if ok and object then
            QBCore = object
        else
            print('^1[gofast] qb-core introuvable : passage en standalone^0')
            framework = 'standalone'
        end
    end

    Bridge.framework = framework
    print(('^2[gofast] Framework détecté : %s^0'):format(framework))
end

function Bridge.GetLicense(src)
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:sub(1, 8) == 'license:' then return identifier end
    end
    return nil
end

local function GetFrameworkPlayer(src)
    if ESX then return ESX.GetPlayerFromId(src) end
    if QBCore then return QBCore.Functions.GetPlayer(src) end
    return nil
end

--- Identifiant du personnage (sert à l'XP). ESX : identifier, QB : citizenid, standalone : licence.
function Bridge.GetIdentifier(src)
    if ESX then
        local xPlayer = GetFrameworkPlayer(src)
        return xPlayer and xPlayer.identifier or nil
    elseif QBCore then
        local player = GetFrameworkPlayer(src)
        return player and player.PlayerData and player.PlayerData.citizenid or nil
    end
    return Bridge.GetLicense(src)
end

function Bridge.IsLoaded(src)
    return Bridge.GetIdentifier(src) ~= nil
end

function Bridge.GetJob(src)
    if ESX then
        local xPlayer = GetFrameworkPlayer(src)
        if xPlayer and xPlayer.job then
            return xPlayer.job.name, xPlayer.job.onDuty ~= false
        end
    elseif QBCore then
        local player = GetFrameworkPlayer(src)
        if player and player.PlayerData and player.PlayerData.job then
            return player.PlayerData.job.name, player.PlayerData.job.onduty == true
        end
    end
    return nil, false
end

function Bridge.IsPolice(src)
    if Bridge.framework == 'standalone' then
        return IsPlayerAceAllowed(src, Config.Police.AcePermission)
    end
    local jobName, onDuty = Bridge.GetJob(src)
    if not jobName or not U.Contains(Config.Police.Jobs, jobName) then return false end
    if Config.Police.RequireOnDuty and not onDuty then return false end
    return true
end

function Bridge.GetPoliceSources()
    local sources = {}
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src and Bridge.IsPolice(src) then
            sources[#sources + 1] = src
        end
    end
    return sources
end

function Bridge.AddMoney(src, amount)
    local account = Config.Rewards.Account[Bridge.framework] or 'cash'
    if ESX then
        local xPlayer = GetFrameworkPlayer(src)
        if not xPlayer then return false end
        if account == 'money' or account == 'cash' then
            xPlayer.addMoney(amount)
        else
            xPlayer.addAccountMoney(account, amount)
        end
        return true
    elseif QBCore then
        local player = GetFrameworkPlayer(src)
        if not player then return false end
        return player.Functions.AddMoney(account, amount, 'gofast-reward') ~= false
    end
    return Config.Standalone.AddMoney(src, account, amount) ~= false
end

function Bridge.AddItem(src, itemName, count)
    if GetResourceState('ox_inventory') == 'started' then
        local success = exports.ox_inventory:AddItem(src, itemName, count)
        return success and true or false
    end
    if ESX then
        local xPlayer = GetFrameworkPlayer(src)
        if not xPlayer then return false end
        xPlayer.addInventoryItem(itemName, count)
        return true
    elseif QBCore then
        local player = GetFrameworkPlayer(src)
        if not player then return false end
        local added = player.Functions.AddItem(itemName, count)
        if added and QBCore.Shared.Items and QBCore.Shared.Items[itemName] then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'add', count)
        end
        return added and true or false
    end
    TriggerEvent('gofast:standalone:addItem', src, itemName, count)
    return true
end

-- =========================================================================
-- STOCKAGE XP / STATISTIQUES
-- =========================================================================
Rewards = {}

local Stats = {}    -- [identifier] = { xp = number, missions = number }
local Loading = {}  -- [identifier] = promise

local function KvpKey(identifier)
    return 'stats:' .. identifier
end

local function UseDatabase()
    return Config.XP.Storage == 'oxmysql'
end

if UseDatabase() then
    CreateThread(function()
        if GetResourceState('oxmysql') ~= 'started' then
            print('^1[gofast] oxmysql non démarré : stockage XP basculé en KVP^0')
            Config.XP.Storage = 'kvp'
            return
        end
        exports.oxmysql:query([[
            CREATE TABLE IF NOT EXISTS `gofast_players` (
                `identifier` VARCHAR(64) NOT NULL,
                `xp` INT NOT NULL DEFAULT 0,
                `missions` INT NOT NULL DEFAULT 0,
                `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`identifier`)
            )
        ]], {}, function()
            print('^2[gofast] Table gofast_players prête^0')
        end)
    end)
end

--- Charge (ou renvoie depuis le cache) les statistiques. Peut attendre la base : appeler depuis un thread.
function Rewards.LoadStats(identifier)
    if Stats[identifier] then return Stats[identifier] end
    if Loading[identifier] then return Citizen.Await(Loading[identifier]) end

    local loadingPromise = promise.new()
    Loading[identifier] = loadingPromise

    local stats = { xp = 0, missions = 0 }
    if UseDatabase() then
        local query = promise.new()
        exports.oxmysql:single('SELECT `xp`, `missions` FROM `gofast_players` WHERE `identifier` = ? LIMIT 1', { identifier }, function(row)
            query:resolve(row or false)
        end)
        local row = Citizen.Await(query)
        if row then
            stats.xp = tonumber(row.xp) or 0
            stats.missions = tonumber(row.missions) or 0
        end
    else
        local raw = GetResourceKvpString(KvpKey(identifier))
        if raw then
            local ok, decoded = pcall(json.decode, raw)
            if ok and type(decoded) == 'table' then
                stats.xp = tonumber(decoded.xp) or 0
                stats.missions = tonumber(decoded.missions) or 0
            end
        end
    end

    Stats[identifier] = stats
    Loading[identifier] = nil
    loadingPromise:resolve(stats)
    return stats
end

function Rewards.GetCachedStats(identifier)
    return Stats[identifier]
end

function Rewards.SaveStats(identifier)
    local stats = Stats[identifier]
    if not stats then return end
    if UseDatabase() then
        exports.oxmysql:query(
            'INSERT INTO `gofast_players` (`identifier`, `xp`, `missions`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `xp` = VALUES(`xp`), `missions` = VALUES(`missions`)',
            { identifier, stats.xp, stats.missions }
        )
    else
        SetResourceKvp(KvpKey(identifier), json.encode(stats))
    end
end

--- Ajoute (ou retire si négatif) de l'XP. Renvoie { oldLevel, newLevel, xp, delta }.
function Rewards.AddXP(identifier, amount)
    local stats = Stats[identifier]
    if not stats or not Config.XP.Enabled then return nil end
    local oldLevel = U.GetLevelData(stats.xp).level
    local oldXp = stats.xp
    stats.xp = math.max(0, math.floor(stats.xp + amount))
    Rewards.SaveStats(identifier)
    return {
        oldLevel = oldLevel,
        newLevel = U.GetLevelData(stats.xp).level,
        xp = stats.xp,
        delta = stats.xp - oldXp,
    }
end

function Rewards.SetXP(identifier, xp)
    local stats = Stats[identifier]
    if not stats then return false end
    stats.xp = math.max(0, math.floor(xp))
    Rewards.SaveStats(identifier)
    return true
end

-- =========================================================================
-- CALCUL DES RÉCOMPENSES
-- =========================================================================
function Rewards.GetLevelBonus(baseReward, level)
    return math.floor(baseReward * math.max(0, (level or 1) - 1) * Config.Rewards.LevelBonusPerLevel)
end

--- Santé moyenne carrosserie + moteur (0 - 1000), lue côté serveur
function Rewards.GetVehicleHealth(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return 0.0 end
    local body = U.Clamp(GetVehicleBodyHealth(vehicle), 0.0, 1000.0)
    local engine = U.Clamp(GetVehicleEngineHealth(vehicle), 0.0, 1000.0)
    return (body + engine) / 2.0
end

--- Calcul pur, sans effet de bord
function Rewards.Calculate(mission, vehicleHealth, now)
    local base = mission.baseReward
    local result = {
        base = base,
        levelBonus = Rewards.GetLevelBonus(base, mission.levelAtStart),
        fastBonus = 0,
        checkpointBonus = math.floor(base * Config.Rewards.CheckpointBonus * mission.passedCount),
        damagePenalty = 0,
        health = math.floor(vehicleHealth / 10),
        elapsed = mission.transitStartedAt and (now - mission.transitStartedAt) or 0,
    }

    local fast = Config.Rewards.FastBonus
    if fast.Enabled and mission.transitStartedAt and result.elapsed <= mission.timeLimit * fast.Threshold then
        result.fastBonus = math.floor(base * fast.Percent)
    end

    local damage = Config.Rewards.DamagePenalty
    if damage.Enabled and vehicleHealth < damage.Threshold then
        local ratio = U.Clamp((damage.Threshold - vehicleHealth) / damage.Threshold, 0.0, 1.0)
        result.damagePenalty = math.floor(base * damage.MaxPercent * ratio)
    end

    result.total = math.max(0, base + result.levelBonus + result.fastBonus + result.checkpointBonus - result.damagePenalty)
    return result
end

--- Paiement final. Appelé une seule fois : la mission est marquée terminée AVANT l'appel.
function Rewards.Complete(src, mission, tier)
    local result = Rewards.Calculate(mission, Rewards.GetVehicleHealth(mission.vehicle), os.time())

    result.paid = result.total > 0 and Bridge.AddMoney(src, result.total) or false

    result.items = {}
    for _, item in ipairs(tier.items or {}) do
        if math.random() < (item.chance or 1.0) then
            local count = math.floor(U.RandomRange(item.count or 1))
            if count > 0 and Bridge.AddItem(src, item.name, count) then
                result.items[#result.items + 1] = { label = item.label or item.name, count = count }
            end
        end
    end

    local stats = Stats[mission.identifier]
    if stats then stats.missions = stats.missions + 1 end

    result.xp = 0
    result.levelUp = nil
    if Config.XP.Enabled and stats then
        local xpGain = tier.xp * (mission.rare and Config.Rare.XPMultiplier or 1.0)
        if result.fastBonus > 0 then
            xpGain = xpGain + tier.xp * (Config.Rewards.FastBonus.XPPercent or 0)
        end
        result.xp = math.floor(xpGain)
        local xpResult = Rewards.AddXP(mission.identifier, result.xp)
        if xpResult and xpResult.newLevel > xpResult.oldLevel then
            result.levelUp = xpResult.newLevel
        end
    elseif stats then
        Rewards.SaveStats(mission.identifier)
    end

    return result
end

--- Pénalité d'XP en cas d'échec. Renvoie l'XP réellement retirée.
function Rewards.ApplyFailurePenalty(mission, cooldownKind)
    if not Config.XP.Enabled then return 0 end
    local amount = Config.XP.FailPenalty
    if cooldownKind == 'Abandon' then
        amount = Config.XP.AbandonPenalty
    elseif cooldownKind == 'Disconnect' then
        amount = Config.XP.DisconnectPenalty
    end
    if not amount or amount <= 0 then return 0 end
    local xpResult = Rewards.AddXP(mission.identifier, -amount)
    return xpResult and -xpResult.delta or 0
end
