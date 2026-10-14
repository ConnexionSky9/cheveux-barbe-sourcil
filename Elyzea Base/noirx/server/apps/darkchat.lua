--[[
    NOIR X — DARK CHAT (messagerie clandestine)
    Conversations privées (dm) et groupes, invitations, rôles, messages éphémères,
    favoris, accusés de lecture, blocage (via Ghostline).

    Sécurité : CHAQUE lecture et écriture vérifie côté serveur que l'identité utilisée
    appartient au joueur et qu'elle est membre ACTIF de la conversation. Un nouveau membre
    de groupe ne voit que les messages postérieurs à son arrivée (colonne since_id).
]]

Chat = {}

local function now() return os.time() end
local function int(v) return math.tointeger(tonumber(v)) end

local function member(convId, identityId)
    local r = DB.Single([[SELECT conversation_id, identity_id, role, status, last_read_id, since_id, favorite
        FROM noirx_conv_members WHERE conversation_id = ? AND identity_id = ?]], { convId, identityId })
    return r
end

local function activeMember(convId, identityId)
    local m = member(convId, identityId)
    if m and m.status == 'active' then return m end
    return nil
end

local function conv(convId)
    return DB.Single('SELECT id, kind, name, owner_identity, ephemeral, created_at, last_message_at FROM noirx_conversations WHERE id = ?', { convId })
end

local function activeMembers(convId)
    return DB.Query([[SELECT m.identity_id, m.role, m.status, m.last_read_id, i.handle
        FROM noirx_conv_members m JOIN noirx_identities i ON i.id = m.identity_id
        WHERE m.conversation_id = ? AND m.status = ?]], { convId, 'active' })
end

local function dmPeer(convId, me)
    return DB.Single([[SELECT m.identity_id, m.last_read_id, i.handle FROM noirx_conv_members m
        JOIN noirx_identities i ON i.id = m.identity_id
        WHERE m.conversation_id = ? AND m.identity_id <> ?]], { convId, me })
end

local function ctxIdentity(ctx, args)
    return Ghost.Owned(ctx.charId, args.identity)
end

local function lastMessageId(convId)
    local r = DB.Single('SELECT MAX(id) AS m FROM noirx_messages WHERE conversation_id = ?', { convId })
    return int(r and r.m) or 0
end

local function validEphemeral(sec)
    for _, v in ipairs(Config.Chat.ephemeralOptions) do
        if v == sec then return true end
    end
    return false
end

local function cleanBody(s)
    if type(s) ~= 'string' then return nil end
    -- retire les caractères de contrôle sauf le retour à la ligne (\10)
    s = s:gsub('[\0-\9\11-\31\127]', ''):gsub('\n\n\n+', '\n\n'):gsub('^%s+', ''):gsub('%s+$', '')
    if #s == 0 then return nil end
    if #s > Config.Chat.maxMessageLength then s = s:sub(1, Config.Chat.maxMessageLength) end
    return s
end

local function convTitle(c, me)
    if c.kind == 'group' then return c.name, nil end
    local peer = dmPeer(c.id, me)
    if not peer then return 'Conversation', nil end
    local pid = int(peer.identity_id)
    return Ghost.AliasFor(me, pid) or peer.handle, pid
end

local function messageView(r)
    return {
        id = int(r.id), sender = int(r.sender_identity), handle = r.handle,
        body = r.body, at = tonumber(r.created_at), expiresAt = tonumber(r.expires_at),
    }
end

-- ─── Liste ──────────────────────────────────────────────────────

Rpc.Register('chat.list', { app = 'darkchat' }, function(src, ctx, args)
    local me = ctxIdentity(ctx, args)
    if not me then return Rpc.Fail('identity', 'Identité invalide.') end
    local t = now()
    local rows = DB.Query([[SELECT c.id, c.kind, c.name, c.owner_identity, c.ephemeral, c.last_message_at,
            m.role, m.status, m.last_read_id, m.since_id, m.favorite
        FROM noirx_conv_members m JOIN noirx_conversations c ON c.id = m.conversation_id
        WHERE m.identity_id = ? AND m.status IN ('active', 'invited')
        ORDER BY m.favorite DESC, c.last_message_at DESC]], { me.id })
    local out = {}
    for _, r in ipairs(rows) do
        local c = { id = int(r.id), kind = r.kind, name = r.name }
        local title, peer = convTitle(c, me.id)
        local item = {
            id = c.id, kind = r.kind, title = title, peer = peer, role = r.role, status = r.status,
            favorite = tonumber(r.favorite) == 1, ephemeral = tonumber(r.ephemeral) or 0,
            lastAt = tonumber(r.last_message_at),
        }
        if r.status == 'active' then
            local last = DB.Single([[SELECT m.body, m.sender_identity FROM noirx_messages m
                WHERE m.conversation_id = ? AND m.id > ? AND (m.expires_at IS NULL OR m.expires_at > ?)
                ORDER BY m.id DESC LIMIT 1]], { c.id, int(r.since_id) or 0, t })
            item.preview = last and last.body:sub(1, 60) or nil
            item.previewMine = last and int(last.sender_identity) == me.id or false
            local unread = DB.Single([[SELECT COUNT(*) AS n FROM noirx_messages
                WHERE conversation_id = ? AND id > ? AND id > ? AND sender_identity <> ? AND (expires_at IS NULL OR expires_at > ?)]],
                { c.id, int(r.last_read_id) or 0, int(r.since_id) or 0, me.id, t })
            item.unread = tonumber(unread and unread.n) or 0
        end
        out[#out + 1] = item
    end
    return { conversations = out }
end)

-- ─── Ouverture / création ───────────────────────────────────────

Rpc.Register('chat.dm', { app = 'darkchat', rate = { 6, 10 } }, function(src, ctx, args)
    local me = ctxIdentity(ctx, args)
    if not me then return Rpc.Fail('identity', 'Identité invalide.') end
    local target = args.target and Ghost.Owned(Ghost.OwnerOf(int(args.target)) or '', args.target)
        or Ghost.ByHandle(args.handle)
    if not target then return Rpc.Fail('not_found', 'Contact injoignable.') end
    if target.id == me.id then return Rpc.Fail('self', 'Impossible de t\'écrire à toi-même.') end
    if Ghost.Blocked(me.id, target.id) then return Rpc.Fail('blocked', 'Tu as bloqué ce contact.') end
    if Ghost.Blocked(target.id, me.id) then return Rpc.Fail('not_found', 'Contact injoignable.') end

    local ok, res = Locks.Run('dm:' .. math.min(me.id, target.id) .. ':' .. math.max(me.id, target.id), function()
        local existing = DB.Single([[SELECT c.id FROM noirx_conversations c
            JOIN noirx_conv_members a ON a.conversation_id = c.id AND a.identity_id = ?
            JOIN noirx_conv_members b ON b.conversation_id = c.id AND b.identity_id = ?
            WHERE c.kind = 'dm' LIMIT 1]], { me.id, target.id })
        if existing then
            local id = int(existing.id)
            DB.Execute('UPDATE noirx_conv_members SET status = ? WHERE conversation_id = ?', { 'active', id })
            return { ok = true, conversation = id }
        end
        local t = now()
        local id = int(DB.Insert([[INSERT INTO noirx_conversations (kind, name, owner_identity, ephemeral, created_at, last_message_at)
            VALUES ('dm', '', ?, 0, ?, ?)]], { me.id, t, t }))
        for _, ident in ipairs({ me.id, target.id }) do
            DB.Insert([[INSERT INTO noirx_conv_members (conversation_id, identity_id, role, status, last_read_id, since_id, favorite, joined_at)
                VALUES (?, ?, 'member', 'active', 0, 0, 0, ?)]], { id, ident, t })
        end
        return { ok = true, conversation = id }
    end)
    if not ok then return Rpc.Fail('busy', 'Patiente.') end
    return res
end)

Rpc.Register('chat.group', { app = 'darkchat', rate = { 3, 30 } }, function(src, ctx, args)
    local me = ctxIdentity(ctx, args)
    if not me then return Rpc.Fail('identity', 'Identité invalide.') end
    local name = cleanBody(args.name)
    if not name or #name > 32 then return Rpc.Fail('bad_name', 'Nom de groupe : 1 à 32 caractères.') end
    local owned = DB.Single([[SELECT COUNT(*) AS n FROM noirx_conversations c
        JOIN noirx_conv_members m ON m.conversation_id = c.id AND m.identity_id = ? AND m.role = 'owner' AND m.status = 'active'
        WHERE c.kind = 'group']], { me.id })
    if tonumber(owned and owned.n or 0) >= Config.Chat.maxGroupsOwned then
        return Rpc.Fail('limit', 'Nombre maximum de groupes atteint.')
    end
    local t = now()
    local id = int(DB.Insert([[INSERT INTO noirx_conversations (kind, name, owner_identity, ephemeral, created_at, last_message_at)
        VALUES ('group', ?, ?, 0, ?, ?)]], { name, me.id, t, t }))
    DB.Insert([[INSERT INTO noirx_conv_members (conversation_id, identity_id, role, status, last_read_id, since_id, favorite, joined_at)
        VALUES (?, ?, 'owner', 'active', 0, 0, 0, ?)]], { id, me.id, t })
    Audit.Log(src, 'chat.group_create', { conversation = id, identity = me.id })
    return { ok = true, conversation = id }
end)

-- ─── Membres ────────────────────────────────────────────────────

Rpc.Register('chat.members', { app = 'darkchat' }, function(src, ctx, args)
    local me = ctxIdentity(ctx, args)
    local convId = int(args.conversation)
    if not me or not convId or not activeMember(convId, me.id) then return Rpc.Fail('forbidden', 'Accès refusé.') end
    local rows = DB.Query([[SELECT m.identity_id, m.role, m.status, i.handle FROM noirx_conv_members m
        JOIN noirx_identities i ON i.id = m.identity_id
        WHERE m.conversation_id = ? AND m.status IN ('active', 'invited') ORDER BY m.role = 'owner' DESC, i.handle]], { convId })
    local out = {}
    for _, r in ipairs(rows) do
        local id = int(r.identity_id)
        out[#out + 1] = { id = id, handle = r.handle, alias = Ghost.AliasFor(me.id, id), role = r.role, status = r.status, me = id == me.id }
    end
    local c = conv(convId)
    return { members = out, kind = c.kind, ephemeral = tonumber(c.ephemeral) or 0, name = c.name,
        ephemeralOptions = Config.Chat.ephemeralOptions, max = Config.Chat.maxGroupMembers }
end)

Rpc.Register('chat.invite', { app = 'darkchat', rate = { 8, 30 } }, function(src, ctx, args)
    local me = ctxIdentity(ctx, args)
    local convId = int(args.conversation)
    if not me or not convId then return Rpc.Fail('forbidden', 'Accès refusé.') end
    local c = conv(convId)
    local m = activeMember(convId, me.id)
    if not c or c.kind ~= 'group' or not m or (m.role ~= 'owner' and m.role ~= 'admin') then
        return Rpc.Fail('forbidden', 'Seuls les responsables du groupe peuvent inviter.')
    end
    local sent = { ok = true, message = 'Invitation transmise.' }
    local target = Ghost.ByHandle(args.handle)
    if not target or target.id == me.id then return sent end
    local count = DB.Single([[SELECT COUNT(*) AS n FROM noirx_conv_members WHERE conversation_id = ? AND status IN ('active','invited')]], { convId })
    if tonumber(count and count.n or 0) >= Config.Chat.maxGroupMembers then return Rpc.Fail('full', 'Groupe complet.') end
    local existing = member(convId, target.id)
    if existing and (existing.status == 'active' or existing.status == 'invited') then
        return Rpc.Fail('exists', 'Déjà membre ou invité.')
    end
    if Ghost.Blocked(target.id, me.id) then return sent end
    if existing then
        DB.Execute('UPDATE noirx_conv_members SET status = ?, role = ? WHERE conversation_id = ? AND identity_id = ?',
            { 'invited', 'member', convId, target.id })
    else
        DB.Insert([[INSERT INTO noirx_conv_members (conversation_id, identity_id, role, status, last_read_id, since_id, favorite, joined_at)
            VALUES (?, ?, 'member', 'invited', 0, 0, 0, ?)]], { convId, target.id, now() })
    end
    local tsrc = Ghost.Push(target.id, 'chat:invite', { conversation = convId, name = c.name, from = me.handle })
    if tsrc then Push.Notify(tsrc, 'Dark Chat', ('Invitation au groupe « %s »'):format(c.name)) end
    return sent
end)

Rpc.Register('chat.respond', { app = 'darkchat' }, function(src, ctx, args)
    local me = ctxIdentity(ctx, args)
    local convId = int(args.conversation)
    if not me or not convId then return Rpc.Fail('forbidden', 'Accès refusé.') end
    local m = member(convId, me.id)
    if not m or m.status ~= 'invited' then return Rpc.Fail('not_found', 'Invitation introuvable.') end
    if args.accept == true then
        local since = lastMessageId(convId)
        DB.Execute('UPDATE noirx_conv_members SET status = ?, since_id = ?, last_read_id = ?, joined_at = ? WHERE conversation_id = ? AND identity_id = ?',
            { 'active', since, since, now(), convId, me.id })
        for _, mm in ipairs(activeMembers(convId)) do
            if int(mm.identity_id) ~= me.id then Ghost.Push(int(mm.identity_id), 'chat:members', { conversation = convId }) end
        end
    else
        DB.Execute('DELETE FROM noirx_conv_members WHERE conversation_id = ? AND identity_id = ?', { convId, me.id })
    end
    return { ok = true, conversation = convId }
end)

local function removeMember(convId, identityId)
    DB.Execute('UPDATE noirx_conv_members SET status = ? WHERE conversation_id = ? AND identity_id = ?', { 'left', convId, identityId })
end

local function deleteConversation(convId)
    DB.Execute('DELETE FROM noirx_messages WHERE conversation_id = ?', { convId })
    DB.Execute('DELETE FROM noirx_conv_members WHERE conversation_id = ?', { convId })
    DB.Execute('DELETE FROM noirx_conversations WHERE id = ?', { convId })
end

Rpc.Register('chat.leave', { app = 'darkchat' }, function(src, ctx, args)
    local me = ctxIdentity(ctx, args)
    local convId = int(args.conversation)
    if not me or not convId then return Rpc.Fail('forbidden', 'Accès refusé.') end
    local m = activeMember(convId, me.id)
    local c = conv(convId)
    if not m or not c then return Rpc.Fail('forbidden', 'Accès refusé.') end
    removeMember(convId, me.id)
    if c.kind == 'group' and m.role == 'owner' then
        local heir = DB.Single([[SELECT identity_id FROM noirx_conv_members WHERE conversation_id = ? AND status = 'active'
            ORDER BY role = 'admin' DESC, joined_at ASC LIMIT 1]], { convId })
        if heir then
            DB.Execute('UPDATE noirx_conv_members SET role = ? WHERE conversation_id = ? AND identity_id = ?', { 'owner', convId, int(heir.identity_id) })
            DB.Execute('UPDATE noirx_conversations SET owner_identity = ? WHERE id = ?', { int(heir.identity_id), convId })
        else
            deleteConversation(convId)
            return { ok = true }
        end
    end
    for _, mm in ipairs(activeMembers(convId)) do Ghost.Push(int(mm.identity_id), 'chat:members', { conversation = convId }) end
    return { ok = true }
end)

Rpc.Register('chat.kick', { app = 'darkchat' }, function(src, ctx, args)
    local me = ctxIdentity(ctx, args)
    local convId, target = int(args.conversation), int(args.target)
    if not me or not convId or not target then return Rpc.Fail('forbidden', 'Accès refusé.') end
    local c = conv(convId)
    local m = activeMember(convId, me.id)
    local t = member(convId, target)
    if not c or c.kind ~= 'group' or not m or not t or target == me.id then return Rpc.Fail('forbidden', 'Accès refusé.') end
    local can = m.role == 'owner' or (m.role == 'admin' and t.role == 'member')
    if not can then return Rpc.Fail('forbidden', 'Droits insuffisants.') end
    if t.status == 'invited' then
        DB.Execute('DELETE FROM noirx_conv_members WHERE conversation_id = ? AND identity_id = ?', { convId, target })
    else
        removeMember(convId, target)
    end
    Ghost.Push(target, 'chat:removed', { conversation = convId })
    return { ok = true }
end)

Rpc.Register('chat.role', { app = 'darkchat' }, function(src, ctx, args)
    local me = ctxIdentity(ctx, args)
    local convId, target = int(args.conversation), int(args.target)
    if not me or not convId or not target then return Rpc.Fail('forbidden', 'Accès refusé.') end
    if args.role ~= 'admin' and args.role ~= 'member' then return Rpc.Fail('bad_args', 'Rôle invalide.') end
    local m = activeMember(convId, me.id)
    local t = activeMember(convId, target)
    if not m or m.role ~= 'owner' or not t or target == me.id then return Rpc.Fail('forbidden', 'Seul le fondateur gère les rôles.') end
    DB.Execute('UPDATE noirx_conv_members SET role = ? WHERE conversation_id = ? AND identity_id = ?', { args.role, convId, target })
    return { ok = true }
end)

Rpc.Register('chat.settings', { app = 'darkchat' }, function(src, ctx, args)
    local me = ctxIdentity(ctx, args)
    local convId = int(args.conversation)
    if not me or not convId then return Rpc.Fail('forbidden', 'Accès refusé.') end
    local m = activeMember(convId, me.id)
    local c = conv(convId)
    if not m or not c then return Rpc.Fail('forbidden', 'Accès refusé.') end
    if args.favorite ~= nil then
        DB.Execute('UPDATE noirx_conv_members SET favorite = ? WHERE conversation_id = ? AND identity_id = ?',
            { args.favorite and 1 or 0, convId, me.id })
    end
    if args.ephemeral ~= nil then
        local sec = int(args.ephemeral)
        if not sec or not validEphemeral(sec) then return Rpc.Fail('bad_args', 'Durée invalide.') end
        if c.kind == 'group' and m.role ~= 'owner' and m.role ~= 'admin' then
            return Rpc.Fail('forbidden', 'Seuls les responsables changent ce réglage.')
        end
        DB.Execute('UPDATE noirx_conversations SET ephemeral = ? WHERE id = ?', { sec, convId })
        for _, mm in ipairs(activeMembers(convId)) do
            Ghost.Push(int(mm.identity_id), 'chat:settings', { conversation = convId, ephemeral = sec })
        end
    end
    if args.name ~= nil and c.kind == 'group' then
        if m.role ~= 'owner' and m.role ~= 'admin' then return Rpc.Fail('forbidden', 'Droits insuffisants.') end
        local name = cleanBody(args.name)
        if not name or #name > 32 then return Rpc.Fail('bad_name', 'Nom invalide.') end
        DB.Execute('UPDATE noirx_conversations SET name = ? WHERE id = ?', { name, convId })
    end
    return { ok = true }
end)

-- ─── Messages ───────────────────────────────────────────────────

Rpc.Register('chat.history', { app = 'darkchat', rate = { 20, 10 } }, function(src, ctx, args)
    local me = ctxIdentity(ctx, args)
    local convId = int(args.conversation)
    if not me or not convId then return Rpc.Fail('forbidden', 'Accès refusé.') end
    local m = activeMember(convId, me.id)
    if not m then return Rpc.Fail('forbidden', 'Accès refusé.') end
    local c = conv(convId)
    local before = int(args.before)
    local t = now()
    local params = { convId, int(m.since_id) or 0, t }
    local extra = ''
    if before then extra = ' AND m.id < ?'; params[#params + 1] = before end
    params[#params + 1] = Config.Chat.historyPage
    local rows = DB.Query(([[SELECT m.id, m.sender_identity, m.body, m.created_at, m.expires_at, i.handle
        FROM noirx_messages m JOIN noirx_identities i ON i.id = m.sender_identity
        WHERE m.conversation_id = ? AND m.id > ? AND (m.expires_at IS NULL OR m.expires_at > ?)%s
        ORDER BY m.id DESC LIMIT ?]]):format(extra), params)
    local messages = {}
    for i = #rows, 1, -1 do messages[#messages + 1] = messageView(rows[i]) end

    local newest = messages[#messages] and messages[#messages].id or 0
    if not before and newest > (int(m.last_read_id) or 0) then
        DB.Execute('UPDATE noirx_conv_members SET last_read_id = ? WHERE conversation_id = ? AND identity_id = ?', { newest, convId, me.id })
        if Config.Chat.readReceipts and c.kind == 'dm' then
            local peer = dmPeer(convId, me.id)
            if peer then Ghost.Push(int(peer.identity_id), 'chat:read', { conversation = convId, last = newest }) end
        end
    end

    local title, peerId = convTitle({ id = convId, kind = c.kind, name = c.name }, me.id)
    local peerRead
    if Config.Chat.readReceipts and c.kind == 'dm' then
        local peer = dmPeer(convId, me.id)
        peerRead = peer and int(peer.last_read_id) or 0
    end
    return {
        conversation = { id = convId, kind = c.kind, title = title, peer = peerId, role = m.role,
            ephemeral = tonumber(c.ephemeral) or 0, favorite = tonumber(m.favorite) == 1 },
        messages = messages,
        hasMore = #rows >= Config.Chat.historyPage,
        peerRead = peerRead,
    }
end)

Rpc.Register('chat.send', { app = 'darkchat', rate = { Config.Chat.sendRate.count, Config.Chat.sendRate.per } }, function(src, ctx, args)
    local me = ctxIdentity(ctx, args)
    local convId = int(args.conversation)
    if not me or not convId then return Rpc.Fail('forbidden', 'Accès refusé.') end
    local m = activeMember(convId, me.id)
    local c = conv(convId)
    if not m or not c then return Rpc.Fail('forbidden', 'Accès refusé.') end
    local body = cleanBody(args.body)
    if not body then return Rpc.Fail('empty', 'Message vide.') end

    local members = activeMembers(convId)
    if c.kind == 'dm' then
        local peer = dmPeer(convId, me.id)
        if not peer then return Rpc.Fail('not_found', 'Contact injoignable.') end
        local pid = int(peer.identity_id)
        if Ghost.Blocked(me.id, pid) then return Rpc.Fail('blocked', 'Tu as bloqué ce contact.') end
        if Ghost.Blocked(pid, me.id) then return Rpc.Fail('not_found', 'Contact injoignable.') end
        -- Si l'autre avait masqué la conversation, elle réapparaît.
        DB.Execute('UPDATE noirx_conv_members SET status = ? WHERE conversation_id = ? AND identity_id = ? AND status = ?',
            { 'active', convId, pid, 'left' })
        members = activeMembers(convId)
    end

    local t = now()
    local eph = tonumber(c.ephemeral) or 0
    local expires = eph > 0 and (t + eph) or nil
    local id = int(DB.Insert('INSERT INTO noirx_messages (conversation_id, sender_identity, body, created_at, expires_at) VALUES (?, ?, ?, ?, ?)',
        { convId, me.id, body, t, expires }))
    if not id then return Rpc.Fail('internal', 'Message non transmis.') end
    DB.Execute('UPDATE noirx_conversations SET last_message_at = ? WHERE id = ?', { t, convId })
    DB.Execute('UPDATE noirx_conv_members SET last_read_id = ? WHERE conversation_id = ? AND identity_id = ?', { id, convId, me.id })

    local msg = { id = id, sender = me.id, handle = me.handle, body = body, at = t, expiresAt = expires }
    for _, mm in ipairs(members) do
        local rid = int(mm.identity_id)
        if rid ~= me.id and not (c.kind == 'group' and Ghost.Blocked(rid, me.id)) then
            local title = c.kind == 'group' and c.name or (Ghost.AliasFor(rid, me.id) or me.handle)
            Ghost.Push(rid, 'chat:message', { conversation = convId, message = msg, title = title, kind = c.kind })
        end
    end
    return { ok = true, message = msg }
end)

-- Purge des messages éphémères expirés.
Boot.Register('darkchat', function()
    CreateThread(function()
        while true do
            DB.Execute('DELETE FROM noirx_messages WHERE expires_at IS NOT NULL AND expires_at <= ?', { now() })
            Wait(60000)
        end
    end)
end)
