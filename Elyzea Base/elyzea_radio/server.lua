-- =====================================================================
--  elyzea_radio - serveur : canaux réservés, piles, brouilleurs
-- =====================================================================
local core = exports.elyzea_core
local inv = exports.elyzea_inventory
local Jammers, jamSeq = {}, 0

local function Round(f) return tonumber(('%.2f'):format(tonumber(f) or 0)) end

local function RangeOf(freq)
    for _, r in ipairs(Config.Restricted) do
        if freq >= r.from and freq <= r.to then return r end
    end
end

local function Allowed(src, freq)
    local r = RangeOf(freq)
    if not r then return true end
    local p = core:GetPlayer(src)
    local job = p and p.PlayerData.job
    if not job or not r.jobs[job.name] then return false, r end
    if r.requireDuty and not job.onduty then return false, r end
    return true, r
end

local function HasItem(src, item)
    local ok, n = pcall(function() return inv:GetItemCount(src, item) end)
    return ok and (tonumber(n) or 0) > 0
end

-- pma-voice : bloque aussi les canaux réservés si un joueur passe outre l'interface
CreateThread(function()
    while GetResourceState('pma-voice') ~= 'started' do Wait(1000) end
    for _, r in ipairs(Config.Restricted) do
        local f = math.floor(r.from * 100 + 0.5)
        local t = math.floor(r.to * 100 + 0.5)
        for i = f, t do
            local ch = Round(i / 100)
            pcall(function() exports['pma-voice']:addChannelCheck(ch, function(src) return (Allowed(src, ch)) end) end)
            if ch == math.floor(ch) then
                pcall(function() exports['pma-voice']:addChannelCheck(math.floor(ch), function(src) return (Allowed(src, ch)) end) end)
            end
        end
    end
end)

RegisterNetEvent('elyzea_radio:join', function(freq)
    local src = source
    freq = Round(freq)
    if not freq or freq < 1 or freq > Config.MaxFrequency then
        return TriggerClientEvent('elyzea_radio:joined', src, false, 'Fréquence invalide.')
    end
    if not HasItem(src, Config.Item) then return TriggerClientEvent('elyzea_radio:joined', src, false, 'Tu n\'as pas de radio.') end
    local ok, r = Allowed(src, freq)
    if not ok then
        return TriggerClientEvent('elyzea_radio:joined', src, false, ('Fréquence réservée : %s.'):format(r.label))
    end
    TriggerClientEvent('elyzea_radio:joined', src, true, freq, r and r.label or nil)
end)

-- Piles : l'objet est retiré ici, la batterie est rechargée côté client
RegisterNetEvent('elyzea_radio:useBattery', function()
    local src = source
    if not HasItem(src, Config.BatteryItem) then return end
    local ok, res = pcall(function() return inv:RemoveItem(src, Config.BatteryItem, 1) end)
    if ok and res ~= false then TriggerClientEvent('elyzea_radio:recharged', src) end
end)

-- Brouilleurs
local function SyncJammers(target) TriggerClientEvent('elyzea_radio:jammers', target or -1, Jammers) end

RegisterNetEvent('elyzea_radio:placeJammer', function()
    local src = source
    if not Config.Jammer.enabled or not HasItem(src, Config.JammerItem) then return end
    if Config.Jammer.consume then
        local ok, res = pcall(function() return inv:RemoveItem(src, Config.JammerItem, 1) end)
        if not ok or res == false then return end
    end
    local c = GetEntityCoords(GetPlayerPed(src))
    jamSeq = jamSeq + 1
    Jammers[tostring(jamSeq)] = { x = c.x, y = c.y, z = c.z - 0.95, radius = Config.Jammer.radius, expires = os.time() + Config.Jammer.duration * 60 }
    SyncJammers()
    core:Notify(src, ('Brouilleur posé : les radios sont coupées dans un rayon de %d m pendant %d min.'):format(math.floor(Config.Jammer.radius), Config.Jammer.duration), 'success')
end)

CreateThread(function()
    while true do
        Wait(15000)
        local now, changed = os.time(), false
        for id, j in pairs(Jammers) do if j.expires <= now then Jammers[id] = nil changed = true end end
        if changed then SyncJammers() end
    end
end)

AddEventHandler('elyzea:server:playerLoaded', function(src) SyncJammers(src) end)
RegisterNetEvent('elyzea_radio:requestJammers', function() SyncJammers(source) end)

exports('IsRestricted', function(freq) return RangeOf(Round(freq)) ~= nil end)
