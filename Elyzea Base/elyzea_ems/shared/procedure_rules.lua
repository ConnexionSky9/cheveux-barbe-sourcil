-- =====================================================================
--  ELYZEA EMS - règles des actes médicaux en mini-jeux (pures, testées hors jeu)
--  Réglages (config + admin_menu), défi envoyé au client, vérification du
--  résultat, blessures RP, résultats d'examens, réanimation, vaccins.
--  Aucun résultat d'examen n'est inventé : il vient des blessures, maladies
--  ou grossesses enregistrées par le serveur.
-- =====================================================================
ProcRules = {}
local PR = ProcRules

local function num(v, mn, mx, def)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return def end
    if mn and v < mn then v = mn end
    if mx and v > mx then v = mx end
    return v
end
PR.Num = num

local function clean(s, max)
    return (tostring(s or ''):gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, max or 80)
end
local function item(s) s = tostring(s or ''):gsub('[^%w_%-]', '') return s:sub(1, 50) end
local function copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = copy(v) end
    return o
end
PR.Copy = copy

PR.ORDER = { 'blood', 'xray', 'cast', 'hemostasis', 'dressing', 'cpr', 'echo', 'scan', 'vaccine', 'implant', 'implant_remove' }
local CONSENT = { always = true, conscious = true }
local PATIENT = { any = true, conscious = true, down = true }

-- ---------------------------------------------------------------------
-- Réglages : config + valeurs enregistrées par le staff
-- ---------------------------------------------------------------------
local function items(list)
    local out = {}
    for _, it in ipairs(type(list) == 'table' and list or {}) do
        local name = item(it.item)
        if name ~= '' and #out < 4 then out[#out + 1] = { item = name, count = math.floor(num(it.count, 1, 20, 1)), consume = it.consume ~= false } end
    end
    return out
end

function PR.Settings(cfg, saved)
    cfg, saved = cfg or {}, type(saved) == 'table' and saved or {}
    local sa = type(saved.acts) == 'table' and saved.acts or {}
    local out = { enabled = (saved.enabled == nil and cfg.enabled ~= false) or saved.enabled == true, acts = {}, order = {} }
    out.distance = num(cfg.distance, 1, 6, 3)
    out.consentTimeout = math.floor(num(cfg.consentTimeout, 5, 120, 25))
    out.minRatio, out.maxRatio = num(cfg.minRatio, 0.1, 1, 0.35), num(cfg.maxRatio, 1.5, 10, 4)
    for _, id in ipairs(PR.ORDER) do
        local b = (cfg.acts or {})[id]
        if b then
            local o = type(sa[id]) == 'table' and sa[id] or {}
            local function pick(k) if o[k] ~= nil then return o[k] end return b[k] end
            out.acts[id] = {
                id = id, label = clean(b.label or id, 60), icon = b.icon or '🩺', perm = b.perm, service = b.service,
                enabled = pick('enabled') ~= false,
                minLevel = math.floor(num(pick('minLevel'), 0, 50, 0)),
                duration = math.floor(num(pick('duration'), 8, 120, 25)),
                difficulty = math.floor(num(pick('difficulty'), 1, 3, 2)),
                maxMistakes = math.floor(num(pick('maxMistakes'), 0, 10, 3)),
                retry = pick('retry') ~= false,
                consent = CONSENT[b.consent] and b.consent or false,
                patient = PATIENT[b.patient] and b.patient or 'any',
                items = items(o.items ~= nil and o.items or b.items),
            }
            out.order[#out.order + 1] = id
        end
    end
    -- zones
    out.zones, out.zoneById = {}, {}
    for _, z in ipairs(cfg.zones or {}) do
        if type(z.id) == 'string' then
            local v = { id = z.id, label = clean(z.label, 40), region = z.region or 'torso', xray = z.xray == true, cast = z.cast == true }
            out.zones[#out.zones + 1] = v
            out.zoneById[z.id] = v
        end
    end
    -- blessures
    local ij, sij = cfg.injuries or {}, type(saved.injuries) == 'table' and saved.injuries or {}
    local function ipick(k) if sij[k] ~= nil then return sij[k] end return ij[k] end
    local bl = type(sij.bleed) == 'table' and sij.bleed or {}
    out.injuries = {
        enabled = ipick('enabled') ~= false,
        minDamage = num(ij.minDamage, 1, 200, 8), cooldown = num(ij.cooldown, 1, 60, 4), maxActive = math.floor(num(ij.maxActive, 1, 20, 6)),
        bleed = { light = num(bl.light or (ij.bleed or {}).light, 1, 200, 8), major = num(bl.major or (ij.bleed or {}).major, 1, 200, 25),
            critical = num(bl.critical or (ij.bleed or {}).critical, 1, 400, 45) },
        fractureChance = num(ipick('fractureChance'), 0, 100, 35), fractureMajorDamage = num(ij.fractureMajorDamage, 1, 400, 40),
        internalChance = num(ipick('internalChance'), 0, 100, 25), internalMinDamage = num(ij.internalMinDamage, 1, 400, 30),
        fall = { majorHeight = num((ij.fall or {}).majorHeight, 3, 100, 12) },
        drain = { [1] = num((ij.drain or {})[1], 0, 50, 0), [2] = num((ij.drain or {})[2], 0, 50, 3), [3] = num((ij.drain or {})[3], 0, 50, 6) },
        drainFloor = num(ij.drainFloor, 101, 200, 120),
        healMinutes = math.floor(num(ipick('healMinutes'), 0, 1440, 0)),
    }
    if out.injuries.bleed.major < out.injuries.bleed.light then out.injuries.bleed.major = out.injuries.bleed.light end
    if out.injuries.bleed.critical < out.injuries.bleed.major then out.injuries.bleed.critical = out.injuries.bleed.major end
    out.bleedLevels = cfg.bleedLevels or {}
    out.fractureLevels = cfg.fractureLevels or {}
    out.internalLabels = cfg.internalLabels or {}
    -- hémorragie
    local h, sh = cfg.hemostasis or {}, type(saved.hemostasis) == 'table' and saved.hemostasis or {}
    local ss = type(sh.seconds) == 'table' and sh.seconds or {}
    out.hemostasis = { seconds = {}, dressingFrom = math.floor(num(sh.dressingFrom ~= nil and sh.dressingFrom or h.dressingFrom, 1, 4, 2)),
        assistBonus = num(h.assistBonus, 0, 0.2, 0.06) }
    for lv = 1, 3 do out.hemostasis.seconds[lv] = math.floor(num(ss[lv] or ss[tostring(lv)] or (h.seconds or {})[lv], 5, 60, 10 + lv * 8)) end
    -- réanimation
    local c, sc = cfg.cpr or {}, type(saved.cpr) == 'table' and saved.cpr or {}
    local function cpick(k) if sc[k] ~= nil then return sc[k] end return c[k] end
    out.cpr = {
        compressions = math.floor(num(c.compressions, 10, 60, 30)), bpm = math.floor(num(c.bpm, 80, 140, 110)),
        passScore = num(cpick('passScore'), 0.3, 0.95, 0.6),
        base = num(cpick('base'), 0, 1, 0.15), perScore = num(cpick('perScore'), 0, 1, 0.3),
        perSequence = num(c.perSequence, 0, 0.5, 0.05), maxSequenceBonus = num(c.maxSequenceBonus, 0, 1, 0.2),
        stabilized = num(cpick('stabilized'), 0, 1, 0.15), defibrillator = num(cpick('defibrillator'), 0, 1, 0.2),
        defibItem = item(c.defibItem or 'defibrillator'), bleeding = num(cpick('bleeding'), 0, 1, 0.3),
        min = num(c.min, 0, 1, 0.03), max = num(cpick('max'), 0, 1, 0.85),
        extendSeconds = math.floor(num(c.extendSeconds, 0, 600, 60)), health = math.floor(num(c.health, 101, 200, 130)),
    }
    -- attelle / plâtre
    local cm, scm = (cfg.cast or {}).materials or {}, type(saved.castItems) == 'table' and saved.castItems or {}
    out.cast = { materials = {}, requireXray = (cfg.cast or {}).requireXray ~= false }
    for _, m in ipairs(cm) do
        local lv = {}
        for _, t in ipairs(m.treats or {}) do lv[math.floor(num(t, 1, 2, 1))] = true end
        out.cast.materials[#out.cast.materials + 1] = { id = m.id, label = clean(m.label, 40), item = item(scm[m.id] or m.item), treats = lv }
    end
    -- prise de sang, échographie, scanner
    out.blood = copy(cfg.blood or { tubes = {}, analyses = {} })
    out.echo = copy(cfg.echo or { types = {} })
    out.scan = copy(cfg.scan or { types = {} })
    -- vaccins
    local sv = type(saved.vaccines) == 'table' and saved.vaccines or {}
    out.vaccines, out.vaccineById = {}, {}
    for _, v in ipairs(cfg.vaccines or {}) do
        if type(v.id) == 'string' then
            local o = type(sv[v.id]) == 'table' and sv[v.id] or {}
            local function vpick(k) if o[k] ~= nil then return o[k] end return v[k] end
            local x = { id = v.id, label = clean(vpick('label') or v.id, 60), item = item(vpick('item')), enabled = vpick('enabled') ~= false,
                zone = v.zone or 'deltoide', protects = copy(v.protects or {}),
                delayHours = num(vpick('delayHours'), 0, 720, 0), protectionDays = num(vpick('protectionDays'), 0, 3650, 0),
                boosterDays = num(vpick('boosterDays'), 0, 3650, 0),
                contraindications = { active = copy((v.contraindications or {}).active or {}) } }
            out.vaccines[#out.vaccines + 1] = x
            out.vaccineById[x.id] = x
        end
    end
    out.injectionZones = copy(cfg.injectionZones or {})
    -- comptes rendus
    local sr = type(saved.reports) == 'table' and saved.reports or {}
    out.reports = {}
    for k, v in pairs(cfg.reports or {}) do
        out.reports[k] = (type(sr[k]) == 'string' and clean(sr[k], 240) ~= '') and clean(sr[k], 240) or v
    end
    return out
end

-- Nettoie ce que le staff envoie (seuls les champs réglables sont gardés)
function PR.CleanSaved(input, cfg)
    input = type(input) == 'table' and input or {}
    local out = { acts = {} }
    if input.enabled ~= nil then out.enabled = input.enabled == true end
    for _, id in ipairs(PR.ORDER) do
        local a = type(input.acts) == 'table' and input.acts[id]
        if type(a) == 'table' and (cfg.acts or {})[id] then
            local o = {}
            if a.enabled ~= nil then o.enabled = a.enabled == true end
            if a.retry ~= nil then o.retry = a.retry == true end
            if a.minLevel ~= nil then o.minLevel = math.floor(num(a.minLevel, 0, 50, 0)) end
            if a.duration ~= nil then o.duration = math.floor(num(a.duration, 8, 120, 25)) end
            if a.difficulty ~= nil then o.difficulty = math.floor(num(a.difficulty, 1, 3, 2)) end
            if a.maxMistakes ~= nil then o.maxMistakes = math.floor(num(a.maxMistakes, 0, 10, 3)) end
            if type(a.items) == 'table' then o.items = items(a.items) end
            out.acts[id] = o
        end
    end
    if type(input.injuries) == 'table' then
        local i = input.injuries
        out.injuries = {}
        if i.enabled ~= nil then out.injuries.enabled = i.enabled == true end
        for _, k in ipairs({ 'fractureChance', 'internalChance' }) do if i[k] ~= nil then out.injuries[k] = num(i[k], 0, 100, 0) end end
        if i.healMinutes ~= nil then out.injuries.healMinutes = math.floor(num(i.healMinutes, 0, 1440, 0)) end
        if type(i.bleed) == 'table' then
            out.injuries.bleed = { light = num(i.bleed.light, 1, 200, 8), major = num(i.bleed.major, 1, 200, 25), critical = num(i.bleed.critical, 1, 400, 45) }
        end
    end
    if type(input.hemostasis) == 'table' then
        out.hemostasis = { seconds = {} }
        for lv = 1, 3 do
            local s = type(input.hemostasis.seconds) == 'table' and (input.hemostasis.seconds[lv] or input.hemostasis.seconds[tostring(lv)])
            if s ~= nil then out.hemostasis.seconds[lv] = math.floor(num(s, 5, 60, 10 + lv * 8)) end
        end
        if input.hemostasis.dressingFrom ~= nil then out.hemostasis.dressingFrom = math.floor(num(input.hemostasis.dressingFrom, 1, 4, 2)) end
    end
    if type(input.cpr) == 'table' then
        out.cpr = {}
        for _, k in ipairs({ 'passScore', 'base', 'perScore', 'stabilized', 'defibrillator', 'bleeding', 'max' }) do
            if input.cpr[k] ~= nil then out.cpr[k] = num(input.cpr[k], k == 'passScore' and 0.3 or 0, k == 'passScore' and 0.95 or 1, 0) end
        end
    end
    if type(input.castItems) == 'table' then
        out.castItems = {}
        for _, m in ipairs((cfg.cast or {}).materials or {}) do
            if input.castItems[m.id] ~= nil and item(input.castItems[m.id]) ~= '' then out.castItems[m.id] = item(input.castItems[m.id]) end
        end
    end
    if type(input.vaccines) == 'table' then
        out.vaccines = {}
        for _, v in ipairs(cfg.vaccines or {}) do
            local x = input.vaccines[v.id]
            if type(x) == 'table' then
                local o = {}
                if x.enabled ~= nil then o.enabled = x.enabled == true end
                if x.label ~= nil and clean(x.label, 60) ~= '' then o.label = clean(x.label, 60) end
                if x.item ~= nil and item(x.item) ~= '' then o.item = item(x.item) end
                if x.delayHours ~= nil then o.delayHours = num(x.delayHours, 0, 720, 0) end
                if x.protectionDays ~= nil then o.protectionDays = num(x.protectionDays, 0, 3650, 0) end
                if x.boosterDays ~= nil then o.boosterDays = num(x.boosterDays, 0, 3650, 0) end
                out.vaccines[v.id] = o
            end
        end
    end
    if type(input.reports) == 'table' then
        out.reports = {}
        for k in pairs(cfg.reports or {}) do
            if type(input.reports[k]) == 'string' and clean(input.reports[k], 240) ~= '' then out.reports[k] = clean(input.reports[k], 240) end
        end
    end
    return out
end

-- ---------------------------------------------------------------------
-- Défi envoyé au client, et vérification du résultat
-- ---------------------------------------------------------------------
-- ctx : données de l'acte choisies par le serveur (zone, tube attendu, gravité…)
function PR.Challenge(act, set, ctx, rnd)
    local a = set.acts[act]
    if not a then return nil end
    rnd = rnd or math.random
    ctx = ctx or {}
    local duration = a.duration
    if act == 'hemostasis' then duration = set.hemostasis.seconds[ctx.severity or 1] or duration end
    return {
        id = math.floor(rnd() * 899999) + 100000, act = act, title = ctx.title or a.label, icon = a.icon,
        seed = math.floor(rnd() * 2147483000) + 1, duration = duration, difficulty = a.difficulty,
        maxMistakes = a.maxMistakes, extra = ctx.extra or {},
    }
end

-- res = { id, ok, cancelled, mistakes, score (0-1), choice } ; elapsed = secondes côté serveur
-- Renvoie true, ou false + 'cancel' | 'fail' | 'invalid'
function PR.Check(ch, res, elapsed, set)
    if type(ch) ~= 'table' then return false, 'invalid' end
    if type(res) ~= 'table' or tonumber(res.id) ~= ch.id then return false, 'invalid' end
    if res.cancelled == true then return false, 'cancel' end
    local mistakes, score = tonumber(res.mistakes), tonumber(res.score)
    if not mistakes or mistakes < 0 or mistakes % 1 ~= 0 or not score or score < 0 or score > 1 then return false, 'invalid' end
    elapsed = tonumber(elapsed) or 0
    if elapsed > ch.duration * (set.maxRatio or 4) + 20 then return false, 'invalid' end
    if res.ok ~= true then return false, 'fail' end
    if mistakes > ch.maxMistakes then return false, 'invalid' end
    -- impossible de finir plus vite qu'une fraction de la durée prévue
    if elapsed < ch.duration * (set.minRatio or 0.35) then return false, 'invalid' end
    -- choix imposé par le serveur (tube, zone d'injection) : le client ne peut pas le changer
    local x = ch.extra or {}
    if x.expect ~= nil and tostring(res.choice or '') ~= tostring(x.expect) then return false, 'invalid' end
    return true
end

-- ---------------------------------------------------------------------
-- Blessures
-- ---------------------------------------------------------------------
-- Os touché (GetPedLastDamageBone) → zone
PR.BONES = {
    [31086] = 'tete', [39317] = 'tete', [12844] = 'tete', [65068] = 'tete',
    [24818] = 'thorax', [24817] = 'thorax', [10706] = 'thorax', [64729] = 'thorax',
    [24816] = 'abdomen', [23553] = 'abdomen', [11816] = 'abdomen', [57597] = 'abdomen', [0] = 'abdomen',
    [45509] = 'bras_g', [61163] = 'avantbras_g', [18905] = 'avantbras_g',
    [40269] = 'bras_d', [28252] = 'avantbras_d', [57005] = 'avantbras_d',
    [58271] = 'jambe_g', [63931] = 'jambe_g', [14201] = 'jambe_g', [2108] = 'jambe_g',
    [51826] = 'jambe_d', [36864] = 'jambe_d', [52301] = 'jambe_d', [20781] = 'jambe_d',
}
function PR.ZoneFromBone(bone) return PR.BONES[tonumber(bone) or -1] end

-- group : 'bullet' | 'blade' | 'blunt' | 'vehicle' ; renvoie { type, severity } ou nil
function PR.InjuryFromDamage(set, zone, group, damage, rnd)
    local I = set.injuries
    local z = set.zoneById[zone or '']
    damage = tonumber(damage) or 0
    if not I.enabled or not z or damage < I.minDamage then return nil end
    rnd = rnd or math.random
    if group == 'bullet' or group == 'blade' then
        local sev = damage >= I.bleed.critical and 3 or (damage >= I.bleed.major and 2 or 1)
        return { type = 'hemorrhage', severity = sev }
    end
    if group == 'blunt' or group == 'vehicle' then
        if z.region == 'arm' or z.region == 'leg' then
            if rnd() * 100 < I.fractureChance then return { type = 'fracture', severity = damage >= I.fractureMajorDamage and 2 or 1 } end
        elseif damage >= I.internalMinDamage and rnd() * 100 < I.internalChance then
            return { type = 'internal', severity = damage >= I.internalMinDamage * 1.6 and 2 or 1 }
        end
    end
    return nil
end

-- Chute : fracture d'une jambe (gravité selon la hauteur)
function PR.FallFracture(set, height, rnd)
    local z = (rnd or math.random)() < 0.5 and 'jambe_g' or 'jambe_d'
    return { type = 'fracture', zone = z, severity = (tonumber(height) or 0) >= set.injuries.fall.majorHeight and 2 or 1 }
end

-- Libellé d'une blessure
function PR.InjuryLabel(set, inj)
    local z = set.zoneById[inj.zone or '']
    if inj.type == 'hemorrhage' then return set.bleedLevels[inj.severity] or 'Hémorragie' end
    if inj.type == 'fracture' then return set.fractureLevels[inj.severity] or 'Fracture' end
    if inj.type == 'internal' then return set.internalLabels[z and z.region or ''] or 'Lésion interne' end
    return inj.type
end

-- Radiographie d'une zone : 'none' | 'immob' | 'fracture' (+ blessure concernée)
function PR.XrayResult(injuries, zone)
    local best
    for _, inj in ipairs(injuries or {}) do
        if inj.type == 'fracture' and inj.zone == zone and inj.status == 'active' and (not best or inj.severity > best.severity) then best = inj end
    end
    if not best then return 'none', nil end
    return best.severity >= 2 and 'fracture' or 'immob', best
end

-- Scanner / échographie : constatations dans les régions examinées (blessures actives seulement)
function PR.ImagingFindings(set, injuries, regions)
    local want = {}
    for _, r in ipairs(regions or {}) do want[r] = true end
    local out = {}
    for _, inj in ipairs(injuries or {}) do
        local z = set.zoneById[inj.zone or '']
        if z and want[z.region] and inj.status ~= 'healed' and (inj.type == 'internal' or inj.type == 'fracture' or inj.type == 'hemorrhage') then
            out[#out + 1] = { id = inj.id, type = inj.type, zone = inj.zone, zoneLabel = z.label, severity = inj.severity, label = PR.InjuryLabel(set, inj) }
        end
    end
    table.sort(out, function(a, b) return (a.severity or 0) > (b.severity or 0) end)
    return out
end

-- Matériel adapté à la blessure ?
function PR.CastAllowed(material, injury)
    return material ~= nil and injury ~= nil and injury.type == 'fracture' and material.treats[injury.severity] == true
end

-- Hémorragie la plus grave encore active (non contrôlée)
function PR.WorstBleed(injuries)
    local best
    for _, inj in ipairs(injuries or {}) do
        if inj.type == 'hemorrhage' and inj.status == 'active' and (not best or inj.severity > best.severity) then best = inj end
    end
    return best
end

-- ---------------------------------------------------------------------
-- Réanimation : chance de reprise après une séquence réussie
-- ctx = { score (0-1), previous (séquences réussies avant), stabilized, defib, bleeding (gravité active non contrôlée) }
-- ---------------------------------------------------------------------
function PR.CprChance(set, ctx)
    local c = set.cpr
    local p = c.base + (num(ctx.score, 0, 1, 0)) * c.perScore
    p = p + math.min(c.maxSequenceBonus, (tonumber(ctx.previous) or 0) * c.perSequence)
    if ctx.stabilized then p = p + c.stabilized end
    if ctx.defib then p = p + c.defibrillator end
    if (tonumber(ctx.bleeding) or 0) >= 2 then p = p - c.bleeding end
    return math.max(c.min, math.min(c.max, p))
end

-- ---------------------------------------------------------------------
-- Vaccins
-- ---------------------------------------------------------------------
-- history : { { vaccine, given_at, expires_at } } ; active : { [kind] = true } maladies en cours
function PR.VaccineCheck(v, history, active, now)
    if not v or not v.enabled then return false, 'Vaccin indisponible.' end
    for _, k in ipairs(v.contraindications.active or {}) do
        if active and active[k] then return false, 'Contre-indication : le patient est actuellement malade.' end
    end
    for _, h in ipairs(history or {}) do
        if h.vaccine == v.id and v.boosterDays > 0 and now - (tonumber(h.given_at) or 0) < v.boosterDays * 86400 then
            return false, 'Ce vaccin a déjà été fait récemment (rappel trop tôt).'
        end
    end
    return true
end

function PR.VaccineDates(v, now)
    local eff = now + math.floor(v.delayHours * 3600)
    local exp = v.protectionDays > 0 and (eff + math.floor(v.protectionDays * 86400)) or nil
    return eff, exp
end

-- Protégé contre la maladie « kind » ? rows : { { vaccine, effective_at, expires_at } }
function PR.Immune(set, rows, kind, now)
    for _, r in ipairs(rows or {}) do
        local v = set.vaccineById[r.vaccine]
        if v then
            for _, k in ipairs(v.protects or {}) do
                if k == kind and (tonumber(r.effective_at) or 0) <= now and (not tonumber(r.expires_at) or tonumber(r.expires_at) > now) then return true end
            end
        end
    end
    return false
end

-- ---------------------------------------------------------------------
-- Textes
-- ---------------------------------------------------------------------
function PR.Fill(tpl, vars)
    return (tostring(tpl or ''):gsub('{(%w+)}', function(k) local v = (vars or {})[k] return v ~= nil and tostring(v) or '' end))
end

-- Accès de base à un acte (le serveur ajoute distance, service, verrous…)
-- level : niveau du grade de l'EMS ; can(perm) : la permission est-elle accordée ?
function PR.CanUse(set, act, level, can)
    local a = set.acts[act]
    if not set.enabled or not a or not a.enabled then return false, 'Cet acte est désactivé.' end
    if a.perm and not can(a.perm) then return false, 'Votre grade ne permet pas cet acte.' end
    if a.minLevel > 0 and (tonumber(level) or 0) < a.minLevel then return false, 'Votre grade ne permet pas cet acte.' end
    return true
end
