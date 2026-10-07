--[[
    ELYZEA CORE — exports serveur, permissions, notifications, commandes
]]

-- ─────────── Permissions ───────────

function HasPermission(src, perm)
    src = tonumber(src)
    if not src then return false end
    if src == 0 then return true end
    if type(perm) == 'table' then
        for _, p in ipairs(perm) do if HasPermission(src, p) then return true end end
        return false
    end
    perm = tostring(perm or '')
    if perm == '' then return false end
    return IsPlayerAceAllowed(src, perm) or IsPlayerAceAllowed(src, 'group.' .. perm)
end

function GetPermission(src)
    local out = {}
    for _, p in ipairs(Config.Permissions) do
        if IsPlayerAceAllowed(src, 'group.' .. p) or IsPlayerAceAllowed(src, p) then out[p] = true end
    end
    return out
end

function IsOptin() return true end

-- ─────────── Notifications ───────────

-- Notify(src, message, type, durée)  type : 'success' | 'error' | 'inform' | 'warning'
function Notify(src, text, kind, duration, title)
    if type(text) == 'table' then
        TriggerClientEvent('elyzea:client:notify', src, text.description or text.text or text.title, text.type or kind, text.duration or duration, text.description and text.title or title)
        return
    end
    TriggerClientEvent('elyzea:client:notify', src, text, kind, duration, title)
end

-- ─────────── Objets utilisables (relais vers elyzea_inventory) ───────────

local pendingUsable = {}

function CreateUseableItem(name, cb)
    if GetResourceState('elyzea_inventory') == 'started' then
        return exports.elyzea_inventory:RegisterUsableItem(name, function(src, item)
            local ok, res = pcall(cb, src, item)
            if not ok then print(('^1[elyzea_core] objet %s : %s^0'):format(name, tostring(res))) return false end
            return res
        end)
    end
    pendingUsable[name] = cb
end

AddEventHandler('elyzea_inventory:ready', function()
    for name, cb in pairs(pendingUsable) do CreateUseableItem(name, cb) end
    pendingUsable = {}
end)

-- ─────────── Exports ───────────

local api = {
    -- joueurs
    GetPlayer = GetPlayer,
    GetPlayerByCitizenId = GetPlayerByCitizenId,
    GetPlayerByPhone = GetPlayerByPhone,
    GetOfflinePlayer = GetOfflinePlayer,
    GetPlayers = GetPlayersData,
    GetQBPlayers = GetPlayersData,
    IsPlayerLoaded = IsPlayerLoaded,
    Login = Login,
    Logout = Logout,
    Save = Save,
    SaveOffline = SaveOffline,
    DeleteCharacter = DeleteCharacter,
    GetCharacters = GetCharacters,
    GetLicense = GetLicense,
    GenerateUniqueIdentifier = GenerateUniqueIdentifier,
    -- métiers / groupes
    GetJobs = function() return Jobs end,
    GetJob = GetJob,
    GetGangs = function() return Gangs end,
    GetGang = GetGang,
    CreateJobs = CreateJobs,
    CreateJob = CreateJob,
    RemoveJob = RemoveJob,
    CreateGangs = CreateGangs,
    RemoveGang = RemoveGang,
    AddPlayerToJob = AddPlayerToJob,
    RemovePlayerFromJob = RemovePlayerFromJob,
    AddPlayerToGang = AddPlayerToGang,
    RemovePlayerFromGang = RemovePlayerFromGang,
    GetGroupMembers = GetGroupMembers,
    -- sociétés
    GetSocietyMoney = GetSocietyMoney,
    AddSocietyMoney = AddSocietyMoney,
    RemoveSocietyMoney = RemoveSocietyMoney,
    SetSocietyMoney = SetSocietyMoney,
    GetSocietyLogs = GetSocietyLogs,
    -- clés
    GiveKeys = GiveKeys,
    RemoveKeys = RemoveKeys,
    HasKeys = HasKeys,
    -- divers
    HasPermission = HasPermission,
    GetPermission = GetPermission,
    Notify = Notify,
    CreateUseableItem = CreateUseableItem,
    AddNeeds = AddNeeds,
}

-- Raccourcis « par source »
function api.GetPlayerData(src) local p = GetPlayer(src) return p and p.PlayerData or nil end
function api.GetMoney(src, kind) local p = GetPlayer(src) return p and p.Functions.GetMoney(kind) or 0 end
function api.AddMoney(src, kind, amount, reason) local p = GetPlayer(src) return p ~= nil and p.Functions.AddMoney(kind, amount, reason) end
function api.RemoveMoney(src, kind, amount, reason) local p = GetPlayer(src) return p ~= nil and p.Functions.RemoveMoney(kind, amount, reason) end
function api.SetMoney(src, kind, amount, reason) local p = GetPlayer(src) return p ~= nil and p.Functions.SetMoney(kind, amount, reason) end
function api.SetJob(src, job, grade) local p = GetPlayer(src) return p ~= nil and p.Functions.SetJob(job, grade) end
function api.SetGang(src, gang, grade) local p = GetPlayer(src) return p ~= nil and p.Functions.SetGang(gang, grade) end
function api.SetJobDuty(src, state) local p = GetPlayer(src) return p ~= nil and p.Functions.SetJobDuty(state) end
function api.SetMetadata(src, key, value) local p = GetPlayer(src) if p then p.Functions.SetMetaData(key, value) return true end return false end
function api.GetMetadata(src, key) local p = GetPlayer(src) return p and p.Functions.GetMetaData(key) end
function api.SetCharInfo(src, key, value) local p = GetPlayer(src) if p then p.Functions.SetCharInfo(key, value) return true end return false end
function api.SetPlayerData(src, key, value) local p = GetPlayer(src) if p then p.Functions.SetPlayerData(key, value) return true end return false end
function api.GetCitizenId(src) local p = GetPlayer(src) return p and p.PlayerData.citizenid end
function api.GetCharName(src)
    local p = GetPlayer(src)
    if not p then return GetPlayerName(src) end
    return ('%s %s'):format(p.PlayerData.charinfo.firstname, p.PlayerData.charinfo.lastname)
end
function api.GetSourceByCitizenId(cid) local p = GetPlayerByCitizenId(cid) return p and p.PlayerData.source end

for name, fn in pairs(api) do exports(name, fn) end

-- ─────────── Rappels serveur pour le client du core ───────────

RegisterNetEvent('elyzea:server:requestPlayerData', function()
    local src = source
    local p = GetPlayer(src)
    if p then
        TriggerClientEvent('elyzea:client:setPlayerData', src, p.PlayerData)
        if IsPlayerLoaded(src) then TriggerClientEvent('elyzea:client:playerLoaded', src, p.PlayerData) end
    end
end)

-- Santé / gilet envoyés au client à l'apparition
AddEventHandler('elyzea:server:playerLoaded', function(src)
    local p = GetPlayer(src)
    if not p then return end
    TriggerClientEvent('elyzea:client:restoreStatus', src, p.PlayerData.metadata.health, p.PlayerData.metadata.armor)
end)

-- ─────────── Commandes d'administration (ACE : command.<nom>) ───────────

local function reply(src, msg, kind)
    if src == 0 then print(msg) else Notify(src, msg, kind or 'inform') end
end

RegisterCommand('logout', function(src, args)
    local target = tonumber(args[1]) or src
    if target == 0 or not GetPlayer(target) then return reply(src, 'Joueur introuvable.', 'error') end
    Logout(target)
    reply(src, 'Personnage déconnecté.', 'success')
end, true)

RegisterCommand('setjob', function(src, args)
    local target, job, grade = tonumber(args[1]), args[2], tonumber(args[3]) or 0
    local p = target and GetPlayer(target)
    if not p or not job then return reply(src, 'Usage : /setjob [id] [métier] [grade]', 'error') end
    if not p.Functions.SetJob(job, grade) then return reply(src, 'Métier inconnu : ' .. job, 'error') end
    reply(src, ('Métier de %s : %s (%d)'):format(target, job, grade), 'success')
end, true)

RegisterCommand('givemoney', function(src, args)
    local target, kind, amount = tonumber(args[1]), args[2], tonumber(args[3])
    local p = target and GetPlayer(target)
    if not p or not kind or not amount then return reply(src, 'Usage : /givemoney [id] [cash|bank] [montant]', 'error') end
    if not p.Functions.AddMoney(kind, amount, 'admin') then return reply(src, 'Opération impossible.', 'error') end
    reply(src, ('%d $ (%s) donnés à %d'):format(amount, kind, target), 'success')
end, true)

RegisterCommand('setmoney', function(src, args)
    local target, kind, amount = tonumber(args[1]), args[2], tonumber(args[3])
    local p = target and GetPlayer(target)
    if not p or not kind or not amount then return reply(src, 'Usage : /setmoney [id] [cash|bank] [montant]', 'error') end
    if not p.Functions.SetMoney(kind, amount, 'admin') then return reply(src, 'Opération impossible.', 'error') end
    reply(src, ('Argent (%s) de %d fixé à %d $'):format(kind, target, amount), 'success')
end, true)

print(('^2[elyzea_core] Base %s démarrée.^0'):format(Config.ServerName))
