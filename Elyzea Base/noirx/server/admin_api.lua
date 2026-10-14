--[[
    NOIR X — API d'administration
    ─────────────────────────────────────────────────────────────────
    Ces exports serveur sont prévus pour être appelés par TON admin menu
    (aucun deuxième menu n'est créé). Exemple depuis une autre ressource :
        local ok, id = exports.noirx:AdminCreateIntel({ informant_id = 1, category = 'weed', ... })

    Des commandes en jeu réservées au staff
    (permission admin_menu noirx_staff) permettent de tout gérer : voir INTEGRATION.md § 6.
    Toutes les actions sont journalisées dans noirx_audit.
]]

local function actorOf(actor) return tostring(actor or GetInvokingResource() or 'console') end

-- ─── Réglages persistants ───────────────────────────────────────
exports('AdminGetSetting', function(path) return Settings.Get(path) end)
exports('AdminSetSetting', function(path, value, actor) return Settings.Set(path, value, actorOf(actor)) end)
exports('AdminResetSetting', function(path, actor) return Settings.Reset(path, actorOf(actor)) end)
exports('AdminGetConfig', function() return Config end)

-- ─── Ratline : informateurs et informations ─────────────────────
exports('AdminListInformants', function() return Ratline.AdminListInformants() end)
exports('AdminCreateInformant', function(data) return Ratline.AdminCreateInformant(data) end)
exports('AdminUpdateInformant', function(id, data) return Ratline.AdminUpdateInformant(id, data) end)
exports('AdminDeleteInformant', function(id) return Ratline.AdminDeleteInformant(id) end)
exports('AdminListIntel', function(informantId) return Ratline.AdminListIntel(informantId) end)
exports('AdminCreateIntel', function(data) return Ratline.AdminCreateIntel(data) end)
exports('AdminUpdateIntel', function(id, data) return Ratline.AdminUpdateIntel(id, data) end)
exports('AdminDeleteIntel', function(id) return Ratline.AdminDeleteIntel(id) end)
exports('AdminGetRatlineCategories', function() return Config.Ratline.categories end)

-- ─── Blanchiment ────────────────────────────────────────────────
exports('AdminListLaunders', function() return Launder.AdminList() end)
exports('AdminCancelLaunder', function(jobId, refund, actor) return Launder.AdminCancel(jobId, refund == true, actorOf(actor)) end)

-- ─── Identités ──────────────────────────────────────────────────
exports('AdminFindIdentity', function(handle) return Ghost.AdminFind(handle) end)
exports('AdminRevokeIdentity', function(id, actor) return Ghost.AdminRevoke(id, actorOf(actor)) end)

-- ─── Paiements ──────────────────────────────────────────────────
exports('AdminListStuckPayouts', function()
    return DB.Query('SELECT * FROM noirx_payouts WHERE status = ? ORDER BY id', { 'processing' })
end)
--- Après vérification manuelle : 'paid' (déjà versé) ou 'pending' (à reverser).
exports('AdminResolvePayout', function(id, status, actor)
    if status ~= 'paid' and status ~= 'pending' then return false end
    local n = DB.Execute('UPDATE noirx_payouts SET status = ? WHERE id = ? AND status = ?', { status, tonumber(id), 'processing' })
    Audit.Log(0, 'admin.payout_resolve', { id = id, status = status, actor = actorOf(actor) })
    return n == 1
end)

-- ─── Journaux ───────────────────────────────────────────────────
exports('AdminGetAudit', function(limit, action)
    limit = math.min(500, math.max(1, math.tointeger(tonumber(limit)) or 100))
    if action then
        return DB.Query('SELECT * FROM noirx_audit WHERE action = ? ORDER BY id DESC LIMIT ?', { action, limit })
    end
    return DB.Query('SELECT * FROM noirx_audit ORDER BY id DESC LIMIT ?', { limit })
end)

-- ═══ Commandes en jeu (staff) — solution d'attente avant l'admin menu ═══

local function reply(src, msg)
    if src == 0 then print('[noirx] ' .. msg) return end
    TriggerClientEvent('chat:addMessage', src, { args = { 'NOIR X', msg } })
    TriggerClientEvent('noirx:client:notify', src, 'Admin', msg)
end

local function staffCommand(name, fn)
    RegisterCommand(name, function(src, args, raw)
        if not Admin.IsStaff(src) then return end
        local ok, err = pcall(fn, src, args, raw)
        if not ok then reply(src, 'Erreur : ' .. tostring(err)) end
    end, false)
end

--- Sépare la partie après la commande sur le caractère |
local function pipeArgs(raw)
    local rest = raw:match('^%S+%s*(.*)$') or ''
    local out = {}
    for part in (rest .. '|'):gmatch('(.-)|') do out[#out + 1] = (part:gsub('^%s+', ''):gsub('%s+$', '')) end
    return out
end

local function playerCoords(src)
    if src == 0 then return nil end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

-- /nx_informant_add Nom | accroche | message d'accueil
staffCommand('nx_informant_add', function(src, _, raw)
    local p = pipeArgs(raw)
    local ok, id = Ratline.AdminCreateInformant({ name = p[1], tagline = p[2], greeting = p[3] })
    reply(src, ok and ('Informateur créé : #%s'):format(id) or ('Refusé : %s'):format(id))
end)

-- /nx_informant_list
staffCommand('nx_informant_list', function(src)
    for _, r in ipairs(Ratline.AdminListInformants()) do
        reply(src, ('#%s %s %s'):format(r.id, r.name, tonumber(r.enabled) == 1 and '' or '(désactivé)'))
    end
end)

-- /nx_intel_here <informantId> <catégorie> <prix> <dirty|clean> <fiabilité> | Titre | Réponse | mots, clés
-- Enregistre ta position actuelle comme GPS de l'info.
staffCommand('nx_intel_here', function(src, args, raw)
    local p = pipeArgs(raw)
    local head = {}
    for w in (p[1] or ''):gmatch('%S+') do head[#head + 1] = w end
    local ok, id = Ratline.AdminCreateIntel({
        informant_id = head[1], category = head[2], price = tonumber(head[3]) or 0,
        currency = head[4] or 'dirty', reliability = tonumber(head[5]) or 100,
        title = p[2], answer = p[3], keywords = p[4] or '', coords = playerCoords(src),
    })
    reply(src, ok and ('Info créée : #%s'):format(id) or ('Refusé : %s'):format(id))
end)

-- /nx_intel_add : identique mais sans GPS
staffCommand('nx_intel_add', function(src, args, raw)
    local p = pipeArgs(raw)
    local head = {}
    for w in (p[1] or ''):gmatch('%S+') do head[#head + 1] = w end
    local ok, id = Ratline.AdminCreateIntel({
        informant_id = head[1], category = head[2], price = tonumber(head[3]) or 0,
        currency = head[4] or 'dirty', reliability = tonumber(head[5]) or 100,
        title = p[2], answer = p[3], keywords = p[4] or '',
    })
    reply(src, ok and ('Info créée : #%s'):format(id) or ('Refusé : %s'):format(id))
end)

-- /nx_intel_list [informantId]
staffCommand('nx_intel_list', function(src, args)
    for _, r in ipairs(Ratline.AdminListIntel(args[1])) do
        reply(src, ('#%s [inf %s · %s] %s — %s%s %s%s'):format(r.id, r.informant_id, r.category, r.title,
            Config.Money.symbol, r.price, r.currency, r.x and ' · GPS' or ''))
    end
end)

-- /nx_intel_toggle <id> on|off
staffCommand('nx_intel_toggle', function(src, args)
    local ok = Ratline.AdminUpdateIntel(args[1], { enabled = args[2] ~= 'off' })
    reply(src, ok and 'Info mise à jour.' or 'Info introuvable.')
end)

-- /nx_intel_del <id>
staffCommand('nx_intel_del', function(src, args)
    reply(src, Ratline.AdminDeleteIntel(args[1]) and 'Info supprimée.' or 'Info introuvable.')
end)

-- /nx_set <chemin> <valeur>      ex. /nx_set Laundering.feePercent 25
staffCommand('nx_set', function(src, args)
    local path, raw = args[1], args[2]
    if not path or raw == nil then reply(src, 'Usage : /nx_set Chemin.Du.Reglage valeur') return end
    local current = Settings.Get(path)
    local value
    if type(current) == 'number' then value = tonumber(raw)
    elseif type(current) == 'boolean' then value = (raw == 'true' or raw == 'on' or raw == '1')
    else value = table.concat(args, ' ', 2) end
    local ok, err = Settings.Set(path, value, src == 0 and 'console' or Players.CharOf(src))
    reply(src, ok and ('%s = %s'):format(path, tostring(value)) or ('Refusé : %s'):format(err))
end)

-- /nx_get <chemin>
staffCommand('nx_get', function(src, args)
    reply(src, ('%s = %s'):format(tostring(args[1]), tostring(Settings.Get(args[1] or ''))))
end)

-- /nx_launders
staffCommand('nx_launders', function(src)
    local list = Launder.AdminList()
    if #list == 0 then reply(src, 'Aucun blanchiment en cours.') end
    for _, j in ipairs(list) do
        reply(src, ('#%d %s — %s%d, reste %ds%s'):format(j.id, j.owner, Config.Money.symbol, j.amount, j.remaining,
            j.underAttack and ' · ATTAQUE' or ''))
    end
end)

-- /nx_launder_cancel <id> [refund]
staffCommand('nx_launder_cancel', function(src, args)
    local ok, info = Launder.AdminCancel(args[1], args[2] == 'refund', src == 0 and 'console' or Players.CharOf(src))
    reply(src, ok and ('Annulé. Remboursé : %s%d'):format(Config.Money.symbol, info) or ('Refusé : %s'):format(info))
end)

-- /nx_revoke <pseudo>
staffCommand('nx_revoke', function(src, args)
    local row = Ghost.AdminFind(args[1] or '')
    if not row then reply(src, 'Pseudo introuvable.') return end
    Ghost.AdminRevoke(row.id, src == 0 and 'console' or Players.CharOf(src))
    reply(src, ('Identité %s révoquée.'):format(row.handle))
end)
