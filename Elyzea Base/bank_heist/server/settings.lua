-- =====================================================================
--  BANK HEIST - serveur : réglages persistants
--  Défauts : config.lua · Réglages du staff : bh_settings (clé 'config', JSON), revalidés ici.
--  Copie publique (positions, noms, prix, règles d'affichage) : GlobalState.bhCfg.
-- =====================================================================
local P = BHS

local function num(v, mn, mx, def)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return def end
    if mn then v = math.max(mn, v) end
    if mx then v = math.min(mx, v) end
    return v
end
local function int(v, mn, mx, def) local n = num(v, mn, mx, def) return n and math.floor(n) end
local function bool(v, def) if v == nil then return def end return v == true end
local function str(v, max, def)
    if type(v) ~= 'string' and type(v) ~= 'number' then return def end
    v = tostring(v):gsub('[<>"]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if v == '' then return def end
    return v:sub(1, max)
end
local function choice(v, l, def) for _, x in ipairs(l) do if v == x then return v end end return def end
local function ident(v, def) v = str(v, 40, nil) v = v and v:lower():gsub('[^%w_%-]', '') return (v and v ~= '') and v or def end
local function model(v, def) v = str(v, 64, nil) v = v and v:gsub('[^%w_]', '') return (v and v ~= '') and v or def end
local function pos(t, def, withH)
    t = type(t) == 'table' and t or {}
    def = def or {}
    local o = { x = num(t.x, -10000, 10000, def.x or 0.0), y = num(t.y, -10000, 10000, def.y or 0.0), z = num(t.z, -500, 3000, def.z or 0.0) }
    if withH then o.h = num(t.h, 0, 360, def.h or 0.0) end
    return o
end
local function list(t, fn, max)
    local o = {}
    for _, v in ipairs(type(t) == 'table' and t or {}) do
        local x = fn(v)
        if x ~= nil then o[#o + 1] = x end
        if #o >= (max or 50) then break end
    end
    return o
end
local function anim(t, def)
    t = type(t) == 'table' and t or {}
    return { dict = str(t.dict, 80, def.dict), name = str(t.name, 64, def.name), flag = int(t.flag, 0, 255, def.flag or 0), time = def.time and int(t.time, 100, 10000, def.time) or nil }
end
local function blip(t, def)
    t = type(t) == 'table' and t or {}
    return { enabled = bool(t.enabled, def.enabled), sprite = int(t.sprite, 1, 900, def.sprite), color = int(t.color, 0, 85, def.color), scale = num(t.scale, 0.3, 2.0, def.scale) }
end
local function hours(t) t = type(t) == 'table' and t or {} return { from = int(t.from, 0, 23, 0), to = int(t.to, 0, 23, 0) } end
local PAY = { 'cash', 'bank', 'item' }
local TOOLS = { 'any', 'laptop', 'c4', 'none' }
P.ITEM_KINDS = { 'laptop', 'bag', 'c4', 'drill' }

local function lootPoint(p)
    if type(p) ~= 'table' then return nil end
    local o = pos(p, nil, true)
    o.type = choice(p.type, Config.LootTypeList, 'trolley_cash')
    o.model = model(p.model, '')
    o.min = int(p.min, 0, 100000000, 20000)
    o.max = int(p.max, 0, 100000000, 40000)
    if o.max < o.min then o.max = o.min end
    o.item = ident(p.item, '')            -- objet donné à la place de l'argent (ex. goldbar), vide = argent
    o.itemMin = int(p.itemMin, 1, 1000, 1)
    o.itemMax = int(p.itemMax, 1, 1000, 3)
    if o.itemMax < o.itemMin then o.itemMax = o.itemMin end
    return o
end

function P.Sanitize(raw)
    local D = Config.Defaults
    local S = BH.Merge(D, raw)
    local o = {}
    local g = S.general
    o.general = {
        enabled = bool(g.enabled, true), maxSimultaneous = int(g.maxSimultaneous, 1, 20, 1), globalCooldown = int(g.globalCooldown, 0, 1440, 30),
        participantRadius = num(g.participantRadius, 2, 100, 15), lateJoin = bool(g.lateJoin, true), bankRadius = num(g.bankRadius, 10, 300, 45),
        abandonMinutes = int(g.abandonMinutes, 1, 120, 8), interactDistance = num(g.interactDistance, 0.5, 10, 2.0),
        depositKey = int(g.depositKey, 0, 360, 38), depositKeyLabel = str(g.depositKeyLabel, 8, 'E'),
    }
    o.items = {}
    for _, k in ipairs(P.ITEM_KINDS) do
        local d, v = D.items[k], S.items[k] or {}
        o.items[k] = { name = d.name, label = str(v.label, 50, d.label), price = int(v.price, 0, 100000000, d.price), maxOwned = int(v.maxOwned, 0, 100, d.maxOwned) }
        if d.sell ~= nil then o.items[k].sell = bool(v.sell, true) end
    end
    local dm = D.merchants[1]
    local seen = {}
    o.merchants = list(S.merchants, function(m)
        if type(m) ~= 'table' then return nil end
        local id = ident(m.id, nil)
        if not id or seen['m' .. id] then return nil end
        seen['m' .. id] = true
        local sells = type(m.sells) == 'table' and m.sells or {}
        local ped = pos(m.ped, dm.ped, true)
        ped.model = model((m.ped or {}).model, dm.ped.model)
        return { id = id, name = str(m.name, 50, id), enabled = bool(m.enabled, true), ped = ped, scenario = str(m.scenario, 64, ''),
            interactDistance = num(m.interactDistance, 0.5, 10, 2.0), payment = choice(m.payment, PAY, 'cash'),
            sells = { laptop = bool(sells.laptop, true), bag = bool(sells.bag, true), c4 = bool(sells.c4, true), drill = bool(sells.drill, true) },
            jobs = list(m.jobs, function(j) return ident(j) end, 20), forbidPolice = bool(m.forbidPolice, true), blip = blip(m.blip, dm.blip) }
    end, 20)

    local di = D.informants[1]
    o.informants = list(S.informants, function(n)
        if type(n) ~= 'table' then return nil end
        local id = ident(n.id, nil)
        if not id or seen['i' .. id] then return nil end
        seen['i' .. id] = true
        local ped = pos(n.ped, di.ped, true)
        ped.model = model((n.ped or {}).model, di.ped.model)
        return { id = id, name = str(n.name, 50, id), enabled = bool(n.enabled, true), ped = ped, scenario = str(n.scenario, 64, ''),
            interactDistance = num(n.interactDistance, 0.5, 10, 2.2), price = int(n.price, 0, 10000000, di.price), payment = choice(n.payment, PAY, 'cash'),
            merchant = ident(n.merchant, ''), blipMinutes = int(n.blipMinutes, 1, 120, 10), cooldown = int(n.cooldown, 0, 1440, 15),
            forbidPolice = bool(n.forbidPolice, true), hours = hours(n.hours),
            greeting = str(n.greeting, 300, di.greeting), answer = str(n.answer, 300, di.answer) }
    end, 20)

    local dr = S.door
    o.door = { hack = bool(dr.hack, true), c4 = bool(dr.c4, true), c4OnlyAfterHack = bool(dr.c4OnlyAfterHack, false), openTime = int(dr.openTime, 1, 30, 5) }
    if not o.door.hack and not o.door.c4 then o.door.hack = true end

    local h = S.hack
    o.hack = { attempts = int(h.attempts, 1, 10, 3), retryDelay = int(h.retryDelay, 0, 120, 5), requireThreat = bool(h.requireThreat, true), games = {} }
    for _, gid in ipairs(Config.GameList) do
        local v, d = (h.games or {})[gid] or {}, D.hack.games[gid]
        o.hack.games[gid] = { enabled = bool(v.enabled, true), weight = int(v.weight, 0, 100, 1), time = int(v.time, 8, 300, d.time), difficulty = int(v.difficulty, 1, 3, 1) }
    end
    local c = S.c4
    o.c4 = { delay = int(c.delay, 2, 120, 10), plantTime = int(c.plantTime, 1, 30, 5), prop = model(c.prop, D.c4.prop), explosionType = int(c.explosionType, 0, 82, 2),
        shake = num(c.shake, 0, 3, 0.6), alertPolice = bool(c.alertPolice, true) }
    local dl = S.drill
    o.drill = { time = int(dl.time, 5, 300, 25), heatRate = num(dl.heatRate, 0.2, 5, 1.0), prop = model(dl.prop, D.drill.prop) }
    local al = S.alarm
    o.alarm = { enabled = bool(al.enabled, true), maxMinutes = int(al.maxMinutes, 1, 120, 10), volume = num(al.volume, 0, 1, 0.6), lights = bool(al.lights, true),
        robbersCanDisable = bool(al.robbersCanDisable, true), policeCanDisable = bool(al.policeCanDisable, true), wiresTime = int(al.wiresTime, 5, 120, 20),
        failRealert = bool(al.failRealert, true) }

    local l = S.loot
    local function pct(t, d) t = type(t) == 'table' and t or {} local x = { enabled = bool(t.enabled, d.enabled), chance = num(t.chance, 0, 100, d.chance), min = int(t.min, 1, 1000, d.min), max = int(t.max, 1, 1000, d.max) } if x.max < x.min then x.max = x.min end return x end
    o.loot = { rewardType = choice(l.rewardType, PAY, 'item'), moneyItem = ident(l.moneyItem, 'black_money'), depositRate = int(l.depositRate, 1, 200, 100),
        bagCapacity = int(l.bagCapacity, 1000, 100000000, 250000), perTick = int(l.perTick, 1, 10000000, 5000), openDuration = int(l.openDuration, 30, 3600, 420),
        bonus = pct(l.bonus, D.loot.bonus), malus = pct(l.malus, D.loot.malus) }

    local db = D.banks[1]
    o.banks = list(S.banks, function(b)
        if type(b) ~= 'table' then return nil end
        local id = ident(b.id, nil)
        if not id or seen['b' .. id] then return nil end
        seen['b' .. id] = true
        local door = type(b.door) == 'table' and b.door or {}
        local req = type(b.required) == 'table' and b.required or {}
        local banker = pos(b.banker or b.clerk, db.banker, true)
        banker.model = model((b.banker or b.clerk or {}).model, db.banker.model)
        local x = {
            id = id, name = str(b.name, 60, id), enabled = bool(b.enabled, true), banker = banker,
            door = { enabled = bool(door.enabled, true), model = model(door.model, db.door.model), x = num(door.x, -10000, 10000, db.door.x), y = num(door.y, -10000, 10000, db.door.y),
                z = num(door.z, -500, 3000, db.door.z), openOffset = num(door.openOffset, -180, 180, db.door.openOffset), closedHeading = num(door.closedHeading, -1, 360, db.door.closedHeading or -1) },
            doorPoint = pos(b.doorPoint or b.vault, db.doorPoint, true),
            alarm = pos(b.alarm, db.alarm),
            loot = (function()
                local l = list(b.loot, lootPoint, 20)
                -- réglages de la version 1 : chariots « cash » + butin min / max de la banque
                if #l == 0 and type(b.cash) == 'table' and #b.cash > 0 then
                    local old = type(b.loot) == 'table' and b.loot or {}
                    local n = #b.cash
                    for _, c in ipairs(b.cash) do
                        l[#l + 1] = lootPoint({ type = 'trolley_cash', x = c.x, y = c.y, z = c.z, h = c.h,
                            min = math.floor((tonumber(old.min) or 80000) / n), max = math.floor((tonumber(old.max) or 140000) / n) })
                    end
                end
                return l
            end)(),
            minCops = int(b.minCops, 0, 50, 3), minRobbers = int(b.minRobbers, 1, 20, 2), maxRobbers = int(b.maxRobbers, 1, 30, 6), cooldown = int(b.cooldown, 0, 10080, 90),
            hours = hours(b.hours), required = { tool = choice(req.tool, TOOLS, 'any'), bag = bool(req.bag, true) },
            threatTime = int(b.threatTime, 1, 120, 8), blip = blip(b.blip, db.blip),
        }
        if x.maxRobbers < x.minRobbers then x.maxRobbers = x.minRobbers end
        return x
    end, 30)

    local bk = S.banking
    o.banking = { enabled = bool(bk.enabled, true), minAmount = int(bk.minAmount, 1, 1000000, 1), maxTransfer = int(bk.maxTransfer, 1, 1000000000, 1000000),
        transferFee = num(bk.transferFee, 0, 50, 0) }

    o.deposits = list(S.deposits, function(d)
        if type(d) ~= 'table' then return nil end
        local id = ident(d.id, nil)
        if not id or seen['d' .. id] then return nil end
        seen['d' .. id] = true
        local p = pos(d, D.deposits[1])
        return { id = id, name = str(d.name, 50, id), enabled = bool(d.enabled, true), x = p.x, y = p.y, z = p.z, radius = num(d.radius, 0.5, 20, 2.5), allowPassenger = bool(d.allowPassenger, false) }
    end, 30)

    local v = S.visuals
    o.visuals = { bankerHandsUp = anim(v.bankerHandsUp, D.visuals.bankerHandsUp), bankerKneel = anim(v.bankerKneel, D.visuals.bankerKneel), depositAnim = anim(v.depositAnim, D.visuals.depositAnim) }
    o.police = { title = str(S.police.title, 80, D.police.title), alertKind = choice(S.police.alertKind, { 'robbery', 'shots', 'assault', 'distress', 'other', 'suspect' }, 'robbery'),
        jobs = list(S.police.jobs, function(j) return ident(j) end, 20) }
    o.security = { rateLimit = int(S.security.rateLimit, 2, 50, 10), logRetentionDays = int(S.security.logRetentionDays, 1, 365, 30) }
    return o
end

function P.BankById(id) for _, b in ipairs(P.S.banks) do if b.id == id then return b end end end
function P.MerchantById(id) for _, m in ipairs(P.S.merchants) do if m.id == id then return m end end end
function P.InformantById(id) for _, m in ipairs(P.S.informants) do if m.id == id then return m end end end
function P.DepositById(id) for _, d in ipairs(P.S.deposits) do if d.id == id then return d end end end

-- Copie publique (sans les montants du butin : le client ne connaît que la forme de la banque)
function P.Publish()
    local S = P.S
    local pub = { general = S.general, visuals = S.visuals, door = S.door, c4 = { plantTime = S.c4.plantTime, prop = S.c4.prop, shake = S.c4.shake, delay = S.c4.delay },
        drill = { time = S.drill.time, heatRate = S.drill.heatRate, prop = S.drill.prop }, alarm = { volume = S.alarm.volume, lights = S.alarm.lights,
        robbersCanDisable = S.alarm.robbersCanDisable, policeCanDisable = S.alarm.policeCanDisable }, banking = { enabled = S.banking.enabled },
        items = S.items, imagePath = Config.ImagePath, capacity = S.loot.bagCapacity, lootTypes = Config.LootTypes,
        banks = {}, merchants = {}, informants = {}, deposits = {} }
    for _, b in ipairs(S.banks) do
        local loot = {}
        for i, p in ipairs(b.loot) do loot[i] = { type = p.type, model = p.model, x = p.x, y = p.y, z = p.z, h = p.h } end
        pub.banks[#pub.banks + 1] = { id = b.id, name = b.name, enabled = b.enabled, banker = b.banker, door = b.door, doorPoint = b.doorPoint, alarm = b.alarm, loot = loot, blip = b.blip }
    end
    for _, m in ipairs(S.merchants) do pub.merchants[#pub.merchants + 1] = { id = m.id, name = m.name, enabled = m.enabled, ped = m.ped, scenario = m.scenario, interactDistance = m.interactDistance, blip = m.blip } end
    for _, n in ipairs(S.informants) do pub.informants[#pub.informants + 1] = { id = n.id, name = n.name, enabled = n.enabled, ped = n.ped, scenario = n.scenario, interactDistance = n.interactDistance, hours = n.hours } end
    for _, d in ipairs(S.deposits) do if d.enabled then pub.deposits[#pub.deposits + 1] = d end end
    GlobalState.bhCfg = pub
end

function P.LoadSettings()
    local row = MySQL.single.await('SELECT `v` FROM `bh_settings` WHERE `k` = ?', { 'config' })
    local raw = nil
    if row and row.v then
        local ok, v = pcall(json.decode, row.v)
        raw = ok and v or nil
    end
    P.S = P.Sanitize(raw)
    P.Publish()
end
function P.SaveSettings(raw)
    local S = P.Sanitize(raw)
    MySQL.query.await('INSERT INTO `bh_settings` (`k`, `v`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `v` = VALUES(`v`)', { 'config', json.encode(S) })
    P.S = S
    P.Publish()
    if P.PublishBanks then P.PublishBanks() end
end
function P.ResetSettings()
    MySQL.query.await('DELETE FROM `bh_settings` WHERE `k` = ?', { 'config' })
    P.S = P.Sanitize(nil)
    P.Publish()
    if P.PublishBanks then P.PublishBanks() end
end
