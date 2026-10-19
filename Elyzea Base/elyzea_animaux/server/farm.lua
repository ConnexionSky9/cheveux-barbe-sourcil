-- =========================================================
--  ELYZEA ANIMAUX - SERVEUR : ferme
--  Les animaux d'enclos appartiennent à la ferme (jamais à un joueur).
--  Ils sont créés par le serveur (entités réseau : tout le monde voit
--  la même vache au même endroit) quand un joueur approche, puis
--  supprimés quand plus personne n'est autour. Faim et santé de
--  chaque animal sont enregistrées (table elyzea_animaux_farm) :
--  un animal affamé ou malade se couche et ne produit plus.
-- =========================================================
A.FarmRows = {}     -- [enclos][slot] = { species, variant, hunger, health, last }
A.FarmLive = {}     -- [enclos] = { ents = { [slot] = netId }, empty = secondes sans joueur }

local function enclosure(id) for _, e in ipairs(A.Farm.enclosures) do if e.id == id then return e end end end
A.Enclosure = enclosure

function A.PublicFarm()
    local out = {}
    if not A.Farm.enabled then return out end
    for _, e in ipairs(A.Farm.enclosures) do
        if e.enabled then out[#out + 1] = { id = e.id, label = e.label, x = e.x, y = e.y, z = e.z, radius = e.radius } end
    end
    return out
end

local function mood(r)
    if r.health < 35 then return 'sick' end
    if r.hunger < 25 then return 'hungry' end
    return 'ok'
end

local function entityList()
    local list = {}
    for encId, live in pairs(A.FarmLive) do
        local rows = A.FarmRows[encId] or {}
        for slot, netId in pairs(live.ents) do
            local r = rows[slot]
            if r then list[tostring(netId)] = { enc = encId, slot = slot, species = r.species, mood = mood(r) } end
        end
    end
    return list
end
local listPending = false
function A.FarmBroadcast()
    if listPending then return end
    listPending = true
    SetTimeout(200, function()
        listPending = false
        TriggerClientEvent('elyzea_animaux:client:farmEntities', -1, entityList())
    end)
end
RegisterNetEvent('elyzea_animaux:server:farmHello', function()
    local src = source
    if A.Rate(src, 'farmHello', 3, 10000) then TriggerClientEvent('elyzea_animaux:client:farmEntities', src, entityList()) end
end)

local function randomVariant(sid)
    local sp = A.SpeciesEff(sid)
    local pool = {}
    for _, v in ipairs(sp and sp.variants or {}) do if v.enabled and A.VariantUsable(v) then pool[#pool + 1] = v.id end end
    return pool[math.random(1, math.max(1, #pool))] or 't0'
end

-- Lignes en base alignées sur la composition des enclos (sans perdre l'état des animaux gardés)
function A.FarmSyncRows()
    local wanted = {}
    for _, e in ipairs(A.Farm.enclosures) do
        local slots, n = {}, 0
        local keys = {}
        for sid in pairs(e.animals) do keys[#keys + 1] = sid end
        table.sort(keys)
        for _, sid in ipairs(keys) do for _ = 1, e.animals[sid] do n = n + 1 slots[n] = sid end end
        wanted[e.id] = slots
    end
    for encId, rows in pairs(A.FarmRows) do
        for slot, r in pairs(rows) do
            if not wanted[encId] or wanted[encId][slot] ~= r.species then
                rows[slot] = nil
                MySQL.query.await('DELETE FROM `elyzea_animaux_farm` WHERE `enclosure` = ? AND `slot` = ?', { encId, slot })
            end
        end
        if not wanted[encId] then A.FarmRows[encId] = nil end
    end
    for encId, slots in pairs(wanted) do
        A.FarmRows[encId] = A.FarmRows[encId] or {}
        for slot, sid in ipairs(slots) do
            if not A.FarmRows[encId][slot] then
                local r = { species = sid, variant = randomVariant(sid), hunger = 100, health = 100, last = 0 }
                A.FarmRows[encId][slot] = r
                MySQL.query.await('INSERT INTO `elyzea_animaux_farm` (`enclosure`, `slot`, `species`, `variant`, `hunger`, `health`, `last_produce`) VALUES (?, ?, ?, ?, 100, 100, 0) ON DUPLICATE KEY UPDATE `species` = VALUES(`species`), `variant` = VALUES(`variant`)',
                    { encId, slot, sid, r.variant })
            end
        end
    end
end

local function saveRow(encId, slot)
    local r = A.FarmRows[encId] and A.FarmRows[encId][slot]
    if r then MySQL.update.await('UPDATE `elyzea_animaux_farm` SET `hunger` = ?, `health` = ?, `last_produce` = ? WHERE `enclosure` = ? AND `slot` = ?', { r.hunger, r.health, r.last, encId, slot }) end
end

local function despawnEnclosure(encId)
    local live = A.FarmLive[encId]
    if not live then return end
    for _, netId in pairs(live.ents) do
        local ent = A.EntityOf(netId)
        if ent ~= 0 then DeleteEntity(ent) end
    end
    A.FarmLive[encId] = nil
    A.FarmBroadcast()
end
A.FarmDespawn = despawnEnclosure

function A.FarmDespawnAll() for encId in pairs(A.FarmLive) do despawnEnclosure(encId) end end

local function spawnSlot(e, slot, r)
    local v = A.Variant(r.species, r.variant) or A.Variant(r.species, 't0')
    if not v then return nil end
    local a = math.random() * math.pi * 2
    local d = math.sqrt(math.random()) * e.radius * 0.7
    local ped = CreatePed(28, GetHashKey(v.model), e.x + math.cos(a) * d, e.y + math.sin(a) * d, e.z + 0.5, math.random(0, 359) + 0.0, true, true)
    local t = GetGameTimer() + 3000
    while (not ped or ped == 0 or not DoesEntityExist(ped)) and GetGameTimer() < t do Wait(50) end
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    pcall(function() SetEntityOrphanMode(ped, 2) end)
    pcall(function() SetPedConfigFlag(ped, 17, true) end)   -- pas de fuite / réaction aux événements
    pcall(function() SetPedComponentVariation(ped, v.c, v.d, v.t, 0) end)
    local netId = NetworkGetNetworkIdFromEntity(ped)
    pcall(function() Entity(ped).state:set('elyFarm', { enc = e.id, slot = slot, species = r.species, c = v.c, d = v.d, t = v.t }, true) end)
    return netId
end

CreateThread(function()
    while not A.Ready do Wait(500) end
    local lastHunger = os.time()
    while true do
        Wait(3000)
        if not A.Farm.enabled then
            if next(A.FarmLive) then A.FarmDespawnAll() end
        else
            local players = {}
            for _, p in ipairs(GetPlayers()) do
                local pos = A.PedPos(tonumber(p))
                if pos then players[#players + 1] = pos end
            end
            local changed = false
            for _, e in ipairs(A.Farm.enclosures) do
                local c = vector3(e.x, e.y, e.z)
                local nearest = 1e9
                for _, pos in ipairs(players) do nearest = math.min(nearest, #(pos - c)) end
                local live = A.FarmLive[e.id]
                if e.enabled and nearest <= A.Farm.activation then
                    if not live then live = { ents = {}, empty = 0 } A.FarmLive[e.id] = live end
                    live.empty = 0
                    for slot, r in pairs(A.FarmRows[e.id] or {}) do
                        live.fails, live.back = live.fails or {}, live.back or {}
                        local cur = live.ents[slot] and A.EntityOf(live.ents[slot]) or 0
                        if cur ~= 0 and GetEntityHealth(cur) <= 0 then
                            -- tué : retiré, remplacé 2 min plus tard, l'état de l'enclos en garde la trace
                            DeleteEntity(cur)
                            live.ents[slot] = nil
                            live.back[slot] = os.time() + 120
                            r.health = math.max(0, r.health - 30)
                            saveRow(e.id, slot)
                            changed = true
                        end
                        if (live.back[slot] or 0) > os.time() then
                            -- en attente de remplacement
                        elseif (live.fails[slot] or 0) < 3 and (not live.ents[slot] or A.EntityOf(live.ents[slot]) == 0) then
                            local netId = spawnSlot(e, slot, r)
                            live.ents[slot] = netId
                            if not netId then
                                live.fails[slot] = (live.fails[slot] or 0) + 1
                                local key = 'farm|' .. r.species
                                A.Diag.clientIssues[key] = A.Diag.clientIssues[key] or { kind = 'farm', what = ('Création impossible : %s (%s)'):format(r.species, e.id), count = 0 }
                                A.Diag.clientIssues[key].count, A.Diag.clientIssues[key].last = A.Diag.clientIssues[key].count + 1, os.time()
                            end
                            changed = true
                        end
                    end
                elseif live then
                    live.empty = live.empty + 3
                    if not e.enabled or nearest > A.Farm.activation + 50 or live.empty >= 60 then despawnEnclosure(e.id) end
                end
            end
            for encId in pairs(A.FarmLive) do if not enclosure(encId) then despawnEnclosure(encId) end end
            if changed then A.FarmBroadcast() end
        end
        -- Faim des animaux d'enclos (toutes les 10 minutes)
        if os.time() - lastHunger >= 600 then
            lastHunger = os.time()
            local moods = false
            for encId, rows in pairs(A.FarmRows) do
                for slot, r in pairs(rows) do
                    local before = mood(r)
                    r.hunger = math.max(0, r.hunger - A.Farm.hungerRate)
                    if r.hunger <= 0 then r.health = math.max(0, r.health - 5) end
                    if mood(r) ~= before then moods = true end
                    saveRow(encId, slot)
                end
            end
            if moods then A.FarmBroadcast() end
        end
    end
end)

function A.FarmBoot()
    local rows = MySQL.query.await('SELECT * FROM `elyzea_animaux_farm`') or {}
    for _, r in ipairs(rows) do
        A.FarmRows[r.enclosure] = A.FarmRows[r.enclosure] or {}
        A.FarmRows[r.enclosure][r.slot] = { species = r.species, variant = r.variant, hunger = r.hunger, health = r.health, last = r.last_produce or 0 }
    end
    A.FarmSyncRows()
end

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then A.FarmDespawnAll() end end)

-- ---------------------------------------------------------
--  Interactions des joueurs
-- ---------------------------------------------------------
local function farmTarget(src, netId)
    netId = tonumber(netId)
    for encId, live in pairs(A.FarmLive) do
        for slot, n in pairs(live.ents) do
            if n == netId then
                local ent = A.EntityOf(n)
                local pos = A.PedPos(src)
                if ent == 0 or not pos or #(GetEntityCoords(ent) - pos) > 4.5 then return nil, 'Approche-toi de l\'animal.' end
                return encId, slot, A.FarmRows[encId][slot]
            end
        end
    end
    return nil, 'Cet animal n\'est plus là.'
end

Ely.callback.register('elyzea_animaux:farm', function(src, netId, action)
    if not A.Ready or not A.Rate(src, 'farm', 8, 10000) then return false, 'Doucement.' end
    return A.Locked(src, function()
        if not A.Farm.enabled then return false, 'La ferme est fermée.' end
        local encId, slot, r = farmTarget(src, netId)
        if not encId then return false, slot end
        local e = enclosure(encId)
        local sp = A.SpeciesEff(r.species)
        local label = sp and sp.label or r.species
        if action == 'observe' then
            local state = mood(r) == 'sick' and 'malade, il a besoin de soins' or mood(r) == 'hungry' and 'affamé' or 'en bonne santé'
            return true, ('%s · %s : %s (faim %d %%, santé %d %%).'):format(e and e.label or 'Enclos', label, state, math.floor(r.hunger), math.floor(r.health))
        elseif action == 'feed' then
            if r.hunger >= 95 then return false, ('Le %s n\'a pas faim.'):format(label:lower()) end
            if not A.RemoveItem(src, 'feed', 1) then return false, ('Il te faut : %s.'):format(A.ItemLabel('feed')) end
            r.hunger = math.min(100, r.hunger + A.Farm.feedValue)
            saveRow(encId, slot)
            A.FarmBroadcast()
            return true, ('Tu as nourri l\'animal (faim %d %%).'):format(math.floor(r.hunger))
        elseif action == 'care' then
            if r.health >= 100 then return false, 'Cet animal est en bonne santé.' end
            if not A.RemoveItem(src, 'medkit', 1) then return false, ('Il te faut : %s.'):format(A.ItemLabel('medkit')) end
            r.health = math.min(100, r.health + A.Farm.careValue)
            saveRow(encId, slot)
            A.FarmBroadcast()
            return true, ('Tu as soigné l\'animal (santé %d %%).'):format(math.floor(r.health))
        elseif action == 'produce' then
            local pr = Config.FarmProduce[r.species]
            local p = A.Farm.produce
            if not pr or not p.enabled then return false, 'Rien à récolter sur cet animal.' end
            if r.hunger < p.minHunger or r.health < p.minHealth then return false, 'L\'animal n\'est pas assez en forme pour produire : nourris-le et soigne-le.' end
            local wait = r.last + p.cooldown * 60 - os.time()
            if wait > 0 then return false, ('Reviens dans %d min.'):format(math.ceil(wait / 60)) end
            local n = math.random(pr.count[1], pr.count[2])
            if not A.AddItem(src, pr.item, n) then return false, 'Inventaire plein.' end
            r.last = os.time()
            saveRow(encId, slot)
            A.Log(src, 'Ferme : récolte', ('%s : %d × %s (%s)'):format(A.CharName(src), n, A.ItemLabel(pr.item), e and e.label or encId))
            return true, ('Récolté : %d × %s.'):format(n, A.ItemLabel(pr.item))
        end
        return false
    end)
end)
