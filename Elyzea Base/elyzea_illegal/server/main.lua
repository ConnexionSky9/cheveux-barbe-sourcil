-- =========================================================
--  ELYZEA ILLÉGAL - DÉMARRAGE, CONNEXIONS, EXPORTS
-- =========================================================
local Loaded = {}   -- [src] = citizenid (pour la dernière connexion à la déconnexion)

-- Tous les fichiers serveur sont-ils chargés ? (après une mise à jour qui ajoute des fichiers,
-- FiveM ne relit fxmanifest.lua qu'après « refresh » : un simple « restart » ne suffit pas)
local REQUIRED = { 'DB', 'Log', 'Players', 'Cache', 'Sync', 'Groups', 'Grades', 'Members', 'Finances', 'Peds', 'Orders',
    'Deliveries', 'Stashes', 'Missions', 'Tablet' }
local FILES = { Deliveries = 'server/deliveries.lua', Stashes = 'server/stashes.lua', Missions = 'server/missions/core.lua', Tablet = 'server/tablet.lua' }
-- Missions (types) : fichiers attendus
CreateThread(function()
    Wait(0)
    if Missions and not Missions.types.fourgon then print('^1[ILLEGAL] Fichier non chargé : server/missions/fourgon.lua (refresh puis ensure elyzea_illegal)^7') end
end)
local missing = {}
for _, name in ipairs(REQUIRED) do if _G[name] == nil then missing[#missing + 1] = FILES[name] or name end end
if #missing > 0 then
    print(('^1[ILLEGAL] Fichiers non chargés : %s^7'):format(table.concat(missing, ', ')))
    print('^1[ILLEGAL] Vérifie qu\'ils sont bien dans resources/elyzea_illegal, puis dans la console serveur : refresh  puis  ensure elyzea_illegal^7')
end

CreateThread(function()
    DB.install()
    Cache.load()
    Sync.peds()   -- joueurs déjà connectés (redémarrage de la ressource)
    if Stashes then Stashes.registerAll() Stashes.sync() end
    if Missions then Missions.load() end
    for _, p in ipairs(GetPlayers()) do
        local src = tonumber(p)
        local cid = Players.cid(src)
        if cid then Loaded[src] = cid Sync.membership(src) end
    end
end)

-- Personnage chargé : le joueur retrouve son groupe, son grade et ses permissions
local function onLoaded(src)
    src = tonumber(src)
    if not src or not Cache.ready then return end
    local cid = Players.cid(src)
    if not cid then return end
    Loaded[src] = cid
    Members.touch(src)
    Sync.membership(src)
    Sync.peds(src)
    if Stashes then Stashes.sync(src) end
    if Deliveries then Deliveries.resend(src) end
end

-- Évènements serveur uniquement (AddEventHandler) : un client ne peut pas les déclencher
AddEventHandler('elyzea:server:playerLoaded', function(src)
    src = tonumber(src)
    if src then onLoaded(src) end
end)

-- Le client demande son état (démarrage de la ressource, reconnexion…)
RegisterNetEvent('illegal:server:hello', function()
    local src = source
    if not Players.rateLimit(src, 'hello', 3, 10000) then return end
    if not Cache.ready then return end
    Sync.peds(src)
    local cid = Players.cid(src)
    if cid then Loaded[src] = cid end
    Sync.membership(src)
    if Stashes then Stashes.sync(src) end
    if Deliveries then Deliveries.resend(src) end
end)

-- Changement de personnage / déconnexion : on enregistre la dernière connexion
local function onUnload(src)
    local cid = Loaded[src]
    Loaded[src] = nil
    Sessions[src] = nil
    local g = cid and Cache.group(Cache.memberOf[cid])
    if g and g.members[cid] then
        g.members[cid].lastSeen = os.time()
        DB.touchMember(cid, g.members[cid].name)
        Sync.group(g.id)
    end
end
AddEventHandler('elyzea:server:playerUnloaded', function(src) if tonumber(src) then onUnload(tonumber(src)) end end)
AddEventHandler('playerDropped', function() onUnload(source) end)

-- ---------------------------------------------------------
--  Exports pour d'autres ressources (lecture seule)
-- ---------------------------------------------------------
-- Groupe d'un joueur : { id, name, label, type, grade, gradeLevel, boss } ou nil
exports('GetPlayerGroup', function(src)
    local g, _, grade = Cache.membership(Players.cid(src))
    if not g then return nil end
    return { id = g.id, name = g.name, label = g.label, type = g.type, color = g.color, grade = grade.name, gradeLabel = grade.label, gradeLevel = grade.level, boss = grade.boss }
end)

-- Territoire à une position (elyzea_tags) : { id, name, owner = { id, label, color } | nil } ou nil
exports('GetTerritoryAt', function(coords)
    if type(coords) ~= 'table' and type(coords) ~= 'vector3' then return nil end
    local z = Territory.at(vector3(tonumber(coords.x) or 0.0, tonumber(coords.y) or 0.0, tonumber(coords.z) or 0.0))
    if not z then return nil end
    local owner
    for _, t in ipairs(Territory.list(nil)) do
        if t.id == z.id then owner = t.owner break end
    end
    return { id = z.id, name = z.name, owner = owner and { id = owner.id, label = owner.label, color = owner.color } or nil }
end)

exports('HasGroupPermission', function(src, perm)
    local _, _, grade = Cache.membership(Players.cid(src))
    return Cache.hasPerm(grade, perm)
end)

-- Groupes et leurs grades (coffres de l'éditeur de map d'admin_menu : accès « Groupes illégaux »)
exports('GetGroupList', function()
    local list = {}
    for _, g in pairs(Cache.groups) do
        local grades = {}
        for _, gr in ipairs(Cache.sortedGrades(g)) do grades[#grades + 1] = { level = gr.level, label = gr.label } end
        list[#list + 1] = { name = g.name, label = g.label, type = g.type, grades = grades }
    end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    return list
end)

-- ---------------------------------------------------------
--  Exports pour elyzea_labs (laboratoires des groupes)
-- ---------------------------------------------------------
-- Groupe d'un joueur avec l'identifiant du grade (droits par grade dans les laboratoires)
exports('GetPlayerGroupFull', function(src)
    local cid = Players.cid(src)
    local g, _, grade = Cache.membership(cid)
    if not g then return nil end
    return { id = g.id, name = g.name, label = g.label, color = g.color, cid = cid, gradeId = grade.id, gradeLabel = grade.label,
        gradeLevel = grade.level, boss = grade.boss == true }
end)

-- Groupe et ses grades (du plus bas au plus haut)
exports('GetGroupInfo', function(groupId)
    local g = Cache.group(groupId)
    if not g then return nil end
    local grades = {}
    for _, gr in ipairs(Cache.sortedGrades(g)) do grades[#grades + 1] = { id = gr.id, label = gr.label, level = gr.level, boss = gr.boss == true } end
    return { id = g.id, name = g.name, label = g.label, color = g.color, grades = grades, finance = { clean = g.finance.clean, dirty = g.finance.dirty } }
end)

-- Membres connectés d'un groupe : { { src, cid, gradeId, boss } }
exports('GetGroupOnline', function(groupId)
    local g = Cache.group(groupId)
    local out = {}
    if not g then return out end
    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        local cid = Players.cid(src)
        local m = cid and g.members[cid]
        if m then out[#out + 1] = { src = src, cid = cid, gradeId = m.gradeId, boss = g.grades[m.gradeId] and g.grades[m.gradeId].boss == true } end
    end
    return out
end)

-- Débit du compte du groupe (sous verrou, avec historique). account : 'clean' | 'dirty'
exports('GroupPay', function(groupId, account, amount, reason, src)
    local g = Cache.group(groupId)
    amount = math.floor(tonumber(amount) or 0)
    if not g then return false, 'Groupe introuvable.' end
    if amount <= 0 then return true end
    local actor = src and Players.actor(src) or { name = 'Laboratoire', cid = nil }
    local ok, err = Finances.payOrder(actor, g, account, amount, tostring(reason or 'Laboratoire'))
    if ok then Sync.group(g.id) end
    return ok, err
end)

-- Crédit du compte du groupe (remboursement, revente d'équipement)
exports('GroupCredit', function(groupId, account, amount, reason, src)
    local g = Cache.group(groupId)
    amount = math.floor(tonumber(amount) or 0)
    if not g or amount <= 0 or (account ~= 'clean' and account ~= 'dirty') then return false end
    if not Finances.lock(g.id) then return false end
    local before = g.finance[account]
    local ok = Finances.credit(g, account, amount)
    Finances.unlock(g.id)
    if ok then
        local actor = src and Players.actor(src) or { name = 'Laboratoire', cid = nil }
        local tx = { account = account, type = 'order', amount = amount, before = before, after = g.finance[account], actor = actor.name, actorCid = actor.cid, reason = tostring(reason or 'Laboratoire') }
        tx.id = DB.insertTransaction(g.id, tx)
        tx.created = os.time()
        Cache.pushTransaction(g, tx)
        Sync.group(g.id)
    end
    return ok
end)

-- Liste des groupes avec leur identifiant (menu admin des laboratoires)
exports('GetGroupIds', function()
    local list = {}
    for _, g in pairs(Cache.groups) do list[#list + 1] = { id = g.id, label = g.label, color = g.color } end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    return list
end)
