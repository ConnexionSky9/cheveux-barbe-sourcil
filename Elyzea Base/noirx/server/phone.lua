--[[
    NOIR X — Serveur : ouverture et session du téléphone
    Principes :
      • Le client ne peut que DEMANDER l'ouverture ; le serveur vérifie la possession.
      • Chaque ouverture crée une session avec un jeton aléatoire ; toute action NUI
        relayée au serveur doit présenter ce jeton (voir server/core/rpc.lua).
      • Pendant l'ouverture, la possession est revérifiée périodiquement : si l'item
        est saisi, supprimé ou transféré, le téléphone se ferme.
      • L'usage de l'item ne modifie jamais l'inventaire (aucune duplication possible).
]]

Phone = { sessions = {}, onOpen = {} }

local Sessions = Phone.sessions -- [src] = { token, charId, openedAt, settings, lastReqId }
local LastOpen = {}
local MemSettings = {}
local SessionSeq = 0

local function newToken()
    SessionSeq = SessionSeq + 1
    return ('%08x%08x%08x%04x'):format(math.random(0, 0x7fffffff), math.random(0, 0x7fffffff),
        GetGameTimer() & 0x7fffffff, SessionSeq % 0xffff)
end

local function newSerial()
    local chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    local function block(n)
        local s = {}
        for i = 1, n do
            local k = math.random(1, #chars)
            s[i] = chars:sub(k, k)
        end
        return table.concat(s)
    end
    return ('NX-%s-%s'):format(block(4), block(4))
end

local function defaultSettings()
    return {
        wallpaper = Config.UI.defaultWallpaper,
        sounds = Config.UI.sounds.enabled,
        volume = Config.UI.sounds.volume,
        battery = 100,
    }
end

local function loadDevice(charId)
    if DB.driver == 'none' then
        MemSettings[charId] = MemSettings[charId] or { serial = newSerial(), settings = defaultSettings() }
        return MemSettings[charId]
    end
    local row = DB.Single('SELECT serial, settings FROM noirx_devices WHERE owner = ?', { charId })
    if row then
        local settings = row.settings and json.decode(row.settings) or nil
        local merged = defaultSettings()
        if type(settings) == 'table' then
            for k, v in pairs(settings) do merged[k] = v end
        end
        return { serial = row.serial, settings = merged }
    end
    local device = { serial = newSerial(), settings = defaultSettings() }
    DB.Insert('INSERT INTO noirx_devices (owner, serial, settings) VALUES (?, ?, ?)',
        { charId, device.serial, json.encode(device.settings) })
    return device
end

local function saveSettings(charId, settings)
    if DB.driver == 'none' then
        if MemSettings[charId] then MemSettings[charId].settings = settings end
        return
    end
    DB.Execute('UPDATE noirx_devices SET settings = ? WHERE owner = ?', { json.encode(settings), charId })
end

local function sanitizeSettings(input, current)
    if type(input) ~= 'table' then return nil end
    local out = {}
    for k, v in pairs(current) do out[k] = v end

    if input.wallpaper ~= nil then
        local valid = false
        for _, w in ipairs(Config.UI.wallpapers) do
            if w == input.wallpaper then valid = true break end
        end
        if not valid then return nil end
        out.wallpaper = input.wallpaper
    end
    if input.sounds ~= nil then
        if type(input.sounds) ~= 'boolean' then return nil end
        out.sounds = input.sounds
    end
    if input.volume ~= nil then
        if type(input.volume) ~= 'number' or input.volume ~= input.volume then return nil end
        out.volume = NoirX.Clamp(math.floor(input.volume * 100 + 0.5) / 100, 0.0, 1.0)
    end
    if input.battery ~= nil then
        if type(input.battery) ~= 'number' or input.battery ~= input.battery then return nil end
        out.battery = NoirX.Clamp(math.floor(input.battery), Config.UI.battery.min, 100)
    end
    return out
end

function Phone.GetSession(src)
    return Sessions[tonumber(src) or -1]
end

function Phone.ForceClose(src, reason)
    local s = Sessions[src]
    if not s then return end
    Sessions[src] = nil
    TriggerClientEvent('noirx:client:forceClose', src, reason)
    Audit.Log(src, 'phone.close', { reason = reason })
end

local function requestOpen(src, origin)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then return false end

    local now = GetGameTimer()
    if LastOpen[src] and now - LastOpen[src] < Config.Phone.openCooldownMs then
        return false
    end
    LastOpen[src] = now

    if Sessions[src] then
        TriggerClientEvent('noirx:client:focus', src)
        return true
    end

    if not Inventory.IsConfigured() then
        TriggerClientEvent('noirx:client:notify', src, 'NOIR X', 'Terminal non relié à l\'inventaire du serveur.')
        return false
    end

    if not Inventory.HasItem(src, Config.Item.name) then
        Audit.Log(src, 'phone.open_denied', { origin = origin })
        return false
    end

    local charId = Players.CharOf(src)
    if not charId then
        NoirX.Error(('Impossible d\'identifier le joueur %d'):format(src))
        return false
    end

    local device = loadDevice(charId)
    local token = newToken()
    Sessions[src] = { token = token, charId = charId, openedAt = os.time(), settings = device.settings, lastReqId = 0 }

    TriggerClientEvent('noirx:client:open', src, {
        token = token,
        serial = device.serial,
        settings = device.settings,
        apps = NoirX.EnabledApps(),
        money = { symbol = Config.Money.symbol },
        ui = {
            bootDuration = Config.UI.bootDuration,
            showBootEveryOpen = Config.UI.showBootEveryOpen,
            battery = Config.UI.battery,
            sounds = Config.UI.sounds,
            wallpapers = Config.UI.wallpapers,
        },
    })
    Audit.Log(src, 'phone.open', { origin = origin, serial = device.serial })

    for _, hook in ipairs(Phone.onOpen) do
        local ok, err = pcall(hook, src, charId)
        if not ok then NoirX.Error('onOpen :', tostring(err)) end
    end
    if DB.driver ~= 'none' then
        CreateThread(function() Payouts.Deliver(src) end)
    end
    return true
end

Phone.RequestOpen = requestOpen

local function validSession(src, token)
    local s = Sessions[src]
    return s ~= nil and type(token) == 'string' and s.token == token, s
end

-- ─── Exports serveur ─────────────────────────────────────────────

exports('UseNoirphone', function(src)
    return requestOpen(src, 'item')
end)

exports('ForceClose', function(src, reason)
    Phone.ForceClose(tonumber(src), reason or 'external')
end)

exports('IsPhoneOpen', function(src)
    return Sessions[tonumber(src)] ~= nil
end)

exports('Notify', function(src, title, body)
    return Push.Notify(tonumber(src), title, body)
end)

-- ─── Événements réseau ───────────────────────────────────────────

RegisterNetEvent('noirx:server:requestOpen', function()
    if not Config.Phone.command and not Config.Phone.keybind then return end
    requestOpen(source, 'command')
end)

RegisterNetEvent('noirx:server:closed', function(token)
    local src = source
    local ok, s = validSession(src, token)
    if not ok then return end
    Sessions[src] = nil
    Audit.Log(src, 'phone.close', { reason = 'user', duration = os.time() - s.openedAt })
end)

RegisterNetEvent('noirx:server:saveSettings', function(token, input)
    local src = source
    local ok, s = validSession(src, token)
    if not ok then return end
    local clean = sanitizeSettings(input, s.settings)
    if not clean then
        Audit.Log(src, 'phone.settings_rejected', {})
        return
    end
    s.settings = clean
    saveSettings(s.charId, clean)
end)

-- Relais des notifications « téléphone » d'autres ressources (voir client/phone.lua).
-- Le message ne peut viser que l'émetteur lui-même : aucun risque d'envoi à un autre joueur.
local RelayBucket = {}
RegisterNetEvent('noirx:server:relayNotify', function(title, message)
    local src = source
    if not Config.Integrations or not Config.Integrations.illegalPhone then return end
    if type(title) ~= 'string' or type(message) ~= 'string' then return end
    local t = GetGameTimer()
    local b = RelayBucket[src]
    if not b or t - b.at > 10000 then b = { at = t, n = 0 }; RelayBucket[src] = b end
    b.n = b.n + 1
    if b.n > 6 then return end
    title, message = title:sub(1, 40), message:sub(1, 200)
    if Push.Notify(src, title ~= '' and title or 'Numéro inconnu', message) then return end
    if GetResourceState('elyzea_core') == 'started' then
        exports.elyzea_core:Notify(src, message, 'warning', 6000, title)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    RelayBucket[src] = nil
    local s = Sessions[src]
    if s then
        Sessions[src] = nil
        Audit.Log(src, 'phone.close', { reason = 'disconnect' })
    end
    LastOpen[src] = nil
end)

-- Revérification de possession pendant l'ouverture.
CreateThread(function()
    while true do
        Wait(Config.Inventory.recheckInterval)
        for src in pairs(Sessions) do
            if not GetPlayerName(src) then
                Sessions[src] = nil
            elseif not Inventory.HasItem(src, Config.Item.name) then
                Phone.ForceClose(src, 'item_lost')
            else
                -- Argent sale / propre modifié par un autre script : le portefeuille se met à jour.
                local s = Sessions[src]
                local w = Wallet.Get(src)
                local sig = tostring(w.dirty) .. ':' .. tostring(w.clean)
                if s and s.walletSig and s.walletSig ~= sig then Push.ToSrc(src, 'wallet:changed', {}) end
                if s then s.walletSig = sig end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(Sessions) do
        TriggerClientEvent('noirx:client:forceClose', src, 'restart')
    end
end)

math.randomseed(os.time())
