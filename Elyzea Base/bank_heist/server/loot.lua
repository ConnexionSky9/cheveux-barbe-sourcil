-- =====================================================================
--  BANK HEIST - serveur : collecte du butin (chariots, liasses, lingots, coffres percés) et encaissement
--  · Collecte progressive comptée PAR LE SERVEUR (une tranche par seconde) : le client ne fait que
--    jouer l'animation. Réserve partagée entre braqueurs, jamais dépassée ; capacité du sac respectée ;
--    une seule collecte à la fois par joueur.
--  · Le sac est celui de jewelry_heist (sac de billets) : visible sur le dos, se pose avec E, se ramasse
--    avec ALT, garde son contenu exact. Il ne s'ouvre pas : il s'encaisse seulement à un point de dépôt.
-- =====================================================================
local P = BHS
P.collectors = {}   -- [src] = { bank, point, bag }
P.drills = {}       -- [src] = { bank, point, startedAt }

local function stop(src, reason, silent)
    local c = P.collectors[src]
    if not c then return end
    P.collectors[src] = nil
    local s = P.sessions[c.bank]
    if s and s.points[c.point] and s.points[c.point].busyBy == src then s.points[c.point].busyBy = nil P.PublishBanks() end
    if GetPlayerPing(src) > 0 then
        TriggerClientEvent('bh:client:collectStop', src, reason)
        if not silent and reason then P.Notify(src, reason, 'inform') end
    end
end
function P.StopCollectorsOf(bankId)
    for src, c in pairs(P.collectors) do if c.bank == bankId then stop(src, 'Le coffre est refermé.') end end
    for src, d in pairs(P.drills) do if d.bank == bankId then P.drills[src] = nil TriggerClientEvent('bh:client:drillStop', src) end end
end

-- Point de butin utilisable : session ouverte, point existant, joueur à côté
local function point(src, d)
    local b = P.BankById(tostring(d.bank or ''))
    local s = b and P.sessions[b.id]
    if not s or s.door ~= 'open' then return nil, 'Le coffre n\'est pas ouvert.' end
    local i = tonumber(d.point) or 0
    local def, sp = b.loot[i], s.points[i]
    if not def or not sp then return nil, 'Rien à prendre ici.' end
    if not P.Robber(src, s) then return nil, 'Vous ne participez pas à ce braquage.' end
    if not P.Near(src, def, 2.2) then return nil, 'Approchez-vous.' end
    if P.InVehicle(src) or P.IsDown(src) then return nil, 'Impossible maintenant.' end
    return { b = b, s = s, i = i, def = def, sp = sp, type = Config.LootTypes[def.type] or {} }
end

-- Sac de billets porté (ou le sac vide de l'inventaire qui devient le sac porté)
local function ensureBag(src, s)
    local bag = Adapters.Bag.Carried(src)
    if bag and bag.kind ~= 'bank' then return nil, 'Vous portez déjà un autre sac.' end
    if bag and bag.capacity and bag.money >= bag.capacity then return nil, 'Votre sac est plein.' end
    if bag then return bag end
    local item = P.S.items.bag.name
    if Adapters.Inv.Count(src, item) < 1 or not Adapters.Inv.Remove(src, item, 1) then return nil, 'Il vous faut un ' .. P.S.items.bag.label .. '.' end
    local id = Adapters.Bag.Create(src, P.S.loot.bagCapacity, s.id)
    if not id then Adapters.Inv.Add(src, item, 1) return nil, 'Impossible de préparer le sac.' end
    P.Log('loot', s.id, src, 'Sac de billets sorti (' .. id .. ')')
    return { id = id, kind = 'bank', money = 0, capacity = P.S.loot.bagCapacity }
end

-- Prendre des objets (point « objet », ex. lingots) : donnés d'un coup
local function takeItems(src, x)
    local n = x.sp.itemLeft or 0
    if n <= 0 then return { error = 'Il n\'y a plus rien.' } end
    if not Adapters.Inv.CanCarry(src, x.sp.item, n) then return { error = 'Pas assez de place dans votre inventaire.' } end
    if not Adapters.Inv.Add(src, x.sp.item, n) then return { error = 'Pas assez de place dans votre inventaire.' } end
    x.sp.itemLeft = 0
    P.Log('loot', x.s.id, src, ('Objets pris : %s ×%d'):format(x.sp.item, n))
    P.PublishBanks()
    return { ok = true, items = true, message = ('Récupéré : %s ×%d'):format(x.sp.item, n) }
end

P.Req.collectStart = function(src, d)
    local x, why = point(src, d)
    if not x then return { error = why } end
    if x.type.tool == 'drill' and not x.sp.drilled then return { error = 'Percez d\'abord les coffres individuels.' } end
    if x.sp.busyBy and x.sp.busyBy ~= src then return { error = 'Quelqu\'un se sert déjà ici.' } end
    if P.collectors[src] then return { error = 'Vous ramassez déjà.' } end
    if not P.Lock('collect:' .. src) then return { error = 'Patientez un instant.' } end
    local res
    if (x.sp.itemLeft or 0) > 0 then res = takeItems(src, x)
    elseif x.sp.left <= 0 then res = { error = 'Il n\'y a plus rien à prendre.' }
    elseif not Adapters.Bag.Ready() then res = { error = 'Système de sac indisponible (jewelry_heist).' }
    else
        local bag, err = ensureBag(src, x.s)
        if not bag then res = { error = err }
        else
            P.collectors[src] = { bank = x.b.id, point = x.i, bag = bag.id }
            x.sp.busyBy = src
            P.PublishBanks()
            res = { ok = true, bag = bag.id, anim = x.type.anim, pile = x.type.pile }
        end
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
            local b = P.BankById(c.bank)
            local sp = s and s.points[c.point]
            if not s or s.door ~= 'open' or not sp or not b then stop(src, 'Le coffre est refermé.')
            elseif GetPlayerPing(src) <= 0 or P.IsDown(src) or not P.Near(src, b.loot[c.point], 2.6) then stop(src, 'Collecte interrompue.')
            else
                local bag = Adapters.Bag.Carried(src)
                if not bag or bag.id ~= c.bag then stop(src, 'Vous n\'avez plus le sac.')
                else
                    local room = bag.capacity and bag.capacity > 0 and (bag.capacity - bag.money) or P.S.loot.perTick
                    local want = math.min(P.S.loot.perTick, sp.left, room)
                    local added = want > 0 and Adapters.Bag.AddMoney(src, bag.id, want) or 0
                    sp.left = sp.left - added
                    s.distributed = s.distributed + added
                    if added > 0 then
                        s.byPlayer[src] = (s.byPlayer[src] or 0) + added
                        TriggerClientEvent('bh:client:grabbed', src, added)
                        P.PushHud(s)
                    end
                    if sp.left <= 0 then stop(src, 'Il n\'y a plus rien ici.') P.PublishBanks()
                    elseif added <= 0 or bag.money + added >= (bag.capacity or math.huge) then stop(src, 'Votre sac est plein.') end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------
-- Perceuse (coffres individuels) : durée vérifiée par le serveur
-- ---------------------------------------------------------------------
P.Req.drillStart = function(src, d)
    local x, why = point(src, d)
    if not x then return { error = why } end
    if x.type.tool ~= 'drill' then return { error = 'Pas besoin de perceuse ici.' } end
    if x.sp.drilled then return { error = 'Déjà percé.' } end
    if x.sp.drillBy and x.sp.drillBy ~= src then return { error = 'Quelqu\'un perce déjà ici.' } end
    if Adapters.Inv.Count(src, P.S.items.drill.name) < 1 then return { error = 'Il vous faut une ' .. P.S.items.drill.label .. '.' } end
    if P.drills[src] then return { error = 'Vous percez déjà.' } end
    x.sp.drillBy = src
    P.drills[src] = { bank = x.b.id, point = x.i, startedAt = GetGameTimer() }
    P.Log('loot', x.s.id, src, 'Perçage des coffres individuels')
    P.PublishBanks()
    return { ok = true, time = P.S.drill.time, heatRate = P.S.drill.heatRate }
end

local function drillEnd(src, success)
    local dr = P.drills[src]
    if not dr then return nil end
    P.drills[src] = nil
    local s = P.sessions[dr.bank]
    local sp = s and s.points[dr.point]
    if sp and sp.drillBy == src then sp.drillBy = nil end
    if success and sp then sp.drilled = true end
    P.PublishBanks()
    return dr, s
end

P.Req.drillDone = function(src)
    local dr = P.drills[src]
    if not dr then return { error = 'Aucun perçage en cours.' } end
    local b = P.BankById(dr.bank)
    -- le perçage efficace dure au moins « time » secondes (un client ne peut pas aller plus vite)
    if GetGameTimer() - dr.startedAt < P.S.drill.time * 1000 * 0.95 then
        P.Log('anomaly', 'drill', src, 'Perçage terminé trop vite')
        drillEnd(src, false)
        return { error = 'Le perçage n\'est pas terminé.' }
    end
    if not b or not P.Near(src, b.loot[dr.point], 2.8) then drillEnd(src, false) return { error = 'Vous vous êtes éloigné.' } end
    local _, s = drillEnd(src, true)
    if s then P.Log('loot', s.id, src, 'Coffres individuels percés') end
    return { ok = true }
end

P.Req.drillAbort = function(src) drillEnd(src, false) return { ok = true } end

AddEventHandler('playerDropped', function() local src = source stop(src, nil, true) drillEnd(src, false) end)
AddEventHandler('elyzea:server:playerUnloaded', function(src) src = tonumber(src) or -1 stop(src, nil, true) drillEnd(src, false) end)

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
