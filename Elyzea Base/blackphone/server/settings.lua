-- =====================================================================
--  BLACKPHONE - serveur : réglages persistants (bp_settings), tous revalidés ici
-- =====================================================================
local P = BPS

local function num(v, mn, mx, def) v = tonumber(v) if not v or v ~= v then return def end return math.min(mx, math.max(mn, v)) end
local function int(v, mn, mx, def) return math.floor(num(v, mn, mx, def)) end
local function bool(v, def) if v == nil then return def end return v == true end
local function str(v, max, def) if type(v) ~= 'string' and type(v) ~= 'number' then return def end v = tostring(v):gsub('[<>"]', ''):gsub('^%s+', ''):gsub('%s+$', '') if v == '' then return def end return v:sub(1, max) end
local function ident(v, def) v = str(v, 60, nil) v = v and v:gsub('[^%w_%-]', '') return (v and v ~= '') and v or def end
local function choice(v, l, def) for _, x in ipairs(l) do if v == x then return v end end return def end
local function list(t, fn, max) local o = {} for _, v in ipairs(type(t) == 'table' and t or {}) do local x = fn(v) if x ~= nil then o[#o + 1] = x end if #o >= (max or 50) then break end end return o end
local PAY = { 'cash', 'bank', 'item' }

function P.Sanitize(raw)
    local D = Config.Defaults
    local S = BP.Merge(D, raw)
    local o = {}
    local g = S.general
    o.general = { enabled = bool(g.enabled, true), phoneItem = ident(g.phoneItem, 'blackphone'), laptopItem = ident(g.laptopItem, 'police_laptop'),
        moneyType = choice(g.moneyType, PAY, 'cash'), moneyItem = ident(g.moneyItem, 'black_money'), sounds = bool(g.sounds, true), volume = int(g.volume, 0, 100, 35),
        auditDays = int(g.auditDays, 7, 365, 60), messageDays = int(g.messageDays, 1, 365, 30) }
    o.apps = {}
    for k in pairs(D.apps) do o.apps[k] = bool(S.apps[k], true) end
    local pr = S.profile
    o.profile = { aliasMin = int(pr.aliasMin, 2, 10, 3), aliasMax = int(pr.aliasMax, 6, 24, 18), renameCooldownHours = int(pr.renameCooldownHours, 0, 720, 72), renameCost = int(pr.renameCost, 0, 10000000, 5000) }
    local c = S.chat
    o.chat = { maxGroupMembers = int(c.maxGroupMembers, 2, 50, 12), maxGroups = int(c.maxGroups, 1, 30, 6), maxLength = int(c.maxLength, 50, 2000, 500),
        ephemeralOptions = list(c.ephemeralOptions, function(x) return P.Int(x, 0, 604800) end, 8), readReceipts = bool(c.readReceipts, true), perMinute = int(c.perMinute, 3, 120, 20) }
    if #o.chat.ephemeralOptions == 0 then o.chat.ephemeralOptions = { 0 } end
    local m = S.market
    local seen = {}
    o.market = { fee = num(m.fee, 0, 50, 8), minPrice = int(m.minPrice, 1, 100000000, 50), maxPrice = int(m.maxPrice, 1, 1000000000, 5000000),
        durationHours = int(m.durationHours, 1, 720, 48), maxActive = int(m.maxActive, 1, 50, 6),
        categories = list(m.categories, function(cat)
            if type(cat) ~= 'table' then return nil end
            local id = ident(cat.id, nil)
            if not id or seen[id] then return nil end
            seen[id] = true
            return { id = id, label = str(cat.label, 40, id), items = list(cat.items, function(it) return ident(it, nil) end, 60) }
        end, 30) }
    if o.market.maxPrice < o.market.minPrice then o.market.maxPrice = o.market.minPrice end
    local k = S.contracts
    o.contracts = { categories = list(k.categories, function(x) return ident(x, nil) end, 20), minReward = int(k.minReward, 0, 100000000, 500),
        maxReward = int(k.maxReward, 1, 1000000000, 1000000), fee = num(k.fee, 0, 50, 5), maxActive = int(k.maxActive, 1, 50, 4), maxDeadlineHours = int(k.maxDeadlineHours, 1, 2160, 168) }
    if #o.contracts.categories == 0 then o.contracts.categories = { 'autre' } end
    local b = S.breach
    o.breach = { cost = int(b.cost, 0, 100000000, 15000), cooldownMinutes = int(b.cooldownMinutes, 0, 1440, 45), maxConcurrent = int(b.maxConcurrent, 1, 20, 2),
        durationMin = int(b.durationMin, 60, 120, 60), durationMax = int(b.durationMax, 60, 120, 120), steps = int(b.steps, 1, 5, 3), difficulty = int(b.difficulty, 1, 3, 2),
        effectMinutes = int(b.effectMinutes, 0, 240, 10), minPolice = int(b.minPolice, 0, 50, 0),
        tracking = { enabled = bool(b.tracking.enabled, true), interval = int(b.tracking.interval, 2, 60, 5), precision = int(b.tracking.precision, 0, 500, 35), maxOfficers = int(b.tracking.maxOfficers, 1, 64, 6) },
        counter = { enabled = bool(b.counter.enabled, true), chance = int(b.counter.chance, 0, 100, 45), cooldown = int(b.counter.cooldown, 0, 600, 30), shieldMinutes = int(b.counter.shieldMinutes, 0, 240, 15) } }
    if o.breach.durationMax < o.breach.durationMin then o.breach.durationMax = o.breach.durationMin end
    local pg = S.police.grades
    o.police = { jobs = list(S.police.jobs, function(j) return ident(j, nil) end, 10),
        grades = { laptop = int(pg.laptop, 0, 99, 1), cyber = int(pg.cyber, 0, 99, 2), tracking = int(pg.tracking, 0, 99, 2), counter = int(pg.counter, 0, 99, 3), history = int(pg.history, 0, 99, 4) } }
    return o
end

-- Copie publique (envoyée au client à l'ouverture, jamais utilisée pour décider)
function P.PublicCfg()
    local S = P.S
    local cats = {}
    for _, c in ipairs(S.market.categories) do cats[#cats + 1] = { id = c.id, label = c.label } end
    return { apps = S.apps, sounds = S.general.sounds, volume = S.general.volume, moneyLabel = Config.MarketPayment[S.general.moneyType],
        chat = { maxLength = S.chat.maxLength, ephemeralOptions = S.chat.ephemeralOptions, readReceipts = S.chat.readReceipts },
        market = { fee = S.market.fee, minPrice = S.market.minPrice, maxPrice = S.market.maxPrice, durationHours = S.market.durationHours, categories = cats },
        contracts = { categories = S.contracts.categories, minReward = S.contracts.minReward, maxReward = S.contracts.maxReward, fee = S.contracts.fee, maxDeadlineHours = S.contracts.maxDeadlineHours },
        breach = { cost = S.breach.cost, cooldownMinutes = S.breach.cooldownMinutes, steps = S.breach.steps },
        profile = { aliasMin = S.profile.aliasMin, aliasMax = S.profile.aliasMax, renameCost = S.profile.renameCost } }
end

function P.LoadSettings()
    local row = MySQL.single.await('SELECT `v` FROM `bp_settings` WHERE `k` = ?', { 'config' })
    P.S = P.Sanitize(row and row.v and json.decode(row.v) or nil)
end
function P.SaveSettings(raw)
    local S = P.Sanitize(raw)
    MySQL.query.await('INSERT INTO `bp_settings` (`k`, `v`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `v` = VALUES(`v`)', { 'config', json.encode(S) })
    P.S = S
end
function P.ResetSettings()
    MySQL.query.await('DELETE FROM `bp_settings` WHERE `k` = ?', { 'config' })
    P.S = P.Sanitize(nil)
end
