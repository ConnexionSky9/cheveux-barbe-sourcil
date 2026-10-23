-- =====================================================================
--  ELYZEA EMS - règles de santé (sans FiveM : partagées et testées hors jeu)
--  Maladies et blessures, chute, contagion, transmission des MST,
--  recherche d'un patient par nom / prénom, rendez-vous.
-- =====================================================================
HealthRules = {}
local HR = HealthRules

local CURES = { treat = true, splint = true }
local TYPES = { illness = true, injury = true, std = true }

local function num(v, mn, mx, def)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return def end
    if mn and v < mn then v = mn end
    if mx and v > mx then v = mx end
    return v
end
HR.Num = num

local function clean(s, max)
    return (tostring(s or ''):gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, max or 80)
end
HR.Clean = clean

-- ---------------------------------------------------------------------
-- Réglages : valeurs de la config + celles enregistrées par le staff
-- ---------------------------------------------------------------------
-- Une maladie complète et sûre, à partir de sa définition (base) et des réglages du staff (o)
function HR.Condition(id, base, o)
    base, o = base or {}, o or {}
    local function pick(k) if o[k] ~= nil then return o[k] end return base[k] end
    local c = {
        id = id,
        label = clean(pick('label') or id, 60),
        type = TYPES[base.type] and base.type or 'illness',
        cure = CURES[base.cure] and base.cure or 'treat',
        known = pick('known') == true,
        enabled = pick('enabled') ~= false,
        durationMin = math.floor(num(pick('durationMin'), 0, 100000, 0)),
        durationMax = math.floor(num(pick('durationMax'), 0, 100000, 0)),
        randomPerHour = num(pick('randomPerHour'), 0, 100, 0),
        contagionRadius = num(pick('contagionRadius'), 0, 20, 0),
        contagionChance = num(pick('contagionChance'), 0, 100, 0),
        transmission = num(pick('transmission'), 0, 100, 0),
        symptomEvery = math.floor(num(pick('symptomEvery'), 0, 86400, 0)),
        symptoms = {},
    }
    if c.durationMax < c.durationMin then c.durationMax = c.durationMin end
    for _, s in ipairs(type(base.symptoms) == 'table' and base.symptoms or {}) do c.symptoms[#c.symptoms + 1] = clean(s, 140) end
    return c
end

-- Toutes les maladies (config + réglages), et les réglages généraux
function HR.Settings(cfg, saved)
    cfg, saved = cfg or {}, type(saved) == 'table' and saved or {}
    local sc = type(saved.conditions) == 'table' and saved.conditions or {}
    local out = { conditions = {}, order = {} }
    local ids = {}
    for id in pairs(cfg.conditions or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        out.conditions[id] = HR.Condition(id, cfg.conditions[id], sc[id])
        out.order[#out.order + 1] = id
    end
    local fall = cfg.fall or {}
    local sf = type(saved.fall) == 'table' and saved.fall or {}
    out.fall = {
        enabled = (sf.enabled == nil and fall.enabled ~= false) or sf.enabled == true,
        minHeight = num(sf.minHeight ~= nil and sf.minHeight or fall.minHeight, 2, 100, 6),
    }
    local sp = cfg.splint or {}
    local ssp = type(saved.splint) == 'table' and saved.splint or {}
    out.splint = { duration = math.floor(num(sp.duration, 1000, 60000, 8000)),
        healMinutes = math.floor(num(ssp.healMinutes ~= nil and ssp.healMinutes or sp.healMinutes, 0, 1440, 0)) }
    out.treat = { duration = math.floor(num((cfg.treat or {}).duration, 1000, 60000, 6000)) }
    out.enabled = (saved.enabled == nil and cfg.enabled ~= false) or saved.enabled == true
    out.tick = math.floor(num(cfg.tick, 10, 600, 60))
    return out
end

-- Nettoie ce que le staff envoie depuis le menu (seuls les champs réglables sont gardés)
function HR.CleanSaved(input, cfg)
    input = type(input) == 'table' and input or {}
    local out = { conditions = {} }
    if input.enabled ~= nil then out.enabled = input.enabled == true end
    for id in pairs((cfg or {}).conditions or {}) do
        local c = type(input.conditions) == 'table' and input.conditions[id]
        if type(c) == 'table' then
            local o = {}
            if c.enabled ~= nil then o.enabled = c.enabled == true end
            if c.known ~= nil then o.known = c.known == true end
            if c.label ~= nil and clean(c.label, 60) ~= '' then o.label = clean(c.label, 60) end
            for _, k in ipairs({ 'durationMin', 'durationMax', 'symptomEvery' }) do
                if c[k] ~= nil then o[k] = math.floor(num(c[k], 0, 100000, 0)) end
            end
            for _, k in ipairs({ 'randomPerHour', 'contagionChance', 'transmission' }) do
                if c[k] ~= nil then o[k] = num(c[k], 0, 100, 0) end
            end
            if c.contagionRadius ~= nil then o.contagionRadius = num(c.contagionRadius, 0, 20, 0) end
            if o.durationMin and o.durationMax and o.durationMax < o.durationMin then o.durationMax = o.durationMin end
            out.conditions[id] = o
        end
    end
    if type(input.fall) == 'table' then
        out.fall = { enabled = input.fall.enabled ~= false, minHeight = num(input.fall.minHeight, 2, 100, 6) }
    end
    if type(input.splint) == 'table' then out.splint = { healMinutes = math.floor(num(input.splint.healMinutes, 0, 1440, 0)) } end
    return out
end

-- ---------------------------------------------------------------------
-- Calculs
-- ---------------------------------------------------------------------
-- Tirage : pct en % (0-100) ; rnd() renvoie un nombre dans [0, 1)
function HR.Roll(pct, rnd)
    pct = num(pct, 0, 100, 0)
    if pct <= 0 then return false end
    if pct >= 100 then return true end
    return (rnd or math.random)() * 100 < pct
end

-- Fin d'une maladie (horodatage) ou nil si elle ne guérit pas toute seule
function HR.ExpiresAt(c, now, rnd)
    if not c or (c.durationMax or 0) <= 0 then return nil end
    local mn, mx = c.durationMin or 0, c.durationMax
    local minutes = mn + math.floor((rnd or math.random)() * (mx - mn + 1))
    if minutes > mx then minutes = mx end
    return now + math.max(1, minutes) * 60
end

-- Chute : blessure à la jambe ?
function HR.FallInjury(height, settings)
    local f = settings and settings.fall
    local c = settings and settings.conditions and settings.conditions.leg
    if not f or not f.enabled or not c or not c.enabled then return false end
    height = tonumber(height)
    return height ~= nil and height >= f.minHeight and height < 400
end

-- Chance de tomber malade par vérification (randomPerHour % par heure, vérifié toutes les tick s)
function HR.TickChance(perHour, tick)
    perHour = num(perHour, 0, 100, 0)
    if perHour <= 0 then return 0 end
    local p = 1 - (1 - perHour / 100) ^ ((tick or 60) / 3600)
    return p * 100
end

-- Contagion par minute de proximité -> par vérification
function HR.ContagionTickChance(perMinute, tick)
    perMinute = num(perMinute, 0, 100, 0)
    if perMinute <= 0 then return 0 end
    return (1 - (1 - perMinute / 100) ^ ((tick or 60) / 60)) * 100
end

-- Moment intime : MST transmises. a / b = { cid, kinds = { [id] = true } } ; renvoie { { cid, kind } }
function HR.Transmissions(a, b, protected, pct, settings, rnd)
    local out = {}
    if protected then return out end
    pct = num(pct, 0, 1, 1)
    for _, pair in ipairs({ { a, b }, { b, a } }) do
        local from, to = pair[1], pair[2]
        for kind in pairs(from.kinds or {}) do
            local c = settings.conditions[kind]
            if c and c.enabled and c.type == 'std' and not (to.kinds or {})[kind] and HR.Roll(c.transmission * pct, rnd) then
                out[#out + 1] = { cid = to.cid, kind = kind }
            end
        end
    end
    return out
end

-- Effets à appliquer chez le joueur (envoyés à LUI seul : jamais visibles des autres)
function HR.Effects(active, settings)
    local e = { limp = false, noSprint = false, cough = 0, symptoms = {} }
    for kind, r in pairs(active or {}) do
        local c = settings.conditions[kind]
        if c and c.enabled then
            if kind == 'leg' then
                if r.splinted then e.noSprint = true else e.limp = true e.noSprint = true end
            end
            if kind == 'cold' and (c.symptomEvery or 0) > 0 then
                e.cough = e.cough > 0 and math.min(e.cough, c.symptomEvery) or c.symptomEvery
            end
            if c.type == 'std' and (c.symptomEvery or 0) > 0 and #c.symptoms > 0 then
                e.symptoms[#e.symptoms + 1] = { every = c.symptomEvery, texts = c.symptoms }
            end
        end
    end
    return e
end

-- ---------------------------------------------------------------------
-- Recherche d'un patient par nom / prénom (dans n'importe quel ordre, sans accents ni majuscules)
-- ---------------------------------------------------------------------
local ACC = {}
for from, to in pairs({ a = 'àâäáãÀÂÄÁÃ', c = 'çÇ', e = 'éèêëÉÈÊË', i = 'îïíìÎÏÍÌ', o = 'ôöóòõÔÖÓÒÕ', u = 'ùûüúÙÛÜÚ', y = 'ÿýÝ', n = 'ñÑ' }) do
    for ch in to:gmatch('[\192-\223][\128-\191]') do ACC[ch] = from end
end
function HR.Fold(s)
    s = tostring(s or ''):gsub('[\192-\223][\128-\191]', function(ch) return ACC[ch] or ch end)
    return s:lower()
end
function HR.SearchTokens(q)
    local out = {}
    for w in HR.Fold(clean(q, 60)):gmatch('[^%s%-%%_\']+') do
        if #out < 4 then out[#out + 1] = w end
    end
    return out
end
function HR.NameMatches(name, tokens)
    if #tokens == 0 then return false end
    local n = HR.Fold(name)
    for _, t in ipairs(tokens) do if not n:find(t, 1, true) then return false end end
    return true
end

-- ---------------------------------------------------------------------
-- Rendez-vous
-- ---------------------------------------------------------------------
HR.APPT_STATUS = { pending = 'En attente', accepted = 'Accepté', done = 'Terminé', cancelled = 'Annulé', expired = 'Annulé (aucun EMS disponible)' }

-- Nouvel état d'un rendez-vous au temps now (expiration automatique), ou nil s'il ne change pas
function HR.ApptNext(row, now, cfg)
    if row.status == 'pending' and now - (row.created or now) >= (cfg.expireMinutes or 120) * 60 then return 'expired' end
    if row.status == 'accepted' and now - (row.accepted or row.created or now) >= (cfg.acceptedHours or 24) * 3600 then return 'done' end
    return nil
end

function HR.ApptType(cfg, id)
    for _, t in ipairs(cfg.types or {}) do if t.id == id then return t end end
    return nil
end

-- Prénom (notification « L'EMS Prénom a accepté votre rendez-vous »)
function HR.FirstName(full)
    return (tostring(full or ''):match('^%s*(%S+)') or tostring(full or ''))
end
