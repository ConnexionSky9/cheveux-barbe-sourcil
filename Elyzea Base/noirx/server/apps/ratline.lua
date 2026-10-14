--[[
    NOIR X — RATLINE : discussion avec des informateurs PNJ
    Chaque informateur possède des « infos » gérées par le staff : lieu d'un champ de weed,
    emplacement d'un revendeur PNJ et ce qu'il vend, opportunités, rumeurs…
    Le joueur choisit un sujet (ou écrit librement : l'informateur reconnaît des mots-clés),
    paie le prix éventuel (argent sale ou propre), reçoit la réponse et peut placer un GPS.
    Une info achetée reste consultable gratuitement par ce personnage.

    Fiabilité (0-100) : en dessous de 85, l'informateur nuance sa réponse ; en dessous de 60,
    il prévient que l'info peut être périmée. Le staff garde la main sur ce qui est vrai.
]]

Ratline = {}

local Cooldown = {} -- [charId] = os.time()

-- ─── Utilitaires ────────────────────────────────────────────────

local ACCENTS = {
    ['à'] = 'a', ['â'] = 'a', ['ä'] = 'a', ['á'] = 'a', ['ç'] = 'c',
    ['é'] = 'e', ['è'] = 'e', ['ê'] = 'e', ['ë'] = 'e',
    ['î'] = 'i', ['ï'] = 'i', ['í'] = 'i', ['ô'] = 'o', ['ö'] = 'o', ['ó'] = 'o',
    ['ù'] = 'u', ['û'] = 'u', ['ü'] = 'u', ['ú'] = 'u', ['ÿ'] = 'y', ['œ'] = 'oe',
    ['À'] = 'a', ['Â'] = 'a', ['Ç'] = 'c', ['É'] = 'e', ['È'] = 'e', ['Ê'] = 'e',
    ['Î'] = 'i', ['Ô'] = 'o', ['Ù'] = 'u', ['Û'] = 'u',
}

function Ratline.Normalize(text)
    text = tostring(text or '')
    for k, v in pairs(ACCENTS) do text = text:gsub(k, v) end
    return text:lower():gsub('[^%w%s]', ' '):gsub('%s+', ' ')
end

local function cleanText(s, max)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('[%c]', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if #s == 0 then return nil end
    if #s > max then s = s:sub(1, max) end
    return s
end

local function hedge(reliability, answer)
    reliability = tonumber(reliability) or 100
    if reliability < 60 then
        return 'Je te garantis rien, ça date un peu. ' .. answer
    elseif reliability < 85 then
        return 'D\'après ce qui circule… ' .. answer
    end
    return answer
end

local function reliabilityLabel(r)
    r = tonumber(r) or 100
    if r >= 85 then return 'fiable' elseif r >= 60 then return 'probable' end
    return 'rumeur'
end

local function now() return os.time() end

local function activeIntel(informantId)
    return DB.Query([[SELECT id, category, title, keywords, price, currency, reliability, x, y, z
        FROM noirx_intel WHERE informant_id = ? AND enabled = 1 AND (expires_at IS NULL OR expires_at > ?)
        ORDER BY sort_order ASC, id ASC]], { informantId, now() })
end

local function purchasedSet(charId, informantId)
    local rows = DB.Query([[SELECT p.intel_id FROM noirx_intel_purchases p
        JOIN noirx_intel i ON i.id = p.intel_id WHERE p.owner = ? AND i.informant_id = ?]], { charId, informantId })
    local set = {}
    for _, r in ipairs(rows) do set[tonumber(r.intel_id)] = true end
    return set
end

local function getInformant(id)
    id = tonumber(id)
    if not id then return nil end
    return DB.Single('SELECT id, name, tagline, greeting FROM noirx_informants WHERE id = ? AND enabled = 1', { id })
end

local function log(charId, informantId, sender, body, intelId, hasGps)
    DB.Insert([[INSERT INTO noirx_ratline_log (owner, informant_id, sender, body, intel_id, has_gps, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)]], { charId, informantId, sender, body, intelId, hasGps and 1 or 0, now() })
end

local function topicOf(row, purchased)
    return {
        id = tonumber(row.id),
        category = row.category,
        categoryLabel = Config.Ratline.categories[row.category] or row.category,
        title = row.title,
        price = tonumber(row.price) or 0,
        currency = row.currency,
        reliability = reliabilityLabel(row.reliability),
        purchased = purchased == true,
        hasGps = row.x ~= nil and row.y ~= nil,
    }
end

local function typingDelay()
    local d = Config.Ratline.typingDelayMs
    return math.random(d[1], d[2])
end

-- ─── RPC ────────────────────────────────────────────────────────

Rpc.Register('ratline.list', { app = 'ratline' }, function(src, ctx)
    local rows = DB.Query('SELECT id, name, tagline FROM noirx_informants WHERE enabled = 1 ORDER BY sort_order ASC, id ASC', {})
    local out = {}
    for _, r in ipairs(rows) do
        local last = DB.Single('SELECT sender, body, created_at FROM noirx_ratline_log WHERE owner = ? AND informant_id = ? ORDER BY id DESC LIMIT 1',
            { ctx.charId, r.id })
        out[#out + 1] = {
            id = tonumber(r.id), name = r.name, tagline = r.tagline,
            last = last and { body = last.body, at = tonumber(last.created_at), mine = last.sender == 'me' } or nil,
        }
    end
    return { informants = out }
end)

Rpc.Register('ratline.open', { app = 'ratline' }, function(src, ctx, args)
    local inf = getInformant(args.informant)
    if not inf then return Rpc.Fail('not_found', 'Contact injoignable.') end
    local bought = purchasedSet(ctx.charId, inf.id)
    local topics = {}
    for _, row in ipairs(activeIntel(inf.id)) do
        topics[#topics + 1] = topicOf(row, bought[tonumber(row.id)])
    end
    local rows = DB.Query([[SELECT id, sender, body, intel_id, has_gps, created_at FROM noirx_ratline_log
        WHERE owner = ? AND informant_id = ? ORDER BY id DESC LIMIT ?]], { ctx.charId, inf.id, Config.Ratline.historyLimit })
    local history = {}
    for i = #rows, 1, -1 do
        local r = rows[i]
        history[#history + 1] = {
            id = tonumber(r.id), mine = r.sender == 'me', body = r.body,
            intel = tonumber(r.intel_id), gps = tonumber(r.has_gps) == 1, at = tonumber(r.created_at),
        }
    end
    return {
        informant = { id = tonumber(inf.id), name = inf.name, tagline = inf.tagline, greeting = inf.greeting },
        topics = topics,
        history = history,
        symbol = Config.Money.symbol,
    }
end)

Rpc.Register('ratline.ask', { app = 'ratline', rate = { 6, 10 } }, function(src, ctx, args)
    local last = Cooldown[ctx.charId]
    if last and now() - last < Config.Ratline.askCooldownSeconds then
        return Rpc.Fail('cooldown', 'Il te répond, laisse-lui une seconde.')
    end
    local inf = getInformant(args.informant)
    local intelId = tonumber(args.intel)
    if not inf or not intelId then return Rpc.Fail('not_found', 'Contact injoignable.') end

    local ok, result = Locks.Run('money:' .. ctx.charId, function()
        local intel = DB.Single([[SELECT id, title, answer, price, currency, reliability, x, y, z FROM noirx_intel
            WHERE id = ? AND informant_id = ? AND enabled = 1 AND (expires_at IS NULL OR expires_at > ?)]],
            { intelId, inf.id, now() })
        if not intel then return Rpc.Fail('not_found', 'Il ne sait plus rien là-dessus.') end

        local already = DB.Single('SELECT id FROM noirx_intel_purchases WHERE owner = ? AND intel_id = ?', { ctx.charId, intel.id })
        local price = math.floor(tonumber(intel.price) or 0)
        local charged = 0
        if not already then
            if price > 0 then
                if not Wallet.Charge(src, intel.currency, price, 'ratline:' .. intel.id) then
                    return Rpc.Fail('funds', ('Il veut %s%d en %s. Tu ne les as pas.'):format(
                        Config.Money.symbol, price, intel.currency == 'dirty' and 'argent sale' or 'argent propre'))
                end
                charged = price
            end
            DB.Insert('INSERT INTO noirx_intel_purchases (owner, intel_id, price, currency, created_at) VALUES (?, ?, ?, ?, ?)',
                { ctx.charId, intel.id, charged, intel.currency, now() })
        end

        local hasGps = intel.x ~= nil and intel.y ~= nil
        local answer = hedge(intel.reliability, intel.answer)
        log(ctx.charId, inf.id, 'me', intel.title, intel.id, false)
        log(ctx.charId, inf.id, 'npc', answer, intel.id, hasGps)
        Cooldown[ctx.charId] = now()
        Audit.Log(src, 'ratline.ask', { informant = inf.id, intel = intel.id, charged = charged, currency = intel.currency })
        return {
            ok = true,
            question = intel.title,
            answer = answer,
            intel = tonumber(intel.id),
            gps = hasGps and { x = tonumber(intel.x), y = tonumber(intel.y), z = tonumber(intel.z) or 0.0 } or nil,
            charged = charged,
            currency = intel.currency,
            delay = typingDelay(),
        }
    end)
    if not ok then return Rpc.Fail('busy', 'Transaction en cours.') end
    if result and result.charged and result.charged > 0 then Push.ToSrc(src, 'wallet:changed', {}) end
    return result
end)

Rpc.Register('ratline.say', { app = 'ratline', rate = { 6, 10 } }, function(src, ctx, args)
    local inf = getInformant(args.informant)
    if not inf then return Rpc.Fail('not_found', 'Contact injoignable.') end
    local text = cleanText(args.text, Config.Ratline.maxFreeTextLength)
    if not text then return Rpc.Fail('empty', 'Message vide.') end

    local words = {}
    for w in Ratline.Normalize(text):gmatch('%S+') do
        if #w >= 3 then words[w] = true end
    end

    local matches, others = {}, {}
    local bought = purchasedSet(ctx.charId, inf.id)
    for _, row in ipairs(activeIntel(inf.id)) do
        local hit = false
        for kw in tostring(row.keywords or ''):gmatch('[^,]+') do
            local k = Ratline.Normalize(kw):gsub('^%s+', ''):gsub('%s+$', '')
            if #k > 0 then
                if k:find(' ', 1, true) then
                    if Ratline.Normalize(text):find(k, 1, true) then hit = true end
                elseif words[k] then
                    hit = true
                end
            end
            if hit then break end
        end
        if hit then matches[#matches + 1] = topicOf(row, bought[tonumber(row.id)])
        else others[#others + 1] = topicOf(row, bought[tonumber(row.id)]) end
    end

    local reply, suggestions
    if #matches > 0 then
        reply = #matches == 1 and 'Ça, je peux t\'en parler. Tu veux savoir ?' or 'J\'ai plusieurs trucs là-dessus. Lequel ?'
        suggestions = matches
    elseif #others > 0 then
        reply = 'Connais pas. Par contre, je peux te parler de ça :'
        suggestions = { table.unpack(others, 1, math.min(3, #others)) }
    else
        reply = 'J\'ai rien pour toi en ce moment. Repasse plus tard.'
        suggestions = {}
    end
    log(ctx.charId, inf.id, 'me', text, nil, false)
    log(ctx.charId, inf.id, 'npc', reply, nil, false)
    return { reply = reply, suggestions = suggestions, delay = typingDelay() }
end)

Rpc.Register('ratline.gps', { app = 'ratline' }, function(src, ctx, args)
    local intelId = tonumber(args.intel)
    if not intelId then return Rpc.Fail('bad_args', 'Requête invalide.') end
    local row = DB.Single([[SELECT i.x, i.y, i.z FROM noirx_intel i
        JOIN noirx_intel_purchases p ON p.intel_id = i.id AND p.owner = ?
        WHERE i.id = ? AND i.enabled = 1]], { ctx.charId, intelId })
    if not row or row.x == nil then return Rpc.Fail('not_found', 'Position indisponible.') end
    return { gps = { x = tonumber(row.x), y = tonumber(row.y), z = tonumber(row.z) or 0.0 } }
end)

-- ─── Administration (appelée par server/admin_api.lua) ─────────

local function validInformant(d, partial)
    if type(d) ~= 'table' then return nil, 'bad_data' end
    local out = {}
    if d.name ~= nil or not partial then
        out.name = cleanText(d.name, 40); if not out.name then return nil, 'name_required' end
    end
    if d.tagline ~= nil then out.tagline = cleanText(d.tagline, 80) or '' end
    if d.greeting ~= nil then out.greeting = cleanText(d.greeting, 240) or '' end
    if d.enabled ~= nil then out.enabled = d.enabled and 1 or 0 end
    if d.sort_order ~= nil then out.sort_order = math.floor(tonumber(d.sort_order) or 0) end
    return out
end

local function validIntel(d, partial)
    if type(d) ~= 'table' then return nil, 'bad_data' end
    local out = {}
    if d.informant_id ~= nil or not partial then
        out.informant_id = math.tointeger(tonumber(d.informant_id))
        if not out.informant_id or not DB.Single('SELECT id FROM noirx_informants WHERE id = ?', { out.informant_id }) then
            return nil, 'informant_not_found'
        end
    end
    if d.category ~= nil or not partial then
        out.category = tostring(d.category or 'other')
        if not Config.Ratline.categories[out.category] then return nil, 'bad_category' end
    end
    if d.title ~= nil or not partial then
        out.title = cleanText(d.title, 80); if not out.title then return nil, 'title_required' end
    end
    if d.answer ~= nil or not partial then
        out.answer = cleanText(d.answer, 600); if not out.answer then return nil, 'answer_required' end
    end
    if d.keywords ~= nil then out.keywords = cleanText(d.keywords, 255) or '' end
    if d.price ~= nil then
        local p = tonumber(d.price)
        if not p or p < 0 or p ~= p or p > 1e9 then return nil, 'bad_price' end
        out.price = math.floor(p)
    end
    if d.currency ~= nil then
        if d.currency ~= 'dirty' and d.currency ~= 'clean' then return nil, 'bad_currency' end
        out.currency = d.currency
    end
    if d.reliability ~= nil then
        local r = tonumber(d.reliability)
        if not r or r ~= r then return nil, 'bad_reliability' end
        out.reliability = math.floor(NoirX.Clamp(r, 0, 100))
    end
    if d.coords ~= nil then
        if d.coords == false then
            out.x, out.y, out.z = nil, nil, nil
            out.__clearCoords = true
        else
            local c = d.coords
            local x, y, z = tonumber(c.x or c[1]), tonumber(c.y or c[2]), tonumber(c.z or c[3] or 0)
            if not x or not y or x ~= x or y ~= y then return nil, 'bad_coords' end
            out.x, out.y, out.z = x, y, z or 0.0
        end
    end
    if d.expires_at ~= nil then
        if d.expires_at == false then out.__clearExpiry = true
        else
            local e = math.tointeger(tonumber(d.expires_at))
            if not e then return nil, 'bad_expiry' end
            out.expires_at = e
        end
    end
    if d.enabled ~= nil then out.enabled = d.enabled and 1 or 0 end
    if d.sort_order ~= nil then out.sort_order = math.floor(tonumber(d.sort_order) or 0) end
    return out
end

local function buildUpdate(tbl, data, id)
    local sets, params = {}, {}
    local columns = {}
    for k, v in pairs(data) do
        if k:sub(1, 2) ~= '__' then columns[#columns + 1] = k end
    end
    table.sort(columns)
    for _, k in ipairs(columns) do
        sets[#sets + 1] = k .. ' = ?'
        params[#params + 1] = data[k]
    end
    if data.__clearCoords then sets[#sets + 1] = 'x = NULL, y = NULL, z = NULL' end
    if data.__clearExpiry then sets[#sets + 1] = 'expires_at = NULL' end
    if #sets == 0 then return nil end
    params[#params + 1] = id
    -- Les noms de colonnes viennent exclusivement des validateurs ci-dessus (liste fermée).
    return ('UPDATE %s SET %s WHERE id = ?'):format(tbl, table.concat(sets, ', ')), params
end

function Ratline.AdminCreateInformant(d)
    local data, err = validInformant(d, false)
    if not data then return false, err end
    local id = DB.Insert([[INSERT INTO noirx_informants (name, tagline, greeting, enabled, sort_order, created_at)
        VALUES (?, ?, ?, ?, ?, ?)]], { data.name, data.tagline or '', data.greeting or '',
        data.enabled == nil and 1 or data.enabled, data.sort_order or 0, now() })
    return id ~= nil, id
end

function Ratline.AdminUpdateInformant(id, d)
    local data, err = validInformant(d, true)
    if not data then return false, err end
    local sql, params = buildUpdate('noirx_informants', data, tonumber(id))
    if not sql then return false, 'nothing_to_update' end
    return DB.Execute(sql, params) == 1
end

function Ratline.AdminDeleteInformant(id)
    id = tonumber(id)
    DB.Execute('DELETE FROM noirx_intel WHERE informant_id = ?', { id })
    return DB.Execute('DELETE FROM noirx_informants WHERE id = ?', { id }) == 1
end

function Ratline.AdminListInformants()
    return DB.Query('SELECT id, name, tagline, greeting, enabled, sort_order FROM noirx_informants ORDER BY sort_order, id', {})
end

function Ratline.AdminCreateIntel(d)
    local data, err = validIntel(d, false)
    if not data then return false, err end
    local id = DB.Insert([[INSERT INTO noirx_intel (informant_id, category, title, keywords, answer, x, y, z, price, currency,
        reliability, enabled, expires_at, sort_order, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        { data.informant_id, data.category, data.title, data.keywords or '', data.answer, data.x, data.y, data.z,
          data.price or 0, data.currency or 'dirty', data.reliability or 100,
          data.enabled == nil and 1 or data.enabled, data.expires_at, data.sort_order or 0, now(), now() })
    return id ~= nil, id
end

function Ratline.AdminUpdateIntel(id, d)
    local data, err = validIntel(d, true)
    if not data then return false, err end
    data.updated_at = now()
    local sql, params = buildUpdate('noirx_intel', data, tonumber(id))
    if not sql then return false, 'nothing_to_update' end
    return DB.Execute(sql, params) == 1
end

function Ratline.AdminDeleteIntel(id)
    return DB.Execute('DELETE FROM noirx_intel WHERE id = ?', { tonumber(id) }) == 1
end

function Ratline.AdminListIntel(informantId)
    if informantId then
        return DB.Query('SELECT * FROM noirx_intel WHERE informant_id = ? ORDER BY sort_order, id', { tonumber(informantId) })
    end
    return DB.Query('SELECT * FROM noirx_intel ORDER BY informant_id, sort_order, id', {})
end
