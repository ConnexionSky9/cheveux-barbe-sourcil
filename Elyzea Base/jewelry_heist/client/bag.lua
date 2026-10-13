-- =====================================================================
--  JEWELRY HEIST - client : sac (au sol, porté, dépôt avec E)
--  · Sacs au sol : objets LOCAUX créés par chaque joueur à partir de GlobalState.jhBags
--    (positions seulement : le contenu reste sur le serveur).
--  · Sac porté : état du joueur « jhBag » (Player(id).state). Mode « prop » : chaque client
--    attache un objet local au dos du porteur (visible à pied et en véhicule). Mode « component » :
--    le porteur met le sac de tenue GTA (composant 5), synchronisé par le jeu.
--  · Le visuel ne crée ni ne copie jamais de contenu : seul le serveur déplace le sac.
-- =====================================================================
local C = JHC
local ground = {}       -- [id] = objet
C.BagByEntity = {}      -- [objet] = id
local worn = {}         -- [serverId] = { obj, ped }
local savedComp = nil   -- composant d'origine du joueur (mode component)

local function bagHash() local cfg = C.Cfg() return cfg and C.LoadModel(cfg.bag.model) end

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
    C.BagByEntity[obj] = id
    return obj
end
local function removeGround(id)
    local o = ground[id]
    if o and DoesEntityExist(o) then C.BagByEntity[o] = nil DeleteEntity(o) end
    ground[id] = nil
end

CreateThread(function()
    while true do
        local list = GlobalState.jhBags or {}
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

-- Sac au sol le plus proche (pour le menu ALT)
function C.NearestBag(maxDist)
    local cfg = C.Cfg()
    local pc = GetEntityCoords(PlayerPedId())
    local best, bestD, bestObj
    for id, b in pairs(GlobalState.jhBags or {}) do
        local d = #(pc - vector3(b.x, b.y, b.z))
        if d <= (maxDist or (cfg and cfg.bag.pickupDistance) or 2.0) and (not bestD or d < bestD) then best, bestD, bestObj = id, d, ground[id] end
    end
    return best, bestObj
end

-- ---------------------------------------------------------------------
-- Sac porté : visuel
-- ---------------------------------------------------------------------
local function attachTo(ped)
    local cfg = C.Cfg()
    local hash = bagHash()
    if not hash then return nil end
    local p = GetEntityCoords(ped)
    local obj = CreateObject(hash, p.x, p.y, p.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityCollision(obj, false, false)
    local o, r = cfg.bag.offset, cfg.bag.rotation
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, cfg.bag.bone), o.x + 0.0, o.y + 0.0, o.z + 0.0, r.x + 0.0, r.y + 0.0, r.z + 0.0, true, true, false, true, 1, true)
    return obj
end
local function unwear(sid)
    local w = worn[sid]
    if w and DoesEntityExist(w.obj) then DeleteEntity(w.obj) end
    worn[sid] = nil
end

local function isFreemode(ped)
    local m = GetEntityModel(ped)
    return m == joaat('mp_m_freemode_01') or m == joaat('mp_f_freemode_01'), m == joaat('mp_f_freemode_01')
end
local function setComponent(on)
    local cfg = C.Cfg()
    local ped = PlayerPedId()
    local fm, female = isFreemode(ped)
    if not fm then return false end
    if on then
        if not savedComp then savedComp = { GetPedDrawableVariation(ped, 5), GetPedTextureVariation(ped, 5) } end
        local c = female and cfg.bag.component.female or cfg.bag.component.male
        if GetPedDrawableVariation(ped, 5) ~= c.drawable then SetPedComponentVariation(ped, 5, c.drawable, c.texture, 0) end
    elseif savedComp then
        SetPedComponentVariation(ped, 5, savedComp[1], savedComp[2], 0)
        savedComp = nil
    end
    return true
end

CreateThread(function()
    while true do
        local cfg = C.Cfg()
        if cfg then
            local seen = {}
            local myId = GetPlayerServerId(PlayerId())
            for _, pid in ipairs(GetActivePlayers()) do
                local sid = GetPlayerServerId(pid)
                local ped = GetPlayerPed(pid)
                local has = Player(sid).state.jhBag
                -- mode component : seul le porteur change sa tenue (synchronisée) ; repli « prop » hors personnage freemode
                local useProp = has and (cfg.bag.mode == 'prop' or not isFreemode(ped))
                if sid == myId and cfg.bag.mode == 'component' then setComponent(has ~= nil and not useProp) end
                if useProp then
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
            if not LocalPlayer.state.jhBag and savedComp then setComponent(false) end
        end
        Wait(500)
    end
end)

-- ---------------------------------------------------------------------
-- Actions : ramasser, déposer (E), ouvrir
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

function C.PickupBag(id)
    if busy then return end
    busy = true
    local cfg = C.Cfg()
    animOnce(cfg.anims.pickup)
    C.Show(C.Req('bagPickup', { bag = id }))
    busy = false
end

function C.DropBag()
    if busy or not LocalPlayer.state.jhBag then return end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return C.Notify(JH.T('bag_vehicle'), 'error') end
    busy = true
    animOnce(C.Cfg().bag.dropAnim)
    C.Show(C.Req('bagDrop'))
    busy = false
end

function C.OpenBag(id)
    local r = C.Req('bagOpen', { bag = id })
    if not C.Show(r) then return end
    C.OpenUI('bag', r.bag)
end

-- Touche de dépôt (E par défaut) et rappel à l'écran
CreateThread(function()
    while true do
        local sleep = 500
        local cfg = C.Cfg()
        -- jhNoDrop : posé par une autre ressource (ex. point de dépôt de bank_heist, où E sert à encaisser)
        if cfg and LocalPlayer.state.jhBag and not C.ui and not busy and not LocalPlayer.state.jhNoDrop then
            local ped = PlayerPedId()
            if not IsPedInAnyVehicle(ped, false) and not IsEntityDead(ped) then
                sleep = 0
                C.Help(cfg.general.dropKey == 38 and '~INPUT_CONTEXT~ Déposer le sac' or ('[%s] Déposer le sac'):format(cfg.general.dropKeyLabel))
                if IsControlJustReleased(0, cfg.general.dropKey) then CreateThread(C.DropBag) end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(ground) do removeGround(id) end
    for sid in pairs(worn) do unwear(sid) end
    if savedComp then setComponent(false) end
end)
