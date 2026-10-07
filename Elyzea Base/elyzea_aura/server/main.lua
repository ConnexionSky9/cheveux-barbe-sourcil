-- =========================================================
--  ELYZEA AURA - Serveur
-- =========================================================
local ESX, QBCore
local Framework = Config.Framework
if Framework == 'auto' then
    if GetResourceState('elyzea_core') ~= 'missing' then
        Framework = 'elyzea'
    elseif GetResourceState('qb-core') ~= 'missing' then
        Framework = 'qb'
    elseif GetResourceState('es_extended') ~= 'missing' then
        Framework = 'esx'
    else
        Framework = 'standalone'
    end
end
if Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
elseif Framework == 'qb' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif Framework == 'elyzea' then
    -- Base Elyzea : le joueur elyzea_core a la même forme (PlayerData, Functions) et les mêmes tables
    local core = exports.elyzea_core
    QBCore = {
        Functions = {
            GetPlayer = function(src) return core:GetPlayer(src) end,
            GetPlayerByCitizenId = function(cid) return core:GetPlayerByCitizenId(cid) end,
        },
        Shared = { Items = {} },
    }
end
print(('[elyzea_aura] Elyzea Aura 5 démarré (framework : %s)'):format(Framework))

-- ---------------------------------------------------------
--  Base de données : création et mise à jour automatiques
--  (plus besoin d'importer les fichiers SQL à la main)
-- ---------------------------------------------------------
local SchemaReady = false
local COLUMNS = { -- colonnes ajoutées au fil des versions
    { 'elyzea_phones', 'passcode', 'VARCHAR(40) NULL' },
    { 'elyzea_gallery', 'type', "VARCHAR(10) NOT NULL DEFAULT 'photo'" },
    { 'elyzea_gallery', 'duration', 'INT NOT NULL DEFAULT 0' },
    { 'elyzea_tracks', 'thumb', 'VARCHAR(500) NULL' },
    { 'elyzea_tracks', 'source', "VARCHAR(12) NOT NULL DEFAULT 'direct'" },
}

MySQL.ready(function()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/elyzea_aura.sql') or ''
    local created, added = 0, 0
    for statement in sql:gmatch('[^;]+') do
        local q = statement:gsub('%-%-[^\n]*', ''):gsub('^%s+', ''):gsub('%s+$', '')
        if q ~= '' then
            local ok, err = pcall(MySQL.query.await, q)
            if ok then created = created + 1 else print('^1[elyzea_aura] Table non créée : ' .. tostring(err) .. '^0') end
        end
    end
    for _, col in ipairs(COLUMNS) do
        local exists = MySQL.scalar.await('SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?', { col[1], col[2] })
        if exists == 0 then
            local ok, err = pcall(MySQL.query.await, ('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(col[1], col[2], col[3]))
            if ok then added = added + 1 else print('^1[elyzea_aura] Colonne ' .. col[1] .. '.' .. col[2] .. ' non ajoutée : ' .. tostring(err) .. '^0') end
        end
    end
    SchemaReady = true
    print(('^2[elyzea_aura] Base de données à jour (%d tables vérifiées, %d colonne(s) ajoutée(s)).^0'):format(created, added))
end)

local Players = {}      -- [src] = { identifier, number, settings }
local Calls = {}        -- [callId] = { caller, target, callerNumber, targetNumber, state, startedAt }
local PlayerCall = {}   -- [src] = callId
local callCounter = 0

-- ---------------------------------------------------------
--  Pont framework
-- ---------------------------------------------------------
local function GetIdentifier(src)
    if ESX then
        local x = ESX.GetPlayerFromId(src)
        return x and x.identifier
    elseif QBCore then
        local p = QBCore.Functions.GetPlayer(src)
        return p and p.PlayerData.citizenid
    end
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'license:' then return id end
    end
end

local function GetCharName(src)
    if ESX then
        local x = ESX.GetPlayerFromId(src)
        if x then return x.getName() end
    elseif QBCore then
        local p = QBCore.Functions.GetPlayer(src)
        if p then return ('%s %s'):format(p.PlayerData.charinfo.firstname, p.PlayerData.charinfo.lastname) end
    end
    return GetPlayerName(src) or 'Inconnu'
end

local function GetJob(src)
    if ESX then
        local x = ESX.GetPlayerFromId(src)
        return x and x.job and x.job.name
    elseif QBCore then
        local p = QBCore.Functions.GetPlayer(src)
        return p and p.PlayerData.job and p.PlayerData.job.name
    end
end

local function GetBank(src)
    if ESX then
        local x = ESX.GetPlayerFromId(src)
        return x and x.getAccount('bank').money or 0
    elseif QBCore then
        local p = QBCore.Functions.GetPlayer(src)
        return p and p.Functions.GetMoney('bank') or 0
    end
    return 0
end

local function RemoveBank(src, amount, reason)
    if ESX then
        local x = ESX.GetPlayerFromId(src)
        if x and x.getAccount('bank').money >= amount then
            x.removeAccountMoney('bank', amount, reason)
            return true
        end
    elseif QBCore then
        local p = QBCore.Functions.GetPlayer(src)
        if p then return p.Functions.RemoveMoney('bank', amount, reason) end
    end
    return false
end

local function AddBank(src, amount, reason)
    if ESX then
        local x = ESX.GetPlayerFromId(src)
        if x then x.addAccountMoney('bank', amount, reason) return true end
    elseif QBCore then
        local p = QBCore.Functions.GetPlayer(src)
        if p then return p.Functions.AddMoney('bank', amount, reason) end
    end
    return false
end

-- Crédit d'un joueur hors ligne directement en base
local function AddBankOffline(identifier, amount)
    if QBCore then
        local raw = MySQL.scalar.await('SELECT money FROM players WHERE citizenid = ?', { identifier })
        local money = raw and json.decode(raw)
        if not money then return false end
        money.bank = (money.bank or 0) + amount
        MySQL.update.await('UPDATE players SET money = ? WHERE citizenid = ?', { json.encode(money), identifier })
        return true
    elseif ESX then
        local raw = MySQL.scalar.await('SELECT accounts FROM users WHERE identifier = ?', { identifier })
        local accounts = raw and json.decode(raw)
        if not accounts then return false end
        accounts.bank = (accounts.bank or 0) + amount
        MySQL.update.await('UPDATE users SET accounts = ? WHERE identifier = ?', { json.encode(accounts), identifier })
        return true
    end
    return false
end

-- Avec Fivemanage, l'envoi se fait toujours par lien à usage unique :
-- le passage par le serveur coupe les fichiers (erreur « unexpected EOF »).
function EffectiveUploadMethod()
    local m = Config.Camera.UploadMethod
    if m ~= 'client' and tostring(Config.Camera.ImageUrl):find('fivemanage') then return 'presigned' end
    return m
end

-- Appel sécurisé d'une fonction d'elyzea_inventory : renvoie nil si elle n'existe pas
local function Ox(fn, ...)
    if GetResourceState('elyzea_inventory') ~= 'started' then return nil end
    local ok, res = pcall(function(...) return exports.elyzea_inventory[fn](exports.elyzea_inventory, ...) end, ...)
    if ok then return res end
    return nil
end

local function HasPhoneItem(src)
    if not Config.RequireItem then return true end
    local count = Ox('Search', src, 'count', Config.ItemName)
    if count ~= nil then
        return count > 0
    elseif ESX then
        local x = ESX.GetPlayerFromId(src)
        local item = x and x.getInventoryItem(Config.ItemName)
        return item and item.count > 0
    elseif QBCore then
        local p = QBCore.Functions.GetPlayer(src)
        return p and p.Functions.GetItemByName(Config.ItemName) ~= nil
    end
    return true
end

-- ---------------------------------------------------------
--  Joueurs & numéros
-- ---------------------------------------------------------
local function GenerateNumber()
    return (Config.NumberFormat:gsub('#', function() return tostring(math.random(0, 9)) end))
end

local function EnsurePlayer(src)
    if Players[src] then return Players[src] end
    local t = GetGameTimer()
    while not SchemaReady and GetGameTimer() - t < 15000 do Wait(100) end
    local identifier = GetIdentifier(src)
    if not identifier then return nil end

    local row = MySQL.single.await('SELECT number, settings, passcode FROM elyzea_phones WHERE identifier = ?', { identifier })
    if not row then
        local number
        repeat
            number = GenerateNumber()
        until not MySQL.scalar.await('SELECT 1 FROM elyzea_phones WHERE number = ?', { number })
        MySQL.insert.await('INSERT INTO elyzea_phones (identifier, number, settings) VALUES (?, ?, ?)',
            { identifier, number, json.encode(Config.DefaultSettings) })
        row = { number = number, settings = json.encode(Config.DefaultSettings) }
    end

    local settings = json.decode(row.settings or '{}') or {}
    for k, v in pairs(Config.DefaultSettings) do
        if settings[k] == nil then settings[k] = type(v) == 'table' and {} or v end
    end

    Players[src] = { identifier = identifier, number = row.number, settings = settings, passcode = row.passcode }
    return Players[src]
end

local function GetSourceByNumber(number)
    for src, data in pairs(Players) do
        if data.number == number then return src end
    end
end

local function ResetPlayer(src)
    Players[src] = nil
    CreateThread(function() EnsurePlayer(src) end)
end

AddEventHandler('esx:playerLoaded', function(src) ResetPlayer(src) end)
AddEventHandler('elyzea:server:playerLoaded', function(src) ResetPlayer(src) end)

CreateThread(function()
    Wait(1000)
    for _, id in ipairs(GetPlayers()) do EnsurePlayer(tonumber(id)) end
end)

local function trim(s, max)
    if type(s) ~= 'string' then return '' end
    s = s:gsub('^%s+', ''):gsub('%s+$', '')
    if max and #s > max then s = s:sub(1, max) end
    return s
end

-- payload = { app, key, params } : le texte est traduit côté téléphone selon la langue du joueur
local function Notify(src, payload)
    TriggerClientEvent('elyzea_aura:client:notify', src, payload)
end

-- ---------------------------------------------------------
--  Système de callbacks
-- ---------------------------------------------------------
local Callbacks = {}
local function Register(name, fn) Callbacks[name] = fn end

RegisterNetEvent('elyzea_aura:server:cb', function(name, reqId, args)
    local src = source
    local fn = Callbacks[name]
    if not fn then
        TriggerClientEvent('elyzea_aura:client:cb', src, reqId, { ok = false, error = 'unknown' })
        return
    end
    local me = EnsurePlayer(src)
    if not me then
        TriggerClientEvent('elyzea_aura:client:cb', src, reqId, { ok = false, error = 'not_loaded' })
        return
    end
    local ok, result = pcall(fn, src, me, type(args) == 'table' and args or {})
    if not ok then
        print(('[elyzea_aura] Erreur dans %s : %s'):format(name, result))
        result = { ok = false, error = 'server' }
    end
    TriggerClientEvent('elyzea_aura:client:cb', src, reqId, result)
end)

-- ---------------------------------------------------------
--  Appli (magasin) : vérifie qu'une app est installée
-- ---------------------------------------------------------
local StoreApps = {}
for _, id in ipairs(Config.StoreApps) do StoreApps[id] = true end
local SocialApps = { birdy = true, instapick = true }

local function HasApp(player, app)
    for _, id in ipairs(player.settings.installed or {}) do
        if id == app then return true end
    end
    return false
end

-- ---------------------------------------------------------
--  Profil & réglages
-- ---------------------------------------------------------
Register('canOpen', function(src)
    return { ok = HasPhoneItem(src) }
end)

Register('getProfile', function(src, me)
    return {
        ok = true,
        number = me.number,
        name = GetCharName(src),
        settings = me.settings,
        bank = (Config.Bank.Enabled and Framework ~= 'standalone') and GetBank(src) or nil,
        services = Config.Services,
        places = (function()
            local out = {}
            for i, p in ipairs(Config.Places) do out[i] = { id = i, label = p.label } end
            return out
        end)(),
        cameraEnabled = Config.Camera.Enabled,
        camera = {
            method = EffectiveUploadMethod(),
            imageField = Config.Camera.ImageField, videoField = Config.Camera.VideoField,
            maxVideo = Config.Camera.MaxVideoSeconds,
            bitrate = Config.Camera.VideoBitrate,
            flipY = Config.Camera.FlipY,
            -- envoyé uniquement en mode 'client'
            direct = Config.Camera.UploadMethod == 'client' and {
                imageUrl = Config.Camera.ImageUrl, videoUrl = Config.Camera.VideoUrl,
                imageField = Config.Camera.ImageField, videoField = Config.Camera.VideoField,
                headers = Config.Camera.Headers, path = Config.Camera.ResponsePath,
            } or nil,
        },
        itoune = {
            spotify = Config.Itoune.YouTubeApiKey ~= '',
            distance = Config.Itoune.Distance,
            maxVolume = Config.Itoune.MaxVolume,
        },
        dating = { minAge = Config.Dating.MinAge, maxPhotos = Config.Dating.MaxPhotos },
        passcode = me.passcode and #me.passcode > 0 and { set = true, length = tonumber(me.passcode:match('^(%d):')) or 4 } or { set = false },
        bankEnabled = Config.Bank.Enabled and Framework ~= 'standalone',
        auraDrop = Config.AuraDrop.Enabled,
    }
end)

Register('saveSettings', function(src, me, args)
    if type(args.settings) ~= 'table' then return { ok = false } end
    for k, _ in pairs(Config.DefaultSettings) do
        if args.settings[k] ~= nil then me.settings[k] = args.settings[k] end
    end
    local installed = {}
    for _, id in ipairs(type(me.settings.installed) == 'table' and me.settings.installed or {}) do
        if StoreApps[id] then installed[#installed + 1] = id end
    end
    me.settings.installed = installed
    local s = me.settings
    if type(s.accent) ~= 'string' or not (s.accent:match('^#%x%x%x%x%x%x$') or s.accent:match('^%a+$')) then s.accent = Config.DefaultSettings.accent end
    if type(s.wallpaper) ~= 'string' or #s.wallpaper > 400 or not (s.wallpaper:match('^%a+$') or s.wallpaper:match('^https://')) then s.wallpaper = Config.DefaultSettings.wallpaper end
    if type(s.deviceName) ~= 'string' then s.deviceName = '' end
    s.deviceName = trim(s.deviceName, 30)
    if type(s.cardName) ~= 'string' then s.cardName = '' end
    s.cardName = trim(s.cardName, 40)
    MySQL.update.await('UPDATE elyzea_phones SET settings = ? WHERE identifier = ?', { json.encode(me.settings), me.identifier })
    return { ok = true, settings = me.settings }
end)

-- ---------------------------------------------------------
--  Contacts
-- ---------------------------------------------------------
Register('getContacts', function(src, me)
    local rows = MySQL.query.await('SELECT id, name, number, favorite FROM elyzea_contacts WHERE owner = ? ORDER BY name ASC', { me.identifier })
    return { ok = true, contacts = rows or {} }
end)

Register('saveContact', function(src, me, args)
    local name, number = trim(args.name, 50), trim(args.number, 20)
    if name == '' or number == '' then return { ok = false, error = 'Nom et numéro requis' } end
    local fav = args.favorite and 1 or 0
    if args.id then
        MySQL.update.await('UPDATE elyzea_contacts SET name = ?, number = ?, favorite = ? WHERE id = ? AND owner = ?',
            { name, number, fav, tonumber(args.id), me.identifier })
    else
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_contacts WHERE owner = ?', { me.identifier })
        if count >= Config.Limits.ContactsMax then return { ok = false, error = 'Répertoire plein' } end
        MySQL.insert.await('INSERT INTO elyzea_contacts (owner, name, number, favorite) VALUES (?, ?, ?, ?)',
            { me.identifier, name, number, fav })
    end
    return { ok = true }
end)

Register('deleteContact', function(src, me, args)
    MySQL.update.await('DELETE FROM elyzea_contacts WHERE id = ? AND owner = ?', { tonumber(args.id), me.identifier })
    return { ok = true }
end)

-- ---------------------------------------------------------
--  Messages
-- ---------------------------------------------------------
Register('getConversations', function(src, me)
    local rows = MySQL.query.await([[
        SELECT sender, receiver, message, is_read, UNIX_TIMESTAMP(created_at) AS ts
        FROM elyzea_messages WHERE sender = ? OR receiver = ?
        ORDER BY id DESC LIMIT 600
    ]], { me.number, me.number }) or {}

    local convs, order = {}, {}
    for _, m in ipairs(rows) do
        local other = m.sender == me.number and m.receiver or m.sender
        if not convs[other] then
            convs[other] = { number = other, last = m.message, ts = m.ts, unread = 0 }
            order[#order + 1] = other
        end
        if m.receiver == me.number and m.is_read == 0 then
            convs[other].unread = convs[other].unread + 1
        end
    end
    local out = {}
    for i, n in ipairs(order) do out[i] = convs[n] end
    return { ok = true, conversations = out }
end)

Register('getMessages', function(src, me, args)
    local other = trim(args.number, 20)
    local rows = MySQL.query.await([[
        SELECT id, sender, message, UNIX_TIMESTAMP(created_at) AS ts FROM elyzea_messages
        WHERE (sender = ? AND receiver = ?) OR (sender = ? AND receiver = ?)
        ORDER BY id DESC LIMIT 150
    ]], { me.number, other, other, me.number }) or {}
    MySQL.update('UPDATE elyzea_messages SET is_read = 1 WHERE sender = ? AND receiver = ?', { other, me.number })
    local out = {}
    for i = #rows, 1, -1 do
        local r = rows[i]
        out[#out + 1] = { id = r.id, mine = r.sender == me.number, message = r.message, ts = r.ts }
    end
    return { ok = true, messages = out }
end)

Register('sendMessage', function(src, me, args)
    local target, msg = trim(args.number, 20), trim(args.message, Config.Limits.MessageLength)
    if target == '' or msg == '' then return { ok = false } end
    if me.settings.airplane then return { ok = false, error = 'Mode avion activé' } end
    local id = MySQL.insert.await('INSERT INTO elyzea_messages (sender, receiver, message) VALUES (?, ?, ?)', { me.number, target, msg })
    local tsrc = GetSourceByNumber(target)
    if tsrc and not Players[tsrc].settings.airplane then
        TriggerClientEvent('elyzea_aura:client:newMessage', tsrc, { id = id, from = me.number, message = msg, ts = os.time() })
    end
    return { ok = true, message = { id = id, mine = true, message = msg, ts = os.time() } }
end)

Register('deleteConversation', function(src, me, args)
    local other = trim(args.number, 20)
    MySQL.update.await('DELETE FROM elyzea_messages WHERE (sender = ? AND receiver = ?) OR (sender = ? AND receiver = ?)',
        { me.number, other, other, me.number })
    return { ok = true }
end)

-- ---------------------------------------------------------
--  Appels
-- ---------------------------------------------------------
local function LogCall(call, status)
    local duration = (call.state == 'active' and call.startedAt) and (os.time() - call.startedAt) or 0
    MySQL.insert('INSERT INTO elyzea_calls (caller, receiver, status, duration) VALUES (?, ?, ?, ?)',
        { call.callerNumber, call.targetNumber, status, duration })
end

local function EndCall(callId, reason)
    local call = Calls[callId]
    if not call then return end
    local status = call.state == 'active' and 'answered' or (reason == 'declined' and 'declined' or 'missed')
    LogCall(call, status)

    if Config.Voice == 'saltychat' and call.state == 'active' and GetResourceState('saltychat') == 'started' then
        exports.saltychat:EndCall(call.caller, call.target)
    end

    for _, s in ipairs({ call.caller, call.target }) do
        if PlayerCall[s] == callId then PlayerCall[s] = nil end
        TriggerClientEvent('elyzea_aura:client:callEnded', s, { id = callId, reason = reason })
    end
    Calls[callId] = nil
end

Register('getCalls', function(src, me)
    local rows = MySQL.query.await([[
        SELECT id, caller, receiver, status, duration, UNIX_TIMESTAMP(created_at) AS ts FROM elyzea_calls
        WHERE caller = ? OR receiver = ? ORDER BY id DESC LIMIT 60
    ]], { me.number, me.number }) or {}
    local out = {}
    for i, r in ipairs(rows) do
        local outgoing = r.caller == me.number
        out[i] = {
            id = r.id, number = outgoing and r.receiver or r.caller,
            outgoing = outgoing, status = r.status, duration = r.duration, ts = r.ts
        }
    end
    return { ok = true, calls = out }
end)

Register('startCall', function(src, me, args)
    local number = trim(args.number, 20)
    if number == '' or number == me.number then return { ok = false, error = 'Numéro invalide' } end
    if me.settings.airplane then return { ok = false, error = 'Mode avion activé' } end
    if PlayerCall[src] then return { ok = false, error = 'Déjà en ligne' } end

    local tsrc = GetSourceByNumber(number)
    if not tsrc or Players[tsrc].settings.airplane or not HasPhoneItem(tsrc) then
        MySQL.insert('INSERT INTO elyzea_calls (caller, receiver, status) VALUES (?, ?, ?)', { me.number, number, 'missed' })
        return { ok = false, error = 'Correspondant injoignable' }
    end
    if PlayerCall[tsrc] then return { ok = false, error = 'Ligne occupée' } end

    callCounter = callCounter + 1
    local callId = callCounter + 1000
    Calls[callId] = { caller = src, target = tsrc, callerNumber = me.number, targetNumber = number, state = 'ringing' }
    PlayerCall[src], PlayerCall[tsrc] = callId, callId

    TriggerClientEvent('elyzea_aura:client:incomingCall', tsrc, { id = callId, number = me.number })

    SetTimeout(30000, function()
        if Calls[callId] and Calls[callId].state == 'ringing' then EndCall(callId, 'timeout') end
    end)
    return { ok = true, id = callId }
end)

Register('acceptCall', function(src, me, args)
    local call = Calls[tonumber(args.id)]
    if not call or call.target ~= src or call.state ~= 'ringing' then return { ok = false } end
    call.state, call.startedAt = 'active', os.time()

    if Config.Voice == 'saltychat' and GetResourceState('saltychat') == 'started' then
        exports.saltychat:EstablishCall(call.caller, call.target)
    end
    for _, s in ipairs({ call.caller, call.target }) do
        TriggerClientEvent('elyzea_aura:client:callStarted', s, { id = tonumber(args.id) })
    end
    return { ok = true }
end)

Register('endCall', function(src, me, args)
    local callId = tonumber(args.id) or PlayerCall[src]
    local call = Calls[callId]
    if not call or (call.caller ~= src and call.target ~= src) then return { ok = false } end
    local reason = (call.state == 'ringing' and call.target == src) and 'declined' or 'hangup'
    EndCall(callId, reason)
    return { ok = true }
end)

AddEventHandler('playerDropped', function()
    local src = source
    if PlayerCall[src] then EndCall(PlayerCall[src], 'dropped') end
    Players[src] = nil
end)

-- ---------------------------------------------------------
--  Comptes Birdy / InstaPick
-- ---------------------------------------------------------
local function GetAccount(identifier, app)
    return MySQL.single.await('SELECT username, display_name FROM elyzea_accounts WHERE identifier = ? AND app = ?', { identifier, app })
end

Register('getAccount', function(src, me, args)
    if not SocialApps[args.app] then return { ok = false } end
    return { ok = true, account = GetAccount(me.identifier, args.app) }
end)

Register('createAccount', function(src, me, args)
    local app = args.app
    if not SocialApps[app] or not HasApp(me, app) then return { ok = false, error = 'Application non installée' } end
    local username = trim(args.username, 20):lower()
    local display = trim(args.display, 40)
    if not username:match('^[a-z0-9_%.]+$') or #username < 3 then
        return { ok = false, error = 'Identifiant : 3 à 20 caractères, lettres, chiffres, _ ou .' }
    end
    if display == '' then display = GetCharName(src) end
    if GetAccount(me.identifier, app) then return { ok = false, error = 'Compte déjà créé' } end
    if MySQL.scalar.await('SELECT 1 FROM elyzea_accounts WHERE app = ? AND username = ?', { app, username }) then
        return { ok = false, error = 'Cet identifiant est déjà pris' }
    end
    MySQL.insert.await('INSERT INTO elyzea_accounts (identifier, app, username, display_name) VALUES (?, ?, ?, ?)',
        { me.identifier, app, username, display })
    return { ok = true, account = { username = username, display_name = display } }
end)

-- ---------------------------------------------------------
--  Fils sociaux (Birdy = texte, InstaPick = photo)
-- ---------------------------------------------------------
local FEED_SQL = [[
    SELECT p.id, p.content, p.image, p.repost_of, UNIX_TIMESTAMP(p.created_at) AS ts,
      a.username, a.display_name, (p.author = ?) AS mine,
      o.content AS o_content, o.image AS o_image, oa.username AS o_username, oa.display_name AS o_display,
      (SELECT COUNT(*) FROM elyzea_social_likes l WHERE l.post_id = IFNULL(p.repost_of, p.id)) AS likes,
      (SELECT COUNT(*) FROM elyzea_social_likes l WHERE l.post_id = IFNULL(p.repost_of, p.id) AND l.identifier = ?) AS liked,
      (SELECT COUNT(*) FROM elyzea_social_posts r WHERE r.repost_of = IFNULL(p.repost_of, p.id)) AS reposts,
      (SELECT COUNT(*) FROM elyzea_social_comments c WHERE c.post_id = IFNULL(p.repost_of, p.id)) AS comments
    FROM elyzea_social_posts p
    JOIN elyzea_accounts a ON a.identifier = p.author AND a.app = p.app
    LEFT JOIN elyzea_social_posts o ON o.id = p.repost_of
    LEFT JOIN elyzea_accounts oa ON oa.identifier = o.author AND oa.app = o.app
    WHERE p.app = ? %s
    ORDER BY p.id DESC LIMIT 60
]]

local function CleanFeed(rows)
    for _, r in ipairs(rows) do
        r.mine = r.mine == 1 or r.mine == true
        r.liked = (r.liked or 0) > 0
    end
    return rows
end

Register('getFeed', function(src, me, args)
    if not SocialApps[args.app] then return { ok = false } end
    local rows
    if args.username then
        rows = MySQL.query.await(FEED_SQL:format('AND a.username = ?'), { me.identifier, me.identifier, args.app, tostring(args.username) })
    else
        rows = MySQL.query.await(FEED_SQL:format(''), { me.identifier, me.identifier, args.app })
    end
    return { ok = true, posts = CleanFeed(rows or {}) }
end)

Register('createPost', function(src, me, args)
    local app = args.app
    if not SocialApps[app] or not HasApp(me, app) then return { ok = false, error = 'Application non installée' } end
    local account = GetAccount(me.identifier, app)
    if not account then return { ok = false, error = 'Crée d\'abord ton compte' } end

    local content = trim(args.content, Config.Limits.PostLength)
    local image = trim(args.image, 500)
    if image ~= '' and not image:match('^https://') then return { ok = false, error = 'Le lien de l\'image doit commencer par https://' } end
    if app == 'instapick' and image == '' then return { ok = false, error = 'Choisis une photo' } end
    if app == 'birdy' and content == '' then return { ok = false, error = 'Écris quelque chose' } end

    MySQL.insert.await('INSERT INTO elyzea_social_posts (app, author, content, image) VALUES (?, ?, ?, ?)',
        { app, me.identifier, content, image ~= '' and image or nil })

    -- Notifications : mentions @identifiant, sinon abonnés à l'app
    local mentioned = {}
    for handle in content:gmatch('@([%w_%.]+)') do mentioned[handle:lower()] = true end
    for s, data in pairs(Players) do
        if s ~= src and data.settings.notifications and HasApp(data, app) then
            local acc = next(mentioned) and GetAccount(data.identifier, app)
            if acc and mentioned[acc.username] then
                Notify(s, { app = app, key = 'mention', params = { name = account.display_name }, text = content })
            elseif app == 'instapick' or not next(mentioned) then
                Notify(s, { app = app, key = app == 'instapick' and 'newPhoto' or 'newPost', params = { name = account.display_name }, text = content })
            end
        end
    end
    return { ok = true }
end)

Register('likePost', function(src, me, args)
    local id = tonumber(args.id)
    local exists = MySQL.scalar.await('SELECT 1 FROM elyzea_social_likes WHERE post_id = ? AND identifier = ?', { id, me.identifier })
    if exists then
        MySQL.update.await('DELETE FROM elyzea_social_likes WHERE post_id = ? AND identifier = ?', { id, me.identifier })
    else
        MySQL.insert.await('INSERT INTO elyzea_social_likes (post_id, identifier) VALUES (?, ?)', { id, me.identifier })
    end
    return { ok = true, liked = not exists }
end)

Register('repost', function(src, me, args)
    local id = tonumber(args.id)
    if not HasApp(me, 'birdy') or not GetAccount(me.identifier, 'birdy') then return { ok = false, error = 'Crée d\'abord ton compte' } end
    local original = MySQL.single.await('SELECT id, author, repost_of FROM elyzea_social_posts WHERE id = ? AND app = ?', { id, 'birdy' })
    if not original then return { ok = false } end
    local target = original.repost_of or original.id
    local existing = MySQL.scalar.await('SELECT id FROM elyzea_social_posts WHERE author = ? AND repost_of = ?', { me.identifier, target })
    if existing then
        MySQL.update.await('DELETE FROM elyzea_social_posts WHERE id = ?', { existing })
        return { ok = true, reposted = false }
    end
    MySQL.insert.await('INSERT INTO elyzea_social_posts (app, author, content, repost_of) VALUES (?, ?, ?, ?)', { 'birdy', me.identifier, '', target })
    return { ok = true, reposted = true }
end)

Register('deletePost', function(src, me, args)
    local id = tonumber(args.id)
    local affected = MySQL.update.await('DELETE FROM elyzea_social_posts WHERE id = ? AND author = ?', { id, me.identifier })
    if affected > 0 then
        MySQL.update('DELETE FROM elyzea_social_likes WHERE post_id = ?', { id })
        MySQL.update('DELETE FROM elyzea_social_comments WHERE post_id = ?', { id })
        MySQL.update('DELETE FROM elyzea_social_posts WHERE repost_of = ?', { id })
    end
    return { ok = true }
end)

Register('getComments', function(src, me, args)
    local rows = MySQL.query.await([[
        SELECT c.id, c.content, UNIX_TIMESTAMP(c.created_at) AS ts, a.username, a.display_name
        FROM elyzea_social_comments c
        JOIN elyzea_social_posts p ON p.id = c.post_id
        JOIN elyzea_accounts a ON a.identifier = c.author AND a.app = p.app
        WHERE c.post_id = ? ORDER BY c.id ASC LIMIT 100
    ]], { tonumber(args.id) })
    return { ok = true, comments = rows or {} }
end)

Register('addComment', function(src, me, args)
    local id = tonumber(args.id)
    local content = trim(args.content, 200)
    if content == '' then return { ok = false } end
    local post = MySQL.single.await('SELECT app, author FROM elyzea_social_posts WHERE id = ?', { id })
    if not post then return { ok = false } end
    local account = GetAccount(me.identifier, post.app)
    if not account then return { ok = false, error = 'Crée d\'abord ton compte' } end
    MySQL.insert.await('INSERT INTO elyzea_social_comments (post_id, author, content) VALUES (?, ?, ?)', { id, me.identifier, content })
    for s, data in pairs(Players) do
        if data.identifier == post.author and s ~= src then
            Notify(s, { app = post.app, key = 'comment', params = { name = account.display_name }, text = content })
        end
    end
    return { ok = true }
end)

-- ---------------------------------------------------------
--  Itoune (bibliothèque musicale personnelle)
-- ---------------------------------------------------------
local function UrlEncode(str)
    return (tostring(str):gsub('[^%w%-%._~]', function(c) return ('%%%02X'):format(c:byte()) end))
end

local function HttpGet(url)
    local p = promise.new()
    PerformHttpRequest(url, function(code, body) p:resolve({ code = code, body = body }) end, 'GET', '', { ['User-Agent'] = 'Mozilla/5.0 ElyzeaAura' })
    return Citizen.Await(p)
end

local function YouTubeId(link)
    return link:match('youtu%.be/([%w_%-]+)') or link:match('[?&]v=([%w_%-]+)')
        or link:match('/shorts/([%w_%-]+)') or link:match('/embed/([%w_%-]+)') or link:match('/live/([%w_%-]+)')
end

-- Transforme un lien YouTube / Spotify / audio direct en morceau jouable
local function ResolveTrack(link)
    local ytId = link:match('youtu') and YouTubeId(link)
    if ytId then
        local url = 'https://www.youtube.com/watch?v=' .. ytId
        local r = HttpGet('https://www.youtube.com/oembed?format=json&url=' .. UrlEncode(url))
        local ok, meta = pcall(json.decode, r.body or '')
        if r.code == 401 or r.code == 403 then return nil, 'Cette vidéo ne peut pas être lue en dehors de YouTube' end
        if r.code == 404 or r.code == 400 then return nil, 'Vidéo YouTube introuvable ou privée' end
        if not ok or type(meta) ~= 'table' then meta = {} end -- titre indisponible : la vidéo reste jouable
        return { title = meta.title or ('Vidéo YouTube ' .. ytId), artist = meta.author_name or 'YouTube', url = url,
            thumb = ('https://i.ytimg.com/vi/%s/hqdefault.jpg'):format(ytId), source = 'youtube' }
    end

    local spId = link:match('open%.spotify%.com/.-track/(%w+)')
    if spId then
        if Config.Itoune.YouTubeApiKey == '' then return nil, 'Les liens Spotify ne sont pas activés sur ce serveur' end
        local r = HttpGet('https://open.spotify.com/oembed?url=' .. UrlEncode('https://open.spotify.com/track/' .. spId))
        local meta = r.code == 200 and json.decode(r.body or '') or nil
        if not meta or not meta.title then return nil, 'Morceau Spotify introuvable' end
        local search = HttpGet(('https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&maxResults=1&q=%s&key=%s')
            :format(UrlEncode(meta.title .. ' audio'), Config.Itoune.YouTubeApiKey))
        local res = search.code == 200 and json.decode(search.body or '') or nil
        local item = res and res.items and res.items[1]
        if not item or not item.id or not item.id.videoId then return nil, 'Aucune version écoutable trouvée pour ce morceau' end
        return { title = meta.title, artist = item.snippet and item.snippet.channelTitle or 'Spotify',
            url = 'https://www.youtube.com/watch?v=' .. item.id.videoId, thumb = meta.thumbnail_url, source = 'spotify' }
    end

    if link:match('^https://') then
        local name = link:match('/([^/%?]+)%.%w+$') or link:match('/([^/%?]+)$') or 'Morceau'
        return { title = name:gsub('[_%-]', ' '), artist = 'Lien audio', url = link, source = 'direct' }
    end
    return nil, 'Lien non reconnu : collez un lien YouTube, Spotify ou audio'
end

Register('getTracks', function(src, me)
    local rows = MySQL.query.await('SELECT id, title, artist, url, thumb, source FROM elyzea_tracks WHERE owner = ? ORDER BY id DESC', { me.identifier })
    return { ok = true, tracks = rows or {} }
end)

Register('addTrack', function(src, me, args)
    if not HasApp(me, 'itoune') then return { ok = false, error = 'Application non installée' } end
    local link = trim(args.link or args.url, 500)
    if link == '' then return { ok = false, error = 'Collez un lien' } end
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_tracks WHERE owner = ?', { me.identifier })
    if count >= Config.Limits.TracksMax then return { ok = false, error = 'Bibliothèque pleine' } end
    local track, err = ResolveTrack(link)
    if not track then return { ok = false, error = err } end
    track.title = trim(track.title, 80); track.artist = trim(track.artist or '', 60)
    if track.artist == '' then track.artist = 'Artiste inconnu' end
    track.id = MySQL.insert.await('INSERT INTO elyzea_tracks (owner, title, artist, url, thumb, source) VALUES (?, ?, ?, ?, ?, ?)',
        { me.identifier, track.title, track.artist, track.url, track.thumb, track.source })
    return { ok = true, track = track }
end)

-- Diffusion de la musique (haut-parleur) : les joueurs proches l'entendent, le volume baisse avec la distance
local MusicRate, ActiveMusic = {}, {} -- ActiveMusic[src] = { url, offset, startedAt, paused, volume }

local function MusicPosition(m)
    return m.offset + (m.paused and 0 or (os.time() - m.startedAt))
end

RegisterNetEvent('elyzea_aura:server:music', function(action, data)
    local src = source
    if not Players[src] then return end
    local now = GetGameTimer()
    if action ~= 'volume' then
        if (MusicRate[src] or 0) > now then return end
        MusicRate[src] = now + 300
    end
    data = type(data) == 'table' and data or {}
    local m, out = ActiveMusic[src], {}
    if action == 'play' then
        if type(data.url) ~= 'string' or #data.url > 500 or not data.url:match('^https://') then return end
        m = { url = data.url, offset = tonumber(data.time) or 0, startedAt = os.time(), paused = false, volume = math.min(math.max(tonumber(data.volume) or 0.5, 0), 1) }
        ActiveMusic[src] = m
        out = { url = m.url, time = m.offset, volume = m.volume }
    elseif not m then
        return
    elseif action == 'pause' then
        m.offset = tonumber(data.time) or MusicPosition(m); m.paused = true
        out = { time = m.offset }
    elseif action == 'resume' then
        m.offset = tonumber(data.time) or m.offset; m.startedAt = os.time(); m.paused = false
        out = { time = m.offset }
    elseif action == 'seek' then
        m.offset = tonumber(data.time) or 0; m.startedAt = os.time()
        out = { time = m.offset }
    elseif action == 'volume' then
        m.volume = math.min(math.max(tonumber(data.volume) or 0.5, 0), 1)
        out = { volume = m.volume }
    elseif action == 'stop' then
        ActiveMusic[src] = nil
    else
        return
    end
    TriggerClientEvent('elyzea_aura:client:music', -1, src, action, out)
end)

-- Un joueur qui se connecte récupère les musiques déjà en cours autour de lui
Register('musicSync', function(src)
    local list = {}
    for s2, m in pairs(ActiveMusic) do
        if s2 ~= src and not m.paused then
            list[#list + 1] = { id = s2, url = m.url, time = MusicPosition(m), volume = m.volume }
        end
    end
    return { ok = true, list = list }
end)

AddEventHandler('playerDropped', function()
    local src = source
    ActiveMusic[src] = nil
    TriggerClientEvent('elyzea_aura:client:music', -1, src, 'stop', {})
end)

-- ---------------------------------------------------------
--  Annonces
-- ---------------------------------------------------------
Register('getAds', function(src, me)
    local rows = MySQL.query.await([[
        SELECT id, author, author_name, number, title, content, price, UNIX_TIMESTAMP(created_at) AS ts
        FROM elyzea_ads ORDER BY id DESC LIMIT 60
    ]]) or {}
    for _, r in ipairs(rows) do r.mine = r.author == me.identifier; r.author = nil end
    return { ok = true, ads = rows }
end)

Register('createAd', function(src, me, args)
    local title, content = trim(args.title, 80), trim(args.content, Config.Limits.AdLength)
    local price = tonumber(args.price)
    if title == '' or content == '' then return { ok = false, error = 'Titre et description requis' } end
    if price then price = math.max(0, math.floor(price)) end
    MySQL.insert.await('INSERT INTO elyzea_ads (author, author_name, number, title, content, price) VALUES (?, ?, ?, ?, ?, ?)',
        { me.identifier, GetCharName(src), me.number, title, content, price })
    return { ok = true }
end)

Register('deleteAd', function(src, me, args)
    MySQL.update.await('DELETE FROM elyzea_ads WHERE id = ? AND author = ?', { tonumber(args.id), me.identifier })
    return { ok = true }
end)

-- ---------------------------------------------------------
--  Notes
-- ---------------------------------------------------------
Register('getNotes', function(src, me)
    local rows = MySQL.query.await('SELECT id, title, content, UNIX_TIMESTAMP(updated_at) AS ts FROM elyzea_notes WHERE owner = ? ORDER BY updated_at DESC', { me.identifier })
    return { ok = true, notes = rows or {} }
end)

Register('saveNote', function(src, me, args)
    local title, content = trim(args.title, 80), trim(args.content, Config.Limits.NoteLength)
    if title == '' then title = 'Sans titre' end
    if args.id then
        MySQL.update.await('UPDATE elyzea_notes SET title = ?, content = ? WHERE id = ? AND owner = ?', { title, content, tonumber(args.id), me.identifier })
        return { ok = true, id = tonumber(args.id) }
    end
    local id = MySQL.insert.await('INSERT INTO elyzea_notes (owner, title, content) VALUES (?, ?, ?)', { me.identifier, title, content })
    return { ok = true, id = id }
end)

Register('deleteNote', function(src, me, args)
    MySQL.update.await('DELETE FROM elyzea_notes WHERE id = ? AND owner = ?', { tonumber(args.id), me.identifier })
    return { ok = true }
end)

-- ---------------------------------------------------------
--  Galerie
-- ---------------------------------------------------------
Register('getGallery', function(src, me)
    local rows = MySQL.query.await('SELECT id, url, type, duration, UNIX_TIMESTAMP(created_at) AS ts FROM elyzea_gallery WHERE owner = ? ORDER BY id DESC', { me.identifier })
    return { ok = true, photos = rows or {} }
end)

Register('savePhoto', function(src, me, args)
    local url = trim(args.url, 500)
    if not url:match('^https://') then return { ok = false } end
    local id = MySQL.insert.await('INSERT INTO elyzea_gallery (owner, url) VALUES (?, ?)', { me.identifier, url })
    return { ok = true, id = id }
end)

-- Lien d'envoi à usage unique (Fivemanage) : le téléphone envoie ensuite le fichier lui-même
Register('mediaUploadUrl', function(src, me, args)
    if not Config.Camera.Enabled then return { ok = false } end
    local kind = args.type == 'video' and 'video' or 'image'
    local p = promise.new()
    local presigned = Config.Camera.PresignedUrl or 'https://api.fivemanage.com/api/presigned-url?fileType=%s'
    PerformHttpRequest(presigned:format(kind), function(code, body, _, errorData)
        p:resolve({ code = code, body = body or errorData })
    end, 'GET', '', Config.Camera.Headers or {})
    local r = Citizen.Await(p)
    local ok, data = pcall(json.decode, r.body or '')
    local url = ok and type(data) == 'table' and (data.presignedUrl or (data.data and data.data.presignedUrl))
    if not url then
        print(('^1[elyzea_aura] Lien d\'envoi refusé par l\'hébergeur (code %s) : %s^0'):format(r.code, tostring(r.body):sub(1, 300)))
        if r.code == 401 or r.code == 403 then return { ok = false, error = 'Clé API de l\'hébergeur manquante ou invalide' } end
        return { ok = false, error = 'L\'hébergeur a refusé le fichier' }
    end
    return { ok = true, url = url }
end)

Register('saveMedia', function(src, me, args)
    local url = trim(args.url, 500)
    if not url:match('^https://') then return { ok = false } end
    local kind = args.type == 'video' and 'video' or 'photo'
    local id = MySQL.insert.await('INSERT INTO elyzea_gallery (owner, url, type, duration) VALUES (?, ?, ?, ?)',
        { me.identifier, url, kind, math.floor(tonumber(args.duration) or 0) })
    return { ok = true, id = id }
end)

Register('deletePhoto', function(src, me, args)
    MySQL.update.await('DELETE FROM elyzea_gallery WHERE id = ? AND owner = ?', { tonumber(args.id), me.identifier })
    return { ok = true }
end)

-- ---------------------------------------------------------
--  Banque (connectée au compte bancaire du framework)
-- ---------------------------------------------------------
local function BankLog(identifier, label, amount)
    MySQL.insert('INSERT INTO elyzea_bank_history (owner, label, amount) VALUES (?, ?, ?)', { identifier, label, amount })
end

local function BankAvailable()
    return Config.Bank.Enabled and Framework ~= 'standalone'
end

Register('getBank', function(src, me)
    if not BankAvailable() then return { ok = false } end
    local rows = MySQL.query.await('SELECT label, amount, UNIX_TIMESTAMP(created_at) AS ts FROM elyzea_bank_history WHERE owner = ? ORDER BY id DESC LIMIT 40', { me.identifier })
    local pending = MySQL.scalar.await('SELECT COUNT(*) FROM elyzea_bank_requests WHERE to_number = ? AND status = ?', { me.number, 'pending' })
    return { ok = true, balance = GetBank(src), history = rows or {}, pending = pending or 0 }
end)

Register('getBalance', function(src)
    if not BankAvailable() then return { ok = false } end
    return { ok = true, balance = GetBank(src) }
end)

-- Virement : fonctionne aussi si le destinataire est hors ligne
local function DoTransfer(src, me, number, amount, label)
    if amount < Config.Bank.MinTransfer or amount > Config.Bank.MaxTransfer then return false, 'Montant invalide' end
    if number == me.number then return false, 'Impossible de vous virer à vous-même' end

    local tsrc = GetSourceByNumber(number)
    local targetIdentifier = tsrc and Players[tsrc].identifier
        or MySQL.scalar.await('SELECT identifier FROM elyzea_phones WHERE number = ?', { number })
    if not targetIdentifier then return false, 'Numéro introuvable' end
    if not tsrc and not Config.Bank.OfflineTransfers then return false, 'Destinataire hors ligne ou introuvable' end

    if not RemoveBank(src, amount, 'elyzea-transfer') then return false, 'Solde insuffisant' end
    local credited = tsrc and AddBank(tsrc, amount, 'elyzea-transfer') or (not tsrc and AddBankOffline(targetIdentifier, amount))
    if not credited then
        AddBank(src, amount, 'elyzea-refund')
        return false, 'Virement impossible vers ce compte'
    end

    local suffix = (label and label ~= '') and (' (' .. label .. ')') or ''
    BankLog(me.identifier, number .. suffix, -amount)
    BankLog(targetIdentifier, me.number .. suffix, amount)
    if tsrc then
        Notify(tsrc, { app = 'bank', key = 'bankReceived', params = { amount = amount, number = me.number } })
        TriggerClientEvent('elyzea_aura:client:bankUpdate', tsrc, GetBank(tsrc))
    end
    return true
end

Register('transfer', function(src, me, args)
    if not BankAvailable() then return { ok = false } end
    local ok, err = DoTransfer(src, me, trim(args.number, 20), math.floor(tonumber(args.amount) or 0), trim(args.label, 40))
    if not ok then return { ok = false, error = err } end
    return { ok = true, balance = GetBank(src) }
end)

-- Demandes de paiement
Register('requestMoney', function(src, me, args)
    if not BankAvailable() then return { ok = false } end
    local number, amount = trim(args.number, 20), math.floor(tonumber(args.amount) or 0)
    local reason = trim(args.reason, 60)
    if amount < Config.Bank.MinTransfer or amount > Config.Bank.MaxTransfer then return { ok = false, error = 'Montant invalide' } end
    if number == me.number then return { ok = false, error = 'Impossible de vous virer à vous-même' } end
    if not MySQL.scalar.await('SELECT 1 FROM elyzea_phones WHERE number = ?', { number }) then return { ok = false, error = 'Numéro introuvable' } end
    MySQL.insert.await('INSERT INTO elyzea_bank_requests (from_number, to_number, amount, reason) VALUES (?, ?, ?, ?)', { me.number, number, amount, reason })
    local tsrc = GetSourceByNumber(number)
    if tsrc then Notify(tsrc, { app = 'bank', key = 'bankRequest', params = { amount = amount, number = me.number } }) end
    return { ok = true }
end)

Register('getRequests', function(src, me)
    local rows = MySQL.query.await([[
        SELECT id, from_number, to_number, amount, reason, status, UNIX_TIMESTAMP(created_at) AS ts FROM elyzea_bank_requests
        WHERE (to_number = ? OR from_number = ?) ORDER BY id DESC LIMIT 30
    ]], { me.number, me.number }) or {}
    for _, r in ipairs(rows) do r.incoming = r.to_number == me.number end
    return { ok = true, requests = rows }
end)

Register('answerRequest', function(src, me, args)
    local req = MySQL.single.await('SELECT * FROM elyzea_bank_requests WHERE id = ? AND to_number = ? AND status = ?', { tonumber(args.id), me.number, 'pending' })
    if not req then return { ok = false, error = 'Demande introuvable' } end
    if args.accept then
        local ok, err = DoTransfer(src, me, req.from_number, req.amount, req.reason)
        if not ok then return { ok = false, error = err } end
    end
    MySQL.update.await('UPDATE elyzea_bank_requests SET status = ? WHERE id = ?', { args.accept and 'paid' or 'declined', req.id })
    local fsrc = GetSourceByNumber(req.from_number)
    if fsrc then Notify(fsrc, { app = 'bank', key = args.accept and 'requestPaid' or 'requestDeclined', params = { amount = req.amount, number = me.number } }) end
    return { ok = true, balance = GetBank(src) }
end)

-- ---------------------------------------------------------
--  Sécurité : code de déverrouillage (stocké haché)
-- ---------------------------------------------------------
local Attempts = {} -- [identifier] = { count, lockedUntil }

local function HashCode(identifier, code)
    return ('%d:%s'):format(#code, tostring(GetHashKey(Config.Security.Salt .. identifier .. code)))
end

Register('setPasscode', function(src, me, args)
    local code = tostring(args.code or '')
    if not code:match('^%d+$') or (#code ~= 4 and #code ~= 6) then return { ok = false, error = 'Le code doit contenir 4 ou 6 chiffres' } end
    if me.passcode and me.passcode ~= '' and HashCode(me.identifier, tostring(args.old or '')) ~= me.passcode then
        return { ok = false, error = 'Code actuel incorrect' }
    end
    me.passcode = HashCode(me.identifier, code)
    MySQL.update.await('UPDATE elyzea_phones SET passcode = ? WHERE identifier = ?', { me.passcode, me.identifier })
    return { ok = true, length = #code }
end)

Register('removePasscode', function(src, me, args)
    if not me.passcode or me.passcode == '' then return { ok = true } end
    if HashCode(me.identifier, tostring(args.code or '')) ~= me.passcode then return { ok = false, error = 'Code actuel incorrect' } end
    me.passcode = nil
    me.settings.faceid = false
    MySQL.update.await('UPDATE elyzea_phones SET passcode = NULL, settings = ? WHERE identifier = ?', { json.encode(me.settings), me.identifier })
    return { ok = true }
end)

Register('unlock', function(src, me, args)
    if not me.passcode or me.passcode == '' then return { ok = true } end
    local a = Attempts[me.identifier] or { count = 0, lockedUntil = 0 }
    if os.time() < a.lockedUntil then return { ok = false, wait = a.lockedUntil - os.time() } end
    if HashCode(me.identifier, tostring(args.code or '')) == me.passcode then
        Attempts[me.identifier] = nil
        return { ok = true }
    end
    a.count = a.count + 1
    if a.count >= Config.Security.MaxAttempts then
        a.count, a.lockedUntil = 0, os.time() + Config.Security.LockoutSeconds
    end
    Attempts[me.identifier] = a
    return { ok = false, wait = a.lockedUntil > os.time() and (a.lockedUntil - os.time()) or nil }
end)

-- Commande admin : /elyzea_resetcode [id] (permission : command.elyzea_resetcode)
RegisterCommand('elyzea_resetcode', function(source, args)
    local target = tonumber(args[1])
    local p = target and EnsurePlayer(target)
    if not p then
        if source == 0 then print('[elyzea_aura] Joueur introuvable') end
        return
    end
    p.passcode = nil
    p.settings.faceid = false
    MySQL.update.await('UPDATE elyzea_phones SET passcode = NULL, settings = ? WHERE identifier = ?', { json.encode(p.settings), p.identifier })
    Notify(target, { app = 'settings', key = 'codeReset' })
    if source == 0 then print(('[elyzea_aura] Code du joueur %s réinitialisé'):format(target)) end
end, true)

-- ---------------------------------------------------------
--  AuraDrop : partager sa fiche contact avec un joueur proche
-- ---------------------------------------------------------
local Drops, dropCounter = {}, 0

local function DisplayName(src, p)
    return (p.settings.cardName ~= nil and p.settings.cardName ~= '') and p.settings.cardName or GetCharName(src)
end
local function DeviceName(src, p)
    if p.settings.deviceName and p.settings.deviceName ~= '' then return p.settings.deviceName end
    return 'Aura ' .. (GetCharName(src):match('^(%S+)') or '')
end

Register('getNearby', function(src, me)
    if not Config.AuraDrop.Enabled then return { ok = false } end
    local myCoords = GetEntityCoords(GetPlayerPed(src))
    local out = {}
    for s, p in pairs(Players) do
        if s ~= src and GetPlayerPing(s) > 0 and not p.settings.airplane and p.settings.auraDrop ~= false then
            local dist = #(myCoords - GetEntityCoords(GetPlayerPed(s)))
            if dist <= Config.AuraDrop.Distance then
                out[#out + 1] = { id = s, device = DeviceName(s, p), distance = math.floor(dist * 10) / 10 }
            end
        end
    end
    table.sort(out, function(a, b) return a.distance < b.distance end)
    return { ok = true, devices = out }
end)

Register('auraDropSend', function(src, me, args)
    local target = tonumber(args.id)
    local tp = target and Players[target]
    if not tp then return { ok = false, error = 'Appareil hors de portée' } end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target))) > Config.AuraDrop.Distance + 2.0 then
        return { ok = false, error = 'Appareil hors de portée' }
    end
    dropCounter = dropCounter + 1
    local id = dropCounter
    Drops[id] = { from = src, to = target, name = DisplayName(src, me), number = me.number }
    TriggerClientEvent('elyzea_aura:client:auraDrop', target, { id = id, name = Drops[id].name, number = me.number, device = DeviceName(src, me) })
    SetTimeout(60000, function() Drops[id] = nil end)
    return { ok = true }
end)

Register('auraDropAnswer', function(src, me, args)
    local d = Drops[tonumber(args.id)]
    if not d or d.to ~= src then return { ok = false, error = 'Cette demande a expiré' } end
    Drops[tonumber(args.id)] = nil
    if args.accept then
        local exists = MySQL.scalar.await('SELECT 1 FROM elyzea_contacts WHERE owner = ? AND number = ?', { me.identifier, d.number })
        if not exists then
            MySQL.insert.await('INSERT INTO elyzea_contacts (owner, name, number) VALUES (?, ?, ?)', { me.identifier, trim(d.name, 50), d.number })
        end
    end
    if Players[d.from] then
        Notify(d.from, { app = 'auradrop', key = args.accept and 'dropAccepted' or 'dropDeclined', params = { device = DeviceName(src, me) } })
    end
    return { ok = true, contact = args.accept and { name = d.name, number = d.number } or nil }
end)

-- ---------------------------------------------------------
--  Envoi des photos et vidéos (mode 'server')
-- ---------------------------------------------------------
local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local B64L = {}
for i = 1, 64 do B64L[B64:byte(i)] = i - 1 end

local function Base64Decode(data)
    data = data:gsub('[^%w%+/=]', '')
    local out, n = {}, 0
    for i = 1, #data, 4 do
        local a, b, c, d = data:byte(i, i + 3)
        local vc = c and c ~= 61 and B64L[c] or nil
        local vd = d and d ~= 61 and B64L[d] or nil
        local v = ((B64L[a] or 0) << 18) | ((B64L[b] or 0) << 12) | ((vc or 0) << 6) | (vd or 0)
        n = n + 1
        if vd then out[n] = string.char((v >> 16) & 255, (v >> 8) & 255, v & 255)
        elseif vc then out[n] = string.char((v >> 16) & 255, (v >> 8) & 255)
        else out[n] = string.char((v >> 16) & 255) end
    end
    return table.concat(out)
end

local function JsonPath(tbl, path)
    local cur = tbl
    for key in tostring(path):gmatch('[^%.]+') do
        if type(cur) ~= 'table' then return nil end
        cur = cur[tonumber(key) or key]
    end
    return cur
end

local Uploading = {}

-- Au démarrage : prévient si la clé de l'hébergeur n'a pas été renseignée
CreateThread(function()
    Wait(2000)
    if not Config.Camera.Enabled then return end
    local key = Config.Camera.Headers and Config.Camera.Headers.Authorization
    local isDiscord = tostring(Config.Camera.ImageUrl):find('discord') ~= nil
    if not isDiscord and (not key or key == '' or key == 'TA_CLE_API_FIVEMANAGE') then
        print('^1[elyzea_aura] Appareil photo : aucune clé API configurée. Les photos et vidéos ne pourront pas être enregistrées.^0')
        print('^1[elyzea_aura] Mets ta clé Fivemanage dans Config.Camera.Headers.Authorization (config.lua).^0')
    end
end)
RegisterNetEvent('elyzea_aura:server:upload', function(reqId, kind, mime, data, duration)
    local src = source
    local me = EnsurePlayer(src)
    local function reply(res) TriggerClientEvent('elyzea_aura:client:uploadResult', src, reqId, res) end
    if not me or not Config.Camera.Enabled then return reply({ ok = false }) end
    if Uploading[src] then return reply({ ok = false, error = 'Un envoi est déjà en cours' }) end
    if type(data) ~= 'string' or #data > 20 * 1024 * 1024 then return reply({ ok = false, error = 'Fichier trop lourd' }) end

    local video = kind == 'video'
    mime = video and (tostring(mime):match('^video/webm') and 'video/webm' or 'video/mp4') or 'image/jpeg'
    Uploading[src] = true
    CreateThread(function()
        local bin = Base64Decode(data)
        local boundary = ('----ElyzeaAura%d'):format(math.random(100000, 999999))
        local field = video and Config.Camera.VideoField or Config.Camera.ImageField
        local filename = ('elyzea_%d.%s'):format(os.time(), video and 'webm' or 'jpg')
        local body = ('--%s\r\nContent-Disposition: form-data; name="%s"; filename="%s"\r\nContent-Type: %s\r\n\r\n'):format(boundary, field, filename, mime)
            .. bin .. ('\r\n--%s--\r\n'):format(boundary)
        local headers = { ['Content-Type'] = 'multipart/form-data; boundary=' .. boundary }
        for k, v in pairs(Config.Camera.Headers or {}) do headers[k] = v end

        PerformHttpRequest(video and Config.Camera.VideoUrl or Config.Camera.ImageUrl, function(code, resp, _, errorData)
            Uploading[src] = nil
            local ok, decoded = pcall(json.decode, resp or errorData or '')
            decoded = ok and type(decoded) == 'table' and decoded or nil
            -- Le lien peut se trouver à plusieurs endroits selon la version de l'API
            local url = decoded and (JsonPath(decoded, Config.Camera.ResponsePath) or decoded.url or (decoded.data and decoded.data.url))
            if not url or not tostring(url):match('^https://') then
                print(('^1[elyzea_aura] Échec de l\'envoi (code %s) : %s^0'):format(code, tostring(resp or errorData):sub(1, 300)))
                if code == 401 or code == 403 then
                    print('^1[elyzea_aura] Clé API refusée : vérifie Config.Camera.Headers.Authorization dans config.lua (clé Fivemanage valide, sans espace).^0')
                    return reply({ ok = false, error = 'Clé API de l\'hébergeur manquante ou invalide' })
                elseif code == 413 then
                    return reply({ ok = false, error = 'Fichier trop lourd' })
                end
                return reply({ ok = false, error = 'L\'hébergeur a refusé le fichier' })
            end
            CreateThread(function()
                local id = MySQL.insert.await('INSERT INTO elyzea_gallery (owner, url, type, duration) VALUES (?, ?, ?, ?)',
                    { me.identifier, url, video and 'video' or 'photo', math.floor(tonumber(duration) or 0) })
                reply({ ok = true, id = id, url = url, type = video and 'video' or 'photo' })
            end)
        end, 'POST', body, headers)
    end)
end)

-- ---------------------------------------------------------
--  Étincelle (rencontres)
-- ---------------------------------------------------------
local GENDERS = { man = true, woman = true, other = true }
local INTERESTS = { men = true, women = true, all = true }

local function DatingRow(identifier)
    return MySQL.single.await('SELECT * FROM elyzea_dating_profiles WHERE identifier = ?', { identifier })
end
local function PublicProfile(r)
    if not r then return nil end
    return { id = r.id, name = r.name, age = r.age, gender = r.gender, bio = r.bio,
        photos = json.decode(r.photos or '[]') or {}, tags = json.decode(r.tags or '[]') or {} }
end
local function Wants(interest, gender)
    return interest == 'all' or (interest == 'men' and gender == 'man') or (interest == 'women' and gender == 'woman')
end
local function SourceByIdentifier(identifier)
    for s, p in pairs(Players) do if p.identifier == identifier then return s end end
end
local function MatchMember(matchId, myId)
    local m = MySQL.single.await('SELECT * FROM elyzea_dating_matches WHERE id = ?', { matchId })
    if not m or (m.a ~= myId and m.b ~= myId) then return nil end
    return m, (m.a == myId and m.b or m.a)
end

Register('datingGetProfile', function(src, me)
    local r = DatingRow(me.identifier)
    local p = PublicProfile(r)
    if p then p.interest = r.interest; p.active = r.active == 1 end
    return { ok = true, profile = p }
end)

Register('datingSaveProfile', function(src, me, args)
    if not HasApp(me, 'etincelle') then return { ok = false, error = 'Application non installée' } end
    local name, bio = trim(args.name, 30), trim(args.bio, 300)
    local age = math.floor(tonumber(args.age) or 0)
    if #name < 2 then return { ok = false, error = 'Indiquez votre prénom' } end
    if age < Config.Dating.MinAge or age > 99 then return { ok = false, error = 'Âge invalide' } end
    if not GENDERS[args.gender] or not INTERESTS[args.interest] then return { ok = false, error = 'Complétez votre profil' } end
    local photos, tags = {}, {}
    for _, url in ipairs(type(args.photos) == 'table' and args.photos or {}) do
        if type(url) == 'string' and url:match('^https://') and #url <= 500 and #photos < Config.Dating.MaxPhotos then photos[#photos + 1] = url end
    end
    if #photos == 0 then return { ok = false, error = 'Ajoutez au moins une photo' } end
    for _, tg in ipairs(type(args.tags) == 'table' and args.tags or {}) do
        if type(tg) == 'string' and #tags < 6 then tags[#tags + 1] = trim(tg, 20) end
    end
    if DatingRow(me.identifier) then
        MySQL.update.await('UPDATE elyzea_dating_profiles SET name = ?, age = ?, gender = ?, interest = ?, bio = ?, photos = ?, tags = ? WHERE identifier = ?',
            { name, age, args.gender, args.interest, bio, json.encode(photos), json.encode(tags), me.identifier })
    else
        MySQL.insert.await('INSERT INTO elyzea_dating_profiles (identifier, name, age, gender, interest, bio, photos, tags) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            { me.identifier, name, age, args.gender, args.interest, bio, json.encode(photos), json.encode(tags) })
    end
    return { ok = true }
end)

Register('datingToggle', function(src, me, args)
    MySQL.update.await('UPDATE elyzea_dating_profiles SET active = ? WHERE identifier = ?', { args.active and 1 or 0, me.identifier })
    return { ok = true }
end)

Register('datingDiscover', function(src, me)
    local mine = DatingRow(me.identifier)
    if not mine then return { ok = false, error = 'Créez votre profil' } end
    local rows = MySQL.query.await([[
        SELECT p.*, (SELECT COUNT(*) FROM elyzea_dating_swipes s WHERE s.swiper = p.id AND s.target = ? AND s.super = 1) AS super_me
        FROM elyzea_dating_profiles p
        WHERE p.id <> ? AND p.active = 1 AND p.id NOT IN (SELECT target FROM elyzea_dating_swipes WHERE swiper = ?)
        ORDER BY RAND() LIMIT 60
    ]], { mine.id, mine.id, mine.id }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        if Wants(mine.interest, r.gender) and Wants(r.interest, mine.gender) and #out < 15 then
            local p = PublicProfile(r); p.superMe = (r.super_me or 0) > 0
            out[#out + 1] = p
        end
    end
    return { ok = true, profiles = out }
end)

Register('datingSwipe', function(src, me, args)
    local mine = DatingRow(me.identifier)
    local target = MySQL.single.await('SELECT * FROM elyzea_dating_profiles WHERE id = ?', { tonumber(args.id) })
    if not mine or not target or target.id == mine.id then return { ok = false } end
    local like, super = args.like and 1 or 0, (args.like and args.super) and 1 or 0
    MySQL.insert.await('INSERT INTO elyzea_dating_swipes (swiper, target, liked, super) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE liked = VALUES(liked), super = VALUES(super)',
        { mine.id, target.id, like, super })
    if like == 0 then return { ok = true } end

    local tsrc = SourceByIdentifier(target.identifier)
    local reciprocal = MySQL.scalar.await('SELECT 1 FROM elyzea_dating_swipes WHERE swiper = ? AND target = ? AND liked = 1', { target.id, mine.id })
    if reciprocal then
        local a, b = math.min(mine.id, target.id), math.max(mine.id, target.id)
        MySQL.insert.await('INSERT IGNORE INTO elyzea_dating_matches (a, b) VALUES (?, ?)', { a, b })
        local matchId = MySQL.scalar.await('SELECT id FROM elyzea_dating_matches WHERE a = ? AND b = ?', { a, b })
        if tsrc then Notify(tsrc, { app = 'etincelle', key = 'datingMatch', params = { name = mine.name } }) end
        return { ok = true, match = { id = matchId, profile = PublicProfile(target) } }
    end
    if super == 1 and tsrc then Notify(tsrc, { app = 'etincelle', key = 'datingSuper' }) end
    return { ok = true }
end)

Register('datingMatches', function(src, me)
    local mine = DatingRow(me.identifier)
    if not mine then return { ok = true, matches = {} } end
    local rows = MySQL.query.await([[
        SELECT m.id AS match_id, UNIX_TIMESTAMP(m.created_at) AS ts, p.id, p.name, p.age, p.photos,
          (SELECT d.message FROM elyzea_dating_messages d WHERE d.match_id = m.id ORDER BY d.id DESC LIMIT 1) AS last,
          (SELECT UNIX_TIMESTAMP(d.created_at) FROM elyzea_dating_messages d WHERE d.match_id = m.id ORDER BY d.id DESC LIMIT 1) AS last_ts
        FROM elyzea_dating_matches m
        JOIN elyzea_dating_profiles p ON p.id = IF(m.a = ?, m.b, m.a)
        WHERE m.a = ? OR m.b = ?
        ORDER BY COALESCE(last_ts, ts) DESC
    ]], { mine.id, mine.id, mine.id }) or {}
    for _, r in ipairs(rows) do
        local photos = json.decode(r.photos or '[]') or {}
        r.photo = photos[1]; r.photos = nil
    end
    return { ok = true, matches = rows }
end)

Register('datingMessages', function(src, me, args)
    local mine = DatingRow(me.identifier)
    if not mine then return { ok = false } end
    local m, otherId = MatchMember(tonumber(args.matchId), mine.id)
    if not m then return { ok = false } end
    local rows = MySQL.query.await('SELECT id, sender, message, UNIX_TIMESTAMP(created_at) AS ts FROM elyzea_dating_messages WHERE match_id = ? ORDER BY id ASC LIMIT 200', { m.id }) or {}
    for _, r in ipairs(rows) do r.mine = r.sender == mine.id; r.sender = nil end
    local other = MySQL.single.await('SELECT * FROM elyzea_dating_profiles WHERE id = ?', { otherId })
    return { ok = true, messages = rows, profile = PublicProfile(other) }
end)

Register('datingSend', function(src, me, args)
    local mine = DatingRow(me.identifier)
    if not mine then return { ok = false } end
    local m, otherId = MatchMember(tonumber(args.matchId), mine.id)
    local msg = trim(args.message, 500)
    if not m or msg == '' then return { ok = false } end
    local id = MySQL.insert.await('INSERT INTO elyzea_dating_messages (match_id, sender, message) VALUES (?, ?, ?)', { m.id, mine.id, msg })
    local other = MySQL.single.await('SELECT identifier FROM elyzea_dating_profiles WHERE id = ?', { otherId })
    local tsrc = other and SourceByIdentifier(other.identifier)
    if tsrc then
        Notify(tsrc, { app = 'etincelle', key = 'datingMessage', params = { name = mine.name }, text = msg })
        TriggerClientEvent('elyzea_aura:client:datingMessage', tsrc, { matchId = m.id, message = msg, ts = os.time() })
    end
    return { ok = true, message = { id = id, mine = true, message = msg, ts = os.time() } }
end)

Register('datingUnmatch', function(src, me, args)
    local mine = DatingRow(me.identifier)
    if not mine then return { ok = false } end
    local m = MatchMember(tonumber(args.matchId), mine.id)
    if not m then return { ok = false } end
    MySQL.update.await('DELETE FROM elyzea_dating_messages WHERE match_id = ?', { m.id })
    MySQL.update.await('DELETE FROM elyzea_dating_matches WHERE id = ?', { m.id })
    return { ok = true }
end)

-- ---------------------------------------------------------
--  Livrézy (livraison de courses par un PNJ)
-- ---------------------------------------------------------
local Catalog, Orders = {}, {} -- Catalog[item] = { label, price, category } ; Orders[src] = commande active
for _, cat in ipairs(Config.Delivery.Categories) do
    for _, it in ipairs(cat.items) do Catalog[it.name] = { label = it.label, price = it.price, category = cat.id } end
end

local function HasOx() return GetResourceState('elyzea_inventory') == 'started' end

-- L'item existe-t-il dans l'inventaire du serveur ?
local function ItemExists(item)
    if HasOx() then
        local ok, data = pcall(function() return exports.elyzea_inventory:Items(item) end)
        if ok then return data ~= nil end
    end
    if QBCore and QBCore.Shared and QBCore.Shared.Items and next(QBCore.Shared.Items) then return QBCore.Shared.Items[item] ~= nil end
    return true
end

-- Vérifie le poids TOTAL de la commande (et non article par article)
local function CanCarryAll(src, items)
    if not HasOx() then return true end
    local weight = 0
    for _, it in ipairs(items) do
        local data = Ox('Items', it.name)
        weight = weight + ((data and data.weight) or 0) * it.qty
    end
    local res = Ox('CanCarryWeight', src, weight)
    if res == nil then return true end -- fonction absente : on ne bloque pas la commande
    return res and true or false
end

-- Au démarrage : signale dans la console les articles du catalogue absents de l'inventaire
CreateThread(function()
    Wait(3000)
    local missing = {}
    for name in pairs(Catalog) do if not ItemExists(name) then missing[#missing + 1] = name end end
    if #missing > 0 then
        print(('^3[elyzea_aura] Livrézy : ces articles n\'existent pas dans ton inventaire et sont masqués : %s^0'):format(table.concat(missing, ', ')))
        print('^3[elyzea_aura] Corrige leur "name" dans Config.Delivery.Categories (voir elyzea_inventory/shared/items.lua et data/items.lua).^0')
    end
end)

local function GiveItem(src, item, count)
    if HasOx() then
        local ok, res = pcall(function() return exports.elyzea_inventory:AddItem(src, item, count) end)
        if ok then return res and true or false end
    end
    if QBCore then
        local p = QBCore.Functions.GetPlayer(src)
        if p and p.Functions.AddItem(item, count) then
            if QBCore.Shared and QBCore.Shared.Items and QBCore.Shared.Items[item] then
                TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add', count)
            end
            return true
        end
        return false
    elseif ESX then
        local x = ESX.GetPlayerFromId(src)
        if x then x.addInventoryItem(item, count) return true end
    end
    return false
end

local function TakeMoney(src, method, amount)
    if method == 'cash' then
        if ESX then
            local x = ESX.GetPlayerFromId(src)
            if x and x.getMoney() >= amount then x.removeMoney(amount) return true end
            return false
        elseif QBCore then
            local p = QBCore.Functions.GetPlayer(src)
            return p and p.Functions.RemoveMoney('cash', amount, 'elyzea-delivery') or false
        end
        return false
    end
    return RemoveBank(src, amount, 'elyzea-delivery')
end

local function Refund(src, identifier, method, amount, reason)
    if amount <= 0 then return end
    if src and GetPlayerPing(src) > 0 then
        if method == 'cash' then
            if ESX then local x = ESX.GetPlayerFromId(src); if x then x.addMoney(amount) end
            elseif QBCore then local p = QBCore.Functions.GetPlayer(src); if p then p.Functions.AddMoney('cash', amount, reason) end end
        else
            AddBank(src, amount, reason)
            TriggerClientEvent('elyzea_aura:client:bankUpdate', src, GetBank(src))
        end
    else
        AddBankOffline(identifier, amount) -- joueur parti : remboursé sur son compte
    end
end

local function NearestShop(src)
    local pos = GetEntityCoords(GetPlayerPed(src))
    local best, bestDist
    for _, shop in ipairs(Config.Delivery.Shops) do
        local d = #(pos - shop.coords)
        if not bestDist or d < bestDist then best, bestDist = shop, d end
    end
    return best
end

local function CloseOrder(src, status)
    local o = Orders[src]
    if not o then return end
    Orders[src] = nil
    MySQL.update('UPDATE elyzea_delivery_orders SET status = ? WHERE id = ?', { status, o.id })
end

Register('deliveryCatalog', function(src, me)
    local o = Orders[src]
    local cats = {}
    for _, cat in ipairs(Config.Delivery.Categories) do
        local list = {}
        for _, it in ipairs(cat.items) do if ItemExists(it.name) then list[#list + 1] = it end end
        if #list > 0 then cats[#cats + 1] = { id = cat.id, label = cat.label, items = list } end
    end
    return {
        ok = Config.Delivery.Enabled, fee = Config.Delivery.Fee, pay = Config.Delivery.PayWith,
        categories = cats, imagePath = Config.Delivery.ImagePath,
        maxItems = Config.Delivery.MaxItems, maxPerItem = Config.Delivery.MaxPerItem,
        cash = Framework ~= 'standalone',
        active = o and { id = o.id, items = o.items, total = o.total, shop = o.shop.label, status = o.status, readyIn = math.max(0, o.readyAt - os.time()) } or nil,
    }
end)

Register('deliveryOrder', function(src, me, args)
    if not Config.Delivery.Enabled or Framework == 'standalone' then return { ok = false } end
    if not HasApp(me, 'livrezy') then return { ok = false, error = 'Application non installée' } end
    if Orders[src] then return { ok = false, error = 'Une livraison est déjà en cours' } end
    local method = args.pay == 'cash' and 'cash' or 'bank'

    -- Le serveur recalcule tout : le prix envoyé par le téléphone n'est jamais utilisé
    local items, count, subtotal = {}, 0, 0
    for _, line in ipairs(type(args.cart) == 'table' and args.cart or {}) do
        local it = type(line) == 'table' and Catalog[line.name]
        local qty = math.floor(tonumber(line.qty) or 0)
        if it and qty >= 1 and qty <= Config.Delivery.MaxPerItem and ItemExists(line.name) then
            items[#items + 1] = { name = line.name, label = it.label, qty = qty, price = it.price }
            count = count + qty
            subtotal = subtotal + it.price * qty
        end
    end
    if #items == 0 then return { ok = false, error = 'Votre panier est vide' } end
    if count > Config.Delivery.MaxItems then return { ok = false, error = 'Trop d\'articles dans le panier' } end
    if not CanCarryAll(src, items) then
        return { ok = false, error = 'Votre inventaire est trop plein pour cette commande' }
    end

    local total = subtotal + Config.Delivery.Fee
    if not TakeMoney(src, method, total) then
        return { ok = false, error = method == 'cash' and 'Pas assez d\'espèces sur vous' or 'Solde insuffisant' }
    end
    if method == 'bank' then
        BankLog(me.identifier, 'Livrézy', -total)
        TriggerClientEvent('elyzea_aura:client:bankUpdate', src, GetBank(src))
    end

    local shop = NearestShop(src)
    local prep = math.random(Config.Delivery.PrepTime[1], Config.Delivery.PrepTime[2])
    local id = MySQL.insert.await('INSERT INTO elyzea_delivery_orders (owner, items, total, pay, shop) VALUES (?, ?, ?, ?, ?)',
        { me.identifier, json.encode(items), total, method, shop.label })
    local order = { id = id, identifier = me.identifier, items = items, total = total, pay = method, shop = shop, status = 'preparing', readyAt = os.time() + prep }
    Orders[src] = order

    -- Fin de la préparation : le livreur prend la route
    SetTimeout(prep * 1000, function()
        local o = Orders[src]
        if not o or o.id ~= id then return end
        o.status, o.dispatchedAt = 'enroute', os.time()
        MySQL.update('UPDATE elyzea_delivery_orders SET status = ? WHERE id = ?', { 'enroute', id })
        TriggerClientEvent('elyzea_aura:client:deliveryDispatch', src, {
            id = id, shop = { label = shop.label, x = shop.coords.x, y = shop.coords.y, z = shop.coords.z },
            vehicle = Config.Delivery.Vehicles[math.random(#Config.Delivery.Vehicles)],
            ped = Config.Delivery.Peds[math.random(#Config.Delivery.Peds)],
        })
        -- Sécurité : remboursement si la livraison n'aboutit jamais
        SetTimeout(Config.Delivery.Timeout * 1000, function()
            local o2 = Orders[src]
            if o2 and o2.id == id then
                Refund(src, o2.identifier, o2.pay, o2.total, 'elyzea-delivery-refund')
                CloseOrder(src, 'refunded')
                TriggerClientEvent('elyzea_aura:client:deliveryAbort', src, { id = id, reason = 'timeout' })
            end
        end)
    end)
    return { ok = true, order = { id = id, items = items, total = total, shop = shop.label, status = 'preparing', readyIn = prep } }
end)

Register('deliveryCancel', function(src, me)
    local o = Orders[src]
    if not o then return { ok = false } end
    -- Avant le départ : remboursement total ; en route : les frais de livraison sont retenus
    local refund = o.status == 'preparing' and o.total or (o.total - Config.Delivery.Fee)
    Refund(src, o.identifier, o.pay, refund, 'elyzea-delivery-cancel')
    local id = o.id
    CloseOrder(src, 'cancelled')
    TriggerClientEvent('elyzea_aura:client:deliveryAbort', src, { id = id, reason = 'cancelled' })
    return { ok = true, refund = refund }
end)

RegisterNetEvent('elyzea_aura:server:deliveryComplete', function(id)
    local src = source
    local o = Orders[src]
    if not o or o.id ~= id or o.status ~= 'enroute' or os.time() - (o.dispatchedAt or os.time()) < 8 then return end
    local failed = 0
    for _, it in ipairs(o.items) do
        if not GiveItem(src, it.name, it.qty) then failed = failed + it.price * it.qty end
    end
    if failed > 0 then Refund(src, o.identifier, o.pay, failed, 'elyzea-delivery-partial') end
    CloseOrder(src, 'delivered')
    Notify(src, { app = 'livrezy', key = failed > 0 and 'deliveryPartial' or 'deliveryDone', params = { amount = failed } })
end)

RegisterNetEvent('elyzea_aura:server:deliveryFailed', function(id)
    local src = source
    local o = Orders[src]
    if not o or o.id ~= id then return end
    Refund(src, o.identifier, o.pay, o.total, 'elyzea-delivery-refund')
    CloseOrder(src, 'refunded')
    Notify(src, { app = 'livrezy', key = 'deliveryFailed' })
end)

Register('deliveryHistory', function(src, me)
    local rows = MySQL.query.await('SELECT id, items, total, shop, status, UNIX_TIMESTAMP(created_at) AS ts FROM elyzea_delivery_orders WHERE owner = ? ORDER BY id DESC LIMIT 20', { me.identifier }) or {}
    for _, r in ipairs(rows) do r.items = json.decode(r.items or '[]') or {} end
    return { ok = true, orders = rows }
end)

AddEventHandler('playerDropped', function()
    local src = source
    local o = Orders[src]
    if o then
        Refund(nil, o.identifier, o.pay, o.total, 'elyzea-delivery-refund')
        Orders[src] = nil
        MySQL.update('UPDATE elyzea_delivery_orders SET status = ? WHERE id = ?', { 'refunded', o.id })
    end
end)

-- ---------------------------------------------------------
--  HelpMécano (dépannage par un mécanicien PNJ)
-- ---------------------------------------------------------
local MechServices, Jobs = {}, {} -- Jobs[src] = intervention en cours
for _, sv in ipairs(Config.Mechanic.Services) do MechServices[sv.id] = sv end

local function MechanicsOnline()
    local n = 0
    for _, id in ipairs(GetPlayers()) do
        if GetJob(tonumber(id)) == Config.Mechanic.MechanicJob then n = n + 1 end
    end
    return n
end

local function NearestGarage(src)
    local pos = GetEntityCoords(GetPlayerPed(src))
    local best, bestDist
    for _, g in ipairs(Config.Mechanic.Garages) do
        local d = #(pos - g.coords)
        if not bestDist or d < bestDist then best, bestDist = g, d end
    end
    return best
end

local function CloseJob(src, status)
    local j = Jobs[src]
    if not j then return end
    Jobs[src] = nil
    MySQL.update('UPDATE elyzea_mechanic_jobs SET status = ? WHERE id = ?', { status, j.id })
end

Register('mechanicInfo', function(src, me)
    local j = Jobs[src]
    return {
        ok = Config.Mechanic.Enabled and Framework ~= 'standalone',
        services = Config.Mechanic.Services, pay = Config.Mechanic.PayWith, cash = Framework ~= 'standalone',
        blocked = Config.Mechanic.BlockIfMechanicsOnline and MechanicsOnline() > 0,
        active = j and { id = j.id, service = j.service.id, label = j.service.label, price = j.price, garage = j.garage.label,
            vehicle = j.vehicle, plate = j.plate, status = j.status, readyIn = math.max(0, j.readyAt - os.time()) } or nil,
    }
end)

Register('mechanicOrder', function(src, me, args)
    if not Config.Mechanic.Enabled or Framework == 'standalone' then return { ok = false } end
    if not HasApp(me, 'helpmecano') then return { ok = false, error = 'Application non installée' } end
    if Jobs[src] then return { ok = false, error = 'Une intervention est déjà en cours' } end
    if Config.Mechanic.BlockIfMechanicsOnline and MechanicsOnline() > 0 then
        return { ok = false, error = 'Des mécaniciens sont en service : contactez-les via l\'app Urgences' }
    end
    local service = MechServices[args.service]
    if not service then return { ok = false, error = 'Choisissez un service' } end
    local netId = tonumber(args.netId)
    if not netId then return { ok = false, error = 'Aucun véhicule à proximité' } end

    local method = args.pay == 'cash' and 'cash' or 'bank'
    if not TakeMoney(src, method, service.price) then
        return { ok = false, error = method == 'cash' and 'Pas assez d\'espèces sur vous' or 'Solde insuffisant' }
    end
    if method == 'bank' then
        BankLog(me.identifier, 'HelpMécano', -service.price)
        TriggerClientEvent('elyzea_aura:client:bankUpdate', src, GetBank(src))
    end

    local garage = NearestGarage(src)
    local delay = math.random(Config.Mechanic.DispatchDelay[1], Config.Mechanic.DispatchDelay[2])
    local vehicle, plate = trim(args.vehicle, 60), trim(args.plate, 12)
    local id = MySQL.insert.await('INSERT INTO elyzea_mechanic_jobs (owner, service, price, pay, vehicle, plate, garage) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { me.identifier, service.id, service.price, method, vehicle, plate, garage.label })
    local job = { id = id, identifier = me.identifier, service = service, price = service.price, pay = method, garage = garage,
        vehicle = vehicle, plate = plate, netId = netId, status = 'pending', readyAt = os.time() + delay }
    Jobs[src] = job

    SetTimeout(delay * 1000, function()
        local j = Jobs[src]
        if not j or j.id ~= id then return end
        j.status, j.dispatchedAt = 'enroute', os.time()
        MySQL.update('UPDATE elyzea_mechanic_jobs SET status = ? WHERE id = ?', { 'enroute', id })
        TriggerClientEvent('elyzea_aura:client:mechanicDispatch', src, {
            id = id, netId = netId, service = service.id, duration = service.duration, label = service.label,
            garage = { label = garage.label, x = garage.coords.x, y = garage.coords.y, z = garage.coords.z },
            truck = Config.Mechanic.Truck, ped = Config.Mechanic.Peds[math.random(#Config.Mechanic.Peds)],
        })
        SetTimeout(Config.Mechanic.Timeout * 1000, function()
            local j2 = Jobs[src]
            if j2 and j2.id == id then
                Refund(src, j2.identifier, j2.pay, j2.price, 'elyzea-mechanic-refund')
                CloseJob(src, 'refunded')
                TriggerClientEvent('elyzea_aura:client:mechanicAbort', src, { id = id, reason = 'timeout' })
            end
        end)
    end)
    return { ok = true, job = { id = id, service = service.id, label = service.label, price = service.price, garage = garage.label,
        vehicle = vehicle, plate = plate, status = 'pending', readyIn = delay } }
end)

Register('mechanicCancel', function(src, me)
    local j = Jobs[src]
    if not j then return { ok = false } end
    if j.status == 'working' then return { ok = false, error = 'L\'intervention a déjà commencé' } end
    -- avant le départ : remboursement total ; en route : 20 % retenus pour le déplacement
    local refund = j.status == 'pending' and j.price or math.floor(j.price * 0.8)
    Refund(src, j.identifier, j.pay, refund, 'elyzea-mechanic-cancel')
    local id = j.id
    CloseJob(src, 'cancelled')
    TriggerClientEvent('elyzea_aura:client:mechanicAbort', src, { id = id, reason = 'cancelled' })
    return { ok = true, refund = refund }
end)

RegisterNetEvent('elyzea_aura:server:mechanicStatus', function(id, status)
    local j = Jobs[source]
    if j and j.id == id and (status == 'working') then j.status = 'working' end
end)

RegisterNetEvent('elyzea_aura:server:mechanicComplete', function(id)
    local src = source
    local j = Jobs[src]
    if not j or j.id ~= id or os.time() - (j.dispatchedAt or os.time()) < 5 then return end
    CloseJob(src, 'done')
    Notify(src, { app = 'helpmecano', key = 'mechDone', params = { service = j.service.label } })
end)

RegisterNetEvent('elyzea_aura:server:mechanicFailed', function(id, reason)
    local src = source
    local j = Jobs[src]
    if not j or j.id ~= id then return end
    Refund(src, j.identifier, j.pay, j.price, 'elyzea-mechanic-refund')
    CloseJob(src, 'refunded')
    Notify(src, { app = 'helpmecano', key = reason == 'novehicle' and 'mechNoVehicle' or 'mechFailed' })
end)

Register('mechanicHistory', function(src, me)
    local rows = MySQL.query.await('SELECT id, service, price, vehicle, plate, garage, status, UNIX_TIMESTAMP(created_at) AS ts FROM elyzea_mechanic_jobs WHERE owner = ? ORDER BY id DESC LIMIT 20', { me.identifier }) or {}
    for _, r in ipairs(rows) do r.label = MechServices[r.service] and MechServices[r.service].label or r.service end
    return { ok = true, jobs = rows }
end)

AddEventHandler('playerDropped', function()
    local src = source
    local j = Jobs[src]
    if j then
        if j.status ~= 'working' then Refund(nil, j.identifier, j.pay, j.price, 'elyzea-mechanic-refund') end
        Jobs[src] = nil
        MySQL.update('UPDATE elyzea_mechanic_jobs SET status = ? WHERE id = ?', { 'refunded', j.id })
    end
end)

-- ---------------------------------------------------------
--  Véhicules du joueur (Elyzea/QBCore : player_vehicles ; ESX : owned_vehicles)
-- ---------------------------------------------------------
local function CleanPlate(p) return (tostring(p or ''):gsub('^%s+', ''):gsub('%s+$', '')):upper() end

-- Liste brute des véhicules possédés : { plate, model, state ('garage'|'out'|'impound'), garage, props, fuel, engine, body }
local function OwnedVehicles(me)
    local out = {}
    if QBCore then
        local ok, rows = pcall(MySQL.query.await, 'SELECT * FROM player_vehicles WHERE citizenid = ?', { me.identifier })
        for _, r in ipairs(ok and rows or {}) do
            local st = tonumber(r.state) or 0
            out[#out + 1] = { plate = CleanPlate(r.plate), model = r.vehicle or r.hash, state = st == 1 and 'garage' or st == 2 and 'impound' or 'out',
                garage = r.garage or '', props = r.mods, fuel = tonumber(r.fuel) or 100, engine = tonumber(r.engine) or 1000, body = tonumber(r.body) or 1000 }
        end
    elseif ESX then
        local ok, rows = pcall(MySQL.query.await, 'SELECT * FROM owned_vehicles WHERE owner = ?', { me.identifier })
        for _, r in ipairs(ok and rows or {}) do
            local props = json.decode(r.vehicle or '{}') or {}
            local stored = tonumber(r.stored) or 0
            out[#out + 1] = { plate = CleanPlate(r.plate), model = props.model, state = (r.pound == 1 or r.impounded == 1) and 'impound' or (stored == 1 and 'garage' or 'out'),
                garage = r.parking or r.garage or '', props = r.vehicle, fuel = tonumber(props.fuelLevel) or 100,
                engine = tonumber(props.engineHealth) or 1000, body = tonumber(props.bodyHealth) or 1000 }
        end
    end
    return out
end

-- Véhicules réellement présents dans le monde, indexés par plaque (OneSync)
local function WorldVehicles()
    local map = {}
    for _, veh in ipairs(GetAllVehicles()) do
        local plate = CleanPlate(GetVehicleNumberPlateText(veh))
        if plate ~= '' then map[plate] = veh end
    end
    return map
end

local function VehicleState(veh)
    local rot = GetEntityRotation(veh)
    return {
        netId = NetworkGetNetworkIdFromEntity(veh),
        engine = math.floor(math.max(0, GetVehicleEngineHealth(veh)) / 10),
        body = math.floor(math.max(0, GetVehicleBodyHealth(veh)) / 10),
        clean = math.floor(100 - (GetVehicleDirtLevel(veh) or 0) / 15.0 * 100),
        upside = math.abs(rot.y) > 75.0,
    }
end

-- HelpMécano : mes véhicules sortis, avec leur état et leur distance
Register('myVehiclesOut', function(src, me)
    local myPos = GetEntityCoords(GetPlayerPed(src))
    local world, list = WorldVehicles(), {}
    for _, v in ipairs(OwnedVehicles(me)) do
        local veh = world[v.plate]
        if veh and DoesEntityExist(veh) then
            local info = VehicleState(veh)
            local pos = GetEntityCoords(veh)
            info.plate, info.model = v.plate, v.model
            info.distance = math.floor(#(myPos - pos))
            info.x, info.y = pos.x, pos.y
            list[#list + 1] = info
        end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    return { ok = true, vehicles = list, maxDistance = Config.Mechanic.MaxVehicleDistance }
end)

-- ---------------------------------------------------------
--  Garage : livraison d'un véhicule par un voiturier PNJ
-- ---------------------------------------------------------
local Valets = {} -- Valets[src] = livraison en cours

local function SetGarageState(me, plate, state)
    if QBCore then
        return MySQL.update.await('UPDATE player_vehicles SET state = ? WHERE citizenid = ? AND plate = ?', { state == 'garage' and 1 or 0, me.identifier, plate })
    elseif ESX then
        return MySQL.update.await('UPDATE owned_vehicles SET stored = ? WHERE owner = ? AND plate = ?', { state == 'garage' and 1 or 0, me.identifier, plate })
    end
    return 0
end

local function CloseValet(src, status)
    local v = Valets[src]
    if not v then return end
    Valets[src] = nil
    MySQL.update('UPDATE elyzea_garage_orders SET status = ? WHERE id = ?', { status, v.id })
end

Register('garageList', function(src, me)
    if not Config.Garage.Enabled or Framework == 'standalone' then return { ok = false } end
    local world, list = WorldVehicles(), {}
    local myPos = GetEntityCoords(GetPlayerPed(src))
    for _, v in ipairs(OwnedVehicles(me)) do
        local veh = world[v.plate]
        local item = { plate = v.plate, model = v.model, state = v.state, garage = Config.Garage.Labels[v.garage] or v.garage,
            fuel = math.floor(v.fuel), engine = math.floor(v.engine / 10), body = math.floor(v.body / 10) }
        if veh and DoesEntityExist(veh) then
            local pos = GetEntityCoords(veh)
            item.state = 'out'
            item.inWorld, item.x, item.y = true, pos.x, pos.y
            item.distance = math.floor(#(myPos - pos))
        end
        list[#list + 1] = item
    end
    local order = { garage = 1, out = 2, impound = 3 }
    table.sort(list, function(a, b) return (order[a.state] or 9) < (order[b.state] or 9) end)
    local a = Valets[src]
    return { ok = true, vehicles = list, price = Config.Garage.Price, pay = Config.Garage.PayWith, cash = Framework ~= 'standalone',
        active = a and { id = a.id, plate = a.plate, model = a.model, status = a.status, price = a.price, readyIn = math.max(0, a.readyAt - os.time()) } or nil }
end)

Register('garageOrder', function(src, me, args)
    if not Config.Garage.Enabled or Framework == 'standalone' then return { ok = false } end
    if not HasApp(me, 'garage') then return { ok = false, error = 'Application non installée' } end
    if Valets[src] then return { ok = false, error = 'Une livraison de véhicule est déjà en cours' } end
    local plate = CleanPlate(args.plate)
    local found
    for _, v in ipairs(OwnedVehicles(me)) do if v.plate == plate then found = v end end
    if not found then return { ok = false, error = 'Véhicule introuvable' } end
    if found.state ~= 'garage' then return { ok = false, error = 'Ce véhicule n\'est pas au garage' } end
    if WorldVehicles()[plate] then return { ok = false, error = 'Ce véhicule est déjà sorti' } end

    local method = args.pay == 'cash' and 'cash' or 'bank'
    if not TakeMoney(src, method, Config.Garage.Price) then
        return { ok = false, error = method == 'cash' and 'Pas assez d\'espèces sur vous' or 'Solde insuffisant' }
    end
    if method == 'bank' then
        BankLog(me.identifier, 'Garage', -Config.Garage.Price)
        TriggerClientEvent('elyzea_aura:client:bankUpdate', src, GetBank(src))
    end
    -- le véhicule est marqué « sorti » tout de suite pour qu'il ne puisse pas être sorti deux fois
    SetGarageState(me, plate, 'out')

    local delay = math.random(Config.Garage.DispatchDelay[1], Config.Garage.DispatchDelay[2])
    local label = trim(args.label, 60)
    local id = MySQL.insert.await('INSERT INTO elyzea_garage_orders (owner, plate, vehicle, price, pay) VALUES (?, ?, ?, ?, ?)',
        { me.identifier, plate, label, Config.Garage.Price, method })
    local valet = { id = id, identifier = me.identifier, me = me, plate = plate, model = found.model, label = label, price = Config.Garage.Price,
        pay = method, status = 'pending', readyAt = os.time() + delay }
    Valets[src] = valet

    SetTimeout(delay * 1000, function()
        local v = Valets[src]
        if not v or v.id ~= id then return end
        v.status, v.dispatchedAt = 'enroute', os.time()
        TriggerClientEvent('elyzea_aura:client:garageDispatch', src, {
            id = id, plate = plate, model = found.model, props = found.props, fuel = found.fuel, engine = found.engine, body = found.body,
            ped = Config.Garage.Peds[math.random(#Config.Garage.Peds)],
        })
        SetTimeout(Config.Garage.Timeout * 1000, function()
            local v2 = Valets[src]
            if v2 and v2.id == id then
                Refund(src, v2.identifier, v2.pay, v2.price, 'elyzea-garage-refund')
                SetGarageState(v2.me, plate, 'garage')
                CloseValet(src, 'refunded')
                TriggerClientEvent('elyzea_aura:client:garageAbort', src, { id = id, reason = 'timeout' })
            end
        end)
    end)
    return { ok = true, order = { id = id, plate = plate, model = found.model, label = label, price = Config.Garage.Price, status = 'pending', readyIn = delay } }
end)

Register('garageCancel', function(src, me)
    local v = Valets[src]
    if not v then return { ok = false } end
    if v.status ~= 'pending' then return { ok = false, error = 'Le voiturier est déjà en route' } end
    Refund(src, v.identifier, v.pay, v.price, 'elyzea-garage-cancel')
    SetGarageState(me, v.plate, 'garage')
    local id = v.id
    CloseValet(src, 'cancelled')
    TriggerClientEvent('elyzea_aura:client:garageAbort', src, { id = id, reason = 'cancelled' })
    return { ok = true, refund = v.price }
end)

-- Remise des clés une fois le véhicule livré
local function GiveVehicleKeys(src, netId, plate)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if GetResourceState('elyzea_core') == 'started' then
        pcall(function() exports.elyzea_core:GiveKeys(src, (veh and veh ~= 0) and veh or plate) end)
    else
        TriggerClientEvent('vehiclekeys:client:SetOwner', src, plate) -- qb-vehiclekeys et compatibles
    end
end

RegisterNetEvent('elyzea_aura:server:garageComplete', function(id, netId)
    local src = source
    local v = Valets[src]
    if not v or v.id ~= id or os.time() - (v.dispatchedAt or os.time()) < 5 then return end
    GiveVehicleKeys(src, tonumber(netId), v.plate)
    CloseValet(src, 'done')
    Notify(src, { app = 'garage', key = 'valetDone', params = { vehicle = v.label } })
end)

RegisterNetEvent('elyzea_aura:server:garageFailed', function(id)
    local src = source
    local v = Valets[src]
    if not v or v.id ~= id then return end
    Refund(src, v.identifier, v.pay, v.price, 'elyzea-garage-refund')
    SetGarageState(v.me, v.plate, 'garage')
    CloseValet(src, 'refunded')
    Notify(src, { app = 'garage', key = 'valetFailed' })
end)

AddEventHandler('playerDropped', function()
    local src = source
    local v = Valets[src]
    if v then
        -- livraison non terminée : remboursement, véhicule remis au garage (et retiré du monde s'il roulait déjà)
        Refund(nil, v.identifier, v.pay, v.price, 'elyzea-garage-refund')
        SetGarageState(v.me, v.plate, 'garage')
        local veh = WorldVehicles()[v.plate]
        if veh and DoesEntityExist(veh) then DeleteEntity(veh) end
        Valets[src] = nil
        MySQL.update('UPDATE elyzea_garage_orders SET status = ? WHERE id = ?', { 'refunded', v.id })
    end
end)

-- ---------------------------------------------------------
--  ElyzeaCarPlay : contrôle des véhicules (état stocké dans les state bags de la voiture)
-- ---------------------------------------------------------
local OwnedCache = {} -- [src] = { at, plates }

local function OwnsPlate(src, me, plate)
    local c = OwnedCache[src]
    if not c or os.time() - c.at > 30 then
        c = { at = os.time(), plates = {} }
        for _, v in ipairs(OwnedVehicles(me)) do c.plates[v.plate] = true end
        OwnedCache[src] = c
    end
    return c.plates[plate] == true
end

-- Dans la voiture : la tablette marche. À distance : seulement pour les véhicules qu'on possède.
local function CanControl(src, me, veh, remote)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return false end
    if not remote and GetVehiclePedIsIn(GetPlayerPed(src), false) == veh then return true end
    return OwnsPlate(src, me, CleanPlate(GetVehicleNumberPlateText(veh)))
end

local function CarState(veh)
    local st = Entity(veh).state
    return {
        locked = st.cp_locked == nil and (GetVehicleDoorLockStatus(veh) or 0) >= 2 or st.cp_locked == true,
        neon = st.cp_neon == true,
        neonColor = st.cp_neonColor or Config.CarPlay.NeonColors[1],
        doors = st.cp_doors or { false, false, false, false, false, false },
        windows = st.cp_windows or { false, false, false, false },
        music = st.cp_music,
        engine = st.cp_engine == nil and GetIsVehicleEngineRunning(veh) or st.cp_engine == true,
        lights = st.cp_lights == true,
    }
end

Register('carplayState', function(src, me, args)
    local veh = NetworkGetEntityFromNetworkId(tonumber(args.netId) or 0)
    if not CanControl(src, me, veh, args.remote) then return { ok = false, error = 'Vous ne pouvez pas contrôler ce véhicule' } end
    local pos = GetEntityCoords(veh)
    return { ok = true, state = CarState(veh), x = pos.x, y = pos.y, plate = CleanPlate(GetVehicleNumberPlateText(veh)),
        distance = math.floor(#(GetEntityCoords(GetPlayerPed(src)) - pos)), colors = Config.CarPlay.NeonColors }
end)

local CarRate = {}
Register('carplayAction', function(src, me, args)
    if not Config.CarPlay.Enabled then return { ok = false } end
    local now = GetGameTimer()
    if (CarRate[src] or 0) > now then return { ok = false, error = 'Doucement !' } end
    CarRate[src] = now + 150
    local veh = NetworkGetEntityFromNetworkId(tonumber(args.netId) or 0)
    if not CanControl(src, me, veh, args.remote) then return { ok = false, error = 'Vous ne pouvez pas contrôler ce véhicule' } end
    local st, a, v = Entity(veh).state, args.action, args.value
    local cur = CarState(veh)

    if a == 'lock' then
        st:set('cp_locked', v == true, true)
        SetVehicleDoorsLocked(veh, v == true and 2 or 1)
        st:set('cp_ping', os.time() .. ':' .. (v and 'lock' or 'unlock'), true)
    elseif a == 'neon' then
        st:set('cp_neon', v == true, true)
    elseif a == 'neonColor' and type(v) == 'table' then
        st:set('cp_neonColor', { math.floor(tonumber(v[1]) or 255) % 256, math.floor(tonumber(v[2]) or 255) % 256, math.floor(tonumber(v[3]) or 255) % 256 }, true)
        st:set('cp_neon', true, true)
    elseif a == 'door' and type(v) == 'table' then
        local i = math.floor(tonumber(v.index) or -1)
        if i < 0 or i > 5 then return { ok = false } end
        local doors = cur.doors; doors[i + 1] = v.open == true
        st:set('cp_doors', doors, true)
    elseif a == 'doorsAll' then
        st:set('cp_doors', { v == true, v == true, v == true, v == true, v == true, v == true }, true)
    elseif a == 'window' and type(v) == 'table' then
        local i = math.floor(tonumber(v.index) or -1)
        if i < 0 or i > 3 then return { ok = false } end
        local w = cur.windows; w[i + 1] = v.down == true
        st:set('cp_windows', w, true)
    elseif a == 'windowsAll' then
        st:set('cp_windows', { v == true, v == true, v == true, v == true }, true)
    elseif a == 'ping' then
        st:set('cp_ping', os.time() .. ':ping', true)
    elseif a == 'alarm' then
        st:set('cp_ping', os.time() .. ':alarm', true)
    elseif a == 'engine' then
        st:set('cp_engine', v == true, true)
    elseif a == 'lights' then
        st:set('cp_lights', v == true, true)
    elseif a == 'music' then
        local track, err = ResolveTrack(trim(v, 500))
        if not track then return { ok = false, error = err } end
        st:set('cp_music', { url = track.url, title = track.title, artist = track.artist, thumb = track.thumb, source = track.source,
            offset = 0, startedAt = os.time(), paused = false, volume = 0.6 }, true)
    elseif a == 'musicPause' or a == 'musicResume' or a == 'musicSeek' or a == 'musicVolume' then
        local m = cur.music
        if not m then return { ok = false } end
        local pos = m.paused and m.offset or (m.offset + os.time() - m.startedAt)
        if a == 'musicPause' then m.offset, m.paused = pos, true
        elseif a == 'musicResume' then m.offset, m.startedAt, m.paused = pos, os.time(), false
        elseif a == 'musicSeek' then m.offset, m.startedAt = math.max(0, tonumber(v) or 0), os.time()
        elseif a == 'musicVolume' then m.volume = math.max(0, math.min(1, tonumber(v) or 0.6)) end
        st:set('cp_music', m, true)
    elseif a == 'musicStop' then
        st:set('cp_music', nil, true)
    else
        return { ok = false }
    end
    return { ok = true, state = CarState(veh) }
end)

-- Toute ma flotte : chaque véhicule sorti, avec son état et sa position
Register('carplayFleet', function(src, me)
    local myPos = GetEntityCoords(GetPlayerPed(src))
    local world, list = WorldVehicles(), {}
    for _, v in ipairs(OwnedVehicles(me)) do
        local veh = world[v.plate]
        if veh and DoesEntityExist(veh) then
            local pos = GetEntityCoords(veh)
            local st = CarState(veh)
            local open = 0
            for i = 1, 6 do if st.doors[i] then open = open + 1 end end
            list[#list + 1] = { netId = NetworkGetNetworkIdFromEntity(veh), plate = v.plate, model = v.model,
                x = pos.x, y = pos.y, z = pos.z, distance = math.floor(#(myPos - pos)),
                locked = st.locked, engine = st.engine, neon = st.neon, lights = st.lights, doorsOpen = open, music = st.music and st.music.title or nil,
                occupied = GetPedInVehicleSeat(veh, -1) ~= 0 }
        end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    return { ok = true, vehicles = list, summonDistance = Config.CarPlay.SummonDistance }
end)

-- Verrouiller / déverrouiller toute la flotte d'un coup
Register('carplayLockAll', function(src, me, args)
    local world, count = WorldVehicles(), 0
    for _, v in ipairs(OwnedVehicles(me)) do
        local veh = world[v.plate]
        if veh and DoesEntityExist(veh) then
            local st = Entity(veh).state
            st:set('cp_locked', args.lock == true, true)
            SetVehicleDoorsLocked(veh, args.lock == true and 2 or 1)
            st:set('cp_ping', os.time() .. ':' .. (args.lock and 'lock' or 'unlock'), true)
            count = count + 1
        end
    end
    return { ok = true, count = count }
end)

-- « Venir à moi » : le serveur vérifie que la voiture m'appartient et qu'elle est vide
Register('carplaySummonCheck', function(src, me, args)
    local veh = NetworkGetEntityFromNetworkId(tonumber(args.netId) or 0)
    if not CanControl(src, me, veh, true) then return { ok = false, error = 'Vous ne pouvez pas contrôler ce véhicule' } end
    if GetPedInVehicleSeat(veh, -1) ~= 0 then return { ok = false, error = 'Quelqu\'un est au volant de ce véhicule' } end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) > Config.CarPlay.SummonDistance then
        return { ok = false, error = 'Trop loin pour venir seule : rapprochez-vous' }
    end
    local st = Entity(veh).state
    st:set('cp_locked', false, true); SetVehicleDoorsLocked(veh, 1)
    st:set('cp_engine', true, true)
    return { ok = true }
end)

AddEventHandler('playerDropped', function() OwnedCache[source] = nil; CarRate[source] = nil end)

-- ---------------------------------------------------------
--  Urgences
-- ---------------------------------------------------------
Register('sendAlert', function(src, me, args)
    local service
    for _, s in ipairs(Config.Services) do if s.id == args.service then service = s end end
    if not service then return { ok = false } end
    local message = trim(args.message, 200)
    if message == '' then message = 'Demande d\'intervention' end
    local coords = GetEntityCoords(GetPlayerPed(src))

    local count = 0
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        if GetJob(s) == service.job then
            count = count + 1
            TriggerClientEvent('elyzea_aura:client:alert', s, {
                service = service.label, serviceId = service.id, color = service.color, message = message,
                number = me.number, coords = { x = coords.x, y = coords.y, z = coords.z }
            })
        end
    end
    return { ok = true, count = count }
end)

-- Export pratique pour d'autres ressources
exports('GetPhoneNumber', function(src)
    local p = EnsurePlayer(src)
    return p and p.number
end)

exports('SendNotification', function(src, title, text, app)
    Notify(src, { app = app or 'system', title = title, text = text })
end)

exports('GetFramework', function() return Framework end)
