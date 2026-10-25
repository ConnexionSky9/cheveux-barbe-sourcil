-- =========================================================
--  REQUINS (permission « sharks_manage »)
--  · Zones dessinées en jeu + points d'apparition dans l'eau, sauvegardés dans data/sharks.json
--  · Les requins sont des PNJ réseau créés PAR LE SERVEUR, seulement quand un joueur est proche
--    de la zone (sinon le jeu ne les simule pas). Après un redémarrage ils reviennent tout seuls.
--  · Requin tué : son corps reste quelques secondes, puis il réapparaît à son point d'apparition
--    après le délai de la zone.
--  · Joueurs protégés (ajoutés par leur ID, enregistrés par licence) : jamais visés ni mordus.
--  · Le comportement (attaque des nageurs, rester dans la zone) est géré par client/sharks.lua.
-- =========================================================
local AM = AdminMenu
local C = Sharks.Cfg

local S = Storage.load('sharks', {})
S.enabled = S.enabled ~= false
S.areas = type(S.areas) == 'table' and S.areas or {}
S.immune = type(S.immune) == 'table' and S.immune or {}
S.nextId = tonumber(S.nextId) or 1

local function save() Storage.save('sharks', S) end
local function now() return os.time() end
local function str(v, max) return (tostring(v or ''):gsub('[%c]', ' '):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, max or 40) end
local function num(v, min, max, def)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return def end
    return math.max(min, math.min(max, v))
end
local function findArea(id)
    id = tonumber(id)
    for i, a in ipairs(S.areas) do if a.id == id then return a, i end end
end

-- ---------------------------------------------------------
--  Requins vivants (mémoire du serveur uniquement)
--  Live[areaId] = { lastNear = os.time(), slots = { [n] = { spawn = index, ent, state, deadAt, respawnAt } } }
--  state : 'none' (à créer), 'alive', 'dead' (attend la réapparition)
-- ---------------------------------------------------------
local Live = {}
local aliveTotal = 0

local function deleteEnt(ent)
    if ent and DoesEntityExist(ent) then DeleteEntity(ent) end
end

local function clearArea(id)
    local L = Live[id]
    if not L then return end
    for _, sl in ipairs(L.slots) do
        if sl.state == 'alive' then aliveTotal = math.max(0, aliveTotal - 1) end
        deleteEnt(sl.ent)
    end
    Live[id] = nil
end

-- (Re)construit les emplacements d'une zone à partir de ses points d'apparition
local function buildSlots(a)
    clearArea(a.id)
    local L = { lastNear = 0, slots = {} }
    for i, sp in ipairs(a.spawns or {}) do
        for _ = 1, math.floor(num(sp.count, 1, C.maxPerSpawn, 1)) do
            L.slots[#L.slots + 1] = { spawn = i, state = 'none' }
        end
    end
    Live[a.id] = L
end

-- ---------------------------------------------------------
--  Données envoyées à tous les clients (GlobalState) : zones actives et joueurs protégés
-- ---------------------------------------------------------
local function publish()
    local list = {}
    if S.enabled then
        for _, a in ipairs(S.areas) do
            if a.enabled and #(a.points or {}) >= 3 then
                local homes = {}
                for _, sp in ipairs(a.spawns or {}) do homes[#homes + 1] = { x = sp.x, y = sp.y, z = sp.z } end
                list[#list + 1] = { id = a.id, points = a.points, homes = homes }
            end
        end
    end
    GlobalState.sharkAreas = list
end

local function immuneLicenses()
    local set = {}
    for _, p in ipairs(S.immune) do set[p.license] = true end
    return set
end

local function publishImmune()
    local set, ids = immuneLicenses(), {}
    for _, p in ipairs(GetPlayers()) do
        local lic = AM.getLicense(tonumber(p))
        if lic and set[lic] then ids[tostring(p)] = true end
    end
    GlobalState.sharkImmune = ids
end

-- ---------------------------------------------------------
--  Création d'un requin
-- ---------------------------------------------------------
local function spawnShark(a, sl)
    local sp = a.spawns[sl.spawn]
    if not sp then return end
    local ang, d = math.random() * math.pi * 2, math.random() * 3.0
    local x, y, z = sp.x + math.cos(ang) * d, sp.y + math.sin(ang) * d, sp.z
    local ent = CreatePed(28, joaat(a.model or C.models[1].id), x, y, z, math.random(0, 359) + 0.0, true, true)
    local limit = GetGameTimer() + 2000
    while (not ent or ent == 0 or not DoesEntityExist(ent)) and GetGameTimer() < limit do Wait(50) end
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    -- zone supprimée / modifiée pendant l'attente
    if Live[a.id] == nil or not findArea(a.id) then DeleteEntity(ent) return end
    if SetEntityOrphanMode then SetEntityOrphanMode(ent, 0) end   -- retiré par le jeu si plus personne autour
    Entity(ent).state:set('shark', { a = a.id, x = sp.x, y = sp.y, z = sp.z }, true)
    sl.ent, sl.state = ent, 'alive'
    aliveTotal = aliveTotal + 1
end

local function playerNear(cx, cy, radius)
    local r2 = radius * radius
    for _, p in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(p)
        if ped ~= 0 then
            local c = GetEntityCoords(ped)
            local dx, dy = c.x - cx, c.y - cy
            if dx * dx + dy * dy <= r2 then return true end
        end
    end
    return false
end

-- ---------------------------------------------------------
--  Boucle : morts, réapparitions, apparition quand un joueur approche
-- ---------------------------------------------------------
local function tickArea(a, t)
    local L = Live[a.id]
    if not L then buildSlots(a) L = Live[a.id] end
    -- morts et disparitions (vérifié même sans joueur proche)
    for _, sl in ipairs(L.slots) do
        if sl.state == 'alive' then
            if not sl.ent or not DoesEntityExist(sl.ent) then
                sl.ent, sl.state = nil, 'none'                      -- retiré par le jeu : revient sans délai
                aliveTotal = math.max(0, aliveTotal - 1)
            elseif GetEntityHealth(sl.ent) <= 0 then
                sl.state, sl.deadAt, sl.respawnAt = 'dead', t, t + math.floor(num(a.respawn, C.minRespawn, C.maxRespawn, C.defaultRespawn))
                aliveTotal = math.max(0, aliveTotal - 1)
                a.kills = (tonumber(a.kills) or 0) + 1
                Storage.saveLater('sharks', S, 10000)
            end
        end
        if sl.state == 'dead' and sl.ent and t - sl.deadAt >= C.corpseSeconds then
            deleteEnt(sl.ent)
            sl.ent = nil
        end
    end
    local cx, cy, r = Sharks.bounds(a.points)
    if playerNear(cx, cy, r + C.activateDistance) then
        L.lastNear = t
        local made = 0
        for _, sl in ipairs(L.slots) do
            if made >= 4 or aliveTotal >= C.maxTotal then break end
            if sl.state == 'none' or (sl.state == 'dead' and t >= sl.respawnAt) then
                deleteEnt(sl.ent)
                sl.ent, sl.state = nil, 'none'
                spawnShark(a, sl)
                made = made + 1
            end
        end
    elseif t - (L.lastNear or 0) >= C.despawnAfter then
        -- plus personne : on retire les requins vivants (ils reviendront), les délais de réapparition continuent
        for _, sl in ipairs(L.slots) do
            if sl.state == 'alive' then
                deleteEnt(sl.ent)
                sl.ent, sl.state = nil, 'none'
                aliveTotal = math.max(0, aliveTotal - 1)
            end
        end
    end
end

CreateThread(function()
    Wait(5000)
    publish()
    publishImmune()
    while true do
        local t = now()
        for _, a in ipairs(S.areas) do
            if S.enabled and a.enabled and #(a.points or {}) >= 3 and #(a.spawns or {}) > 0 then
                local ok, err = pcall(tickArea, a, t)
                if not ok then print(('^1[AdminMenu] Requins (zone %s) : %s^7'):format(tostring(a.id), tostring(err))) end
            elseif Live[a.id] then
                clearArea(a.id)
            end
        end
        Wait(2000)
    end
end)

-- Joueurs protégés : mis à jour à l'arrivée / au départ
AddEventHandler('playerJoining', function() SetTimeout(3000, publishImmune) end)
AddEventHandler('playerDropped', function() SetTimeout(500, publishImmune) end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(Live) do clearArea(id) end
end)

-- ---------------------------------------------------------
--  Actions du menu
-- ---------------------------------------------------------
local function act(fn)
    return { perm = 'sharks_manage', fn = function(src, d)
        local msg, kind = fn(src, d)
        if msg then AM.notify(src, msg, kind or 'success') end
    end }
end
local A = AM.Actions

local function cleanPoint(p)
    if type(p) ~= 'table' then return nil end
    local x, y, z = num(p.x, -20000, 20000), num(p.y, -20000, 20000), num(p.z, -500, 2000)
    if not x or not y or not z then return nil end
    return x, y, z
end

A.sharks_settings = act(function(src, d)
    S.enabled = d.enabled == true
    save()
    publish()
    if not S.enabled then for id in pairs(Live) do clearArea(id) end end
    AM.addLog(src, 'Requins', S.enabled and 'Activés' or 'Désactivés (tous les requins retirés)')
    return S.enabled and 'Requins activés.' or 'Requins désactivés : tous les requins sont retirés.'
end)

-- Zone dessinée en jeu (création si id absent)
A.sharks_zone_save = act(function(src, d)
    local pts = {}
    for _, p in ipairs(type(d.points) == 'table' and d.points or {}) do
        local x, y, z = cleanPoint(p)
        if x then pts[#pts + 1] = { x = x, y = y, z = z } end
    end
    if #pts < 3 then return 'Pose au moins 3 coins.', 'error' end
    if #pts > C.maxZonePoints then return ('%d coins maximum.'):format(C.maxZonePoints), 'error' end
    local a = findArea(d.id)
    if not a then
        if #S.areas >= C.maxAreas then return ('%d zones maximum.'):format(C.maxAreas), 'error' end
        local name = str(d.name, 40)
        a = { id = S.nextId, name = name ~= '' and name or ('Zone requins %d'):format(S.nextId), enabled = true,
            model = C.models[1].id, respawn = C.defaultRespawn, points = {}, spawns = {}, kills = 0 }
        S.nextId = S.nextId + 1
        S.areas[#S.areas + 1] = a
    end
    a.points = pts
    -- points d'apparition qui ne sont plus dans la zone : retirés
    local kept, removed = {}, 0
    for _, sp in ipairs(a.spawns or {}) do
        if Sharks.inPoly(pts, sp.x, sp.y) then kept[#kept + 1] = sp else removed = removed + 1 end
    end
    a.spawns = kept
    buildSlots(a)
    save()
    publish()
    AM.addLog(src, 'Requins : zone', ('#%d %s (%d coins)'):format(a.id, a.name, #pts))
    return ('Zone « %s » enregistrée (%d coins)%s. %s'):format(a.name, #pts,
        removed > 0 and (', %d point(s) d\'apparition hors zone retiré(s)'):format(removed) or '',
        #a.spawns == 0 and 'Pose maintenant les points d\'apparition dans l\'eau.' or '')
end)

-- Points d'apparition (remplace la liste de la zone)
A.sharks_spawns_save = act(function(src, d)
    local a = findArea(d.id)
    if not a then return 'Zone introuvable.', 'error' end
    local list, total, outside = {}, 0, 0
    for _, p in ipairs(type(d.points) == 'table' and d.points or {}) do
        local x, y, z = cleanPoint(p)
        if x then
            if not Sharks.inPoly(a.points, x, y) then
                outside = outside + 1
            elseif #list < C.maxSpawnsPerArea then
                local n = math.floor(num(p.count, 1, C.maxPerSpawn, 1))
                n = math.min(n, C.maxPerArea - total)
                if n >= 1 then
                    list[#list + 1] = { x = x, y = y, z = z, count = n }
                    total = total + n
                end
            end
        end
    end
    a.spawns = list
    buildSlots(a)
    save()
    publish()
    AM.addLog(src, 'Requins : points d\'apparition', ('#%d %s : %d point(s), %d requin(s)'):format(a.id, a.name, #list, total))
    return ('%d point(s) d\'apparition, %d requin(s) dans « %s ».%s'):format(#list, total, a.name,
        outside > 0 and (' %d point(s) hors zone ignoré(s).'):format(outside) or '')
end)

A.sharks_spawn_count = act(function(src, d)
    local a = findArea(d.id)
    local sp = a and a.spawns[tonumber(d.index) or 0]
    if not sp then return 'Point introuvable.', 'error' end
    local others = 0
    for i, o in ipairs(a.spawns) do if i ~= tonumber(d.index) then others = others + (o.count or 1) end end
    local n = math.floor(num(d.count, 1, C.maxPerSpawn, 1))
    if others + n > C.maxPerArea then return ('%d requins maximum par zone.'):format(C.maxPerArea), 'error' end
    sp.count = n
    buildSlots(a)
    save()
    return nil
end)

A.sharks_spawn_delete = act(function(src, d)
    local a = findArea(d.id)
    local i = tonumber(d.index)
    if not a or not i or not a.spawns[i] then return 'Point introuvable.', 'error' end
    table.remove(a.spawns, i)
    buildSlots(a)
    save()
    publish()
    AM.addLog(src, 'Requins : point supprimé', ('#%d %s'):format(a.id, a.name))
    return 'Point d\'apparition supprimé.'
end)

A.sharks_area_update = act(function(src, d)
    local a = findArea(d.id)
    if not a then return 'Zone introuvable.', 'error' end
    if d.name ~= nil and str(d.name, 40) ~= '' then a.name = str(d.name, 40) end
    if d.enabled ~= nil then a.enabled = d.enabled == true end
    if d.model ~= nil and Sharks.modelOk(d.model) and d.model ~= a.model then a.model = d.model buildSlots(a) end
    if d.respawn ~= nil then a.respawn = math.floor(num(d.respawn, C.minRespawn, C.maxRespawn, C.defaultRespawn)) end
    if not a.enabled then clearArea(a.id) end
    save()
    publish()
    AM.addLog(src, 'Requins : zone modifiée', ('#%d %s · %s · %s · %ds'):format(a.id, a.name, a.enabled and 'active' or 'désactivée', a.model, a.respawn))
    return d.quiet and nil or ('« %s » enregistrée.'):format(a.name)
end)

A.sharks_area_reset = act(function(src, d)
    local a = findArea(d.id)
    if not a then return 'Zone introuvable.', 'error' end
    buildSlots(a)
    AM.addLog(src, 'Requins : réapparition immédiate', ('#%d %s'):format(a.id, a.name))
    return 'Tous les requins de la zone vont réapparaître à leur point (dès qu\'un joueur est proche).'
end)

A.sharks_area_delete = act(function(src, d)
    local a, i = findArea(d.id)
    if not a then return 'Zone introuvable.', 'error' end
    clearArea(a.id)
    table.remove(S.areas, i)
    save()
    publish()
    AM.addLog(src, 'Requins : zone supprimée', ('#%d %s'):format(a.id, a.name))
    return ('Zone « %s » supprimée.'):format(a.name)
end)

-- Joueurs protégés : ajoutés par leur ID serveur, enregistrés par licence (gardés après un redémarrage)
A.sharks_immune_add = act(function(src, d)
    local id = tonumber(d.target)
    if not id or not GetPlayerName(id) then return 'Aucun joueur connecté avec cet ID.', 'error' end
    local lic = AM.getLicense(id)
    if not lic then return 'Licence du joueur introuvable.', 'error' end
    for _, p in ipairs(S.immune) do
        if p.license == lic then return ('%s est déjà protégé.'):format(p.name), 'error' end
    end
    local note = str(d.note, 60)
    S.immune[#S.immune + 1] = { license = lic, name = GetPlayerName(id), note = note ~= '' and note or nil,
        by = AM.pname(src) or ('#' .. src), at = now() }
    save()
    publishImmune()
    AM.addLog(src, 'Requins : joueur protégé', ('%s (ID %d)'):format(GetPlayerName(id), id))
    TriggerClientEvent('adminmenu:notify', id, 'Les requins ne t\'attaqueront plus.', 'success')
    return ('%s ne sera plus attaqué par les requins (même après un redémarrage).'):format(GetPlayerName(id))
end)

A.sharks_immune_remove = act(function(src, d)
    local idx = tonumber(d.index)
    local p = idx and S.immune[idx]
    if not p then return 'Joueur introuvable dans la liste.', 'error' end
    table.remove(S.immune, idx)
    save()
    publishImmune()
    AM.addLog(src, 'Requins : protection retirée', p.name)
    return ('%s n\'est plus protégé.'):format(p.name)
end)

-- ---------------------------------------------------------
--  Données de l'onglet
-- ---------------------------------------------------------
table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'sharks_manage') then return end
    local t = now()
    local online = {}
    for _, p in ipairs(GetPlayers()) do
        local lic = AM.getLicense(tonumber(p))
        if lic then online[lic] = tonumber(p) end
    end
    local areas = {}
    for _, a in ipairs(S.areas) do
        local L = Live[a.id]
        local alive, dead, next = 0, 0, nil
        for _, sl in ipairs(L and L.slots or {}) do
            if sl.state == 'alive' then alive = alive + 1
            elseif sl.state == 'dead' then
                dead = dead + 1
                local w = math.max(0, (sl.respawnAt or t) - t)
                next = next and math.min(next, w) or w
            end
        end
        local total = 0
        for _, sp in ipairs(a.spawns or {}) do total = total + (sp.count or 1) end
        local cx, cy, r = Sharks.bounds(a.points or {})
        areas[#areas + 1] = { id = a.id, name = a.name, enabled = a.enabled, model = a.model, respawn = a.respawn, kills = a.kills or 0,
            points = a.points, spawns = a.spawns, total = total, alive = alive, dead = dead, next = next,
            center = { x = cx, y = cy, z = (a.spawns[1] and a.spawns[1].z or (a.points[1] and a.points[1].z) or 0) + 3.0 }, radius = r }
    end
    local immune = {}
    for i, p in ipairs(S.immune) do
        immune[#immune + 1] = { index = i, name = p.name, note = p.note, by = p.by, at = p.at, online = online[p.license] }
    end
    data.sharks = { enabled = S.enabled, areas = areas, immune = immune, models = C.models, alive = aliveTotal,
        limits = { maxPerSpawn = C.maxPerSpawn, maxSpawns = C.maxSpawnsPerArea, maxPerArea = C.maxPerArea, minRespawn = C.minRespawn,
            maxRespawn = C.maxRespawn, activate = C.activateDistance } }
end)
