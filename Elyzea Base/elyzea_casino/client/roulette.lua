-- =========================================================
--  ELYZEA CASINO - roulette côté client : croupier, roue 3D et bille, interface
--  Le serveur envoie le résultat AVANT l'animation : la roue de l'interface s'arrête exactement
--  sur ce numéro ; la roue 3D du jeu joue la même chute (Config.Roulette3DExact).
-- =========================================================
local A = Config.Anims

local function exitIndex(result)
    local label = Rules.PocketLabel(result)
    for i, v in ipairs(Config.RouletteWheelOrder) do if v == label then return i end end
    return 1
end

function CS.RLState(id, st)
    -- rien de 3D à mettre à jour hors lancement ; l'interface reçoit l'état (CS.OnTable)
end

RegisterNetEvent('elyzea_casino:rl:spin', function(id, result, duration, variant)
    if CS.seated and CS.seated.id == id then
        CS.UI({ action = 'rlSpin', id = id, result = result, duration = duration, variant = variant })
    end
    local e = CS.ents[id]
    if not e or not e.table then return end
    local dealer = CS.DealerPed(id)
    if dealer then CS.PlayAnim(dealer, A.rouletteSpin, 0, -1, A.fallbackHand) end
    local dict = A.rouletteTable
    if not CS.LoadDict(dict) then return end
    CreateThread(function()
        local p = CS.points[id]
        if not p or not p.table then return end
        local ball
        local hash = CS.LoadModel('vw_prop_roulette_ball')
        if hash then
            ball = CreateObjectNoOffset(hash, p.table.x, p.table.y, p.table.z, false, false, false)
            SetModelAsNoLongerNeeded(hash)
            SetEntityHeading(ball, p.table.h)
            SetEntityCollision(ball, false, false)
            e.ball = ball
        end
        local function play(ent, clip) if ent and DoesEntityExist(ent) then PlayEntityAnim(ent, clip, dict, 1000.0, false, true, true, 0, 136704) end end
        play(e.table, 'intro_wheel') play(ball, 'intro_ball')
        Wait(1000)
        play(e.table, 'loop_wheel') play(ball, 'loop_ball')
        Wait(math.max(0, duration - 5500))
        if Config.Roulette3DExact then
            local n = exitIndex(result)
            play(e.table, ('exit_%d_wheel'):format(n)) play(ball, ('exit_%d_ball'):format(n))
        end
        Wait(9000)
        if ball and DoesEntityExist(ball) then DeleteEntity(ball) end
        if e.ball == ball then e.ball = nil end
    end)
end)

RegisterNUICallback('rlAction', function(d, cb)
    if not CS.seated or CS.seated.game ~= 'roulette' then return cb({ ok = false, msg = 'Tu n\'es pas à la table.' }) end
    d.pedId = CS.seated.id
    local ok, msg = Ely.callback.await('elyzea_casino:rl:action', false, d)
    cb({ ok = ok == true, msg = msg })
    if ok and d.action == 'bet' then
        if CS.Gesture then CS.Gesture(A.playerBet) end
        PlaySoundFrontend(-1, 'CHIPS', 'DLC_VW_TABLE_GAMES_SOUNDS', true)
    end
end)
