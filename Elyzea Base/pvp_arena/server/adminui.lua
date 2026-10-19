-- =========================================================
--  PVP ARENA - pont avec admin_menu (onglet ⚔️ Arène PvP, permission « pvp_manage »)
--  AdminData(src) : état complet (parties, arènes, réglages, historique, argent en jeu)
--  AdminAction(src, nom, données) : chaque action est revalidée ici.
-- =========================================================
local Lobbies, byPlayer = Arena.lobbies, Arena.byPlayer

-- Historique et argent : lus en base par un fil (jamais pendant l'appel du menu)
local cache = { at = 0, history = {}, money = {}, pending = { n = 0, amount = 0 } }
local function refresh()
    CreateThread(function()
        local h = MySQL.query.await('SELECT `uid`, `arena`, `mode`, `wins`, `score_a`, `score_b`, `winner`, `status`, `stake_pot`, `bet_pot`, `created_at` FROM `pvp_matches` ORDER BY `created_at` DESC LIMIT 40') or {}
        for _, r in ipairs(h) do if type(r.created_at) == 'number' then r.created_at = math.floor(r.created_at / 1000) end end
        local m = MySQL.query.await('SELECT `kind`, `status`, COUNT(*) AS `n`, COALESCE(SUM(`amount`), 0) AS `amount`, COALESCE(SUM(`payout`), 0) AS `payout` FROM `pvp_ledger` GROUP BY `kind`, `status`') or {}
        local p = MySQL.single.await('SELECT COUNT(*) AS `n`, COALESCE(SUM(`amount`), 0) AS `amount` FROM `pvp_pending`') or {}
        cache = { at = os.time(), history = h, money = m, pending = { n = tonumber(p.n) or 0, amount = tonumber(p.amount) or 0 } }
    end)
end
CreateThread(function()
    while not Arena.ready do Wait(500) end
    refresh()
    while true do Wait(60000) refresh() end
end)

local function matchView(L)
    local members = {}
    for _, s in ipairs(L.order) do
        local m = L.members[s]
        if m then
            local st = L.match and L.match.stats[s]
            members[#members + 1] = { id = s, name = m.name, team = m.team, ready = m.ready, paid = m.stakePaid, host = s == L.host,
                alive = L.match and L.match.alive[s] == true or nil, kills = st and st.kills or 0, deaths = st and st.deaths or 0,
                weapon = L.match and L.match.picks[s] or nil }
        end
    end
    local bets, betA, betB = {}, 0, 0
    for _, b in pairs(L.bets) do
        if not b.pending then
            bets[#bets + 1] = { name = b.name, team = b.team, amount = b.amount }
            if b.team == 'A' then betA = betA + b.amount else betB = betB + b.amount end
        end
    end
    return { uid = L.uid, name = L.name, state = L.state, host = L.hostName, settings = { mode = L.settings.mode, wins = L.settings.wins, stake = L.settings.stake,
        arena = L.settings.arena, roundTime = L.settings.roundTime, friendlyFire = L.settings.friendlyFire },
        members = members, bets = bets, betA = betA, betB = betB, stakePot = L.stakePot or 0, bucket = L.bucket,
        round = L.match and L.match.round or 0, score = L.match and L.match.score or { A = 0, B = 0 } }
end

function AdminData(src)
    if not Arena.IsAdmin(src) then return { available = true, denied = true } end
    if not Arena.ready then return { available = false, loading = true } end
    if os.time() - cache.at > 60 then refresh() end
    local matches = {}
    for _, L in pairs(Lobbies) do matches[#matches + 1] = matchView(L) end
    table.sort(matches, function(a, b) return a.uid < b.uid end)
    local arenas = {}
    for _, id in ipairs(Arena.arenaOrder) do
        local a = Arena.arenas[id]
        local ok, why = Arena.ArenaValid(a)
        arenas[#arenas + 1] = { id = a.id, label = a.label, valid = ok, why = why, spawns = a.spawns, safe = a.safe, zone = a.zone, center = a.center, time = a.time, weather = a.weather }
    end
    local weapons = {}
    for _, c in ipairs(Config.WeaponCategories) do
        for _, w in ipairs(c.weapons) do weapons[#weapons + 1] = { name = w.name:upper(), label = w.label, cat = c.label } end
    end
    return { available = true, matches = matches, arenas = arenas, settings = Arena.CurrentSettings(), weapons = weapons,
        modes = Config.Modes, winsOptions = Config.WinsOptions, roundTimes = Config.RoundTimes,
        history = cache.history, money = cache.money, pending = cache.pending, statsAt = cache.at,
        npcFallback = Config.Npc.enabled, bucketBase = Config.BucketBase }
end
exports('AdminData', AdminData)

-- ---------------------------------------------------------------- actions
local A = {}
local function posOf(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = math.floor(c.x * 100) / 100, y = math.floor(c.y * 100) / 100, z = math.floor(c.z * 100) / 100, h = math.floor(GetEntityHeading(ped)) + 0.0 }
end
local function arenaOf(id) return Arena.arenas[tostring(id or ''):lower()] end
local function busyArena(id) for _, L in pairs(Lobbies) do if L.settings.arena == id and L.match then return true end end return false end

A.settings_save = function(src, d) local ok, err = Arena.SaveSettings(d.settings) return ok, ok and 'Réglages de l\'arène enregistrés (appliqués tout de suite).' or err end
A.settings_reset = function() Arena.ResetSettings() return true, 'Réglages remis à ceux de config.lua.' end

A.match_cancel = function(src, d)
    local L = Lobbies[tostring(d.uid or '')]
    if not L then return false, 'Partie introuvable.' end
    Arena.Cancel(L, 'annulée par le staff')
    Arena.Log(('Partie %s annulée depuis le menu par %s.'):format(L.uid, GetPlayerName(src) or src))
    return true, ('Partie %s annulée : joueurs renvoyés au RP, mises et paris remboursés.'):format(L.uid)
end

A.player_kick = function(src, d)
    local t = tonumber(d.id)
    if not t or not GetPlayerName(t) then return false, 'Joueur introuvable.' end
    if byPlayer[t] then
        local L = Lobbies[byPlayer[t]]
        if L and L.state == 'LOBBY' then Arena.LeaveLobby(t, 'sorti par le staff') else Arena.LeaveMatch(t, 'sorti par le staff') end
    else
        Arena.RestoreFromDb(t)
        Player(t).state:set('pvpArena', false, true)
        local b = GetPlayerRoutingBucket(t)
        if b > Config.BucketBase and b <= Config.BucketBase + 100 then SetPlayerRoutingBucket(t, 0) end
        TriggerClientEvent('pvp_arena:forceClean', t)
    end
    Arena.Notify(t, Arena.T('kicked'), 'info')
    Arena.Log(('%s sorti de l\'arène par %s (menu).'):format(GetPlayerName(t), GetPlayerName(src) or src))
    return true, ('%s est sorti de l\'arène et renvoyé au RP.'):format(GetPlayerName(t))
end

A.arena_new = function(src, d)
    local id = tostring(d.id or ''):lower():gsub('[^%w_]', ''):sub(1, 30)
    if id == '' then return false, 'Identifiant obligatoire (lettres, chiffres, _).' end
    if arenaOf(id) then return false, 'Cet identifiant existe déjà.' end
    local p = posOf(src)
    if not p then return false, 'Position introuvable.' end
    local raw = LoadResourceFile(GetCurrentResourceName(), 'data/arenas.json')
    if not raw or raw == '' or raw == '[]' then Arena.arenas, Arena.arenaOrder = {}, {} end   -- la 1re arène posée remplace les exemples
    local label = tostring(d.label or ''):gsub('[%c<>]', ''):sub(1, 40)
    Arena.arenas[id] = { id = id, label = label ~= '' and label or id, spawns = { A = {}, B = {} }, safe = {},
        zone = { points = {}, minZ = p.z - 5.0, maxZ = p.z + 30.0 }, center = p }
    Arena.arenaOrder[#Arena.arenaOrder + 1] = id
    Arena.SaveArenas()
    return true, ('Arène « %s » créée à ta position. Ajoute maintenant les apparitions A et B et les coins de la zone.'):format(Arena.arenas[id].label)
end

A.arena_edit = function(src, d)
    local a = arenaOf(d.id)
    if not a then return false, 'Arène introuvable.' end
    local label = tostring(d.label or ''):gsub('[%c<>]', ''):sub(1, 40)
    if label ~= '' then a.label = label end
    if tonumber(d.minZ) and tonumber(d.maxZ) then
        local mn, mx = tonumber(d.minZ), tonumber(d.maxZ)
        if not mn or not mx or mx <= mn then return false, 'Hauteur : le maximum doit être au-dessus du minimum.' end
        a.zone.minZ, a.zone.maxZ = mn, mx
    end
    local t = tonumber(d.time)
    a.time = (t and t >= 0 and t <= 23) and math.floor(t) or nil
    local w = tostring(d.weather or ''):upper():gsub('[^%u_]', '')
    a.weather = w ~= '' and w or nil
    Arena.SaveArenas()
    return true, 'Arène enregistrée.'
end

A.arena_add = function(src, d)
    local a = arenaOf(d.id)
    if not a then return false, 'Arène introuvable.' end
    local p = posOf(src)
    if not p then return false, 'Position introuvable.' end
    local what = tostring(d.what or '')
    if what == 'A' or what == 'B' then
        if #a.spawns[what] >= 20 then return false, '20 points maximum par équipe.' end
        a.spawns[what][#a.spawns[what] + 1] = p
    elseif what == 'corner' then
        if #a.zone.points >= 60 then return false, '60 coins maximum.' end
        a.zone.points[#a.zone.points + 1] = { x = p.x, y = p.y }
    elseif what == 'safe' then a.safe[#a.safe + 1] = p
    elseif what == 'center' then a.center = p
    elseif what == 'floor' then a.zone.minZ = p.z - 2.0
    elseif what == 'ceiling' then a.zone.maxZ = p.z + 2.0
    else return false, 'Point inconnu.' end
    Arena.SaveArenas()
    local names = { A = 'Apparition ' .. Config.Teams.A.name, B = 'Apparition ' .. Config.Teams.B.name, corner = 'Coin de zone', safe = 'Point sûr', center = 'Centre', floor = 'Sol (hauteur minimum)', ceiling = 'Plafond (hauteur maximum)' }
    return true, ('%s enregistré à ta position.'):format(names[what])
end

A.arena_point_delete = function(src, d)
    local a = arenaOf(d.id)
    if not a then return false, 'Arène introuvable.' end
    local i = tonumber(d.index)
    local list = (d.what == 'A' or d.what == 'B') and a.spawns[d.what] or d.what == 'corner' and a.zone.points or d.what == 'safe' and a.safe or nil
    if not list or not i or not list[i] then return false, 'Point introuvable.' end
    table.remove(list, i)
    Arena.SaveArenas()
    return true, 'Point supprimé.'
end

A.arena_reset = function(src, d)
    local a = arenaOf(d.id)
    if not a then return false, 'Arène introuvable.' end
    if d.what == 'A' or d.what == 'B' then a.spawns[d.what] = {} elseif d.what == 'corner' then a.zone.points = {} elseif d.what == 'safe' then a.safe = {} else return false, 'Point inconnu.' end
    Arena.SaveArenas()
    return true, 'Points effacés.'
end

A.arena_delete = function(src, d)
    local a = arenaOf(d.id)
    if not a then return false, 'Arène introuvable.' end
    if busyArena(a.id) then return false, 'Une partie se joue dans cette arène.' end
    Arena.arenas[a.id] = nil
    for i, id in ipairs(Arena.arenaOrder) do if id == a.id then table.remove(Arena.arenaOrder, i) break end end
    Arena.SaveArenas()
    return true, ('Arène « %s » supprimée.'):format(a.label)
end

A.arena_show = function(src, d)
    local a = arenaOf(d.id)
    if not a then return false, 'Arène introuvable.' end
    TriggerClientEvent('pvp_arena:showArena', src, a, 60)
    return true, 'Zone, apparitions et points sûrs affichés 60 s autour de l\'arène.'
end

A.arena_tp = function(src, d)
    local a = arenaOf(d.id)
    if not a then return false, 'Arène introuvable.' end
    if byPlayer[src] then return false, 'Pas pendant une partie.' end
    local p
    if d.what == 'A' or d.what == 'B' then p = a.spawns[d.what][tonumber(d.index) or 1]
    elseif d.what == 'safe' then p = a.safe[tonumber(d.index) or 1]
    else p = a.center end
    if not p then return false, 'Point introuvable.' end
    local ped = GetPlayerPed(src)
    SetEntityCoords(ped, p.x, p.y, p.z, false, false, false, false)
    if p.h then SetEntityHeading(ped, p.h) end
    return true, 'Téléporté.'
end

local function num(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    return v
end
local function outsideCount(a, list)
    local n = 0
    for _, s in ipairs(list) do if not Rules.InZone(a.zone, s.x, s.y, s.z) then n = n + 1 end end
    return n
end

-- Zone dessinée en jeu (admin_menu › Arène PvP › « Dessiner la zone ») : coins dans l'ordre + plancher / plafond
A.arena_zone = function(src, d)
    local a = arenaOf(d.id)
    if not a then return false, 'Arène introuvable.' end
    if busyArena(a.id) then return false, 'Une partie se joue dans cette arène : attends la fin pour changer sa zone.' end
    local pts = {}
    for _, p in ipairs(type(d.points) == 'table' and d.points or {}) do
        local x, y = num(type(p) == 'table' and p.x), num(type(p) == 'table' and p.y)
        if not x or not y then return false, 'Coin invalide.' end
        pts[#pts + 1] = { x = math.floor(x * 100) / 100, y = math.floor(y * 100) / 100 }
    end
    local ok, why = Rules.CheckPolygon(pts, Config.Zone.maxSize)
    if not ok then return false, 'Zone refusée : ' .. why .. '.' end
    local mn, mx = num(d.minZ), num(d.maxZ)
    if not mn or not mx or mx - mn < 2.0 then return false, 'Hauteur de zone invalide (2 m minimum entre le sol et le plafond).' end
    if mx - mn > 600 or math.abs(mn) > 3000 then return false, 'Hauteur de zone invalide.' end
    a.zone = { points = pts, minZ = math.floor(mn * 10) / 10, maxZ = math.floor(mx * 10) / 10 }
    -- le centre (téléportation staff, « Aller au centre ») suit la zone s'il n'est pas dedans
    if not a.center or not Rules.InZone(a.zone, a.center.x, a.center.y, a.center.z) then
        local cx, cy = 0, 0
        for _, p in ipairs(pts) do cx, cy = cx + p.x, cy + p.y end
        cx, cy = cx / #pts, cy / #pts
        if Rules.InPoly(pts, cx, cy) then
            local lo = a.zone.minZ
            for _, p in ipairs(type(d.points) == 'table' and d.points or {}) do if num(p.z) then lo = math.max(lo, num(p.z)) break end end
            a.center = { x = cx, y = cy, z = math.min(lo + 1.0, a.zone.maxZ - 0.5) }
        end
    end
    Arena.SaveArenas()
    local out = outsideCount(a, a.spawns.A) + outsideCount(a, a.spawns.B) + outsideCount(a, a.safe)
    return true, ('Zone de « %s » enregistrée : %d coins, hauteur %.1f → %.1f.%s'):format(a.label, #pts, a.zone.minZ, a.zone.maxZ,
        out > 0 and (' ⚠ %d point(s) d\'apparition / sûrs sont hors de la nouvelle zone : replace-les.'):format(out) or '')
end

-- Apparitions d'une équipe posées en jeu (admin_menu › « Placer les apparitions ») : remplace la liste
A.arena_spawns = function(src, d)
    local a = arenaOf(d.id)
    if not a then return false, 'Arène introuvable.' end
    local team = d.team == 'A' and 'A' or d.team == 'B' and 'B' or nil
    if not team then return false, 'Équipe inconnue.' end
    if busyArena(a.id) then return false, 'Une partie se joue dans cette arène : attends la fin.' end
    local list = {}
    for _, p in ipairs(type(d.points) == 'table' and d.points or {}) do
        local x, y, z = num(type(p) == 'table' and p.x), num(type(p) == 'table' and p.y), num(type(p) == 'table' and p.z)
        if not x or not y or not z or math.abs(x) > 12000 or math.abs(y) > 12000 then return false, 'Point d\'apparition invalide.' end
        local h = (num(p.h) or 0.0) % 360
        list[#list + 1] = { x = math.floor(x * 100) / 100, y = math.floor(y * 100) / 100, z = math.floor(z * 100) / 100, h = math.floor(h) + 0.0 }
    end
    if #list == 0 then return false, 'Pose au moins un point d\'apparition.' end
    if #list > 20 then return false, '20 points maximum par équipe.' end
    if #a.zone.points >= 3 then
        for i, s in ipairs(list) do
            if not Rules.InZone(a.zone, s.x, s.y, s.z) then return false, ('Le point n°%d est hors de la zone de combat : place-le à l\'intérieur.'):format(i) end
        end
    end
    a.spawns[team] = list
    Arena.SaveArenas()
    return true, ('%d apparition(s) de l\'équipe %s enregistrée(s) pour « %s ».'):format(#list, Config.Teams[team].name, a.label)
end

A.stats_refresh = function() refresh() return true, 'Historique actualisé (quelques secondes).' end

function AdminAction(src, name, data)
    if not Arena.IsAdmin(src) then return false, 'Permission « pvp_manage » refusée.' end
    if not Arena.ready then return false, 'L\'arène démarre encore, réessaie dans quelques secondes.' end
    local fn = A[tostring(name)]
    if not fn then return false, 'Action inconnue.' end
    local ok, success, msg = pcall(fn, src, type(data) == 'table' and data or {})
    if not ok then
        print(('^1[pvp_arena] admin %s : %s^0'):format(tostring(name), tostring(success)))
        return false, 'Erreur interne (voir la console du serveur).'
    end
    if success and name ~= 'arena_show' and name ~= 'arena_tp' and name ~= 'stats_refresh' then Arena.Log(('Menu admin (%s) : %s'):format(GetPlayerName(src) or src, tostring(msg))) end
    Arena.Touch(nil)
    return success, msg
end
exports('AdminAction', AdminAction)
