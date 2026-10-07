-- =====================================================================
--  elyzea_police - serveur : interactions, amendes, prison, permis
-- =====================================================================
local P = Police
local MAX_DIST = 4.0

local function Near(src, target)
    target = tonumber(target)
    if not target or target == src or not GetPlayerName(target) then return nil end
    if P.Dist(src, target) > MAX_DIST then
        P.Notify(src, 'La personne est trop loin.', 'error')
        return nil
    end
    return target
end

-- ---------------------------------------------------------------------
-- Menottes / escorte / véhicule
-- ---------------------------------------------------------------------
RegisterNetEvent('police:server:cuff', function(target)
    local src = source
    if not P.Can(src, 'cuff') then return end
    target = Near(src, target)
    if not target then return end
    local state = not P.Cuffed[target]
    P.Cuffed[target] = state or nil
    if not state and P.Escorted[target] then
        P.Escorted[target] = nil
        TriggerClientEvent('police:client:escorted', target, nil)
    end
    Player(target).state:set('cuffed', state, true)
    TriggerClientEvent('police:client:cuffed', target, state, src)
    TriggerClientEvent('police:client:cuffAnim', src, state)
    P.Notify(src, state and ('%s est menotté.'):format(P.Name(target)) or ('%s est démenotté.'):format(P.Name(target)), 'success')
end)

RegisterNetEvent('police:server:escort', function(target)
    local src = source
    if not P.Can(src, 'cuff') then return end
    target = Near(src, target)
    if not target then return end
    if not P.Cuffed[target] then return P.Notify(src, 'La personne doit être menottée.', 'error') end
    if P.Escorted[target] then
        P.Escorted[target] = nil
        TriggerClientEvent('police:client:escorted', target, nil)
    else
        P.Escorted[target] = src
        TriggerClientEvent('police:client:escorted', target, src)
    end
end)

RegisterNetEvent('police:server:putInVehicle', function(target, netId)
    local src = source
    if not P.Can(src, 'cuff') then return end
    target = Near(src, target)
    if not target then return end
    if not P.Cuffed[target] then return P.Notify(src, 'La personne doit être menottée.', 'error') end
    P.Escorted[target] = nil
    TriggerClientEvent('police:client:escorted', target, nil)
    TriggerClientEvent('police:client:putInVehicle', target, netId)
end)

RegisterNetEvent('police:server:takeOutVehicle', function(target)
    local src = source
    if not P.Can(src, 'cuff') then return end
    target = tonumber(target)
    if not target or not GetPlayerName(target) or P.Dist(src, target) > 8.0 then return end
    TriggerClientEvent('police:client:takeOutVehicle', target)
end)

-- ---------------------------------------------------------------------
-- Fouille (elyzea_inventory)
-- ---------------------------------------------------------------------
RegisterNetEvent('police:server:search', function(target, handsUp)
    local src = source
    if not P.Can(src, 'search') then return end
    target = Near(src, target)
    if not target then return end
    if P.Settings.settings.searchNeedsCuff and not P.Cuffed[target] and not handsUp then
        return P.Notify(src, 'La personne doit être menottée ou avoir les mains en l\'air.', 'error')
    end
    if GetResourceState('elyzea_inventory') ~= 'started' then
        return P.Notify(src, 'La fouille nécessite elyzea_inventory.', 'error')
    end
    exports.elyzea_inventory:OpenInventory(src, 'player', target)
    P.Notify(target, 'Vous êtes fouillé.', 'inform')
    P.Log(src, 'Fouille', ('%s [%d]'):format(P.Name(target), target))
end)

-- Vérifier l'identité de la personne proche
RegisterNetEvent('police:server:checkId', function(target)
    local src = source
    if not P.Can(src, 'cuff') then return end
    target = Near(src, target)
    if not target then return end
    local p = P.GetPlayer(target)
    if not p then return end
    TriggerClientEvent('police:client:openProfile', src, p.PlayerData.citizenid)
end)

-- ---------------------------------------------------------------------
-- Amendes
-- ---------------------------------------------------------------------
local function SocietyDeposit(amount)
    if not P.Settings.settings.fineToSociety then return end
    local job = P.Settings.job and P.Settings.job.name
    if not job then return end
    pcall(function() exports.elyzea_core:AddSocietyMoney(job, amount, 'Amende') end)
end

local function PayFine(src, fineId)
    local cid = P.Cid(src)
    local fine = MySQL.single.await('SELECT * FROM police_fines WHERE id = ? AND citizenid = ? AND paid = 0', { fineId, cid })
    if not fine then return false end
    local p = P.GetPlayer(src)
    if not p or not p.Functions.RemoveMoney('bank', fine.amount, 'police-fine') then
        P.Notify(src, ("Vous n'avez pas assez d'argent en banque ($%d)."):format(fine.amount), 'error')
        return false
    end
    MySQL.update.await('UPDATE police_fines SET paid = 1 WHERE id = ?', { fineId })
    SocietyDeposit(fine.amount)
    P.Notify(src, ('Amende payée : $%d.'):format(fine.amount), 'success')
    return true
end

-- items = liste d'id du catalogue ; custom = { label, amount } facultatif
function P.IssueFine(src, target, items, custom, note)
    local p = P.GetPlayer(target)
    if not p then return false, 'Joueur introuvable.' end
    local labels, total, jail = {}, 0, 0
    for _, id in ipairs(items or {}) do
        for _, f in ipairs(P.Settings.fines) do
            if f.id == id then
                labels[#labels + 1] = f.label
                total = total + (tonumber(f.amount) or 0)
                jail = jail + (tonumber(f.jail) or 0)
            end
        end
    end
    if custom and tonumber(custom.amount) and tonumber(custom.amount) > 0 then
        labels[#labels + 1] = tostring(custom.label or 'Autre'):sub(1, 80)
        total = total + math.floor(tonumber(custom.amount))
    end
    if total <= 0 then return false, 'Choisissez au moins une infraction.' end
    total = math.min(total, P.Settings.settings.maxFine or 50000)

    local label = table.concat(labels, ', '):sub(1, 255)
    local name = P.CharName(p.PlayerData.charinfo)
    local id = MySQL.insert.await('INSERT INTO police_fines (citizenid, name, label, amount, officer) VALUES (?, ?, ?, ?, ?)',
        { p.PlayerData.citizenid, name, label, total, P.Name(src) })

    -- Paiement immédiat si possible, sinon l'amende reste due (/amendes)
    if p.Functions.RemoveMoney('bank', total, 'police-fine') then
        MySQL.update.await('UPDATE police_fines SET paid = 1 WHERE id = ?', { id })
        SocietyDeposit(total)
        P.Notify(target, ('Amende de $%d prélevée : %s.'):format(total, label), 'inform')
    else
        P.Notify(target, ('Amende de $%d : %s. Payez-la avec /%s.'):format(total, label, Config.Commands.fines), 'error')
    end
    P.Log(src, 'Amende', ('%s · $%d · %s'):format(name, total, label))
    return true, ('Amende de $%d donnée à %s.'):format(total, name), jail
end

RegisterNetEvent('police:server:fine', function(target, items, custom)
    local src = source
    if not P.Can(src, 'fines') then return end
    target = Near(src, target)
    if not target then return end
    local ok, msg = P.IssueFine(src, target, type(items) == 'table' and items or {}, type(custom) == 'table' and custom or nil)
    P.Notify(src, msg, ok and 'success' or 'error')
end)

RegisterNetEvent('police:server:myFines', function()
    local src = source
    local cid = P.Cid(src)
    if not cid then return end
    local rows = MySQL.query.await('SELECT id, label, amount, officer, DATE_FORMAT(created_at, "%d/%m/%Y") AS date FROM police_fines WHERE citizenid = ? AND paid = 0 ORDER BY id DESC', { cid }) or {}
    TriggerClientEvent('police:client:myFines', src, rows)
end)

RegisterNetEvent('police:server:payFine', function(id)
    local src = source
    PayFine(src, tonumber(id))
    local cid = P.Cid(src)
    local rows = MySQL.query.await('SELECT id, label, amount, officer, DATE_FORMAT(created_at, "%d/%m/%Y") AS date FROM police_fines WHERE citizenid = ? AND paid = 0 ORDER BY id DESC', { cid }) or {}
    TriggerClientEvent('police:client:myFines', src, rows)
end)

-- ---------------------------------------------------------------------
-- Prison
-- ---------------------------------------------------------------------
local function JailPoint(kind)
    local list = P.Settings.points[kind] or {}
    return list[1]
end

function P.SendToJail(src, target, minutes, reason)
    local p = P.GetPlayer(target)
    if not p then return false, 'Joueur introuvable.' end
    minutes = math.floor(tonumber(minutes) or 0)
    if minutes <= 0 then return false, 'Durée invalide.' end
    minutes = math.min(minutes, P.Settings.settings.maxJail or 120)
    local point = JailPoint('jail')
    if not point then return false, "Aucun point de prison n'est défini (tablette staff)." end

    local cid = p.PlayerData.citizenid
    local name = P.CharName(p.PlayerData.charinfo)
    reason = tostring(reason or ''):sub(1, 255)
    P.Jailed[target] = { citizenid = cid, remaining = minutes * 60, reason = reason }
    MySQL.query.await('INSERT INTO police_jail (citizenid, name, remaining, reason, officer) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE remaining = VALUES(remaining), reason = VALUES(reason), officer = VALUES(officer)',
        { cid, name, minutes * 60, reason, src and P.Name(src) or 'Système' })

    P.Cuffed[target], P.Escorted[target] = nil, nil
    Player(target).state:set('cuffed', false, true)
    TriggerClientEvent('police:client:cuffed', target, false)
    TriggerClientEvent('police:client:escorted', target, nil)
    TriggerClientEvent('police:client:jailed', target, point, minutes * 60, reason, P.Settings.settings.jailRadius)
    P.Log(src, 'Prison', ('%s · %d min · %s'):format(name, minutes, reason))
    return true, ('%s est envoyé en prison pour %d minutes.'):format(name, minutes)
end

function P.Release(target, byName)
    local j = P.Jailed[target]
    if not j then return false end
    P.Jailed[target] = nil
    MySQL.query.await('DELETE FROM police_jail WHERE citizenid = ?', { j.citizenid })
    TriggerClientEvent('police:client:released', target, JailPoint('release'))
    P.Notify(target, byName and ('Vous avez été libéré par %s.'):format(byName) or 'Vous avez purgé votre peine.', 'success')
    return true
end

-- Libérer un prisonnier hors ligne (par citizenid)
function P.ReleaseCid(cid, byName)
    local src = P.FindByCid(cid)
    if src and P.Jailed[src] then return P.Release(src, byName) end
    MySQL.query.await('DELETE FROM police_jail WHERE citizenid = ?', { cid })
    return true
end

RegisterNetEvent('police:server:jail', function(target, minutes, reason)
    local src = source
    if not P.Can(src, 'jail') then return end
    target = Near(src, target)
    if not target then return end
    local ok, msg = P.SendToJail(src, target, minutes, reason)
    P.Notify(src, msg, ok and 'success' or 'error')
end)

-- Décompte : une fois par minute, seulement pour les joueurs connectés
CreateThread(function()
    while true do
        Wait(60000)
        for src, j in pairs(P.Jailed) do
            if GetPlayerName(src) then
                j.remaining = j.remaining - 60
                if j.remaining <= 0 then
                    P.Release(src)
                else
                    MySQL.update('UPDATE police_jail SET remaining = ? WHERE citizenid = ?', { j.remaining, j.citizenid })
                    TriggerClientEvent('police:client:jailTime', src, j.remaining)
                end
            else
                P.Jailed[src] = nil
            end
        end
    end
end)

-- Retour en prison à la reconnexion
local function CheckJail(src)
    local cid = P.Cid(src)
    if not cid then return end
    local row = MySQL.single.await('SELECT remaining, reason FROM police_jail WHERE citizenid = ?', { cid })
    if row and row.remaining > 0 then
        local point = JailPoint('jail')
        if not point then return end
        P.Jailed[src] = { citizenid = cid, remaining = row.remaining, reason = row.reason }
        TriggerClientEvent('police:client:jailed', src, point, row.remaining, row.reason, P.Settings.settings.jailRadius)
    end
end

RegisterNetEvent('police:server:playerLoaded', function()
    local src = source
    P.Sync(src)
    SetTimeout(4000, function() CheckJail(src) end)
end)

AddEventHandler('police:server:ready', function()
    for src in pairs(exports.elyzea_core:GetPlayers()) do CheckJail(src) end
end)

-- ---------------------------------------------------------------------
-- Permis (metadata elyzea_core « licences »)
-- ---------------------------------------------------------------------
function P.SetLicense(src, cid, license, state)
    license = tostring(license or ''):lower():gsub('[^%w_]', '')
    if license == '' then return false, 'Permis invalide.' end
    local target, p = P.FindByCid(cid)
    if p then
        local lic = P.Copy(p.PlayerData.metadata.licences or {})
        lic[license] = state == true
        p.Functions.SetMetaData('licences', lic)
    else
        MySQL.update.await(('UPDATE players SET metadata = JSON_SET(metadata, "$.licences.%s", JSON_EXTRACT(?, "$")) WHERE citizenid = ?'):format(license),
            { state == true and 'true' or 'false', cid })
    end
    P.Log(src, state and 'Permis donné' or 'Permis retiré', ('%s · %s'):format(cid, license))
    return true, state and 'Permis donné.' or 'Permis retiré.'
end

-- ---------------------------------------------------------------------
-- Déconnexion
-- ---------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    P.Cuffed[src] = nil
    P.Jailed[src] = nil
    for target, cop in pairs(P.Escorted) do
        if cop == src or target == src then
            P.Escorted[target] = nil
            if target ~= src then TriggerClientEvent('police:client:escorted', target, nil) end
        end
    end
end)
