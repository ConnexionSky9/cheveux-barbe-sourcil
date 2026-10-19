-- =========================================================
--  ELYZEA CASINO - guichet : achat et revente de jetons
--  Transaction atomique côté serveur : tout est vérifié (service ouvert, distance, solde, limites,
--  place dans l'inventaire) AVANT de débiter ; si le crédit échoue, le débit est annulé.
--  Chaque demande porte un numéro unique : renvoyée deux fois, elle n'est exécutée qu'une fois.
-- =========================================================
local S = Casino.settings
local done = {}   -- [src] = { [nonce] = résultat }

local function hourOpen(c)
    if not c.hoursOn then return true end
    local h = tonumber(os.date('%H'))
    local f, t = math.floor(c.hoursFrom or 0), math.floor(c.hoursTo or 0)
    if f == t then return true end
    if f < t then return h >= f and h < t end
    return h >= f or h < t
end
Casino.CashierOpen = function() return S.cashier.enabled == true and hourOpen(S.cashier) end

local function quote(kind, chips)
    local c = S.cashier
    if kind == 'buy' then
        local base = math.ceil(chips * (tonumber(c.buyRate) or 1))
        local fee = math.ceil(base * (tonumber(c.buyFeePct) or 0) / 100)
        return base + fee, fee
    end
    local base = math.floor(chips * (tonumber(c.sellRate) or 1))
    local fee = math.ceil(base * (tonumber(c.sellFeePct) or 0) / 100)
    return math.max(0, base - fee), fee
end

local function cashierPoint(src, pedId)
    local pt = Casino.points[tonumber(pedId) or -1]
    if not pt or pt.role ~= 'cashier' then return nil, 'Guichet introuvable.' end
    if not Casino.Near(src, pt, 'ped') then return nil, 'Approche-toi du guichet.' end
    return pt
end

Ely.callback.register('elyzea_casino:cashier:info', function(src, pedId)
    local pt, err = cashierPoint(src, pedId)
    if not pt then return { error = err } end
    local c = S.cashier
    local cash = 0
    local bank = 0
    pcall(function() cash = exports.elyzea_core:GetMoney(src, 'cash') bank = exports.elyzea_core:GetMoney(src, 'bank') end)
    return {
        name = pt.name ~= '' and pt.name or 'Caisse du casino',
        open = Casino.Enabled() and Casino.CashierOpen(), enabled = c.enabled, hoursOn = c.hoursOn, hoursFrom = c.hoursFrom, hoursTo = c.hoursTo,
        buyRate = c.buyRate, sellRate = c.sellRate, buyFeePct = c.buyFeePct, sellFeePct = c.sellFeePct,
        minTx = c.minTx, maxTx = c.maxTx, maxChips = c.maxChips, accounts = c.accounts,
        chips = Casino.Chips(src), cash = cash, bank = bank,
    }
end)

local function run(src, d)
    if not Casino.Enabled() then return false, 'Le casino est fermé.' end
    if not Casino.CashierOpen() then return false, 'Le guichet est fermé pour le moment.' end
    local pt, err = cashierPoint(src, d.pedId)
    if not pt then return false, err end
    local p = Casino.Player(src)
    if not p then return false, 'Personnage non chargé.' end
    local c = S.cashier
    local kind = d.kind == 'sell' and 'sell' or 'buy'
    local chips = math.tointeger(tonumber(d.chips))
    if not chips or chips <= 0 then return false, 'Quantité invalide.' end
    if chips < (c.minTx or 1) then return false, ('Minimum %d jetons par transaction.'):format(c.minTx) end
    if c.maxTx and c.maxTx > 0 and chips > c.maxTx then return false, ('Maximum %d jetons par transaction.'):format(c.maxTx) end
    local account = d.account == 'bank' and 'bank' or 'cash'
    if not (c.accounts or {})[account] then return false, account == 'bank' and 'Paiement par banque désactivé.' or 'Paiement en liquide désactivé.' end
    local money, fee = quote(kind, chips)
    local core = exports.elyzea_core

    if kind == 'buy' then
        if c.maxChips and c.maxChips > 0 and Casino.Chips(src) + chips > c.maxChips then
            return false, ('Tu ne peux pas détenir plus de %d jetons.'):format(c.maxChips)
        end
        local okCarry, can = pcall(function() return exports.elyzea_inventory:CanCarryItem(src, Config.ChipItem, chips) end)
        if okCarry and can == false then return false, 'Pas assez de place dans ton inventaire.' end
        if (core:GetMoney(src, account) or 0) < money then return false, ('Il te manque %d $.'):format(money - (core:GetMoney(src, account) or 0)) end
        if not core:RemoveMoney(src, account, money, 'casino-jetons') then return false, 'Paiement refusé.' end
        local ok, r = pcall(function() return exports.elyzea_inventory:AddItem(src, Config.ChipItem, chips) end)
        if not ok or r ~= true then
            core:AddMoney(src, account, money, 'casino-remboursement')   -- annulation complète
            return false, 'Impossible de te donner les jetons (inventaire plein) : tu as été remboursé.'
        end
    else
        if Casino.Chips(src) < chips then return false, 'Tu n\'as pas assez de jetons.' end
        if not Casino.TakeChips(src, chips) then return false, 'Retrait des jetons impossible.' end
        if money > 0 and not core:AddMoney(src, account, money, 'casino-revente') then
            exports.elyzea_inventory:AddItem(src, Config.ChipItem, chips)   -- annulation complète
            return false, 'Paiement impossible : tes jetons t\'ont été rendus.'
        end
    end
    MySQL.insert('INSERT INTO `casino_tx` (`citizenid`, `name`, `kind`, `chips`, `money`, `fee`, `account`, `cashier`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { p.cid, p.name, kind, chips, money, fee, account, tostring(pt.id) })
    return true, kind == 'buy' and ('Achat : %d jetons pour %d $.'):format(chips, money) or ('Revente : %d jetons contre %d $.'):format(chips, money),
        { chips = Casino.Chips(src), money = money }
end

Ely.callback.register('elyzea_casino:cashier:tx', function(src, d)
    if type(d) ~= 'table' then return false, 'Demande invalide.' end
    local nonce = tostring(d.nonce or '')
    if nonce == '' or #nonce > 40 then return false, 'Demande invalide.' end
    done[src] = done[src] or {}
    if done[src][nonce] then return table.unpack(done[src][nonce]) end   -- même demande renvoyée : même réponse, rien de refait
    local res = table.pack(Casino.Locked(src, 'cashier', run, src, d))
    done[src][nonce] = { table.unpack(res, 1, res.n) }
    return table.unpack(res, 1, res.n)
end)

AddEventHandler('playerDropped', function() done[source] = nil end)
