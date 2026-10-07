-- ELYZEA CORE — notifications, barre de progression, aide à l'écran

function Notify(text, kind, duration, title)
    if type(text) == 'table' then
        local d = text
        text, kind, duration, title = d.description or d.text or d.title, d.type or kind, d.duration or duration, d.description and d.title or nil
    end
    if kind == 'primary' or kind == 'info' then kind = 'inform' end
    SendNUIMessage({ action = 'notify', text = text, type = kind or 'inform', duration = duration or Config.Notify.duration,
        title = title, position = Config.Notify.position })
end
exports('Notify', Notify)
RegisterNetEvent('elyzea:client:notify', function(text, kind, duration, title) Notify(text, kind, duration, title) end)

-- ─────────── Barre de progression ───────────
-- ProgressBar({ duration, label, canCancel, disable = { move, car, combat, mouse }, anim = { dict, clip, flag } | { scenario }, prop = { model, bone, pos, rot } })
-- Renvoie true si terminée, false si annulée.
local progressActive = false

local function loadDict(dict)
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
    return HasAnimDictLoaded(dict)
end

function ProgressBar(d)
    if progressActive then return false end
    d = d or {}
    local duration = math.floor(tonumber(d.duration) or 3000)
    progressActive = true
    local ped = PlayerPedId()
    local prop

    if d.anim then
        if d.anim.scenario then
            TaskStartScenarioInPlace(ped, d.anim.scenario, 0, true)
        elseif d.anim.dict and loadDict(d.anim.dict) then
            TaskPlayAnim(ped, d.anim.dict, d.anim.clip, d.anim.blendIn or 3.0, d.anim.blendOut or 1.0, d.anim.duration or -1, d.anim.flag or 49, 0, false, false, false)
        end
    end
    if d.prop and d.prop.model then
        local model = type(d.prop.model) == 'string' and joaat(d.prop.model) or d.prop.model
        RequestModel(model)
        local t = GetGameTimer() + 3000
        while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
        if HasModelLoaded(model) then
            local c = GetEntityCoords(ped)
            prop = CreateObject(model, c.x, c.y, c.z, true, true, false)
            local pos, rot = d.prop.pos or vec3(0.0, 0.0, 0.0), d.prop.rot or vec3(0.0, 0.0, 0.0)
            AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, d.prop.bone or 60309), pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 0, true)
            SetModelAsNoLongerNeeded(model)
        end
    end

    SendNUIMessage({ action = 'progress', label = d.label, duration = duration })
    local endAt = GetGameTimer() + duration
    local cancelled = false
    local disable = d.disable or {}
    while GetGameTimer() < endAt do
        if disable.move then DisableControlAction(0, 30, true) DisableControlAction(0, 31, true) DisableControlAction(0, 21, true) DisableControlAction(0, 22, true) end
        if disable.car then DisableControlAction(0, 63, true) DisableControlAction(0, 64, true) DisableControlAction(0, 71, true) DisableControlAction(0, 72, true) DisableControlAction(0, 75, true) end
        if disable.combat then DisablePlayerFiring(PlayerId(), true) DisableControlAction(0, 24, true) DisableControlAction(0, 25, true) DisableControlAction(0, 37, true) end
        if disable.mouse then DisableControlAction(0, 1, true) DisableControlAction(0, 2, true) end
        if d.canCancel and (IsControlJustPressed(0, 73) or IsControlJustPressed(0, 177)) then cancelled = true break end
        if IsEntityDead(ped) then cancelled = true break end
        Wait(0)
    end

    SendNUIMessage({ action = 'progressStop' })
    if d.anim then
        if d.anim.scenario then ClearPedTasks(ped)
        elseif d.anim.dict then StopAnimTask(ped, d.anim.dict, d.anim.clip, 1.0) end
    end
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    progressActive = false
    return not cancelled
end
exports('ProgressBar', ProgressBar)
exports('ProgressActive', function() return progressActive end)
exports('CancelProgress', function() progressActive = false SendNUIMessage({ action = 'progressStop' }) end)

-- ─────────── Aide à l'écran ───────────
local textShown = nil
function ShowTextUI(text)
    if textShown == text then return end
    textShown = text
    SendNUIMessage({ action = 'textui', text = text })
end
function HideTextUI()
    if not textShown then return end
    textShown = nil
    SendNUIMessage({ action = 'textuiHide' })
end
exports('ShowTextUI', ShowTextUI)
exports('HideTextUI', HideTextUI)
exports('IsTextUIOpen', function() return textShown ~= nil, textShown end)
