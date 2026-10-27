-- =====================================================================
--  BARRE DE POLE DANCE - client
--  E près de la barre : la danseuse monte sur la barre (animation d'entrée), puis enchaîne les routines
--  du club de strip-tease du jeu (tours, montées, descentes). Scènes synchronisées par le réseau :
--  tout le monde autour voit la même danse, calée sur la barre.
--  Touches : 1 / 2 / 3 routines · 4 danse sensuelle devant la barre · 5 enchaînement automatique
--            RETOUR ARRIÈRE ou E : descendre de la barre.
--  Spectateurs : E pour lancer des billets (pourboire validé par le serveur).
-- =====================================================================
local M = {}
CL.Games.pole = M
local C = Config.Pole
local props = {}        -- [instId] = objet barre (local)
local state = {}        -- [instId] = { sid, name } : qui danse
local dancing = nil     -- { id, stop = bool, reason }

-- ---------------------------------------------------------------- barre
local function dims(o)
    local mn = GetModelDimensions(GetEntityModel(o))
    return math.max(0.0, -(mn and mn.z or 0.0))
end
function M.Spawn(inst)
    local d = inst.data
    if d.spawn == false then return end   -- barre du décor : déjà sur la carte
    local o = CL.Object(C.model, d.x, d.y, d.z, C.collision ~= false)
    if not o then return end
    SetEntityCoordsNoOffset(o, d.x, d.y, d.z + dims(o), false, false, false)
    SetEntityHeading(o, d.h or 0.0)
    props[inst.id] = o
end
function M.Despawn(inst)
    if props[inst.id] then CL.Delete(props[inst.id]) props[inst.id] = nil end
end
function M.InteractPoint(inst) local d = inst.data return vector3(d.x, d.y, d.z + 1.0) end
function M.Busy() return dancing ~= nil end

-- ---------------------------------------------------------------- qui danse (envoyé par le serveur)
RegisterNetEvent('elyzea_loisirs:client:pole', function(id, d) state[tonumber(id)] = d end)
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    Wait(3000)
    local list = Ely.callback.await('loisirs:pole_state', false)
    if type(list) == 'table' then for id, d in pairs(list) do state[tonumber(id)] = d end end
end)

function M.InteractDistance(inst)
    local st = state[inst.id]
    if st and st.sid ~= CL.Me() and C.tips and C.tips.enabled then return C.tips.maxDistance - 0.3 end
    return C.interactDistance
end
function M.Prompt(inst)
    local st = state[inst.id]
    if not st then return ('[E] 💃 Danser à la barre · %s'):format(inst.name) end
    if st.sid == CL.Me() then return nil end
    if C.tips and C.tips.enabled then return ('[E] 💵 Lancer %d $ à %s'):format(C.tips.amount, st.name) end
    return nil
end

-- ---------------------------------------------------------------- la vraie barre
-- La danse se cale sur l'objet barre lui-même (barre posée par le menu ou barre du décor) :
-- son axe (x, y) et son pied (bas du modèle). Si l'objet n'est pas trouvé, on prend la position enregistrée.
local function poleEntity(inst)
    local o = props[inst.id]
    if o and DoesEntityExist(o) then return o end
    local d = inst.data
    o = GetClosestObjectOfType(d.x, d.y, d.z + 1.0, 1.5, GetHashKey(C.model), false, false, false)
    if o and o ~= 0 then return o end
end
local function poleBase(inst)
    local o = poleEntity(inst)
    if o then
        local c = GetEntityCoords(o)
        return vector3(c.x, c.y, c.z - dims(o)), o
    end
    local d = inst.data
    return vector3(d.x, d.y, d.z), nil
end

-- ---------------------------------------------------------------- scènes synchronisées
-- origine des animations = pied de la barre + décalage (config + réglage de la barre), tournée selon la barre
local calib = nil   -- réglage en direct (staff) : { id, token, ox, oy, oz, h }
local function setting(inst, k, def)
    if calib and calib.id == inst.id then return calib[k] end
    return inst.data[k] or def
end
local function origin(inst)
    local base = poleBase(inst)
    local off = C.sceneOffset or vector3(0.0, 0.0, 0.0)
    local h = setting(inst, 'h', 0.0) or 0.0
    local x, y = LU.toWorld(base.x, base.y, h, off.x + (setting(inst, 'ox', 0.0) or 0.0), off.y + (setting(inst, 'oy', 0.0) or 0.0))
    return vector3(x, y, base.z + off.z + (setting(inst, 'oz', 0.0) or 0.0)), h
end

local scene, sceneAnim, sceneCheck
local function stopScene()
    if scene then NetworkStopSynchronisedScene(scene) scene = nil end
    sceneAnim = nil
end
-- joue une animation calée sur la barre ; renvoie sa durée (s)
local function playScene(inst, a, loop)
    local ped = PlayerPedId()
    if not CL.Anim.Load(a.dict) then return 0 end
    local o, h = origin(inst)
    local old = scene
    scene = NetworkCreateSynchronisedScene(o.x, o.y, o.z, 0.0, 0.0, h, 2, false, loop == true, 1.0, 0.0, C.sceneSpeed or 1.0)
    NetworkAddPedToSynchronisedScene(ped, scene, a.dict, a.clip, 1.5, -4.0, 1, 1, 1000.0, 0)
    NetworkStartSynchronisedScene(scene)
    if old then NetworkStopSynchronisedScene(old) end
    sceneAnim = { a = a, loop = loop == true, o = o, h = h }
    sceneCheck = GetGameTimer() + 700
    local dur = GetAnimDuration(a.dict, a.clip) or 0
    if dur <= 0 then dur = 8.0 end
    return dur / (C.sceneSpeed or 1.0)
end
-- secours : si la scène réseau n'a pas démarré, l'animation est jouée calée au même point
local function checkScene()
    if not sceneCheck or GetGameTimer() < sceneCheck or not sceneAnim then return end
    sceneCheck = nil
    local localId = scene and NetworkGetLocalSceneFromNetworkId(scene) or -1
    if localId and localId ~= -1 and IsSynchronizedSceneRunning(localId) then return end
    local s, ped = sceneAnim, PlayerPedId()
    CL.Dbg('scène réseau absente : animation calée de secours', s.a.clip)
    TaskPlayAnimAdvanced(ped, s.a.dict, s.a.clip, s.o.x, s.o.y, s.o.z, 0.0, 0.0, s.h, 2.0, -2.0, -1, s.loop and 1 or 0, 0.0, 2, 0)
end

local function lockControls()
    CL.Anim.LockControls()
    for _, c in ipairs({ 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 37, 44, 45, 47, 74, 140, 141, 142, 143, 157, 158, 159, 160, 161, 162, 163, 164, 165, 172, 173, 174, 175, 10, 11, 191 }) do
        DisableControlAction(0, c, true)
    end
end
local function pressed(k) return IsDisabledControlJustPressed(0, k) end

-- danse sensuelle debout, devant la barre (3 parties enchaînées en boucle) : renvoie la durée de la partie
local function privatePart(inst, part, first)
    local ped = PlayerPedId()
    if first then
        stopScene()
        ClearPedTasks(ped)
        local base = poleBase(inst)
        local h = setting(inst, 'h', 0.0) or 0.0
        local x, y = LU.toWorld(base.x, base.y, h, 0.0, C.private.distance or 0.9)
        SetEntityCoordsNoOffset(ped, x, y, (CL.Ground(x, y, base.z) or base.z) + 1.0, false, false, false)
        SetEntityHeading(ped, h)
    end
    local a = C.private.parts[part]
    if not CL.Anim.Load(a.dict) then return 0 end
    TaskPlayAnim(ped, a.dict, a.clip, 3.0, -3.0, -1, 1, 0.0, false, false, false)
    local dur = GetAnimDuration(a.dict, a.clip) or 0
    if dur <= 0 then dur = 15.0 end
    return dur
end

-- ---------------------------------------------------------------- interface (petit panneau à droite)
local ui = { cursor = false, cam = true }
local queue = {}            -- commandes venues de l'interface ou du clavier
local function push(cmd) queue[#queue + 1] = cmd end
local function panel(inst, st)
    local dances = {}
    for i, d in ipairs(C.dances) do dances[i] = { i = i, label = d.label, icon = d.icon, desc = d.desc } end
    CL.SendUI({ action = 'pole', show = true, name = inst.name, dances = dances,
        private = C.private and { label = C.private.label, icon = C.private.icon, desc = C.private.desc } or nil,
        current = st.current, mode = st.mode, auto = st.auto, cam = ui.cam, cursor = ui.cursor, entering = st.entering,
        calib = calib and calib.id == inst.id and { ox = calib.ox, oy = calib.oy, oz = calib.oz, h = calib.h } or nil })
end
local function setCursor(on)
    ui.cursor = on
    SetNuiFocus(on, on)
    if SetNuiFocusKeepInput then SetNuiFocusKeepInput(false) end
end
RegisterNUICallback('pole', function(d, cb)
    if dancing and type(d) == 'table' then push(d) end
    cb({ ok = dancing ~= nil })
end)

-- caméra « spectacle » : tourne doucement autour de la barre
local camAngle = 0.0
local function spectacleCam(inst, dt)
    local base = poleBase(inst)
    camAngle = (camAngle + dt * 14.0) % 360.0
    local r = math.rad(camAngle)
    local from = vector3(base.x + math.sin(r) * 3.3, base.y + math.cos(r) * 3.3, base.z + 1.9)
    CL.Cam.Set(from, vector3(base.x, base.y, base.z + 1.35), 55.0)
end

-- ---------------------------------------------------------------- danser
local function dance(inst)
    local ped = PlayerPedId()
    local me = { id = inst.id, stop = false }
    dancing = me
    queue = {}
    local st = { auto = false, current = 1, mode = 'pole', entering = true }
    local nextAt = 0
    local started = GetGameTimer()
    local last = started
    -- réglage en direct demandé par le staff pour cette barre
    if calib and calib.id ~= inst.id then calib = nil end
    if calib and calib.ox == nil then
        local d = inst.data
        calib.ox, calib.oy, calib.oz, calib.h = d.ox or 0.0, d.oy or 0.0, d.oz or 0.0, d.h or 0.0
    end
    setCursor(true)
    -- montée sur la barre
    local dur = playScene(inst, C.enter, false)
    local enterEnd = GetGameTimer() + math.floor(dur * 1000 * 0.95)
    local part, lastToggle, replayAt = 1, 0, nil
    local function startRoutine(i)
        st.mode, st.current = 'pole', i
        local dd = playScene(inst, C.dances[i], true)
        nextAt = GetGameTimer() + math.floor(dd * 1000)
    end
    local function startPrivate()
        st.auto, st.mode, part = false, 'private', 1
        nextAt = GetGameTimer() + math.floor(privatePart(inst, part, true) * 1000)
    end
    panel(inst, st)
    local dirty = false
    while not me.stop do
        lockControls()
        local now = GetGameTimer()
        local dt = (now - last) / 1000
        last = now
        if IsEntityDead(ped) or IsPedRagdoll(ped) then me.stop, me.reason = true, 'down' break end
        -- la barre ne repousse pas la danseuse
        local _, pole = poleBase(inst)
        if pole then SetEntityNoCollisionEntity(ped, pole, true) end
        checkScene()
        if enterEnd and now >= enterEnd then enterEnd = nil st.entering = false startRoutine(1) dirty = true end
        -- clavier (curseur caché) → mêmes commandes que l'interface
        if not ui.cursor then
            for i, d in ipairs(C.dances) do if pressed(d.key) then push({ cmd = 'dance', i = i }) end end
            if C.private and pressed(C.private.key) then push({ cmd = 'private' }) end
            if pressed(C.autoKey) then push({ cmd = 'auto' }) end
            if pressed(C.cursorKey or 74) then push({ cmd = 'cursor' }) end
            if now - started > 600 then for _, k in ipairs(C.stopKeys) do if pressed(k) then push({ cmd = 'stop' }) end end end
            if calib and calib.id == inst.id then
                local step = IsDisabledControlPressed(0, 21) and 0.05 or 0.01
                if pressed(174) then push({ cmd = 'nudge', axis = 'ox', d = -step }) end
                if pressed(175) then push({ cmd = 'nudge', axis = 'ox', d = step }) end
                if pressed(172) then push({ cmd = 'nudge', axis = 'oy', d = step }) end
                if pressed(173) then push({ cmd = 'nudge', axis = 'oy', d = -step }) end
                if pressed(10) then push({ cmd = 'nudge', axis = 'oz', d = step }) end
                if pressed(11) then push({ cmd = 'nudge', axis = 'oz', d = -step }) end
                if pressed(191) then push({ cmd = 'calibSave' }) end
            end
        end
        -- commandes
        while #queue > 0 do
            local c = table.remove(queue, 1)
            local cmd = c.cmd
            dirty = true
            if cmd == 'stop' then me.stop, me.reason = true, 'exit'
            elseif cmd == 'cursor' then setCursor(not ui.cursor)
            elseif cmd == 'cam' then ui.cam = not ui.cam if not ui.cam then CL.Cam.Stop() end
            elseif not enterEnd and cmd == 'dance' and C.dances[tonumber(c.i) or 0] then st.auto = false startRoutine(tonumber(c.i))
            elseif not enterEnd and cmd == 'private' and C.private and st.mode ~= 'private' then startPrivate()
            elseif not enterEnd and cmd == 'auto' and now - lastToggle > 300 then
                lastToggle = now
                st.auto = not st.auto
                if st.auto and st.mode ~= 'pole' then startRoutine(st.current) end
            elseif cmd == 'nudge' and calib and calib.id == inst.id then
                local lim = c.axis == 'oz' and 1.5 or 1.0
                if c.axis == 'h' then calib.h = ((calib.h or 0) + (tonumber(c.d) or 0)) % 360
                elseif c.axis == 'ox' or c.axis == 'oy' or c.axis == 'oz' then
                    calib[c.axis] = LU.clamp(LU.round((calib[c.axis] or 0) + (tonumber(c.d) or 0), 3), -lim, lim)
                end
                replayAt = now + 150
            elseif cmd == 'calibSave' and calib and calib.id == inst.id then
                TriggerServerEvent('elyzea_loisirs:server:poleCalibSave', calib.token, inst.id, { ox = calib.ox, oy = calib.oy, oz = calib.oz, h = calib.h })
            elseif cmd == 'calibQuit' and calib then calib = nil replayAt = now
            end
        end
        -- réglage modifié : la danse en cours est relancée au nouvel endroit
        if replayAt and now >= replayAt then
            replayAt = nil
            if enterEnd then playScene(inst, C.enter, false)
            elseif st.mode == 'pole' then playScene(inst, C.dances[st.current], true)
            else privatePart(inst, part, true) end
        end
        if not enterEnd then
            if st.mode == 'private' and now >= nextAt then
                part = part % #C.private.parts + 1
                nextAt = now + math.floor(privatePart(inst, part, false) * 1000)
            end
            if st.auto and st.mode == 'pole' and now >= nextAt then startRoutine(st.current % #C.dances + 1) dirty = true end
        end
        if ui.cam and ui.cursor then spectacleCam(inst, dt) elseif CL.Cam.Active() and not ui.cam then CL.Cam.Stop() end
        if not ui.cursor and CL.Cam.Active() then CL.Cam.Stop() end
        if dirty then panel(inst, st) dirty = false end
        Wait(0)
    end
    setCursor(false)
    CL.Cam.Stop()
    CL.SendUI({ action = 'pole', show = false })
    -- descente de la barre (sauf si on a été arrêté par le serveur ou qu'on est tombé)
    if me.reason == 'exit' and st.mode == 'pole' and not enterEnd then
        local ed = playScene(inst, C.exit, false)
        local t0 = GetGameTimer()
        while GetGameTimer() - t0 < ed * 1000 * 0.95 do lockControls() checkScene() Wait(0) end
    end
    stopScene()
    ClearPedTasks(ped)
    dancing = nil
    if calib and calib.id == inst.id then calib = nil end   -- le réglage se termine avec la danse
    Ely.callback.await('loisirs:pole_release', false)
end

-- staff : réglage en direct (lancé depuis le menu admin › Loisirs › Pole dance › Caler en jeu)
RegisterNetEvent('elyzea_loisirs:client:poleCalibrate', function(id, token)
    id = tonumber(id)
    calib = { id = id, token = token }
    if dancing and dancing.id == id then
        local inst = CL.inst[id]
        if inst then local d = inst.data calib.ox, calib.oy, calib.oz, calib.h = d.ox or 0.0, d.oy or 0.0, d.oz or 0.0, d.h or 0.0 end
        push({ cmd = 'refresh' })
    else
        CL.Notify('Réglage de la barre : va à la barre et appuie sur E, le panneau de réglage s\'ouvrira.', 'inform')
    end
end)
RegisterNetEvent('elyzea_loisirs:client:poleCalibSaved', function(ok, msg)
    CL.Notify(msg or (ok and 'Réglage enregistré.' or 'Réglage refusé.'), ok and 'success' or 'error')
end)

RegisterNetEvent('elyzea_loisirs:client:poleStop', function(id)
    if dancing and (not id or dancing.id == tonumber(id)) then dancing.stop, dancing.reason = true, 'server' end
end)

-- ---------------------------------------------------------------- pourboires (billets qui volent jusqu'à la danseuse)
local function flyNotes(fromPed, toPed)
    local T = C.tips
    if not T.note then return end
    local a = GetEntityCoords(fromPed)
    local b = GetEntityCoords(toPed)
    for n = 1, (T.notes or 4) do
        CreateThread(function()
            Wait(n * 120)
            local o = CL.Object(T.note, a.x, a.y, a.z + 0.4, false)
            if not o then return end
            local sx, sy = (math.random() - 0.5) * 0.6, (math.random() - 0.5) * 0.6
            local t0 = GetGameTimer()
            while true do
                local k = (GetGameTimer() - t0) / 900
                if k >= 1 then break end
                local x = a.x + (b.x + sx - a.x) * k
                local y = a.y + (b.y + sy - a.y) * k
                local z = (a.z + 0.4) + ((b.z - 0.6) - (a.z + 0.4)) * k + math.sin(k * math.pi) * 0.8
                SetEntityCoordsNoOffset(o, x, y, z, false, false, false)
                SetEntityRotation(o, k * 540.0, k * 260.0, k * 720.0, 2, true)
                Wait(0)
            end
            Wait(4000)
            CL.Delete(o)
        end)
    end
end
RegisterNetEvent('elyzea_loisirs:client:poleTip', function(id, tipper, dancer)
    local inst = CL.inst[tonumber(id) or -1]
    if not inst or not CL.spawned[inst.id] then return end
    local from, to = CL.PedOf(tipper), CL.PedOf(dancer)
    if tipper == CL.Me() then
        local A = C.tips.anim
        if A then CL.Anim.Play(PlayerPedId(), A, 4.0, math.floor((A.duration or 2.0) * 1000)) end
    end
    if from and to then flyNotes(from, to) end
end)

function M.Interact(inst)
    local st = state[inst.id]
    if st and st.sid ~= CL.Me() then
        local r = Ely.callback.await('loisirs:pole_tip', false, inst.id)
        if not r or r.error then CL.Notify(r and r.error or 'Le serveur ne répond pas.', 'error')
        else CL.Notify(('Tu as lancé %d $ à %s.'):format(r.amount or C.tips.amount, st.name), 'success') end
        return
    end
    if dancing then return end
    local r = Ely.callback.await('loisirs:pole_claim', false, inst.id)
    if not r or r.error then return CL.Notify(r and r.error or 'Le serveur ne répond pas.', 'error') end
    CreateThread(function()
        local ok, err = pcall(dance, inst)
        if not ok then
            print('^1[elyzea_loisirs] pole : ' .. tostring(err) .. '^0')
            stopScene() ClearPedTasks(PlayerPedId()) dancing = nil
            SetNuiFocus(false, false) CL.Cam.Stop()
            CL.SendUI({ action = 'pole', show = false })
            Ely.callback.await('loisirs:pole_release', false)
        end
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if dancing then stopScene() ClearPedTasks(PlayerPedId()) SetNuiFocus(false, false) end
end)
RegisterNetEvent('elyzea:client:playerUnloaded', function() if dancing then dancing.stop, dancing.reason = true, 'unload' end end)
