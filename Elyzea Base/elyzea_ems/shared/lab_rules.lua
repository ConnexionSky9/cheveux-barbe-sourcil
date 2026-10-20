-- =====================================================================
--  ELYZEA EMS - règles du laboratoire (pures, testées hors jeu)
--  Calcule le résultat d'une analyse à partir des consommations ENREGISTRÉES
--  jusqu'à l'heure du prélèvement. Aucun hasard : mêmes données = même résultat.
--  Résultats simulés pour le jeu de rôle, pas des mesures médicales réelles.
-- =====================================================================
LabRules = {}

local function round(v, n) local m = 10 ^ (n or 2) return math.floor(v * m + 0.5) / m end

-- Consommations d'une substance faites avant le prélèvement, triées par date
local function before(list, sampleT)
    local out = {}
    for _, c in ipairs(list or {}) do
        local t = tonumber(c.at)
        if t and t <= sampleT then out[#out + 1] = { at = t, amount = tonumber(c.amount) or 1 } end
    end
    table.sort(out, function(a, b) return a.at < b.at end)
    return out
end

-- Le suivi des consommations couvre-t-il toute la période utile avant le prélèvement ?
local function covered(trackingSince, sampleT, hours)
    return tonumber(trackingSince) ~= nil and trackingSince <= sampleT - hours * 3600
end

-- Ancienneté de la dernière prise, sans heure exacte (le labo ne la connaît pas)
local function recency(lastAt, sampleT, recentHours)
    if not lastAt then return nil end
    local h = (sampleT - lastAt) / 3600
    if h <= recentHours then return { recent = true, text = ('Consommation récente (moins de %d h avant le prélèvement)'):format(recentHours) } end
    return { recent = false, text = ('Consommation plus ancienne (plus de %d h avant le prélèvement)'):format(recentHours) }
end

-- Alcoolémie simulée (g/L) au moment du prélèvement : formule de Widmark,
-- chaque verre s'ajoute, l'élimination est linéaire dans le temps.
function LabRules.Bac(drinks, sampleT, cfg)
    local w = (tonumber(cfg.bodyWeight) or 70) * (tonumber(cfg.diffusion) or 0.65)
    local rate = tonumber(cfg.eliminationPerHour) or 0.15
    local level, t = 0.0, nil
    for _, d in ipairs(drinks) do
        if t then level = math.max(0.0, level - rate * (d.at - t) / 3600) end
        level = level + d.amount / w
        t = d.at
    end
    if t then level = math.max(0.0, level - rate * (sampleT - t) / 3600) end
    return round(level, 2)
end

function LabRules.AlcoholLevel(bac, th)
    if bac <= 0 then return 'nul' end
    if bac < (th.moderate or 0.5) then return 'faible' end
    if bac < (th.high or 1.0) then return 'modere' end
    return 'eleve'
end

-- Section alcool. status : 'positive' | 'negative' | 'indeterminate'
function LabRules.Alcohol(records, sampleT, trackingSince, cfg)
    local window = tonumber(cfg.detectionHours) or 12
    local drinks = {}
    for _, d in ipairs(before(records, sampleT)) do
        if d.at >= sampleT - window * 3600 then drinks[#drinks + 1] = d end
    end
    local bac = LabRules.Bac(drinks, sampleT, cfg)
    local last = drinks[#drinks] and drinks[#drinks].at or nil
    local r = { bac = bac, level = LabRules.AlcoholLevel(bac, cfg.thresholds or {}), drinks = #drinks }
    if bac > 0 then
        r.status, r.present = 'positive', true
        r.recency = recency(last, sampleT, tonumber(cfg.recentHours) or 2)
    elseif covered(trackingSince, sampleT, window) then
        r.status, r.present = 'negative', false
        if last then r.note = 'Consommation enregistrée mais déjà éliminée au moment du prélèvement.' end
    else
        -- suivi trop récent : on ne peut pas affirmer l'absence d'alcool
        r.status, r.present, r.level, r.bac = 'indeterminate', nil, nil, nil
        r.note = 'Données de consommation insuffisantes pour cette période.'
    end
    return r
end

-- Une substance du dépistage. hasSource : la substance est reliée à des objets ou à un script
function LabRules.Substance(sub, records, sampleT, trackingSince, hasSource)
    local window = tonumber(sub.detectionHours) or 48
    local last
    for _, d in ipairs(before(records, sampleT)) do
        if d.at >= sampleT - window * 3600 then last = d.at end
    end
    local r = { id = sub.id, label = sub.label }
    if last then
        r.status = 'positive'
        r.recency = recency(last, sampleT, tonumber(sub.recentHours) or 4)
    elseif not hasSource then
        r.status = 'indeterminate'
        r.note = 'Aucune donnée de consommation n\'est reliée à cette substance sur le serveur.'
    elseif covered(trackingSince, sampleT, window) then
        r.status = 'negative'
    else
        r.status = 'indeterminate'
        r.note = 'Données de consommation insuffisantes pour cette période.'
    end
    return r
end

-- Analyse complète. byKind = { alcohol = {…}, thc = {…}, … } (listes { at, amount })
-- sources = { thc = true, … } : substances reliées à une source de données
function LabRules.Analyze(byKind, sampleT, trackingSince, labCfg, sources)
    local out = { alcohol = LabRules.Alcohol(byKind.alcohol or {}, sampleT, trackingSince, labCfg.alcohol), substances = {} }
    for _, sub in ipairs(labCfg.substances or {}) do
        out.substances[#out.substances + 1] = LabRules.Substance(sub, byKind[sub.id] or {}, sampleT, trackingSince, sources and sources[sub.id] == true)
    end
    return out
end
