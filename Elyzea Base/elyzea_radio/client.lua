-- =====================================================================
--  elyzea_radio - client : interface, canal pma-voice, batterie, brouilleurs
-- =====================================================================
local voice = exports['pma-voice']
local R = { on = false, freq = nil, label = nil, volume = Config.DefaultVolume, open = false, jammed = false }
local Jammers = {}

local function Notify(msg, kind) Ely.notify({ description = msg, type = kind or 'inform' }) end
local function Kvp(k, def) local v = GetResourceKvpString('elyzea_radio_' .. k) return v and json.decode(v) or def end
local function SetKvp(k, v) SetResourceKvp('elyzea_radio_' .. k, json.encode(v)) end

R.battery = Config.Battery.enabled and (Kvp('battery', 100) or 100) or 100
R.volume = Kvp('volume', Config.DefaultVolume) or Config.DefaultVolume
-- Favoris : liste de { freq, label } (reprend les anciens favoris F1 à F4)
R.favorites = Kvp('favorites', nil)
if type(R.favorites) ~= 'table' then
    R.favorites = {}
    for _, f in pairs(Kvp('presets', {}) or {}) do
        if tonumber(f) then R.favorites[#R.favorites + 1] = { freq = tonumber(f), label = '' } end
    end
    table.sort(R.favorites, function(a, b) return a.freq < b.freq end)
end

local function Job()
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData() end)
    return ok and pd and pd.job or nil
end

-- Canaux réservés du métier du joueur (favoris imposés)
local function JobChannels()
    local job = Job()
    local list = job and Config.JobChannels[job.name] or nil
    if not list then return {}, nil end
    local out = {}
    for _, c in ipairs(list) do out[#out + 1] = { freq = tonumber(('%.2f'):format(c.freq)), label = c.label } end
    return out, job.label or job.name
end

local function HasRadio()
    local ok, n = pcall(function() return exports.elyzea_inventory:Search('count', Config.Item) end)
    return ok and (tonumber(n) or 0) > 0
end

local function State()
    return { on = R.on, freq = R.freq, label = R.label, volume = R.volume, battery = math.floor(R.battery + 0.5),
        batteryEnabled = Config.Battery.enabled, favorites = R.favorites, maxFavorites = Config.MaxFavorites,
        jobChannels = (JobChannels()), jobLabel = select(2, JobChannels()), jammed = R.jammed, max = Config.MaxFrequency,
        restricted = Config.Restricted }
end
local function Push() if R.open then SendNUIMessage({ action = 'state', state = State() }) end end

local function Leave(silent)
    if R.freq then
        pcall(function() voice:setRadioChannel(0) end)
        pcall(function() voice:setVoiceProperty('radioEnabled', false) end)
        if not silent then Notify('Radio : canal quitté.', 'inform') end
    end
    R.freq, R.label = nil, nil
    Push()
end

local function PowerOff(reason)
    Leave(true)
    R.on = false
    if reason then Notify(reason, 'error') end
    Push()
end

local function Open()
    if not HasRadio() then return Notify('Tu n\'as pas de radio.', 'error') end
    R.open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', state = State() })
end

local function Close()
    R.open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('elyzea_radio:use', Open)
RegisterNetEvent('elyzea_radio:recharge', function() TriggerServerEvent('elyzea_radio:useBattery') end)
RegisterNetEvent('elyzea_radio:recharged', function()
    R.battery = 100
    SetKvp('battery', R.battery)
    Notify('Radio rechargée (100 %).', 'success')
    Push()
end)
RegisterNetEvent('elyzea_radio:useJammer', function()
    if not Config.Jammer.enabled then return Notify('Le brouilleur est désactivé.', 'error') end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return Notify('Sors du véhicule pour poser le brouilleur.', 'error') end
    local done = Ely.progressBar({ duration = 4000, label = 'Installation du brouilleur', canCancel = true,
        disable = { move = true, car = true, combat = true }, anim = { dict = 'amb@medic@standing@kneel@base', clip = 'base', flag = 1 } })
    ClearPedTasks(ped)
    if done then TriggerServerEvent('elyzea_radio:placeJammer') end
end)

RegisterNetEvent('elyzea_radio:joined', function(ok, freqOrMsg, label)
    if not ok then
        Notify(freqOrMsg or 'Impossible de rejoindre cette fréquence.', 'error')
        return Push()
    end
    R.freq, R.label = freqOrMsg, label
    pcall(function() voice:setVoiceProperty('radioEnabled', true) end)
    pcall(function() voice:setRadioVolume(R.volume) end)
    pcall(function() voice:setRadioChannel(R.freq) end)
    Notify(('Radio : fréquence %.2f%s.'):format(R.freq, label and (' (' .. label .. ')') or ''), 'success')
    Push()
end)

-- ---------------------------------------------------------------------
-- Interface
-- ---------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb) Close() cb('ok') end)
RegisterNUICallback('power', function(_, cb)
    cb('ok')
    if R.on then return PowerOff() end
    if Config.Battery.enabled and R.battery <= 0 then Notify('Batterie vide : utilise des piles.', 'error') return Push() end
    if R.jammed then Notify('Signal brouillé ici.', 'error') return Push() end
    R.on = true
    Push()
end)
RegisterNUICallback('join', function(body, cb)
    cb('ok')
    if not R.on then return Notify('Allume la radio d\'abord.', 'error') end
    if R.jammed then return Notify('Signal brouillé ici.', 'error') end
    local f = tonumber(body.freq)
    if not f then return Notify('Fréquence invalide.', 'error') end
    TriggerServerEvent('elyzea_radio:join', f)
end)
RegisterNUICallback('leave', function(_, cb) cb('ok') Leave() end)
RegisterNUICallback('volume', function(body, cb)
    cb('ok')
    R.volume = math.max(0, math.min(100, math.floor(tonumber(body.volume) or R.volume)))
    SetKvp('volume', R.volume)
    if R.freq then pcall(function() voice:setRadioVolume(R.volume) end) end
    Push()
end)
local function Round(f) return tonumber(('%.2f'):format(tonumber(f) or 0)) end

RegisterNUICallback('favJoin', function(body, cb)
    cb('ok')
    if not R.on then return Notify('Allume la radio d\'abord.', 'error') end
    if R.jammed then return Notify('Signal brouillé ici.', 'error') end
    local f = tonumber(body.freq)
    if f then TriggerServerEvent('elyzea_radio:join', f) end
end)

RegisterNUICallback('favAdd', function(body, cb)
    cb('ok')
    local f = Round(tonumber(body.freq) or R.freq)
    if not f or f < 1 or f > Config.MaxFrequency then return Notify('Entre une fréquence valide (1.00 à ' .. Config.MaxFrequency .. ').', 'error') end
    for _, c in ipairs((JobChannels())) do if c.freq == f then return Notify('Cette fréquence est déjà dans les canaux de ton métier.', 'inform') end end
    local label = tostring(body.label or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 24)
    for _, fav in ipairs(R.favorites) do
        if fav.freq == f then
            fav.label = label ~= '' and label or fav.label
            SetKvp('favorites', R.favorites)
            Notify('Favori mis à jour.', 'success')
            return Push()
        end
    end
    if #R.favorites >= Config.MaxFavorites then return Notify(('%d favoris maximum : supprimes-en un.'):format(Config.MaxFavorites), 'error') end
    R.favorites[#R.favorites + 1] = { freq = f, label = label }
    table.sort(R.favorites, function(a, b) return a.freq < b.freq end)
    SetKvp('favorites', R.favorites)
    Notify(('Fréquence %.2f ajoutée aux favoris.'):format(f), 'success')
    Push()
end)

RegisterNUICallback('favDel', function(body, cb)
    cb('ok')
    local f = Round(body.freq)
    for i, fav in ipairs(R.favorites) do
        if fav.freq == f then table.remove(R.favorites, i) break end
    end
    SetKvp('favorites', R.favorites)
    Push()
end)

-- Le métier change : les canaux du métier suivent
RegisterNetEvent('elyzea:client:onJobUpdate', function() SetTimeout(200, Push) end)

-- ---------------------------------------------------------------------
-- Radio retirée de l'inventaire, batterie, brouilleurs
-- ---------------------------------------------------------------------
RegisterNetEvent('elyzea_radio:jammers', function(list) Jammers = type(list) == 'table' and list or {} end)
AddEventHandler('onClientResourceStart', function(res) if res == GetCurrentResourceName() then TriggerServerEvent('elyzea_radio:requestJammers') end end)

local jamProps = {}
local function JamProps()
    for id, obj in pairs(jamProps) do
        if not Jammers[id] then if DoesEntityExist(obj) then DeleteEntity(obj) end jamProps[id] = nil end
    end
    for id, j in pairs(Jammers) do
        if not jamProps[id] and #(GetEntityCoords(PlayerPedId()) - vector3(j.x, j.y, j.z)) < 120.0 then
            local hash = joaat(Config.Jammer.model)
            if IsModelInCdimage(hash) and pcall(Ely.requestModel, hash, 3000) then
                local obj = CreateObject(hash, j.x, j.y, j.z, false, false, false)
                FreezeEntityPosition(obj, true)
                SetModelAsNoLongerNeeded(hash)
                jamProps[id] = obj
            end
        end
    end
end

CreateThread(function()
    local tick = 0
    while true do
        Wait(2000)
        tick = tick + 2
        if R.on and not HasRadio() then PowerOff('Radio : tu n\'as plus ta radio.') end
        -- brouilleurs
        local pc, jammed = GetEntityCoords(PlayerPedId()), false
        for _, j in pairs(Jammers) do if #(pc - vector3(j.x, j.y, j.z)) <= (j.radius or 35.0) then jammed = true break end end
        if jammed ~= R.jammed then
            R.jammed = jammed
            if jammed and R.freq then Leave(true) Notify('Radio : signal brouillé.', 'error') end
            Push()
        end
        JamProps()
        -- batterie
        if Config.Battery.enabled and R.on and tick % 60 == 0 then
            local before = R.battery
            R.battery = math.max(0, R.battery - Config.Battery.drainPerMinute)
            SetKvp('battery', R.battery)
            if before > Config.Battery.lowWarning and R.battery <= Config.Battery.lowWarning then Notify(('Radio : batterie faible (%d %%).'):format(math.floor(R.battery)), 'error') end
            if R.battery <= 0 then PowerOff('Radio : batterie vide.') end
            Push()
        end
        if IsEntityDead(PlayerPedId()) and R.freq then Leave(true) end
    end
end)

RegisterNetEvent('elyzea:client:playerUnloaded', function() PowerOff() end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if R.freq then pcall(function() voice:setRadioChannel(0) end) end
    if R.open then SetNuiFocus(false, false) end
    for _, obj in pairs(jamProps) do if DoesEntityExist(obj) then DeleteEntity(obj) end end
end)

exports('GetFrequency', function() return R.freq end)
exports('IsOn', function() return R.on end)
