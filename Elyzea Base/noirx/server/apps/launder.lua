--[[
    NOIR X — BLANCHIMENT + DUELS DE PIRATAGE

    Blanchiment :
      1. Le joueur choisit un montant d'argent sale. Le serveur RETIRE l'item d'argent sale
         immédiatement (via l'adaptateur d'inventaire) et enregistre l'opération en base.
      2. L'opération dure un temps qui dépend du montant (Config.Laundering).
      3. À la fin, le montant net (montant − frais − éventuel vol) est versé en argent PROPRE
         via la file de paiements (exactement une fois, même après un redémarrage).

    Piratage pendant le blanchiment :
      • Un pirate PNJ peut attaquer (probabilité configurable), uniquement si le propriétaire
        est connecté.
      • Un joueur peut intercepter un blanchiment depuis Blackbreach (coût + délai configurables).
      • Les deux camps reçoivent la même ligne de code : le premier qui la recopie exactement gagne.
        Le serveur chronomètre, valide le texte et rejette une frappe humainement impossible.
      • Si l'attaquant gagne, le propriétaire perd un pourcentage du montant ; un pirate joueur
        reçoit ce montant en argent sale (via la file de paiements).
]]

Launder = { jobs = {}, attacks = {} }

local Jobs = Launder.jobs        -- [jobId] = job
local Attacks = Launder.attacks  -- [attackId] = attack
local Signals, JobSignal = {}, {}
local InterceptCd = {}
local AttackSeq = 0

local function cfg() return Config.Laundering end
local function hcfg() return Config.Laundering.hack end
local function now() return os.time() end
local function ms() return GetGameTimer() end

-- ─── Règles de calcul (pures, testées) ──────────────────────────

function Launder.Duration(amount)
    local c = cfg()
    local secs = c.baseSeconds + math.ceil(amount / 1000) * c.secondsPer1000
    return math.min(c.maxSeconds, secs)
end

function Launder.Fee(amount)
    return math.floor(amount * cfg().feePercent / 100)
end

local WORDS = {
    verbs = { 'inject', 'reroute', 'spoof', 'decrypt', 'bypass', 'override', 'mirror', 'tunnel', 'flush', 'patch' },
    flags = { '--node', '--port', '--key', '--relay', '--hash', '--proxy', '--vault', '--seed' },
    names = { 'ghost', 'relay', 'vault', 'shade', 'cinder', 'onyx', 'raven', 'static', 'null', 'ember' },
}

local function pick(t) return t[math.random(1, #t)] end
local function hex(n)
    local s = {}
    for i = 1, n do
        local k = math.random(1, 16)
        s[i] = ('0123456789abcdef'):sub(k, k)
    end
    return table.concat(s)
end

--- Génère une ligne de « code » facile à lire mais longue à taper.
function Launder.GenerateLine(minLen, maxLen)
    minLen = minLen or hcfg().lineLength[1]
    maxLen = maxLen or hcfg().lineLength[2]
    local target = math.random(minLen, maxLen)
    local parts = { pick(WORDS.verbs) }
    local line = parts[1]
    local guard = 0
    while #line < target and guard < 20 do
        guard = guard + 1
        local flag = pick(WORDS.flags)
        local value
        local r = math.random(1, 3)
        if r == 1 then value = pick(WORDS.names) .. '-' .. math.random(10, 99)
        elseif r == 2 then value = hex(math.random(4, 6))
        else value = tostring(math.random(1000, 9999)) end
        local candidate = line .. ' ' .. flag .. ' ' .. value
        if #candidate > maxLen then
            if #line >= minLen then break end
            candidate = (line .. ' ' .. value):sub(1, maxLen)
        end
        line = candidate
    end
    if #line < minLen then line = line .. ' ' .. hex(minLen - #line) end
    return line:sub(1, maxLen)
end

--- Temps minimal (ms) pour qu'un humain tape la ligne.
function Launder.MinHumanMs(line)
    return math.floor(#line / hcfg().maxHumanCps * 1000) + 300
end

local function amountBand(a)
    if a < 5000 then return 'faible' elseif a < 20000 then return 'moyen'
    elseif a < 60000 then return 'élevé' end
    return 'massif'
end

-- ─── Vues pour la NUI ───────────────────────────────────────────

local function jobView(job)
    if not job then return nil end
    local t = now()
    return {
        id = job.id,
        amount = job.amount, fee = job.fee, net = job.net, stolen = job.stolen,
        payout = job.net - job.stolen,
        startedAt = job.startedAt, endsAt = job.endsAt,
        remaining = math.max(0, job.endsAt - t),
        total = math.max(1, job.endsAt - job.startedAt),
        underAttack = job.attack ~= nil,
    }
end

local function attackView(a, role)
    return {
        attack = a.id,
        role = role,
        line = a.line,
        remainingMs = math.max(0, a.deadlineMs - ms()),
        windowMs = a.deadlineMs - a.startMs,
        npc = a.attacker == 'npc',
    }
end

local function myJob(charId)
    for _, j in pairs(Jobs) do
        if j.owner == charId then return j end
    end
    return nil
end

-- ─── Attaques ───────────────────────────────────────────────────

local function startAttack(job, attackerChar, attackerSrc)
    AttackSeq = AttackSeq + 1
    local h = hcfg()
    local line = Launder.GenerateLine()
    local startMs = ms()
    local a = {
        id = AttackSeq,
        jobId = job.id,
        attacker = attackerChar or 'npc',
        attackerSrc = attackerSrc,
        line = line,
        startMs = startMs,
        deadlineMs = startMs + h.windowSeconds * 1000,
    }
    if not attackerChar then
        local cps = h.npcCharsPerSecond[1] + math.random() * (h.npcCharsPerSecond[2] - h.npcCharsPerSecond[1])
        a.npcDoneMs = startMs + 1500 + math.floor(#line / cps * 1000)
    end
    a.dbId = DB.Insert('INSERT INTO noirx_launder_attacks (job_id, attacker, line, started_at) VALUES (?, ?, ?, ?)',
        { job.id, a.attacker, line, now() })
    Attacks[a.id] = a
    job.attack = a.id
    job.attacks = job.attacks + 1
    DB.Execute('UPDATE noirx_launder_jobs SET attacks = ? WHERE id = ?', { job.attacks, job.id })

    local victimSrc = Players.SrcOf(job.owner)
    if victimSrc then
        Push.ToSrc(victimSrc, 'duel:start', attackView(a, 'defender'))
        Push.Notify(victimSrc, 'INTRUSION', 'On pirate ton blanchiment ! Ouvre ton NOIR X et recopie la séquence avant lui.', 'alert')
    end
    if attackerSrc then
        Push.ToSrc(attackerSrc, 'duel:start', attackView(a, 'attacker'))
    end
    Audit.Log(victimSrc or 0, 'launder.attack_start', { job = job.id, attacker = a.attacker })
    return a
end

--- Termine un duel. winner = 'defender' | 'attacker'
function Launder.Resolve(attackId, winner, reason)
    local a = Attacks[attackId]
    if not a then return false end
    Attacks[attackId] = nil
    local job = Jobs[a.jobId]
    if job then job.attack = nil end

    local loss, reward = 0, 0
    if winner == 'attacker' and job then
        local h = hcfg()
        local pct = math.random(h.lossPercentMin, math.max(h.lossPercentMin, h.lossPercentMax))
        loss = math.floor(job.amount * pct / 100)
        loss = math.max(0, math.min(loss, job.net - job.stolen))
        job.stolen = job.stolen + loss
        DB.Execute('UPDATE noirx_launder_jobs SET stolen = ? WHERE id = ?', { job.stolen, job.id })
        if a.attacker ~= 'npc' and loss > 0 then
            reward = math.floor(loss * h.attackerRewardPercent / 100)
            if reward > 0 then
                Payouts.Queue(a.attacker, 'dirty', reward, 'breach', 'launder:' .. job.id .. ':' .. a.id)
            end
        end
    end
    DB.Execute('UPDATE noirx_launder_attacks SET winner = ?, loss = ?, resolved_at = ? WHERE id = ?',
        { winner, loss, now(), a.dbId })

    local victimSrc = job and Players.SrcOf(job.owner)
    if victimSrc then
        Push.ToSrc(victimSrc, 'duel:end', { attack = a.id, role = 'defender', won = winner == 'defender', loss = loss, reason = reason })
        Push.ToSrc(victimSrc, 'launder:update', { job = jobView(job) })
        -- téléphone rangé : le résultat arrive en notification (sinon le duel l'affiche déjà)
        if not Phone.GetSession(victimSrc) then Push.Notify(victimSrc, winner == 'defender' and 'Intrusion bloquée' or 'Blanchiment piraté',
            winner == 'defender' and 'Le pirate a été éjecté. L\'opération continue.'
            or ('Le pirate a siphonné %s%d de ton opération.'):format(Config.Money.symbol, loss), winner == 'attacker' and 'alert' or nil) end
    end
    local attackerSrc = a.attacker ~= 'npc' and Players.SrcOf(a.attacker) or nil
    if attackerSrc then
        Push.ToSrc(attackerSrc, 'duel:end', { attack = a.id, role = 'attacker', won = winner == 'attacker', reward = reward, reason = reason })
        if not Phone.GetSession(attackerSrc) then Push.Notify(attackerSrc, 'Blackbreach', winner == 'attacker'
            and ('Transfert réussi : %s%d d\'argent sale.'):format(Config.Money.symbol, reward)
            or 'Liaison coupée : la cible a été plus rapide.') end
    end
    Audit.Log(victimSrc or 0, 'launder.attack_end', { job = a.jobId, winner = winner, loss = loss, reward = reward, reason = reason })
    return true
end

-- ─── Fin de blanchiment ─────────────────────────────────────────

function Launder.Complete(job)
    if job.attack then return false end
    local updated = DB.Execute('UPDATE noirx_launder_jobs SET status = ?, finished_at = ? WHERE id = ? AND status = ?',
        { 'done', now(), job.id, 'running' })
    Jobs[job.id] = nil
    local sig = JobSignal[job.id]
    if sig then Signals[sig] = nil; JobSignal[job.id] = nil end
    if updated ~= 1 then return false end

    local payout = job.net - job.stolen
    if payout > 0 then
        Payouts.Queue(job.owner, 'clean', payout, 'launder', 'launder:' .. job.id)
    end
    local src = Players.SrcOf(job.owner)
    if src then
        Push.ToSrc(src, 'launder:done', { id = job.id, payout = payout, stolen = job.stolen })
        Push.Notify(src, 'Blanchiment', ('Opération terminée : %s%d propres.'):format(Config.Money.symbol, payout))
    end
    Audit.Log(src or 0, 'launder.done', { job = job.id, owner = job.owner, payout = payout, stolen = job.stolen })
    return true
end

local function scheduleNpc(job)
    local h = hcfg()
    if math.random(1, 100) > h.npcChance then return nil end
    local earliest = job.startedAt + h.vulnerableAfterSeconds
    local latest = job.endsAt - h.windowSeconds - 2
    if latest <= earliest then return nil end
    return math.random(earliest, latest)
end

-- ─── RPC ────────────────────────────────────────────────────────

local function cooldownRemaining(charId)
    local row = DB.Single('SELECT MAX(started_at) AS last FROM noirx_launder_jobs WHERE owner = ?', { charId })
    local last = row and tonumber(row.last)
    if not last then return 0 end
    return math.max(0, last + cfg().cooldownSeconds - now())
end

local function historyOf(charId)
    local rows = DB.Query([[SELECT id, amount, fee, net, stolen, status, started_at, finished_at
        FROM noirx_launder_jobs WHERE owner = ? AND status <> ? ORDER BY id DESC LIMIT 10]], { charId, 'running' })
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = {
            id = tonumber(r.id), amount = tonumber(r.amount), net = tonumber(r.net), stolen = tonumber(r.stolen),
            payout = tonumber(r.net) - tonumber(r.stolen), status = r.status, at = tonumber(r.finished_at or r.started_at),
        }
    end
    return out
end

Rpc.Register('launder.state', { app = 'launder' }, function(src, ctx)
    local c = cfg()
    return {
        rules = {
            min = c.minAmount, max = c.maxAmount, feePercent = c.feePercent,
            baseSeconds = c.baseSeconds, secondsPer1000 = c.secondsPer1000, maxSeconds = c.maxSeconds,
            symbol = Config.Money.symbol,
        },
        dirty = Inventory.GetItemCount(src, Config.Money.dirtyItem),
        job = jobView(myJob(ctx.charId)),
        cooldown = cooldownRemaining(ctx.charId),
        history = historyOf(ctx.charId),
    }
end)

Rpc.Register('launder.start', { app = 'launder', rate = { 3, 10 } }, function(src, ctx, args)
    local c = cfg()
    local amount = math.tointeger(tonumber(args.amount))
    if not amount or amount < c.minAmount or amount > c.maxAmount then
        return Rpc.Fail('bad_amount', ('Montant entre %s%d et %s%d.'):format(Config.Money.symbol, c.minAmount, Config.Money.symbol, c.maxAmount))
    end

    local ok, result = Locks.Run('money:' .. ctx.charId, function()
        if myJob(ctx.charId) then return Rpc.Fail('busy', 'Un blanchiment est déjà en cours.') end
        local cd = cooldownRemaining(ctx.charId)
        if cd > 0 then return Rpc.Fail('cooldown', ('Réseau saturé. Réessaie dans %d s.'):format(cd)) end

        if not Inventory.RemoveItem(src, Config.Money.dirtyItem, amount, { reason = 'launder' }) then
            return Rpc.Fail('funds', 'Pas assez d\'argent sale sur toi.')
        end

        local t = now()
        local job = {
            owner = ctx.charId, amount = amount, fee = Launder.Fee(amount), stolen = 0, attacks = 0,
            startedAt = t, endsAt = t + Launder.Duration(amount),
        }
        job.net = amount - job.fee
        job.npcAttackAt = scheduleNpc(job)
        job.id = DB.Insert([[INSERT INTO noirx_launder_jobs (owner, amount, fee, net, stolen, status, started_at, ends_at, npc_attack_at, attacks)
            VALUES (?, ?, ?, ?, 0, ?, ?, ?, ?, 0)]], { job.owner, amount, job.fee, job.net, 'running', job.startedAt, job.endsAt, job.npcAttackAt })
        if not job.id then
            -- Échec d'écriture : on rend l'argent sale immédiatement.
            if not Inventory.AddItem(src, Config.Money.dirtyItem, amount, { reason = 'launder_refund' }) then
                NoirX.Error(('Remboursement impossible pour %s (%d). À traiter manuellement.'):format(ctx.charId, amount))
            end
            return Rpc.Fail('internal', 'Le réseau a refusé l\'opération.')
        end
        job.id = math.tointeger(job.id) or job.id
        Jobs[job.id] = job
        Audit.Log(src, 'launder.start', { job = job.id, amount = amount, fee = job.fee, ends = job.endsAt })
        return { ok = true, job = jobView(job) }
    end)
    if not ok then return Rpc.Fail('busy', 'Transaction en cours.') end
    Push.ToSrc(src, 'wallet:changed', {})
    return result
end)

--- Duel actif du joueur (défenseur ou attaquant), pour réafficher le duel à la réouverture.
Rpc.Register('duel.active', { rate = { 10, 5 } }, function(src, ctx)
    for _, a in pairs(Attacks) do
        local job = Jobs[a.jobId]
        if job and job.owner == ctx.charId then return { duel = attackView(a, 'defender') } end
        if a.attacker == ctx.charId then return { duel = attackView(a, 'attacker') } end
    end
    return { duel = nil }
end)

Rpc.Register('duel.submit', { rate = { 12, 5 } }, function(src, ctx, args)
    local id = math.tointeger(tonumber(args.attack))
    local a = id and Attacks[id]
    if not a then return Rpc.Fail('over', 'Le duel est terminé.') end
    local job = Jobs[a.jobId]
    local role
    if job and job.owner == ctx.charId then role = 'defender'
    elseif a.attacker == ctx.charId then role = 'attacker'
    else return Rpc.Fail('forbidden', 'Accès refusé.') end

    if type(args.text) ~= 'string' or args.text ~= a.line then
        return { ok = true, correct = false }
    end
    local elapsed = ms() - a.startMs
    if elapsed < Launder.MinHumanMs(a.line) then
        Audit.Log(src, 'launder.duel_too_fast', { attack = a.id, elapsed = elapsed })
        return Rpc.Fail('too_fast', 'Séquence rejetée : frappe non humaine.')
    end
    Locks.Run('attack:' .. a.id, function()
        if Attacks[a.id] then Launder.Resolve(a.id, role, 'typed') end
    end)
    return { ok = true, correct = true }
end)

-- ─── Blackbreach : interception par un joueur ───────────────────

local function signalFor(job)
    local s = JobSignal[job.id]
    if not s then
        repeat s = ('%X'):format(math.random(0x1000, 0xFFFF)) until not Signals[s]
        Signals[s] = job.id
        JobSignal[job.id] = s
    end
    return s
end

local function vulnerable(job, attackerChar)
    local h = hcfg()
    local t = now()
    return job.owner ~= attackerChar
        and not job.attack
        and job.attacks < h.maxAttacksPerJob
        and t - job.startedAt >= h.vulnerableAfterSeconds
        and job.endsAt - t > h.windowSeconds + 5
        and Players.SrcOf(job.owner) ~= nil
end

Rpc.Register('breach.signals', { app = 'blackbreach', rate = { 10, 10 } }, function(src, ctx)
    local h = hcfg()
    if not h.playerInterception then return { enabled = false, signals = {} } end
    local list = {}
    for _, job in pairs(Jobs) do
        if vulnerable(job, ctx.charId) then
            list[#list + 1] = { id = signalFor(job), band = amountBand(job.amount), remaining = job.endsAt - now() }
        end
    end
    table.sort(list, function(x, y) return x.id < y.id end)
    local cd = InterceptCd[ctx.charId]
    return {
        enabled = true,
        signals = list,
        cost = h.interceptCost, currency = h.interceptCurrency, symbol = Config.Money.symbol,
        cooldown = cd and math.max(0, cd - now()) or 0,
    }
end)

Rpc.Register('breach.intercept', { app = 'blackbreach', rate = { 3, 10 } }, function(src, ctx, args)
    local h = hcfg()
    if not h.playerInterception then return Rpc.Fail('disabled', 'Interception désactivée.') end
    local jobId = Signals[tostring(args.signal or '')]
    local job = jobId and Jobs[jobId]
    if not job then return Rpc.Fail('lost', 'Signal perdu.') end

    local ok, result = Locks.Run('money:' .. ctx.charId, function()
        local cd = InterceptCd[ctx.charId]
        if cd and cd > now() then return Rpc.Fail('cooldown', ('Matériel en surchauffe. %d s.'):format(cd - now())) end
        for _, a in pairs(Attacks) do
            if a.attacker == ctx.charId then return Rpc.Fail('busy', 'Tu es déjà en intrusion.') end
        end
        if not vulnerable(job, ctx.charId) then return Rpc.Fail('lost', 'Signal perdu.') end
        if h.interceptCost > 0 and not Wallet.Charge(src, h.interceptCurrency, h.interceptCost, 'breach') then
            return Rpc.Fail('funds', 'Fonds insuffisants pour lancer l\'intrusion.')
        end
        InterceptCd[ctx.charId] = now() + h.interceptCooldownSeconds
        local a = startAttack(job, ctx.charId, src)
        return { ok = true, duel = attackView(a, 'attacker') }
    end)
    if not ok then return Rpc.Fail('busy', 'Transaction en cours.') end
    if result.ok and h.interceptCost > 0 then Push.ToSrc(src, 'wallet:changed', {}) end
    return result
end)

-- ─── Boucle serveur ─────────────────────────────────────────────

function Launder.Tick()
    local tms, t = ms(), now()
    for id, a in pairs(Attacks) do
        if a.npcDoneMs and tms >= a.npcDoneMs then
            Locks.Run('attack:' .. id, function()
                if Attacks[id] then Launder.Resolve(id, 'attacker', 'npc_faster') end
            end)
        elseif tms >= a.deadlineMs then
            Locks.Run('attack:' .. id, function()
                -- Personne n'a fini : le PNJ l'emporte, un pirate joueur échoue.
                if Attacks[id] then Launder.Resolve(id, a.attacker == 'npc' and 'attacker' or 'defender', 'timeout') end
            end)
        end
    end
    for _, job in pairs(Jobs) do
        if not job.attack then
            if t >= job.endsAt then
                Launder.Complete(job)
            elseif job.npcAttackAt and t >= job.npcAttackAt then
                job.npcAttackAt = nil
                DB.Execute('UPDATE noirx_launder_jobs SET npc_attack_at = NULL WHERE id = ?', { job.id })
                if job.attacks < hcfg().maxAttacksPerJob and Players.SrcOf(job.owner) then
                    startAttack(job, nil, nil)
                end
            end
        end
    end
end

--- Restauration après redémarrage : les opérations reprennent, les duels interrompus sont annulés.
function Launder.Restore()
    DB.Execute('UPDATE noirx_launder_attacks SET winner = ?, resolved_at = ? WHERE winner IS NULL', { 'void', now() })
    local rows = DB.Query([[SELECT id, owner, amount, fee, net, stolen, started_at, ends_at, npc_attack_at, attacks
        FROM noirx_launder_jobs WHERE status = ?]], { 'running' })
    for _, r in ipairs(rows) do
        local id = math.tointeger(tonumber(r.id))
        Jobs[id] = {
            id = id, owner = r.owner, amount = tonumber(r.amount), fee = tonumber(r.fee), net = tonumber(r.net),
            stolen = tonumber(r.stolen), startedAt = tonumber(r.started_at), endsAt = tonumber(r.ends_at),
            npcAttackAt = tonumber(r.npc_attack_at), attacks = tonumber(r.attacks) or 0,
        }
    end
    if #rows > 0 then NoirX.Debug(('%d blanchiment(s) restauré(s)'):format(#rows)) end
end

--- Annulation administrative. refund = true → l'argent sale restant est rendu.
function Launder.AdminCancel(jobId, refund, actor)
    jobId = math.tointeger(tonumber(jobId))
    local job = jobId and Jobs[jobId]
    if not job then return false, 'not_running' end
    if job.attack then Launder.Resolve(job.attack, 'defender', 'admin_cancel') end
    local updated = DB.Execute('UPDATE noirx_launder_jobs SET status = ?, finished_at = ? WHERE id = ? AND status = ?',
        { 'cancelled', now(), job.id, 'running' })
    Jobs[job.id] = nil
    if updated ~= 1 then return false, 'not_running' end
    local back = 0
    if refund then
        back = job.amount - job.stolen
        if back > 0 then Payouts.Queue(job.owner, 'dirty', back, 'launder_refund', 'launder:' .. job.id .. ':refund') end
    end
    local src = Players.SrcOf(job.owner)
    if src then Push.ToSrc(src, 'launder:update', { job = nil }) end
    Audit.Log(0, 'launder.admin_cancel', { job = job.id, refund = back, actor = actor })
    return true, back
end

function Launder.AdminList()
    local out = {}
    for _, j in pairs(Jobs) do
        local v = jobView(j); v.owner = j.owner; out[#out + 1] = v
    end
    return out
end

Boot.Register('launder', function()
    Launder.Restore()
    CreateThread(function()
        while true do
            Wait(500)
            local ok, err = pcall(Launder.Tick)
            if not ok then NoirX.Error('Launder.Tick :', tostring(err)) end
        end
    end)
end)

Phone.onOpen[#Phone.onOpen + 1] = function(src, charId)
    for _, a in pairs(Attacks) do
        local job = Jobs[a.jobId]
        if job and job.owner == charId then Push.ToSrc(src, 'duel:start', attackView(a, 'defender')) end
        if a.attacker == charId then Push.ToSrc(src, 'duel:start', attackView(a, 'attacker')) end
    end
end
