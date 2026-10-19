-- =========================================================
--  ELYZEA ANIMAUX - CLIENT : état, interface, événements
-- =========================================================
C = {
    World = { vendors = {}, settings = nil, farm = {} },
    Active = {},     -- [netId] = { id, owner, name, species, harness, leash, radius, neck } (tous les joueurs)
    Mine = {},       -- [id animal] = mes animaux sortis (voir client/pets.lua)
    FarmEnts = {},   -- [netId] = { enc, slot, species, mood }
    ui = nil,        -- vue ouverte : 'shop' | 'pets' | nil
}

function C.Notify(msg, kind) Ely.notify({ description = msg, type = kind or 'inform' }) end
RegisterNetEvent('elyzea_animaux:client:notify', function(msg, kind) C.Notify(msg, kind) end)

-- Problème vu en jeu (modèle absent, commande sans animation…) : envoyé au diagnostic une fois par session
local reported = {}
function C.Issue(kind, what)
    local k = kind .. '|' .. what
    if reported[k] then return end
    reported[k] = true
    TriggerServerEvent('elyzea_animaux:server:issue', kind, what)
end

function C.LoadModel(model, timeout)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local t = GetGameTimer() + (timeout or 8000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > t then return nil end
        Wait(0)
    end
    return hash
end

function C.LoadDict(dict)
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
    return HasAnimDictLoaded(dict)
end

-- Sol sous un point (renvoie z ou nil)
function C.Ground(x, y, z)
    for _, dz in ipairs({ 1.5, 5.0, 25.0, 60.0 }) do
        local ok, gz = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, z + dz, false)
        if ok and gz and math.abs(gz - z) < dz + 2.0 then return gz end
    end
    return nil
end

-- ---------------------------------------------------------
--  Données du serveur
-- ---------------------------------------------------------
RegisterNetEvent('elyzea_animaux:client:world', function(w)
    if type(w) ~= 'table' then return end
    C.World = w
    if C.OnVendors then C.OnVendors() end
    if C.OnSettings then C.OnSettings() end
end)
RegisterNetEvent('elyzea_animaux:client:active', function(list) C.Active = type(list) == 'table' and list or {} end)

local function hello()
    TriggerServerEvent('elyzea_animaux:server:hello')
    TriggerServerEvent('elyzea_animaux:server:farmHello')
end
AddEventHandler('onClientResourceStart', function(res) if res == GetCurrentResourceName() and NetworkIsSessionStarted() then SetTimeout(1500, hello) end end)
RegisterNetEvent('elyzea:client:playerLoaded', function() SetTimeout(2000, hello) end)
CreateThread(function() Wait(4000) hello() end)

-- ---------------------------------------------------------
--  Interface (NUI)
-- ---------------------------------------------------------
function C.OpenUI(view, data)
    C.ui = view
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', view = view, data = data })
end

function C.CloseUI()
    if not C.ui then return end
    local was = C.ui
    C.ui = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if was == 'shop' and C.EndPreview then C.EndPreview() end
end

RegisterNUICallback('close', function(_, cb) cb({}) C.CloseUI() end)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and C.ui then SetNuiFocus(false, false) end end)

-- ---------------------------------------------------------
--  « Mes animaux » (touche F7 / commande /animaux)
-- ---------------------------------------------------------
function C.MyPets()
    local d = Ely.callback.await('elyzea_animaux:myPets', false)
    if type(d) ~= 'table' then return nil end
    for _, p in ipairs(d.pets) do
        local m = C.Mine[p.id]
        p.commands = m and C.CommandList(p.id) or {}
        p.mode = m and m.mode or nil
    end
    return d
end

function C.OpenPets()
    if C.ui then return end
    if IsPauseMenuActive() or IsEntityDead(PlayerPedId()) then return end
    local d = C.MyPets()
    if not d then return C.Notify('Tes animaux ne répondent pas, réessaie.', 'error') end
    C.OpenUI('pets', d)
end

local function refreshPets()
    if C.ui ~= 'pets' then return end
    local d = C.MyPets()
    if d then SendNUIMessage({ action = 'update', view = 'pets', data = d }) end
end
C.RefreshPets = refreshPets

RegisterCommand('animaux', function() C.OpenPets() end, false)
RegisterKeyMapping('animaux', 'Mes animaux (sortir, ranger, ordres, fiche)', 'keyboard', Config.Keys.menu)

RegisterNUICallback('pets', function(body, cb)
    local a, id = body.action, tonumber(body.id)
    if a == 'spawn' then
        cb({})
        CreateThread(function() C.SpawnPet(id) Wait(600) refreshPets() end)
    elseif a == 'store' then
        cb({})
        CreateThread(function() C.StorePet(id) Wait(800) refreshPets() end)
    elseif a == 'command' then
        cb({})
        C.CloseUI()
        CreateThread(function() C.Command(id, body.command) end)
    elseif a == 'care' then
        cb({})
        CreateThread(function() C.Care(id, body.kind) Wait(400) refreshPets() end)
    elseif a == 'leash' then
        cb({})
        CreateThread(function() C.ToggleLeash(id) Wait(400) refreshPets() end)
    elseif a == 'unharness' then
        cb({})
        CreateThread(function() C.Harness(id, nil) Wait(400) refreshPets() end)
    elseif a == 'rename' then
        local ok, msg = Ely.callback.await('elyzea_animaux:rename', false, id, body.name)
        if msg then C.Notify(msg, ok and 'success' or 'error') end
        cb({ ok = ok == true })
        if ok then refreshPets() end
    else
        cb({})
    end
end)

-- ---------------------------------------------------------
--  Objets utilisés depuis l'inventaire
-- ---------------------------------------------------------
RegisterNetEvent('elyzea_animaux:client:useItem', function(kind, slot, meta)
    CreateThread(function()
        if kind == 'feed' then return C.FarmUseFeed and C.FarmUseFeed() end
        local id = C.NearestMine(Config.Care.useDistance + 1.0)
        if kind == 'medkit' and not id then
            -- trousse : peut aussi soigner un animal blessé resté à la maison
            local d = C.MyPets()
            for _, p in ipairs(d and d.pets or {}) do if p.status == 'injured' then return C.Care(p.id, 'medkit') end end
            if C.FarmNearest and C.FarmNearest() then return C.FarmAct(C.FarmNearest(), 'care') end
            return C.Notify('Aucun de tes animaux n\'a besoin de soins ici.', 'error')
        end
        if not id then return C.Notify('Approche-toi de ton animal (sorti).', 'error') end
        if kind == 'harness' then return C.Harness(id, slot) end
        if kind == 'leash' then return C.ToggleLeash(id) end
        C.Care(id, kind)
    end)
end)
