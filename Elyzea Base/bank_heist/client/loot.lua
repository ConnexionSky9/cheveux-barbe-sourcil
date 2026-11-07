-- =====================================================================
--  BANK HEIST - client : ramassage du butin, perceuse, HUD du butin, encaissement (E)
--  La collecte est comptée par le serveur (une tranche par seconde) : le client joue la scène
--  (billets glissés dans le sac) et affiche le montant. Le sac est celui de jewelry_heist.
-- =====================================================================
local C = BHC
local collecting = nil     -- { scene }
local bag = nil            -- { money, capacity } si le joueur porte un sac de billets
local heist = nil          -- dernier état envoyé par le serveur (braquage en cours)

-- ---------------------------------------------------------------------
-- HUD en haut à droite : butin de l'équipe, ma part, sac, alarme, porte, minuteur
-- ---------------------------------------------------------------------
local function hud()
    if not heist and not bag then SendNUIMessage({ action = 'hud', show = false }) return end
    SendNUIMessage({ action = 'hud', show = true, heist = heist, bag = bag })
end
RegisterNetEvent('bh:client:hud', function(d)
    heist = type(d) == 'table' and d or nil
    hud()
end)
RegisterNetEvent('jh:client:bagInfo', function(info)
    if type(info) == 'table' and info.kind == 'bank' then bag = { money = info.money or 0, capacity = info.capacity or ((C.Cfg() or {}).capacity) } else bag = nil end
    hud()
end)
CreateThread(function()
    while not C.Cfg() do Wait(500) end
    Wait(2000)
    local r = C.Req('bagInfo')
    if r.bag then bag = { money = r.money, capacity = r.capacity } hud() end
end)
function C.CarriedBankBag() return bag end

-- Chaque tranche ramassée : liasse en main, son de billets, « +5 000 $ » dans le HUD
RegisterNetEvent('bh:client:grabbed', function(amount)
    if collecting then C.Scenes.GrabTick(collecting.scene) end
    C.Sfx('cash', 0.5)
    SendNUIMessage({ action = 'grabbed', amount = amount })
end)

-- ---------------------------------------------------------------------
-- Ramassage d'un point de butin
-- ---------------------------------------------------------------------
local function stopCollect(fromServer)
    if not collecting then return end
    local c = collecting
    collecting = nil
    if not fromServer then C.Req('collectStop') end
    C.Scenes.GrabEnd(c.scene)
end

function C.Collect(bankId, i)
    if collecting then return end
    local def = C.BankDef(bankId)
    local p = def and def.loot[i]
    if not p then return end
    local r = C.Req('collectStart', { bank = bankId, point = i })
    if not C.Show(r) then return end
    if r.items then C.Sfx('cash') return end
    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, p.x + 0.0, p.y + 0.0, p.z + 0.0, 600)
    Wait(600)
    collecting = { bank = bankId }
    collecting.scene = C.Scenes.GrabBegin(r.anim == 'table' and 'table' or 'trolley', C.LootProp(bankId, i), r.pile)
    CreateThread(function()
        while collecting do
            C.Help('Remplissage du sac… ~INPUT_VEH_DUCK~ arrêter')
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)
            if IsControlJustPressed(0, 73) or IsEntityDead(ped) or IsPedRagdoll(ped) then stopCollect(false) end
            Wait(0)
        end
    end)
end
RegisterNetEvent('bh:client:collectStop', function() stopCollect(true) end)

-- ---------------------------------------------------------------------
-- Perceuse (coffres individuels) : mini-jeu dans l'interface, scène et étincelles en jeu
-- ---------------------------------------------------------------------
local drilling = nil
function C.Drill(bankId, i)
    if drilling or C.ui then return end
    local def = C.BankDef(bankId)
    local p = def and def.loot[i]
    if not p then return end
    local r = C.Req('drillStart', { bank = bankId, point = i })
    if not C.Show(r) then return end
    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, p.x + 0.0, p.y + 0.0, p.z + 0.0, 600)
    Wait(600)
    drilling = { bank = bankId, point = i, scene = C.Scenes.DrillBegin((C.Cfg().drill or {}).prop) }
    C.OpenUI('drill', { time = r.time, heatRate = r.heatRate })
    -- surveillance : éloigné, à terre → échec
    CreateThread(function()
        while drilling do
            if IsEntityDead(ped) or IsPedRagdoll(ped) or C.Dist(p) > 3.0 then
                C.CloseUI()
                C.OnDrillClosed(false)
            end
            Wait(250)
        end
    end)
end
RegisterNUICallback('drillPress', function(body, cb) cb({}) if drilling then C.Scenes.DrillPress(drilling.scene, body and body.on == true) end end)
function C.OnDrillClosed(done)
    if not drilling then return end
    local d = drilling
    drilling = nil
    C.Scenes.DrillEnd(d.scene)
    if done then
        local r = C.Req('drillDone')
        if C.Show(r) then
            C.Sfx('unlock')
            C.Notify('Coffres ouverts : remplissez le sac.', 'success')
            CreateThread(function() Wait(400) C.Collect(d.bank, d.point) end)
        end
    else
        C.Req('drillAbort')
        C.Notify('Perçage interrompu.', 'error')
    end
end
RegisterNetEvent('bh:client:drillStop', function() if drilling then C.CloseUI() C.OnDrillClosed(false) end end)

-- ---------------------------------------------------------------------
-- Argent du sac, encaissement
-- ---------------------------------------------------------------------
local taking = false
function C.TakeBagMoney(bagId)
    if taking then return end
    taking = true
    local ped = PlayerPedId()
    local a = (C.Cfg() or {}).visuals and C.Cfg().visuals.depositAnim
    if a and C.PlayAnim(ped, a, a.time) then Wait(a.time or 1000) end
    ClearPedTasks(ped)
    C.Show(C.Req('takeBagMoney', { bag = bagId }))
    taking = false
end
AddEventHandler('bh:client:takeBagMoney', function(bagId) CreateThread(function() C.TakeBagMoney(bagId) end) end)
RegisterCommand('sacargent', function() if bag and bag.money > 0 then CreateThread(function() C.TakeBagMoney(nil) end) else C.Notify('Vous ne portez pas de sac de billets plein.', 'error') end end, false)

-- Encaissement : E près d'un point de dépôt en portant un sac de billets
CreateThread(function()
    local blocking = false
    local cfg, cfgAt = nil, -1000
    while true do
        local sleep = 700
        local now = GetGameTimer()
        if bag and (not cfg or now - cfgAt >= 500) then cfg, cfgAt = C.Cfg(), now end
        local nearDp = nil
        if cfg and bag then
            local pc = GetEntityCoords(PlayerPedId())
            for _, d in ipairs(cfg.deposits or {}) do
                if #(pc - C.Vec(d)) <= d.radius then nearDp = d break end
            end
        end
        if (nearDp ~= nil) ~= blocking then blocking = nearDp ~= nil C.NoDrop('deposit', blocking) end
        if nearDp and not C.ui then
            sleep = 0
            C.Help((cfg.general.depositKey == 38 and '~INPUT_CONTEXT~' or ('[' .. cfg.general.depositKeyLabel .. ']')) .. (' Encaisser le sac (%s)'):format(BH.Money(bag.money)))
            if IsControlJustReleased(0, cfg.general.depositKey) then
                local ped = PlayerPedId()
                local veh = GetVehiclePedIsIn(ped, false)
                if veh ~= 0 and (not nearDp.allowPassenger or GetPedInVehicleSeat(veh, -1) == ped) then C.Notify('Descendez du véhicule pour déposer le sac.', 'error')
                else
                    local a = cfg.visuals.depositAnim
                    if C.PlayAnim(ped, a, a.time) then Wait(a.time or 1000) end
                    ClearPedTasks(ped)
                    local r = C.Req('deposit', { deposit = nearDp.id })
                    if C.Show(r) then C.Sfx('cash') C.Banner('ARGENT ENCAISSÉ', BH.Money(r.amount or 0), 'success') end
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    LocalPlayer.state:set('jhNoDrop', false, false)
    if collecting then C.Scenes.GrabEnd(collecting.scene) end
    if drilling then C.Scenes.DrillEnd(drilling.scene) end
end)
