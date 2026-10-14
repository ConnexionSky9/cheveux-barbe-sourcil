--[[
    NOIR X — GHOSTLINE (identités clandestines, contacts, réputation) + BURNER

    Une « identité » est un pseudonyme NOIR X. Chaque personnage possède :
      • une identité principale (créée à la première utilisation) ;
      • des identités Burner temporaires (payantes, expirent, révocables par le staff).
    L'identité civile (nom du personnage, licence) n'est JAMAIS envoyée aux autres joueurs.
    Toute action vérifie côté serveur que l'identité utilisée appartient bien au joueur,
    qu'elle n'est ni révoquée ni expirée.
]]

Ghost = { ownerCache = {} }

local function now() return os.time() end

local function trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

function Ghost.ValidHandle(h)
    h = trim(h)
    local c = Config.Chat
    if #h < c.handleMin or #h > c.handleMax then return nil end
    if not h:match('^[%w_%-%.]+$') then return nil end
    return h
end

--- Identité active appartenant au personnage, ou nil.
function Ghost.Owned(charId, identityId)
    identityId = math.tointeger(tonumber(identityId))
    if not identityId then return nil end
    local row = DB.Single([[SELECT id, owner, handle, kind, reputation, expires_at FROM noirx_identities
        WHERE id = ? AND owner = ? AND revoked = 0 AND (expires_at IS NULL OR expires_at > ?)]], { identityId, charId, now() })
    if row then row.id = math.tointeger(tonumber(row.id)) end
    return row
end

function Ghost.ByHandle(handle)
    handle = trim(handle)
    if handle == '' then return nil end
    local row = DB.Single([[SELECT id, owner, handle, kind, reputation FROM noirx_identities
        WHERE handle_lc = ? AND revoked = 0 AND (expires_at IS NULL OR expires_at > ?)]], { handle:lower(), now() })
    if row then row.id = math.tointeger(tonumber(row.id)) end
    return row
end

function Ghost.OwnerOf(identityId)
    local c = Ghost.ownerCache[identityId]
    if c then return c end
    local row = DB.Single('SELECT owner FROM noirx_identities WHERE id = ?', { identityId })
    if row then Ghost.ownerCache[identityId] = row.owner end
    return row and row.owner
end

--- Envoie un push au joueur propriétaire de l'identité (s'il est connecté).
function Ghost.Push(identityId, event, payload)
    local owner = Ghost.OwnerOf(identityId)
    if not owner then return nil end
    payload = payload or {}
    payload.identity = identityId
    return Push.ToChar(owner, event, payload)
end

local function contactRow(owner, contact)
    return DB.Single('SELECT * FROM noirx_contacts WHERE owner_identity = ? AND contact_identity = ?', { owner, contact })
end

--- L'identité `a` a-t-elle bloqué `b` ?
function Ghost.Blocked(a, b)
    local r = DB.Single('SELECT blocked FROM noirx_contacts WHERE owner_identity = ? AND contact_identity = ?', { a, b })
    return r ~= nil and tonumber(r.blocked) == 1
end

function Ghost.AliasFor(owner, contact)
    local r = DB.Single('SELECT alias FROM noirx_contacts WHERE owner_identity = ? AND contact_identity = ?', { owner, contact })
    return r and r.alias ~= '' and r.alias or nil
end

local function identityView(r)
    return {
        id = math.tointeger(tonumber(r.id)), handle = r.handle, kind = r.kind,
        reputation = tonumber(r.reputation) or 0,
        expiresAt = tonumber(r.expires_at),
    }
end

function Ghost.MyIdentities(charId)
    local rows = DB.Query([[SELECT id, handle, kind, reputation, expires_at FROM noirx_identities
        WHERE owner = ? AND revoked = 0 AND (expires_at IS NULL OR expires_at > ?) ORDER BY kind DESC, id ASC]], { charId, now() })
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = identityView(r) end
    return out
end

local function createIdentity(charId, handle, kind, expiresAt)
    local id = DB.Insert([[INSERT INTO noirx_identities (owner, handle, handle_lc, kind, reputation, created_at, expires_at, revoked)
        VALUES (?, ?, ?, ?, 0, ?, ?, 0)]], { charId, handle, handle:lower(), kind, now(), expiresAt })
    return id and math.tointeger(id) or nil
end

local function handleTaken(handle)
    return DB.Single('SELECT id FROM noirx_identities WHERE handle_lc = ?', { handle:lower() }) ~= nil
end

-- ─── Identités ──────────────────────────────────────────────────

Rpc.Register('ghost.me', {}, function(src, ctx)
    return {
        identities = Ghost.MyIdentities(ctx.charId),
        rules = { min = Config.Chat.handleMin, max = Config.Chat.handleMax },
    }
end)

Rpc.Register('ghost.create', { rate = { 4, 10 } }, function(src, ctx, args)
    local handle = Ghost.ValidHandle(args.handle)
    if not handle then
        return Rpc.Fail('bad_handle', ('Pseudo de %d à %d caractères : lettres, chiffres, _ - .'):format(Config.Chat.handleMin, Config.Chat.handleMax))
    end
    local ok, res = Locks.Run('ghost:' .. ctx.charId, function()
        if DB.Single('SELECT id FROM noirx_identities WHERE owner = ? AND kind = ?', { ctx.charId, 'main' }) then
            return Rpc.Fail('exists', 'Tu as déjà une identité principale.')
        end
        if handleTaken(handle) then return Rpc.Fail('taken', 'Ce pseudo est déjà pris.') end
        local id = createIdentity(ctx.charId, handle, 'main', nil)
        if not id then return Rpc.Fail('taken', 'Ce pseudo est déjà pris.') end
        Audit.Log(src, 'ghost.create', { identity = id, handle = handle })
        return { ok = true, identities = Ghost.MyIdentities(ctx.charId) }
    end)
    if not ok then return Rpc.Fail('busy', 'Patiente.') end
    return res
end)

-- ─── Contacts ───────────────────────────────────────────────────

Rpc.Register('contacts.list', { app = 'ghostline' }, function(src, ctx, args)
    local me = Ghost.Owned(ctx.charId, args.identity)
    if not me then return Rpc.Fail('identity', 'Identité invalide.') end
    local rows = DB.Query([[SELECT c.contact_identity, c.status, c.alias, c.favorite, c.blocked, c.trust,
            i.handle, i.reputation, i.kind, i.revoked, i.expires_at,
            (SELECT value FROM noirx_ratings r WHERE r.rater = c.owner_identity AND r.target = c.contact_identity) AS my_rating
        FROM noirx_contacts c JOIN noirx_identities i ON i.id = c.contact_identity
        WHERE c.owner_identity = ? ORDER BY c.favorite DESC, i.handle ASC]], { me.id })
    local t = now()
    local out = {}
    for _, r in ipairs(rows) do
        local active = tonumber(r.revoked) == 0 and (r.expires_at == nil or tonumber(r.expires_at) > t)
        out[#out + 1] = {
            id = math.tointeger(tonumber(r.contact_identity)), handle = r.handle,
            alias = r.alias ~= '' and r.alias or nil, status = r.status,
            favorite = tonumber(r.favorite) == 1, blocked = tonumber(r.blocked) == 1,
            trust = tonumber(r.trust) or 0, reputation = tonumber(r.reputation) or 0,
            burner = r.kind == 'burner', offline = not active, myRating = tonumber(r.my_rating) or 0,
        }
    end
    return { contacts = out }
end)

Rpc.Register('contacts.request', { app = 'ghostline', rate = { 6, 30 } }, function(src, ctx, args)
    local me = Ghost.Owned(ctx.charId, args.identity)
    if not me then return Rpc.Fail('identity', 'Identité invalide.') end
    local target = Ghost.ByHandle(args.handle)
    -- Réponse identique que le pseudo existe ou non : on ne révèle pas les identités.
    local sent = { ok = true, message = 'Invitation transmise.' }
    if not target or target.id == me.id then return sent end
    if contactRow(me.id, target.id) then return Rpc.Fail('exists', 'Déjà dans tes contacts ou en attente.') end

    local theirs = contactRow(target.id, me.id)
    if theirs and theirs.status == 'pending_out' then
        DB.Execute('UPDATE noirx_contacts SET status = ? WHERE owner_identity = ? AND contact_identity = ?', { 'accepted', target.id, me.id })
        DB.Insert([[INSERT INTO noirx_contacts (owner_identity, contact_identity, status, alias, favorite, blocked, trust, created_at)
            VALUES (?, ?, ?, '', 0, 0, 0, ?)]], { me.id, target.id, 'accepted', now() })
        Ghost.Push(target.id, 'ghost:contacts', {})
        return { ok = true, message = 'Contact établi.' }
    end

    DB.Insert([[INSERT INTO noirx_contacts (owner_identity, contact_identity, status, alias, favorite, blocked, trust, created_at)
        VALUES (?, ?, ?, '', 0, 0, 0, ?)]], { me.id, target.id, 'pending_out', now() })
    if not theirs then
        DB.Insert([[INSERT INTO noirx_contacts (owner_identity, contact_identity, status, alias, favorite, blocked, trust, created_at)
            VALUES (?, ?, ?, '', 0, 0, 0, ?)]], { target.id, me.id, 'pending_in', now() })
        local tsrc = Ghost.Push(target.id, 'ghost:request', { from = me.handle })
        if tsrc then Push.Notify(tsrc, 'Ghostline', me.handle .. ' veut établir un contact.') end
    end
    return sent
end)

Rpc.Register('contacts.respond', { app = 'ghostline' }, function(src, ctx, args)
    local me = Ghost.Owned(ctx.charId, args.identity)
    local other = math.tointeger(tonumber(args.contact))
    if not me or not other then return Rpc.Fail('identity', 'Identité invalide.') end
    local mine = contactRow(me.id, other)
    if not mine or mine.status ~= 'pending_in' then return Rpc.Fail('not_found', 'Demande introuvable.') end
    if args.accept == true then
        DB.Execute('UPDATE noirx_contacts SET status = ? WHERE owner_identity = ? AND contact_identity = ?', { 'accepted', me.id, other })
        DB.Execute('UPDATE noirx_contacts SET status = ? WHERE owner_identity = ? AND contact_identity = ? AND status = ?',
            { 'accepted', other, me.id, 'pending_out' })
        Ghost.Push(other, 'ghost:contacts', {})
    else
        DB.Execute('DELETE FROM noirx_contacts WHERE owner_identity = ? AND contact_identity = ?', { me.id, other })
        DB.Execute('DELETE FROM noirx_contacts WHERE owner_identity = ? AND contact_identity = ? AND status = ?',
            { other, me.id, 'pending_out' })
    end
    return { ok = true }
end)

Rpc.Register('contacts.update', { app = 'ghostline' }, function(src, ctx, args)
    local me = Ghost.Owned(ctx.charId, args.identity)
    local other = math.tointeger(tonumber(args.contact))
    if not me or not other then return Rpc.Fail('identity', 'Identité invalide.') end
    local row = contactRow(me.id, other)
    if not row then
        -- Bloquer un inconnu (ex. depuis une conversation de groupe) crée une fiche bloquée.
        if args.blocked == true and DB.Single('SELECT id FROM noirx_identities WHERE id = ?', { other }) then
            DB.Insert([[INSERT INTO noirx_contacts (owner_identity, contact_identity, status, alias, favorite, blocked, trust, created_at)
                VALUES (?, ?, ?, '', 0, 1, 0, ?)]], { me.id, other, 'blocked', now() })
            return { ok = true }
        end
        return Rpc.Fail('not_found', 'Contact introuvable.')
    end
    local alias = row.alias
    if args.alias ~= nil then
        alias = trim(args.alias):gsub('[%c]', '')
        if #alias > 24 then alias = alias:sub(1, 24) end
    end
    local favorite = args.favorite == nil and tonumber(row.favorite) or (args.favorite and 1 or 0)
    local blocked = args.blocked == nil and tonumber(row.blocked) or (args.blocked and 1 or 0)
    local trust = tonumber(row.trust)
    if args.trust ~= nil then
        trust = math.tointeger(tonumber(args.trust))
        if not trust then return Rpc.Fail('bad_args', 'Valeur invalide.') end
        trust = NoirX.Clamp(trust, 0, 5)
    end
    DB.Execute('UPDATE noirx_contacts SET alias = ?, favorite = ?, blocked = ?, trust = ? WHERE owner_identity = ? AND contact_identity = ?',
        { alias, favorite, blocked, trust, me.id, other })
    return { ok = true }
end)

Rpc.Register('contacts.remove', { app = 'ghostline' }, function(src, ctx, args)
    local me = Ghost.Owned(ctx.charId, args.identity)
    local other = math.tointeger(tonumber(args.contact))
    if not me or not other then return Rpc.Fail('identity', 'Identité invalide.') end
    DB.Execute('DELETE FROM noirx_contacts WHERE owner_identity = ? AND contact_identity = ?', { me.id, other })
    DB.Execute('DELETE FROM noirx_contacts WHERE owner_identity = ? AND contact_identity = ? AND status <> ?',
        { other, me.id, 'accepted' })
    return { ok = true }
end)

--- Note de réputation : +1 / -1 / 0, une seule note par paire, uniquement entre contacts établis.
Rpc.Register('contacts.rate', { app = 'ghostline', rate = { 6, 30 } }, function(src, ctx, args)
    local me = Ghost.Owned(ctx.charId, args.identity)
    local other = math.tointeger(tonumber(args.contact))
    local value = math.tointeger(tonumber(args.value))
    if not me or not other or not value or value < -1 or value > 1 then return Rpc.Fail('bad_args', 'Valeur invalide.') end
    local row = contactRow(me.id, other)
    if not row or row.status ~= 'accepted' then return Rpc.Fail('not_contact', 'Contact non établi.') end
    if Ghost.OwnerOf(other) == ctx.charId then return Rpc.Fail('self', 'Impossible de te noter toi-même.') end
    Locks.Run('rate:' .. other, function()
        local existing = DB.Single('SELECT value FROM noirx_ratings WHERE rater = ? AND target = ?', { me.id, other })
        if existing then
            DB.Execute('UPDATE noirx_ratings SET value = ?, updated_at = ? WHERE rater = ? AND target = ?', { value, now(), me.id, other })
        else
            DB.Insert('INSERT INTO noirx_ratings (rater, target, value, updated_at) VALUES (?, ?, ?, ?)', { me.id, other, value, now() })
        end
        local sum = DB.Single('SELECT SUM(value) AS total FROM noirx_ratings WHERE target = ?', { other })
        DB.Execute('UPDATE noirx_identities SET reputation = ? WHERE id = ?', { math.floor(tonumber(sum and sum.total) or 0), other })
    end)
    return { ok = true }
end)

-- ─── Burner ─────────────────────────────────────────────────────

local function randomBurnerHandle()
    local chars = 'abcdefghjkmnpqrstuvwxyz23456789'
    for _ = 1, 20 do
        local s = {}
        for i = 1, 5 do
            local k = math.random(1, #chars)
            s[i] = chars:sub(k, k)
        end
        local h = 'burn-' .. table.concat(s)
        if not handleTaken(h) then return h end
    end
    return nil
end

Rpc.Register('burner.list', { app = 'burner' }, function(src, ctx)
    local rows = DB.Query([[SELECT id, handle, kind, reputation, expires_at, revoked, created_at FROM noirx_identities
        WHERE owner = ? AND kind = ? ORDER BY id DESC LIMIT 10]], { ctx.charId, 'burner' })
    local t = now()
    local list = {}
    for _, r in ipairs(rows) do
        local v = identityView(r)
        v.active = tonumber(r.revoked) == 0 and tonumber(r.expires_at) > t
        v.revoked = tonumber(r.revoked) == 1
        v.remaining = math.max(0, tonumber(r.expires_at) - t)
        list[#list + 1] = v
    end
    local b = Config.Burner
    return {
        burners = list,
        offer = { price = b.price, currency = b.currency, durations = b.durations, maxActive = b.maxActive, symbol = Config.Money.symbol },
    }
end)

local function createBurner(src, ctx, args)
    local b = Config.Burner
    local idx = math.tointeger(tonumber(args.duration))
    local duration = idx and b.durations[idx]
    if not duration then return Rpc.Fail('bad_args', 'Durée invalide.') end
    local handle
    if args.handle ~= nil and trim(args.handle) ~= '' then
        handle = Ghost.ValidHandle(args.handle)
        if not handle then return Rpc.Fail('bad_handle', 'Pseudo invalide.') end
    end

    local ok, res = Locks.Run('money:' .. ctx.charId, function()
        local active = DB.Single([[SELECT COUNT(*) AS n FROM noirx_identities WHERE owner = ? AND kind = ? AND revoked = 0 AND expires_at > ?]],
            { ctx.charId, 'burner', now() })
        if tonumber(active and active.n or 0) >= b.maxActive then
            return Rpc.Fail('limit', 'Nombre maximum de burners actifs atteint.')
        end
        if handle and handleTaken(handle) then return Rpc.Fail('taken', 'Ce pseudo est déjà pris.') end
        handle = handle or randomBurnerHandle()
        if not handle then return Rpc.Fail('internal', 'Réessaie.') end
        if b.price > 0 and not Wallet.Charge(src, b.currency, b.price, 'burner') then
            return Rpc.Fail('funds', 'Fonds insuffisants.')
        end
        local id = createIdentity(ctx.charId, handle, 'burner', now() + duration)
        if not id then
            if b.price > 0 then Payouts.Queue(ctx.charId, b.currency, b.price, 'burner_refund', 'burner:fail:' .. now()) end
            return Rpc.Fail('taken', 'Ce pseudo est déjà pris.')
        end
        Audit.Log(src, 'burner.create', { identity = id, handle = handle, duration = duration, price = b.price })
        return { ok = true, identity = id, handle = handle }
    end)
    if not ok then return Rpc.Fail('busy', 'Transaction en cours.') end
    if res.ok and b.price > 0 then Push.ToSrc(src, 'wallet:changed', {}) end
    return res
end

Rpc.Register('burner.create', { app = 'burner', rate = { 3, 30 } }, createBurner)

Rpc.Register('burner.revoke', { app = 'burner', identityCheck = false }, function(src, ctx, args)
    local id = math.tointeger(tonumber(args.identity))
    if not id then return Rpc.Fail('bad_args', 'Requête invalide.') end
    local n = DB.Execute('UPDATE noirx_identities SET revoked = 1 WHERE id = ? AND owner = ? AND kind = ?', { id, ctx.charId, 'burner' })
    if n ~= 1 then return Rpc.Fail('not_found', 'Burner introuvable.') end
    Audit.Log(src, 'burner.revoke', { identity = id })
    local l = Auth.logins[ctx.charId]
    if l and l.id == id then Auth.Logout(ctx.charId, 'revoked') end
    return { ok = true }
end)

--- Révocation administrative d'une identité (burner ou principale).
function Ghost.AdminRevoke(identityId, actor)
    local n = DB.Execute('UPDATE noirx_identities SET revoked = 1 WHERE id = ?', { math.tointeger(tonumber(identityId)) })
    Audit.Log(0, 'admin.identity_revoke', { identity = identityId, actor = actor })
    return n == 1
end

function Ghost.AdminFind(handle)
    return DB.Single('SELECT id, owner, handle, kind, reputation, created_at, expires_at, revoked FROM noirx_identities WHERE handle_lc = ?',
        { trim(handle):lower() })
end

-- ─── Connexion au réseau par burner ─────────────────────────────
-- Le téléphone ne donne accès aux applications qu'une fois connecté avec un burner actif
-- (Config.Auth.requireBurner). La connexion dure tant que le burner vit : à son expiration
-- ou à sa révocation, le joueur est déconnecté et revient à l'écran de connexion.

local LOGOUT_TEXT = {
    expired = 'Ton burner a expiré : déconnecté du réseau.',
    revoked = 'Ton burner a été révoqué : déconnecté du réseau.',
    manual = 'Déconnecté du réseau.',
}

function Auth.Logout(charId, reason)
    if not Auth.logins[charId] then return end
    Auth.logins[charId] = nil
    local src = Players.SrcOf(charId)
    if src then
        Push.ToSrc(src, 'auth:logout', { reason = reason, message = LOGOUT_TEXT[reason] or LOGOUT_TEXT.manual })
        Push.Notify(src, 'NOIR X', LOGOUT_TEXT[reason] or LOGOUT_TEXT.manual, 'alert')
    end
    Audit.Log(0, 'auth.logout', { owner = charId, reason = reason })
end

local function loginView(l)
    return l and { id = l.id, handle = l.handle, remaining = math.max(0, l.exp - now()) } or nil
end

local function activeBurners(charId)
    local out = {}
    for _, r in ipairs(DB.Query([[SELECT id, handle, expires_at FROM noirx_identities
        WHERE owner = ? AND kind = 'burner' AND revoked = 0 AND expires_at > ? ORDER BY id DESC]], { charId, now() })) do
        out[#out + 1] = { id = math.tointeger(tonumber(r.id)), handle = r.handle, remaining = tonumber(r.expires_at) - now() }
    end
    return out
end

local function doLogin(src, charId, identityId)
    local r = DB.Single([[SELECT id, handle, expires_at FROM noirx_identities
        WHERE id = ? AND owner = ? AND kind = 'burner' AND revoked = 0 AND expires_at > ?]], { identityId, charId, now() })
    if not r then return Rpc.Fail('not_found', 'Burner introuvable ou expiré.') end
    Auth.logins[charId] = { id = math.tointeger(tonumber(r.id)), handle = r.handle, exp = tonumber(r.expires_at) }
    Audit.Log(src, 'auth.login', { identity = r.id })
    return { ok = true, login = loginView(Auth.logins[charId]) }
end

Rpc.Register('auth.state', { auth = false, rate = { 10, 5 } }, function(src, ctx)
    local b = Config.Burner
    return {
        required = Auth.Required(),
        login = loginView(Auth.Get(ctx.charId)),
        burners = activeBurners(ctx.charId),
        offer = { price = b.price, currency = b.currency, durations = b.durations, maxActive = b.maxActive, symbol = Config.Money.symbol },
    }
end)

Rpc.Register('auth.login', { auth = false, rate = { 5, 10 } }, function(src, ctx, args)
    local id = math.tointeger(tonumber(args.identity))
    if not id then return Rpc.Fail('bad_args', 'Requête invalide.') end
    return doLogin(src, ctx.charId, id)
end)

-- Crée un burner temporaire (payant, Config.Burner) puis connecte directement avec.
Rpc.Register('auth.create', { auth = false, rate = { 3, 30 } }, function(src, ctx, args)
    local res = createBurner(src, ctx, args)
    if not res.ok then return res end
    return doLogin(src, ctx.charId, res.identity)
end)

Rpc.Register('auth.logout', { auth = false }, function(src, ctx)
    Auth.Logout(ctx.charId, 'manual')
    return { ok = true }
end)

-- Expiration (toutes les 5 s) et révocation par le staff (toutes les 30 s)
CreateThread(function()
    local tick = 0
    while true do
        Wait(5000)
        tick = tick + 1
        local t = now()
        for charId, l in pairs(Auth.logins) do
            if l.exp <= t then
                Auth.Logout(charId, 'expired')
            elseif tick % 6 == 0 and DB.driver ~= 'none' then
                local r = DB.Single('SELECT revoked FROM noirx_identities WHERE id = ?', { l.id })
                if not r or tonumber(r.revoked) == 1 then Auth.Logout(charId, 'revoked') end
            end
        end
    end
end)
