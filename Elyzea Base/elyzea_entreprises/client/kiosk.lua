-- =====================================================================
--  elyzea_entreprises - client : borne de commande (Burger Shot)
--  Clients : borne (E), récupération au comptoir, suivi en direct.
--  Employés : file des commandes, préparation devant le client
--  (animation, plateau et produits posés sur le comptoir).
-- =====================================================================
local C = ENTC
C.orders = {}       -- file des commandes (employés)
C.myOrders = {}     -- mes commandes (clients)
local kiosk = nil   -- { company, zone } borne ouverte
local working = nil -- préparation en cours

local DEFAULT_ANIM = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' }
-- Emplacements sur le plateau (gauche/droite, arrière/avant), puis autour
local SLOTS = {
    { -0.12, -0.06 }, { 0.0, -0.06 }, { 0.12, -0.06 }, { -0.12, 0.07 }, { 0.0, 0.07 }, { 0.12, 0.07 },
    { -0.26, 0.0 }, { 0.26, 0.0 }, { -0.26, 0.14 }, { 0.26, 0.14 },
}

local function Kiosk(c) return C.cfg[c] and C.cfg[c].kiosk end

-- ---------------------------------------------------------------------
-- Borne (clients)
-- ---------------------------------------------------------------------
local function CloseKiosk()
    if not kiosk then return end
    kiosk = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'kioskClose' })
end

RegisterNetEvent('ent:kioskData', function(data)
    if not kiosk or kiosk.company ~= data.company then return end
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'kiosk', data = data })
end)

RegisterNetEvent('ent:kioskOrdered', function(r)
    C.myOrders = r.mine or {}
    SendNUIMessage({ action = 'kioskOrdered', data = r })
end)

RegisterNetEvent('ent:myOrders', function(list)
    C.myOrders = type(list) == 'table' and list or {}
    SendNUIMessage({ action = 'myOrders', list = C.myOrders })
end)

RegisterNUICallback('kioskOrder', function(body, cb)
    cb('ok')
    if kiosk then TriggerServerEvent('ent:kioskOrder', kiosk.company, body.cart, body.method) end
end)
RegisterNUICallback('kioskCancel', function(body, cb)
    cb('ok')
    TriggerServerEvent('ent:kioskCancel', tonumber(body.id))
end)
RegisterNUICallback('kioskClose', function(_, cb) CloseKiosk() cb('ok') end)

-- ---------------------------------------------------------------------
-- File des commandes (employés)
-- ---------------------------------------------------------------------
RegisterNetEvent('ent:orders', function(list)
    C.orders = type(list) == 'table' and list or {}
    SendNUIMessage({ action = 'orders', list = C.orders })
end)

RegisterNetEvent('ent:newOrder', function(o)
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
    SendNUIMessage({ action = 'newOrder', data = o })
    C.Notify(('Nouvelle commande n°%s (%d article%s) pour %s.'):format(o.number, o.count, o.count > 1 and 's' or '', o.name), 'inform')
end)

-- Actions de la tablette (onglet Commandes) : renvoie true si traitée
function C.KioskAction(a, d)
    if a == 'orderStart' then
        C.CloseTablet()
        TriggerServerEvent('ent:orderStart', tonumber(d.id))
    elseif a == 'orderCancel' then
        TriggerServerEvent('ent:orderCancel', tonumber(d.id))
    elseif a == 'ordersRefresh' then
        TriggerServerEvent('ent:ordersData')
    else
        return false
    end
    return true
end

-- ---------------------------------------------------------------------
-- Préparation devant le client
-- ---------------------------------------------------------------------
local function Offset(base, heading, ox, oy, oz)
    local h = math.rad(heading)
    local right = vector3(math.cos(h), math.sin(h), 0.0)
    local fwd = vector3(-math.sin(h), math.cos(h), 0.0)
    return base + right * ox + fwd * oy + vector3(0.0, 0.0, oz or 0.0)
end

local function SpawnProp(model, pos, heading, fallback)
    local hash = type(model) == 'string' and joaat(model) or model
    if not hash or not IsModelInCdimage(hash) then
        if not fallback then return nil end
        hash = joaat(fallback)
        if not IsModelInCdimage(hash) then return nil end
    end
    local ok = pcall(Ely.requestModel, hash, 5000)
    if not ok then return nil end
    local obj = CreateObject(hash, pos.x, pos.y, pos.z, true, true, false)
    SetModelAsNoLongerNeeded(hash)
    if not obj or obj == 0 then return nil end
    SetEntityHeading(obj, heading + 0.0)
    SetEntityCollision(obj, false, false)
    FreezeEntityPosition(obj, true)
    return obj
end

local function DeleteList(list)
    for _, obj in ipairs(list or {}) do
        if DoesEntityExist(obj) then
            SetEntityAsMissionEntity(obj, true, true)
            DeleteEntity(obj)
        end
    end
end

RegisterNetEvent('ent:orderAssemble', function(p)
    if working then return end
    local c = C.Company()
    local k = Kiosk(c) or {}
    working = { id = p.id, aborted = false, props = {} }
    C.busy = true
    local ped = PlayerPedId()
    local z = p.zone
    local heading = (z.h or 0.0) + 0.0
    local base = Offset(vector3(z.x, z.y, z.z), heading, 0.0, k.trayForward or 0.55, k.trayHeight or -0.05)
    TaskTurnPedToFaceCoord(ped, base.x, base.y, base.z, 1200)
    Wait(900)

    local function Register(obj)
        if not obj then return end
        working.props[#working.props + 1] = obj
        local net = NetworkGetNetworkIdFromEntity(obj)
        if net and net ~= 0 then TriggerServerEvent('ent:orderProps', p.id, p.token, { net }) end
    end

    local tray = SpawnProp(k.trayModel or 'prop_food_bs_tray_01', base, heading, 'prop_food_tray_01')
    Register(tray)
    SendNUIMessage({ action = 'assemble', data = { number = p.number, name = p.name, steps = p.steps } })

    local ok = true
    for i, st in ipairs(p.steps) do
        if working.aborted then ok = false break end
        local duration = math.floor((tonumber(st.time) or 5) * 1000)
        SendNUIMessage({ action = 'assembleStep', index = i, duration = duration })
        local a = (k.anims or {})[st.category] or DEFAULT_ANIM
        local hasAnim = a.dict and a.dict ~= '' and DoesAnimDictExist(a.dict)
        local done = Ely.progressBar({
            duration = duration, label = ('%s (%d/%d)'):format(st.label, i, #p.steps), canCancel = true,
            disable = { move = true, car = true, combat = true },
            anim = hasAnim and { dict = a.dict, clip = a.clip, flag = 1 } or DEFAULT_ANIM,
        })
        if not done or working.aborted then ok = false break end
        local slot = SLOTS[((i - 1) % #SLOTS) + 1]
        local pos = tray and GetOffsetFromEntityInWorldCoords(tray, slot[1], slot[2], 0.03) or Offset(base, heading, slot[1], slot[2], 0.03)
        Register(SpawnProp(st.prop or 'prop_cs_burger_01', pos, heading, 'prop_cs_burger_01'))
        TriggerServerEvent('ent:orderStep', p.id, p.token, i)
    end
    ClearPedTasks(ped)
    SendNUIMessage({ action = 'assembleEnd', ok = ok })
    if not working.aborted then TriggerServerEvent('ent:orderDone', p.id, p.token, ok) end
    local props = working.props
    working = nil
    C.busy = false
    -- Le plateau reste quelques secondes sous les yeux du client
    SetTimeout(ok and 4000 or 0, function() DeleteList(props) end)
end)

RegisterNetEvent('ent:orderAbort', function()
    if not working then return end
    working.aborted = true
    pcall(function() exports.elyzea_core:CancelProgress() end)
    C.Notify('Le staff a annulé cette commande.', 'error')
end)

RegisterNetEvent('ent:orderHandOver', function()
    local ped = PlayerPedId()
    if pcall(Ely.requestAnimDict, 'mp_common', 3000) then
        TaskPlayAnim(ped, 'mp_common', 'givetake1_a', 8.0, -8.0, 1500, 48, 0.0, false, false, false)
    end
end)

-- Suivi en direct pour le client
RegisterNetEvent('ent:orderWatch', function(d) SendNUIMessage({ action = 'watch', data = d }) end)
RegisterNetEvent('ent:orderWatchStep', function(i) SendNUIMessage({ action = 'watchStep', index = i }) end)
RegisterNetEvent('ent:orderWatchEnd', function(ok) SendNUIMessage({ action = 'watchEnd', ok = ok == true }) end)

-- ---------------------------------------------------------------------
-- Points des clients : bornes et récupération au comptoir
-- ---------------------------------------------------------------------
local function HasReady(c)
    for _, o in ipairs(C.myOrders) do if o.status == 'ready' then return true end end
    return false
end

local shown
CreateThread(function()
    while true do
        local sleep, text, act = 1000, nil, nil
        if not kiosk and not C.tabletOpen and not working then
            local pc = GetEntityCoords(PlayerPedId())
            local myCompany = C.OnDuty() and C.Company() or nil
            for c, s in pairs(C.cfg) do
                if s.kiosk and s.kiosk.enabled ~= false and s.enabled then
                    for _, z in ipairs(s.zones or {}) do
                        if z.enabled ~= false then
                            local d = #(pc - vector3(z.x, z.y, z.z))
                            if z.type == 'borne' and d < 20.0 then
                                sleep = 0
                                DrawMarker(29, z.x, z.y, z.z + 0.2, 0, 0, 0, 0, 0, 0, 0.45, 0.45, 0.45, 224, 67, 59, 160, true, true, 2, false, nil, nil, false)
                                if d <= (z.radius or 1.0) + 0.6 and not text then
                                    text, act = '[E] Borne de commande', { kind = 'kiosk', company = c, zone = z }
                                end
                            elseif (z.type == 'comptoir' or z.type == 'assemblage') and d < 4.0 and myCompany ~= c and HasReady(c) then
                                sleep = 0
                                if d <= (z.radius or 1.5) + 0.8 and not text then
                                    text, act = '[E] Récupérer ma commande', { kind = 'pickup', company = c }
                                end
                            end
                        end
                    end
                end
            end
        end
        if text ~= shown then
            if text then Ely.showTextUI(text) elseif shown then Ely.hideTextUI() end
            shown = text
        end
        if act and IsControlJustPressed(0, 38) then
            Ely.hideTextUI() shown = nil
            if act.kind == 'kiosk' then
                kiosk = { company = act.company, zone = act.zone }
                TriggerServerEvent('ent:kioskOpen', act.company)
            else
                TriggerServerEvent('ent:orderPickup', act.company)
            end
            Wait(600)
        end
        -- Ferme la borne si le joueur s'éloigne
        if kiosk then
            sleep = 300
            local z = kiosk.zone
            if #(GetEntityCoords(PlayerPedId()) - vector3(z.x, z.y, z.z)) > (z.radius or 1.0) + 4.0 then CloseKiosk() end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if kiosk then SetNuiFocus(false, false) end
    if working then DeleteList(working.props) end
end)
