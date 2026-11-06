-- =====================================================================
--  ELYZEA LASERGAME - ADMINISTRATION (staff)
--  Toutes les actions passent par Bridge.IsAdmin (permission admin_menu « lasergame_manage »
--  ou ACE « elyzea_lasergame.admin »), sont validées strictement et journalisées.
-- =====================================================================
Admin = {}

local function guard(src)
    if not Bridge.IsAdmin(src) then
        Security.Suspicious(src, 'action staff sans permission')
        return false
    end
    return true
end

local function adminRPC(name, fn)
    RPC.Register('admin:' .. name, function(src, ...)
        if not guard(src) then return false, 'Permission refusée.' end
        return fn(src, ...)
    end)
end

local function log(src, msg, data)
    Logs.Add('admin', msg, data, src)
    Bridge.StaffLog(src, 'LaserGame', msg)
end

-- ---------------------------------------------------------------- vue d'ensemble
local function gamesView()
    local out = {}
    for _, g in pairs(Games.list) do
        local players = {}
        for _, s in ipairs(Games.PlayerList(g)) do
            local p = g.players[s]
            players[#players + 1] = { id = s, name = p.name, team = p.team, alive = p.alive, kills = p.kills }
        end
        local spect = 0
        for _ in pairs(g.spectators or {}) do spect = spect + 1 end
        local m = g.arena or Maps.Get(g.map)
        out[#out + 1] = { uid = g.uid, mode = g.mode, name = g.name, host = g.hostName, phase = g.phase, map = m and m.label or g.map, format = g.format,
            stake = g.stake, round = g.round, score = g.score, private = g.private, players = players, spectators = spect,
            createdAt = g.createdAt }
    end
    table.sort(out, function(a, b) return (a.createdAt or 0) > (b.createdAt or 0) end)
    return out
end
Admin.GamesView = gamesView

local function settingsView()
    local weapons = {}
    for _, w in ipairs(LG.Weapons) do
        weapons[#weapons + 1] = { id = w.id, label = w.label, cat = w.cat, damage = w.damage, range = w.range, rpm = w.rpm,
            spread = w.spread, mag = w.mag, reload = w.reload, disabled = w.disabled == true }
    end
    local formats = {}
    for _, f in ipairs(Config.PvP.formats) do formats[#formats + 1] = { id = f.id, label = f.label, enabled = not (Config.PvP.disabledFormats or {})[f.id] } end
    local ranks = {}
    for _, r in ipairs(LG.Ranks) do ranks[#ranks + 1] = { id = r.id, label = r.label, min = r.min } end
    return {
        pvp = { enabled = Config.PvP.enabled, requireFullTeams = Config.PvP.requireFullTeams, requireEqualTeams = Config.PvP.requireEqualTeams,
            oneHitElimination = Config.PvP.oneHitElimination, friendlyFire = Config.PvP.friendlyFire, shield = Config.PvP.shield,
            minRankedDuration = Config.PvP.minRankedDuration, lobbyIdleTimeout = Config.PvP.lobbyIdleTimeout,
            defaultRoundTime = Config.PvP.defaultRoundTime, defaultRounds = Config.PvP.defaultRounds },
        stake = { enabled = Config.Stake.enabled, min = Config.Stake.min, max = Config.Stake.max, step = Config.Stake.step, houseFeePct = Config.Stake.houseFeePct },
        formats = formats, weapons = weapons, arenas = Maps.AdminView(), ranks = ranks, teams = { A = Config.Teams.A.name, B = Config.Teams.B.name },
        adminMenu = GetResourceState('admin_menu') == 'started',
        npcs = Settings.Npcs(),
        framework = Bridge.Name(),
        categories = LG.WeaponCategories,
    }
end

adminRPC('open', function(src)
    return true, { settings = settingsView(), games = gamesView() }
end)

adminRPC('games', function(src) return true, gamesView() end)

-- ---------------------------------------------------------------- réglages
local function ensure(t, k) t[k] = t[k] or {} return t[k] end

adminRPC('set', function(src, section, payload, key)
    local d = Settings.data
    local S = Settings.SCHEMA
    payload = type(payload) == 'table' and payload or {}
    if section == 'pvp' then
        for k, v in pairs(Settings.Clean(S.pvp, payload)) do ensure(d, 'pvp')[k] = v end
    elseif section == 'stake' then
        local c = Settings.Clean(S.stake, payload)
        if c.min and c.max and c.max < c.min then return false, 'Le maximum doit être supérieur au minimum.' end
        for k, v in pairs(c) do ensure(d, 'stake')[k] = v end
    elseif section == 'format' then
        local f = tostring(key or '')
        local found = false
        for _, x in ipairs(Config.PvP.formats) do if x.id == f then found = true end end
        if not found then return false, 'Format inconnu.' end
        local df = ensure(ensure(d, 'pvp'), 'disabledFormats')
        df[f] = payload.enabled == false or nil
    elseif section == 'weapon' then
        local w = LGU.Weapon(tostring(key or ''))
        if not w then return false, 'Arme inconnue.' end
        local c = Settings.Clean(S.weapon, payload)
        local dw = ensure(ensure(d, 'weapons'), w.id)
        for k, v in pairs(c) do dw[k] = v end
    elseif section == 'rank' then
        local id = tostring(key or '')
        local found
        for i, r in ipairs(LG.Ranks) do if r.id == id then found = i end end
        if not found or found == 1 then return false, 'Rang inconnu (le premier rang commence toujours à 0).' end
        ensure(ensure(d, 'ranks'), id).min = LGU.Int(payload.min, 1, 100000, LG.Ranks[found].min)
    elseif section == 'reset' then
        local what = tostring(key or '')
        if what == 'all' then Settings.data = { npcs = d.npcs, npcRemoved = d.npcRemoved }
        elseif d[what] ~= nil then d[what] = nil
        else return false, 'Rien à réinitialiser.' end
    else
        return false, 'Section inconnue.'
    end
    Settings.Save()
    Ranking.ClearCache()
    log(src, ('réglage modifié : %s %s'):format(section, key and tostring(key) or ''), payload)
    return true, settingsView()
end)

-- ---------------------------------------------------------------- arènes (créées en jeu)
-- Même fonction que l'onglet LaserGame d'admin_menu (export AdminArena) : voir server/maps.lua › Maps.Action
function Admin.Arena(src, action, data)
    local ok, msg, view, id = Maps.Action(src, action, data)
    if ok and action ~= 'list' and action ~= 'tp' and action ~= 'show' then
        Settings.Publish()
        Lobby.PushList()
        log(src, ('arène %s : %s'):format(tostring(id or (type(data) == 'table' and data.id) or '?'), action))
    end
    return ok, msg, view, id
end

adminRPC('arena', function(src, action, data)
    local ok, msg, view = Admin.Arena(src, action, data)
    if not ok then return false, msg end
    return true, { message = msg, arenas = view or Maps.AdminView() }
end)

-- ---------------------------------------------------------------- PNJ
adminRPC('npc', function(src, action, data)
    data = type(data) == 'table' and data or {}
    local list = ensure(Settings.data, 'npcs')
    if action == 'add' then
        local ped = GetPlayerPed(src)
        local c = GetEntityCoords(ped)
        if #list >= 20 then return false, 'Maximum 20 PNJ ajoutés en jeu.' end
        local model = LGU.CleanText(data.model, 40)
        if model == '' or not model:match('^[%w_]+$') then model = 's_m_y_ammucity_01' end
        local n = { id = ('npc_%d'):format(os.time()), model = model, x = c.x, y = c.y, z = c.z - 1.0, h = GetEntityHeading(ped),
            scenario = 'WORLD_HUMAN_CLIPBOARD', distance = 2.2, label = LGU.CleanText(data.label, 40) ~= '' and LGU.CleanText(data.label, 40) or 'LaserGame ElyzeaFA',
            text = 'Ouvrir le LaserGame', blip = { enabled = data.blip ~= false, sprite = 432, color = 27, scale = 0.85, label = 'LaserGame ElyzeaFA' } }
        list[#list + 1] = n
        log(src, 'PNJ LaserGame ajouté', n)
    elseif action == 'remove' then
        local id = tostring(data.id or '')
        local removed = false
        for i, n in ipairs(list) do if n.id == id then table.remove(list, i) removed = true break end end
        if not removed then
            for _, n in ipairs(Config.Npcs) do
                if n.id == id then ensure(Settings.data, 'npcRemoved')[id] = true removed = true end
            end
        end
        if not removed then return false, 'PNJ introuvable.' end
        log(src, 'PNJ LaserGame retiré : ' .. id)
    elseif action == 'restore' then
        Settings.data.npcRemoved = nil
        log(src, 'PNJ de la configuration rétablis')
    else
        return false, 'Action inconnue.'
    end
    Settings.Save()
    return true, settingsView()
end)

-- ---------------------------------------------------------------- parties
adminRPC('game', function(src, uid, action, target)
    local g = Games.list[tostring(uid or '')]
    if not g then return false, 'Partie introuvable.' end
    if action == 'stop' then
        log(src, ('partie %s arrêtée'):format(g.uid))
        Pvp.Stop(g, 'arrêt staff')
    elseif action == 'kick' then
        target = tonumber(target)
        if not target or not (g.players[target] or (g.spectators or {})[target]) then return false, 'Joueur introuvable.' end
        log(src, ('joueur %d expulsé de la partie %s'):format(target, g.uid))
        Games.ForceLeave(target, 'expulsé par le staff')
        Games.Notify(target, 'Tu as été expulsé de la partie par le staff.', 'error')
    elseif action == 'spectate' then
        return true, 'spectate'
    else
        return false, 'Action inconnue.'
    end
    return true, gamesView()
end)

-- ---------------------------------------------------------------- joueurs
adminRPC('players.search', function(src, query)
    query = LGU.CleanText(query, 40)
    if #query < 2 then return false, 'Au moins 2 caractères.' end
    local like = '%' .. query:gsub('[%%_]', '') .. '%'
    local rows = MySQL.query.await([[SELECT `citizenid`, `firstname`, `lastname`, `points`, `wins`, `losses`, `matches`, `banned`
        FROM `lg_players` WHERE `citizenid` LIKE ? OR CONCAT(`firstname`, ' ', `lastname`) LIKE ? ORDER BY `points` DESC LIMIT 25]], { like, like }) or {}
    for _, r in ipairs(rows) do r.rank = LGU.RankFor(r.points).id end
    return true, rows
end)

adminRPC('players.get', function(src, cid)
    local p = DB.ProfileByCid(tostring(cid or ''))
    if not p then return false, 'Joueur introuvable.' end
    local view = Ranking.ProfileView({ cid = p.citizenid })
    view.citizenid = p.citizenid
    view.banUntil = type(p.ban_until) == 'number' and math.floor(p.ban_until / 1000) or nil
    view.online = Bridge.SourceByCid(p.citizenid)
    return true, { profile = view, history = Ranking.History(p.citizenid, 30) }
end)

adminRPC('players.set', function(src, cid, action, value, extra)
    cid = tostring(cid or '')
    local p = DB.ProfileByCid(cid)
    if not p then return false, 'Joueur introuvable.' end
    if action == 'points' then
        local v = LGU.Int(value, 0, 100000, p.points)
        MySQL.update.await('UPDATE `lg_players` SET `points` = ?, `peak_points` = GREATEST(`peak_points`, ?) WHERE `citizenid` = ?', { v, v, cid })
        log(src, ('points de %s : %d → %d'):format(cid, p.points, v))
    elseif action == 'rank' then
        local target
        for _, r in ipairs(LG.Ranks) do if r.id == value then target = r end end
        if not target then return false, 'Rang inconnu.' end
        MySQL.update.await('UPDATE `lg_players` SET `points` = ?, `peak_points` = GREATEST(`peak_points`, ?) WHERE `citizenid` = ?', { target.min, target.min, cid })
        log(src, ('rang de %s fixé à %s (%d points)'):format(cid, target.label, target.min))
    elseif action == 'reset' then
        if value == 'pvp' or value == 'all' or value == nil then
            MySQL.update.await('UPDATE `lg_players` SET `points` = ?, `peak_points` = ?, `wins` = 0, `losses` = 0, `draws` = 0, `kills` = 0, `deaths` = 0, `matches` = 0, `streak` = 0, `best_streak` = 0 WHERE `citizenid` = ?',
                { LG.Ranking.start, LG.Ranking.start, cid })
        end
        log(src, ('statistiques réinitialisées (%s) : %s'):format(tostring(value), cid))
    elseif action == 'exclude' then
        Players.Exclude(cid, true, LGU.CleanText(extra and extra.reason, 160), extra and extra.hours or 0)
        log(src, ('exclusion du LaserGame : %s (%s h)'):format(cid, tostring(extra and extra.hours or 'définitif')), extra)
    elseif action == 'unexclude' then
        Players.Exclude(cid, false)
        log(src, ('exclusion levée : %s'):format(cid))
    else
        return false, 'Action inconnue.'
    end
    Ranking.ClearCache()
    local view = Ranking.ProfileView({ cid = cid })
    view.citizenid = cid
    return true, view
end)

-- ---------------------------------------------------------------- statistiques et journaux
adminRPC('stats', function(src)
    local s = MySQL.single.await([[SELECT
        (SELECT COUNT(*) FROM `lg_matches` WHERE `mode` = 'pvp' AND `status` = 'finished') AS pvp,
        (SELECT COUNT(*) FROM `lg_players`) AS players,
        (SELECT CAST(COALESCE(SUM(`amount`), 0) AS SIGNED) FROM `lg_ledger` WHERE `status` IN ('paid', 'lost', 'refunded')) AS staked,
        (SELECT CAST(COALESCE(SUM(`amount`), 0) AS SIGNED) FROM `lg_ledger` WHERE `status` = 'held') AS held]]) or {}
    return true, s
end)

adminRPC('logs', function(src, category, page)
    page = LGU.Int(page, 1, 500, 1)
    local cats = { admin = 1, money = 1, pvp = 1, security = 1, error = 1 }
    local rows
    if cats[category] then
        rows = MySQL.query.await('SELECT `id`, `category`, `name`, `message`, `data`, `created_at` FROM `lg_logs` WHERE `category` = ? ORDER BY `id` DESC LIMIT 50 OFFSET ?', { category, (page - 1) * 50 })
    else
        rows = MySQL.query.await('SELECT `id`, `category`, `name`, `message`, `data`, `created_at` FROM `lg_logs` ORDER BY `id` DESC LIMIT 50 OFFSET ?', { (page - 1) * 50 })
    end
    for _, r in ipairs(rows or {}) do if type(r.created_at) == 'number' then r.created_at = math.floor(r.created_at / 1000) end end
    return true, rows or {}
end)

-- ---------------------------------------------------------------- commande
RegisterCommand(Config.AdminCommand, function(src)
    if src == 0 then return print('[elyzea_lasergame] commande réservée aux joueurs staff') end
    if not Bridge.IsAdmin(src) then return Games.Notify(src, 'Permission refusée.', 'error') end
    TriggerClientEvent('elyzea_lasergame:openAdmin', src)
end, false)

-- ---------------------------------------------------------------- admin_menu (onglet « LaserGame »)
-- Vue d'ensemble lue par admin_menu pour le staff qui a la permission « lasergame_manage ».
exports('AdminSummary', function()
    local s = MySQL.single.await([[SELECT (SELECT COUNT(*) FROM `lg_players`) AS players,
        (SELECT COUNT(*) FROM `lg_matches` WHERE `status` = 'finished') AS matches,
        (SELECT CAST(COALESCE(SUM(`amount`), 0) AS SIGNED) FROM `lg_ledger` WHERE `status` = 'held') AS held]]) or {}
    return { games = gamesView(), stats = s, framework = Bridge.Name(), command = Config.AdminCommand, arenas = Maps.AdminView(),
        teams = { A = Config.Teams.A.name, B = Config.Teams.B.name }, limits = Maps.LIMITS }
end)

-- Arrêt d'une partie depuis admin_menu (la permission est revérifiée ici)
exports('AdminStopGame', function(src, uid)
    if not Bridge.IsAdmin(src) then return false, 'Permission refusée.' end
    local g = Games.list[tostring(uid or '')]
    if not g then return false, 'Partie introuvable.' end
    log(src, ('partie %s arrêtée (admin_menu)'):format(g.uid))
    Pvp.Stop(g, 'arrêt staff')
    return true, 'Partie arrêtée.'
end)

-- Arènes depuis admin_menu (onglet LaserGame › Arènes ; outils de dessin de zone et d'apparitions)
exports('AdminArenas', function() return Maps.AdminView() end)
exports('AdminArena', function(src, action, data)
    src = tonumber(src) or 0
    if src ~= 0 and not Bridge.IsAdmin(src) then return false, 'Permission refusée.' end
    local ok, msg, view = Admin.Arena(src, tostring(action or ''), data)
    return ok, msg, view
end)
