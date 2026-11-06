-- =====================================================================
--  ELYZEA LASERGAME - SERVEUR : démarrage, interface, profil, classements
-- =====================================================================
-- ---------------------------------------------------------------- interface
local function categoriesView()
    local cats = {}
    for _, c in ipairs(LG.WeaponCategories) do
        local ws = {}
        for _, w in ipairs(LGU.WeaponsOfCategory(c.id)) do
            if not w.disabled then ws[#ws + 1] = { id = w.id, label = w.label, damage = w.damage, range = w.range, rpm = w.rpm, mag = w.mag, tier = w.tier } end
        end
        if #ws > 0 then cats[#cats + 1] = { id = c.id, label = c.label, weapons = ws } end
    end
    return cats
end

RPC.Register('ui:init', function(src)
    local id = Bridge.Identity(src)
    if not id then return false, 'Personnage introuvable.' end
    local formats = {}
    for _, f in ipairs(Config.PvP.formats) do
        if not (Config.PvP.disabledFormats or {})[f.id] then formats[#formats + 1] = f end
    end
    local ranks = {}
    for _, r in ipairs(LG.Ranks) do ranks[#ranks + 1] = { id = r.id, label = r.label, min = r.min, color = r.color, tier = r.tier } end
    local g, role = Games.ByPlayer(src)
    return true, {
        me = { id = src, name = id.name, firstname = id.firstname, lastname = id.lastname },
        profile = Ranking.ProfileView(id),
        isAdmin = Bridge.IsAdmin(src),
        pvp = { enabled = Config.PvP.enabled, formats = formats, rounds = Config.PvP.roundsOptions, roundTimes = Config.PvP.roundTimeOptions,
            defaultRounds = Config.PvP.defaultRounds, defaultRoundTime = Config.PvP.defaultRoundTime, ranked = Config.PvP.ranked },
        stake = { enabled = Config.Stake.enabled, min = Config.Stake.min, max = Config.Stake.max, step = Config.Stake.step, fee = Config.Stake.houseFeePct },
        maps = Maps.Public(), categories = categoriesView(), ranks = ranks,
        teams = { A = { name = Config.Teams.A.name, hex = Config.Teams.A.hex }, B = { name = Config.Teams.B.name, hex = Config.Teams.B.hex } },
        games = Lobby.PublicList(src),
        current = g and { uid = g.uid, mode = g.mode, role = role, phase = g.phase } or nil,
        lobby = g and g.phase == LG.Phase.LOBBY and Games.handlers[g.mode].lobbyView(g, src) or nil,
        spectator = Config.Spectator.enabled,
    }
end)

RPC.Register('profile:get', function(src)
    local id = Bridge.Identity(src)
    if not id then return false end
    return true, Ranking.ProfileView(id)
end)

RPC.Register('history:get', function(src)
    local id = Bridge.Identity(src)
    if not id then return false end
    return true, Ranking.History(id.cid, 25)
end)

RPC.Register('lb:get', function(src, kind, page)
    local data = Ranking.Board(tostring(kind or ''), page)
    if not data then return false, 'Classement inconnu.' end
    return true, data
end)

RPC.Register('list:get', function(src) return true, Lobby.PublicList(src) end)

-- ---------------------------------------------------------------- commandes
RegisterCommand('lgleave', function(src)
    if src == 0 then return end
    if not Games.ForceLeave(src, 'a quitté (/lgleave)') then
        Games.Notify(src, 'Tu n\'es dans aucune partie.', 'info')
    end
end, false)

-- ---------------------------------------------------------------- démarrage
Bridge.OnLogin(function(src)
    SetTimeout(4000, function()
        if not GetPlayerName(src) or not DB.ready then return end
        Restore.FromDb(src)
        Economy.PayPending(src)
    end)
end)

CreateThread(function()
    Settings.CaptureDefaults()
    local ok, err = pcall(DB.Init)
    if not ok then
        print('^1[elyzea_lasergame] base de données indisponible : ' .. tostring(err) .. '^0')
        return
    end
    Settings.Load()
    Maps.Load()
    Settings.Apply()
    Players.LoadExclusions()
    -- crash / redémarrage pendant une partie : mises remboursées, joueurs encore connectés remis au RP
    Economy.RecoverOnStart()
    for _, sid in ipairs(GetPlayers()) do
        local s = tonumber(sid)
        local st = Player(s).state
        if st[LG.StateGame] then
            st:set(LG.StateArena, false, true)
            st:set(LG.StateGame, nil, true)
        end
        Restore.FromDb(s)
    end
    Logs.Add('admin', ('ressource démarrée (v%s, framework %s, %d arène(s))'):format(LG.Version, Bridge.Name(), #Maps.order))
end)

-- Arrêt de la ressource : chacun est rendu au RP tout de suite (la sauvegarde en base reste jusqu'à confirmation)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, g in pairs(Games.list) do
        if g.phase ~= LG.Phase.LOBBY then
            for _, s in ipairs(Games.Members(g)) do
                local snap = (g.players[s] or {}).snap or ((g.spectators or {})[s] or {}).snap
                if snap then
                    SetPlayerRoutingBucket(s, tonumber(snap.bucket) or 0)
                    TriggerClientEvent('elyzea_lasergame:restore', s, { x = snap.x, y = snap.y, z = snap.z, h = snap.h, health = snap.health,
                        armor = snap.armor, look = snap.look, quiet = true })
                end
                Player(s).state:set(LG.StateArena, false, true)
                Player(s).state:set(LG.StateGame, nil, true)
            end
        end
    end
end)

-- Le state bag partagé peut être remis à zéro par une autre ressource (ex. redémarrage de pvp_arena) :
-- il est réaffirmé toutes les 5 s pour les joueurs en partie
CreateThread(function()
    while true do
        Wait(5000)
        for s, r in pairs(Games.byPlayer) do
            local g = Games.list[r.uid]
            if g and g.phase ~= LG.Phase.LOBBY and GetPlayerName(s) then
                local st = Player(s).state
                if not st[LG.StateArena] then st:set(LG.StateArena, true, true) end
            end
        end
    end
end)

exports('IsInGame', function(src) return Games.ByPlayer(tonumber(src)) ~= nil end)
exports('GetPlayerGame', function(src)
    local g, role = Games.ByPlayer(tonumber(src))
    return g and { uid = g.uid, mode = g.mode, role = role, phase = g.phase } or nil
end)
