-- =====================================================================
--  ELYZEA DROGUES · règles pures (serveur et tests hors jeu)
-- =====================================================================
DrugRules = {}

local function int(v, lo, hi, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    return math.max(lo, math.min(hi, math.floor(v)))
end
DrugRules.int = int

-- Réglages par défaut tirés de config.lua
function DrugRules.Defaults()
    local s = { drugs = {}, trip = {}, creatures = {} }
    for id, d in pairs(Config.Drugs) do s.drugs[id] = { enabled = true, duration = d.duration, cooldown = d.cooldown } end
    local t = Config.Trip
    s.trip = { maxCreatures = t.maxCreatures, spawnEvery = t.spawnEvery, hitCooldown = t.hitCooldown, fallTime = t.fallTime, lifetime = t.lifetime }
    for _, c in ipairs(t.creatures) do s.creatures[c.model] = true end
    return s
end

-- Nettoie des réglages venus du menu (ou de la base) : bornes, drogues et créatures connues uniquement
function DrugRules.Clean(input)
    local def = DrugRules.Defaults()
    if type(input) ~= 'table' then return def end
    local out = { drugs = {}, trip = {}, creatures = {} }
    for id, d in pairs(def.drugs) do
        local x = type(input.drugs) == 'table' and input.drugs[id] or nil
        x = type(x) == 'table' and x or {}
        out.drugs[id] = {
            enabled = x.enabled ~= false,
            duration = int(x.duration, 10, 3600, d.duration),
            cooldown = int(x.cooldown, 0, 3600, d.cooldown),
        }
    end
    local t = type(input.trip) == 'table' and input.trip or {}
    out.trip = {
        maxCreatures = int(t.maxCreatures, 1, 12, def.trip.maxCreatures),
        spawnEvery = int(t.spawnEvery, 2, 120, def.trip.spawnEvery),
        hitCooldown = int(t.hitCooldown, 1, 60, def.trip.hitCooldown),
        fallTime = int(t.fallTime, 1, 15, def.trip.fallTime),
        lifetime = int(t.lifetime, 5, 300, def.trip.lifetime),
    }
    local any = false
    for model in pairs(def.creatures) do
        local on = not (type(input.creatures) == 'table' and input.creatures[model] == false)
        out.creatures[model] = on
        if on then any = true end
    end
    if not any then return nil, 'Garde au moins une créature pour les hallucinations.' end
    return out
end

-- Drogue déclenchée par un objet (nil si l'objet n'est pas une drogue)
function DrugRules.DrugOfItem(item)
    for id, d in pairs(Config.Drugs) do
        for _, it in ipairs(d.items) do if it == item then return id end end
    end
end

-- Fin de l'effet après une prise : la même drogue reprise prolonge, jusqu'à maxStack × la durée
function DrugRules.Extend(currentUntil, now, duration, maxStack)
    local base = math.max(currentUntil or 0, now)
    return math.min(base + duration, now + duration * (maxStack or 2))
end
