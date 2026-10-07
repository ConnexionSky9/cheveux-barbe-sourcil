--[[
    GO FAST - Sécurité serveur
    * Anti-spam (rate limit par joueur et par event)
    * Jetons de mission
    * Vérifications de distance basées sur la position serveur (OneSync)
    * Avertissements / kick configurable
    * Logs console + Discord (webhook lu dans la convar gofast_webhook)
]]

local U = GoFast.Utils

Security = {}

local RateLimits = {}
local Flags = {}
local TOKEN_CHARS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

-- -------------------------------------------------------------------------
-- Logs
-- -------------------------------------------------------------------------
function Log(category, title, description)
    if not Config.Logs.Enabled or not Config.Logs.Categories[category] then return end

    if Config.Logs.Console then
        print(('^3[gofast][%s]^0 %s | %s'):format(category, title, (description or ''):gsub('\n', ' | ')))
    end

    local webhook = GetConvar('gofast_webhook', '')
    if webhook == '' then return end

    local payload = json.encode({
        username = Config.Logs.BotName,
        embeds = { {
            title = title,
            description = description,
            color = Config.Logs.Colors[category] or 9807270,
            footer = { text = ('gofast | %s'):format(os.date('%d/%m/%Y %H:%M:%S')) },
        } },
    })

    PerformHttpRequest(webhook, function(status)
        if status and status >= 400 then
            print(('^1[gofast] Webhook Discord refusé (HTTP %s)^0'):format(status))
        end
    end, 'POST', payload, { ['Content-Type'] = 'application/json' })
end

-- -------------------------------------------------------------------------
-- Identité lisible pour les logs
-- -------------------------------------------------------------------------
function Security.PlayerLabel(src)
    local license = 'n/a'
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:sub(1, 8) == 'license:' then
            license = identifier
            break
        end
    end
    return ('%s (id %s, %s)'):format(GetPlayerName(src) or U.Lang('unknown'), src, license)
end

-- -------------------------------------------------------------------------
-- Anti-spam
-- -------------------------------------------------------------------------
function Security.RateLimit(src, key, intervalMs)
    local now = GetGameTimer()
    local bucket = RateLimits[src]
    if not bucket then
        bucket = { calls = {}, blocked = 0 }
        RateLimits[src] = bucket
    end

    local last = bucket.calls[key]
    if last and (now - last) < (intervalMs or Config.Security.RateLimitMs) then
        bucket.blocked = bucket.blocked + 1
        if bucket.blocked >= Config.Security.SpamThreshold then
            bucket.blocked = 0
            Security.Flag(src, 'spam', ('Appels répétés sur "%s"'):format(key))
        end
        return false
    end

    bucket.calls[key] = now
    bucket.blocked = math.max(0, bucket.blocked - 1)
    return true
end

-- -------------------------------------------------------------------------
-- Jetons
-- -------------------------------------------------------------------------
function Security.GenerateToken(length)
    local output = {}
    for index = 1, (length or 32) do
        local pick = math.random(#TOKEN_CHARS)
        output[index] = TOKEN_CHARS:sub(pick, pick)
    end
    return table.concat(output)
end

-- -------------------------------------------------------------------------
-- Positions (toujours lues côté serveur, jamais envoyées par le client)
-- -------------------------------------------------------------------------
function Security.GetPedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetEntityCoords(ped)
end

function Security.IsPlayerNear(src, coords, radius)
    local playerCoords = Security.GetPedCoords(src)
    if not playerCoords then return false end
    return #(playerCoords - coords) <= radius
end

-- -------------------------------------------------------------------------
-- Avertissements
-- -------------------------------------------------------------------------
function Security.Flag(src, reason, details)
    Flags[src] = (Flags[src] or 0) + 1
    Log('exploit', 'Comportement suspect', ('%s\nRaison : %s\nDétails : %s\nAvertissements : %d'):format(
        Security.PlayerLabel(src), reason, details or '-', Flags[src]))

    if Config.Security.KickOnExploit and Flags[src] >= Config.Security.MaxFlags then
        DropPlayer(src, U.Lang('kick_exploit'))
    end
end

function Security.Clear(src)
    RateLimits[src] = nil
    Flags[src] = nil
end
