-- =====================================================================
--  ELYZEA LASERGAME - RANGS, POINTS, CLASSEMENTS, HISTORIQUE
--  Points PVP : Elo par équipe (niveau des adversaires), performance individuelle, séries.
--  Anti-farm : parties privées non classées, durée minimale, même adversaires répétés
--  dans la fenêtre (24 h) → points réduits puis nuls, pénalité d'abandon.
-- =====================================================================
Ranking = {}

local cache = {}   -- [clé] = { t, rows, total }

local function avg(list)
    if #list == 0 then return LG.Ranking.start end
    local s = 0
    for _, v in ipairs(list) do s = s + v end
    return s / #list
end

-- Signature des adversaires (même équipe adverse = même signature)
local function oppSignature(cids)
    table.sort(cids)
    local s = table.concat(cids, ',')
    if #s > 64 then
        -- court hachage stable (FNV-1a 32 bits) pour les grosses équipes
        local h = 2166136261
        for i = 1, #s do h = ((h ~ s:byte(i)) * 16777619) % 4294967296 end
        s = ('h%08x%d'):format(h, #cids)
    end
    return s
end

-- Mise à jour après un match PVP
--   game : partie · players : liste { cid, name, team, result ('win'|'loss'|'draw'|'left'), kills, deaths }
--   ranked : bool · Renvoie [cid] = { delta, points, rank, rankUp, rankDown }
function Ranking.ApplyPvP(game, players, ranked)
    local out = {}
    local profiles, byTeam = {}, { A = {}, B = {} }
    for _, p in ipairs(players) do
        local prof = DB.ProfileByCid(p.cid) or { points = LG.Ranking.start, matches = 0, streak = 0, best_streak = 0, peak_points = LG.Ranking.start }
        profiles[p.cid] = prof
        if byTeam[p.team] then byTeam[p.team][#byTeam[p.team] + 1] = prof.points end
    end
    local teamAvg = { A = avg(byTeam.A), B = avg(byTeam.B) }
    local cidsOf = { A = {}, B = {} }
    for _, p in ipairs(players) do if cidsOf[p.team] then cidsOf[p.team][#cidsOf[p.team] + 1] = p.cid end end
    local sig = { A = oppSignature(LGU.Copy(cidsOf.B)), B = oppSignature(LGU.Copy(cidsOf.A)) }

    for _, p in ipairs(players) do
        local prof = profiles[p.cid]
        local opp = p.team == 'A' and 'B' or 'A'
        local delta = 0
        local result = p.result == 'left' and 'loss' or p.result
        if ranked then
            local rep = MySQL.scalar.await('SELECT COUNT(*) FROM `lg_match_players` WHERE `citizenid` = ? AND `opp_sig` = ? AND `mode` = \'pvp\' AND `created_at` > (NOW() - INTERVAL ? HOUR)',
                { p.cid, sig[p.team], LG.Ranking.repeatWindowHours }) or 0
            delta = LGU.RatingDelta({ rating = prof.points, teamRating = teamAvg[p.team], oppRating = teamAvg[opp], result = result,
                matches = prof.matches, kills = p.kills, deaths = p.deaths, streak = prof.streak, repeatCount = rep })
            if p.result == 'left' then delta = math.min(delta, 0) - LG.Ranking.leaverPenalty end
            if prof.points + delta < LG.Ranking.floor then delta = LG.Ranking.floor - prof.points end
        end
        local newPoints = prof.points + delta
        local streak = result == 'win' and (prof.streak + 1) or (result == 'draw' and prof.streak or 0)
        MySQL.update.await(([[UPDATE `lg_players` SET `points` = ?, `peak_points` = GREATEST(`peak_points`, ?),
            `wins` = `wins` + ?, `losses` = `losses` + ?, `draws` = `draws` + ?, `kills` = `kills` + ?, `deaths` = `deaths` + ?,
            `matches` = `matches` + 1, `streak` = ?, `best_streak` = GREATEST(`best_streak`, ?) WHERE `citizenid` = ?]]),
            { newPoints, newPoints, result == 'win' and 1 or 0, result == 'loss' and 1 or 0, result == 'draw' and 1 or 0,
              p.kills or 0, p.deaths or 0, streak, streak, p.cid })
        MySQL.insert.await('INSERT INTO `lg_match_players` (`match_uid`, `citizenid`, `mode`, `team`, `result`, `kills`, `deaths`, `points_delta`, `payout`, `opp_sig`) VALUES (?, ?, \'pvp\', ?, ?, ?, ?, ?, ?, ?)',
            { game.uid, p.cid, p.team, p.result, p.kills or 0, p.deaths or 0, delta, p.payout or 0, sig[p.team] })
        local oldRank, oldIdx = LGU.RankFor(prof.points)
        local newRank, newIdx = LGU.RankFor(newPoints)
        out[p.cid] = { delta = delta, points = newPoints, rank = newRank.id, rankLabel = newRank.label, oldRank = oldRank.id,
            rankUp = newIdx > oldIdx, rankDown = newIdx < oldIdx }
    end
    cache = {}
    return out
end

-- Mise à jour après une partie Zombie
--   players : liste { cid, name, kills, money, downs, revives }
function Ranking.ApplyZombie(game, players, round, duration)
    local solo = #players == 1
    local names, cids, kills, money = {}, {}, 0, 0
    for _, p in ipairs(players) do
        names[#names + 1] = p.name
        cids[#cids + 1] = p.cid
        kills, money = kills + (p.kills or 0), money + (p.money or 0)
        DB.ProfileByCid(p.cid)
        MySQL.update.await(([[UPDATE `lg_players` SET
            `zb_best_date` = IF(? > `zb_best_round`, NOW(), `zb_best_date`),
            `zb_best_round` = GREATEST(`zb_best_round`, ?),
            `zb_best_round_solo` = IF(?, GREATEST(`zb_best_round_solo`, ?), `zb_best_round_solo`),
            `zb_kills` = `zb_kills` + ?, `zb_money` = `zb_money` + ?, `zb_games` = `zb_games` + 1,
            `zb_downs` = `zb_downs` + ?, `zb_revives` = `zb_revives` + ? WHERE `citizenid` = ?]]),
            { round, round, solo and 1 or 0, round, p.kills or 0, p.money or 0, p.downs or 0, p.revives or 0, p.cid })
        MySQL.insert.await('INSERT INTO `lg_match_players` (`match_uid`, `citizenid`, `mode`, `team`, `result`, `kills`, `deaths`, `round`) VALUES (?, ?, \'zombie\', NULL, ?, ?, ?, ?)',
            { game.uid, p.cid, p.left and 'left' or 'loss', p.kills or 0, p.downs or 0, round })
    end
    MySQL.insert.await('INSERT INTO `lg_zombie_runs` (`match_uid`, `round`, `kills`, `money`, `players`, `names`, `cids`, `duration`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { game.uid, round, kills, money, #players, table.concat(names, ', '):sub(1, 255), table.concat(cids, ','):sub(1, 400), duration or 0 })
    cache = {}
end

-- ---------------------------------------------------------------- classements
local BOARDS = {
    pvp_points = { sql = 'SELECT `citizenid`, `firstname`, `lastname`, `points` AS v, `wins`, `losses`, `kills`, `deaths`, `matches` FROM `lg_players` WHERE `matches` > 0 AND `banned` = 0 ORDER BY `points` DESC, `wins` DESC',
                   count = 'SELECT COUNT(*) FROM `lg_players` WHERE `matches` > 0 AND `banned` = 0' },
    pvp_ratio  = { sql = 'SELECT `citizenid`, `firstname`, `lastname`, ROUND(`kills` / GREATEST(`deaths`, 1), 2) AS v, `kills`, `deaths`, `matches`, `points` FROM `lg_players` WHERE `matches` >= 10 AND `banned` = 0 ORDER BY v DESC, `kills` DESC',
                   count = 'SELECT COUNT(*) FROM `lg_players` WHERE `matches` >= 10 AND `banned` = 0' },
    pvp_wins   = { sql = 'SELECT `citizenid`, `firstname`, `lastname`, `wins` AS v, `losses`, `matches`, `points` FROM `lg_players` WHERE `wins` > 0 AND `banned` = 0 ORDER BY `wins` DESC, `points` DESC',
                   count = 'SELECT COUNT(*) FROM `lg_players` WHERE `wins` > 0 AND `banned` = 0' },
    pvp_streak = { sql = 'SELECT `citizenid`, `firstname`, `lastname`, `best_streak` AS v, `wins`, `points` FROM `lg_players` WHERE `best_streak` > 0 AND `banned` = 0 ORDER BY `best_streak` DESC, `wins` DESC',
                   count = 'SELECT COUNT(*) FROM `lg_players` WHERE `best_streak` > 0 AND `banned` = 0' },
    pvp_rank   = { sql = 'SELECT `citizenid`, `firstname`, `lastname`, `peak_points` AS v, `points`, `wins` FROM `lg_players` WHERE `matches` > 0 AND `banned` = 0 ORDER BY `peak_points` DESC',
                   count = 'SELECT COUNT(*) FROM `lg_players` WHERE `matches` > 0 AND `banned` = 0' },
    zb_round   = { sql = 'SELECT `citizenid`, `firstname`, `lastname`, `zb_best_round` AS v, `zb_kills`, `zb_money`, `zb_games`, `zb_best_date` FROM `lg_players` WHERE `zb_games` > 0 AND `banned` = 0 ORDER BY `zb_best_round` DESC, `zb_kills` DESC',
                   count = 'SELECT COUNT(*) FROM `lg_players` WHERE `zb_games` > 0 AND `banned` = 0' },
    zb_kills   = { sql = 'SELECT `citizenid`, `firstname`, `lastname`, `zb_kills` AS v, `zb_best_round`, `zb_money`, `zb_games`, `zb_best_date` FROM `lg_players` WHERE `zb_kills` > 0 AND `banned` = 0 ORDER BY `zb_kills` DESC',
                   count = 'SELECT COUNT(*) FROM `lg_players` WHERE `zb_kills` > 0 AND `banned` = 0' },
    zb_solo    = { sql = 'SELECT `citizenid`, `firstname`, `lastname`, `zb_best_round_solo` AS v, `zb_kills`, `zb_money`, `zb_games`, `zb_best_date` FROM `lg_players` WHERE `zb_best_round_solo` > 0 AND `banned` = 0 ORDER BY `zb_best_round_solo` DESC, `zb_kills` DESC',
                   count = 'SELECT COUNT(*) FROM `lg_players` WHERE `zb_best_round_solo` > 0 AND `banned` = 0' },
    zb_teams   = { sql = 'SELECT `match_uid` AS citizenid, `names`, `round` AS v, `kills`, `money`, `players`, `duration`, `created_at` FROM `lg_zombie_runs` WHERE `players` > 1 ORDER BY `round` DESC, `kills` DESC',
                   count = 'SELECT COUNT(*) FROM `lg_zombie_runs` WHERE `players` > 1' },
    zb_global  = { sql = 'SELECT `match_uid` AS citizenid, `names`, `round` AS v, `kills`, `money`, `players`, `duration`, `created_at` FROM `lg_zombie_runs` ORDER BY `round` DESC, `kills` DESC, `duration` ASC',
                   count = 'SELECT COUNT(*) FROM `lg_zombie_runs`' },
}
Ranking.Boards = BOARDS

function Ranking.Board(kind, page)
    local b = BOARDS[kind]
    if not b then return nil end
    page = LGU.Int(page, 1, 1000, 1)
    local size = Config.LeaderboardPageSize
    local key = kind .. ':' .. page
    local c = cache[key]
    if c and os.time() - c.t < Config.LeaderboardCacheSeconds then return c.data end
    local rows = MySQL.query.await(b.sql .. ' LIMIT ? OFFSET ?', { size, (page - 1) * size }) or {}
    local total = MySQL.scalar.await(b.count) or 0
    for i, r in ipairs(rows) do
        r.pos = (page - 1) * size + i
        -- MySQL renvoie les ratios (DECIMAL) en texte avec elyzea_core / oxmysql : valeur numérique pour l'affichage
        r.v = tonumber(r.v) or r.v
        if r.points or kind:sub(1, 3) == 'pvp' then
            local rk = LGU.RankFor(r.points or r.v)
            r.rank = rk.id
        end
        if r.zb_best_date and type(r.zb_best_date) == 'number' then r.zb_best_date = math.floor(r.zb_best_date / 1000) end
        if r.created_at and type(r.created_at) == 'number' then r.created_at = math.floor(r.created_at / 1000) end
        if kind ~= 'zb_teams' and kind ~= 'zb_global' then r.citizenid = nil end   -- l'identifiant n'est pas envoyé aux joueurs
    end
    local data = { kind = kind, page = page, pages = math.max(1, math.ceil(total / size)), total = total, rows = rows, t = os.time() }
    cache[key] = { t = os.time(), data = data }
    return data
end

-- Historique personnel (20 dernières parties)
function Ranking.History(cid, limit)
    local rows = MySQL.query.await([[SELECT mp.`match_uid`, mp.`mode`, mp.`team`, mp.`result`, mp.`kills`, mp.`deaths`, mp.`points_delta`,
        mp.`payout`, mp.`round`, mp.`created_at`, m.`map`, m.`format`, m.`score_a`, m.`score_b`, m.`name`
        FROM `lg_match_players` mp LEFT JOIN `lg_matches` m ON m.`uid` = mp.`match_uid`
        WHERE mp.`citizenid` = ? ORDER BY mp.`id` DESC LIMIT ?]], { cid, limit or 20 }) or {}
    for _, r in ipairs(rows) do if type(r.created_at) == 'number' then r.created_at = math.floor(r.created_at / 1000) end end
    return rows
end

-- Profil complet pour l'interface
function Ranking.ProfileView(id)
    local p = DB.Profile(id)
    local rank, idx, nxt, progress = LGU.RankFor(p.points)
    local position = MySQL.scalar.await('SELECT COUNT(*) + 1 FROM `lg_players` WHERE `points` > ? AND `matches` > 0 AND `banned` = 0', { p.points }) or 0
    return {
        firstname = p.firstname, lastname = p.lastname, points = p.points, peak = p.peak_points,
        rank = rank.id, rankLabel = rank.label, rankIndex = idx, next = nxt and { id = nxt.id, label = nxt.label, min = nxt.min } or nil,
        progress = progress, position = p.matches > 0 and position or nil,
        wins = p.wins, losses = p.losses, draws = p.draws, kills = p.kills, deaths = p.deaths, matches = p.matches,
        ratio = p.deaths > 0 and math.floor(p.kills / p.deaths * 100 + 0.5) / 100 or p.kills,
        streak = p.streak, bestStreak = p.best_streak,
        zbBestRound = p.zb_best_round, zbBestSolo = p.zb_best_round_solo, zbKills = p.zb_kills, zbMoney = p.zb_money,
        zbGames = p.zb_games, zbRevives = p.zb_revives,
        zbBestDate = type(p.zb_best_date) == 'number' and math.floor(p.zb_best_date / 1000) or p.zb_best_date,
        banned = p.banned == 1 or p.banned == true, banReason = p.ban_reason,
    }
end

function Ranking.ClearCache() cache = {} end
