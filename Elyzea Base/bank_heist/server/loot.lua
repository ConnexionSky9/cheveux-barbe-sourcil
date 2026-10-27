-- =====================================================================
--  BANK HEIST - serveur : collecte des billets et encaissement
--  · Collecte progressive comptée PAR LE SERVEUR (une tranche par seconde) : le client ne fait que
--    jouer l'animation. Réserve partagée entre braqueurs, jamais dépassée ; capacité du sac respectée ;
--    une seule collecte à la fois par joueur.
--  · Le sac est celui de jewelry_heist (sac de billets) : visible sur le dos, se pose avec E, se ramasse
--    avec ALT, garde son contenu exact. Il ne s'ouvre pas : il s'encaisse seulement à un point de dépôt.
-- =====================================================================
local P = BHS
P.collectors = {}   -- [src] = { bank, spot, bag }

local function stop(src, reason, silent)
    local c = P.collectors[src]
    if not c then return end
    P.collectors[src] = nil
    if GetPlayerPing(src) > 0 then
        TriggerClientEvent('bh:client:collectStop', src, reason)
        if not silent and reason then P.Notify(src, reason, 'inform') end
    end
end
function P.StopCollectorsOf(bankId) for src, c in pairs(P.collectors) do if c.bank == bankId then stop(src, 'Le coffre est refermé.') end end end

P.Req.collectStart = function(src, d)
    local b = P.BankById(tostring(d.bank or ''))
    local s = b and P.sessions[b.id]
    if not s or s.state ~= 'open' then return { error = 'Le coffre n\'est pas ouvert.' } end
    if s.pool <= 0 then return { error = 'Il n\'y a plus de billets.' } end
    if P.collectors[src] then return { error = 'Vous ramassez déjà.' } end
    if not P.Robber(src, s) then return { error = 'Vous ne participez pas à ce braquage.' } end
    local spot = b.cash[tonumber(d.spot) or 0]
    if not spot or not P.Near(src, spot, 2.0) then return { error = 'Approchez-vous des billets.' } end
    if P.InVehicle(src) or P.IsDown(src) then return { error = 'Impossible maintenant.' } end
    if not Adapters.Bag.Ready() then return { error = 'Système de sac indisponible (jewelry_heist).' } end
    if not P.Lock('collect:' .. src) then return { error = 'Patientez un instant.' } end
    local bag = Adapters.Bag.Carried(src)
    local res
    if bag and bag.kind ~= 'bank' then res = { error = 'Vous portez déjà un autre sac.' }
    elseif bag and bag.capacity and bag.money >= bag.capacity then res = { error = 'Votre sac est plein.' }
    elseif not bag then
        -- premier remplissage : le sac vide de l'inventaire devient le sac porté
        local item = P.S.items.bag.name
        if Adapters.Inv.Count(src, item) < 1 then res = { error = 'Il vous faut un ' .. P.S.items.bag.label .. '.' }
        elseif not Adapters.Inv.Remove(src, item, 1) then res = { error = 'Il vous faut un ' .. P.S.items.bag.label .. '.' }
        else
            local id = Adapters.Bag.Create(src, P.S.loot.bagCapacity, s.id)
            if not id then
                Adapters.Inv.Add(src, item, 1)
                res = { error = 'Impossible de préparer le sac.' }
            else
                bag = { id = id, kind = 'bank', money = 0, capacity = P.S.loot.bagCapacity }
                P.Log('loot', s.id, src, 'Sac de billets sorti (' .. id .. ')')
            end
        end
    end
    if not res then
        P.collectors[src] = { bank = b.id, spot = spot, bag = bag.id }
        res = { ok = true, bag = bag.id }
    end
    P.Unlock('collect:' .. src)
    return res
end

P.Req.collectStop = function(src) stop(src, nil, true) return { ok = true } end

-- Une tranche par seconde pour chaque joueur en train de ramasser
CreateThread(function()
    while true do
        Wait(1000)
        for src, c in pairs(P.collectors) do
            local s = P.sessions[c.bank]
            if not s or s.state ~= 'open' then stop(src, 'Le coffre est refermé.')
            elseif GetPlayerPing(src) <= 0 or P.IsDown(src) or not P.Near(src, c.spot, 2.5) then stop(src, 'Collecte interrompue.')
            else
                local bag = Adapters.Bag.Carried(src)
                if not bag or bag.id ~= c.bag then stop(src, 'Vous n\'avez plus le sac.')
                else
                    local room = bag.capacity and bag.capacity > 0 and (bag.capacity - bag.money) or P.S.loot.perTick
                    local want = math.min(P.S.loot.perTick, s.pool, room)
                    local added = want > 0 and Adapters.Bag.AddMoney(src, bag.id, want) or 0
                    s.pool = s.pool - added
                    s.distributed = s.distributed + added
                    if added > 0 then s.byPlayer = s.byPlayer or {} s.byPlayer[src] = (s.byPlayer[src] or 0) + added end
                    if s.pool <= 0 then
                        stop(src, 'Le coffre est vide.')
                        P.PublishBanks()
                    elseif added <= 0 or bag.money + added >= (bag.capacity or math.huge) then stop(src, 'Votre sac est plein.') end
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function() P.collectors[source] = nil end)
AddEventHandler('elyzea:server:playerUnloaded', function(src) P.collectors[tonumber(src) or -1] = nil end)

-- Objets en plus (lingots…) tirés à l'ouverture
P.Req.takeExtras = function(src, d)
    local b = P.BankById(tostring(d.bank or ''))
    local s = b and P.sessions[b.id]
    if not s or s.state ~= 'open' then return { error = 'Le coffre n\'est pas ouvert.' } end
    if #s.extras == 0 then return { error = 'Il n\'y a rien d\'autre.' } end
    if not P.Robber(src, s) then return { error = 'Vous ne participez pas à ce braquage.' } end
    local near = false
    for _, sp in ipairs(b.cash) do if P.Near(src, sp, 2.5) then near = true end end
    if not near then return { error = 'Approchez-vous du coffre.' } end
    if not P.Lock('extras:' .. b.id) then return { error = 'Patientez un instant.' } end
    local got, keep = {}, {}
    for _, e in ipairs(s.extras) do
        if Adapters.Inv.CanCarry(src, e.item, e.count) and Adapters.Inv.Add(src, e.item, e.count) then got[#got + 1] = ('%s ×%d'):format(e.item, e.count)
        else keep[#keep + 1] = e end
    end
    s.extras = keep
    P.Unlock('extras:' .. b.id)
    if #got > 0 then P.Log('loot', s.id, src, 'Objets pris : ' .. table.concat(got, ', ')) end
    if #keep > 0 then return { error = 'Pas assez de place pour tout prendre.' } end
    P.PublishBanks()
    return { ok = true, message = 'Récupéré : ' .. table.concat(got, ', ') }
end

-- ---------------------------------------------------------------------
-- Encaissement à un point de dépôt (E)
-- ---------------------------------------------------------------------
-- Paie le contenu d'un sac vidé (dépôt ou « Prendre l'argent ») ; si le paiement échoue, le sac est rendu porté.
local function payBag(src, amount, id, where)
    local reward = math.floor(amount * P.S.loot.depositRate / 100)
    local kind = P.S.loot.rewardType
    if Adapters.Money.Add(src, kind, reward, 'Braquage de banque ' .. tostring(id)) then
        P.Log('deposit', id, src, ('Sac vidé (%s) : %s → %s (%s)'):format(where, BH.Money(amount), BH.Money(reward), kind))
        P.Notify(src, ('Argent récupéré : %s (%s).'):format(BH.Money(reward), Adapters.Money.Labels[kind]), 'success')
        return { ok = true, amount = reward }
    end
    local nid = Adapters.Bag.Create(src, P.S.loot.bagCapacity, id)
    local back = nid and Adapters.Bag.AddMoney(src, nid, amount) or 0
    P.Log('anomaly', id, src, ('Paiement refusé (%s) : sac rendu %s'):format(BH.Money(reward), back == amount and 'intact' or ('PARTIEL ' .. BH.Money(back))))
    return { error = 'Impossible de recevoir l\'argent (inventaire plein ?) : vous gardez le sac.' }
end

-- Prendre l'argent d'un sac de billets : sac posé au sol (bag = id) ou sac porté (sans bag)
P.Req.takeBagMoney = function(src, d)
    if P.IsDown(src) or P.InVehicle(src) then return { error = 'Impossible maintenant.' } end
    if P.collectors[src] then return { error = 'Terminez d\'abord la collecte.' } end
    if not P.Lock('deposit:' .. src) then return { error = 'Patientez un instant.' } end
    local amount, id
    if d.bag then
        amount, id = Adapters.Bag.CashOutGround(src, tostring(d.bag))
    else
        local bag = Adapters.Bag.Carried(src)
        if bag and bag.kind == 'bank' then amount, id = Adapters.Bag.CashOut(src) else amount = 0 end
    end
    local res
    if (amount or 0) <= 0 then res = { error = d.bag and 'Le sac est vide ou trop loin.' or 'Vous ne portez pas de sac de billets plein.' }
    else res = payBag(src, amount, id, d.bag and 'au sol' or 'porté') end
    P.Unlock('deposit:' .. src)
    return res
end

P.Req.deposit = function(src, d)
    local dp = P.DepositById(tostring(d.deposit or ''))
    if not dp or not dp.enabled then return { error = 'Point de dépôt inconnu.' } end
    if not P.Near(src, dp, dp.radius + 0.5) then return { error = 'Vous n\'êtes pas au point de dépôt.' } end
    local ped = GetPlayerPed(src)
    local veh = ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
    if veh ~= 0 and (not dp.allowPassenger or GetPedInVehicleSeat(veh, -1) == ped) then return { error = 'Descendez du véhicule pour déposer le sac.' } end
    if P.IsDown(src) then return { error = 'Impossible maintenant.' } end
    local bag = Adapters.Bag.Carried(src)
    if not bag or bag.kind ~= 'bank' then return { error = 'Vous ne portez pas de sac de billets.' } end
    if P.collectors[src] then return { error = 'Terminez d\'abord la collecte.' } end
    if not P.Lock('deposit:' .. src) then return { error = 'Patientez un instant.' } end
    local amount, id = Adapters.Bag.CashOut(src)
    local res
    if amount <= 0 then res = { error = 'Le sac est vide.' }
    else
        res = payBag(src, amount, id, dp.name)
    end
    P.Unlock('deposit:' .. src)
    return res
end

-- Montant du sac porté (pour l'affichage) : lu sur le serveur
P.Req.bagInfo = function(src)
    local bag = Adapters.Bag.Carried(src)
    if not bag or bag.kind ~= 'bank' then return { bag = false } end
    return { bag = true, money = bag.money, capacity = bag.capacity or P.S.loot.bagCapacity }
end
