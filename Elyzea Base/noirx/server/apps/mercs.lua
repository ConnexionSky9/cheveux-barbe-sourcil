--[[
    NOIR X — MERCENAIRES (contrats de PNJ armés)

    Cycle d'un contrat :
      1. Devis (mercs.quote) : le commanditaire donne le NOM COMPLET d'un personnage connecté et
         une formule (1, 3 ou 5 mercenaires). Le serveur vérifie la cible et toutes les limites.
      2. Commande (mercs.order) : revérification complète, débit UNE seule fois (verrou par
         personnage), enregistrement en base. Statut « pending ».
      3. Au bout de Config.Mercs.deployDelaySeconds, le serveur demande au jeu de la cible des
         points d'apparition (routes à 140-240 m), les revalide (distance réelle côté serveur),
         puis crée lui-même véhicules et PNJ (OneSync). Statut « deploying ».
      4. Quand un mercenaire arrive à portée : statut « engaged » (alerte police facultative).
      5. Fin : « success » (cible à terre), « failed » (équipe éliminée), « expired » (cible jamais
         trouvée), « timeout » (combat trop long), « target_left » (cible déconnectée),
         « cancelled » (staff). Remboursement selon Config.Mercs.refund, versé par la file de
         paiements (exactement une fois). Les PNJ s'en vont puis sont supprimés.

    Le client ne fournit que des positions candidates et ne contrôle ni le nombre de PNJ,
    ni les montants, ni le résultat. Après un redémarrage, les contrats actifs repartent
    en « pending » (les PNJ n'existent plus) ou expirent avec remboursement.
]]

Mercs = { contracts = {}, leaving = {} }

local Contracts = Mercs.contracts   -- [id] = contrat actif
local Leaving = Mercs.leaving       -- [id] = { ents, at }
local Quotes = {}                   -- [charId] = devis
local ACTIVE = { pending = true, deploying = true, engaged = true }

local function cfg() return Config.Mercs end
local function now() return os.time() end
local function gt() return GetGameTimer() end

local function tierById(id)
    for _, t in ipairs(cfg().tiers) do
        if t.id == id then return t end
    end
    return nil
end

local function norm(s)
    s = tostring(s or ''):lower():gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
    return s
end

local function sym() return Config.Money.symbol end
local function money(n) return ('%s%d'):format(sym(), math.floor(n or 0)) end

-- ─── Vues ───────────────────────────────────────────────────────

local function aliveCount(c)
    local n = 0
    for _, ped in ipairs(c.peds or {}) do
        if DoesEntityExist(ped) and not (c.dead and c.dead[ped]) then n = n + 1 end
    end
    return n
end

local function view(c)
    local t = now()
    return {
        id = c.id, targetName = c.targetName, tier = c.tier, label = (tierById(c.tier) or {}).label or c.tier,
        size = c.size, price = c.price, currency = c.currency, status = c.status,
        createdAt = c.createdAt,
        deployIn = math.max(0, c.deployAt - t),
        expiresIn = math.max(0, c.expiresAt - t),
        engagedAt = c.engagedAt,
        engageLeft = c.engagedAt and math.max(0, c.engagedAt + cfg().engageSeconds - t) or nil,
        alive = (c.status == 'deploying' or c.status == 'engaged') and aliveCount(c) or nil,
        waiting = c.waitReason,
    }
end

local function pushBuyer(c, title, body, kind)
    local src = Players.SrcOf(c.buyer)
    if not src then return end
    Push.ToSrc(src, 'mercs:update', { contract = view(c) })
    if title then Push.Notify(src, title, body, kind) end
end

-- ─── Cible : recherche et protections ───────────────────────────

local function findTarget(name)
    local want = norm(name)
    if #want < 3 then return nil end
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        local charId = src and Players.CharOf(src)
        if charId and norm(Identity.GetCharName(src)) == want then
            return src, charId, Identity.GetCharName(src)
        end
    end
    return nil
end

local function jobOf(src)
    if GetResourceState('elyzea_core') ~= 'started' then return nil end
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData(src) end)
    return ok and type(pd) == 'table' and type(pd.job) == 'table' and pd.job or nil
end

local function isDown(src)
    if Player(src).state.emsDown == true then return true end
    local ped = GetPlayerPed(src)
    return ped == 0 or GetEntityHealth(ped) <= 0
end

--- nil si la cible est attaquable, sinon un code + message.
local function protection(tsrc)
    local c = cfg()
    if c.protectedAce and c.protectedAce ~= '' and IsPlayerAceAllowed(tsrc, c.protectedAce) then
        return 'protected', 'Le réseau refuse ce contrat : cible intouchable.'
    end
    if c.protectStaffOnDuty and GetResourceState('admin_menu') == 'started' then
        local ok, staff = pcall(function() return exports.admin_menu:IsStaffOnDuty(tsrc) end)
        if ok and staff == true then return 'protected', 'Le réseau refuse ce contrat : cible intouchable.' end
    end
    if #(c.protectedJobs or {}) > 0 then
        local job = jobOf(tsrc)
        if job and job.onduty then
            for _, j in ipairs(c.protectedJobs) do
                if j == job.name then return 'protected', 'Le réseau refuse ce contrat : cible intouchable.' end
            end
        end
    end
    if isDown(tsrc) then return 'down', 'La cible est déjà hors d\'état.' end
    if GetPlayerRoutingBucket(tsrc) ~= 0 then return 'unreachable', 'Cible injoignable pour le moment. Réessaie plus tard.' end
    return nil
end

local function policeCount()
    if GetResourceState('elyzea_police') ~= 'started' then return 0 end
    local ok, n = pcall(function() return exports.elyzea_police:GetOnDutyCount() end)
    return ok and tonumber(n) or 0
end

local function activeCount(filter)
    local n = 0
    for _, c in pairs(Contracts) do
        if filter(c) then n = n + 1 end
    end
    return n
end

local function buyerCooldown(charId)
    local row = DB.Single('SELECT MAX(created_at) AS last FROM noirx_merc_contracts WHERE buyer = ?', { charId })
    local last = row and tonumber(row.last)
    if not last then return 0 end
    return math.max(0, last + cfg().cooldownMinutes * 60 - now())
end

--- Toutes les règles d'une commande. Retourne nil ou Rpc.Fail(...).
local function checkOrder(src, charId, tsrc, tchar, tier)
    local c = cfg()
    if tchar == charId then return Rpc.Fail('self', 'Contrat refusé.') end
    local code, msg = protection(tsrc)
    if code then return Rpc.Fail(code, msg) end
    if c.minPolice > 0 and policeCount() < c.minPolice then
        return Rpc.Fail('police', 'Trop calme en ville : le réseau n\'envoie personne pour l\'instant.')
    end
    if activeCount(function(x) return x.buyer == charId end) >= c.maxActivePerBuyer then
        return Rpc.Fail('busy', 'Tu as déjà un contrat en cours.')
    end
    if activeCount(function() return true end) >= c.maxActiveGlobal then
        return Rpc.Fail('saturated', 'Toutes les équipes sont occupées. Réessaie plus tard.')
    end
    if activeCount(function(x) return x.target == tchar end) > 0 then
        return Rpc.Fail('target_busy', 'Un contrat est déjà en cours sur cette cible.')
    end
    local cd = buyerCooldown(charId)
    if cd > 0 then return Rpc.Fail('cooldown', ('Les équipes ne reprennent pas tes appels avant %d min.'):format(math.ceil(cd / 60))) end
    local row = DB.Single([[SELECT COUNT(*) AS n, MAX(created_at) AS last FROM noirx_merc_contracts
        WHERE target = ? AND created_at > ? AND status <> 'cancelled']], { tchar, now() - 86400 }) or {}
    if (tonumber(row.n) or 0) >= c.maxPerTargetPerDay then
        return Rpc.Fail('target_limit', 'Cette cible a déjà fait l\'objet de trop de contrats aujourd\'hui.')
    end
    local last = tonumber(row.last)
    if last and last + c.targetCooldownMinutes * 60 > now() then
        return Rpc.Fail('target_cooldown', 'Cette cible est trop surveillée en ce moment. Réessaie plus tard.')
    end
    if not tier then return Rpc.Fail('bad_tier', 'Formule inconnue.') end
    return nil
end

-- ─── Fin de contrat ─────────────────────────────────────────────

local function release(c)
    local ents = {}
    for _, ped in ipairs(c.peds or {}) do
        if DoesEntityExist(ped) then
            local st = Entity(ped).state.nxMerc
            if type(st) == 'table' then
                st.leave = true
                Entity(ped).state:set('nxMerc', st, true)
            end
            ents[#ents + 1] = ped
        end
    end
    for _, veh in ipairs(c.vehs or {}) do
        if DoesEntityExist(veh) then ents[#ents + 1] = veh end
    end
    if #ents > 0 then Leaving[c.id] = { ents = ents, at = now() + cfg().leaveSeconds } end
    GlobalState[('nxm:%d'):format(c.id)] = nil
end

local END_TEXT = {
    success = 'Contrat rempli. L\'équipe se retire.',
    failed = 'L\'équipe a été éliminée. Contrat perdu.',
    expired = 'L\'équipe n\'a jamais trouvé la cible. Contrat expiré.',
    timeout = 'L\'équipe a décroché : la cible tient trop longtemps.',
    target_left = 'La cible a disparu du réseau. Contrat annulé.',
    cancelled = 'Contrat annulé par le réseau.',
}

--- Termine un contrat (une seule fois). refundPct facultatif (sinon Config.Mercs.refund[status]).
function Mercs.Finish(c, status, note, refundPct)
    if not Contracts[c.id] then return false end
    Contracts[c.id] = nil
    local t = now()
    local updated = DB.Execute([[UPDATE noirx_merc_contracts SET status = ?, note = ?, finished_at = ?
        WHERE id = ? AND status IN ('pending', 'deploying', 'engaged')]], { status, note and tostring(note):sub(1, 120) or nil, t, c.id })
    release(c)
    c.status = status
    if updated ~= 1 then
        NoirX.Warn(('Contrat mercenaires %s déjà terminé en base.'):format(tostring(c.id)))
        return false
    end
    local pct = refundPct or (cfg().refund or {})[status] or 0
    local refund = math.floor(c.price * math.max(0, math.min(100, pct)) / 100)
    if refund > 0 then
        Payouts.Queue(c.buyer, c.currency, refund, 'mercs_refund', ('mercs:%d:refund'):format(c.id))
        DB.Execute('UPDATE noirx_merc_contracts SET refund = ? WHERE id = ?', { refund, c.id })
    end
    c.refund = refund
    Audit.Log(0, 'mercs.finish', { contract = c.id, status = status, refund = refund, note = note })
    local text = END_TEXT[status] or 'Contrat terminé.'
    if refund > 0 then text = text .. (' Remboursement : %s.'):format(money(refund)) end
    pushBuyer(c, 'Mercenaires', text, status == 'success' and nil or (status == 'failed' and 'error' or nil))
    return true
end

-- ─── Apparition ─────────────────────────────────────────────────

local function waitEntity(ent)
    local limit = gt() + 2000
    while (not ent or ent == 0 or not DoesEntityExist(ent)) and gt() < limit do Wait(25) end
    return ent and ent ~= 0 and DoesEntityExist(ent)
end

local function pick(t) return t[math.random(1, #t)] end

local function requestSpots(c, tsrc)
    local v = cfg().vehicle
    local groups = v.enabled and math.ceil(c.size / math.max(1, v.seats)) or 1
    c.spotReq = { nonce = math.random(100000, 999999), at = gt(), groups = groups }
    TriggerClientEvent('noirx:client:mercSpots', tsrc, c.id, c.spotReq.nonce, groups,
        cfg().spawnDistance[1], cfg().spawnDistance[2], v.enabled == true)
end

local function spawnTeam(c, spots, tsrc)
    local mc = cfg()
    local tier = tierById(c.tier)
    local v = mc.vehicle
    c.peds, c.vehs, c.dead = {}, {}, {}
    local seats = v.enabled and math.max(1, v.seats) or c.size
    local made = 0
    local g = 0
    while made < c.size do
        g = g + 1
        local s = spots[(g - 1) % #spots + 1]
        local veh
        if v.enabled then
            veh = CreateVehicleServerSetter(joaat(pick(v.models)), 'automobile', s.x, s.y, s.z + 0.3, s.h)
            if waitEntity(veh) then
                if SetEntityOrphanMode then SetEntityOrphanMode(veh, 0) end
                Entity(veh).state:set('nxMercVeh', c.id, true)
                c.vehs[#c.vehs + 1] = veh
            else
                veh = nil
            end
        end
        for seat = 1, seats do
            if made >= c.size then break end
            local ox, oy = 0.0, 0.0
            if not veh then ox, oy = math.random(-30, 30) / 10, math.random(-30, 30) / 10 end
            local ped = CreatePed(4, joaat(pick(mc.models)), s.x + ox, s.y + oy, s.z, s.h, true, true)
            if waitEntity(ped) then
                if SetEntityOrphanMode then SetEntityOrphanMode(ped, 0) end
                if veh then SetPedIntoVehicle(ped, veh, seat - 2) end
                GiveWeaponToPed(ped, joaat(tier.weapons[(made % #tier.weapons) + 1]), 250, false, true)
                SetPedArmour(ped, math.floor(tier.armour or 0))
                Entity(ped).state:set('nxMerc', {
                    c = c.id, t = tsrc, acc = tier.accuracy, hp = tier.health,
                    drv = veh ~= nil and seat == 1, hostile = mc.hostileToAll == true,
                }, true)
                c.peds[#c.peds + 1] = ped
            end
            made = made + 1
        end
        if g > 10 then break end
    end
    return #c.peds > 0
end

-- Points d'apparition proposés par le jeu de la cible (réponse à requestSpots)
RegisterNetEvent('noirx:server:mercSpots', function(id, nonce, spots)
    local src = source
    local c = Contracts[math.tointeger(tonumber(id)) or -1]
    if not c or c.status ~= 'pending' or not c.spotReq or c.spotReq.nonce ~= nonce or c.targetSrc ~= src then return end
    local req = c.spotReq
    c.spotReq = nil
    local tc = GetEntityCoords(GetPlayerPed(src))
    local dmin, dmax = cfg().spawnDistance[1], cfg().spawnDistance[2]
    local valid = {}
    if type(spots) == 'table' then
        for i = 1, math.min(#spots, req.groups) do
            local s = spots[i]
            local x, y, z = tonumber(type(s) == 'table' and s.x), tonumber(type(s) == 'table' and s.y), tonumber(type(s) == 'table' and s.z)
            if x and y and z then
                local d = #(vector3(x, y, z) - tc)
                if d >= dmin * 0.5 and d <= dmax + 60.0 and math.abs(z - tc.z) < 80.0 then
                    valid[#valid + 1] = { x = x + 0.0, y = y + 0.0, z = z + 0.0, h = (tonumber(s.h) or 0.0) + 0.0 }
                end
            end
        end
    end
    if #valid == 0 then c.retryAt = now() + 10 return end
    if DB.Execute('UPDATE noirx_merc_contracts SET status = ? WHERE id = ? AND status = ?', { 'deploying', c.id, 'pending' }) ~= 1 then return end
    c.status = 'deploying'
    c.waitReason = nil
    if not spawnTeam(c, valid, src) then
        -- Rien n'a pu être créé : retour en attente, nouvel essai plus tard.
        DB.Execute('UPDATE noirx_merc_contracts SET status = ? WHERE id = ?', { 'pending', c.id })
        c.status, c.retryAt = 'pending', now() + 15
        return
    end
    Audit.Log(0, 'mercs.deploy', { contract = c.id, peds = #c.peds, vehicles = #c.vehs })
    pushBuyer(c, 'Mercenaires', ('Équipe déployée (%d). Elle cherche la cible.'):format(#c.peds))
end)

-- ─── Boucle serveur ─────────────────────────────────────────────

local function resolveTarget(c)
    local s = c.targetSrc
    if s and GetPlayerName(s) and Players.CharOf(s) == c.target then return s end
    s = Players.SrcOf(c.target)
    c.targetSrc = s
    return s
end

local function isDead(ped)
    if GetEntityHealth(ped) <= 0 then return true end
    local ok, cause = pcall(GetPedCauseOfDeath, ped)
    return ok and cause ~= nil and cause ~= 0
end

local function requeue(c, t)
    for _, veh in ipairs(c.vehs or {}) do if DoesEntityExist(veh) then DeleteEntity(veh) end end
    for _, ped in ipairs(c.peds or {}) do if DoesEntityExist(ped) then DeleteEntity(ped) end end
    c.peds, c.vehs, c.dead = {}, {}, {}
    c.status, c.deployAt, c.retryAt = 'pending', t + 20, nil
    DB.Execute('UPDATE noirx_merc_contracts SET status = ?, deploy_at = ? WHERE id = ?', { 'pending', c.deployAt, c.id })
end

local function tickContract(c, t)
    local mc = cfg()
    local tsrc = resolveTarget(c)
    if not tsrc then
        if t >= (c.graceUntil or 0) then Mercs.Finish(c, 'target_left') end
        return
    end
    for _, ped in ipairs(c.peds or {}) do
        local st = DoesEntityExist(ped) and Entity(ped).state.nxMerc
        if type(st) == 'table' and st.t ~= tsrc then st.t = tsrc Entity(ped).state:set('nxMerc', st, true) end
    end

    if c.status == 'pending' then
        if t >= c.expiresAt then return Mercs.Finish(c, 'expired') end
        if c.spotReq and gt() - c.spotReq.at > 8000 then c.spotReq, c.retryAt = nil, t + 10 end
        if t >= c.deployAt and not c.spotReq and (not c.retryAt or t >= c.retryAt) then
            if GetPlayerRoutingBucket(tsrc) ~= 0 or isDown(tsrc) then
                c.waitReason, c.retryAt = 'unreachable', t + 15
            else
                requestSpots(c, tsrc)
            end
        end
        return
    end

    -- deploying / engaged
    local tped = GetPlayerPed(tsrc)
    local tc = GetEntityCoords(tped)
    local alive, nearest = 0, math.huge
    for _, ped in ipairs(c.peds) do
        if DoesEntityExist(ped) and not c.dead[ped] then
            if isDead(ped) then
                c.dead[ped] = true
            else
                alive = alive + 1
                local d = #(GetEntityCoords(ped) - tc)
                if d < nearest then nearest = d end
            end
        end
    end
    if alive == 0 then
        if next(c.dead) then return Mercs.Finish(c, 'failed') end
        if t >= c.expiresAt then return Mercs.Finish(c, 'expired') end
        return requeue(c, t)   -- PNJ supprimés par le jeu (plus personne autour) : nouvel envoi
    end
    if not c.lastPos or t - c.lastPos >= 3 then
        c.lastPos = t
        GlobalState[('nxm:%d'):format(c.id)] = { x = tc.x, y = tc.y, z = tc.z }
    end
    if c.lastAlive ~= alive then c.lastAlive = alive pushBuyer(c) end

    if c.status == 'deploying' then
        if t >= c.expiresAt then return Mercs.Finish(c, 'expired') end
        if nearest <= mc.engageDistance then
            c.status, c.engagedAt = 'engaged', t
            DB.Execute('UPDATE noirx_merc_contracts SET status = ?, engaged_at = ? WHERE id = ?', { 'engaged', t, c.id })
            Audit.Log(0, 'mercs.engaged', { contract = c.id })
            pushBuyer(c, 'Mercenaires', 'Contact établi avec la cible.')
            if mc.policeAlert and GetResourceState('elyzea_police') == 'started' then
                pcall(function()
                    exports.elyzea_police:SendAlert('shots', { x = tc.x, y = tc.y, z = tc.z }, 'Coups de feu',
                        'Fusillade signalée : plusieurs individus armés.', nil, {})
                end)
            end
        end
        return
    end

    -- engaged
    if isDown(tsrc) then return Mercs.Finish(c, 'success') end
    if t >= c.engagedAt + mc.engageSeconds then return Mercs.Finish(c, 'timeout') end
    if not c.lastTask or t - c.lastTask >= 6 then
        c.lastTask = t
        for _, ped in ipairs(c.peds) do
            if DoesEntityExist(ped) and not c.dead[ped] and GetVehiclePedIsIn(ped, false) == 0 then
                pcall(TaskCombatPed, ped, tped, 0, 16)
            end
        end
    end
end

function Mercs.Tick()
    local t = now()
    for _, c in pairs(Contracts) do
        local ok, err = pcall(tickContract, c, t)
        if not ok then NoirX.Error(('Mercenaires #%s : %s'):format(tostring(c.id), tostring(err))) end
    end
    for id, l in pairs(Leaving) do
        if t >= l.at then
            for _, e in ipairs(l.ents) do if DoesEntityExist(e) then DeleteEntity(e) end end
            Leaving[id] = nil
        end
    end
    for charId, q in pairs(Quotes) do
        if q.exp < t then Quotes[charId] = nil end
    end
end

-- ─── RPC ────────────────────────────────────────────────────────

local function rules()
    local tiers = {}
    for _, t in ipairs(cfg().tiers) do tiers[#tiers + 1] = { id = t.id, label = t.label, size = t.size, price = t.price } end
    return {
        tiers = tiers, currency = cfg().currency, symbol = sym(),
        validity = cfg().validityMinutes * 60, deployDelay = cfg().deployDelaySeconds, engageSeconds = cfg().engageSeconds,
    }
end

local function historyOf(charId)
    local out = {}
    local rows = DB.Query([[SELECT id, target_name, tier, size, price, currency, status, refund, created_at, finished_at
        FROM noirx_merc_contracts WHERE buyer = ? AND status NOT IN ('pending', 'deploying', 'engaged') ORDER BY id DESC LIMIT 15]], { charId })
    for _, r in ipairs(rows) do
        out[#out + 1] = {
            id = tonumber(r.id), targetName = r.target_name, size = tonumber(r.size), price = tonumber(r.price),
            label = (tierById(r.tier) or {}).label or r.tier, currency = r.currency, status = r.status,
            refund = tonumber(r.refund) or 0, at = tonumber(r.finished_at) or tonumber(r.created_at),
        }
    end
    return out
end

Rpc.Register('mercs.state', { app = 'mercs', rate = { 10, 5 } }, function(src, ctx)
    local mine = {}
    for _, c in pairs(Contracts) do
        if c.buyer == ctx.charId then mine[#mine + 1] = view(c) end
    end
    return { rules = rules(), active = mine, cooldown = buyerCooldown(ctx.charId), history = historyOf(ctx.charId) }
end)

Rpc.Register('mercs.quote', { app = 'mercs', rate = { 5, 10 } }, function(src, ctx, args)
    local tier = tierById(tostring(args.tier or ''))
    if not tier then return Rpc.Fail('bad_tier', 'Formule inconnue.') end
    if type(args.target) ~= 'string' or #args.target > 60 then return Rpc.Fail('bad_target', 'Nom invalide.') end
    local tsrc, tchar, tname = findTarget(args.target)
    if not tsrc then
        Audit.Log(src, 'mercs.quote_miss', {})
        return Rpc.Fail('not_found', 'Aucune cible localisable sous ce nom (prénom et nom exacts, personne en ville).')
    end
    local fail = checkOrder(src, ctx.charId, tsrc, tchar, tier)
    if fail then return fail end
    local q = { tier = tier.id, target = tchar, targetName = tname, price = tier.price, exp = now() + cfg().quoteSeconds,
        id = ('%d%d'):format(now(), math.random(100, 999)) }
    Quotes[ctx.charId] = q
    return {
        quote = q.id, targetName = tname, tier = tier.id, label = tier.label, size = tier.size, price = tier.price,
        currency = cfg().currency, validity = cfg().validityMinutes * 60, deployDelay = cfg().deployDelaySeconds,
        quoteExpires = cfg().quoteSeconds,
    }
end)

Rpc.Register('mercs.order', { app = 'mercs', rate = { 3, 10 } }, function(src, ctx, args)
    local q = Quotes[ctx.charId]
    if not q or q.id ~= tostring(args.quote or '') or q.exp < now() then
        return Rpc.Fail('quote', 'Devis expiré. Redemande un devis.')
    end
    local ok, result = Locks.Run('money:' .. ctx.charId, function()
        if Quotes[ctx.charId] ~= q then return Rpc.Fail('quote', 'Devis déjà utilisé.') end
        Quotes[ctx.charId] = nil
        local tier = tierById(q.tier)
        local tsrc = Players.SrcOf(q.target)
        if not tsrc then return Rpc.Fail('not_found', 'La cible a quitté la ville.') end
        local fail = checkOrder(src, ctx.charId, tsrc, q.target, tier)
        if fail then return fail end
        local cur = cfg().currency
        if not Wallet.Charge(src, cur, q.price, 'mercs') then
            return Rpc.Fail('funds', ('Fonds insuffisants (%s %s).'):format(money(q.price), cur == 'dirty' and 'sales' or 'propres'))
        end
        local t = now()
        local c = {
            buyer = ctx.charId, buyerName = Identity.GetCharName(src), target = q.target, targetName = q.targetName,
            targetSrc = tsrc, tier = tier.id, size = tier.size, price = q.price, currency = cur, status = 'pending',
            createdAt = t, deployAt = t + cfg().deployDelaySeconds, expiresAt = t + cfg().validityMinutes * 60,
            peds = {}, vehs = {}, dead = {},
        }
        c.id = DB.Insert([[INSERT INTO noirx_merc_contracts (buyer, buyer_name, target, target_name, tier, size, price, currency, status, created_at, deploy_at, expires_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
            { c.buyer, c.buyerName, c.target, c.targetName, c.tier, c.size, c.price, cur, 'pending', t, c.deployAt, c.expiresAt })
        if not c.id then
            if not Wallet.Credit(src, cur, q.price, 'mercs_refund') then
                NoirX.Error(('Remboursement mercenaires impossible pour %s (%d). À traiter manuellement.'):format(ctx.charId, q.price))
            end
            return Rpc.Fail('internal', 'Le réseau a refusé l\'opération.')
        end
        c.id = math.tointeger(tonumber(c.id)) or c.id
        Contracts[c.id] = c
        Audit.Log(src, 'mercs.order', { contract = c.id, target = c.target, tier = c.tier, price = c.price })
        return { ok = true, contract = view(c) }
    end)
    if not ok then return Rpc.Fail('busy', 'Transaction en cours.') end
    if result.ok then Push.ToSrc(src, 'wallet:changed', {}) end
    return result
end)

-- ─── Administration ─────────────────────────────────────────────

function Mercs.AdminList()
    local active = {}
    for _, c in pairs(Contracts) do
        local v = view(c)
        v.buyer, v.buyerName, v.target = c.buyer, c.buyerName, c.target
        active[#active + 1] = v
    end
    table.sort(active, function(a, b) return a.id > b.id end)
    local recent = DB.Query([[SELECT id, buyer, buyer_name, target, target_name, tier, size, price, currency, status, refund, note, created_at, finished_at
        FROM noirx_merc_contracts WHERE status NOT IN ('pending', 'deploying', 'engaged') ORDER BY id DESC LIMIT 30]], {})
    return active, recent
end

function Mercs.AdminCancel(id, refund, actor)
    local c = Contracts[math.tointeger(tonumber(id)) or -1]
    if not c then return false, 'not_running' end
    Mercs.Finish(c, 'cancelled', 'Annulé par ' .. tostring(actor or 'le staff'), refund and 100 or 0)
    return true, c.refund or 0
end

-- ─── Démarrage, redémarrage, arrêt ──────────────────────────────

function Mercs.Restore()
    local t = now()
    local rows = DB.Query([[SELECT id, buyer, buyer_name, target, target_name, tier, size, price, currency, status, created_at, deploy_at, expires_at
        FROM noirx_merc_contracts WHERE status IN ('pending', 'deploying', 'engaged')]], {})
    for _, r in ipairs(rows) do
        local id = math.tointeger(tonumber(r.id))
        local c = {
            id = id, buyer = r.buyer, buyerName = r.buyer_name, target = r.target, targetName = r.target_name,
            tier = r.tier, size = tonumber(r.size), price = tonumber(r.price), currency = r.currency, status = 'pending',
            createdAt = tonumber(r.created_at), deployAt = math.max(tonumber(r.deploy_at) or t, t + 30),
            expiresAt = tonumber(r.expires_at) or t, graceUntil = t + 120, peds = {}, vehs = {}, dead = {},
        }
        Contracts[id] = c
        if c.expiresAt <= t or not tierById(c.tier) then
            Mercs.Finish(c, 'expired', 'Redémarrage du serveur')
        elseif r.status ~= 'pending' then
            -- Les PNJ n'existent plus après un redémarrage : l'équipe repart.
            DB.Execute('UPDATE noirx_merc_contracts SET status = ?, deploy_at = ? WHERE id = ?', { 'pending', c.deployAt, id })
        end
    end
    if #rows > 0 then NoirX.Debug(('%d contrat(s) de mercenaires restauré(s)'):format(#rows)) end
end

Boot.Register('mercs', function()
    Mercs.Restore()
    CreateThread(function()
        while true do
            Wait(1000)
            local ok, err = pcall(Mercs.Tick)
            if not ok then NoirX.Error('Mercs.Tick :', tostring(err)) end
        end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, c in pairs(Contracts) do
        for _, e in ipairs(c.peds or {}) do if DoesEntityExist(e) then DeleteEntity(e) end end
        for _, e in ipairs(c.vehs or {}) do if DoesEntityExist(e) then DeleteEntity(e) end end
        GlobalState[('nxm:%d'):format(c.id)] = nil
    end
    for _, l in pairs(Leaving) do
        for _, e in ipairs(l.ents) do if DoesEntityExist(e) then DeleteEntity(e) end end
    end
end)
