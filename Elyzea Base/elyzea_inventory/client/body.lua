-- ELYZEA FA — Inventaire : armes visibles sur le personnage (client)
-- Le serveur partage la liste des armes portées par chaque joueur (state bag « elyBodyWeapons »).
-- Chaque client dessine ces armes sur les joueurs proches : objets locaux attachés aux os du personnage.
--   dos      : fusils, mitraillettes, fusils à pompe, fusils de précision, armes lourdes (une seule)
--   ceinture : pistolet glissé à l'arrière du pantalon (un seul)
-- Le joueur choisit dans l'inventaire : clic droit › Mettre dans le dos / à la ceinture.

local C = Config.BodyWeapons
if not C or not C.enabled then return end

local function u32(n)
    n = tonumber(n) or 0
    if n < 0 then n = n + 4294967296 end
    return n
end

-- Groupe d'arme du jeu -> emplacement, priorité (la plus grosse arme va dans le dos)
local GROUPS = {
    [416676503]  = { 'waist', 1 },   -- pistolets
    [3337201093] = { 'back', 1 },    -- mitraillettes
    [860033945]  = { 'back', 2 },    -- fusils à pompe
    [970310034]  = { 'back', 3 },    -- fusils d'assaut
    [1159398588] = { 'back', 4 },    -- mitrailleuses
    [3082541095] = { 'back', 5 },    -- fusils de précision
    [2725924767] = { 'back', 6 },    -- armes lourdes
}

local Info = {}   -- [nom] = { place, prio, hash }
local function infoOf(name)
    local i = Info[name]
    if i then return i end
    local hash = joaat(name)
    local over = C.override and C.override[name:upper()]
    local g = GROUPS[u32(GetWeapontypeGroup(hash))]
    local place = g and g[1] or false
    if over ~= nil then place = over end
    i = { place = place, prio = g and g[2] or 0, hash = hash }
    Info[name] = i
    return i
end

-- Emplacement possible d'une arme : 'back', 'waist' ou nil (utilisé par le clic droit de l'inventaire)
function BodyPlace(name)
    if type(name) ~= 'string' then return nil end
    return infoOf(name).place or nil
end

-- Arme du dos et arme de ceinture choisies par le joueur (jamais celle tenue en main)
local function wanted(ped, list)
    local inHand = u32(GetSelectedPedWeapon(ped))
    local back, waist
    for _, w in ipairs(list) do
        if type(w) == 'table' and type(w.n) == 'string' then
            local i = infoOf(w.n)
            if u32(i.hash) ~= inHand and i.place == w.p then
                if w.p == 'back' and not back then back = i.hash
                elseif w.p == 'waist' and not waist then waist = i.hash end
            end
        end
    end
    return back, waist
end

local Failed = {}   -- modèles introuvables (armes ajoutées sans modèle, etc.)
local function spawnOn(ped, hash, spot)
    if Failed[hash] then return nil end
    local model = GetWeapontypeModel(hash)
    if not model or model == 0 or not IsModelInCdimage(model) then Failed[hash] = true return nil end
    if not HasModelLoaded(model) then
        RequestModel(model)
        local t = GetGameTimer() + 3000
        while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
        if not HasModelLoaded(model) then return nil end
    end
    local c = GetEntityCoords(ped)
    local obj = CreateObject(model, c.x, c.y, c.z - 5.0, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if not obj or obj == 0 then return nil end
    SetEntityCollision(obj, false, false)
    local p = C[spot]
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, p.bone), p.pos.x, p.pos.y, p.pos.z, p.rot.x, p.rot.y, p.rot.z,
        true, true, false, true, 2, true)
    return obj
end

local Spawned = {}   -- [id serveur] = { back = { hash, ped, obj }, waist = { … } }

local function remove(entry)
    if entry and entry.obj and DoesEntityExist(entry.obj) then DeleteEntity(entry.obj) end
end

local function update(sid, ped, spot, hash)
    local s = Spawned[sid]
    if not s then s = {} Spawned[sid] = s end
    local cur = s[spot]
    if cur and (cur.hash ~= hash or cur.ped ~= ped or not DoesEntityExist(cur.obj) or not IsEntityAttachedToEntity(cur.obj, ped)) then
        remove(cur)
        s[spot], cur = nil, nil
    end
    if hash and not cur then
        local obj = spawnOn(ped, hash, spot)
        if obj then s[spot] = { hash = hash, ped = ped, obj = obj } end
    end
end

local function clear(sid)
    local s = Spawned[sid]
    if not s then return end
    remove(s.back)
    remove(s.waist)
    Spawned[sid] = nil
end

CreateThread(function()
    while true do
        local myPos = GetEntityCoords(PlayerPedId())
        local present = {}
        for _, pl in ipairs(GetActivePlayers()) do
            local sid = GetPlayerServerId(pl)
            local ped = GetPlayerPed(pl)
            local list = Player(sid).state.elyBodyWeapons
            local back, waist
            if type(list) == 'table' and #list > 0 and ped ~= 0 and DoesEntityExist(ped) and IsEntityVisible(ped)
                and #(myPos - GetEntityCoords(ped)) <= C.distance
                and not (C.hideInVehicle and IsPedInAnyVehicle(ped, false)) then
                back, waist = wanted(ped, list)
            end
            present[sid] = true
            update(sid, ped, 'back', back)
            update(sid, ped, 'waist', waist)
        end
        for sid in pairs(Spawned) do if not present[sid] then clear(sid) end end
        Wait(250)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for sid in pairs(Spawned) do clear(sid) end
end)

-- Réglage des positions en jeu (visible seulement pour soi) :
--   /positionarme dos 0.075 -0.15 -0.02 0 165 0
--   /positionarme ceinture -0.08 -0.17 -0.06 0 95 180
-- La ligne à recopier dans config.lua s'affiche dans la console F8.
RegisterCommand('positionarme', function(_, args)
    local spot = ({ dos = 'back', back = 'back', ceinture = 'waist', waist = 'waist' })[tostring(args[1] or ''):lower()]
    local n = {}
    for i = 2, 7 do n[#n + 1] = tonumber(args[i]) end
    if not spot or #n ~= 6 then
        return print('Usage : /positionarme dos|ceinture x y z rx ry rz')
    end
    C[spot].pos = vec3(n[1], n[2], n[3])
    C[spot].rot = vec3(n[4], n[5], n[6])
    for sid in pairs(Spawned) do clear(sid) end
    print(('%s = { bone = %d, pos = vec3(%s, %s, %s), rot = vec3(%s, %s, %s) },'):format(spot, C[spot].bone, n[1], n[2], n[3], n[4], n[5], n[6]))
end, false)
