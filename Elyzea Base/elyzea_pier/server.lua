-- =====================================================================
--  ELYZEA PIER - SERVEUR : tickets, argent, vérifications, horloge commune, staff
--  Le serveur est la seule autorité : prix, débit, tickets, file d'attente, places,
--  départs, arrivées. Aucun événement client ne peut démarrer ni terminer un trajet.
-- =====================================================================
Pier = { busy = {}, locks = {}, rate = {} }

local RES = GetCurrentResourceName()
local core = function() return exports.elyzea_core end
local inv = function() return exports.elyzea_inventory end

-- ---------------------------------------------------------------- utilitaires
function Pier.Log(msg) print(('^5[elyzea_pier]^0 %s'):format(msg)) end

function Pier.Notify(src, msg, kind)
    TriggerClientEvent('elyzea_pier:notify', src, msg, kind or 'info')
end

function Pier.Identity(src)
    local ok, pd = pcall(function() return core():GetPlayerData(src) end)
    if not ok or type(pd) ~= 'table' or not pd.citizenid then return nil end
    local ci = pd.charinfo or {}
    local name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return { cid = pd.citizenid, name = name ~= '' and name or (GetPlayerName(src) or ('#' .. src)) }
end

function Pier.Pos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

function Pier.Dist(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end

function Pier.Near(src, point, radius)
    local p = Pier.Pos(src)
    return p ~= nil and Pier.Dist(p, point) <= radius
end

-- Limite de fréquence (seau à jetons) : protège contre les événements en rafale
function Pier.Allow(src)
    local now = GetGameTimer()
    local lim = Config.Security.maxRequestsPerSecond
    local r = Pier.rate[src]
    if not r then r = { tokens = lim, t = now } Pier.rate[src] = r end
    r.tokens = math.min(lim, r.tokens + (now - r.t) * lim / 1000)
    r.t = now
    if r.tokens < 1 then return false end
    r.tokens = r.tokens - 1
    return true
end

-- Une action sensible à la fois par joueur (double clic, requêtes simultanées)
function Pier.Locked(src, fn, ...)
    if Pier.locks[src] then return false, 'Action déjà en cours.' end
    Pier.locks[src] = true
    local res = table.pack(pcall(fn, ...))
    Pier.locks[src] = nil
    if not res[1] then
        Pier.Log('^1erreur : ' .. tostring(res[2]) .. '^0')
        return false, 'Erreur interne, réessaie.'
    end
    return table.unpack(res, 2, res.n)
end

-- Rappel serveur protégé (limite de fréquence + erreur rattrapée)
function Pier.Register(name, fn)
    Ely.callback.register('elyzea_pier:' .. name, function(src, ...)
        if not Pier.Allow(src) then return false, 'Trop de requêtes, patiente un instant.' end
        return fn(src, ...)
    end)
end

-- Le joueur peut-il monter dans une attraction ?
function Pier.CanRide(src)
    if not Pier.Identity(src) then return false, 'Personnage non chargé.' end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, 'Personnage introuvable.' end
    if GetEntityHealth(ped) <= 0 then return false, 'Impossible en étant mort.' end
    local st = Player(src).state
    if st.emsDown then return false, 'Impossible en étant à terre.' end
    if st.cuffed then return false, 'Impossible en étant menotté.' end
    if st.pvpArena then return false, 'Impossible pendant une partie.' end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'Descends d\'abord du véhicule.' end
    if GetPlayerRoutingBucket(src) ~= 0 then return false, 'Impossible depuis une instance.' end
    return true
end

-- ---------------------------------------------------------------- tickets (inventaire du serveur)
function Pier.TicketCount(src, kind)
    local t = Config.Tickets[kind]
    if not t then return 0 end
    local ok, n = pcall(function() return inv():GetItemCount(src, t.item) end)
    return ok and (tonumber(n) or 0) or 0
end

-- Consommation d'UN ticket au moment de l'embarquement effectif (serveur seulement)
function Pier.TakeTicket(src, kind)
    local t = Config.Tickets[kind]
    if not t or Pier.TicketCount(src, kind) < 1 then return false end
    local ok, r = pcall(function() return inv():RemoveItem(src, t.item, 1) end)
    if ok and r == true then
        Pier.Log(('%s : ticket « %s » utilisé'):format((Pier.Identity(src) or {}).name or src, t.label))
        return true
    end
    return false
end

-- Remboursement d'un ticket (passager descendu avant le départ)
function Pier.GiveTicket(src, kind)
    local t = Config.Tickets[kind]
    local ok, r = pcall(function() return inv():AddItem(src, t.item, 1) end)
    return ok and r == true
end

-- ---------------------------------------------------------------- achat auprès du PNJ
local function nearNpc(src)
    local c = Config.Npc.coords
    return Pier.Near(src, { x = c.x, y = c.y, z = c.z }, Config.InteractDistance + 2.5)
end

Pier.Register('buy', function(src, kind, qty, account)
    return Pier.Locked(src, function()
        local t = Config.Tickets[tostring(kind or '')]
        if not t then return false, 'Ticket inconnu.' end
        if not nearNpc(src) then return false, 'Approche-toi de la billetterie.' end
        local id = Pier.Identity(src)
        if not id then return false, 'Personnage non chargé.' end
        qty = math.tointeger(tonumber(qty))
        if not qty or qty < 1 or qty > Config.MaxTicketsPerPurchase then
            return false, ('Quantité invalide (1 à %d).'):format(Config.MaxTicketsPerPurchase)
        end
        account = account == 'bank' and 'bank' or 'cash'
        if not Config.Accounts[account] then return false, account == 'bank' and 'Paiement par carte refusé ici.' or 'Paiement en liquide refusé ici.' end
        if Config.MaxTicketsOwned > 0 and Pier.TicketCount(src, kind) + qty > Config.MaxTicketsOwned then
            return false, ('Tu ne peux pas avoir plus de %d tickets %s.'):format(Config.MaxTicketsOwned, t.label)
        end
        local okCarry, can = pcall(function() return inv():CanCarryItem(src, t.item, qty) end)
        if okCarry and can == false then return false, 'Pas assez de place dans ton inventaire.' end
        local price = math.floor(t.price) * qty
        local have = tonumber(core():GetMoney(src, account)) or 0
        if have < price then return false, ('Il te manque %d $ (%s).'):format(price - have, account == 'bank' and 'banque' or 'liquide') end
        if not core():RemoveMoney(src, account, price, 'parc de Del Perro : tickets') then return false, 'Paiement refusé.' end
        local ok, r = pcall(function() return inv():AddItem(src, t.item, qty) end)
        if not ok or r ~= true then
            core():AddMoney(src, account, price, 'parc de Del Perro : remboursement')   -- annulation complète
            return false, 'Impossible de te donner les tickets : tu as été remboursé.'
        end
        Pier.Log(('%s achète %d ticket(s) %s pour %d $ (%s)'):format(id.name, qty, t.label, price, account))
        return true, ('%d ticket(s) %s acheté(s) pour %d $.'):format(qty, t.label, price), Pier.InfoFor(src)
    end)
end)

-- Informations pour l'interface (tickets possédés, prix, places, attente)
function Pier.InfoFor(src)
    local out = { accounts = Config.Accounts, max = Config.MaxTicketsPerPurchase, rides = {} }
    for kind, t in pairs(Config.Tickets) do
        local ride = kind == 'wheel' and Wheel or Coaster
        local r = { kind = kind, label = t.label, price = t.price, owned = Pier.TicketCount(src, kind), enabled = ride ~= nil and ride.Enabled() }
        if ride then
            r.capacity, r.free, r.queue, r.wait = ride.Capacity(), ride.Free(), ride.QueueLength(), ride.EstimatedWait(src)
            r.status = ride.Status()
        end
        out.rides[kind] = r
    end
    out.money = { cash = tonumber(core():GetMoney(src, 'cash')) or 0, bank = tonumber(core():GetMoney(src, 'bank')) or 0 }
    return out
end

Pier.Register('info', function(src) return true, Pier.InfoFor(src) end)

-- Horloge commune : le client calcule l'écart avec le serveur (aller-retour mesuré)
Ely.callback.register('elyzea_pier:time', function() return GetGameTimer() end)

-- Quitter une file d'attente (ou descendre du train avant le départ : ticket rendu)
Pier.Register('leave', function(src)
    local b = Pier.busy[src]
    if b == 'wheel' then return Wheel.Leave(src) end
    if b == 'coaster' then return Coaster.Leave(src) end
    return true
end)

-- ---------------------------------------------------------------- départ d'un joueur
AddEventHandler('playerDropped', function()
    local src = source
    if Wheel then Wheel.Drop(src) end
    if Coaster then Coaster.Drop(src) end
    Pier.busy[src], Pier.locks[src], Pier.rate[src] = nil, nil, nil
end)

-- ---------------------------------------------------------------- staff
local function isStaff(src)
    if src == 0 then return true end
    if IsPlayerAceAllowed(src, Config.AcePermission) then return true end
    if GetResourceState('admin_menu') == 'started' then
        local ok, r = pcall(function() return exports.admin_menu:HasPermission(src, 'editor_peds') end)
        return ok and r == true
    end
    return false
end
Pier.IsStaff = isStaff

RegisterCommand('pier_info', function(src)
    if not isStaff(src) then return end
    local lines = { Wheel.Describe(), Coaster.Describe() }
    for _, l in ipairs(lines) do if src == 0 then print(l) else Pier.Notify(src, l, 'info') end end
end, false)

RegisterCommand('pier_reset', function(src)
    if not isStaff(src) then return end
    Wheel.Reset('remise à zéro par le staff')
    Coaster.Reset('remise à zéro par le staff')
    Pier.Log('attractions remises à zéro par ' .. (src == 0 and 'la console' or (Pier.Identity(src) or {}).name or src))
end, false)

-- Position actuelle (pour régler config.lua) : affichée en jeu et dans la console serveur
RegisterCommand('pier_here', function(src)
    if src == 0 or not isStaff(src) then return end
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    local line = ('vector4(%.2f, %.2f, %.2f, %.1f)'):format(c.x, c.y, c.z - 1.0, GetEntityHeading(ped))
    Pier.Log('position : ' .. line)
    Pier.Notify(src, 'Position (copiée dans la console serveur) : ' .. line, 'info')
end, false)

exports('IsOnRide', function(src) return Pier.busy[tonumber(src)] ~= nil end)
