-- =====================================================================
--  ELYZEA DROGUES · monde (client)
--  Installations du staff (postes, points de récolte, PNJ acheteurs / fournisseurs) et pots des joueurs.
--  Objets et PNJ LOCAUX créés seulement à moins de 80 m, supprimés au-delà de 100 m (pas de réseau).
--  DrugWorld.byEnt[entité] = { kind = 'site' | 'plant', id } : utilisé par le ALT (client/alt.lua).
-- =====================================================================
DrugWorld = { sites = {}, plants = {}, ents = {}, byEnt = {}, nodeHidden = {}, chairs = {} }
local W = DrugWorld
local SPAWN, DESPAWN = 80.0, 100.0

local function loadModel(model)
    local h = type(model) == 'number' and model or GetHashKey(model or '')
    if not IsModelInCdimage(h) then return nil end
    RequestModel(h)
    local t = GetGameTimer() + 4000
    while not HasModelLoaded(h) and GetGameTimer() < t do Wait(0) end
    return HasModelLoaded(h) and h or nil
end
W.LoadModel = loadModel

local function obj(model, x, y, z, h, rx, ry, ground)
    local hash = loadModel(model)
    if not hash then return nil end
    local o = CreateObjectNoOffset(hash, x, y, z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not o or o == 0 then return nil end
    SetEntityRotation(o, rx or 0.0, ry or 0.0, h or 0.0, 2, true)
    if ground then PlaceObjectOnGroundProperly(o) end
    FreezeEntityPosition(o, true)
    SetEntityInvincible(o, true)
    return o
end

local function npc(model, x, y, z, h, scenario)
    local hash = loadModel(model)
    if not hash then return nil end
    local p = CreatePed(4, hash, x, y, z, h or 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not p or p == 0 then return nil end
    SetEntityCoordsNoOffset(p, x, y, z, false, false, false)   -- même convention que l'éditeur de map
    SetEntityHeading(p, h or 0.0)
    SetEntityInvincible(p, true)
    FreezeEntityPosition(p, true)
    SetBlockingOfNonTemporaryEvents(p, true)
    SetPedFleeAttributes(p, 0, false)
    SetPedCanRagdoll(p, false)
    if scenario then TaskStartScenarioInPlace(p, scenario, 0, true) end
    return p
end

-- Le chargement d'un modèle rend la main : si l'élément a été retiré entre-temps, l'objet créé est supprimé
local function orphan(key, list, ent)
    if W.ents[key] == list then return false end
    if ent and DoesEntityExist(ent) then DeleteEntity(ent) end
    return true
end

local function despawn(key)
    local e = W.ents[key]
    if not e then return end
    for _, ent in ipairs(e) do
        W.byEnt[ent] = nil
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    W.ents[key] = nil
    local sid = tonumber(key:match('^site:(%d+)$') or '')
    if sid then W.chairs[sid] = nil end
end

-- ---------------------------------------------------------------- installations du staff
local function spawnSite(s)
    local key = 'site:' .. s.id
    if W.ents[key] then return end
    local list = {}
    W.ents[key] = list   -- réservé tout de suite (pas de double apparition pendant le chargement)
    local ent
    if Config.NpcSites[s.type] then
        ent = npc(s.model, s.x, s.y, s.z, s.h, Config.NpcSites[s.type].scenario)
    else
        ent = obj(s.model, s.x, s.y, s.z, s.h, s.rx, s.ry, false)
    end
    if orphan(key, list, ent) then return end
    if not ent then W.ents[key] = nil return end
    list[1] = ent
    W.byEnt[ent] = { kind = 'site', id = s.id }
    -- décor permanent du poste (accessoires, chaise) : objets locaux, l'ALT sur eux vise le poste
    local decor = Config.Decor and Config.Decor[s.type]
    if decor then
        for _, spec in ipairs(decor.props or {}) do
            local o = DrugScene.Place(ent, spec, false)
            if orphan(key, list, o) then return end
            if o then list[#list + 1] = o W.byEnt[o] = { kind = 'site', id = s.id } end
        end
        if decor.seat then
            local c = DrugScene.PlaceChair(ent)
            if orphan(key, list, c) then return end
            if c then list[#list + 1] = c W.byEnt[c] = { kind = 'site', id = s.id } W.chairs[s.id] = c end
        end
    end
end
-- Entité principale d'un poste (la première créée) et sa chaise éventuelle
function W.StationEntity(id) local l = W.ents['site:' .. id] return l and l[1] or nil end
function W.Chair(id) local c = W.chairs[id] return c and DoesEntityExist(c) and c or nil end

RegisterNetEvent('elyzea_drogues:sites', function(list, nodes)
    local new = {}
    for _, s in ipairs(list or {}) do new[s.id] = s end
    for id, old in pairs(W.sites) do
        local s = new[id]
        if not s or s.model ~= old.model or s.x ~= old.x or s.y ~= old.y or s.z ~= old.z or s.h ~= old.h or s.rx ~= old.rx or s.ry ~= old.ry then despawn('site:' .. id) end
    end
    W.sites = new
    W.nodeHidden = {}
    for id, left in pairs(nodes or {}) do W.nodeHidden[tonumber(id)] = GetGameTimer() + left * 1000 end
end)

-- Point de récolte vidé : disparaît jusqu'à la repousse
RegisterNetEvent('elyzea_drogues:node', function(id, seconds)
    W.nodeHidden[id] = GetGameTimer() + (seconds or 0) * 1000
    despawn('site:' .. id)
end)

-- ---------------------------------------------------------------- pots et plantes des joueurs
local function plantModel(p)
    if not p.v then return nil end
    local st = Config.Culture.stages[math.max(1, p.st or 1)]
    return st and st.model
end

local function spawnPlant(p)
    local key = 'plant:' .. p.id
    if W.ents[key] then return end
    local list = {}
    W.ents[key] = list
    local pot = obj(Config.Culture.potModel, p.x, p.y, p.z, p.h, 0.0, 0.0, true)
    if orphan(key, list, pot) then return end
    if not pot then W.ents[key] = nil return end
    list[#list + 1] = pot
    W.byEnt[pot] = { kind = 'plant', id = p.id }
    local _, mx = GetModelDimensions(GetEntityModel(pot))
    local pc = GetEntityCoords(pot)
    local model = plantModel(p)
    if model then
        local pl = obj(model, pc.x, pc.y, pc.z + (mx.z * 0.55), p.h, 0.0, 0.0, false)
        if orphan(key, list, pl) then return end
        if pl then
            if p.dead then SetEntityAlpha(pl, 140, false) end
            SetEntityCollision(pl, false, false)
            list[#list + 1] = pl
            W.byEnt[pl] = { kind = 'plant', id = p.id }
        end
    end
    if p.lamp then
        local o = Config.Culture.lampOffset
        local rad = math.rad(p.h or 0.0)
        local lx = pc.x + o.x * math.cos(rad) - o.y * math.sin(rad)
        local ly = pc.y + o.x * math.sin(rad) + o.y * math.cos(rad)
        local lamp = obj(Config.Culture.lampModel, lx, ly, pc.z, (p.h or 0.0) + 180.0, 0.0, 0.0, true)
        if orphan(key, list, lamp) then return end
        if lamp then list[#list + 1] = lamp W.byEnt[lamp] = { kind = 'plant', id = p.id } end
    end
    W.plantKey = W.plantKey or {}
    W.plantKey[p.id] = ('%s:%s:%s:%s'):format(tostring(p.v), tostring(p.st), tostring(p.lamp), tostring(p.dead))
end

RegisterNetEvent('elyzea_drogues:plants', function(list)
    for id in pairs(W.plants) do despawn('plant:' .. id) end
    W.plants = {}
    for _, p in ipairs(list or {}) do W.plants[p.id] = p end
end)
RegisterNetEvent('elyzea_drogues:plant', function(id, p)
    local old = W.plants[id]
    W.plants[id] = p
    if not p then despawn('plant:' .. id) return end
    local key = ('%s:%s:%s:%s'):format(tostring(p.v), tostring(p.st), tostring(p.lamp), tostring(p.dead))
    if old and W.plantKey and W.plantKey[id] ~= key then despawn('plant:' .. id) end
end)

-- ---------------------------------------------------------------- boucle d'apparition (toutes les 1,5 s)
CreateThread(function()
    Wait(2500)
    TriggerServerEvent('elyzea_drogues:requestAll')
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local now = GetGameTimer()
        for id, s in pairs(W.sites) do
            local d = #(pos - vector3(s.x, s.y, s.z))
            local hidden = (W.nodeHidden[id] or 0) > now
            if d < SPAWN and not hidden and not W.ents['site:' .. id] then spawnSite(s)
            elseif (d > DESPAWN or hidden) and W.ents['site:' .. id] then despawn('site:' .. id) end
        end
        for id, p in pairs(W.plants) do
            local d = #(pos - vector3(p.x, p.y, p.z))
            if d < SPAWN and not W.ents['plant:' .. id] then spawnPlant(p)
            elseif d > DESPAWN and W.ents['plant:' .. id] then despawn('plant:' .. id) end
        end
        Wait(1500)
    end
end)

-- Lueur de la couleur de la variété sous la lampe de culture (plantes proches seulement)
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local near = {}
        for _, p in pairs(W.plants) do
            if p.v and p.lamp and not p.dead and #(pos - vector3(p.x, p.y, p.z)) < 25.0 then near[#near + 1] = p end
        end
        if #near == 0 then Wait(1500) else
            local vs = DrugFx.settings and DrugFx.settings.varieties or {}
            for _ = 1, 60 do
                for _, p in ipairs(near) do
                    local c = (vs[p.v] or {}).color or { 120, 255, 120 }
                    DrawLightWithRange(p.x, p.y, p.z + 1.3, c[1], c[2], c[3], 2.2, 1.6)
                end
                Wait(0)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for key in pairs(W.ents) do despawn(key) end
end)
