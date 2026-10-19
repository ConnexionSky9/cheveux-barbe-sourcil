-- =========================================================
--  ELYZEA CASINO - roue de la fortune côté client
--  Le joueur lance la roue (animation des bras), la roue 3D tourne et ralentit pour s'arrêter
--  sur le segment tiré par le serveur ; tous les joueurs proches voient la même rotation.
--  La roue de l'interface montre les vrais textes / couleurs réglés dans l'admin.
-- =========================================================
local A = Config.Anims
local angles = {}    -- [id] = angle actuel de la roue 3D (degrés)
local spinningMe = false

local function wheelAnimDict()
    local female = GetEntityModel(PlayerPedId()) == GetHashKey('mp_f_freemode_01')
    return female and A.wheelFemale or A.wheelMale
end

function CS.WheelPrompt(id, p)
    if not p.wheel then return false end
    local w = p.wheel
    local cost = (w.costType == 'free' or (w.cost or 0) <= 0) and 'gratuit' or ('%d %s'):format(w.cost, w.costType == 'money' and '$' or 'jetons')
    local text = spinningMe and 'La roue tourne…' or ('[E] Tourner « %s » (%s)'):format(w.name, cost)
    CS.ShowPrompt(text)
    if not spinningMe and IsControlJustPressed(0, 38) then
        CS.HidePrompt()
        CreateThread(function() CS.SpinWheel(id) end)
    end
    return true
end

function CS.SpinWheel(id)
    if spinningMe then return end
    spinningMe = true
    local nonce = ('%d-%d'):format(GetGameTimer(), math.random(100000, 999999))
    local ok, msg = Ely.callback.await('elyzea_casino:wheel:spin', false, { pedId = id, nonce = nonce })
    if not ok then
        spinningMe = false
        return CS.Notify(msg or 'Impossible de tourner la roue.', 'error')
    end
end

-- Rotation pour tous (même segment, même durée)
RegisterNetEvent('elyzea_casino:wheel:spin', function(id, idx, n, duration, spinner)
    local me = spinner == GetPlayerServerId(PlayerId())
    local p = CS.points[id]
    local e = CS.ents[id]
    if me then
        spinningMe = true
        local ped = PlayerPedId()
        if p and p.table then
            TaskTurnPedToFaceCoord(ped, p.table.x, p.table.y, p.table.z, 800)
            Wait(500)
        end
        local dict = wheelAnimDict()
        if CS.LoadDict(dict) then
            TaskPlayAnim(ped, dict, 'enter_right_to_baseidle', 4.0, -4.0, -1, 0, 0.0, false, false, false)
            SetTimeout(1300, function() TaskPlayAnim(ped, dict, 'armraisedidle_to_spinningidle_high', 4.0, -4.0, -1, 0, 0.0, false, false, false) end)
            SetTimeout(3200, function() ClearPedTasks(ped) end)
        else
            CS.PlayAnim(ped, A.fallbackHand, 48, 1500)
        end
        if p and p.wheel then
            CS.uiOpen = 'wheel'
            CS.UI({ action = 'wheelSpin', id = id, idx = idx, n = n, duration = duration, wheel = p.wheel })
        end
        SetTimeout(duration + 4500, function()
            spinningMe = false
            if CS.uiOpen == 'wheel' then CS.uiOpen = nil CS.UI({ action = 'wheelHide' }) end
        end)
    end
    if not e or not e.wheel or not p then return end
    -- Rotation 3D : plusieurs tours puis arrêt doux sur le segment (le haut de la roue = repère)
    CreateThread(function()
        Wait(me and 1200 or 1200)
        local start = angles[id] or 0.0
        local seg = 360.0 / math.max(1, n)
        local target = (idx - 1) * seg
        local base = start - (start % 360.0)
        local final = base + 360.0 * 5 + target
        local t0, dur = GetGameTimer(), duration - 1200
        while DoesEntityExist(e.wheel) do
            local k = math.min(1.0, (GetGameTimer() - t0) / dur)
            local ease = 1 - (1 - k) ^ 3
            local a = start + (final - start) * ease
            SetEntityRotation(e.wheel, 0.0, a, p.table.h, 2, true)
            if k >= 1.0 then break end
            Wait(0)
        end
        angles[id] = final % 360.0
    end)
end)

RegisterNetEvent('elyzea_casino:wheel:result', function(id, idx, label, prize)
    CS.UI({ action = 'wheelResult', id = id, idx = idx, label = label, prize = prize })
    PlaySoundFrontend(-1, prize and 'WIN' or 'LOSER', 'HUD_AWARDS', true)
end)
