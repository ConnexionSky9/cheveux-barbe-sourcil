-- =====================================================================
--  ELYZEA DROGUES · consommation (serveur)
--  · Chaque produit de config/products.lua devient « utilisable » (elyzea_inventory) : 1 unité retirée
--    par l'inventaire seulement si le serveur accepte la prise (drogue activée, délai, état du joueur).
--  · Durée = réglage de la drogue × force du produit ; reprendre prolonge (plafonné).
--  · Prise enregistrée pour le laboratoire EMS (exports.elyzea_ems:RecordConsumption).
--  · Fumée colorée : le client qui fume demande au serveur de prévenir les joueurs proches (limité).
-- =====================================================================
local active = {}       -- [src] = { [drugId] = fin (os.time) }
local lastUse = {}      -- [src] = { [drugId] = os.time }
local lastSmoke = {}    -- [src] = { untilT, color, lastPuff }

local function S() return DS.S end

local function canTake(src, id)
    local d, set = Config.Drugs[id], S().drugs[id]
    if not d or not set then return false, 'Drogue inconnue.' end
    if not set.enabled then return false, ('%s : désactivé sur le serveur.'):format(d.label) end
    local ok, why = DS.CanAct(src)
    if not ok then return false, why end
    if Config.BlockInArena and Player(src).state.pvpArena then return false, 'Pas pendant une partie d\'arène.' end
    local last = (lastUse[src] or {})[id]
    if last and os.time() - last < set.cooldown then
        return false, ('Attends encore %d s avant d\'en reprendre.'):format(set.cooldown - (os.time() - last))
    end
    return true
end

-- Besoins : le cannabis donne faim et détend, la méth donne soif et stresse (jamais sous 0)
local NEEDS = { weed = { -10, 0, -15 }, meth = { 0, -15, 5 }, ecstasy = { 0, -10, -10 }, opiates = { 0, 0, -10 } }
local function needs(src, id)
    local n = NEEDS[id]
    if not n then return end
    pcall(function()
        local pd = exports.elyzea_core:GetPlayerData(src)
        local md = pd and pd.metadata or {}
        local function cap(cur, delta) cur = tonumber(cur) or 0 if delta < 0 then return math.max(delta, -cur) end return delta end
        exports.elyzea_core:AddNeeds(src, cap(md.hunger, n[1]), cap(md.thirst, n[2]), cap(md.stress, n[3]))
    end)
end

-- Démarre (ou prolonge) l'effet. item = produit consommé (nil pour un test du staff)
local function apply(src, id, item, test)
    local set = S().drugs[id]
    local prod = item and Config.Products[item] or nil
    local duration = math.floor(set.duration * (prod and prod.mult or 1.0) + 0.5)
    local now = os.time()
    active[src] = active[src] or {}
    local untilT = DrugRules.Extend(active[src][id], now, duration, Config.MaxStack)
    active[src][id] = untilT
    if not test then
        lastUse[src] = lastUse[src] or {}
        lastUse[src][id] = now
        needs(src, id)
        if GetResourceState('elyzea_ems') == 'started' then
            pcall(function() exports.elyzea_ems:RecordConsumption(src, Config.Drugs[id].substance, 1) end)
        end
        DS.Log('conso', src, ('%s (%s)'):format(item or '?', id))
    end
    local color = DrugRules.SmokeColor(S(), prod)
    if color then lastSmoke[src] = { untilT = now + 15, color = color, lastPuff = 0 } end
    -- Force du produit (ex. gros gâteau aux champignons) : intensité × power
    local intensity = (tonumber(set.intensity) or 100) * (prod and tonumber(prod.power) or 1.0)
    TriggerClientEvent('elyzea_drogues:take', src, id, untilT - now, test == true, item, color, intensity)
end
DS.ApplyDrug = apply

local function registerItems()
    local inv = exports.elyzea_inventory
    for item, prod in pairs(Config.Products) do
        pcall(function()
            inv:RegisterUsableItem(item, function(src)
                local ok, why = canTake(src, prod.drug)
                if not ok then DS.Notify(src, why, 'error') return false end
                apply(src, prod.drug, item, false)
                return true   -- une unité consommée
            end)
        end)
    end
    for item, fn in pairs(DS.RegisterUsable or {}) do
        pcall(function() inv:RegisterUsableItem(item, function(src) return fn(src) end) end)
    end
end
CreateThread(function()
    while GetResourceState('elyzea_inventory') ~= 'started' do Wait(500) end
    Wait(1000)
    registerItems()
end)
AddEventHandler('elyzea_inventory:ready', registerItems)
AddEventHandler('onResourceStart', function(res) if res == 'elyzea_inventory' then SetTimeout(2000, registerItems) end end)

-- ---------------------------------------------------------------- fumée colorée (synchronisée)
-- Le client envoie une bouffée seulement pendant les 15 s qui suivent une prise qui fume ; la couleur
-- vient du serveur (jamais du client) ; envoyée aux seuls joueurs proches, 1 bouffée / seconde max.
RegisterNetEvent('elyzea_drogues:puff', function()
    local src = source
    local s = lastSmoke[src]
    local now = os.time()
    if not s or now > s.untilT or now - s.lastPuff < 1 then return end
    s.lastPuff = now
    local pos = DS.Pos(src)
    if not pos then return end
    local r2 = (Config.Smoke.syncRadius or 35.0) ^ 2
    for _, id in ipairs(GetPlayers()) do
        local t = tonumber(id)
        if t ~= src then
            local p = DS.Pos(t)
            if p then
                local dx, dy, dz = p.x - pos.x, p.y - pos.y, p.z - pos.z
                if dx * dx + dy * dy + dz * dz <= r2 then TriggerClientEvent('elyzea_drogues:puff', t, src, s.color) end
            end
        end
    end
end)

-- ---------------------------------------------------------------- suivi des effets
CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for src, list in pairs(active) do
            for id, t in pairs(list) do if t <= now then list[id] = nil end end
            if not next(list) then active[src] = nil end
        end
    end
end)
AddEventHandler('playerDropped', function() active[source] = nil lastUse[source] = nil lastSmoke[source] = nil end)
RegisterNetEvent('elyzea_drogues:cleared', function() active[source] = nil end)

function DS.HighUsers()
    local now, out = os.time(), {}
    for s, list in pairs(active) do
        local l = {}
        for id, t in pairs(list) do if t > now then l[#l + 1] = { id = id, label = Config.Drugs[id].label, left = t - now } end end
        if #l > 0 and GetPlayerName(s) then out[#out + 1] = { id = s, name = GetPlayerName(s), drugs = l } end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end
function DS.StopEffects(src)
    active[src] = nil
    TriggerClientEvent('elyzea_drogues:stop', src)
end

-- Pour d'autres ressources
exports('IsHigh', function(src) src = tonumber(src) return active[src] ~= nil and next(active[src]) ~= nil end)
exports('ClearEffects', function(src) DS.StopEffects(tonumber(src)) end)
exports('GetPrice', function(item) local p = DS.S.prices[tostring(item or '')] return p and p.price or 0 end)
