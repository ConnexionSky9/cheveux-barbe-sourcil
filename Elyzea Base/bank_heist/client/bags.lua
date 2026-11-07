-- =====================================================================
--  BANK HEIST - client : sac de billets (au sol, porté, poser avec E), propre à la banque
--  · Sacs au sol : objets LOCAUX créés par chaque joueur à partir de GlobalState.bhBags
--    (positions seulement : l'argent reste sur le serveur).
--  · Sac porté : état du joueur « bhBag ». Chaque client attache un objet local au dos du porteur.
--  · Le visuel ne crée ni ne copie jamais d'argent : seul le serveur déplace le sac.
-- =====================================================================
local C = BHC
local CFG = Config.Bag or {}
local ground = {}       -- [id] = objet
C.BankBagByEntity = {}  -- [objet] = id
local worn = {}         -- [serverId] = { obj, ped }

local function bagHash() return C.LoadModel(CFG.model or 'prop_cs_heist_bag_02') end

-- ---------------------------------------------------------------------
-- Sacs au sol
-- ---------------------------------------------------------------------
local function spawnGround(id, b)
    local hash = bagHash()
    if not hash then return nil end
    local z = b.z + 0.0
    local ok, gz = GetGroundZFor_3dCoord(b.x + 0.0, b.y + 0.0, z + 0.5, false)
    if ok and math.abs(gz - z) < 3.0 then z = gz end
    local obj = CreateObject(hash, b.x + 0.0, b.y + 0.0, z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false)
    C.BankBagByEntity[obj] = id
    return obj
end
local function removeGround(id)
    local o = ground[id]
    if o and DoesEntityExist(o) then C.BankBagByEntity[o] = nil DeleteEntity(o) end
    ground[id] = nil
end

CreateThread(function()
    while true do
        local list = GlobalState.bhBags or {}
        local pc = GetEntityCoords(PlayerPedId())
        for id in pairs(ground) do if not list[id] then removeGround(id) end end
        for id, b in pairs(list) do
            local d = #(pc - vector3(b.x, b.y, b.z))
            if d < 80.0 and (not ground[id] or not DoesEntityExist(ground[id])) then ground[id] = spawnGround(id, b)
            elseif d > 95.0 and ground[id] then removeGround(id) end
        end
        Wait(1000)
    end
end)

-- Sac au sol le plus proche (menu ALT)
function C.NearestBankBag(maxDist)
    local pc = GetEntityCoords(PlayerPedId())
    local best, bestD
    for id, b in pairs(GlobalState.bhBags or {}) do
        local d = #(pc - vector3(b.x, b.y, b.z))
        if d <= (maxDist or CFG.pickupDistance or 2.0) and (not bestD or d < bestD) then best, bestD = id, d end
    end
    return best, best and ground[best] or nil
end

-- ---------------------------------------------------------------------
-- Sac porté : visuel sur le dos de chaque porteur
-- ---------------------------------------------------------------------
local function attachTo(ped)
    local hash = bagHash()
    if not hash then return nil end
    local p = GetEntityCoords(ped)
    local obj = CreateObject(hash, p.x, p.y, p.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityCollision(obj, false, false)
    local o, r = CFG.offset or { x = -0.05, y = -0.22, z = 0.0 }, CFG.rotation or { x = 0.0, y = 90.0, z = 180.0 }
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, CFG.bone or 24818), o.x + 0.0, o.y + 0.0, o.z + 0.0, r.x + 0.0, r.y + 0.0, r.z + 0.0, true, true, false, true, 1, true)
    return obj
end
local function unwear(sid)
    local w = worn[sid]
    if w and DoesEntityExist(w.obj) then DeleteEntity(w.obj) end
    worn[sid] = nil
end

CreateThread(function()
    while true do
        local seen = {}
        for _, pid in ipairs(GetActivePlayers()) do
            local sid = GetPlayerServerId(pid)
            local ped = GetPlayerPed(pid)
            if Player(sid).state.bhBag then
                seen[sid] = true
                local w = worn[sid]
                if not w or not DoesEntityExist(w.obj) or w.ped ~= ped or not IsEntityAttachedToEntity(w.obj, ped) then
                    unwear(sid)
                    local obj = attachTo(ped)
                    if obj then worn[sid] = { obj = obj, ped = ped } end
                end
            end
        end
        for sid in pairs(worn) do if not seen[sid] then unwear(sid) end end
        Wait(500)
    end
end)

-- ---------------------------------------------------------------------
-- Actions : ramasser (ALT), poser (E)
-- ---------------------------------------------------------------------
local busy = false
local function animOnce(a)
    local ped = PlayerPedId()
    if a and C.LoadDict(a.dict) then
        TaskPlayAnim(ped, a.dict, a.name, 8.0, -8.0, a.time or 1000, 0, 0.0, false, false, false)
        Wait(a.time or 1000)
        ClearPedTasks(ped)
    else Wait(500) end
end

function C.PickupBankBag(id)
    if busy then return end
    busy = true
    animOnce(CFG.pickupAnim)
    C.Show(C.Req('bagPickup', { bag = id }))
    busy = false
end

function C.DropBankBag()
    if busy or not LocalPlayer.state.bhBag then return end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return C.Notify('Descendez du véhicule pour poser le sac.', 'error') end
    busy = true
    animOnce(CFG.dropAnim)
    C.Show(C.Req('bagDrop'))
    busy = false
end

-- Touche pour poser le sac (E par défaut). bhNoDrop : E sert à autre chose ici (dépôt, guichet…)
CreateThread(function()
    local key = CFG.dropKey or 38
    while true do
        local sleep = 500
        if LocalPlayer.state.bhBag and not C.ui and not busy and not LocalPlayer.state.bhNoDrop then
            local ped = PlayerPedId()
            if not IsPedInAnyVehicle(ped, false) and not IsEntityDead(ped) then
                sleep = 0
                C.Help(key == 38 and '~INPUT_CONTEXT~ Poser le sac de billets' or 'Touche de dépôt : poser le sac de billets')
                if IsControlJustReleased(0, key) then CreateThread(C.DropBankBag) end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(ground) do removeGround(id) end
    for sid in pairs(worn) do unwear(sid) end
end)
