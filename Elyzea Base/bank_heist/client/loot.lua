-- =====================================================================
--  BANK HEIST - client : collecte des billets, affichage du sac, encaissement (E)
--  La collecte est comptée par le serveur (une tranche par seconde) : le client joue seulement
--  l'animation et affiche le montant. Le sac est celui de jewelry_heist (visible sur le dos).
-- =====================================================================
local C = BHC
local collecting = false
local bag = nil     -- { money, capacity } si le joueur porte un sac de billets

-- Affichage du sac (montant transporté) : infos envoyées par jewelry_heist au porteur
local function hud()
    if bag then SendNUIMessage({ action = 'bag', show = true, money = bag.money, capacity = bag.capacity })
    else SendNUIMessage({ action = 'bag', show = false }) end
end
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

-- Collecte
function C.Collect(bankId, spot)
    if collecting then return end
    local r = C.Req('collectStart', { bank = bankId, spot = spot })
    if not C.Show(r) then return end
    collecting = true
    local cfg = C.Cfg()
    local ped = PlayerPedId()
    local def = C.BankDef(bankId)
    local p = def and def.cash[spot]
    if p then TaskTurnPedToFaceCoord(ped, p.x + 0.0, p.y + 0.0, p.z + 0.0, 800) Wait(800) end
    C.PlayAnim(ped, cfg.visuals.collectAnim)
    CreateThread(function()
        while collecting do
            C.Help('Ramassage des billets… ~INPUT_VEH_DUCK~ arrêter')
            if IsControlJustPressed(0, 73) or IsEntityDead(ped) then C.Req('collectStop') collecting = false end
            local a = cfg.visuals.collectAnim
            if collecting and not IsEntityPlayingAnim(ped, a.dict, a.name, 3) then C.PlayAnim(ped, a) end
            Wait(0)
        end
        ClearPedTasks(ped)
    end)
end
RegisterNetEvent('bh:client:collectStop', function() collecting = false end)

-- Encaissement : E près d'un point de dépôt en portant un sac de billets
CreateThread(function()
    local blocking = false
    while true do
        local sleep = 700
        local cfg = C.Cfg()
        local nearDp = nil
        if cfg and bag then
            local pc = GetEntityCoords(PlayerPedId())
            for _, d in ipairs(cfg.deposits or {}) do
                if #(pc - C.Vec(d)) <= d.radius then nearDp = d break end
            end
        end
        -- près d'un dépôt, E encaisse au lieu de poser le sac (système de sac de jewelry_heist)
        if (nearDp ~= nil) ~= blocking then blocking = nearDp ~= nil LocalPlayer.state:set('jhNoDrop', blocking, false) end
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
                    C.Show(C.Req('deposit', { deposit = nearDp.id }))
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    LocalPlayer.state:set('jhNoDrop', false, false)
end)
