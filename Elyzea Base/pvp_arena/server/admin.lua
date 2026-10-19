-- =========================================================
--  PVP ARENA - administration (permission Config.Permission d'admin_menu, ou console serveur)
--  Parties : lister, détails, annuler (rembourse), sortir un joueur, statistiques.
--  Arènes posées en jeu : créer, ajouter points d'apparition / coins / points sûrs, hauteur,
--  voir la zone, tester un point d'apparition. Enregistré dans data/arenas.json.
-- =========================================================
local T = Arena.T
local C = Config.Commands
local Lobbies, byPlayer = Arena.lobbies, Arena.byPlayer

local function reply(src, msg, kind)
    if src == 0 then print('[pvp_arena] ' .. msg) else Arena.Notify(src, msg, kind or 'info') TriggerClientEvent('chat:addMessage', src, { args = { 'Arène', msg } }) end
end

local function admin(name, fn)
    RegisterCommand(name, function(src, args)
        if not Arena.IsAdmin(src) then return reply(src, T('no_perm'), 'error') end
        local ok, err = pcall(fn, src, args)
        if not ok then print(('^1[pvp_arena] /%s : %s^0'):format(name, tostring(err))) reply(src, T('error'), 'error') end
    end, false)
end

local function findLobby(arg)
    if not arg then return nil end
    if Lobbies[arg] then return Lobbies[arg] end
    local n = tonumber(arg)
    if n and byPlayer[n] then return Lobbies[byPlayer[n]] end
end

admin(C.list, function(src)
    local n = 0
    for _, L in pairs(Lobbies) do
        n = n + 1
        local score = L.match and ('%d-%d, manche %d'):format(L.match.score.A, L.match.score.B, L.match.round) or '-'
        reply(src, ('%s · %s · %s · %d joueur(s) · %s · mise %d $ · paris %d $ · instance %s'):format(L.uid, L.name, L.state,
            Arena.MemberCount(L), score, L.settings.stake, L.betPot or 0, tostring(L.bucket or '-')))
    end
    if n == 0 then reply(src, 'Aucune partie en cours.') end
end)

admin(C.info, function(src, args)
    local L = findLobby(args[1])
    if not L then return reply(src, ('Usage : /%s <uid de partie | id joueur>'):format(C.info), 'error') end
    reply(src, ('%s · état %s · hôte %s · %s · première à %d · arène %s · mise %d $ · pot mises %d $ · paris %d $'):format(L.uid, L.state,
        L.hostName, L.settings.mode, L.settings.wins, L.settings.arena, L.settings.stake, L.stakePot or 0, L.betPot or 0))
    for _, s in ipairs(L.order) do
        local m = L.members[s]
        if m then
            local st = L.match and L.match.stats[s]
            reply(src, ('  [%d] %s · équipe %s · %s%s'):format(s, m.name, m.team, L.match and (L.match.alive[s] and 'vivant' or 'éliminé') or (m.ready and 'prêt' or 'pas prêt'),
                st and (' · %d/%d'):format(st.kills, st.deaths) or ''))
        end
    end
end)

admin(C.cancel, function(src, args)
    local L = findLobby(args[1])
    if not L then return reply(src, ('Usage : /%s <uid de partie | id joueur>'):format(C.cancel), 'error') end
    Arena.Cancel(L, 'annulée par le staff')
    Arena.Log(('Partie %s annulée par %s.'):format(L.uid, src == 0 and 'la console' or GetPlayerName(src)))
    reply(src, ('Partie %s annulée : joueurs renvoyés au RP, mises et paris remboursés.'):format(L.uid), 'success')
end)

-- Sortie forcée d'un joueur (même s'il n'est plus suivi par une partie : état RP sauvegardé rendu)
admin(C.kick, function(src, args)
    local target = tonumber(args[1])
    if not target or not GetPlayerName(target) then return reply(src, ('Usage : /%s <id joueur>'):format(C.kick), 'error') end
    if byPlayer[target] then
        local L = Lobbies[byPlayer[target]]
        if L and L.state == 'LOBBY' then Arena.LeaveLobby(target, 'sorti par le staff') else Arena.LeaveMatch(target, 'sorti par le staff') end
    else
        Arena.RestoreFromDb(target)
        Player(target).state:set('pvpArena', false, true)
        if GetPlayerRoutingBucket(target) >= Config.BucketBase and GetPlayerRoutingBucket(target) <= Config.BucketBase + Config.MaxLobbies then
            SetPlayerRoutingBucket(target, 0)
        end
        TriggerClientEvent('pvp_arena:forceClean', target)
    end
    Arena.Notify(target, T('kicked'), 'info')
    Arena.Log(('%s sorti de l\'arène par %s.'):format(GetPlayerName(target), src == 0 and 'la console' or GetPlayerName(src)))
    reply(src, ('%s est sorti de l\'arène.'):format(GetPlayerName(target)), 'success')
end)

admin(C.stats, function(src, args)
    local n = math.max(1, math.min(20, tonumber(args[1]) or 5))
    local rows = MySQL.query.await('SELECT `uid`, `arena`, `mode`, `score_a`, `score_b`, `winner`, `status`, `stake_pot`, `bet_pot`, `created_at` FROM `pvp_matches` ORDER BY `created_at` DESC LIMIT ?', { n }) or {}
    if #rows == 0 then return reply(src, 'Aucune partie enregistrée.') end
    for _, r in ipairs(rows) do
        reply(src, ('%s · %s · %s · %d-%d · gagnant %s · %s · mises %d $ · paris %d $'):format(r.uid, r.arena, r.mode, r.score_a, r.score_b,
            r.winner and Config.Teams[r.winner].name or '-', r.status, r.stake_pot, r.bet_pot))
    end
end)

-- ---------------------------------------------------------------- arènes posées en jeu
local function posOf(src)
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    return { x = math.floor(c.x * 100) / 100, y = math.floor(c.y * 100) / 100, z = math.floor(c.z * 100) / 100, h = math.floor(GetEntityHeading(ped)) + 0.0 }
end

local function arenaArg(src, id)
    local a = Arena.arenas[tostring(id or ''):lower()]
    if not a then reply(src, 'Arène introuvable (/' .. C.arenaList .. ').', 'error') end
    return a
end

admin(C.arenaList, function(src)
    for _, id in ipairs(Arena.arenaOrder) do
        local a = Arena.arenas[id]
        local ok, why = Arena.ArenaValid(a)
        reply(src, ('%s · %s · A:%d B:%d · coins %d · sûrs %d · hauteur %s→%s · %s'):format(a.id, a.label, #a.spawns.A, #a.spawns.B, #a.zone.points, #a.safe,
            tostring(a.zone.minZ or '-'), tostring(a.zone.maxZ or '-'), ok and 'prête' or ('incomplète : ' .. why)))
    end
end)

admin(C.arenaNew, function(src, args)
    if src == 0 then return reply(src, 'À faire en jeu.') end
    local id = tostring(args[1] or ''):lower():gsub('[^%w_]', ''):sub(1, 30)
    if id == '' then return reply(src, ('Usage : /%s <id> <nom affiché>'):format(C.arenaNew), 'error') end
    if Arena.arenas[id] then return reply(src, 'Cet identifiant existe déjà.', 'error') end
    local label = table.concat(args, ' ', 2)
    local p = posOf(src)
    -- la première arène créée en jeu remplace les exemples de la config
    if not LoadResourceFile(GetCurrentResourceName(), 'data/arenas.json') or LoadResourceFile(GetCurrentResourceName(), 'data/arenas.json') == '' or LoadResourceFile(GetCurrentResourceName(), 'data/arenas.json') == '[]' then
        Arena.arenas, Arena.arenaOrder = {}, {}
    end
    Arena.arenas[id] = { id = id, label = label ~= '' and label:sub(1, 40) or id, spawns = { A = {}, B = {} }, safe = {},
        zone = { points = {}, minZ = p.z - 5.0, maxZ = p.z + 30.0 }, center = p }
    Arena.arenaOrder[#Arena.arenaOrder + 1] = id
    Arena.SaveArenas()
    reply(src, ('Arène « %s » créée. Ajoute : /%s %s A (et B) pour les apparitions, /%s %s corner pour les coins de la zone.'):format(id, C.arenaAdd, id, C.arenaAdd, id), 'success')
end)

admin(C.arenaAdd, function(src, args)
    if src == 0 then return reply(src, 'À faire en jeu.') end
    local a = arenaArg(src, args[1])
    if not a then return end
    local what = tostring(args[2] or ''):lower()
    local p = posOf(src)
    if what == 'a' or what == 'b' then
        local t = what:upper()
        a.spawns[t][#a.spawns[t] + 1] = p
        reply(src, ('Point d\'apparition %s n°%d ajouté (ta position et ton orientation).'):format(t, #a.spawns[t]), 'success')
    elseif what == 'corner' then
        a.zone.points[#a.zone.points + 1] = { x = p.x, y = p.y }
        reply(src, ('Coin n°%d de la zone ajouté.'):format(#a.zone.points), 'success')
    elseif what == 'safe' then
        a.safe[#a.safe + 1] = p
        reply(src, ('Point sûr n°%d ajouté (retour en cas de sortie de zone).'):format(#a.safe), 'success')
    elseif what == 'center' then
        a.center = p
        reply(src, 'Centre de l\'arène enregistré.', 'success')
    else
        return reply(src, ('Usage : /%s <arène> A | B | corner | safe | center'):format(C.arenaAdd), 'error')
    end
    Arena.SaveArenas()
end)

admin(C.arenaReset, function(src, args)
    local a = arenaArg(src, args[1])
    if not a then return end
    local what = tostring(args[2] or ''):lower()
    if what == 'a' or what == 'b' then a.spawns[what:upper()] = {}
    elseif what == 'corner' then a.zone.points = {}
    elseif what == 'safe' then a.safe = {}
    else return reply(src, ('Usage : /%s <arène> A | B | corner | safe'):format(C.arenaReset), 'error') end
    Arena.SaveArenas()
    reply(src, 'Points effacés.', 'success')
end)

admin(C.arenaHeight, function(src, args)
    local a = arenaArg(src, args[1])
    if not a then return end
    local mn, mx = tonumber(args[2]), tonumber(args[3])
    if not mn or not mx or mx <= mn then return reply(src, ('Usage : /%s <arène> <z minimum> <z maximum>'):format(C.arenaHeight), 'error') end
    a.zone.minZ, a.zone.maxZ = mn, mx
    Arena.SaveArenas()
    reply(src, ('Hauteur autorisée : %.1f → %.1f'):format(mn, mx), 'success')
end)

admin(C.arenaDelete, function(src, args)
    local a = arenaArg(src, args[1])
    if not a then return end
    for _, L in pairs(Lobbies) do if L.settings.arena == a.id and L.state ~= 'LOBBY' then return reply(src, 'Une partie utilise cette arène.', 'error') end end
    Arena.arenas[a.id] = nil
    for i, id in ipairs(Arena.arenaOrder) do if id == a.id then table.remove(Arena.arenaOrder, i) break end end
    Arena.SaveArenas()
    reply(src, ('Arène %s supprimée.'):format(a.id), 'success')
end)

-- Affiche la zone, les points d'apparition et les points sûrs pendant 60 s (pour l'admin seulement)
admin(C.arenaShow, function(src, args)
    if src == 0 then return end
    local a = arenaArg(src, args[1])
    if not a then return end
    TriggerClientEvent('pvp_arena:showArena', src, a, 60)
    local ok, why = Arena.ArenaValid(a)
    reply(src, ok and 'Arène affichée 60 s.' or ('Arène incomplète : ' .. why), ok and 'success' or 'warning')
end)

-- Téléporte l'admin sur un point d'apparition pour le tester : /pvp_arena_tp <arène> A|B [n°]
admin(C.arenaTp, function(src, args)
    if src == 0 then return end
    local a = arenaArg(src, args[1])
    if not a then return end
    if byPlayer[src] then return reply(src, 'Pas pendant une partie.', 'error') end
    local list = a.spawns[tostring(args[2] or 'A'):upper()] or {}
    local sp = list[tonumber(args[3]) or 1]
    if not sp then return reply(src, 'Point introuvable.', 'error') end
    local ped = GetPlayerPed(src)
    SetEntityCoords(ped, sp.x, sp.y, sp.z, false, false, false, false)
    SetEntityHeading(ped, sp.h or 0.0)
    reply(src, ('Téléporté sur %s %s n°%d (%.1f, %.1f, %.1f).'):format(a.id, tostring(args[2] or 'A'):upper(), tonumber(args[3]) or 1, sp.x, sp.y, sp.z))
end)

-- État pour le PNJ de l'éditeur et les autres ressources
exports('IsInArena', function(src) return byPlayer[tonumber(src) or -1] ~= nil and Lobbies[byPlayer[tonumber(src)]] and Lobbies[byPlayer[tonumber(src)]].match ~= nil end)
