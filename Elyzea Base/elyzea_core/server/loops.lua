-- ELYZEA CORE — sauvegarde automatique, faim / soif, salaires

-- Sauvegarde
CreateThread(function()
    while true do
        Wait(Config.Characters.saveInterval * 60000)
        for src in pairs(Players) do Save(src) Wait(50) end
    end
end)

-- Faim et soif
CreateThread(function()
    if not Config.Needs.enabled then return end
    while true do
        Wait(Config.Needs.interval * 60000)
        for src, p in pairs(Players) do
            if IsPlayerLoaded(src) and not Player(src).state.elyNeedsFrozen then
                local md = p.PlayerData.metadata
                local hunger = math.max(0, (tonumber(md.hunger) or 100) - Config.Needs.hungerRate)
                local thirst = math.max(0, (tonumber(md.thirst) or 100) - Config.Needs.thirstRate)
                md.hunger, md.thirst = hunger, thirst
                Player(src).state:set('hunger', hunger, true)
                Player(src).state:set('thirst', thirst, true)
                p.Functions.UpdatePlayerData()
                TriggerClientEvent('elyzea:client:needs', src, hunger, thirst)
                if (hunger <= 0 or thirst <= 0) and Config.Needs.damageWhenEmpty > 0 then
                    TriggerClientEvent('elyzea:client:starving', src, Config.Needs.damageWhenEmpty)
                end
            end
        end
    end
end)

-- Salaires
CreateThread(function()
    if not Config.Paycheck.enabled then return end
    while true do
        Wait(Config.Paycheck.interval * 60000)
        for src, p in pairs(Players) do
            local job = p.PlayerData.job
            local def = GetJob(job.name)
            local pay = tonumber(job.payment) or 0
            if IsPlayerLoaded(src) and pay > 0 and def and (job.onduty or def.offDutyPay) then
                local paid = true
                if Config.Paycheck.fromSociety and job.name ~= 'unemployed' then
                    paid = RemoveSocietyMoney(job.name, pay, ('Salaire de %s %s'):format(p.PlayerData.charinfo.firstname, p.PlayerData.charinfo.lastname))
                    if not paid then
                        TriggerClientEvent('elyzea:client:notify', src, 'Votre entreprise n\'a pas pu payer votre salaire.', 'error')
                    end
                end
                if paid then
                    p.Functions.AddMoney(Config.Paycheck.account, pay, 'paycheck')
                    TriggerClientEvent('elyzea:client:notify', src, ('Salaire reçu : %d $'):format(pay), 'success')
                    TriggerEvent('elyzea:server:onPaycheck', src, pay)
                end
            end
        end
    end
end)

-- Mise à jour des besoins envoyée par le client (manger / boire via l'inventaire passe par le serveur)
function AddNeeds(src, hunger, thirst, stress)
    local p = GetPlayer(src)
    if not p then return false end
    local md = p.PlayerData.metadata
    if hunger and hunger ~= 0 then p.Functions.SetMetaData('hunger', (tonumber(md.hunger) or 0) + hunger) end
    if thirst and thirst ~= 0 then p.Functions.SetMetaData('thirst', (tonumber(md.thirst) or 0) + thirst) end
    if stress and stress ~= 0 then p.Functions.SetMetaData('stress', (tonumber(md.stress) or 0) + stress) end
    TriggerClientEvent('elyzea:client:needs', src, p.PlayerData.metadata.hunger, p.PlayerData.metadata.thirst)
    return true
end
