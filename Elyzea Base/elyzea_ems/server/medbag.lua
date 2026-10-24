-- =====================================================================
--  ELYZEA EMS - serveur : MedicalBag (sac médical)
--  · Prise de service : 1 sac dans l'inventaire. Fin de service, départ,
--    connexion hors service : sac retiré de l'inventaire, sac posé supprimé.
--  · Utiliser l'objet : le client pose le sac au sol, le serveur le vérifie
--    puis retire l'objet de l'inventaire.
--  · Ouvrir : boutique gratuite de l'inventaire (contenu illimité, objets EMS),
--    fermée si l'EMS s'éloigne. Ramasser : le sac revient dans l'inventaire.
-- =====================================================================
local P = Ems
local MB = Config.MedicalBag or {}
if MB.enabled == false then return end
local INV = 'elyzea_inventory'
local ITEM = MB.item or 'medicbag'
local SHOP = 'ems_medbag'
local Bags = {}          -- [net] = { net, owner }
local Viewers = {}       -- [src] = net du sac ouvert
P.medbags = Bags

local MODELS = {}
for _, m in ipairs(MB.models or {}) do MODELS[type(m) == 'number' and m or GetHashKey(m)] = true end

local function Inv() return GetResourceState(INV) == 'started' end
local function Count(src)
    if not Inv() then return 0 end
    local ok, n = pcall(function() return exports[INV]:GetItemCount(src, ITEM) end)
    return ok and tonumber(n) or 0
end
local function Give(src)
    if not Inv() then return false end
    local ok, r = pcall(function() return exports[INV]:AddItem(src, ITEM, 1) end)
    return ok and r ~= false and r ~= nil
end
local function Take(src, n)
    if not Inv() or (n or 0) < 1 then return false end
    local ok, r = pcall(function() return exports[INV]:RemoveItem(src, ITEM, n) end)
    return ok and r ~= false and r ~= nil
end

local function Ent(net)
    net = tonumber(net)
    if not net then return nil end
    local e = NetworkGetEntityFromNetworkId(net)
    if e and e ~= 0 and DoesEntityExist(e) then return e end
    return nil
end
local function Near(src, ent, dist)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and ent ~= nil and #(GetEntityCoords(ped) - GetEntityCoords(ent)) <= dist
end
local function OnDuty(src) return P.duty and P.duty[src] == true end
local function Owned(src) local n = 0 for _, b in pairs(Bags) do if b.owner == src then n = n + 1 end end return n end

local function Publish()
    local out = {}
    for _, b in pairs(Bags) do out[#out + 1] = { net = b.net, owner = b.owner } end
    GlobalState.emsMedbags = out
end

local function CloseFor(src)
    if Viewers[src] then
        Viewers[src] = nil
        if Inv() then pcall(function() exports[INV]:CloseInventory(src) end) end
    end
end

local function RemoveBag(net)
    local b = Bags[net]
    if not b then return end
    Bags[net] = nil
    for src, n in pairs(Viewers) do if n == net then CloseFor(src) end end
    local e = Ent(net)
    if e then DeleteEntity(e) end
end

-- Contenu du sac : boutique gratuite de l'inventaire (illimitée, ouverte seulement par ce script)
local function RegisterBagShop()
    if not Inv() then return end
    local list = {}
    for _, name in ipairs(MB.items or {}) do list[#list + 1] = { name = name, price = 0 } end
    -- groupe qu'aucun métier ne porte : un joueur ne peut pas ouvrir cette boutique lui-même (événement client refusé),
    -- seul ce script l'ouvre (OpenInventory ne vérifie pas les groupes)
    pcall(function() exports[INV]:RegisterShop(SHOP, { name = 'MedicalBag', inventory = list, groups = { ['__ems_medbag'] = 99 } }) end)
end

-- ---------------------------------------------------------------------
-- Service : sac donné / retiré (appelé par server/service.lua › P.SetDuty)
-- ---------------------------------------------------------------------
function P.MedbagDuty(src, on)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then return end
    if on then
        if Count(src) < 1 and Give(src) then P.Notify(src, 'MedicalBag ajouté à votre inventaire.', 'inform') end
    else
        local n = Count(src)
        if n > 0 then Take(src, n) end
        CloseFor(src)
        local changed = false
        for net, b in pairs(Bags) do if b.owner == src then RemoveBag(net) changed = true end end
        if changed then Publish() end
    end
end

-- Connexion hors service : pas de sac dans l'inventaire (sac gardé d'une session précédente)
AddEventHandler('elyzea:server:playerLoaded', function(src)
    src = tonumber(src)
    SetTimeout(4000, function()
        if src and GetPlayerName(src) and not OnDuty(src) then
            local n = Count(src)
            if n > 0 then Take(src, n) end
        end
    end)
end)

-- Départ : ses sacs posés disparaissent
AddEventHandler('playerDropped', function()
    local src = source
    Viewers[src] = nil
    local changed = false
    for net, b in pairs(Bags) do if b.owner == src then RemoveBag(net) changed = true end end
    if changed then Publish() end
end)

-- ---------------------------------------------------------------------
-- Objet utilisé : poser le sac (le client le crée, le serveur valide)
-- ---------------------------------------------------------------------
local function RegisterUsable()
    if not Inv() then return end
    pcall(function()
        exports[INV]:RegisterUsableItem(ITEM, function(src)
            if not OnDuty(src) then P.Notify(src, 'Réservé aux EMS en service.', 'error') return false end
            if Owned(src) >= (MB.perEms or 1) then P.Notify(src, 'Votre sac est déjà posé : ramassez-le d\'abord.', 'error') return false end
            TriggerClientEvent('ems:client:medbagPlace', src)
            return false   -- l'objet est retiré quand le sac est vraiment posé (medbagRegister)
        end)
    end)
end

local A = {}
A.medbagRegister = function(src, d)
    local net = tonumber(d.net)
    local e
    for _ = 1, 20 do e = Ent(net) if e then break end Wait(50) end
    if not e then return { error = 'Sac introuvable.' } end
    local bad
    if not MODELS[GetEntityModel(e)] then bad = 'Objet non autorisé.'
    elseif Bags[net] then bad = 'Sac déjà posé.'
    elseif not Near(src, e, 4.0) then bad = 'Sac trop loin.'
    elseif Owned(src) >= (MB.perEms or 1) then bad = 'Votre sac est déjà posé.'
    elseif Count(src) < 1 or not Take(src, 1) then bad = 'Vous n\'avez pas de MedicalBag.' end
    if bad then DeleteEntity(e) return { error = bad } end
    Bags[net] = { net = net, owner = src }
    Publish()
    return { ok = true, message = 'MedicalBag posé : ALT sur le sac pour l\'ouvrir.' }
end

A.medbagOpen = function(src, d)
    local net = tonumber(d.net)
    local b = Bags[net]
    if not b then return { error = 'Sac introuvable.' } end
    if not Near(src, Ent(net), (MB.reach or 2.5) + 0.5) then return { error = 'Le sac est trop loin.' } end
    if not Inv() then return { error = 'Inventaire indisponible.' } end
    local ok, r = pcall(function() return exports[INV]:OpenInventory(src, 'shop', SHOP) end)
    if not ok or r == false then RegisterBagShop() ok, r = pcall(function() return exports[INV]:OpenInventory(src, 'shop', SHOP) end) end
    if not ok or r == false then return { error = 'Impossible d\'ouvrir le sac.' } end
    Viewers[src] = net
    return { ok = true }
end

A.medbagPickup = function(src, d)
    local net = tonumber(d.net)
    local b = Bags[net]
    if not b then return { error = 'Sac introuvable.' } end
    if not Near(src, Ent(net), (MB.reach or 2.5) + 0.5) then return { error = 'Le sac est trop loin.' } end
    if not Give(src) then return { error = 'Pas assez de place dans votre inventaire.' } end
    RemoveBag(net)
    -- le sac ramassé devient celui de la personne qui le ramasse
    Publish()
    return { ok = true, message = 'MedicalBag ramassé.' }
end

for name, fn in pairs(A) do P.Actions[name] = { perm = nil, duty = true, fn = fn } end

-- Sac ouvert : fermé si l'EMS s'éloigne, quitte son service, ou si le sac disparaît
CreateThread(function()
    while true do
        Wait(1000)
        for src, net in pairs(Viewers) do
            if not GetPlayerName(src) then Viewers[src] = nil
            elseif not OnDuty(src) or not Bags[net] or not Near(src, Ent(net), (MB.reach or 2.5) + 1.5) then CloseFor(src) end
        end
        -- sac supprimé par autre chose (nettoyage de la carte…) : oublié
        local changed = false
        for net in pairs(Bags) do if not Ent(net) then Bags[net] = nil changed = true end end
        if changed then Publish() end
    end
end)

-- Démarrage / redémarrage de l'inventaire : contenu du sac et objet utilisable enregistrés
CreateThread(function()
    local t = GetGameTimer() + 60000
    while not Inv() and GetGameTimer() < t do Wait(500) end
    RegisterBagShop()
    RegisterUsable()
end)
AddEventHandler('onResourceStart', function(res)
    if res == INV then SetTimeout(1000, function() RegisterBagShop() RegisterUsable() end) end
end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for net in pairs(Bags) do local e = Ent(net) if e then DeleteEntity(e) end end
end)

Publish()
