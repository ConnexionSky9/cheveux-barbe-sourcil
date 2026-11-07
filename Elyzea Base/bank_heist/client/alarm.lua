-- =====================================================================
--  BANK HEIST - client : alarme de la banque
--  Pendant un braquage avec alarme : sirène (interface, volume selon la distance, coupée au-delà de
--  2,5 × le rayon de la banque) et lumières rouges tournantes dans la banque.
--  Boîtier : policier → coupe directement ; braqueur → pinces, mini-jeu des fils (vérifié par le serveur).
--  Coût : une vérification toutes les 500 ms ; les lumières seulement à moins de 60 m.
-- =====================================================================
local C = BHC
local playing = false
local wires = nil   -- { bank }

CreateThread(function()
    while true do
        local cfg = C.Cfg()
        local sleep = 500
        local vol, lit = 0.0, nil
        if cfg then
            local pc = GetEntityCoords(PlayerPedId())
            local R = cfg.general.bankRadius or 45.0
            for _, b in ipairs(cfg.banks) do
                local st = C.Bank(b.id)
                if st.phase == 'active' and st.alarm then
                    local d = #(pc - C.Vec(b.alarm))
                    if d < R * 2.5 then
                        local v = d < R * 0.5 and 1.0 or math.max(0.0, 1.0 - (d - R * 0.5) / (R * 2.0))
                        vol = math.max(vol, v * (cfg.alarm.volume or 0.6))
                    end
                    if cfg.alarm.lights and d < 60.0 then lit = b end
                end
            end
        end
        if vol > 0.01 then
            SendNUIMessage({ action = 'alarm', on = true, volume = vol })
            playing = true
        elseif playing then
            SendNUIMessage({ action = 'alarm', on = false })
            playing = false
        end
        -- lumières : rouge tournant (boîtier + porte du coffre), chaque image tant qu'on est près
        if lit then
            local t0 = GetGameTimer() + sleep
            while GetGameTimer() < t0 do
                local k = (math.sin(GetGameTimer() / 140.0) + 1.0) * 0.5
                local a, dp = lit.alarm, lit.doorPoint
                DrawLightWithRangeAndShadow(a.x + 0.0, a.y + 0.0, a.z + 2.2, 255, 20, 30, 9.0, 2.0 + k * 6.0, 4.0)
                DrawLightWithRange(dp.x + 0.0, dp.y + 0.0, dp.z + 2.0, 255, 30, 40, 8.0, 1.5 + (1.0 - k) * 5.0)
                Wait(0)
            end
            sleep = 0
        end
        Wait(sleep)
    end
end)

-- Couper l'alarme au boîtier
function C.DisableAlarm(bankId)
    if wires or C.ui then return end
    local ped = PlayerPedId()
    local def = C.BankDef(bankId)
    if def then TaskTurnPedToFaceCoord(ped, def.alarm.x + 0.0, def.alarm.y + 0.0, def.alarm.z + 0.0, 500) Wait(500) end
    local r = C.Req('alarmStart', { bank = bankId })
    if not C.Show(r) then return end
    if r.done then
        C.PlayAnim(ped, { dict = 'anim@heists@prison_heistig1_p1_guard_checks_bus', name = 'loop', flag = 49 }, 2000)
        C.Sfx('unlock')
        return
    end
    wires = { bank = bankId }
    C.PlayAnim(ped, { dict = 'anim@heists@prison_heiststation@cop_reactions', name = 'cop_b_idle', flag = 49 })
    C.OpenUI('wires', r.game)
end
function C.OnWiresClosed(done)
    if not wires then return end
    wires = nil
    ClearPedTasks(PlayerPedId())
    if not done then C.Req('alarmAbort') end
end
RegisterNetEvent('bh:client:alarmGameEnd', function() if wires then C.CloseUI() C.OnWiresClosed(true) end end)

-- Lancement du braquage : bandeau et son pour les braqueurs
RegisterNetEvent('bh:client:robStart', function(d)
    C.Banner('BRAQUAGE EN COURS', ('%s · %s'):format(d and d.bank or '', (d and d.alarm) and 'l\'alarme hurle, la police arrive' or 'alarme silencieuse'), 'danger')
    C.Sfx('sting')
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and playing then SendNUIMessage({ action = 'alarm', on = false }) end end)
