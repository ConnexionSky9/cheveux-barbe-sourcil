-- =====================================================================
--  ELYZEA DROGUES · serveur
--  · Rend chaque objet drogue utilisable (elyzea_inventory) ; 1 unité consommée par prise.
--  · Le serveur décide : drogue activée, délai entre deux prises, durée, joueur à terre ou en arène.
--  · Chaque prise est enregistrée pour le laboratoire EMS (exports.elyzea_ems:RecordConsumption).
--  · Réglages modifiables dans l'admin_menu (exports AdminData / AdminAction), gardés en base.
-- =====================================================================
local S = DrugRules.Defaults()
local active = {}     -- [src] = { [drugId] = fin (os.time) }
local lastUse = {}    -- [src] = { [drugId] = os.time de la dernière prise }
local ready = false

local function notify(src, msg, kind)
    pcall(function() exports.elyzea_core:Notify(src, msg, kind or 'inform') end)
end

-- ---------------------------------------------------------------- réglages (base de données)
local function save()
    MySQL.query('INSERT INTO `elyzea_drogues_settings` (`k`, `v`) VALUES (\'settings\', ?) ON DUPLICATE KEY UPDATE `v` = VALUES(`v`)', { json.encode(S) })
end

local function publicSettings()
    return { drugs = S.drugs, trip = S.trip, creatures = S.creatures }
end

local function pushSettings(target)
    TriggerClientEvent('elyzea_drogues:settings', target or -1, publicSettings())
end

CreateThread(function()
    MySQL.ready.await()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_drogues_settings` (`k` VARCHAR(32) NOT NULL PRIMARY KEY, `v` LONGTEXT NOT NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP) DEFAULT CHARSET=utf8mb4]])
    local raw = MySQL.scalar.await('SELECT `v` FROM `elyzea_drogues_settings` WHERE `k` = \'settings\'')
    if raw then
        local ok, v = pcall(json.decode, raw)
        local clean = ok and DrugRules.Clean(v) or nil
        if clean then S = clean end
    end
    ready = true
    pushSettings(-1)
end)
RegisterNetEvent('elyzea_drogues:requestSettings', function() if ready then pushSettings(source) end end)

-- ---------------------------------------------------------------- prise d'une drogue
local function canTake(src, id)
    local d, set = Config.Drugs[id], S.drugs[id]
    if not d or not set then return false, 'Drogue inconnue.' end
    if not set.enabled then return false, ('%s : désactivé sur le serveur.'):format(d.label) end
    local ped = GetPlayerPed(src)
    if ped == 0 or GetEntityHealth(ped) <= 0 then return false, 'Impossible pour le moment.' end
    local st = Player(src).state
    if st.emsDown or st.cuffed then return false, 'Impossible pour le moment.' end
    if Config.BlockInArena and st.pvpArena then return false, 'Pas pendant une partie d\'arène.' end
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

-- Démarre (ou prolonge) l'effet d'une drogue pour un joueur. test = staff (aucun objet, pas de délai ni d'enregistrement)
local function apply(src, id, test)
    local set = S.drugs[id]
    local now = os.time()
    active[src] = active[src] or {}
    local untilT = DrugRules.Extend(active[src][id], now, set.duration, Config.MaxStack)
    active[src][id] = untilT
    if not test then
        lastUse[src] = lastUse[src] or {}
        lastUse[src][id] = now
        needs(src, id)
        -- laboratoire EMS : la prise est enregistrée côté serveur (jamais par le client)
        if GetResourceState('elyzea_ems') == 'started' then
            pcall(function() exports.elyzea_ems:RecordConsumption(src, Config.Drugs[id].substance, 1) end)
        end
    end
    TriggerClientEvent('elyzea_drogues:take', src, id, untilT - now, test == true)
end

local function registerItems()
    local inv = exports.elyzea_inventory
    for id, d in pairs(Config.Drugs) do
        for _, item in ipairs(d.items) do
            pcall(function()
                inv:RegisterUsableItem(item, function(src)
                    local ok, why = canTake(src, id)
                    if not ok then notify(src, why, 'error') return false end
                    apply(src, id, false)
                    return true   -- une unité consommée
                end)
            end)
        end
    end
end
CreateThread(function()
    while GetResourceState('elyzea_inventory') ~= 'started' do Wait(500) end
    Wait(1000)
    registerItems()
end)
AddEventHandler('elyzea_inventory:ready', registerItems)
AddEventHandler('onResourceStart', function(res) if res == 'elyzea_inventory' then SetTimeout(2000, registerItems) end end)

-- Fin naturelle / joueur parti
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
AddEventHandler('playerDropped', function() active[source] = nil lastUse[source] = nil end)

-- Le client signale qu'il a arrêté ses effets (mort, à terre, réanimation)
RegisterNetEvent('elyzea_drogues:cleared', function() active[source] = nil end)

-- Pour d'autres ressources : exports.elyzea_drogues:IsHigh(source) / ClearEffects(source)
exports('IsHigh', function(src) src = tonumber(src) return active[src] ~= nil and next(active[src]) ~= nil end)
exports('ClearEffects', function(src)
    src = tonumber(src)
    active[src] = nil
    TriggerClientEvent('elyzea_drogues:stop', src)
end)

-- ---------------------------------------------------------------- admin_menu (onglet Drogues)
local function isAdmin(src)
    if src == 0 then return true end
    local ok, r = pcall(function() return exports.admin_menu:HasPermission(src, Config.Permission) end)
    return ok and r == true
end

function AdminData(src)
    if not isAdmin(src) then return { available = true, denied = true } end
    local drugs = {}
    for id, d in pairs(Config.Drugs) do
        drugs[#drugs + 1] = { id = id, label = d.label, icon = d.icon, desc = d.desc, items = d.items, substance = d.substance,
            enabled = S.drugs[id].enabled, duration = S.drugs[id].duration, cooldown = S.drugs[id].cooldown }
    end
    table.sort(drugs, function(a, b) return a.label < b.label end)
    local creatures = {}
    for _, c in ipairs(Config.Trip.creatures) do creatures[#creatures + 1] = { model = c.model, label = c.label, kind = c.kind, on = S.creatures[c.model] ~= false } end
    local now, users = os.time(), {}
    for s, list in pairs(active) do
        local l = {}
        for id, t in pairs(list) do if t > now then l[#l + 1] = { id = id, label = Config.Drugs[id].label, left = t - now } end end
        if #l > 0 and GetPlayerName(s) then users[#users + 1] = { id = s, name = GetPlayerName(s), drugs = l } end
    end
    table.sort(users, function(a, b) return a.id < b.id end)
    return { available = true, ready = ready, drugs = drugs, trip = S.trip, creatures = creatures, users = users,
        emsLinked = GetResourceState('elyzea_ems') == 'started' }
end
exports('AdminData', AdminData)

local A = {}
A.settings_save = function(_, d)
    local clean, err = DrugRules.Clean(d.settings)
    if not clean then return false, err end
    S = clean
    save()
    pushSettings(-1)
    return true, 'Réglages des drogues enregistrés (appliqués aux prochaines prises).'
end
A.settings_reset = function()
    S = DrugRules.Defaults()
    save()
    pushSettings(-1)
    return true, 'Réglages remis à ceux de config.lua.'
end
A.stop_player = function(_, d)
    local t = tonumber(d.id)
    if not t or not GetPlayerName(t) then return false, 'Joueur introuvable.' end
    active[t] = nil
    TriggerClientEvent('elyzea_drogues:stop', t)
    return true, ('Effets arrêtés pour %s.'):format(GetPlayerName(t))
end
A.test_self = function(src, d)
    local id = tostring(d.id or '')
    if not Config.Drugs[id] then return false, 'Drogue inconnue.' end
    if src == 0 then return false, 'En jeu seulement.' end
    apply(src, id, true)
    return true, ('Test : effet « %s » appliqué sur toi (aucun objet consommé, rien d\'enregistré pour le labo).'):format(Config.Drugs[id].label)
end

function AdminAction(src, name, data)
    if not isAdmin(src) then return false, 'Permission « ' .. Config.Permission .. ' » refusée.' end
    if not ready then return false, 'La ressource démarre, réessaie dans un instant.' end
    local fn = A[tostring(name)]
    if not fn then return false, 'Action inconnue.' end
    local ok, success, msg = pcall(fn, src, type(data) == 'table' and data or {})
    if not ok then
        print(('^1[elyzea_drogues] admin %s : %s^0'):format(tostring(name), tostring(success)))
        return false, 'Erreur interne (voir la console du serveur).'
    end
    return success, msg
end
exports('AdminAction', AdminAction)
