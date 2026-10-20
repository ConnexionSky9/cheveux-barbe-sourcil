-- =====================================================================
--  ELYZEA PRESSE - client : matériel tenu en main et viseur
--  · « Utiliser » le micro, la caméra ou l'appareil photo (inventaire) : le sortir / le ranger.
--  · Caméra ou appareil photo en main : G = viseur (molette : zoom, souris : cadrer),
--    clic gauche = photo / début-fin de la séquence, G ou Retour arrière = quitter.
--  · La photo ou la séquence est enregistrée côté serveur comme une fiche (légende, lieu,
--    heure, durée) : aucune image ni vidéo n'est capturée.
--  · Le serveur a déjà vérifié le métier, le service et la permission avant d'envoyer « use ».
-- =====================================================================
local C = PresseC
local PR = Config.Props
local MD = Config.Media

C.hold = nil          -- 'mic' | 'camera' | 'photo'
local prop = nil
local view = nil      -- viseur : { cam, kind, fov, rec, recStart, busy }

local function LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(hash) and hash or nil
end

function C.StopHold()
    if view then C.CloseViewfinder(true) end
    local ped = PlayerPedId()
    if C.hold and PR[C.hold] then StopAnimTask(ped, PR[C.hold].dict, PR[C.hold].clip, 1.0) end
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    prop, C.hold = nil, nil
    SendNUIMessage({ action = 'hold', kind = nil })
end

local function StartHold(kind)
    C.StopHold()
    local def = PR[kind]
    if not def then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return C.Notify('Sortez du véhicule.', 'error') end
    if not C.LoadDict(def.dict) then return C.Notify('Animation indisponible.', 'error') end
    local hash = LoadModel(def.model)
    if hash then
        local c = GetEntityCoords(ped)
        prop = CreateObject(hash, c.x, c.y, c.z + 0.2, true, true, false)
        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, def.bone), def.pos[1], def.pos[2], def.pos[3], def.rot[1], def.rot[2], def.rot[3],
            true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(hash)
    end
    TaskPlayAnim(ped, def.dict, def.clip, 3.0, 3.0, -1, 49, 0, false, false, false)
    C.hold = kind
    SendNUIMessage({ action = 'hold', kind = kind })
    if kind == 'mic' then C.Notify('Micro en main. X : le ranger.', 'inform')
    else C.Notify('G : viseur · X : ranger.', 'inform') end
end

-- ---------------------------------------------------------------------
-- Viseur
-- ---------------------------------------------------------------------
local function ViewUi()
    if not view then return SendNUIMessage({ action = 'viewfinder', show = false }) end
    SendNUIMessage({ action = 'viewfinder', show = true, kind = view.kind, zoom = math.floor((MD.fovMax / view.fov) * 10) / 10,
        rec = view.rec, recSeconds = view.rec and math.floor((GetGameTimer() - view.recStart) / 1000) or 0, street = C.Street() })
end

function C.CloseViewfinder(silent)
    if not view then return end
    if view.rec then C.Req('videoCancel') if not silent then C.Notify('Séquence interrompue : rien n\'est enregistré.', 'error') end end
    RenderScriptCams(false, true, 300, true, false)
    DestroyCam(view.cam, false)
    ClearTimecycleModifier()
    view = nil
    ViewUi()
end

-- Légende demandée dans l'interface (clavier) puis envoi au serveur
local captionWait = nil
local function AskCaption(kind)
    captionWait = promise.new()
    C.Focus('caption', true)
    SendNUIMessage({ action = 'caption', show = true, kind = kind, max = MD.captionMax })
    local caption = Citizen.Await(captionWait)
    captionWait = nil
    C.Focus('caption', false)
    return caption
end
C.ui.caption = { close = function() SendNUIMessage({ action = 'caption', show = false }) if captionWait then captionWait:resolve(nil) end end }
RegisterNUICallback('caption', function(body, cb)
    cb({})
    SendNUIMessage({ action = 'caption', show = false })
    if captionWait then
        if body.cancel then captionWait:resolve(nil) else captionWait:resolve(tostring(body.caption or '')) end
    end
end)

local function Shoot()
    if view.busy then return end
    view.busy = true
    if view.kind == 'photo' then
        PlaySoundFrontend(-1, 'Camera_Shoot', 'Phone_Soundset_Franklin', true)
        SendNUIMessage({ action = 'flashShot' })
        local street = C.Street()
        local caption = AskCaption('photo')
        if caption ~= nil and view then C.Do('mediaSave', { kind = 'photo', caption = caption, street = street }) end
    elseif not view.rec then
        local r = C.Req('videoStart')
        if r.error then C.Notify(r.error, 'error') else view.rec, view.recStart = true, GetGameTimer() end
    else
        view.rec = false
        local street = C.Street()
        local caption = AskCaption('video')
        if caption == nil then C.Req('videoCancel') C.Notify('Séquence abandonnée.', 'inform')
        else C.Do('mediaSave', { kind = 'video', caption = caption, street = street }) end
    end
    if view then view.busy = false end
end

local function OpenViewfinder()
    if view or (C.hold ~= 'camera' and C.hold ~= 'photo') then return end
    local ped = PlayerPedId()
    local rot = GetGameplayCamRot(2)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    view = { cam = cam, kind = C.hold == 'camera' and 'video' or 'photo', fov = MD.fovMax, rx = rot.x, rz = rot.z, rec = false }
    SetCamFov(cam, view.fov)
    RenderScriptCams(true, true, 300, true, false)
    if view.kind == 'video' then SetTimecycleModifier('scanline_cam_cheap') SetTimecycleModifierStrength(0.6) end
    CreateThread(function()
        local lastUi = 0
        while view do
            local v = view
            DisableControlAction(0, 1, true) DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)
            DisableControlAction(0, 14, true) DisableControlAction(0, 15, true)
            DisableControlAction(0, 37, true) DisableControlAction(0, 199, true) DisableControlAction(0, 200, true)
            HideHudAndRadarThisFrame()
            if not v.busy then
                local zoomFactor = v.fov / MD.fovMax
                v.rz = v.rz - GetDisabledControlNormal(0, 1) * 8.0 * zoomFactor
                v.rx = math.max(-60.0, math.min(45.0, v.rx - GetDisabledControlNormal(0, 2) * 8.0 * zoomFactor))
                if IsDisabledControlJustPressed(0, 15) then v.fov = math.max(MD.fovMin, v.fov - 4.0) end
                if IsDisabledControlJustPressed(0, 14) then v.fov = math.min(MD.fovMax, v.fov + 4.0) end
                if IsDisabledControlJustPressed(0, 24) then CreateThread(Shoot) end
                if IsControlJustPressed(0, 47) or IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then C.CloseViewfinder() break end
            end
            ped = PlayerPedId()
            SetEntityHeading(ped, v.rz)
            local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
            local rad = math.rad(v.rz)
            SetCamCoord(v.cam, head.x - math.sin(rad) * 0.35, head.y + math.cos(rad) * 0.35, head.z + 0.05)
            SetCamRot(v.cam, v.rx, 0.0, v.rz, 2)
            SetCamFov(v.cam, v.fov)
            if GetGameTimer() - lastUi > 250 then lastUi = GetGameTimer() ViewUi() end
            if IsEntityDead(ped) or IsPedRagdoll(ped) or C.IsDown() or not C.OnDuty() then C.CloseViewfinder() break end
            Wait(0)
        end
    end)
end

-- ---------------------------------------------------------------------
-- Objet utilisé (vérifié par le serveur)
-- ---------------------------------------------------------------------
RegisterNetEvent('presse:client:use', function(kind)
    if C.IsDown() or IsEntityDead(PlayerPedId()) then return end
    if kind == 'notes' then return C.OpenNotes and C.OpenNotes() end
    if C.hold == kind then return C.StopHold() end
    StartHold(kind)
end)
RegisterNetEvent('presse:client:stopHold', function() C.StopHold() end)

-- Touches pendant que l'objet est en main ; perte de l'objet (véhicule, chute, mort, fin de service)
CreateThread(function()
    while true do
        if C.hold and not view then
            local ped = PlayerPedId()
            local def = PR[C.hold]
            if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) or C.IsDown() or not C.OnDuty() then
                C.StopHold()
            else
                if not IsEntityPlayingAnim(ped, def.dict, def.clip, 3) and not IsPedFalling(ped) then TaskPlayAnim(ped, def.dict, def.clip, 3.0, 3.0, -1, 49, 0, false, false, false) end
                DisableControlAction(0, 24, true) DisableControlAction(0, 25, true) DisableControlAction(0, 140, true)
                if IsControlJustPressed(0, 73) and not C.AnyOpen() then C.StopHold()
                elseif IsControlJustPressed(0, 47) and (C.hold == 'camera' or C.hold == 'photo') and not C.AnyOpen() then OpenViewfinder() end
            end
            Wait(0)
        else
            Wait(300)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if view then RenderScriptCams(false, false, 0, true, false) DestroyCam(view.cam, false) ClearTimecycleModifier() end
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
end)
