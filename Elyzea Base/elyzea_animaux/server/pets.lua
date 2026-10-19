-- =========================================================
--  ELYZEA ANIMAUX - SERVEUR : animaux possédés
--  États en base : stored (rangé) · out (sorti) · injured (blessé,
--  indisponible jusqu'aux soins). Un animal ne peut exister qu'une
--  fois : sortie autorisée par le serveur (jeton), entité vérifiée
--  (modèle, propriétaire réseau, distance), puis enregistrée.
--  Déconnexion, changement de personnage, arrêt de la ressource :
--  l'entité est supprimée et l'animal redevient « rangé ».
-- =========================================================
A.Out = {}         -- [id animal] = { id, src, cid, netId, species, variant, name, gear, leash, far }
A.Spawning = {}    -- [id animal] = { src, cid, token, t }

local function decodeGear(s)
    if type(s) ~= 'string' or s == '' then return {} end
    local ok, g = pcall(json.decode, s)
    return ok and type(g) == 'table' and g or {}
end

local function harnessOk(h)
    if type(h) ~= 'table' then return nil end
    local style, color
    for _, s in ipairs(Config.HarnessStyles) do if s.id == h.style then style = s end end
    for _, c in ipairs(Config.HarnessColors) do if c.id == h.color then color = c end end
    if not style or not color then return nil end
    return { style = style.id, color = color.id }, style, color
end
A.HarnessOk = harnessOk

function A.HarnessLabel(h)
    local _, s, c = harnessOk(h)
    return s and ('%s · %s'):format(s.label, c.label) or 'Harnais'
end

function A.RowPublic(r)
    local sp = A.SpeciesEff(r.species)
    local v = A.Variant(r.species, r.variant)
    local out = A.Out[r.id]
    return {
        id = r.id, chip = r.chip, name = r.name, species = r.species, speciesLabel = sp and sp.label or r.species,
        variant = r.variant, variantLabel = v and v.label or r.variant, cat = sp and sp.cat, exotic = sp and sp.exotic,
        status = r.status, hunger = math.floor(r.hunger + 0.5), thirst = math.floor(r.thirst + 0.5), health = math.floor(r.health + 0.5),
        gear = decodeGear(r.gear), price = r.price, acquired = tonumber(r.acquired) or 0, out = out ~= nil, leash = out and out.leash or false,
        injuredAt = r.injured_at, profile = sp and sp.profile,
    }
end

function A.GetPet(id)
    id = tonumber(id)
    if not id then return nil end
    return MySQL.single.await('SELECT *, UNIX_TIMESTAMP(`acquired_at`) AS acquired FROM `elyzea_animaux` WHERE `id` = ?', { id })
end

function A.PetsOf(cid)
    return MySQL.query.await('SELECT *, UNIX_TIMESTAMP(`acquired_at`) AS acquired FROM `elyzea_animaux` WHERE `citizenid` = ? ORDER BY `id`', { cid }) or {}
end

function A.OutCount(cid)
    local n = 0
    for _, o in pairs(A.Out) do if o.cid == cid then n = n + 1 end end
    for _, s in pairs(A.Spawning) do if s.cid == cid then n = n + 1 end end
    return n
end

-- ---------------------------------------------------------
--  Liste des animaux visibles (harnais, laisse) envoyée à tous
-- ---------------------------------------------------------
local function activeList()
    local list = {}
    for _, o in pairs(A.Out) do
        if o.netId then
            local sp = Config.Species[o.species]
            list[tostring(o.netId)] = { id = o.id, owner = o.src, name = o.name, species = o.species,
                harness = o.gear.harness, leash = o.leash == true, radius = sp and sp.radius or 0.15, neck = sp and sp.neck or 0.1 }
        end
    end
    return list
end
function A.SendActive(src) TriggerClientEvent('elyzea_animaux:client:active', src, activeList()) end
local activePending = false
function A.BroadcastActive()
    if activePending then return end
    activePending = true
    SetTimeout(150, function()
        activePending = false
        TriggerClientEvent('elyzea_animaux:client:active', -1, activeList())
    end)
end

local function entityOf(netId)
    if not netId then return 0 end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent and ent ~= 0 and DoesEntityExist(ent) then return ent end
    return 0
end
A.EntityOf = entityOf

-- ---------------------------------------------------------
--  Ranger / blesser
-- ---------------------------------------------------------
function A.StorePet(id, reason, status)
    local o = A.Out[id]
    A.Spawning[id] = nil
    if o then
        A.Out[id] = nil
        local ent = entityOf(o.netId)
        if ent ~= 0 then DeleteEntity(ent) end
        if o.src and GetPlayerName(o.src) then TriggerClientEvent('elyzea_animaux:client:despawned', o.src, id, reason) end
        A.BroadcastActive()
    end
    status = status or 'stored'
    if status == 'injured' then
        MySQL.update.await("UPDATE `elyzea_animaux` SET `status` = 'injured', `health` = 0, `injured_at` = ? WHERE `id` = ?", { os.time(), id })
    else
        MySQL.update.await("UPDATE `elyzea_animaux` SET `status` = 'stored' WHERE `id` = ? AND `status` = 'out'", { id })
    end
end

function A.StoreAllOf(src, reason)
    local ids = {}
    for id, o in pairs(A.Out) do if o.src == src then ids[#ids + 1] = id end end
    for id, s in pairs(A.Spawning) do if s.src == src then A.Spawning[id] = nil end end
    for _, id in ipairs(ids) do A.StorePet(id, reason) end
    return #ids
end

AddEventHandler('elyzea:server:playerUnloaded', function(src) A.StoreAllOf(tonumber(src), 'logout') end)
AddEventHandler('playerDropped', function() A.StoreAllOf(source, 'drop') end)
AddEventHandler('elyzea:server:characterDeleted', function(cid)
    if type(cid) ~= 'string' then return end
    for id, o in pairs(A.Out) do if o.cid == cid then A.StorePet(id, 'deleted') end end
    MySQL.query.await('DELETE FROM `elyzea_animaux` WHERE `citizenid` = ?', { cid })
    A.Log(0, 'Animaux supprimés avec le personnage', cid)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, o in pairs(A.Out) do
        local ent = entityOf(o.netId)
        if ent ~= 0 then DeleteEntity(ent) end
    end
end)

-- ---------------------------------------------------------
--  Rappels client
-- ---------------------------------------------------------
Ely.callback.register('elyzea_animaux:myPets', function(src)
    if not A.Ready or not A.Rate(src, 'list', 10, 10000) then return nil end
    local cid = A.Cid(src)
    if not cid then return nil end
    local list = {}
    for _, r in ipairs(A.PetsOf(cid)) do list[#list + 1] = A.RowPublic(r) end
    return { pets = list, maxOwned = A.S.general.maxOwned, maxOut = A.S.general.maxOut, enabled = A.S.general.enabled,
        styles = Config.HarnessStyles, colors = Config.HarnessColors }
end)

local function token() return ('%x%x'):format(math.random(0, 0xFFFFFF), math.random(0, 0xFFFFFF)) end

Ely.callback.register('elyzea_animaux:requestSpawn', function(src, id)
    if not A.Ready or not A.Rate(src, 'spawn', 4, 10000) then return false, 'Doucement.' end
    return A.Locked(src, function()
        if not A.S.general.enabled then return false, 'Les animaux sont désactivés pour le moment.' end
        local cid = A.Cid(src)
        local r = cid and A.GetPet(id)
        if not r or r.citizenid ~= cid then return false, 'Cet animal ne t\'appartient pas.' end
        if A.Out[r.id] or A.Spawning[r.id] or r.status == 'out' then return false, 'Cet animal est déjà sorti.' end
        if r.status == 'injured' then return false, ('%s est blessé : il doit être soigné (trousse vétérinaire ou vétérinaire).'):format(r.name) end
        if A.OutCount(cid) >= A.S.general.maxOut then return false, ('Tu as déjà %d animal(aux) sorti(s) (maximum).'):format(A.S.general.maxOut) end
        local v, sp = A.Variant(r.species, r.variant)
        if not sp or not v then return false, 'Espèce ou pelage inconnu : préviens le staff.' end
        local pos, ped = A.PedPos(src)
        if not pos then return false, 'Position introuvable.' end
        if GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'Descends du véhicule pour sortir ton animal.' end
        local t = token()
        A.Spawning[r.id] = { src = src, cid = cid, token = t, t = os.time() }
        local base = Config.Species[r.species]
        return true, {
            token = t, pet = A.RowPublic(r), model = v.model, c = v.c, d = v.d, t = v.t,
            radius = base.radius or 0.15, neck = base.neck or 0.1, settings = A.ClientSettings(),
        }
    end)
end)

RegisterNetEvent('elyzea_animaux:server:spawned', function(id, tok, netId)
    local src = source
    id, netId = tonumber(id), tonumber(netId)
    local s = id and A.Spawning[id]
    local function reject(msg)
        local ent = entityOf(netId)
        if ent ~= 0 and NetworkGetEntityOwner(ent) == src and GetEntityType(ent) == 1 and not IsPedAPlayer(ent) then DeleteEntity(ent) end
        if msg then A.Notify(src, msg, 'error') end
        TriggerClientEvent('elyzea_animaux:client:despawned', src, id, 'rejected')
    end
    if not s or s.src ~= src then return reject('Sortie refusée.') end
    A.Spawning[id] = nil   -- un seul essai par jeton : en cas de refus, le joueur peut redemander tout de suite
    if s.token ~= tok or os.time() - s.t > 25 then return reject('Sortie refusée (délai dépassé), réessaie.') end
    local r = A.GetPet(id)
    if not r or r.citizenid ~= s.cid or A.Cid(src) ~= s.cid then return reject('Sortie refusée.') end
    local ent = entityOf(netId)
    local v = A.Variant(r.species, r.variant)
    -- hachages comparés modulo 2^32 (signé / non signé selon la native)
    if ent == 0 or not v or (GetEntityModel(ent) % 4294967296) ~= (GetHashKey(v.model) % 4294967296) or GetEntityType(ent) ~= 1 then return reject('Sortie refusée : animal introuvable.') end
    if NetworkGetEntityOwner(ent) ~= src then return reject('Sortie refusée : animal créé par un autre joueur.') end
    local pos = A.PedPos(src)
    if not pos or #(GetEntityCoords(ent) - pos) > 30.0 then return reject('Sortie refusée : animal trop loin.') end
    A.Out[id] = { id = id, src = src, cid = s.cid, netId = netId, species = r.species, variant = r.variant, name = r.name,
        gear = decodeGear(r.gear), leash = false, far = 0 }
    MySQL.update.await("UPDATE `elyzea_animaux` SET `status` = 'out' WHERE `id` = ?", { id })
    pcall(function() Entity(ent).state:set('elyPet', { id = id, owner = src, name = r.name, species = r.species }, true) end)
    A.BroadcastActive()
    TriggerClientEvent('elyzea_animaux:client:needs', src, id, { hunger = r.hunger, thirst = r.thirst, health = r.health })
end)

-- Jetons de sortie jamais confirmés (client planté…)
CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for id, s in pairs(A.Spawning) do if now - s.t > 30 then A.Spawning[id] = nil end end
    end
end)

local function ownOut(src, id)
    local o = A.Out[tonumber(id) or -1]
    if not o or o.src ~= src or A.Cid(src) ~= o.cid then return nil end
    return o
end
A.OwnOut = ownOut

local function near(src, o, dist)
    local pos = A.PedPos(src)
    local ent = entityOf(o.netId)
    if not pos or ent == 0 then return false, ent end
    return #(GetEntityCoords(ent) - pos) <= (dist or Config.Care.useDistance) + 1.5, ent
end

RegisterNetEvent('elyzea_animaux:server:store', function(id)
    local src = source
    if not A.Rate(src, 'store', 6, 10000) then return end
    local o = ownOut(src, id)
    if not o then return end
    A.StorePet(o.id, 'stored')
    A.Notify(src, ('%s est rentré à la maison.'):format(o.name), 'success')
end)

-- Santé de l'animal vue par son propriétaire (seulement à la baisse : les soins passent par le serveur)
RegisterNetEvent('elyzea_animaux:server:health', function(id, pct, dead)
    local src = source
    if not A.Rate(src, 'health', 20, 10000) then return end
    local o = ownOut(src, id)
    if not o then return end
    pct = Ani.Clamp(pct, 0, 100, nil)
    if dead == true or (pct and pct <= 0) then
        if A.S.general.invincible then return end
        A.StorePet(o.id, 'injured', 'injured')
        A.Notify(src, ('%s est blessé : il est rentré et doit être soigné avant de ressortir.'):format(o.name), 'error')
        A.Log(src, 'Animal blessé', ('%s (#%d) de %s'):format(o.name, o.id, o.cid))
        return
    end
    if pct then MySQL.update.await('UPDATE `elyzea_animaux` SET `health` = LEAST(`health`, ?) WHERE `id` = ?', { pct, o.id }) end
end)

-- Le client a perdu son animal (entité supprimée par le jeu, téléportation lointaine…)
RegisterNetEvent('elyzea_animaux:server:lost', function(id)
    local src = source
    local o = ownOut(src, id)
    if not o then return end
    if entityOf(o.netId) == 0 then A.StorePet(o.id, 'lost') end
end)

-- ---------------------------------------------------------
--  Nom
-- ---------------------------------------------------------
Ely.callback.register('elyzea_animaux:rename', function(src, id, name)
    if not A.Rate(src, 'rename', 4, 30000) then return false, 'Doucement.' end
    return A.Locked(src, function()
        local cid = A.Cid(src)
        local r = cid and A.GetPet(id)
        if not r or r.citizenid ~= cid then return false, 'Cet animal ne t\'appartient pas.' end
        local clean = Ani.PetName(name)
        if not clean then return false, 'Nom invalide : 2 à 20 lettres, sans symboles.' end
        MySQL.update.await('UPDATE `elyzea_animaux` SET `name` = ? WHERE `id` = ?', { clean, r.id })
        local o = A.Out[r.id]
        if o then
            o.name = clean
            local ent = entityOf(o.netId)
            if ent ~= 0 then pcall(function() Entity(ent).state:set('elyPet', { id = o.id, owner = src, name = clean, species = o.species }, true) end) end
            A.BroadcastActive()
        end
        return true, ('Ton animal s\'appelle maintenant %s.'):format(clean)
    end)
end)

-- ---------------------------------------------------------
--  Soins : nourrir, abreuver, soigner
-- ---------------------------------------------------------
local function applyCare(r, kind)
    local c = Config.Care[kind]
    local h = math.min(100, r.hunger + (c.hunger or 0))
    local t = math.min(100, r.thirst + (c.thirst or 0))
    local hp = math.min(100, r.health + (c.health or 0))
    if r.status == 'injured' and kind == 'medkit' then
        hp = math.max(c.health or 50, 1)
        MySQL.update.await("UPDATE `elyzea_animaux` SET `status` = 'stored', `health` = ?, `injured_at` = NULL WHERE `id` = ?", { hp, r.id })
    else
        MySQL.update.await('UPDATE `elyzea_animaux` SET `hunger` = ?, `thirst` = ?, `health` = ? WHERE `id` = ?', { h, t, hp, r.id })
    end
    return { hunger = h, thirst = t, health = hp }
end

Ely.callback.register('elyzea_animaux:care', function(src, id, kind, slot)
    if not A.Rate(src, 'care', 6, 10000) then return false, 'Doucement.' end
    if kind ~= 'food' and kind ~= 'treat' and kind ~= 'water' and kind ~= 'medkit' then return false end
    return A.Locked(src, function()
        local cid = A.Cid(src)
        local r = cid and A.GetPet(id)
        if not r or r.citizenid ~= cid then return false, 'Cet animal ne t\'appartient pas.' end
        local o = A.Out[r.id]
        if r.status == 'injured' then
            if kind ~= 'medkit' then return false, ('%s est blessé : il lui faut des soins.'):format(r.name) end
        elseif not o then
            return false, 'Sors ton animal pour t\'en occuper.'
        else
            local ok = near(src, o)
            if not ok then return false, 'Approche-toi de ton animal.' end
        end
        if kind == 'medkit' and r.health >= 100 and r.status ~= 'injured' then return false, ('%s est en pleine forme.'):format(r.name) end
        if kind == 'food' and r.hunger >= 98 then return false, ('%s n\'a pas faim.'):format(r.name) end
        if kind == 'water' and r.thirst >= 98 then return false, ('%s n\'a pas soif.'):format(r.name) end
        if not A.RemoveItem(src, kind, 1, tonumber(slot)) and not A.RemoveItem(src, kind, 1) then
            return false, ('Il te faut : %s.'):format(A.ItemLabel(kind))
        end
        local n = applyCare(r, kind)
        if o then TriggerClientEvent('elyzea_animaux:client:needs', src, r.id, n) end
        local msg = ({ food = '%s a mangé ses croquettes.', treat = '%s a croqué sa friandise.', water = '%s a bu.',
            medkit = '%s a été soigné.' })[kind]:format(r.name)
        return true, msg, n
    end)
end)

-- ---------------------------------------------------------
--  Harnais et laisse
-- ---------------------------------------------------------
local function pushGear(o)
    MySQL.update.await('UPDATE `elyzea_animaux` SET `gear` = ? WHERE `id` = ?', { json.encode(o.gear), o.id })
    A.BroadcastActive()
    if o.src then TriggerClientEvent('elyzea_animaux:client:gear', o.src, o.id, o.gear, o.leash) end
end

Ely.callback.register('elyzea_animaux:harness', function(src, id, slot)
    if not A.Rate(src, 'gear', 6, 10000) then return false, 'Doucement.' end
    return A.Locked(src, function()
        local o = ownOut(src, id)
        if not o then return false, 'Sors ton animal d\'abord.' end
        local prof = Ani.Profile(Config.Species[o.species])
        if not prof.harness then return false, 'Cet animal ne peut pas porter de harnais.' end
        if not near(src, o) then return false, 'Approche-toi de ton animal.' end
        if slot == nil then
            -- retirer
            if not o.gear.harness then return false, 'Il ne porte pas de harnais.' end
            local h = o.gear.harness
            local ok = A.AddItem(src, 'harness', 1, { style = h.style, color = h.color, label = 'Harnais · ' .. A.HarnessLabel(h) })
            if not ok then return false, 'Inventaire plein.' end
            o.gear.harness = nil
            if o.leash and A.S.leash.requireHarness then o.leash = false end
            pushGear(o)
            return true, 'Harnais retiré (rendu dans ton inventaire).'
        end
        if not A.S.harness.enabled then return false, 'Les harnais sont désactivés.' end
        local it = A.Slot(src, tonumber(slot))
        if not it or it.name ~= Config.Items.harness then return false, 'Harnais introuvable dans ton inventaire.' end
        local h = harnessOk(it.metadata or {}) or { style = Config.HarnessStyles[1].id, color = Config.HarnessColors[1].id }
        if o.gear.harness then
            local old = o.gear.harness
            if not A.AddItem(src, 'harness', 1, { style = old.style, color = old.color, label = 'Harnais · ' .. A.HarnessLabel(old) }) then
                return false, 'Inventaire plein : retire d\'abord l\'ancien harnais.'
            end
        end
        if not A.RemoveItem(src, 'harness', 1, it.slot) then return false, 'Harnais introuvable dans ton inventaire.' end
        o.gear.harness = h
        pushGear(o)
        return true, ('%s porte maintenant un %s.'):format(o.name, A.HarnessLabel(h):lower())
    end)
end)

local function detachLeash(o, msg)
    if not o.leash then return end
    o.leash = false
    A.BroadcastActive()
    if o.src then
        TriggerClientEvent('elyzea_animaux:client:gear', o.src, o.id, o.gear, false)
        if msg then A.Notify(o.src, msg, 'warning') end
    end
end
A.DetachLeash = detachLeash

Ely.callback.register('elyzea_animaux:leash', function(src, id)
    if not A.Rate(src, 'gear', 6, 10000) then return false, 'Doucement.' end
    return A.Locked(src, function()
        local o = ownOut(src, id)
        if not o then return false, 'Sors ton animal d\'abord.' end
        if o.leash then detachLeash(o) return true, 'Laisse détachée.' end
        if not A.S.leash.enabled then return false, 'Les laisses sont désactivées.' end
        local prof = Ani.Profile(Config.Species[o.species])
        if not prof.leash then return false, 'Cet animal ne se promène pas en laisse.' end
        if not near(src, o, 3.0) then return false, 'Approche-toi de ton animal.' end
        local _, ped = A.PedPos(src)
        if GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'Impossible en véhicule.' end
        if A.S.leash.requireItem and A.ItemCount(src, 'leash') < 1 then return false, 'Il te faut une laisse dans ton inventaire.' end
        if A.S.leash.requireHarness and not o.gear.harness then return false, 'Équipe-lui d\'abord un harnais.' end
        for _, other in pairs(A.Out) do
            if other.src == src and other.leash then return false, ('Tu tiens déjà %s en laisse.'):format(other.name) end
        end
        o.leash = true
        A.BroadcastActive()
        TriggerClientEvent('elyzea_animaux:client:gear', src, o.id, o.gear, true)
        return true, ('%s est en laisse.'):format(o.name)
    end)
end)

-- ---------------------------------------------------------
--  Surveillance : laisse, distance, entités disparues
-- ---------------------------------------------------------
CreateThread(function()
    while true do
        Wait(2000)
        for id, o in pairs(A.Out) do
            local ent = entityOf(o.netId)
            local pos, ped = A.PedPos(o.src)
            if ent == 0 or not pos then
                A.StorePet(id, 'lost')
            else
                local d = #(GetEntityCoords(ent) - pos)
                if o.leash then
                    if not A.S.leash.enabled then detachLeash(o, 'Les laisses ont été désactivées.')
                    elseif d > A.S.leash.breakDistance then detachLeash(o, ('La laisse de %s s\'est détachée (trop loin).'):format(o.name))
                    elseif GetVehiclePedIsIn(ped, false) ~= 0 then detachLeash(o, 'Laisse détachée pour monter en véhicule.')
                    elseif GetEntityHealth(ped) <= 0 then detachLeash(o)
                    elseif A.S.leash.requireItem and A.ItemCount(o.src, 'leash') < 1 then detachLeash(o, 'Tu n\'as plus de laisse.') end
                end
                if d > A.S.general.autoStoreDistance then
                    o.far = o.far + 2
                    if o.far >= A.S.general.storeDelay then
                        A.StorePet(id, 'far')
                        A.Notify(o.src, ('%s était trop loin de toi : il est rentré à la maison.'):format(o.name), 'warning')
                    end
                else
                    o.far = 0
                end
            end
        end
        if not A.S.general.enabled then
            for id in pairs(A.Out) do A.StorePet(id, 'disabled') end
        end
    end
end)

-- ---------------------------------------------------------
--  Besoins : faim, soif, santé (effet réel, sauvegardé)
-- ---------------------------------------------------------
function A.NeedsTick()
    local n = A.S.needs
    if not n.enabled then return end
    local f = n.storedFactor or 0
    MySQL.update.await("UPDATE `elyzea_animaux` SET `hunger` = GREATEST(0, `hunger` - ?), `thirst` = GREATEST(0, `thirst` - ?) WHERE `status` = 'out'", { n.hungerRate, n.thirstRate })
    if f > 0 then
        MySQL.update.await("UPDATE `elyzea_animaux` SET `hunger` = GREATEST(0, `hunger` - ?), `thirst` = GREATEST(0, `thirst` - ?) WHERE `status` = 'stored'", { n.hungerRate * f, n.thirstRate * f })
    end
    if n.damage > 0 then
        MySQL.update.await("UPDATE `elyzea_animaux` SET `health` = GREATEST(0, `health` - ?) WHERE `status` IN ('out', 'stored') AND (`hunger` <= 0 OR `thirst` <= 0)", { n.damage })
    end
    -- Animaux tombés à 0 : blessés (indisponibles)
    local rows = MySQL.query.await("SELECT `id`, `name`, `status` FROM `elyzea_animaux` WHERE `status` IN ('out', 'stored') AND `health` <= 0") or {}
    for _, r in ipairs(rows) do
        local o = A.Out[r.id]
        A.StorePet(r.id, 'injured', 'injured')
        if o then A.Notify(o.src, ('%s est trop affaibli (faim / soif) : il est rentré et doit être soigné.'):format(r.name), 'error') end
    end
    -- Nouvelles valeurs envoyées aux propriétaires (effets : plus lent, refuse les tours)
    local ids = {}
    for id in pairs(A.Out) do ids[#ids + 1] = id end
    if #ids > 0 then
        local marks = {}
        for i = 1, #ids do marks[i] = '?' end
        local cur = MySQL.query.await(('SELECT `id`, `hunger`, `thirst`, `health` FROM `elyzea_animaux` WHERE `id` IN (%s)'):format(table.concat(marks, ',')), ids) or {}
        for _, r in ipairs(cur) do
            local o = A.Out[r.id]
            if o then TriggerClientEvent('elyzea_animaux:client:needs', o.src, r.id, { hunger = r.hunger, thirst = r.thirst, health = r.health }) end
        end
    end
end

CreateThread(function()
    while not A.Ready do Wait(500) end
    local last = os.time()
    while true do
        Wait(30000)
        local now = os.time()
        if now - last >= (A.S.needs.interval or 10) * 60 then
            last = now
            local ok, err = pcall(A.NeedsTick)
            if not ok then print(('^1[ANIMAUX] Besoins : %s^7'):format(tostring(err))) end
        end
        local hours = A.S.needs.recoveryHours or 0
        if hours > 0 then
            pcall(function()
                MySQL.update.await("UPDATE `elyzea_animaux` SET `status` = 'stored', `health` = 40, `injured_at` = NULL WHERE `status` = 'injured' AND `injured_at` < ?", { now - hours * 3600 })
            end)
        end
    end
end)
