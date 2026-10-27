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

-- ---------------------------------------------------------------- scènes synchronisées
-- origine des animations = pied de la barre + décalage (config + réglage de la barre), tournée selon la barre
local function origin(inst)
    local d = inst.data
    local off = C.sceneOffset or vector3(0.0, 0.0, 0.0)
    local x, y = LU.toWorld(d.x, d.y, d.h or 0.0, off.x + (d.ox or 0.0), off.y + (d.oy or 0.0))
    return vector3(x, y, d.z + off.z + (d.oz or 0.0)), (d.h or 0.0)
end

local scene
local function stopScene()
    if scene then NetworkStopSynchronisedScene(scene) scene = nil end
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
    local dur = GetAnimDuration(a.dict, a.clip) or 0
    if dur <= 0 then dur = 8.0 end
    return dur / (C.sceneSpeed or 1.0)
end

local function lockControls()
    CL.Anim.LockControls()
    for _, c in ipairs({ 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 37, 44, 45, 47, 140, 141, 142, 143, 157, 158, 159, 160, 161, 162, 163, 164, 165 }) do
        DisableControlAction(0, c, true)
    end
end
local function pressed(k) return IsDisabledControlJustPressed(0, k) end

local function keysHelp(auto)
    local k = {}
    for i, d in ipairs(C.dances) do k[#k + 1] = ('%d : %s'):format(i, d.label) end
    if C.private then k[#k + 1] = ('4 : %s'):format(C.private.label) end
    k[#k + 1] = ('5 : enchaînement auto %s'):format(auto and '(activé)' or '')
    k[#k + 1] = 'RETOUR / E : descendre'
    return k
end

-- danse sensuelle debout, devant la barre (3 parties enchaînées en boucle) : renvoie la durée de la partie
local function privatePart(inst, part, first)
    local ped = PlayerPedId()
    if first then
        stopScene()
        ClearPedTasks(ped)
        local d = inst.data
        local h = d.h or 0.0
        local x, y = LU.toWorld(d.x, d.y, h, 0.0, C.private.distance or 0.9)
        SetEntityCoordsNoOffset(ped, x, y, (CL.Ground(x, y, d.z) or d.z) + 1.0, false, false, false)
        SetEntityHeading(ped, h)
    end
    local a = C.private.parts[part]
    if not CL.Anim.Load(a.dict) then return 0 end
    TaskPlayAnim(ped, a.dict, a.clip, 3.0, -3.0, -1, 1, 0.0, false, false, false)
    local dur = GetAnimDuration(a.dict, a.clip) or 0
    if dur <= 0 then dur = 15.0 end
    return dur
end

-- ---------------------------------------------------------------- danser
local function dance(inst)
    local ped = PlayerPedId()
    local me = { id = inst.id, stop = false }
    dancing = me
    local auto, current, mode = false, 1, 'pole'
    local nextAt = 0
    local started = GetGameTimer()
    -- montée sur la barre
    local dur = playScene(inst, C.enter, false)
    local enterEnd = GetGameTimer() + math.floor(dur * 1000 * 0.95)
    local part, lastToggle = 1, 0
    local function startRoutine(i)
        mode, current = 'pole', i
        local dd = playScene(inst, C.dances[i], true)
        nextAt = GetGameTimer() + math.floor(dd * 1000)
    end
    while not me.stop do
        lockControls()
        local now = GetGameTimer()
        if IsEntityDead(ped) or IsPedRagdoll(ped) then me.stop, me.reason = true, 'down' break end
        if enterEnd and now >= enterEnd then enterEnd = nil startRoutine(1) end
        if not enterEnd then
            for i, d in ipairs(C.dances) do if pressed(d.key) then auto = false startRoutine(i) end end
            if C.private and pressed(C.private.key) and mode ~= 'private' then
                auto, mode, part = false, 'private', 1
                nextAt = GetGameTimer() + math.floor(privatePart(inst, part, true) * 1000)
            end
            if mode == 'private' and GetGameTimer() >= nextAt then
                part = part % #C.private.parts + 1
                nextAt = GetGameTimer() + math.floor(privatePart(inst, part, false) * 1000)
            end
            if pressed(C.autoKey) and now - (lastToggle or 0) > 300 then
                lastToggle = now
                auto = not auto
                if auto and mode ~= 'pole' then startRoutine(current) end
            end
            if auto and mode == 'pole' and now >= nextAt then startRoutine(current % #C.dances + 1) end
        end
        if now - started > 600 then
            for _, k in ipairs(C.stopKeys) do if pressed(k) then me.stop, me.reason = true, 'exit' end end
        end
        CL.SendUI({ action = 'controls', show = true, game = 'pole',
            hint = enterEnd and '💃 Tu montes sur la barre…' or (mode == 'private' and ('💃 ' .. C.private.label) or ('💃 ' .. C.dances[current].label)),
            info = auto and 'Enchaînement automatique des routines' or 'Choisis une danse', keys = keysHelp(auto) })
        Wait(0)
    end
    CL.SendUI({ action = 'controls', show = false })
    -- descente de la barre (sauf si on a été arrêté par le serveur ou qu'on est tombé)
    if me.reason == 'exit' and mode == 'pole' and not enterEnd then
        local ed = playScene(inst, C.exit, false)
        local t0 = GetGameTimer()
        while GetGameTimer() - t0 < ed * 1000 * 0.95 do lockControls() Wait(0) end
    end
    stopScene()
    ClearPedTasks(ped)
    dancing = nil
    Ely.callback.await('loisirs:pole_release', false)
end

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
            CL.SendUI({ action = 'controls', show = false })
            Ely.callback.await('loisirs:pole_release', false)
        end
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if dancing then stopScene() ClearPedTasks(PlayerPedId()) end
end)
RegisterNetEvent('elyzea:client:playerUnloaded', function() if dancing then dancing.stop, dancing.reason = true, 'unload' end end)
