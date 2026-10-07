--[[
    ELYZEA CORE — joueurs et personnages
    Player = { PlayerData = {...}, Functions = {...} }
    PlayerData : source, citizenid, cid, license, name, money, charinfo, job, gang, position, metadata
]]

Players = {}            -- [source] = Player
local ByCitizen = {}    -- [citizenid] = source
local Loaded = {}       -- [source] = true quand le personnage est apparu en jeu

local function dbg(...) if Config.Debug then print('[elyzea_core]', ...) end end

-- ─────────── Identifiants ───────────

function GetLicense(src)
    return GetPlayerIdentifierByType(src, 'license2') or GetPlayerIdentifierByType(src, 'license')
end

function GetLicenses(src)
    local l2 = GetPlayerIdentifierByType(src, 'license2')
    local l1 = GetPlayerIdentifierByType(src, 'license')
    return l2 or l1 or 'none', l1 or l2 or 'none'
end

local function uniqueValue(column, generator, jsonPath)
    for _ = 1, 50 do
        local value = generator()
        local exists
        if jsonPath then
            exists = MySQL.scalar.await(('SELECT 1 FROM `players` WHERE JSON_UNQUOTE(JSON_EXTRACT(`%s`, ?)) = ? LIMIT 1'):format(column), { jsonPath, value })
        else
            exists = MySQL.scalar.await(('SELECT 1 FROM `players` WHERE `%s` = ? LIMIT 1'):format(column), { value })
        end
        if not exists then return value end
    end
    return generator()
end

local Generators = {
    citizenid = function() return uniqueValue('citizenid', function() return Ely.Shared.RandomString('A.......') end) end,
    phone = function() return uniqueValue('charinfo', function() return tostring(math.random(100, 999)) .. tostring(math.random(1000000, 9999999)) end, '$.phone') end,
    account = function() return 'FR' .. math.random(10, 99) .. 'ELY' .. math.random(1111, 9999) .. math.random(1111, 9999) end,
    fingerprint = function() return Ely.Shared.RandomString('...............') end,
    walletid = function() return 'ELY-' .. math.random(11111111, 99999999) end,
    serial = function() return math.random(11111111, 99999999) end,
}

function GenerateUniqueIdentifier(kind)
    local fn = Generators[kind] or Generators[(kind or ''):lower()]
    if kind == 'PhoneNumber' then fn = Generators.phone end
    if kind == 'AccountNumber' then fn = Generators.account end
    if kind == 'FingerId' then fn = Generators.fingerprint end
    if kind == 'WalletId' then fn = Generators.walletid end
    if kind == 'SerialNumber' then fn = Generators.serial end
    return fn and fn() or nil
end

-- ─────────── Données par défaut ───────────

local function plainPosition(pos)
    if type(pos) ~= 'table' and type(pos) ~= 'vector3' and type(pos) ~= 'vector4' then return nil end
    local ok, res = pcall(function()
        return { x = pos.x + 0.0, y = pos.y + 0.0, z = pos.z + 0.0, w = (pos.w or pos.h or pos.heading or 0.0) + 0.0 }
    end)
    return ok and res or nil
end

function CheckPlayerData(src, pd)
    pd = pd or {}
    if src then
        pd.source = src
        pd.license = pd.license or GetLicense(src)
        pd.name = GetPlayerName(src)
    end
    pd.citizenid = pd.citizenid or GenerateUniqueIdentifier('citizenid')
    pd.cid = tonumber(pd.charinfo and pd.charinfo.cid or pd.cid) or 1

    pd.money = type(pd.money) == 'table' and pd.money or {}
    for kind, start in pairs(Config.Money.types) do
        pd.money[kind] = tonumber(pd.money[kind]) or start
    end

    local ci = type(pd.charinfo) == 'table' and pd.charinfo or {}
    ci.firstname = ci.firstname or 'Prénom'
    ci.lastname = ci.lastname or 'Nom'
    ci.birthdate = ci.birthdate or '2000-01-01'
    ci.gender = tonumber(ci.gender) or 0
    ci.nationality = ci.nationality or 'Française'
    ci.backstory = ci.backstory or ''
    ci.phone = ci.phone or GenerateUniqueIdentifier('phone')
    ci.account = ci.account or GenerateUniqueIdentifier('account')
    ci.cid = ci.cid or pd.cid
    pd.charinfo = ci

    local md = type(pd.metadata) == 'table' and pd.metadata or {}
    md.health = md.health or 200
    md.armor = md.armor or 0
    md.hunger = tonumber(md.hunger) or 100
    md.thirst = tonumber(md.thirst) or 100
    md.stress = tonumber(md.stress) or 0
    md.isdead = md.isdead == true
    md.inlaststand = md.inlaststand == true
    md.ishandcuffed = md.ishandcuffed == true
    md.injail = md.injail or 0
    md.jailitems = md.jailitems or {}
    md.status = md.status or {}
    md.bloodtype = md.bloodtype or Config.BloodTypes[math.random(1, #Config.BloodTypes)]
    md.callsign = md.callsign or 'AUCUN'
    md.fingerprint = md.fingerprint or GenerateUniqueIdentifier('fingerprint')
    md.walletid = md.walletid or GenerateUniqueIdentifier('walletid')
    md.criminalrecord = md.criminalrecord or { hasRecord = false }
    md.licences = md.licences or { id = true, driver = false, weapon = false }
    md.jobrep = md.jobrep or {}
    pd.metadata = md

    local job = type(pd.job) == 'table' and pd.job or {}
    local jobName = job.name or 'unemployed'
    local jobGrade = type(job.grade) == 'table' and job.grade.level or job.grade
    local jobDef = GetJob(jobName)
    local duty = job.onduty
    if jobDef and jobDef.defaultDuty ~= nil and src then duty = jobDef.defaultDuty end
    pd.job = BuildJob(jobName, jobGrade, duty)

    local gang = type(pd.gang) == 'table' and pd.gang or {}
    pd.gang = BuildGang(gang.name or 'none', type(gang.grade) == 'table' and gang.grade.level or gang.grade)

    pd.position = plainPosition(pd.position) or plainPosition(Config.Characters.defaultSpawn)
    return pd
end

-- ─────────── Sauvegarde ───────────

local function savePlayerData(pd)
    MySQL.query.await([[
        INSERT INTO `players` (`citizenid`, `cid`, `license`, `name`, `money`, `charinfo`, `job`, `gang`, `position`, `metadata`, `phone_number`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `cid` = VALUES(`cid`), `name` = VALUES(`name`), `money` = VALUES(`money`),
            `charinfo` = VALUES(`charinfo`), `job` = VALUES(`job`), `gang` = VALUES(`gang`),
            `position` = VALUES(`position`), `metadata` = VALUES(`metadata`), `phone_number` = VALUES(`phone_number`)
    ]], {
        pd.citizenid, pd.cid, pd.license, pd.name or '', json.encode(pd.money), json.encode(pd.charinfo),
        json.encode(pd.job), json.encode(pd.gang), json.encode(pd.position), json.encode(pd.metadata),
        pd.charinfo and pd.charinfo.phone or nil,
    })
end

function Save(src)
    local p = Players[src]
    if not p then return false end
    local pd = p.PlayerData
    if Loaded[src] then
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            local c = GetEntityCoords(ped)
            if #(c - vector3(0.0, 0.0, 0.0)) > 5.0 then
                pd.position = { x = c.x, y = c.y, z = c.z, w = GetEntityHeading(ped) }
            end
            local health = GetEntityHealth(ped)
            if health and health > 0 then pd.metadata.health = health end
            pd.metadata.armor = GetPedArmour(ped)
        end
    end
    local ok, err = pcall(savePlayerData, pd)
    if not ok then print(('^1[elyzea_core] Sauvegarde de %s impossible : %s^0'):format(pd.citizenid, tostring(err))) end
    return ok
end

function SaveOffline(pd)
    return pcall(savePlayerData, pd)
end

-- ─────────── Objet joueur ───────────

local function emitMoney(src, kind, amount, action, reason)
    TriggerClientEvent('elyzea:client:onMoneyChange', src, kind, amount, action, reason)
    TriggerEvent('elyzea:server:onMoneyChange', src, kind, amount, action, reason)
end

local function setStateNeed(src, key, value)
    if key == 'hunger' or key == 'thirst' or key == 'stress' then
        Player(src).state:set(key, value, true)
    end
end

function CreatePlayer(pd)
    local self = { PlayerData = pd, Functions = {}, Offline = false }
    local src = pd.source
    local F = self.Functions

    function F.UpdatePlayerData()
        TriggerClientEvent('elyzea:client:setPlayerData', src, self.PlayerData)
    end

    function F.SetPlayerData(key, value)
        if type(key) ~= 'string' then return end
        self.PlayerData[key] = value
        F.UpdatePlayerData()
    end

    function F.SetJob(name, grade)
        name = tostring(name or ''):lower()
        if not GetJob(name) then return false end
        local old = self.PlayerData.job
        self.PlayerData.job = BuildJob(name, grade, nil)
        StoreGroup(self.PlayerData.citizenid, 'job', name, self.PlayerData.job.grade.level)
        F.UpdatePlayerData()
        TriggerEvent('elyzea:server:onJobUpdate', src, self.PlayerData.job, old)
        TriggerClientEvent('elyzea:client:onJobUpdate', src, self.PlayerData.job)
        return true
    end

    function F.SetGang(name, grade)
        name = tostring(name or ''):lower()
        if not GetGang(name) then return false end
        self.PlayerData.gang = BuildGang(name, grade)
        StoreGroup(self.PlayerData.citizenid, 'gang', name, self.PlayerData.gang.grade.level)
        F.UpdatePlayerData()
        TriggerEvent('elyzea:server:onGangUpdate', src, self.PlayerData.gang)
        TriggerClientEvent('elyzea:client:onGangUpdate', src, self.PlayerData.gang)
        return true
    end

    function F.SetJobDuty(state)
        self.PlayerData.job.onduty = state == true
        F.UpdatePlayerData()
        TriggerEvent('elyzea:server:setDuty', src, self.PlayerData.job.onduty)
        TriggerClientEvent('elyzea:client:setDuty', src, self.PlayerData.job.onduty)
        return true
    end

    function F.SetMetaData(key, value)
        if type(key) ~= 'string' then return end
        if key == 'hunger' or key == 'thirst' or key == 'stress' then
            value = math.max(0, math.min(100, tonumber(value) or 0))
        end
        self.PlayerData.metadata[key] = value
        setStateNeed(src, key, value)
        F.UpdatePlayerData()
        TriggerEvent('elyzea:server:onMetadataChange', src, key, value)
    end
    F.SetMetadata = F.SetMetaData

    function F.GetMetaData(key)
        if key then return self.PlayerData.metadata[key] end
        return self.PlayerData.metadata
    end
    F.GetMetadata = F.GetMetaData

    function F.SetCharInfo(key, value)
        self.PlayerData.charinfo[key] = value
        F.UpdatePlayerData()
    end

    function F.GetMoney(kind)
        return tonumber(self.PlayerData.money[kind or 'cash']) or 0
    end

    function F.AddMoney(kind, amount, reason)
        kind = tostring(kind or 'cash'):lower()
        amount = math.floor(tonumber(amount) or 0)
        if amount < 0 or self.PlayerData.money[kind] == nil then return false end
        if amount == 0 then return true end
        self.PlayerData.money[kind] = self.PlayerData.money[kind] + amount
        F.UpdatePlayerData()
        emitMoney(src, kind, amount, 'add', reason)
        return true
    end

    function F.RemoveMoney(kind, amount, reason)
        kind = tostring(kind or 'cash'):lower()
        amount = math.floor(tonumber(amount) or 0)
        if amount < 0 or self.PlayerData.money[kind] == nil then return false end
        if amount == 0 then return true end
        if Config.Money.noNegative[kind] and self.PlayerData.money[kind] - amount < 0 then return false end
        self.PlayerData.money[kind] = self.PlayerData.money[kind] - amount
        F.UpdatePlayerData()
        emitMoney(src, kind, amount, 'remove', reason)
        return true
    end

    function F.SetMoney(kind, amount, reason)
        kind = tostring(kind or 'cash'):lower()
        amount = math.floor(tonumber(amount) or 0)
        if self.PlayerData.money[kind] == nil then return false end
        local diff = amount - self.PlayerData.money[kind]
        self.PlayerData.money[kind] = amount
        F.UpdatePlayerData()
        emitMoney(src, kind, math.abs(diff), diff >= 0 and 'add' or 'remove', reason or 'set')
        return true
    end

    -- Inventaire (elyzea_inventory)
    local function inv() return GetResourceState('elyzea_inventory') == 'started' and exports.elyzea_inventory or nil end

    function F.AddItem(item, amount, slot, info)
        local i = inv(); if not i then return false end
        return (i:AddItem(src, item, amount or 1, info, slot)) == true
    end

    function F.RemoveItem(item, amount, slot)
        local i = inv(); if not i then return false end
        return (i:RemoveItem(src, item, amount or 1, nil, slot)) == true
    end

    function F.GetItemByName(item)
        local i = inv(); if not i then return nil end
        local n = i:GetItemCount(src, item) or 0
        if n <= 0 then return nil end
        local def = i:Items(item) or {}
        return { name = item, label = def.label or item, amount = n, count = n }
    end

    function F.GetItemsByName(item)
        local i = inv(); if not i then return {} end
        return i:Search(src, 'slots', item) or {}
    end

    function F.ClearInventory()
        local i = inv(); if i then i:ClearInventory(src) end
    end

    function F.HasItem(item, amount)
        local i = inv(); if not i then return false end
        return (i:GetItemCount(src, item) or 0) >= (amount or 1)
    end

    function F.Save() return Save(src) end
    function F.Logout() return Logout(src) end

    return self
end

-- ─────────── Accès ───────────

function GetPlayer(src)
    src = tonumber(src)
    return src and Players[src] or nil
end

function GetPlayerByCitizenId(citizenid)
    local src = citizenid and ByCitizen[citizenid]
    return src and Players[src] or nil
end

function GetPlayerByPhone(phone)
    for _, p in pairs(Players) do
        if p.PlayerData.charinfo.phone == phone then return p end
    end
end

function GetPlayersData()
    local out = {}
    for src, p in pairs(Players) do out[src] = p end
    return out
end

function IsPlayerLoaded(src) return Loaded[tonumber(src)] == true end

-- Joueur hors ligne (lecture seule + Save) : utile pour les tablettes / MDT
function GetOfflinePlayer(citizenid)
    local row = MySQL.single.await('SELECT * FROM `players` WHERE `citizenid` = ?', { citizenid })
    if not row then return nil end
    local pd = {
        citizenid = row.citizenid, cid = row.cid, license = row.license, name = row.name,
        money = Ely.Shared.DecodeJson(row.money, {}), charinfo = Ely.Shared.DecodeJson(row.charinfo, {}),
        job = Ely.Shared.DecodeJson(row.job, {}), gang = Ely.Shared.DecodeJson(row.gang, {}),
        position = Ely.Shared.DecodeJson(row.position, nil), metadata = Ely.Shared.DecodeJson(row.metadata, {}),
    }
    pd = CheckPlayerData(nil, pd)
    return { PlayerData = pd, Offline = true }
end

-- ─────────── Connexion / déconnexion ───────────

function GetCharacters(src)
    local l2, l1 = GetLicenses(src)
    return MySQL.query.await('SELECT * FROM `players` WHERE `license` = ? OR `license` = ? ORDER BY `cid` ASC', { l2, l1 }) or {}
end

-- Login(src, citizenid)            : charge un personnage existant
-- Login(src, nil, { cid, charinfo }) : crée un nouveau personnage
function Login(src, citizenid, newData)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then return false end
    AwaitDatabase()
    if Players[src] then Logout(src) end

    local pd
    if citizenid then
        local row = MySQL.single.await('SELECT * FROM `players` WHERE `citizenid` = ?', { citizenid })
        if not row then return false end
        local l2, l1 = GetLicenses(src)
        if row.license ~= l2 and row.license ~= l1 then
            print(('^1[elyzea_core] %s a tenté de charger le personnage %s qui ne lui appartient pas.^0'):format(GetPlayerName(src), citizenid))
            return false
        end
        if ByCitizen[citizenid] and ByCitizen[citizenid] ~= src then
            DropPlayer(ByCitizen[citizenid], 'Ce personnage vient d\'être chargé depuis une autre connexion.')
        end
        pd = {
            citizenid = row.citizenid, cid = row.cid, license = row.license,
            money = Ely.Shared.DecodeJson(row.money, {}), charinfo = Ely.Shared.DecodeJson(row.charinfo, {}),
            job = Ely.Shared.DecodeJson(row.job, {}), gang = Ely.Shared.DecodeJson(row.gang, {}),
            position = Ely.Shared.DecodeJson(row.position, nil), metadata = Ely.Shared.DecodeJson(row.metadata, {}),
        }
    else
        if type(newData) ~= 'table' then return false end
        pd = { cid = newData.cid, charinfo = newData.charinfo, money = newData.money, job = newData.job, metadata = newData.metadata }
    end

    pd = CheckPlayerData(src, pd)
    local player = CreatePlayer(pd)
    Players[src] = player
    ByCitizen[pd.citizenid] = src
    Loaded[src] = nil

    if not citizenid then
        savePlayerData(pd)
        StoreGroup(pd.citizenid, 'job', pd.job.name, pd.job.grade.level)
    end

    local state = Player(src).state
    state:set('citizenid', pd.citizenid, true)
    state:set('hunger', pd.metadata.hunger, true)
    state:set('thirst', pd.metadata.thirst, true)
    state:set('stress', pd.metadata.stress, true)

    TriggerClientEvent('elyzea:client:setPlayerData', src, pd)
    TriggerEvent('elyzea:server:playerLogin', src, citizenid == nil)
    dbg(('connexion de %s (%s)'):format(GetPlayerName(src), pd.citizenid))
    return true
end

-- Le client signale que le personnage est apparu en jeu
RegisterNetEvent('elyzea:server:onPlayerLoaded', function()
    local src = source
    local p = Players[src]
    if not p or Loaded[src] then return end
    Loaded[src] = true
    Player(src).state:set('isLoggedIn', true, true)
    TriggerEvent('elyzea:server:playerLoaded', src)
    TriggerClientEvent('elyzea:client:playerLoaded', src, p.PlayerData)
end)

function Logout(src)
    src = tonumber(src)
    local p = src and Players[src]
    if not p then return false end
    Save(src)
    TriggerEvent('elyzea:server:playerUnloaded', src, p.PlayerData.citizenid)
    pcall(MySQL.update.await, 'UPDATE `players` SET `last_logged_out` = NOW() WHERE `citizenid` = ?', { p.PlayerData.citizenid })
    ByCitizen[p.PlayerData.citizenid] = nil
    Players[src] = nil
    Loaded[src] = nil
    if GetPlayerName(src) then
        Player(src).state:set('isLoggedIn', false, true)
        Player(src).state:set('citizenid', nil, true)
        TriggerClientEvent('elyzea:client:playerUnloaded', src)
    end
    return true
end

function DeleteCharacter(citizenid)
    if not citizenid then return false end
    local p = GetPlayerByCitizenId(citizenid)
    if p then Logout(p.PlayerData.source) end
    for _, t in ipairs(Config.Characters.deleteTables) do
        pcall(MySQL.query.await, ('DELETE FROM `%s` WHERE `%s` = ?'):format(t[1], t[2]), { citizenid })
    end
    TriggerEvent('elyzea:server:characterDeleted', citizenid)
    return true
end

AddEventHandler('playerDropped', function(reason)
    local src = source
    local p = Players[src]
    if not p then return end
    Save(src)
    TriggerEvent('elyzea:server:playerUnloaded', src, p.PlayerData.citizenid)
    pcall(MySQL.update.await, 'UPDATE `players` SET `last_logged_out` = NOW() WHERE `citizenid` = ?', { p.PlayerData.citizenid })
    ByCitizen[p.PlayerData.citizenid] = nil
    Players[src] = nil
    Loaded[src] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(Players) do Save(src) end
end)

-- Connexion : license Rockstar + base de données prête.
-- Sans base, le joueur resterait sur un écran noir après le loading screen :
-- on le prévient tout de suite avec un message clair à la place.
AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    if not GetLicense(src) then return deferrals.done('Licence Rockstar introuvable : relancez FiveM.') end
    local db = exports[GetCurrentResourceName()]
    local ok, st = pcall(function() return db:db_status() end)
    if ok and type(st) == 'table' and not st.ready then
        if st.disabled then
            print(('^1[elyzea_core] Connexion refusée (%s) : base de données désactivée.^0'):format(GetPlayerName(src) or src))
            return deferrals.done('Serveur en maintenance : la base de données n\'est pas configurée. Réessaie plus tard.')
        end
        deferrals.update('Connexion à la base de données du serveur…')
        local t = GetGameTimer() + 20000
        while not db:db_isReady() and GetGameTimer() < t do Wait(500) end
        if not db:db_isReady() then
            return deferrals.done('Le serveur démarre encore (base de données injoignable). Réessaie dans une minute.')
        end
    end
    deferrals.done()
end)
