-- =====================================================================
--  ELYZEA LABS · serveur : tablette « Laboratoire » (F5 à l'intérieur)
--  Les données envoyées dépendent des droits du joueur. Le code n'est jamais envoyé.
-- =====================================================================
local L = Labs
local DAYS = { 'lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.' }

local function scheduleText(S)
    if not S.enabled then return 'Attaques désactivées' end
    local parts = {}
    for _, s in ipairs(S.slots or {}) do
        local d = {}
        for _, x in ipairs(s.days) do d[#d + 1] = DAYS[x] end
        parts[#parts + 1] = ('%s %s–%s'):format(#s.days == 7 and 'tous les jours' or table.concat(d, ' '), s.from, s.to)
    end
    return #parts > 0 and table.concat(parts, ' · ') or 'Aucun créneau'
end
L.ScheduleText = scheduleText

local function catInfo(c) local x = Config.Categories[c] or { label = c, icon = '•' } return { id = c, label = x.label, icon = x.icon } end

L.pub.tablet = function(src, d)
    local lab = L.list[tonumber(d.lab) or -1]
    if not lab or not L.InsideLab(src, lab.id) then return { error = 'La tablette du laboratoire s\'utilise à l\'intérieur.' } end
    local role, rights = L.Rights(src, lab)
    if not rights.tablet then return { error = 'Ton grade n\'a pas accès à la tablette.' } end
    local it = L.Interior(lab.interior)
    local total, placed = L.EquipCount(lab)
    local lv = LabRules.Level(lab.level)
    local nextDef = Config.Levels[lab.level + 1]
    local out = { role = role, rights = rights, staff = role == 'staff',
        lab = { id = lab.id, name = lab.name, interior = it.label, owner = L.GroupLabel(lab.owner), level = lab.level, levelLabel = lv.label,
            xp = lab.xp, levelXp = lv.xp, nextXp = nextDef and nextDef.xp or nil, maxLevel = #Config.Levels, equipment = total, placed = placed,
            maxEquipment = lv.maxEquipment, account = Config.Account == 'dirty' and 'argent sale' or 'argent propre', present = L.Present(lab) },
        levels = {}, catalog = {}, owned = {}, upgrades = lab.upgrades, permDefs = Config.Perms }
    for i, l in ipairs(Config.Levels) do
        local cats = {}
        for _, c in ipairs(l.unlocks or {}) do cats[#cats + 1] = catInfo(c) end
        out.levels[#out.levels + 1] = { n = i, label = l.label, xp = l.xp, price = l.price, unlocks = cats, maxEquipment = l.maxEquipment, owned = i <= lab.level }
    end
    if nextDef then
        out.canUpgrade = rights.upgrade and lab.xp >= nextDef.xp
        out.upgradeHint = not rights.upgrade and 'Ton grade ne peut pas acheter les améliorations.' or lab.xp < nextDef.xp and ('Encore %d XP.'):format(nextDef.xp - lab.xp) or nil
    end
    local unlocked = LabRules.Unlocked(lab.level)
    for typ, e in pairs(Config.Equipment) do
        local need = LabRules.EquipmentLevel(typ)
        local recipes = {}
        for _, x in ipairs(LabRules.RecipesFor(typ)) do recipes[#recipes + 1] = x.r.label end
        out.catalog[#out.catalog + 1] = { type = typ, label = e.label, category = catInfo(e.category), price = e.price, level = need,
            unlocked = unlocked[e.category] ~= nil, recipes = recipes }
    end
    table.sort(out.catalog, function(a, b) if a.level ~= b.level then return a.level < b.level end return a.label < b.label end)
    for _, e in pairs(lab.equipment) do
        out.owned[#out.owned + 1] = { id = e.id, type = e.type, label = (Config.Equipment[e.type] or { label = e.type }).label, placed = e.placed,
            busy = L.equipBusy[e.id] ~= nil, price = e.price, refund = math.floor((e.price or 0) * Config.SellRefund / 100) }
    end
    table.sort(out.owned, function(a, b) return a.id < b.id end)
    if role == 'boss' or role == 'staff' then
        local g = L.GroupInfo(lab.owner)
        out.grades = {}
        for _, gr in ipairs(g and g.grades or {}) do
            out.grades[#out.grades + 1] = { id = gr.id, label = gr.label, level = gr.level, boss = gr.boss, perms = gr.boss and nil or L.GradePerms(lab, gr.id) }
        end
    end
    if rights.raid then
        local S = L.Raids()
        local r = L.raidOf(lab.id)
        out.raids = { schedule = scheduleText(S), duration = S.duration, radius = S.radius, rule = S.winRule, minAttackers = S.minAttackers,
            current = r and { status = r.status, attacker = r.attackerLabel, attackers = r.a, defenders = r.d,
                remaining = r.status == 'preparing' and (r.prepEnd - os.time()) or ((r.endAt or os.time()) - os.time()) } or nil,
            cooldown = math.max(0, (lab.lastRaid or 0) + S.labCooldown * 60 - os.time()),
            history = L.RaidHistory(lab.id, 10) }
    end
    return out
end

L.pub.setCode = function(src, d)
    local lab = L.list[tonumber(d.lab) or -1]
    if not lab or not L.InsideLab(src, lab.id) then return { error = 'Tu dois être dans le laboratoire.' } end
    if not L.Can(src, lab, 'security') then return { error = 'Tu n\'as pas le droit de changer le code.' } end
    local code = tostring(d.code or '')
    if not L.ValidCode(code) then return { error = ('Code : %d à %d chiffres.'):format(Config.Code.length.min, Config.Code.length.max) } end
    local salt = L.NewSalt()
    local hash = L.HashCode(salt, code)
    MySQL.update.await('UPDATE `labs` SET `code_hash` = ?, `code_salt` = ? WHERE `id` = ?', { hash, salt, lab.id })
    lab.codeHash, lab.codeSalt = hash, salt
    L.Log(lab.id, 'code', L.Name(src), 'code modifié')
    return { ok = true, message = 'Code modifié.' }
end

L.pub.setPerms = function(src, d)
    local lab = L.list[tonumber(d.lab) or -1]
    if not lab or not L.InsideLab(src, lab.id) then return { error = 'Tu dois être dans le laboratoire.' } end
    local role = L.Rights(src, lab)
    if role ~= 'boss' and role ~= 'staff' then return { error = 'Seul le chef du groupe règle les autorisations.' } end
    local perms = L.CleanPerms(lab, d.perms)
    if not perms then return { error = 'Autorisations invalides.' } end
    MySQL.update.await('UPDATE `labs` SET `perms` = ? WHERE `id` = ?', { json.encode(perms), lab.id })
    lab.perms = perms
    L.Log(lab.id, 'droits', L.Name(src), 'autorisations des grades modifiées')
    L.RefreshInside(lab, false)
    return { ok = true, message = 'Autorisations enregistrées.' }
end
