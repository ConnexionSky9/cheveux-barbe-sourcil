-- =========================================================
--  GARDES DU CORPS - SERVEUR (permission « guards », SuperAdmin et Fondateur)
--  Le serveur autorise l'apparition (nombre, modèle, arme), garde la liste des
--  PNJ de chaque staff pour les supprimer à sa déconnexion, et pose les
--  menottes sur un joueur via elyzea_police. Les ordres (F11) sont exécutés
--  par le client du staff, propriétaire de ses PNJ.
-- =========================================================
local AM = AdminMenu
local GC = Config.Guards
local Owned = {}   -- [src] = { [netId] = true }

local MODELS, WEAPONS = {}, {}
for _, m in ipairs(GC.models) do MODELS[m.id] = true end
for _, w in ipairs(GC.weapons) do WEAPONS[w.id] = true end

local function count(src) local n = 0 for _ in pairs(Owned[src] or {}) do n = n + 1 end return n end

local function deleteAll(src)
    for netId in pairs(Owned[src] or {}) do
        local ent = NetworkGetEntityFromNetworkId(netId)
        if ent and ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    Owned[src] = nil
end

local A = {}

function A.spawn(src, d)
    local n = math.floor(tonumber(d.count) or 0)
    local free = GC.max - count(src)
    if n < 1 then return AM.notify(src, 'Nombre invalide.', 'error') end
    if free <= 0 then return AM.notify(src, ('Tu as déjà %d gardes (maximum).'):format(GC.max), 'error') end
    n = math.min(n, free)
    local model = tostring(d.model or '')
    if not MODELS[model] and not model:match('^[%w_]+$') then return AM.notify(src, 'Modèle invalide.', 'error') end
    local weapon = tostring(d.weapon or '')
    if not WEAPONS[weapon] then weapon = '' end
    TriggerClientEvent('adminmenu:guards:spawn', src, { count = n, model = model, weapon = weapon, armor = d.armor == true, invincible = d.invincible == true })
    AM.addLog(src, 'Gardes du corps', ('%d × %s · %s'):format(n, model, weapon ~= '' and weapon or 'sans arme'))
end

-- Le client confirme ses PNJ (netIds) : on les retient pour le nettoyage
function A.register(src, d)
    Owned[src] = Owned[src] or {}
    for _, id in ipairs(type(d.add) == 'table' and d.add or {}) do
        id = tonumber(id)
        if id and count(src) < GC.max then Owned[src][id] = true end
    end
    for _, id in ipairs(type(d.remove) == 'table' and d.remove or {}) do
        id = tonumber(id)
        if id then Owned[src][id] = nil end
    end
end

function A.clear(src)
    TriggerClientEvent('adminmenu:guards:clear', src)
    SetTimeout(1500, function() deleteAll(src) end)
    AM.notify(src, 'Gardes du corps supprimés.', 'success')
end

-- Menottes sur un joueur (posées par un garde à côté de lui)
function A.cuff(src, d)
    local target = tonumber(d.target)
    if not target or not GetPlayerName(target) or target == src then return end
    local guard = NetworkGetEntityFromNetworkId(tonumber(d.guard) or 0)
    if not guard or guard == 0 or not (Owned[src] or {})[tonumber(d.guard)] then return AM.notify(src, 'Garde introuvable.', 'error') end
    if #(GetEntityCoords(guard) - GetEntityCoords(GetPlayerPed(target))) > 4.0 then return AM.notify(src, 'Le garde est trop loin de la personne.', 'error') end
    if GetResourceState('elyzea_police') ~= 'started' then return AM.notify(src, 'La ressource elyzea_police n\'est pas démarrée.', 'error') end
    local ok = pcall(function() exports.elyzea_police:SetCuffed(target, d.on == true, GetPlayerName(src)) end)
    if ok then
        AM.notify(src, d.on and 'Personne menottée par ton garde.' or 'Personne démenottée par ton garde.', 'success')
        AM.addLog(src, d.on and 'Gardes : menottage' or 'Gardes : démenottage', ('%s [%d]'):format(GetPlayerName(target), target))
    end
end

AM.Actions.guards = { perm = 'guards', minLevel = 40, noRefresh = true, fn = function(src, d)
    local fn = A[tostring(d.name or '')]
    if fn then fn(src, type(d.data) == 'table' and d.data or {}) end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'guards') then return end
    data.guards = { count = count(src), max = GC.max, models = GC.models, weapons = GC.weapons }
end)

AddEventHandler('playerDropped', function() deleteAll(source) end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(Owned) do deleteAll(src) end
end)
