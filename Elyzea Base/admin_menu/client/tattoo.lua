-- =========================================================
--  TATOUEUR - CLIENT
--  Survol = aperçu du tatouage sur le personnage, clic = panier.
--  Aucune boucle quand le salon est fermé.
-- =========================================================
local CFG = Config.Tattoo or {}
local MALE, FEMALE = `mp_m_freemode_01`, `mp_f_freemode_01`

TattooOpen = false

local catalog, catalogVersion = nil, -1      -- { id = entrée }
local zonesDef, collectionsDef = {}, {}
local waitingCatalog = false
local nuiSent = {}                            -- catalogue déjà envoyé à l'interface (par sexe et version)

local shop, gender, awaiting
local baseDeco = {}                           -- tatouages (et dégradés) avant l'entrée : { {coll, over}, … }
local adds, removes, preview = {}, {}, nil    -- adds[id] = true, removes[id] = true
local outfit                                  -- vêtements retirés pendant le tatouage

-- ---------------------------------------------------------
--  Catalogue (reçu une fois du serveur, gardé en mémoire)
-- ---------------------------------------------------------
RegisterNetEvent('adminmenu:tattoo:catalog', function(version, list, zones, collections)
    catalog, catalogVersion = {}, version
    for _, e in ipairs(list or {}) do
        catalog[e[1]] = { id = e[1], collection = e[2], m = e[3], f = e[4], zone = e[5], label = e[6], gxt = e[7] }
    end
    zonesDef, collectionsDef = zones or {}, collections or {}
    waitingCatalog = false
    nuiSent = {}
end)

local function overlayName(e) return gender == 'female' and e.f or e.m end

local function displayName(e)
    if e.gxt and e.gxt ~= '' then
        local t = GetLabelText(e.gxt)
        if t and t ~= 'NULL' and t ~= '' then return t end
    end
    if e.label and e.label ~= '' then return e.label end
    return overlayName(e)
end

-- ---------------------------------------------------------
--  Application des tatouages
-- ---------------------------------------------------------
local function readDecorations(p)
    local out = {}
    local ok, list = pcall(GetPedDecorations, p)
    if ok and type(list) == 'table' then
        for _, d in ipairs(list) do
            if type(d) == 'table' and d[1] and d[2] then out[#out + 1] = { d[1], d[2] } end
        end
    end
    return out
end

local removedHash = {}   -- hash d'overlay → true pour les tatouages à retirer
local function rebuildRemoved()
    removedHash = {}
    for id in pairs(removes) do
        local e = catalog[id]
        if e then removedHash[GetHashKey(overlayName(e))] = true end
    end
end

local function finalList()
    local out = {}
    for _, d in ipairs(baseDeco) do
        if not removedHash[d[2]] then out[#out + 1] = { d[1], d[2] } end
    end
    for id in pairs(adds) do
        local e = catalog[id]
        if e then out[#out + 1] = { GetHashKey(e.collection), GetHashKey(overlayName(e)) } end
    end
    return out
end

local function apply()
    local p = PlayerPedId()
    ClearPedDecorations(p)
    for _, d in ipairs(finalList()) do AddPedDecorationFromHashes(p, d[1], d[2]) end
    if preview and catalog[preview] and not adds[preview] then
        local e = catalog[preview]
        AddPedDecorationFromHashes(p, GetHashKey(e.collection), GetHashKey(overlayName(e)))
    end
end

-- ---------------------------------------------------------
--  Vêtements : en sous-vêtements pendant le tatouage
-- ---------------------------------------------------------
local function undress(p)
    local set = (CFG.undress or {})[gender]
    if not set then return end
    outfit = {}
    for comp, v in pairs(set) do
        outfit[comp] = { GetPedDrawableVariation(p, comp), GetPedTextureVariation(p, comp) }
        SetPedComponentVariation(p, comp, v[1], v[2] or 0, 0)
    end
    outfit.hat = { GetPedPropIndex(p, 0), GetPedPropTextureIndex(p, 0) }
    outfit.glasses = { GetPedPropIndex(p, 1), GetPedPropTextureIndex(p, 1) }
    ClearPedProp(p, 0)
    ClearPedProp(p, 1)
end

local function redress()
    if not outfit then return end
    local p, o = PlayerPedId(), outfit
    outfit = nil
    for comp, v in pairs(o) do
        if type(comp) == 'number' then SetPedComponentVariation(p, comp, v[1], v[2], 0) end
    end
    if o.hat[1] >= 0 then SetPedPropIndex(p, 0, o.hat[1], o.hat[2], true) end
    if o.glasses[1] >= 0 then SetPedPropIndex(p, 1, o.glasses[1], o.glasses[2], true) end
end

-- ---------------------------------------------------------
--  Caméra
-- ---------------------------------------------------------
local CAMS = {
    face  = { ref = 'head', dist = 0.70, z = 0.05,  look = 0.00,  fov = 34.0, turn = 0 },
    torso = { ref = 'root', dist = 1.45, z = 0.35,  look = 0.25,  fov = 40.0, turn = 0 },
    larm  = { ref = 'root', dist = 1.35, z = 0.30,  look = 0.20,  fov = 42.0, turn = -90 },
    rarm  = { ref = 'root', dist = 1.35, z = 0.30,  look = 0.20,  fov = 42.0, turn = 90 },
    legs  = { ref = 'root', dist = 1.70, z = -0.35, look = -0.45, fov = 42.0, turn = 0 },
    full  = { ref = 'root', dist = 2.60, z = 0.10,  look = -0.05, fov = 45.0, turn = 0 },
}
local cam, camMode, zoom, spin = nil, 'full', 1.0, 0
local head, root, fwd, baseHeading, radarWas
local cur = {}

local function target()
    local m = CAMS[camMode] or CAMS.full
    local a = m.ref == 'head' and head or root
    local d = m.dist * zoom
    return a.x + fwd.x * d, a.y + fwd.y * d, a.z + m.z, a.x, a.y, a.z + m.look, m.fov
end

local function setCam(mode, back)
    if not CAMS[mode] then return end
    camMode, zoom = mode, 1.0
    local turn = CAMS[mode].turn + (back and 180 or 0)
    SetEntityHeading(PlayerPedId(), baseHeading + turn)
end

local function startCamera(p)
    baseHeading = GetEntityHeading(p)
    local r = math.rad(baseHeading)
    fwd = { x = -math.sin(r), y = math.cos(r) }
    local h = GetPedBoneCoords(p, 31086, 0.0, 0.0, 0.0)
    local c = GetEntityCoords(p)
    head, root = { x = h.x, y = h.y, z = h.z }, { x = c.x, y = c.y, z = c.z }
    camMode, zoom, spin = 'full', 1.0, 0
    local x, y, z, lx, ly, lz, fov = target()
    cur = { x = x, y = y, z = z, lx = lx, ly = ly, lz = lz, fov = fov }
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', x, y, z, 0.0, 0.0, 0.0, fov, false, 2)
    PointCamAtCoord(cam, lx, ly, lz)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 600, true, false)
end

local function stopCamera()
    if not cam then return end
    RenderScriptCams(false, true, 500, true, false)
    DestroyCam(cam, false)
    cam = nil
end

-- ---------------------------------------------------------
--  Ouverture / fermeture
-- ---------------------------------------------------------
local function close(revert)
    if not TattooOpen then return end
    TattooOpen, awaiting = false, false
    if revert then adds, removes, preview = {}, {}, nil rebuildRemoved() apply() end
    preview = nil
    redress()
    stopCamera()
    local p = PlayerPedId()
    if baseHeading then SetEntityHeading(p, baseHeading) end
    FreezeEntityPosition(p, false)
    if radarWas then DisplayRadar(true) end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'tattoo', open = false })
    shop = nil
end

local function frameLoop()
    CreateThread(function()
        while TattooOpen do
            HideHudAndRadarThisFrame()
            local p = PlayerPedId()
            if IsEntityDead(p) or IsPedInAnyVehicle(p, false) then close(true) break end
            local ft = GetFrameTime()
            if spin ~= 0 then SetEntityHeading(p, GetEntityHeading(p) + spin * 110.0 * ft) end
            if cam then
                local x, y, z, lx, ly, lz, fov = target()
                local k = math.min(1.0, ft * 8.0)
                cur.x, cur.y, cur.z = cur.x + (x - cur.x) * k, cur.y + (y - cur.y) * k, cur.z + (z - cur.z) * k
                cur.lx, cur.ly, cur.lz = cur.lx + (lx - cur.lx) * k, cur.ly + (ly - cur.ly) * k, cur.lz + (lz - cur.lz) * k
                cur.fov = cur.fov + (fov - cur.fov) * k
                SetCamCoord(cam, cur.x, cur.y, cur.z)
                PointCamAtCoord(cam, cur.lx, cur.ly, cur.lz)
                SetCamFov(cam, cur.fov)
            end
            Wait(0)
        end
    end)
end

local function open(data)
    local p = PlayerPedId()
    local m = GetEntityModel(p)
    if m ~= MALE and m ~= FEMALE then
        return Notify('Le tatoueur ne travaille que sur un personnage personnalisé (freemode).', 'error')
    end
    if IsPedInAnyVehicle(p, false) or IsEntityDead(p) or TattooOpen then return end
    gender = m == MALE and 'male' or 'female'
    shop = data
    adds, removes, preview = {}, {}, nil
    rebuildRemoved()
    baseDeco = readDecorations(p)

    -- Tatouages déjà portés (reconnus dans le catalogue)
    local owned, byHash = {}, {}
    for id, e in pairs(catalog) do
        local o = overlayName(e)
        if o and o ~= '' then byHash[GetHashKey(o)] = id end
    end
    for _, d in ipairs(baseDeco) do if byHash[d[2]] then owned[#owned + 1] = byHash[d[2]] end end

    ClearPedTasks(p)
    FreezeEntityPosition(p, true)
    undress(p)
    radarWas = not IsRadarHidden()
    DisplayRadar(false)
    startCamera(p)

    -- Catalogue envoyé à l'interface une seule fois par sexe
    local sig = gender .. ':' .. catalogVersion
    local list
    if not nuiSent[sig] then
        list = {}
        for id, e in pairs(catalog) do
            local o = overlayName(e)
            if o and o ~= '' then
                list[#list + 1] = { id, displayName(e), e.zone, e.collection, collectionsDef[e.collection] or e.collection:gsub('_overlays$', ''):gsub('^mp', '') }
            end
        end
        table.sort(list, function(a, b) return a[1] < b[1] end)
        nuiSent[sig] = true
    end

    TattooOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'tattoo', open = true, shop = data, gender = gender, sig = sig,
        list = list, zones = zonesDef, owned = owned })
    frameLoop()
end

RegisterNetEvent('adminmenu:tattoo:show', function(data)
    if TattooOpen or type(data) ~= 'table' then return end
    if (IsStaffMenuOpen and IsStaffMenuOpen()) or BarberOpen or MarketOpen then return end
    if catalog and catalogVersion == data.version then return open(data) end
    if waitingCatalog then return end
    waitingCatalog = true
    TriggerServerEvent('adminmenu:tattoo:catalog')
    CreateThread(function()
        local t = GetGameTimer() + 10000
        while waitingCatalog and GetGameTimer() < t do Wait(100) end
        if waitingCatalog then
            waitingCatalog = false
            return Notify('Le catalogue des tatouages ne répond pas, réessaie.', 'error')
        end
        open(data)
    end)
end)

-- ---------------------------------------------------------
--  Callbacks de l'interface
-- ---------------------------------------------------------
local function idOf(d) local id = tonumber(d and d.id) return id and catalog and catalog[id] and id or nil end

RegisterNUICallback('tattoo_preview', function(d, cb)
    cb('ok')
    if not TattooOpen or awaiting then return end
    local id = idOf(d)
    if id == preview then return end
    preview = id
    apply()
end)
RegisterNUICallback('tattoo_add', function(d, cb)
    cb('ok')
    local id = idOf(d)
    if not TattooOpen or awaiting or not id then return end
    if d.on then adds[id] = true else adds[id] = nil end
    preview = nil
    apply()
end)
RegisterNUICallback('tattoo_remove', function(d, cb)
    cb('ok')
    local id = idOf(d)
    if not TattooOpen or awaiting or not id then return end
    if d.on then removes[id] = true else removes[id] = nil end
    rebuildRemoved()
    preview = nil
    apply()
end)
RegisterNUICallback('tattoo_reset', function(_, cb)
    cb('ok')
    if not TattooOpen or awaiting then return end
    adds, removes, preview = {}, {}, nil
    rebuildRemoved()
    apply()
end)
RegisterNUICallback('tattoo_cam', function(d, cb) cb('ok') if TattooOpen then setCam(d.mode, d.back == true) end end)
RegisterNUICallback('tattoo_rotate', function(d, cb)
    cb('ok')
    if not TattooOpen then return end
    local p = PlayerPedId()
    SetEntityHeading(p, GetEntityHeading(p) + math.max(-45.0, math.min(45.0, tonumber(d.d) or 0.0)))
end)
RegisterNUICallback('tattoo_spin', function(d, cb) cb('ok') spin = math.max(-1, math.min(1, math.floor(tonumber(d.dir) or 0))) end)
RegisterNUICallback('tattoo_zoom', function(d, cb) cb('ok') zoom = math.max(0.5, math.min(1.9, zoom + (tonumber(d.d) or 0) * 0.08)) end)
RegisterNUICallback('tattoo_close', function(_, cb) cb('ok') if not awaiting then close(true) end end)

RegisterNUICallback('tattoo_pay', function(d, cb)
    cb('ok')
    if not TattooOpen or awaiting or not shop then return end
    local cart = { add = {}, remove = {} }
    for id in pairs(adds) do cart.add[#cart.add + 1] = id end
    for id in pairs(removes) do cart.remove[#cart.remove + 1] = id end
    if #cart.add + #cart.remove == 0 then
        return SendNUIMessage({ action = 'tattoo', event = 'payfail', msg = 'Ton panier est vide.' })
    end
    awaiting = true
    TriggerServerEvent('adminmenu:tattoo:pay', shop.id, cart, finalList(), d.method == 'bank' and 'bank' or 'cash')
    SetTimeout(10000, function()
        if awaiting and TattooOpen then
            awaiting = false
            SendNUIMessage({ action = 'tattoo', event = 'payfail', msg = 'Le serveur ne répond pas, réessaie.' })
        end
    end)
end)

-- ---------------------------------------------------------
--  Enregistrement
-- ---------------------------------------------------------
local function saveMode() return 'internal' end

RegisterNetEvent('adminmenu:tattoo:result', function(ok, msg)
    if not TattooOpen then return end
    awaiting = false
    if not ok then return SendNUIMessage({ action = 'tattoo', event = 'payfail', msg = msg or 'Paiement refusé.' }) end
    preview = nil
    redress()
    apply()
    SavedTattoos = finalList()
    TriggerEvent('adminmenu:tattoo:applied', finalList())
    SendNUIMessage({ action = 'tattoo', event = 'paid', msg = msg })
    SetTimeout(900, function() adds, removes = {}, {} close(false) end)
    Notify(msg or 'Tatouages enregistrés !', 'success')
end)

-- ---------------------------------------------------------
--  Mode interne : tatouages remis à chaque spawn
-- ---------------------------------------------------------
SavedTattoos = nil
local function reapply()
    if saveMode() ~= 'internal' or type(SavedTattoos) ~= 'table' then return end
    for _, ms in ipairs({ 500, 3000, 8000 }) do
        SetTimeout(ms, function()
            if TattooOpen then return end
            local p = PlayerPedId()
            local have = {}
            for _, d in ipairs(readDecorations(p)) do have[d[2]] = true end
            for _, d in ipairs(SavedTattoos) do
                if not have[d[2]] then AddPedDecorationFromHashes(p, d[1], d[2]) end
            end
        end)
    end
end
RegisterNetEvent('adminmenu:tattoo:saved', function(list) SavedTattoos = list reapply() end)
local function request()
    if saveMode() ~= 'internal' then return end
    SetTimeout(2000, function() TriggerServerEvent('adminmenu:tattoo:getSaved') end)
end
RegisterNetEvent('elyzea:client:playerLoaded', request)
AddEventHandler('ely_creator:loaded', reapply)
AddEventHandler('ely_creator:created', reapply)
AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() and NetworkIsPlayerActive(PlayerId()) then request() end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and TattooOpen then close(true) end
end)

exports('IsTattooOpen', function() return TattooOpen end)
