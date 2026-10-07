-- =====================================================================
--  elyzea_lscustom - serveur : travail des mécaniciens
-- =====================================================================
local L = LSC
local lastInvoice = 0

local WORK_ZONES = {
    repair = { reparation = true, modification = true },
    clean  = { nettoyage = true, reparation = true, modification = true },
    modify = { modification = true },
}

local function ZoneOk(src, perm)
    if not L.S.settings.workInZonesOnly then return true end
    if L.InZone(L.Coords(src), WORK_ZONES[perm], 3.0) then return true end
    L.Notify(src, "Ce n'est pas possible ici : va dans la zone prévue de l'atelier.", 'error')
    return false
end

local function Near(src, target, max)
    target = tonumber(target)
    if not target or target == src or not GetPlayerName(target) then return nil end
    if #(L.Coords(src) - L.Coords(target)) > (max or 6.0) then
        L.Notify(src, 'La personne est trop loin.', 'error')
        return nil
    end
    return target
end

local function SetSession(src, kind, plate)
    if kind then L.Sessions[src] = { kind = kind, plate = plate, since = os.time() } else L.Sessions[src] = nil end
end

-- ---------------------------------------------------------------------
-- Prise de service (zone « Service »)
-- ---------------------------------------------------------------------
RegisterNetEvent('lscustom:server:toggleDuty', function(fromMenu)
    local src = source
    if not L.IsMechanic(src) then return end
    -- Depuis le menu F6 : partout. Sinon : dans une zone « Service ».
    if not fromMenu and not L.InZone(L.Coords(src), { service = true }, 2.0) then return end
    if not L.S.enabled then return L.Notify(src, L.Deny.closed, 'error') end
    local p = L.GetPlayer(src)
    local state = not p.PlayerData.job.onduty
    -- Fin de service pendant un travail : on libère le véhicule pris en charge
    if not state and L.Sessions[src] then L.Sessions[src] = nil end
    if p.Functions.SetJobDuty then p.Functions.SetJobDuty(state) else pcall(function() exports.qbx_core:SetJobDuty(src, state) end) end
    L.Notify(src, state and 'Tu as pris ton service.' or 'Tu as terminé ton service.', state and 'success' or 'inform')
    L.Log(src, state and 'Prise de service' or 'Fin de service', fromMenu and 'menu F6' or 'accueil')
    if fromMenu then TriggerClientEvent('lscustom:client:dutyChanged', src) end
end)

-- ---------------------------------------------------------------------
-- Réparation / nettoyage
-- ---------------------------------------------------------------------
RegisterNetEvent('lscustom:server:startWork', function(kind, plate)
    local src = source
    if kind ~= 'repair' and kind ~= 'clean' then return end
    if not L.CanOrNotify(src, kind) or not ZoneOk(src, kind) then return end
    SetSession(src, kind, tostring(plate or ''))
    TriggerClientEvent('lscustom:client:doWork', src, kind, kind == 'repair' and L.S.settings.repairTime or L.S.settings.cleanTime)
end)

RegisterNetEvent('lscustom:server:finishWork', function(kind, plate, done)
    local src = source
    local s = L.Sessions[src]
    if not s or s.kind ~= kind then return end
    SetSession(src, nil)
    if not done then return end
    L.Log(src, kind == 'repair' and 'Réparation' or 'Nettoyage', tostring(plate or ''))
    -- Proposer la facture préremplie
    if L.Can(src, 'invoice') then
        TriggerClientEvent('lscustom:client:suggestInvoice', src, {
            amount = L.Price(kind), label = kind == 'repair' and 'Réparation complète' or 'Nettoyage', plate = plate,
        })
    end
end)

-- ---------------------------------------------------------------------
-- Personnalisation
-- ---------------------------------------------------------------------
RegisterNetEvent('lscustom:server:openMods', function(plate)
    local src = source
    if not L.CanOrNotify(src, 'modify') or not ZoneOk(src, 'modify') then return end
    SetSession(src, 'modify', tostring(plate or ''))
    TriggerClientEvent('lscustom:client:openMods', src, L.S.prices)
end)

RegisterNetEvent('lscustom:server:closeMods', function()
    local src = source
    if L.Sessions[src] and L.Sessions[src].kind == 'modify' then SetSession(src, nil) end
end)

-- ---------------------------------------------------------------------
-- Factures
-- ---------------------------------------------------------------------
local function PendingFor(client)
    for _, inv in pairs(L.Invoices) do if inv.client == client then return inv end end
end

local function CreateInvoice(src, target, amount, label, kind, extra)
    if PendingFor(target) then
        L.Notify(src, 'Cette personne a déjà une facture en attente.', 'error')
        return false
    end
    lastInvoice = lastInvoice + 1
    local inv = {
        id = lastInvoice, mechanic = src, client = target, amount = amount, label = label, kind = kind,
        plate = extra and extra.plate, props = extra and extra.props,
        expires = os.time() + (L.S.settings.invoiceTimeout or 60),
    }
    L.Invoices[inv.id] = inv
    TriggerClientEvent('lscustom:client:invoicePrompt', target, {
        id = inv.id, amount = amount, label = label, mechanic = L.Name(src), company = L.S.job.label,
        timeout = L.S.settings.invoiceTimeout or 60,
    })
    L.Notify(src, ('Facture de $%d envoyée à %s.'):format(amount, L.Name(target)), 'inform')
    return true
end

local function Close(inv, paid, reason)
    L.Invoices[inv.id] = nil
    if GetPlayerName(inv.mechanic) then
        TriggerClientEvent('lscustom:client:invoiceResult', inv.mechanic, inv.id, paid, inv.kind)
        if not paid then L.Notify(inv.mechanic, reason or 'La facture a été refusée.', 'error') end
    end
    if GetPlayerName(inv.client) then TriggerClientEvent('lscustom:client:invoiceClosed', inv.client, inv.id) end
end

RegisterNetEvent('lscustom:server:invoice', function(target, amount, label, plate)
    local src = source
    if not L.CanOrNotify(src, 'invoice') then return end
    target = Near(src, target, 6.0)
    if not target then return end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or amount > (L.S.settings.maxInvoice or 100000) then
        return L.Notify(src, ('Montant invalide (maximum $%d).'):format(L.S.settings.maxInvoice or 100000), 'error')
    end
    label = tostring(label or ''):sub(1, 120)
    if label == '' then label = 'Prestation LsCustom' end
    CreateInvoice(src, target, amount, label, 'invoice', { plate = plate })
end)

-- items = { { key = 'engine', level = 2 }, ... } ; le prix est recalculé ici
RegisterNetEvent('lscustom:server:modsInvoice', function(target, items, plate, props)
    local src = source
    if not L.CanOrNotify(src, 'modify') or not ZoneOk(src, 'modify') then
        return TriggerClientEvent('lscustom:client:invoiceResult', src, 0, false, 'mods')
    end
    target = Near(src, target, 10.0)
    if not target then return TriggerClientEvent('lscustom:client:invoiceResult', src, 0, false, 'mods') end
    local total, names, seen = 0, {}, {}
    local SERVICE_PERM = { repair = 'repair', tyres = 'repair', clean = 'clean' }
    for _, it in ipairs(type(items) == 'table' and items or {}) do
        local c = L.CatalogByKey[tostring(it.key)]
        local allowed = c ~= nil and not seen[c.key]
        -- Réparation / roues / nettoyage : il faut aussi la permission correspondante
        if allowed and c.kind == 'service' then
            allowed = SERVICE_PERM[c.key] ~= nil and (L.Can(src, SERVICE_PERM[c.key]))
            if not allowed then L.Notify(src, ('« %s » retiré : ton grade ne le permet pas.'):format(c.label), 'error') end
        end
        if allowed then
            seen[c.key] = true
            total = total + L.Price(c.key, it.level)
            names[#names + 1] = c.label
        end
    end
    if total <= 0 then
        L.Notify(src, 'Aucune modification à facturer.', 'error')
        return TriggerClientEvent('lscustom:client:invoiceResult', src, 0, false, 'mods')
    end
    local label = ('Atelier : %s'):format(table.concat(names, ', ')):sub(1, 255)
    if not CreateInvoice(src, target, total, label, 'mods', { plate = tostring(plate or ''):sub(1, 16), props = type(props) == 'table' and props or nil }) then
        TriggerClientEvent('lscustom:client:invoiceResult', src, 0, false, 'mods')
    end
end)

RegisterNetEvent('lscustom:server:invoiceAnswer', function(id, accept)
    local src = source
    local inv = L.Invoices[tonumber(id)]
    if not inv or inv.client ~= src then return end
    if not accept then return Close(inv, false, ('%s a refusé la facture.'):format(L.Name(src))) end

    local client = L.GetPlayer(src)
    if not client or not client.Functions.RemoveMoney('bank', inv.amount, 'lscustom-invoice') then
        L.Notify(src, ("Tu n'as pas assez d'argent en banque ($%d)."):format(inv.amount), 'error')
        return Close(inv, false, ("%s n'a pas assez d'argent."):format(L.Name(src)))
    end

    -- Commission du mécanicien, le reste au métier
    local commission = math.floor(inv.amount * math.max(0, math.min(100, L.S.settings.commission or 0)) / 100)
    local mech = L.GetPlayer(inv.mechanic)
    if mech and commission > 0 then mech.Functions.AddMoney('bank', commission, 'lscustom-commission') end
    if L.S.settings.societyDeposit and GetResourceState('Renewed-Banking') == 'started' then
        pcall(function() exports['Renewed-Banking']:addAccountMoney(L.JobName(), inv.amount - commission) end)
    end

    -- Personnalisation : on enregistre les modifications du véhicule (s'il appartient à un joueur)
    if inv.kind == 'mods' and inv.plate and inv.props then
        MySQL.update('UPDATE player_vehicles SET mods = ? WHERE plate = ?', { json.encode(inv.props), inv.plate })
        -- Néons animés : visibles par tous grâce à l'état du véhicule
        for _, veh in ipairs(GetAllVehicles()) do
            local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '')
            if plate == inv.plate then
                Entity(veh).state:set('neonFx', inv.props._neonFx, true)
                Entity(veh).state:set('neonOff', false, true)
            end
        end
    end

    MySQL.insert('INSERT INTO lscustom_invoices (mechanic, mechanic_cid, client, client_cid, label, amount, plate) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        L.Name(inv.mechanic), mech and mech.PlayerData.citizenid or nil, L.Name(src), client.PlayerData.citizenid, inv.label, inv.amount, inv.plate,
    })
    L.Notify(src, ('Facture payée : $%d.'):format(inv.amount), 'success')
    if GetPlayerName(inv.mechanic) then
        L.Notify(inv.mechanic, ('Facture payée : $%d%s.'):format(inv.amount, commission > 0 and (' (ta part : $%d)'):format(commission) or ''), 'success')
    end
    L.Log(inv.mechanic, 'Facture payée', ('%s · $%d · %s'):format(L.Name(src), inv.amount, inv.label))
    Close(inv, true)
end)

CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for _, inv in pairs(L.Invoices) do
            if inv.expires <= now then Close(inv, false, 'La facture n\'a pas été acceptée à temps.') end
        end
    end
end)

-- ---------------------------------------------------------------------
-- Véhicules de service
-- ---------------------------------------------------------------------
local function CountVehicles(src)
    local n = 0
    for ent, owner in pairs(L.ServiceVehicles) do
        if owner == src then
            if DoesEntityExist(ent) then n = n + 1 else L.ServiceVehicles[ent] = nil end
        end
    end
    return n
end

RegisterNetEvent('lscustom:server:spawnVehicle', function(index)
    local src = source
    if not L.CanOrNotify(src, 'garage') then return end
    if not L.InZone(L.Coords(src), { garage = true }, 2.0) then return end
    local v = L.S.settings.serviceVehicles[tonumber(index)]
    if not v then return end
    if L.Grade(src) < (tonumber(v.grade) or 0) then return L.Notify(src, 'Ton grade ne permet pas de sortir ce véhicule.', 'error') end
    if CountVehicles(src) >= (L.S.settings.maxServiceVehicles or 1) then
        return L.Notify(src, 'Range d\'abord ton véhicule de service.', 'error')
    end
    -- Point de sortie le plus proche
    local c, best, bestDist = L.Coords(src), nil, nil
    for _, z in ipairs(L.S.zones) do
        if z.type == 'spawn' and z.enabled ~= false then
            local d = #(c - vector3(z.x, z.y, z.z))
            if not bestDist or d < bestDist then best, bestDist = z, d end
        end
    end
    if not best then return L.Notify(src, "Aucune zone « Spawn véhicule » n'est définie.", 'error') end

    local hash = joaat(v.model)
    local veh = CreateVehicleServerSetter(hash, 'automobile', best.x, best.y, best.z, best.h or 0.0)
    local t = GetGameTimer()
    while not DoesEntityExist(veh) and GetGameTimer() - t < 3000 do Wait(10) end
    if not DoesEntityExist(veh) then return L.Notify(src, 'Le véhicule n\'a pas pu être créé.', 'error') end
    SetVehicleNumberPlateText(veh, ('LSC %04d'):format(math.random(0, 9999)))
    L.ServiceVehicles[veh] = src
    pcall(function() exports.qbx_vehiclekeys:GiveKeys(src, veh) end)
    TaskWarpPedIntoVehicle(GetPlayerPed(src), veh, -1)
    L.Log(src, 'Véhicule de service', v.label or v.model)
end)

RegisterNetEvent('lscustom:server:storeVehicle', function(netId)
    local src = source
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or L.ServiceVehicles[veh] == nil then
        return L.Notify(src, "Ce n'est pas un véhicule de service de l'atelier.", 'error')
    end
    if not L.InZone(L.Coords(src), { parking = true }, 4.0) then return end
    L.ServiceVehicles[veh] = nil
    DeleteEntity(veh)
    L.Notify(src, 'Véhicule rangé.', 'success')
end)

-- ---------------------------------------------------------------------
-- Prix modifiés en jeu (permission « prices »)
-- ---------------------------------------------------------------------
RegisterNetEvent('lscustom:server:setPrices', function(prices)
    local src = source
    if not L.CanOrNotify(src, 'prices') then return end
    local n = 0
    for key, v in pairs(type(prices) == 'table' and prices or {}) do
        if L.CatalogByKey[key] and tonumber(v) then
            L.S.prices[key] = math.max(0, math.min(1000000, math.floor(tonumber(v))))
            n = n + 1
        end
    end
    L.Changed()
    L.Log(src, 'Prix modifiés (en jeu)', ('%d prix'):format(n))
    L.Notify(src, 'Tarifs enregistrés.', 'success')
end)

-- ---------------------------------------------------------------------
-- Données du menu de l'atelier
-- ---------------------------------------------------------------------
RegisterNetEvent('lscustom:server:menuData', function()
    local src = source
    local _, duty = L.Mechanics()
    local list = {}
    for _, id in ipairs(duty) do
        local p = L.GetPlayer(id)
        list[#list + 1] = { id = id, name = L.Name(id), grade = p.PlayerData.job.grade.name }
    end
    TriggerClientEvent('lscustom:client:menuData', src, {
        enabled = L.S.enabled, onduty = L.OnDuty(src), grade = L.Grade(src),
        perms = L.GradePerms(L.Grade(src)), mechanics = list, prices = L.S.prices,
    })
end)

AddEventHandler('playerDropped', function()
    local src = source
    L.Sessions[src] = nil
    for ent, owner in pairs(L.ServiceVehicles) do
        if owner == src then
            if DoesEntityExist(ent) then DeleteEntity(ent) end
            L.ServiceVehicles[ent] = nil
        end
    end
    for _, inv in pairs(L.Invoices) do
        if inv.client == src then Close(inv, false, 'Le client est parti.') end
        if inv.mechanic == src then L.Invoices[inv.id] = nil end
    end
end)

-- Néons éteints / rallumés par le conducteur (souvenir pour pouvoir les rallumer)
RegisterNetEvent('lscustom:server:neonOff', function(netId, off)
    local src = source
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(src) then return end
    Entity(veh).state:set('neonOff', off == true, true)
end)
