-- =========================================================
--  ELYZEA ANIMAUX - SERVEUR : démarrage, outils, objets, commandes
--  Le client ne décide de rien : achats, sorties, équipements,
--  soins et réglages sont revérifiés ici (propriété, distance,
--  objets, argent, limites, permissions).
-- =========================================================
local RES = GetCurrentResourceName()

-- ---------------------------------------------------------
--  Outils joueurs
-- ---------------------------------------------------------
function A.Player(src)
    local ok, p = pcall(function() return exports.elyzea_core:GetPlayer(src) end)
    return ok and p and p.PlayerData and p or nil
end

function A.Cid(src)
    local p = A.Player(src)
    return p and p.PlayerData.citizenid or nil
end

function A.CharName(src)
    local p = A.Player(src)
    local ci = p and p.PlayerData.charinfo
    if ci and (ci.firstname or ci.lastname) then
        return (((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''))
    end
    return GetPlayerName(src) or ('#' .. tostring(src))
end

function A.Notify(src, msg, kind)
    if not src or src == 0 then return print('[ANIMAUX] ' .. tostring(msg)) end
    TriggerClientEvent('elyzea_animaux:client:notify', src, msg, kind or 'inform')
end

function A.IsStaff(src, perm)
    if src == 0 then return true end
    if GetResourceState(Config.AdminResource) ~= 'started' then return false end
    local ok, res = pcall(function() return exports[Config.AdminResource]:HasPermission(src, perm) end)
    return ok and res == true
end

function A.Log(src, action, details)
    details = tostring(details or '')
    print(('^5[ANIMAUX]^7 %s%s'):format(action, details ~= '' and (' | ' .. details) or ''))
    if GetResourceState(Config.AdminResource) == 'started' then
        pcall(function() exports[Config.AdminResource]:AddLog(src or 0, '[ANIMAUX] ' .. action, details) end)
    end
end

function A.ItemName(key) return Config.Items[key] end

function A.ItemLabel(key)
    local name = Config.Items[key] or key
    local ok, def = pcall(function() return exports.elyzea_inventory:Items(name) end)
    return ok and type(def) == 'table' and def.label or name
end

function A.ItemExists(name)
    local ok, def = pcall(function() return exports.elyzea_inventory:Items(name) end)
    return ok and type(def) == 'table'
end

function A.ItemCount(src, key)
    local ok, n = pcall(function() return exports.elyzea_inventory:GetItemCount(src, Config.Items[key] or key) end)
    return ok and tonumber(n) or 0
end

function A.RemoveItem(src, key, count, slot)
    local ok, res = pcall(function() return exports.elyzea_inventory:RemoveItem(src, Config.Items[key] or key, count or 1, nil, slot) end)
    return ok and res == true
end

function A.AddItem(src, key, count, meta)
    local name = Config.Items[key] or key
    local okC, can = pcall(function() return exports.elyzea_inventory:CanCarryItem(src, name, count or 1, meta) end)
    if not okC or not can then return false, 'full' end
    local ok, res = pcall(function() return exports.elyzea_inventory:AddItem(src, name, count or 1, meta) end)
    return ok and res == true
end

function A.Slot(src, slot)
    local ok, it = pcall(function() return exports.elyzea_inventory:GetSlot(src, slot) end)
    return ok and type(it) == 'table' and it or nil
end

function A.PedPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped), ped
end

-- Anti-spam : n actions par fenêtre et par joueur
local Buckets = {}
function A.Rate(src, key, max, windowMs)
    local now = GetGameTimer()
    local b = Buckets[src]
    if not b then b = {} Buckets[src] = b end
    local e = b[key]
    if not e or now - e.t > windowMs then e = { t = now, n = 0 } b[key] = e end
    e.n = e.n + 1
    return e.n <= max
end

-- Verrou par joueur : une seule action sensible à la fois (achats et sorties simultanés)
A.Busy = {}
function A.Locked(src, fn)
    if A.Busy[src] then return false, 'Une action est déjà en cours, patiente.' end
    A.Busy[src] = true
    local res = table.pack(pcall(fn))
    A.Busy[src] = nil
    if not res[1] then
        print(('^1[ANIMAUX] Erreur : %s^7'):format(tostring(res[2])))
        return false, 'Erreur du serveur (voir la console).'
    end
    return table.unpack(res, 2, res.n)
end

-- ---------------------------------------------------------
--  Données publiques des vendeurs (envoyées à tous les joueurs)
-- ---------------------------------------------------------
function A.PublicVendors()
    local out = {}
    if not A.S.general or not A.S.general.enabled then return out end
    for _, v in ipairs(A.Vendors) do
        if v.enabled then
            out[#out + 1] = { id = v.id, label = v.label, x = v.x, y = v.y, z = v.z, h = v.h, model = v.model, scenario = v.scenario,
                distance = v.distance, blip = v.blip, vet = v.vet, accessories = v.accessories }
        end
    end
    return out
end

function A.ClientSettings()
    return { follow = A.S.follow, leash = A.S.leash, vehicle = A.S.vehicle, needs = { lowThreshold = A.S.needs.lowThreshold, enabled = A.S.needs.enabled },
        invincible = A.S.general.invincible, autoStore = { distance = A.S.general.autoStoreDistance, delay = A.S.general.storeDelay } }
end

local pushPending = false
function A.PushWorld()
    if pushPending then return end
    pushPending = true
    SetTimeout(250, function()
        pushPending = false
        TriggerClientEvent('elyzea_animaux:client:world', -1, { vendors = A.PublicVendors(), settings = A.ClientSettings(), farm = A.PublicFarm and A.PublicFarm() or {} })
    end)
end

RegisterNetEvent('elyzea_animaux:server:hello', function()
    local src = source
    if not A.Ready or not A.Rate(src, 'hello', 4, 10000) then return end
    TriggerClientEvent('elyzea_animaux:client:world', src, { vendors = A.PublicVendors(), settings = A.ClientSettings(), farm = A.PublicFarm and A.PublicFarm() or {} })
    if A.SendActive then A.SendActive(src) end
end)

-- ---------------------------------------------------------
--  Démarrage
-- ---------------------------------------------------------
CreateThread(function()
    Wait(0)   -- laisse se charger les autres fichiers serveur (pets, shop, farm, admin) avant de démarrer
    MySQL.ready.await()
    local ok, err = pcall(A.Load)
    if not ok then
        print(('^1[ANIMAUX] Chargement impossible : %s^7'):format(tostring(err)))
        A.Diag.loadErrors[#A.Diag.loadErrors + 1] = tostring(err)
        A.S = A.SanitizeSettings({}, Config.Defaults)
        A.Species = A.SanitizeSpecies({})
        A.Vendors = A.SanitizeVendors(Config.Vendors)
        A.Farm = A.SanitizeFarm({}, Config.Farm)
    end
    -- Après un redémarrage, aucune entité d'animal n'existe plus : « sorti » redevient « rangé »
    pcall(function() MySQL.update.await("UPDATE `elyzea_animaux` SET `status` = 'stored' WHERE `status` = 'out'") end)
    A.Ready = true
    if A.FarmBoot then A.FarmBoot() end
    local n = MySQL.scalar.await('SELECT COUNT(*) FROM `elyzea_animaux`') or 0
    print(('^5[ANIMAUX]^7 Prêt : %d animal(aux) enregistré(s), %d vendeur(s), %d enclos.'):format(tonumber(n) or 0, #A.Vendors, #A.Farm.enclosures))
    A.PushWorld()
end)

-- ---------------------------------------------------------
--  Objets utilisables (le client choisit l'animal le plus proche)
-- ---------------------------------------------------------
local function useItem(kind)
    return function(src, item)
        if not A.Ready then return false end
        TriggerClientEvent('elyzea_animaux:client:useItem', src, kind, item and item.slot or nil, item and item.metadata or nil)
        return false   -- retiré par le serveur seulement quand l'action est faite
    end
end

local function registerItems()
    if GetResourceState('elyzea_inventory') ~= 'started' then return end
    for _, k in ipairs({ 'harness', 'leash', 'food', 'treat', 'medkit', 'feed' }) do
        pcall(function() exports.elyzea_inventory:RegisterUsableItem(Config.Items[k], useItem(k)) end)
    end
end
CreateThread(function() Wait(1000) registerItems() end)
AddEventHandler('onResourceStart', function(res) if res == 'elyzea_inventory' then SetTimeout(2000, registerItems) end end)

-- ---------------------------------------------------------
--  Commandes staff de diagnostic
-- ---------------------------------------------------------
RegisterCommand('animaux_diag', function(src)
    if src ~= 0 and not A.IsStaff(src, Config.AdminPerms.manage) then return end
    local d = A.DiagData and A.DiagData() or {}
    local lines = {
        ('Prêt : %s · animaux sortis : %d · enclos actifs : %d'):format(tostring(A.Ready), d.out or 0, d.farmActive or 0),
        ('Vendeurs : %d (%d actifs) · erreurs de sauvegarde : %d · problèmes signalés par les clients : %d'):format(#A.Vendors, d.vendorsOn or 0, #A.Diag.saveErrors, d.issues or 0),
        ('Modèles scannés : %d · manquants : %s'):format(d.scanned or 0, (d.missingModels and #d.missingModels > 0) and table.concat(d.missingModels, ', ') or 'aucun'),
    }
    for _, l in ipairs(lines) do
        if src == 0 then print('[ANIMAUX] ' .. l) else A.Notify(src, l, 'inform') end
    end
end, false)

RegisterCommand('animaux_scan', function(src)
    if src == 0 then return print('[ANIMAUX] /animaux_scan se lance en jeu (le scan lit les modèles chargés par ton client).') end
    if not A.IsStaff(src, Config.AdminPerms.manage) then return end
    A.RequestScan(src)
end, false)

function A.RequestScan(src)
    local models, seen = {}, {}
    for sid in pairs(Config.Species) do
        local sp = A.SpeciesEff(sid)
        for _, v in ipairs(sp.variants) do if not seen[v.model] then seen[v.model] = true models[#models + 1] = v.model end end
    end
    for _, m in ipairs(Config.VendorModels) do if not seen[m] then seen[m] = true models[#models + 1] = m end end
    table.sort(models)
    A.ScanToken = A.ScanToken or {}
    A.ScanToken[src] = os.time()
    TriggerClientEvent('elyzea_animaux:client:scan', src, models)
    A.Notify(src, ('Scan de %d modèle(s) en cours…'):format(#models), 'inform')
end

RegisterNetEvent('elyzea_animaux:server:scanResult', function(results)
    local src = source
    if not A.ScanToken or not A.ScanToken[src] or os.time() - A.ScanToken[src] > 300 then return end
    A.ScanToken[src] = nil
    if not A.IsStaff(src, Config.AdminPerms.manage) then return end
    local who = GetPlayerName(src) or tostring(src)
    local clean = {}
    for model, r in pairs(type(results) == 'table' and results or {}) do
        if type(r) == 'table' then r.by, r.at = who, os.time() clean[model] = r end
    end
    clean = A.SanitizeScan(clean)
    local n, missing = 0, 0
    for model, r in pairs(clean) do A.Scan[model] = r n = n + 1 if not r.exists then missing = missing + 1 end end
    A.SaveSection('scan', A.Scan)
    A.Notify(src, ('Scan terminé : %d modèle(s), %d introuvable(s). Résultat dans le menu › Diagnostic.'):format(n, missing), missing > 0 and 'warning' or 'success')
    A.Log(src, 'Scan des modèles', ('%d modèle(s), %d introuvable(s)'):format(n, missing))
end)

-- Problèmes constatés en jeu (modèle introuvable, commande sans animation…) : diagnostic
RegisterNetEvent('elyzea_animaux:server:issue', function(kind, what)
    local src = source
    if not A.Rate(src, 'issue', 10, 60000) then return end
    kind, what = Ani.Text(kind, 30, nil), Ani.Text(what, 120, nil)
    if not kind or not what then return end
    local key = kind .. '|' .. what
    local e = A.Diag.clientIssues[key]
    if not e then
        local n = 0
        for _ in pairs(A.Diag.clientIssues) do n = n + 1 end
        if n >= 100 then return end
        e = { kind = kind, what = what, count = 0 }
        A.Diag.clientIssues[key] = e
    end
    e.count, e.last = e.count + 1, os.time()
end)

AddEventHandler('playerDropped', function()
    local src = source
    Buckets[src] = nil
    A.Busy[src] = nil
end)
