-- =====================================================================
--  ELYZEA EMS - client : MedicalBag (sac médical) + cibles ALT propres à l'EMS
--  Utiliser l'objet : le sac est posé au sol devant soi (le serveur valide).
--  ALT sur le sac : « Ouvrir le sac » / « Ramasser le sac » (EMS en service).
--  Les exports AltTarget / AltNearby (appelés par elyzea_police/client/alt.lua)
--  servent au brancard ET au sac.
-- =====================================================================
local C = EmsC
local MB = Config.MedicalBag or {}

local function List() local g = GlobalState.emsMedbags return type(g) == 'table' and g or {} end
local function Ent(net)
    net = tonumber(net)
    if net and NetworkDoesNetworkIdExist(net) then
        local e = NetworkGetEntityFromNetworkId(net)
        if e and e ~= 0 and DoesEntityExist(e) then return e end
    end
    return nil
end
local function OfEntity(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) or not NetworkGetEntityIsNetworked(ent) then return nil end
    local net = NetworkGetNetworkIdFromEntity(ent)
    for _, b in ipairs(List()) do if b.net == net then return b end end
    return nil
end
local function Usable() return MB.enabled ~= false and C.OnDuty() end

local function Model()
    for _, m in ipairs(MB.models or {}) do
        local h = type(m) == 'number' and m or GetHashKey(m)
        if IsModelInCdimage(h) then
            RequestModel(h)
            local t = GetGameTimer() + 5000
            while not HasModelLoaded(h) and GetGameTimer() < t do Wait(10) end
            if HasModelLoaded(h) then return h end
        end
    end
    return nil
end

local function Crouch()
    local ped = PlayerPedId()
    if C.LoadDict('pickup_object') then
        TaskPlayAnim(ped, 'pickup_object', 'pickup_low', 8.0, -8.0, 900, 48, 0, false, false, false)
        Wait(700)
    end
end

-- Poser le sac au sol devant soi
RegisterNetEvent('ems:client:medbagPlace', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or C.IsDown() then return C.Notify('Impossible ici.', 'error') end
    local h = Model()
    if not h then return C.Notify('MedicalBag indisponible (modèle introuvable).', 'error') end
    Crouch()
    local c = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.6, 0.0)
    local obj = CreateObject(h, c.x, c.y, c.z, true, true, false)
    SetModelAsNoLongerNeeded(h)
    if not obj or obj == 0 then return C.Notify('Impossible de poser le sac.', 'error') end
    SetEntityHeading(obj, GetEntityHeading(ped))
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    local net = NetworkGetNetworkIdFromEntity(obj)
    SetNetworkIdExistsOnAllMachines(net, true)
    local r = C.Do('medbagRegister', { net = net })
    if not r or not r.ok then
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
end)

-- Options ALT sur le sac visé
function C.BagExtOptions(ent, out)
    local b = OfEntity(ent)
    if not b or not Usable() then return false end
    out[#out + 1] = { id = 'bag_open', label = 'Ouvrir le sac', icon = 'examine', desc = 'Objets EMS à prendre' }
    out[#out + 1] = { id = 'bag_pick', label = 'Ramasser le sac', icon = 'in' }
    return true
end

function C.BagSelect(id, ctx)
    id = tostring(id or '')
    if id ~= 'bag_open' and id ~= 'bag_pick' then return false end
    local b = ctx and ctx.kind == 'ext' and OfEntity(ctx.entity)
    if not b then C.Notify('Sac introuvable.', 'error') return true end
    CreateThread(function()
        if id == 'bag_open' then
            Crouch()
            local r = C.Req('medbagOpen', { net = b.net })
            if r.error then C.Notify(r.error, 'error') end
        else
            Crouch()
            C.Do('medbagPickup', { net = b.net })
        end
    end)
    return true
end

local function NearestBag(maxD)
    local me = GetEntityCoords(PlayerPedId())
    local best, bestD
    for _, b in ipairs(List()) do
        local e = Ent(b.net)
        if e then
            local d = #(GetEntityCoords(e) - me)
            if d <= maxD and (not bestD or d < bestD) then best, bestD = e, d end
        end
    end
    return best
end

-- ---------------------------------------------------------------------
-- Cibles ALT de l'EMS (brancard : client/stretcher.lua, sac : ici)
-- ---------------------------------------------------------------------
exports('AltTarget', function(ent)
    if C.StretcherAltTarget then
        local t = C.StretcherAltTarget(ent)
        if t then return t end
    end
    if Usable() and OfEntity(ent) then return 'MedicalBag' end
    return nil
end)

exports('AltNearby', function()
    local se, st
    if C.StretcherAltNearby then se, st = C.StretcherAltNearby() end
    if not Usable() then return se, st end
    local be = NearestBag(MB.reach or 2.5)
    if se and be then
        local me = GetEntityCoords(PlayerPedId())
        if #(GetEntityCoords(be) - me) < #(GetEntityCoords(se) - me) then return be, 'MedicalBag' end
        return se, st
    end
    if be then return be, 'MedicalBag' end
    return se, st
end)
