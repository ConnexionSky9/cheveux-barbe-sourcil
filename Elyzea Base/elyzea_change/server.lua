-- =========================================================
--  ELYZEA CHANGE - serveur
--  Ouverture : exports.elyzea_change:OpenFor(src, { name, toPesos, toCash, coords })  (appelé par admin_menu)
--  Le taux et la position viennent du serveur (jamais du joueur). Opération atomique :
--  tout est vérifié AVANT de débiter ; si le crédit échoue, le débit est annulé.
--  Une même demande (même numéro) renvoyée deux fois n'est faite qu'une fois.
-- =========================================================
Change = { sessions = {} }
local core = exports.elyzea_core
local function inv() return exports.elyzea_inventory end

local function clampRate(v, def)
    v = math.floor(tonumber(v) or def)
    return math.max(1, math.min(100000, v))
end

function Change.pesos(src)
    local ok, n = pcall(function() return inv():GetItemCount(src, Config.Item) end)
    return ok and math.floor(tonumber(n) or 0) or 0
end
function Change.cash(src)
    local ok, n = pcall(function() return core:GetMoney(src, Config.Account) end)
    return ok and math.floor(tonumber(n) or 0) or 0
end
local function balances(src) return { cash = Change.cash(src), pesos = Change.pesos(src) } end

-- Montant reçu pour un montant donné (arrondi vers le bas : jamais de pesos / $ créés par l'arrondi)
function Change.quote(s, dir, amount)
    if dir == 'buy' then return math.floor(amount * s.toPesos / 100) end
    return math.floor(amount * s.toCash / 100)
end

local function openFor(src, opts)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then return false end
    opts = type(opts) == 'table' and opts or {}
    local c = opts.coords
    local s = {
        name = tostring(opts.name or Config.Default.name):sub(1, 40),
        toPesos = clampRate(opts.toPesos, Config.Default.toPesos),
        toCash = clampRate(opts.toCash, Config.Default.toCash),
        coords = c and vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0) or GetEntityCoords(GetPlayerPed(src)),
    }
    Change.sessions[src] = s
    TriggerClientEvent('elyzea_change:open', src, {
        name = s.name, toPesos = s.toPesos, toCash = s.toCash, min = Config.MinAmount, max = Config.MaxAmount,
        coords = { x = s.coords.x, y = s.coords.y, z = s.coords.z }, money = balances(src),
    })
    return true
end
exports('OpenFor', openFor)
exports('GetPesos', function(src) return Change.pesos(tonumber(src)) end)

local function run(src, dir, amount)
    local s = Change.sessions[src]
    if not s then return false, 'Le guichet est fermé.' end
    if #(GetEntityCoords(GetPlayerPed(src)) - s.coords) > Config.MaxDistance then return false, 'Approche-toi du guichet.' end
    dir = dir == 'sell' and 'sell' or (dir == 'buy' and 'buy' or nil)
    if not dir then return false, 'Demande invalide.' end
    amount = math.tointeger(tonumber(amount))
    if not amount or amount < Config.MinAmount then return false, ('Montant minimum : %d.'):format(Config.MinAmount) end
    if amount > Config.MaxAmount then return false, ('Montant maximum : %d.'):format(Config.MaxAmount) end
    local out = Change.quote(s, dir, amount)
    if out < 1 then return false, 'Montant trop petit pour ce taux.' end

    if dir == 'buy' then
        -- $ liquide -> pesos
        if Change.cash(src) < amount then return false, ('Il te manque %d $ en liquide.'):format(amount - Change.cash(src)) end
        local okCarry, can = pcall(function() return inv():CanCarryItem(src, Config.Item, out) end)
        if okCarry and can == false then return false, 'Pas assez de place dans ton inventaire.' end
        local okPay, paid = pcall(function() return core:RemoveMoney(src, Config.Account, amount, 'change-vers-pesos') end)
        if not okPay or paid ~= true then return false, 'Paiement refusé.' end
        local ok, r = pcall(function() return inv():AddItem(src, Config.Item, out) end)
        if not ok or r ~= true then
            pcall(function() core:AddMoney(src, Config.Account, amount, 'change-annule') end)
            return false, 'Impossible de te donner les pesos (inventaire plein) : tu as été remboursé.'
        end
        return true, ('Change effectué : %d $ → %d pesos.'):format(amount, out)
    end
    -- pesos -> $ liquide
    if Change.pesos(src) < amount then return false, ('Il te manque %d pesos.'):format(amount - Change.pesos(src)) end
    local ok, r = pcall(function() return inv():RemoveItem(src, Config.Item, amount) end)
    if not ok or r ~= true then return false, 'Retrait des pesos impossible.' end
    local okAdd, added = pcall(function() return core:AddMoney(src, Config.Account, out, 'change-vers-dollars') end)
    if not okAdd or added ~= true then
        pcall(function() inv():AddItem(src, Config.Item, amount) end)
        return false, 'Paiement impossible : tes pesos t\'ont été rendus.'
    end
    return true, ('Change effectué : %d pesos → %d $.'):format(amount, out)
end

local busy, done = {}, {}
RegisterNetEvent('elyzea_change:convert', function(dir, amount, nonce)
    local src = source
    nonce = tostring(nonce or '')
    if nonce == '' or #nonce > 40 then return end
    done[src] = done[src] or {}
    local prev = done[src][nonce]
    if prev then return TriggerClientEvent('elyzea_change:result', src, prev[1], prev[2], balances(src)) end
    if busy[src] then return end
    busy[src] = true
    local okRun, ok, msg = pcall(run, src, dir, amount)
    busy[src] = nil
    if not okRun then ok, msg = false, 'Erreur du guichet, réessaie.' print('^1[elyzea_change] ' .. tostring(ok) .. '^0') end
    done[src][nonce] = { ok, msg }
    if ok then print(('[elyzea_change] %s [%d] : %s'):format(GetPlayerName(src) or '?', src, msg)) end
    TriggerClientEvent('elyzea_change:result', src, ok, msg, balances(src))
end)

RegisterNetEvent('elyzea_change:closed', function() Change.sessions[source] = nil end)
AddEventHandler('playerDropped', function() Change.sessions[source], busy[source], done[source] = nil, nil, nil end)
