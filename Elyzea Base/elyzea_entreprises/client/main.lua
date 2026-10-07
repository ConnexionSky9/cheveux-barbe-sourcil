-- =====================================================================
--  elyzea_entreprises - client : zones, tablette F6, factures, préparation
-- =====================================================================
ENTC = { cfg = {}, busy = false, tabletOpen = false }
local C = ENTC
local blips = {}

local ZONE_COLORS = {}
for _, z in ipairs(Config.ZoneTypes) do ZONE_COLORS[z.key] = z.color end

function C.Notify(msg, kind) Ely.notify({ description = msg, type = kind or 'inform' }) end

function C.Job()
    local pd = exports.elyzea_core:GetPlayerData()
    return pd and pd.job or nil
end

-- Entreprise du joueur (nom interne) et son réglage public
function C.Company()
    local j = C.Job()
    if not j then return nil end
    for c, s in pairs(C.cfg) do if s.job.name == j.name then return c, s end end
end

function C.OnDuty()
    local j = C.Job()
    return C.Company() ~= nil and j.onduty == true
end

function C.Can(perm)
    local c, s = C.Company()
    if not c or not s.enabled or not C.OnDuty() then return false end
    local g = C.Job().grade and C.Job().grade.level or 0
    return (s.perms[tostring(g)] or {})[perm] == true
end

function C.NearbyPlayers(max)
    local me, pc = PlayerId(), GetEntityCoords(PlayerPedId())
    local list = {}
    for _, pl in ipairs(GetActivePlayers()) do
        if pl ~= me then
            local d = #(pc - GetEntityCoords(GetPlayerPed(pl)))
            if d <= (max or 6.0) then list[#list + 1] = { id = GetPlayerServerId(pl), dist = math.floor(d * 10) / 10 } end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

-- ---------------------------------------------------------------------
-- Synchronisation, icônes sur la carte
-- ---------------------------------------------------------------------
local function RefreshBlips()
    for _, b in ipairs(blips) do RemoveBlip(b) end
    blips = {}
    for _, s in pairs(C.cfg) do
        if s.settings.showBlips then
            local z
            for _, x in ipairs(s.zones or {}) do if x.enabled ~= false and (x.type == 'comptoir' or x.type == 'entree') then z = x break end end
            if not z then for _, x in ipairs(s.zones or {}) do if x.enabled ~= false and x.type == 'service' then z = x break end end end
            if z then
                local b = AddBlipForCoord(z.x, z.y, z.z)
                SetBlipSprite(b, s.settings.blipSprite or 280)
                SetBlipColour(b, s.enabled and (s.settings.blipColor or 0) or 39)
                SetBlipScale(b, 0.8)
                SetBlipAsShortRange(b, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(s.job.label .. (s.enabled and '' or ' (fermé)'))
                EndTextCommandSetBlipName(b)
                blips[#blips + 1] = b
            end
        end
    end
end

RegisterNetEvent('ent:sync', function(cfg)
    C.cfg = type(cfg) == 'table' and cfg or {}
    RefreshBlips()
    if C.tabletOpen then TriggerServerEvent('ent:tabletData') end
end)

AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then TriggerServerEvent('ent:requestSync') end
end)
RegisterNetEvent('elyzea:client:playerLoaded', function() TriggerServerEvent('ent:requestSync') end)

RegisterNetEvent('ent:teleport', function(z)
    DoScreenFadeOut(300)
    Wait(350)
    SetEntityCoords(PlayerPedId(), z.x + 0.0, z.y + 0.0, z.z + 0.0, false, false, false, false)
    if z.h then SetEntityHeading(PlayerPedId(), z.h + 0.0) end
    Wait(300)
    DoScreenFadeIn(300)
end)

-- ---------------------------------------------------------------------
-- Tablette (F6)
-- ---------------------------------------------------------------------
function C.OpenTablet(tab)
    local c, s = C.Company()
    if not c or C.busy then return end
    C.tabletOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'tablet', company = c, cfg = s, tab = tab, nearby = C.NearbyPlayers(6.0), meter = C.MeterState and C.MeterState() or nil,
        mission = C.MissionState and C.MissionState() or nil, orders = C.orders })
    TriggerServerEvent('ent:tabletData')
    if s.features and s.features.kiosk then TriggerServerEvent('ent:ordersData') end
end

RegisterCommand('entreprise_tablette', function() C.OpenTablet() end, false)
RegisterKeyMapping('entreprise_tablette', 'Entreprise : tablette des employés', 'keyboard', Config.TabletKey)

RegisterNetEvent('ent:tabletData', function(data)
    if C.tabletOpen then SendNUIMessage({ action = 'tabletData', data = data, nearby = C.NearbyPlayers(6.0) }) end
end)
RegisterNetEvent('ent:dutyChanged', function()
    if C.tabletOpen then TriggerServerEvent('ent:tabletData') end
end)

function C.CloseTablet()
    C.tabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeTablet' })
end

RegisterNUICallback('close', function(_, cb) C.CloseTablet() cb('ok') end)
RegisterNUICallback('nearby', function(_, cb) cb({ players = C.NearbyPlayers(6.0) }) end)

-- Comptes des objets (préparation : ingrédients disponibles)
RegisterNUICallback('counts', function(body, cb)
    local out = {}
    for _, name in ipairs(type(body.items) == 'table' and body.items or {}) do
        local ok, n = pcall(function() return exports.elyzea_inventory:Search('count', name) end)
        out[name] = ok and tonumber(n) or 0
    end
    cb(out)
end)

RegisterNUICallback('act', function(body, cb)
    cb('ok')
    local a, d = body.action, body.data or {}
    if a == 'duty' then TriggerServerEvent('ent:duty', true)
    elseif a == 'invoice' then TriggerServerEvent('ent:invoice', tonumber(d.target), tonumber(d.amount), d.label)
    elseif a == 'entry' then TriggerServerEvent('ent:entry', tonumber(d.target), d.vip == true)
    elseif a == 'prepare' then C.CloseTablet() TriggerServerEvent('ent:prepare', d.id)
    elseif a == 'supply' then TriggerServerEvent('ent:buySupply', tonumber(d.index), tonumber(d.qty))
    elseif a == 'stash' then C.CloseTablet() TriggerServerEvent('ent:openStash')
    elseif a == 'vehicle' then C.CloseTablet() TriggerServerEvent('ent:spawnVehicle', tonumber(d.index))
    elseif a == 'boss' then TriggerServerEvent('ent:boss', d.name, d.data)
    elseif a == 'refresh' then TriggerServerEvent('ent:tabletData')
    elseif C.KioskAction and C.KioskAction(a, d) then return
    elseif C.TaxiAction then C.TaxiAction(a, d) end
end)

-- ---------------------------------------------------------------------
-- Préparation : barre de progression puis validation serveur
-- ---------------------------------------------------------------------
RegisterNetEvent('ent:doPrepare', function(p)
    C.busy = true
    local isBar = p.company == 'nightclub'
    local done = Ely.progressBar({
        duration = math.floor((p.time or 5) * 1000), label = ('Préparation : %s'):format(p.label), canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = isBar and { dict = 'mini@drinking', clip = 'shots_barman_b', flag = 49 } or { scenario = 'PROP_HUMAN_BBQ' },
    })
    ClearPedTasks(PlayerPedId())
    TriggerServerEvent('ent:prepareDone', p.token, done == true)
    C.busy = false
end)

-- ---------------------------------------------------------------------
-- Facture reçue (client)
-- ---------------------------------------------------------------------
local promptOpen = false
RegisterNetEvent('ent:invoicePrompt', function(i)
    promptOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'invoice', invoice = i })
end)
RegisterNUICallback('invoiceAnswer', function(body, cb)
    promptOpen = false
    if not C.tabletOpen then SetNuiFocus(false, false) end
    TriggerServerEvent('ent:invoiceAnswer', tonumber(body.id), body.accept == true, body.method)
    cb('ok')
end)
RegisterNetEvent('ent:invoiceClosed', function()
    if promptOpen then
        promptOpen = false
        if not C.tabletOpen then SetNuiFocus(false, false) end
        SendNUIMessage({ action = 'invoiceClose' })
    end
end)
RegisterNetEvent('ent:invoiceResult', function(_, paid)
    if C.tabletOpen then SendNUIMessage({ action = 'invoiceResult', paid = paid }) end
end)

-- ---------------------------------------------------------------------
-- Zones : marqueurs et touche E
-- ---------------------------------------------------------------------
local HELP = {
    service = function() return C.OnDuty() and '[E] Terminer le service' or '[E] Prendre le service' end,
    stash = function() return C.Can('stash') and '[E] Ouvrir le coffre' or nil end,
    cuisine = function() return C.Can('prepare') and '[E] Préparer' or nil end,
    fournisseur = function() return C.Can('stock') and '[E] Commander au fournisseur' or nil end,
    comptoir = function() return C.Can('invoice') and '[E] Caisse' or nil end,
    entree = function() return C.Can('entry') and '[E] Faire payer l\'entrée' or nil end,
    garage = function() return C.Can('garage') and '[E] Véhicules de service' or nil end,
    assemblage = function() return C.Can('orders') and '[E] Commandes de la borne' or nil end,
    parking = function() return (IsPedInAnyVehicle(PlayerPedId(), false) and C.OnDuty()) and '[E] Ranger le véhicule' or nil end,
}
local ACTION = {
    service = function() TriggerServerEvent('ent:duty', false) end,
    stash = function() TriggerServerEvent('ent:openStash') end,
    cuisine = function() C.OpenTablet('prepare') end,
    fournisseur = function() C.OpenTablet('supply') end,
    comptoir = function() C.OpenTablet('invoice') end,
    entree = function() C.OpenTablet('entry') end,
    garage = function() C.OpenTablet('vehicles') end,
    assemblage = function() C.OpenTablet('orders') end,
    parking = function()
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        if veh ~= 0 then TriggerServerEvent('ent:storeVehicle', NetworkGetNetworkIdFromEntity(veh)) end
    end,
}

local shown
CreateThread(function()
    while true do
        local sleep, text, zone = 1000, nil, nil
        local c, s = C.Company()
        if c and not C.busy and not C.tabletOpen then
            local pc = GetEntityCoords(PlayerPedId())
            for _, z in ipairs(s.zones or {}) do
                if z.enabled ~= false then
                    local d = #(pc - vector3(z.x, z.y, z.z))
                    if d < 25.0 and (C.OnDuty() or z.type == 'service') then
                        sleep = 0
                        local col = ZONE_COLORS[z.type] or { 255, 255, 255 }
                        local r = (z.radius or 1.5) * 2.0
                        DrawMarker(1, z.x, z.y, z.z - 0.98, 0, 0, 0, 0, 0, 0, r, r, 0.35, col[1], col[2], col[3], 70, false, false, 2, false, nil, nil, false)
                        if d <= (z.radius or 1.5) + 0.5 and not text and HELP[z.type] then
                            text = HELP[z.type]()
                            if text then zone = z end
                        end
                    end
                end
            end
        end
        if text ~= shown then
            if text then Ely.showTextUI(text) else Ely.hideTextUI() end
            shown = text
        end
        if zone and IsControlJustPressed(0, 38) then
            Ely.hideTextUI() shown = nil
            ACTION[zone.type]()
            Wait(500)
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    Ely.hideTextUI()
    if C.tabletOpen or promptOpen then SetNuiFocus(false, false) end
end)
