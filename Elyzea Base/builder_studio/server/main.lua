-- =========================================================
--  BUILDER STUDIO - SERVEUR : événements réseau
--  Chaque événement vérifie les permissions (staff admin_menu ou ACE, voir Perm).
-- =========================================================
local subscribers = {}   -- [projectId] = { [src] = true }
local rate = {}          -- anti-spam : [src] = { t, n }
local BPS = 250000       -- débit des gros envois (octets / s)

local function allowed(src)
    local now = GetGameTimer()
    local r = rate[src]
    if not r or now - r.t > 1000 then rate[src] = { t = now, n = 1 } return true end
    r.n = r.n + 1
    return r.n <= Config.Limits.maxOpsPerSecond
end

local function notify(src, msg, kind)
    if src and src > 0 then TriggerClientEvent('builder:notify', src, msg, kind or 'info') end
end

local function sendList(target)
    TriggerClientEvent('builder:projects', target, Projects.list())
end

local function subs(id)
    subscribers[id] = subscribers[id] or {}
    return subscribers[id]
end

-- Envoie un résultat d'opération à ceux qui ont le projet chargé (ou à tous s'il est publié)
local function broadcast(p, event, ...)
    if p.active then
        TriggerClientEvent(event, -1, ...)
    else
        for s in pairs(subs(p.id)) do TriggerClientEvent(event, s, ...) end
    end
end

local function sendProject(target, p)
    TriggerLatentClientEvent('builder:project:data', target, BPS, p)
end

CreateThread(function()
    Textures.load()
    Projects.init()
    local n = 0
    for _ in pairs(Projects.index.projects) do n = n + 1 end
    print(('[Builder] Builder Studio prêt : %d projet(s). Commande /%s'):format(n, Config.Command))
end)

-- ---------------------------------------------------------
--  Ouverture
-- ---------------------------------------------------------
RegisterNetEvent('builder:open', function()
    local src = source
    if not Perm.has(src, 'access') then
        notify(src, 'Tu n\'as pas accès au studio : il faut la permission staff « Builder Studio » (admin_menu › grades) ou l\'ACE ' .. Config.Ace.access .. '.', 'error')
        return
    end
    TriggerClientEvent('builder:opened', src, {
        perms = Perm.all(src),
        projects = Projects.list(),
        custom = Projects.custom,
        dims = Projects.dims,
        textures = Textures.public(),
    })
end)

-- Monde : projets publiés envoyés à chaque joueur à la connexion
RegisterNetEvent('builder:world', function()
    local src = source
    for id, e in pairs(Projects.index.projects) do
        if e.active then
            local p = Projects.get(id)
            if p then sendProject(src, p) end
        end
    end
end)

-- ---------------------------------------------------------
--  Projets
-- ---------------------------------------------------------
RegisterNetEvent('builder:project:create', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    local p, err = Projects.create(src, data.name, data.origin)
    if not p then return notify(src, err, 'error') end
    subs(p.id)[src] = true
    sendProject(src, p)
    sendList(src)
    notify(src, 'Projet « ' .. p.name .. ' » créé.', 'success')
end)

RegisterNetEvent('builder:project:load', function(id)
    local src = source
    if not Perm.has(src, 'access') then return end
    local p = Projects.get(id)
    if not p then return notify(src, 'Projet introuvable.', 'error') end
    subs(p.id)[src] = true
    sendProject(src, p)
end)

RegisterNetEvent('builder:project:close', function(id)
    local src = source
    if type(id) == 'string' and subscribers[id] then subscribers[id][src] = nil end
end)

RegisterNetEvent('builder:project:rename', function(id, name)
    local src = source
    local p, err = Projects.rename(src, id, name)
    if not p then return notify(src, err, 'error') end
    broadcast(p, 'builder:project:meta', Projects.summary(p))
    sendList(src)
end)

RegisterNetEvent('builder:project:duplicate', function(id, name)
    local src = source
    local p, err = Projects.duplicate(src, id, name)
    if not p then return notify(src, err, 'error') end
    sendList(src)
    notify(src, 'Projet dupliqué : « ' .. p.name .. ' ».', 'success')
end)

RegisterNetEvent('builder:project:delete', function(id)
    local src = source
    local p = Projects.get(id)
    local wasActive = p and p.active
    local ok, err = Projects.delete(src, id)
    if not ok then return notify(src, err, 'error') end
    if wasActive then TriggerClientEvent('builder:project:removed', -1, id)
    else for s in pairs(subs(id)) do TriggerClientEvent('builder:project:removed', s, id) end end
    subscribers[id] = nil
    sendList(src)
    notify(src, 'Projet supprimé.', 'success')
end)

RegisterNetEvent('builder:project:active', function(id, active)
    local src = source
    local p, err = Projects.setActive(src, id, active)
    if not p then return notify(src, err, 'error') end
    Projects.saveNow(p.id)
    if p.active then
        TriggerLatentClientEvent('builder:project:data', -1, BPS, p)
    else
        -- les joueurs qui ne l'éditent pas le retirent de leur monde
        TriggerClientEvent('builder:project:unpublished', -1, p.id)
    end
    sendList(src)
    notify(src, p.active and 'Projet publié : visible par tous les joueurs.' or 'Projet retiré du jeu.', 'success')
end)

RegisterNetEvent('builder:project:save', function(id)
    local src = source
    if not Perm.has(src, 'build') then return end
    if Projects.saveNow(id) then notify(src, 'Projet enregistré.', 'success') else notify(src, 'Échec de l\'enregistrement (voir console serveur).', 'error') end
end)

RegisterNetEvent('builder:project:snapshot', function(id, label)
    local src = source
    local n, err = Projects.snapshot(src, id, label)
    if not n then return notify(src, err, 'error') end
    Projects.saveNow(id)
    local p = Projects.get(id)
    broadcast(p, 'builder:project:meta', Projects.summary(p))
    notify(src, ('Point de restauration n°%d créé.'):format(n), 'success')
end)

RegisterNetEvent('builder:project:restore', function(id, n)
    local src = source
    local p, err = Projects.restore(src, id, tonumber(n))
    if not p then return notify(src, err, 'error') end
    Projects.saveNow(id)
    if p.active then TriggerLatentClientEvent('builder:project:data', -1, BPS, p)
    else for s in pairs(subs(id)) do sendProject(s, p) end end
    notify(src, 'Projet restauré.', 'success')
end)

RegisterNetEvent('builder:project:history', function(id)
    local src = source
    if not Perm.has(src, 'access') then return end
    local p = Projects.get(id)
    if p then TriggerClientEvent('builder:project:history', src, id, p.history or {}) end
end)

-- ---------------------------------------------------------
--  Opérations d'édition
-- ---------------------------------------------------------
RegisterNetEvent('builder:op', function(id, op, seq)
    local src = source
    if not allowed(src) then
        TriggerClientEvent('builder:rejected', src, id, seq, 'Trop d\'actions par seconde, ralentis.')
        return
    end
    local res, err = Projects.apply(src, id, op)
    if not res then
        TriggerClientEvent('builder:rejected', src, id, seq, err)
        return
    end
    local p = Projects.get(id)
    broadcast(p, 'builder:applied', id, res, src, seq, Projects.summary(p))
end)

-- ---------------------------------------------------------
--  Catalogue, dimensions, textures
-- ---------------------------------------------------------
RegisterNetEvent('builder:dims', function(list)
    local src = source
    if Projects.reportDims(src, list) then
        -- les autres éditeurs reçoivent les nouvelles mesures
        TriggerClientEvent('builder:dims', -1, Projects.dims)
    end
end)

RegisterNetEvent('builder:custom:add', function(item)
    local src = source
    local e, err = Projects.addCustom(src, item)
    if not e then return notify(src, err, 'error') end
    TriggerClientEvent('builder:custom', -1, Projects.custom)
    notify(src, 'Objet « ' .. e.model .. ' » ajouté au catalogue.', 'success')
end)

RegisterNetEvent('builder:custom:remove', function(model)
    local src = source
    local ok, err = Projects.removeCustom(src, model)
    if not ok then return notify(src, err, 'error') end
    TriggerClientEvent('builder:custom', -1, Projects.custom)
end)

RegisterNetEvent('builder:textures', function(id, list)
    local src = source
    local p, err = Projects.setTextures(src, id, list)
    if not p then return notify(src, err, 'error') end
    broadcast(p, 'builder:textures', id, p.textures)
    notify(src, 'Textures appliquées.', 'success')
end)

-- Bibliothèque de textures (importées en jeu)
RegisterNetEvent('builder:tex:upload', function(d)
    local src = source
    if not allowed(src) then return end
    local e, err = Textures.add(src, d)
    if not e then return notify(src, err, 'error') end
    TriggerClientEvent('builder:tex:list', -1, Textures.public())
    notify(src, ('Texture « %s » ajoutée à la bibliothèque.'):format(e.name), 'success')
end)
RegisterNetEvent('builder:tex:remove', function(id)
    local src = source
    local e, err = Textures.remove(src, id)
    if not e then return notify(src, err, 'error') end
    TriggerClientEvent('builder:tex:list', -1, Textures.public())
    notify(src, ('Texture « %s » supprimée de la bibliothèque.'):format(e.name), 'success')
end)
-- Image d'une texture : tout joueur (les projets publiés en ont besoin), à la demande
local texAsked = {}
RegisterNetEvent('builder:tex:get', function(id)
    local src = source
    if type(id) ~= 'string' or not allowed(src) then return end
    texAsked[src] = texAsked[src] or {}
    if texAsked[src][id] and GetGameTimer() - texAsked[src][id] < 10000 then return end
    texAsked[src][id] = GetGameTimer()
    local data = Textures.data(id)
    if data then TriggerLatentClientEvent('builder:tex:data', src, BPS, id, data) end
end)

-- ---------------------------------------------------------
--  Export
-- ---------------------------------------------------------
RegisterNetEvent('builder:export', function(id, opts)
    local src = source
    if type(opts) ~= 'table' then opts = {} end
    local res, err = Export.run(src, id, { name = opts.name, ymap = opts.ymap ~= false })
    if not res then return TriggerClientEvent('builder:exported', src, { ok = false, error = err }) end
    print(('[Builder] Export de %s par %s -> %s'):format(id, Perm.nameOf(src), res.path))
    res.ok = true
    TriggerClientEvent('builder:exported', src, res)
end)

-- ---------------------------------------------------------
--  Portes et ascenseurs (tous les joueurs)
-- ---------------------------------------------------------
local doorState = {}
local EV = GetCurrentResourceName()
RegisterNetEvent(EV .. ':door', function(key, open)
    local src = source
    if not allowed(src) or type(key) ~= 'string' or #key > 120 then return end
    doorState[key] = open == true or nil
    TriggerClientEvent(EV .. ':door', -1, key, open == true)
end)
RegisterNetEvent(EV .. ':doors', function()
    TriggerClientEvent(EV .. ':doors', source, doorState)
end)

-- ---------------------------------------------------------
--  Sauvegarde automatique + points de restauration automatiques
-- ---------------------------------------------------------
CreateThread(function()
    while true do
        Wait(Config.AutosaveSeconds * 1000)
        for id in pairs(Projects.dirty) do
            Projects.saveNow(id)
            if Config.AutoRestoreMinutes > 0 then
                local last = Projects.lastVersion[id] or 0
                if os.time() - last >= Config.AutoRestoreMinutes * 60 then
                    if last > 0 then Projects.snapshot(0, id, 'Automatique', true) end
                    Projects.lastVersion[id] = os.time()
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    rate[src] = nil
    texAsked[src] = nil
    for _, s in pairs(subscribers) do s[src] = nil end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then Projects.flush() end
end)

-- Console : builder_save (sauvegarde immédiate de tout)
RegisterCommand('builder_save', function(src)
    if src ~= 0 and not Perm.has(src, 'admin') then return end
    Projects.flush()
    print('[Builder] Tous les projets sont enregistrés.')
end, true)
