-- =====================================================================
--  ELYZEA MANUTENTION - FENWICK (client)
--  Pas de téléportation : le joueur glisse lui-même les fourches sous la palette.
--  [E] : les fourches descendent, la palette est accrochée là où elle est (même position, même angle),
--        puis fourches ET palette montent ensemble. On roule avec la palette.
--  [E] dans la zone de livraison : fourches et palette redescendent, la palette est posée au sol,
--        le serveur vérifie la position de la palette ELLE-MÊME avant de payer.
--  [G] hors zone : reposer la palette ici (pour se repositionner).
-- =====================================================================
local KEY_E, KEY_G = 38, 47
local lift = { attached = false, offset = nil, rot = nil, raise = 0.0, pending = false }
local RAISE = 0.42           -- hauteur de transport de la palette (m)
local FORK_UP = 0.16         -- hauteur des fourches correspondante (0 = en bas, 1 = tout en haut)

function MyForklift()
    local m = Mission
    if not m or not m.vehNet or not NetworkDoesNetworkIdExist(m.vehNet) then return nil end
    local veh = NetToVeh(m.vehNet)
    if veh and veh ~= 0 and DoesEntityExist(veh) then return veh end
end

local function setForks(veh, h)
    if type(SetForkliftForkHeight) == 'function' then SetForkliftForkHeight(veh, h + 0.0) end
end

local function control(ent)
    if NetworkHasControlOfEntity(ent) then return true end
    NetworkRequestControlOfEntity(ent)
    local t = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(ent) and GetGameTimer() < t do Wait(0) NetworkRequestControlOfEntity(ent) end
    return NetworkHasControlOfEntity(ent)
end

-- La palette est-elle bien devant, entre les fourches, dans le même axe ?
local function palletAligned(veh, pal)
    local pc = GetEntityCoords(pal)
    local off = GetOffsetFromEntityGivenWorldCoords(veh, pc.x, pc.y, pc.z)
    local _, vmax = GetModelDimensions(GetEntityModel(veh))
    local front = vmax.y
    -- palette « 4 entrées » : les fourches entrent de face, de dos ou par les côtés (écart à un multiple de 90° < 25°)
    local dh = math.abs(((GetEntityHeading(veh) - GetEntityHeading(pal)) + 45.0) % 90.0 - 45.0)
    local ok = math.abs(off.x) < 0.75 and off.y > front - 0.6 and off.y < front + 1.6 and math.abs(off.z) < 1.4 and dh < 25.0
    return ok, off, dh
end

local function attachKeepingPlace(veh, pal)
    local pc = GetEntityCoords(pal)
    local off = GetOffsetFromEntityGivenWorldCoords(veh, pc.x, pc.y, pc.z)
    local rot = GetEntityHeading(pal) - GetEntityHeading(veh)
    FreezeEntityPosition(pal, false)
    AttachEntityToEntity(pal, veh, 0, off.x, off.y, off.z, 0.0, 0.0, rot, false, false, true, false, 2, true)
    lift.attached, lift.offset, lift.rot, lift.raise = true, off, rot, 0.0
end

local function moveLoad(veh, pal, from, to, forksFrom, forksTo, ms)
    local steps = math.max(1, math.floor(ms / 16))
    for i = 1, steps do
        local k = i / steps
        lift.raise = from + (to - from) * k
        setForks(veh, forksFrom + (forksTo - forksFrom) * k)
        if DoesEntityExist(pal) and lift.offset then
            AttachEntityToEntity(pal, veh, 0, lift.offset.x, lift.offset.y, lift.offset.z + lift.raise, 0.0, 0.0, lift.rot, false, false, true, false, 2, true)
        end
        Wait(16)
    end
end

-- Pose la palette au sol à l'endroit où elle est (fourches qui redescendent)
local function setDown(veh, pal)
    if not (pal and DoesEntityExist(pal)) then lift.attached = false return end
    control(pal)
    moveLoad(veh, pal, lift.raise, 0.0, FORK_UP, 0.0, 700)
    DetachEntity(pal, true, false)
    PlaceObjectOnGroundProperly(pal)
    FreezeEntityPosition(pal, true)
    lift.attached, lift.offset, lift.rot, lift.raise = false, nil, nil, 0.0
end

function ForkliftReset()
    lift.attached, lift.offset, lift.rot, lift.raise, lift.pending = false, nil, nil, 0.0, false
end

-- Appelé à chaque image pendant les étapes « chargement » et « transport » : renvoie le texte d'aide
function ForkliftTick(c)
    local m = Mission
    if lift.pending then return '…' end
    local veh = MyForklift()
    local ped = PlayerPedId()
    if not veh then return nil end
    local driving = GetVehiclePedIsIn(ped, false) == veh and GetPedInVehicleSeat(veh, -1) == ped
    local pal = Work.pallet
    if m.stage == 'ready' then
        if not (pal and DoesEntityExist(pal)) then return nil end
        local d = #(c - GetEntityCoords(pal))
        if d > 30.0 then return nil end
        if not driving then return d < 8.0 and 'Monte sur ton Fenwick pour charger la palette' or nil end
        local ok = palletAligned(veh, pal)
        DrawMarker(0, GetEntityCoords(pal) + vector3(0.0, 0.0, 1.6), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.4, 0.4, 0.4,
            ok and 62 or 255, ok and 230 or 181, ok and 176 or 71, 180, true, true, 2, false, nil, nil, false)
        if not ok then return 'Avance les fourches sous la palette, bien dans l\'axe' end
        if IsControlJustReleased(0, KEY_E) then
            lift.pending = true
            CreateThread(function()
                setForks(veh, 0.0)
                Wait(400)
                if not control(pal) then lift.pending = false MNotify('Palette indisponible, réessaie.', 'error') return end
                attachKeepingPlace(veh, pal)
                MAction('lift')
            end)
        end
        return '[E] Charger la palette'
    elseif m.stage == 'carry' then
        if not driving then return nil end
        if pal and DoesEntityExist(pal) and not lift.attached then
            -- reconnexion de l'état (palette chargée mais plus accrochée chez nous) : on la ré-accroche sur place
            if #(GetEntityCoords(pal) - GetEntityCoords(veh)) < 5.0 and control(pal) then attachKeepingPlace(veh, pal) lift.raise = RAISE end
        end
        local dz = m.delivery
        local inZone = dz and #(vector2(c.x, c.y) - vector2(dz.x, dz.y)) < (dz.radius or Config.DeliveryRadius) + 2.5
        if IsControlJustReleased(0, KEY_E) and inZone then
            lift.pending = true
            CreateThread(function()
                setDown(veh, pal)
                Wait(150)
                MAction('deliver')
            end)
        elseif IsControlJustReleased(0, KEY_G) and not inZone then
            lift.pending = true
            CreateThread(function()
                setDown(veh, pal)
                MAction('unload')
            end)
        end
        return inZone and '[E] Déposer la palette (livraison)' or '[G] Reposer la palette ici'
    end
end

-- ---------------------------------------------------------------- réponses du serveur
function ForkliftLiftResult(ok, msg)
    local veh, pal = MyForklift(), Work.pallet
    if ok and veh and pal then
        CreateThread(function()
            moveLoad(veh, pal, 0.0, RAISE, 0.0, FORK_UP, 900)
            lift.pending = false
            MNotify('Palette chargée : conduis-la jusqu\'à la zone de livraison.', 'success')
        end)
    else
        -- refusé : la palette reste exactement où elle était
        if pal and DoesEntityExist(pal) and lift.attached then
            DetachEntity(pal, true, false) PlaceObjectOnGroundProperly(pal) FreezeEntityPosition(pal, true)
        end
        lift.attached, lift.pending = false, false
        MNotify(msg or 'Impossible de charger la palette.', 'error')
    end
end

function ForkliftDeliverResult(ok, msg, extra)
    lift.pending = false
    if ok then
        -- la palette livrée disparaît (le serveur la supprime aussi), une nouvelle palette est préparée
        for _, o in ipairs(Work.stacked) do if DoesEntityExist(o) then DeleteEntity(o) end end
        if Work.pallet and DoesEntityExist(Work.pallet) then DeleteEntity(Work.pallet) end
        Work.stacked, Work.pallet = {}, nil
        ForkliftReset()
        local amount = extra and extra.amount or 0
        MNotify(('Livraison validée : %d $ reçus.'):format(amount), 'success', 'PAIEMENT')
        SendNUIMessage({ action = 'banner', data = { title = 'LIVRAISON TERMINÉE !', kind = 'ok',
            text = ('Vous avez livré une palette contenant %d cartons.\nVous avez reçu : %d $'):format(extra and extra.boxes or 0, amount) } })
    else
        -- pas dans la zone : la palette reste posée là, on peut la recharger
        MNotify(msg or 'Livraison refusée.', 'error')
        MAction('unload')
    end
end

function ForkliftUnloadResult(ok, msg)
    lift.pending = false
    if ok then MNotify('Palette posée. Recharge-la quand tu es bien placé.', 'inform') elseif msg then MNotify(msg, 'error') end
end

-- Notification à l'arrivée dans la zone de livraison
CreateThread(function()
    local wasIn = false
    while true do
        Wait(700)
        local m = Mission
        if m and m.stage == 'carry' and m.delivery then
            local c = GetEntityCoords(PlayerPedId())
            local inZone = #(vector2(c.x, c.y) - vector2(m.delivery.x, m.delivery.y)) < (m.delivery.radius or Config.DeliveryRadius) + 2.5
            if inZone and not wasIn then MNotify('Zone de livraison atteinte : appuie sur E pour déposer la palette.', 'inform') end
            wasIn = inZone
        else wasIn = false end
    end
end)
