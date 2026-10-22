-- =====================================================================
--  ELYZEA DROGUES · culture du cannabis (serveur)
--  Pot posé par un joueur → graine → lampe → arrosage → croissance (shared/growth.lua) → récolte.
--  La progression est rattrapée à partir des dates enregistrées (drogues_plants) : elle continue
--  hors ligne et après un redémarrage. Toutes les actions passent par un jeton (durée vérifiée).
-- =====================================================================
local P = DS.plants
local busy = DS.playerBusy
local C = Config.Culture

local function S() return DS.S end
local function bool(v) return v == true or v == 1 or v == '1' end

local function rowToPlant(r)
    return { id = r.id, owner = r.owner_cid, ownerName = r.owner_name, x = r.x, y = r.y, z = r.z, h = r.h,
        variety = (r.variety and Config.Varieties[r.variety]) and r.variety or nil, plantedAt = r.planted_at,
        progress = tonumber(r.progress) or 0, water = tonumber(r.water) or 0, health = tonumber(r.health) or 100,
        lamp = bool(r.lamp), fert = bool(r.fert), dead = bool(r.dead), deadAt = r.dead_at, lastAt = r.last_at or os.time(), wateredAt = r.watered_at }
end

function DS.SavePlant(p)
    MySQL.update([[UPDATE `drogues_plants` SET `variety` = ?, `planted_at` = ?, `progress` = ?, `water` = ?, `health` = ?, `lamp` = ?, `fert` = ?,
        `dead` = ?, `dead_at` = ?, `last_at` = ?, `watered_at` = ? WHERE `id` = ?]],
        { p.variety, p.plantedAt, p.progress, p.water, p.health, p.lamp and 1 or 0, p.fert and 1 or 0, p.dead and 1 or 0, p.deadAt, p.lastAt, p.wateredAt, p.id })
end

local function resetPlant(p)
    p.variety, p.plantedAt, p.progress, p.water, p.health, p.fert, p.dead, p.deadAt = nil, nil, 0, p.water or 0, 100, false, false, nil
end

-- Rattrape le temps et nettoie une plante morte depuis trop longtemps. Renvoie true si l'étape visible a changé.
local function refresh(p, now)
    local before = p.variety and (p.dead and -1 or Growth.Stage(p, Growth.Pct(S(), p))) or 0
    Growth.Advance(p, now, S())
    if p.dead and p.deadAt and now - p.deadAt > S().culture.deadRemoveHours * 3600 then resetPlant(p) end
    local after = p.variety and (p.dead and -1 or Growth.Stage(p, Growth.Pct(S(), p))) or 0
    return before ~= after
end

local function public(p)
    local pct = p.variety and Growth.Pct(S(), p) or 0
    return { id = p.id, o = p.owner, x = p.x, y = p.y, z = p.z, h = p.h, v = p.variety, pct = pct,
        st = p.variety and Growth.Stage(p, pct) or 0, lamp = p.lamp, dead = p.dead, water = math.floor(p.water + 0.5), fert = p.fert }
end
DS.PublicPlant = public

function DS.PushPlants(target)
    local now, list = os.time(), {}
    for _, p in pairs(P) do refresh(p, now) list[#list + 1] = public(p) end
    TriggerClientEvent('elyzea_drogues:plants', target or -1, list)
end
local function pushOne(p) TriggerClientEvent('elyzea_drogues:plant', -1, p.id, p and public(p) or nil) end

function DS.LoadPlants()
    local now = os.time()
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `drogues_plants`') or {}) do
        local p = rowToPlant(r)
        refresh(p, now)
        P[p.id] = p
    end
end

-- Toutes les 5 min : rattrapage, envoi des étapes qui changent, sauvegarde (pas de boucle par plante)
CreateThread(function()
    while not DS.ready do Wait(1000) end
    while true do
        Wait(300000)
        local now = os.time()
        for _, p in pairs(P) do
            if p.variety then
                if refresh(p, now) then pushOne(p) end
                DS.SavePlant(p)
            end
        end
    end
end)

local function countOwned(cid) local n = 0 for _, p in pairs(P) do if p.owner == cid then n = n + 1 end end return n end
local function isOwner(src, p) return DS.Cid(src) == p.owner end
local function isPolice(src)
    if GetResourceState('elyzea_police') ~= 'started' then return false end
    local ok, r = pcall(function() return exports.elyzea_police:IsOnDuty(src) end)
    return ok and r == true
end

-- ---------------------------------------------------------------- poser un pot (objet « plant_pot »)
local function onPotUsed(src)
    if not DS.ready then return false end
    local ok, why = DS.CanAct(src)
    if not ok then DS.Notify(src, why, 'error') return false end
    local cid = DS.Cid(src)
    if not cid then return false end
    if countOwned(cid) >= S().culture.maxPotsPerPlayer then
        DS.Notify(src, ('Tu as déjà %d pot(s) posé(s) : c\'est le maximum.'):format(S().culture.maxPotsPerPlayer), 'error') return false
    end
    TriggerClientEvent('elyzea_drogues:placePot', src)
    return false   -- l'objet est retiré seulement quand le pot est vraiment posé
end

DS.RegisterUsable = DS.RegisterUsable or {}
DS.RegisterUsable.plant_pot = onPotUsed

local function forbidden(x, y)
    for _, z in ipairs(C.forbidden or {}) do
        local dx, dy = x - z.x, y - z.y
        if dx * dx + dy * dy <= (z.r or 50) ^ 2 then return true end
    end
    return false
end
DS.Forbidden = forbidden

Ely.callback.register('elyzea_drogues:potPlace', function(src, x, y, z, h)
    if not DS.ready then return { error = 'Le système démarre.' } end
    x, y, z, h = tonumber(x), tonumber(y), tonumber(z), tonumber(h) or 0.0
    if not x or not y or not z then return { error = 'Position invalide.' } end
    local ok, why = DS.CanAct(src)
    if not ok then return { error = why } end
    local cid = DS.Cid(src)
    if not cid then return { error = 'Personnage introuvable.' } end
    local pos = DS.Pos(src)
    if not pos or not DS.Near(src, { x = x, y = y, z = z }, C.placeMaxDistance) or math.abs(pos.z - z) > 3.0 then return { error = 'Pose le pot plus près de toi.' } end
    if forbidden(x, y) then return { error = 'Impossible de poser un pot ici.' } end
    if countOwned(cid) >= S().culture.maxPotsPerPlayer then return { error = 'Nombre maximum de pots atteint.' } end
    for _, p in pairs(P) do
        local dx, dy, dz = p.x - x, p.y - y, p.z - z
        if dx * dx + dy * dy + dz * dz < S().culture.minDistance ^ 2 then return { error = 'Trop près d\'un autre pot.' } end
    end
    if DS.Count(src, 'plant_pot') < 1 or not DS.Remove(src, 'plant_pot', 1) then return { error = 'Tu n\'as pas de pot.' } end
    local now = os.time()
    local id = MySQL.insert.await('INSERT INTO `drogues_plants` (`owner_cid`, `owner_name`, `x`, `y`, `z`, `h`, `last_at`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { cid, DS.Name(src), x, y, z, h % 360, now })
    if not id then DS.Add(src, 'plant_pot', 1) return { error = 'Pot non enregistré.' } end
    local p = { id = id, owner = cid, ownerName = DS.Name(src), x = x, y = y, z = z, h = h % 360, progress = 0, water = 0, health = 100,
        lamp = false, fert = false, dead = false, lastAt = now }
    P[id] = p
    pushOne(p)
    DS.Log('pot', src, ('pot #%d posé (%.1f, %.1f, %.1f)'):format(id, x, y, z))
    return { ok = true, message = 'Pot posé. ALT sur le pot pour planter une graine.' }
end)

-- ---------------------------------------------------------------- informations (ALT › Consulter)
Ely.callback.register('elyzea_drogues:potInfo', function(src, id)
    local p = P[tonumber(id) or -1]
    if not p then return { error = 'Pot introuvable.' } end
    if not DS.Near(src, p, 6.0) then return { error = 'Trop loin.' } end
    refresh(p, os.time())
    local s = S()
    local v = p.variety and s.varieties[p.variety]
    local pct = p.variety and Growth.Pct(s, p) or 0
    local st = p.variety and Config.Culture.stages[Growth.Stage(p, pct)] or nil
    return { ok = true, info = {
        id = p.id, mine = isOwner(src, p), owner = isOwner(src, p) and 'toi' or nil,
        variety = v and v.label or nil, color = v and v.color or nil, pct = pct, stage = p.dead and 'Morte' or (st and st.label or 'Pot vide'),
        timeLeft = Growth.TimeLeft(s, p), water = math.floor(p.water + 0.5), health = math.floor(p.health + 0.5),
        lamp = p.lamp, fert = p.fert, dead = p.dead, condition = p.variety and Growth.Condition(s, p) or 'pot vide',
        rate = p.variety and Growth.Rate(s, p) or 0,
    } }
end)

-- ---------------------------------------------------------------- actions sur un pot (jeton + durée)
local ACT = {
    plant      = { time = 5,  label = 'Planter la graine' },
    water      = { time = 4,  label = 'Arroser' },
    lamp_on    = { time = 4,  label = 'Installer la lampe' },
    lamp_off   = { time = 3,  label = 'Retirer la lampe' },
    fertilize  = { time = 3,  label = 'Ajouter de l\'engrais' },
    harvest    = { time = 8,  label = 'Récolter' },
    pickup     = { time = 3,  label = 'Reprendre le pot' },
    clear      = { time = 4,  label = 'Retirer la plante morte' },
    destroy    = { time = 6,  label = 'Détruire la plante' },
}

-- Vérifie qu'une action est possible maintenant ; renvoie nil ou un message
local function check(src, p, act, arg)
    local s = S()
    local mine = isOwner(src, p)
    local ownerOnly = Config.Culture.ownerOnlyPlant
    if act == 'plant' then
        if p.variety then return 'Le pot est déjà planté.' end
        if ownerOnly and not mine then return 'Ce n\'est pas ton pot.' end
        local v = Config.Varieties[arg or '']
        if not v then return 'Variété inconnue.' end
        if s.drugs.weed and not s.drugs.weed.enabled then return 'Le cannabis est désactivé sur le serveur.' end
        if DS.Count(src, v.seed) < 1 then return ('Il te faut : %s.'):format(DS.Label(v.seed)) end
    elseif act == 'water' then
        if not p.variety or p.dead then return 'Rien à arroser.' end
        if p.water >= 100 then return 'La plante a assez d\'eau.' end
        if DS.Count(src, 'watering_can') < 1 then return 'Il te faut un arrosoir.' end
        if DS.Count(src, 'water') < 1 then return 'Il te faut une bouteille d\'eau.' end
    elseif act == 'lamp_on' then
        if p.lamp then return 'Une lampe est déjà installée.' end
        if ownerOnly and not mine then return 'Ce n\'est pas ton pot.' end
        if DS.Count(src, 'grow_lamp') < 1 then return 'Il te faut une lampe de culture.' end
    elseif act == 'lamp_off' then
        if not p.lamp then return 'Pas de lampe.' end
        if ownerOnly and not mine then return 'Ce n\'est pas ton pot.' end
        if not DS.CanCarry(src, { { 'grow_lamp', 1 } }) then return 'Ton inventaire est plein.' end
    elseif act == 'fertilize' then
        if not p.variety or p.dead then return 'Rien à fertiliser.' end
        if p.fert then return 'Déjà de l\'engrais.' end
        if DS.Count(src, 'fertilizer') < 1 then return 'Il te faut de l\'engrais.' end
    elseif act == 'harvest' then
        if not Growth.Mature(s, p) then return 'La plante n\'est pas encore mature.' end
        if s.culture.ownerOnlyHarvest and not mine then return 'Ce n\'est pas ta plante.' end
    elseif act == 'pickup' then
        if not mine then return 'Ce n\'est pas ton pot.' end
        if p.variety and not p.dead then return 'Récolte ou retire d\'abord la plante.' end
        local list = { { 'plant_pot', 1 } }
        if p.lamp then list[2] = { 'grow_lamp', 1 } end
        if not DS.CanCarry(src, list) then return 'Ton inventaire est plein.' end
    elseif act == 'clear' then
        if not p.dead then return 'La plante n\'est pas morte.' end
    elseif act == 'destroy' then
        if not (s.culture.policeCanDestroy and isPolice(src)) then return 'Réservé à la police en service.' end
        if not p.variety then return 'Le pot est vide.' end
    else
        return 'Action inconnue.'
    end
end

Ely.callback.register('elyzea_drogues:potStart', function(src, id, act, arg)
    if not DS.ready then return { error = 'Le système démarre.' } end
    if DS.IsBusy(src) then return { error = 'Tu fais déjà quelque chose.' } end
    local ok, why = DS.CanAct(src)
    if not ok then return { error = why } end
    local p = P[tonumber(id) or -1]
    local a = ACT[tostring(act or '')]
    if not p or not a then return { error = 'Pot introuvable.' } end
    if not DS.Near(src, p) then return { error = 'Tu es trop loin.' } end
    refresh(p, os.time())
    local err = check(src, p, act, arg)
    if err then return { error = err } end
    local token = ('%d%06d'):format(os.time(), math.random(0, 999999))
    -- récolte d'une plante mature : mini-jeu (les autres actions gardent la barre de progression)
    local ch = act == 'harvest' and DS.StepChallenge and DS.StepChallenge('pot:harvest', 1, 'weed', 'pot') or nil
    busy[src] = { token = token, kind = 'pot', plant = p.id, act = act, arg = arg, startAt = os.time(), duration = a.time, ch = ch, limit = ch and ch.limit or 0 }
    return { ok = true, token = token, duration = a.time, label = a.label, game = ch }
end)

Ely.callback.register('elyzea_drogues:potFinish', function(src, token, res)
    local b = busy[src]
    if not b or b.kind ~= 'pot' or b.token ~= token then return { error = 'Action expirée.' } end
    busy[src] = nil
    local serr = DS.StepError and DS.StepError(src, b, res, 'pot') or nil
    if serr then return { error = serr } end
    if os.time() - b.startAt < b.duration - 1 then return { error = 'Action interrompue.' } end
    local p = P[b.plant]
    if not p then return { error = 'Pot introuvable.' } end
    if not DS.Near(src, p) then return { error = 'Tu t\'es trop éloigné.' } end
    local now = os.time()
    refresh(p, now)
    local err = check(src, p, b.act, b.arg)
    if err then return { error = err } end
    local s, act, msg = S(), b.act, nil
    if act == 'plant' then
        local v = Config.Varieties[b.arg]
        if not DS.Remove(src, v.seed, 1) then return { error = 'Graine introuvable.' } end
        p.variety, p.plantedAt, p.progress, p.health, p.fert, p.dead, p.deadAt, p.lastAt = b.arg, now, 0, 100, false, false, nil, now
        msg = ('%s plantée. Installe une lampe et arrose-la.'):format(s.varieties[b.arg].label)
    elseif act == 'water' then
        if not DS.Remove(src, 'water', 1) then return { error = 'Bouteille d\'eau introuvable.' } end
        p.water = math.min(100, p.water + s.culture.waterPerUse)
        p.wateredAt = now
        msg = ('Plante arrosée (eau : %d %%).'):format(math.floor(p.water))
    elseif act == 'lamp_on' then
        if not DS.Remove(src, 'grow_lamp', 1) then return { error = 'Lampe introuvable.' } end
        p.lamp = true
        msg = 'Lampe installée : la plante pousse plus vite.'
    elseif act == 'lamp_off' then
        if not DS.Add(src, 'grow_lamp', 1) then return { error = 'Inventaire plein.' } end
        p.lamp = false
        msg = 'Lampe retirée.'
    elseif act == 'fertilize' then
        if not DS.Remove(src, 'fertilizer', 1) then return { error = 'Engrais introuvable.' } end
        p.fert = true
        msg = 'Engrais ajouté.'
    elseif act == 'harvest' then
        local cv, set = Config.Varieties[p.variety], s.varieties[p.variety]
        local n = math.random(set.yieldMin, set.yieldMax)
        local give = { { cv.leaf, n } }
        local seed = math.random(1, 100) <= set.seedChance
        if seed then give[2] = { cv.seed, 1 } end
        if not DS.CanCarry(src, give) then return { error = 'Ton inventaire est plein.' } end
        DS.Add(src, cv.leaf, n)
        if seed then DS.Add(src, cv.seed, 1) end
        DS.Log('recolte', src, ('plante #%d %s → %d feuilles%s'):format(p.id, p.variety, n, seed and ' + 1 graine' or ''))
        resetPlant(p)
        msg = ('Récolte : %d × %s%s. Le pot est prêt pour une nouvelle graine.'):format(n, DS.Label(cv.leaf), seed and (' et 1 × ' .. DS.Label(cv.seed)) or '')
    elseif act == 'pickup' then
        DS.Add(src, 'plant_pot', 1)
        if p.lamp then DS.Add(src, 'grow_lamp', 1) end
        MySQL.query('DELETE FROM `drogues_plants` WHERE `id` = ?', { p.id })
        P[p.id] = nil
        TriggerClientEvent('elyzea_drogues:plant', -1, b.plant, nil)
        DS.Log('pot', src, ('pot #%d repris'):format(b.plant))
        return { ok = true, message = 'Pot repris.' }
    elseif act == 'clear' then
        resetPlant(p)
        msg = 'Plante morte retirée.'
    elseif act == 'destroy' then
        MySQL.query('DELETE FROM `drogues_plants` WHERE `id` = ?', { p.id })
        P[p.id] = nil
        TriggerClientEvent('elyzea_drogues:plant', -1, b.plant, nil)
        DS.Log('saisie', src, ('plante #%d (%s) détruite par la police'):format(b.plant, tostring(p.variety)))
        return { ok = true, message = 'Plante détruite et pot saisi.' }
    end
    p.lastAt = now
    DS.SavePlant(p)
    pushOne(p)
    return { ok = true, message = msg }
end)

-- Pour le staff : pots d'un joueur, suppression
function DS.PlantsList()
    local now, out = os.time(), {}
    for _, p in pairs(P) do
        refresh(p, now)
        out[#out + 1] = { id = p.id, owner = p.ownerName, variety = p.variety and S().varieties[p.variety].label or nil,
            pct = p.variety and Growth.Pct(S(), p) or 0, water = math.floor(p.water), health = math.floor(p.health), lamp = p.lamp, dead = p.dead,
            x = math.floor(p.x * 10) / 10, y = math.floor(p.y * 10) / 10, z = math.floor(p.z * 10) / 10 }
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end
function DS.DeletePlant(id)
    local p = P[id]
    if not p then return false end
    MySQL.query('DELETE FROM `drogues_plants` WHERE `id` = ?', { id })
    P[id] = nil
    TriggerClientEvent('elyzea_drogues:plant', -1, id, nil)
    return true
end
