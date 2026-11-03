-- =====================================================================
--  ELYZEA LASERGAME - MODE PVP (client)
--  Apparitions, décompte, manches, bouclier, élimination → spectateur des coéquipiers,
--  HUD (scores, temps, manche, éliminations, vivants, état des coéquipiers), fin de partie.
-- =====================================================================
local P = { state = nil, shield = 100, maxShield = 100 }

local function enemyTargets()
    local out = {}
    if not P.state then return out end
    for _, p in ipairs(P.state.players or {}) do
        if p.alive and p.team ~= C.team and p.id ~= C.serverId then
            local idx = GetPlayerFromServerId(p.id)
            if idx ~= -1 then out[#out + 1] = { ped = GetPlayerPed(idx), hit = { k = 'p', id = p.id } } end
        end
    end
    return out
end

RegisterNetEvent('elyzea_lasergame:enterGame', function(d)
    if d.mode ~= 'pvp' then return end
    P.state, P.shield, P.maxShield = nil, d.shield or Config.PvP.shield, d.shield or Config.PvP.shield
    C.EnterGame(d, function()
        if d.role == 'spectator' then
            C.StartSpectate('all')
            C.UI('hud', { mode = 'pvp', role = 'spectator', rounds = d.rounds, teamNames = d.teamNames })
            return
        end
        C.CanFire = function() return C.alive and not C.frozen and P.phase == 'round' end
        Weapons.MeleeTargets = enemyTargets
        Weapons.reloadMult = 1.0
        C.UI('hud', { mode = 'pvp', role = 'player', team = d.team, rounds = d.rounds, teamNames = d.teamNames, shield = P.shield, maxShield = P.maxShield })
    end)
end)

RegisterNetEvent('elyzea_lasergame:pvpSpawn', function(d)
    if not C.inGame or C.mode ~= 'pvp' or C.role ~= 'player' then return end
    P.phase = 'countdown'
    if C.StopSpectate then C.StopSpectate() end
    if not IsScreenFadedOut() then C.Fade(true, 250) end
    local ped = C.Resurrect(d.pos, d.pos.h)
    C.SetGhost(false)
    SetEntityInvincible(ped, true)
    C.PlaceAt(d.pos, d.pos.h)
    Map.ResetWall(GetEntityCoords(PlayerPedId()))
    ped = PlayerPedId()
    SetEntityHealth(ped, 200)
    SetPedArmour(ped, 0)
    Weapons.Equip(d.weapon)
    C.alive, C.frozen = true, true
    FreezeEntityPosition(ped, true)
    P.shield = d.shield
    C.UI('shield', { shield = P.shield, max = P.maxShield })
    C.UI('crosshair', true)
    C.Fade(false, 400)
end)

RegisterNetEvent('elyzea_lasergame:countdown', function(d)
    if not C.inGame then return end
    C.UI('countdown', d)
    C.Sound('countdown', 0.9)
end)

RegisterNetEvent('elyzea_lasergame:roundStart', function(d)
    if not C.inGame then return end
    P.phase = 'round'
    if C.role == 'player' and C.alive then
        C.frozen = false
        FreezeEntityPosition(PlayerPedId(), false)
    end
    C.UI('roundStart', d)
    C.Sound('go', 1.0)
end)

RegisterNetEvent('elyzea_lasergame:roundEnd', function(d)
    if not C.inGame then return end
    P.phase = 'round_end'
    C.frozen = true
    local mine = C.team and d.winner == C.team
    C.UI('roundEnd', { winner = d.winner, reason = d.reason, score = d.score, round = d.round, mine = mine, myTeam = C.team })
    C.Sound(d.winner == nil and 'draw' or (mine and 'round_win' or 'round_lose'), 1.0)
end)

RegisterNetEvent('elyzea_lasergame:pvpState', function(s)
    if not C.inGame or C.mode ~= 'pvp' then return end
    P.state = s
    P.phase = s.phase
    -- un joueur éliminé ne voit pas le bouclier des adversaires (pas d'info stratégique)
    local view = { score = s.score, round = s.round, rounds = s.rounds, endsAt = s.endsAt, serverTime = s.serverTime, alive = s.alive,
        players = {}, myTeam = C.team, role = C.role }
    for _, p in ipairs(s.players) do
        local hide = Config.Spectator.hideEnemyHealthToEliminated and C.role == 'player' and p.team ~= C.team
        view.players[#view.players + 1] = { id = p.id, name = p.name, team = p.team, alive = p.alive, kills = p.kills, deaths = p.deaths,
            shield = hide and nil or p.shield, me = p.id == C.serverId }
    end
    C.UI('pvpState', view)
    if C.SpectateRefresh then C.SpectateRefresh(s.players) end
end)

RegisterNetEvent('elyzea_lasergame:damaged', function(d)
    if not C.inGame then return end
    P.shield = d.shield
    C.UI('shield', { shield = d.shield, max = P.maxShield, hit = true })
    -- indicateur de direction du tir
    if d.dir then
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local ang = math.deg(math.atan(d.dir.y - pos.y, d.dir.x - pos.x)) - 90.0 - GetGameplayCamRot(2).z
        C.UI('damageDir', { angle = ang })
    end
    C.Sound('hurt', 0.8)
    if C.settings.effects then ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.03) end
end)

RegisterNetEvent('elyzea_lasergame:eliminated', function(d)
    if not C.inGame then return end
    C.alive = false
    Weapons.Strip()
    C.UI('crosshair', false)
    C.UI('eliminated', d)
    C.Sound('eliminated', 1.0)
    -- effet d'élimination puis spectateur des coéquipiers encore en vie
    local ped = PlayerPedId()
    if C.settings.effects then
        local r, g, b = C.TeamColor(C.team)
        Laser.Impact(GetEntityCoords(ped), { r, g, b }, true)
        AnimpostfxPlay('MinigameEndNeutral', 1500, false)
    end
    SetTimeout(1200, function()
        if C.inGame and not C.alive then
            C.SetGhost(true)
            C.StartSpectate(Config.Spectator.eliminatedSeeTeamOnly and 'team' or 'all')
        end
    end)
end)

RegisterNetEvent('elyzea_lasergame:killfeed', function(k)
    if not C.inGame then return end
    k.myTeam = C.team
    k.mine = k.killerId == C.serverId
    C.UI('killfeed', k)
end)

RegisterNetEvent('elyzea_lasergame:matchEnd', function(d)
    if not C.inGame then return end
    P.phase = 'ended'
    C.frozen = true
    if C.StopSpectate then C.StopSpectate() end
    C.UI('crosshair', false)
    d.myTeam = C.team
    C.UI('matchEnd', d)
    local res = d.me and d.me.result
    C.Sound(res == 'win' and 'victory' or (res == 'loss' and 'defeat' or 'draw'), 1.0)
    if C.settings.effects then AnimpostfxPlay(res == 'win' and 'SuccessNeutral' or 'MinigameEndNeutral', 3000, false) end
end)

-- Quitter la partie (Retour arrière maintenu 2 s, ou /lgleave)
C.ConfirmLeave = function()
    C.UI('confirmLeave')
end
RegisterNUICallback('leaveGame', function(_, cb) cb(1) RPC.Call('lobby:leave') end)
