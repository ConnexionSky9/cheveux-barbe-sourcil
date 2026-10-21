-- =====================================================================
--  ELYZEA LABS · règles partagées (serveur + client) : niveaux, recettes, créneaux d'attaque
-- =====================================================================
LabRules = {}

local function copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = copy(v) end
    return o
end
LabRules.copy = copy

function LabRules.MaxLevel() return #Config.Levels end
function LabRules.Level(n) return Config.Levels[math.max(1, math.min(#Config.Levels, tonumber(n) or 1))] end

-- Catégories débloquées jusqu'au niveau n
function LabRules.Unlocked(n)
    local set = {}
    for i = 1, math.min(#Config.Levels, tonumber(n) or 1) do
        for _, c in ipairs(Config.Levels[i].unlocks or {}) do set[c] = i end
    end
    return set
end

-- Niveau qui débloque une catégorie
function LabRules.CategoryLevel(cat)
    for i, l in ipairs(Config.Levels) do
        for _, c in ipairs(l.unlocks or {}) do if c == cat then return i end end
    end
    return math.huge
end

function LabRules.EquipmentLevel(eq)
    local e = Config.Equipment[eq]
    return e and LabRules.CategoryLevel(e.category) or math.huge
end

-- Recettes d'un équipement, triées
function LabRules.RecipesFor(eq)
    local list = {}
    for id, r in pairs(Config.Recipes) do if r.equipment == eq and r.enabled ~= false then list[#list + 1] = { id = id, r = r } end end
    table.sort(list, function(a, b)
        if (a.r.order or 0) ~= (b.r.order or 0) then return (a.r.order or 0) < (b.r.order or 0) end
        return a.id < b.id
    end)
    return list
end

-- ---------------------------------------------------------------------
--  Créneaux d'attaque
-- ---------------------------------------------------------------------
local function minutes(s)
    local h, m = tostring(s or ''):match('^(%d%d?):(%d%d)$')
    h, m = tonumber(h), tonumber(m)
    if not h or not m or h > 24 or m > 59 or (h == 24 and m > 0) then return nil end
    return h * 60 + m
end
LabRules.minutes = minutes

-- Heure locale du serveur (fuseau réglé) : { iso = 1..7 (lundi = 1), min = minutes depuis minuit }
function LabRules.LocalTime(now, utcOffset)
    local t = os.date('!*t', (now or os.time()) + math.floor((tonumber(utcOffset) or 0) * 3600))
    return { iso = (t.wday + 5) % 7 + 1, min = t.hour * 60 + t.min, hour = t.hour, minute = t.min }
end

-- Vrai si une attaque peut commencer maintenant. Un créneau peut passer minuit (ex. 22:00 → 02:00 :
-- la partie après minuit compte pour le jour où le créneau a commencé).
function LabRules.InSchedule(raids, now)
    if not raids or not raids.enabled then return false end
    local lt = LabRules.LocalTime(now, raids.utcOffset)
    for _, s in ipairs(raids.slots or {}) do
        local from, to = minutes(s.from), minutes(s.to)
        if from and to then
            local days = {}
            for _, d in ipairs(s.days or {}) do days[tonumber(d)] = true end
            if from <= to then
                if days[lt.iso] and lt.min >= from and lt.min < to then return true, s end
            else
                local prev = (lt.iso + 5) % 7 + 1
                if (days[lt.iso] and lt.min >= from) or (days[prev] and lt.min < to) then return true, s end
            end
        end
    end
    return false
end

-- Nettoie les réglages d'attaque (menu admin ou base) ; base = valeurs actuelles
function LabRules.CleanRaids(d, base)
    d = type(d) == 'table' and d or {}
    local o = copy(base or Config.Raids)
    local function num(k, mn, mx, int)
        local v = tonumber(d[k])
        if v and v == v then v = math.max(mn, math.min(mx, v)) o[k] = int and math.floor(v + 0.5) or v end
    end
    local function bool(k) if d[k] ~= nil then o[k] = d[k] == true end end
    bool('enabled') bool('starterBossOnly') bool('lockDuringRaid') bool('kickOnCapture') bool('notifyAllMembers')
    num('utcOffset', -12, 14) num('prepSeconds', 0, 600, true) num('duration', 60, 7200, true) num('radius', 10, 500)
    num('minAttackers', 1, 50, true) num('minDefendersOnline', 0, 50, true) num('emptyGrace', 5, 600, true)
    num('labCooldown', 0, 10080, true) num('groupCooldown', 0, 10080, true)
    if d.winRule == 'present' or d.winRule == 'majority' then o.winRule = d.winRule end
    if type(d.slots) == 'table' then
        local slots = {}
        for _, s in ipairs(d.slots) do
            if type(s) == 'table' and minutes(s.from) and minutes(s.to) and minutes(s.from) ~= minutes(s.to) then
                local days, seen = {}, {}
                for _, x in ipairs(type(s.days) == 'table' and s.days or {}) do
                    x = math.floor(tonumber(x) or 0)
                    if x >= 1 and x <= 7 and not seen[x] then seen[x] = true days[#days + 1] = x end
                end
                table.sort(days)
                if #days > 0 then slots[#slots + 1] = { days = days, from = s.from, to = s.to } end
            end
            if #slots >= 20 then break end
        end
        o.slots = slots
    end
    return o
end

-- Prochaine ouverture (texte pour la tablette), recherche minute par minute sur 7 jours (pas de 15 min)
function LabRules.NextWindow(raids, now)
    now = now or os.time()
    if not raids or not raids.enabled then return nil end
    for step = 0, 7 * 24 * 4 do
        local t = now + step * 900
        if LabRules.InSchedule(raids, t) then return t end
    end
    return nil
end
