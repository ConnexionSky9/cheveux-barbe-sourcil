-- =========================================================
--  Elyzea - Moteur des animations (client)
--  Joue les animations directement avec les fonctions du jeu (plus aucune commande rpemotes) :
--  animation + drapeaux + durée, 2 objets en main, effets (fumée, flash…) visibles par tous,
--  scénarios, démarches et humeurs gardées, animation de sortie, animations à deux
--  (accroché au partenaire ou placé devant lui, comme rpemotes-reborn).
--  rpemotes peut rester installé : il fournit seulement les fichiers d'animations et d'objets.
-- =========================================================
ElyEngine = {}
local E = ElyEngine

E.Config = {
    FxKey         = 'G',     -- effet de l'animation (fumée, flash, billets…) : maintenir ou appuyer
    BlendIn       = 5.0,
    BlendOut      = 5.0,
    LoadTimeout   = 3000,    -- ms max pour charger une animation / un objet
}

local state = nil        -- animation en cours : { cmd, e, props, token, started, scenario, attached, fx }
local token = 0
local walk = GetResourceKvpString('elyzea_anim_walk')
local mood = GetResourceKvpString('elyzea_anim_mood')
E.onEnded = function() end   -- remplacé par client.lua : animation finie / interrompue toute seule

-- ---------------------------------------------------------
--  Chargements (avec délai max : jamais de blocage)
-- ---------------------------------------------------------
local function waitFor(check)
    local t = GetGameTimer() + E.Config.LoadTimeout
    while not check() do
        if GetGameTimer() > t then return false end
        Wait(0)
    end
    return true
end

function E.loadDict(dict)
    if type(dict) ~= 'string' or not DoesAnimDictExist(dict) then return false end
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    return waitFor(function() return HasAnimDictLoaded(dict) end)
end

function E.loadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelInCdimage(hash) then return nil end
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        if not waitFor(function() return HasModelLoaded(hash) end) then return nil end
    end
    return hash
end

local function loadSet(clip)
    if HasAnimSetLoaded(clip) then return true end
    RequestAnimSet(clip)
    return waitFor(function() return HasAnimSetLoaded(clip) end)
end

local function loadPtfx(asset)
    if HasNamedPtfxAssetLoaded(asset) then return true end
    RequestNamedPtfxAsset(asset)
    return waitFor(function() return HasNamedPtfxAssetLoaded(asset) end)
end

local function isScenario(e) return type(e.d) == 'string' and e.d:find('Scenario') ~= nil end
E.isScenario = isScenario

-- ---------------------------------------------------------
--  Peut-on jouer cette animation maintenant ?
-- ---------------------------------------------------------
function E.reason(e, ped)
    ped = ped or PlayerPedId()
    if not e then return 'Animation inconnue' end
    if IsEntityDead(ped) or LocalPlayer.state.emsDown then return 'Impossible : tu es à terre' end
    if LocalPlayer.state.cuffed then return 'Impossible : tu es menotté' end
    local inVeh = IsPedInAnyVehicle(ped, false)
    if e.v and not inVeh then return 'Cette animation se fait seulement dans un véhicule' end
    if (e.n or isScenario(e)) and inVeh then return 'Impossible dans un véhicule' end
    if e.d == 'MaleScenario' and not IsPedMale(ped) then return 'Animation réservée aux personnages masculins' end
    if IsPedSwimming(ped) or IsPedFalling(ped) or IsPedRagdoll(ped) then return 'Impossible pour le moment' end
end

-- ---------------------------------------------------------
--  Objets et effets
-- ---------------------------------------------------------
local function attachProps(ped, list, out, alive, opts)
    opts = opts or {}
    for _, p in ipairs(list or {}) do
        local hash = E.loadModel(p[1])
        if not hash or not alive() or not DoesEntityExist(ped) then break end
        local c = GetEntityCoords(ped)
        local obj = CreateObject(hash, c.x, c.y, c.z + 0.2, opts.network ~= false, true, true)
        SetModelAsNoLongerNeeded(hash)
        if obj and obj ~= 0 then
            SetEntityCollision(obj, false, false)
            AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, p[2]),
                p[3] + 0.0, p[4] + 0.0, p[5] + 0.0, p[6] + 0.0, p[7] + 0.0, p[8] + 0.0,
                true, true, false, true, 1, true)
            if opts.alpha then SetEntityAlpha(obj, opts.alpha, false) end
            out[#out + 1] = obj
        end
    end
end
E.attachProps = attachProps

local function deleteProps(list)
    for i = #list, 1, -1 do
        local obj = list[i]
        if obj and DoesEntityExist(obj) then
            DetachEntity(obj, true, false)
            SetEntityAsMissionEntity(obj, true, true)
            DeleteEntity(obj)
        end
        list[i] = nil
    end
end
E.deleteProps = deleteProps

local function fxStop(st)
    if st and st.fx then
        StopParticleFxLooped(st.fx, false)
        st.fx = nil
    end
end

local function fxStart(st)
    if not st or st.fx or not st.e.fx then return end
    local fx = st.e.fx
    if not loadPtfx(fx.asset) or state ~= st then return end
    local ped = PlayerPedId()
    local target = (fx.noProp or not st.props[1] or not DoesEntityExist(st.props[1])) and ped or st.props[1]
    local pl = fx.pl or {}
    local x, y, z = (pl[1] or 0) + 0.0, (pl[2] or 0) + 0.0, (pl[3] or 0) + 0.0
    local rx, ry, rz = (pl[4] or 0) + 0.0, (pl[5] or 0) + 0.0, (pl[6] or 0) + 0.0
    local scale = (pl[7] or 1) + 0.0
    UseParticleFxAssetNextCall(fx.asset)
    local h
    if fx.bone and target == ped then
        h = StartNetworkedParticleFxLoopedOnEntityBone(fx.name, ped, x, y, z, rx, ry, rz, GetPedBoneIndex(ped, fx.bone), scale, false, false, false)
    else
        h = StartNetworkedParticleFxLoopedOnEntity(fx.name, target, x, y, z, rx, ry, rz, scale, false, false, false)
    end
    if h and h ~= 0 then
        if fx.col and #fx.col > 0 then
            local c = fx.col[math.random(#fx.col)]
            SetParticleFxLoopedColour(h, c[1] / 255.0, c[2] / 255.0, c[3] / 255.0, false)
            SetParticleFxLoopedAlpha(h, (c[4] or 1) + 0.0)
        end
        st.fx = h
    end
end

-- Touche d'effet : maintenir (fumée…) ou appuyer (effet court)
RegisterCommand('+elyzea_anim_fx', function()
    local st = state
    if not st or not st.e.fx or st.fx then return end
    if ElyAnim and ElyAnim.isPlacing and ElyAnim.isPlacing() then return end   -- G = « poser au sol » pendant le placement
    local fx = st.e.fx
    CreateThread(function()
        fxStart(st)
        if not fx.hold then
            Wait((fx.wait and fx.wait > 0) and fx.wait or 1500)
            fxStop(st)
        end
    end)
end, false)
RegisterCommand('-elyzea_anim_fx', function()
    local st = state
    if st and st.e.fx and st.e.fx.hold then fxStop(st) end
end, false)
RegisterKeyMapping('+elyzea_anim_fx', 'Elyzea animations : effet de l\'animation (fumée, flash…)', 'keyboard', E.Config.FxKey)

-- ---------------------------------------------------------
--  Arrêt
-- ---------------------------------------------------------
local function playExit(ped, name)
    local x = ElyzeaExits and ElyzeaExits[name]
    if not x or not x.d or not x.a then return false end
    if not E.loadDict(x.d) then return false end
    if x.sd then Wait(math.min(x.sd, 1500)) end
    TaskPlayAnim(ped, x.d, x.a, E.Config.BlendIn, E.Config.BlendOut, x.t or -1, x.f or 0, 0.0, false, false, false)
    RemoveAnimDict(x.d)
    return true
end

-- opts : noExit (pas d'animation de sortie), keepTask (l'animation est déjà finie / remplacée)
local function cleanup(st, opts)
    opts = opts or {}
    local ped = PlayerPedId()
    fxStop(st)
    deleteProps(st.props)
    if st.attached then
        st.attached = nil
        if IsEntityAttached(ped) then DetachEntity(ped, true, false) end
    end
    if opts.keepTask then return end
    if IsEntityDead(ped) then return end
    if st.e.x and not opts.noExit and not IsPedInAnyVehicle(ped, false) then
        CreateThread(function() if not playExit(ped, st.e.x) then ClearPedTasks(ped) end end)
    elseif st.scenario then
        ClearPedTasks(ped)
    elseif st.e.d and st.e.a then
        StopAnimTask(ped, st.e.d, st.e.a, 1.0)
    end
end

function E.stop(opts)
    token = token + 1
    local st = state
    state = nil
    if st then cleanup(st, opts) return true end
    return false
end

-- ---------------------------------------------------------
--  Lecture
-- ---------------------------------------------------------
local function watch(st)
    CreateThread(function()
        Wait(1000)
        while state == st do
            local ped = PlayerPedId()
            local ended = nil
            if IsEntityDead(ped) then
                ended = 'dead'
            elseif st.scenario then
                if not IsPedUsingAnyScenario(ped) then ended = 'finished' end
            elseif not IsEntityPlayingAnim(ped, st.e.d, st.e.a, 3) then
                -- Animation courte terminée avec un objet en main (cigarette allumée…) : on garde l'objet jusqu'à X
                local holding = (#st.props > 0 or st.e.fx ~= nil) and st.e.t ~= nil
                if holding then
                    if IsPedRagdoll(ped) or IsPedSwimming(ped) then ended = 'interrupted' end
                else
                    ended = ((st.e.f or 0) % 2 == 1) and 'interrupted' or 'finished'
                end
            end
            if ended then
                if state == st then
                    state = nil
                    token = token + 1
                    cleanup(st, { keepTask = true })
                    E.onEnded(st.cmd, ended)
                end
                break
            end
            Wait(250)
        end
    end)
end

-- opts : partner (ped), at (accroche) — utilisés par les animations à deux
function E.play(cmd, opts)
    opts = opts or {}
    local e = ElyzeaAnims[cmd]
    if not e or e.k ~= 'e' then return false, 'Animation inconnue' end
    local ped = PlayerPedId()
    local why = E.reason(e, ped)
    if why then return false, why end

    token = token + 1
    local my = token
    local alive = function() return token == my end
    -- Chargement AVANT de toucher à l'animation en cours : si ça échoue, rien ne change
    if not isScenario(e) then
        if not E.loadDict(e.d) then return false, 'Animation indisponible (fichier absent : vérifie rpemotes)' end
        if not alive() then return false end
    end
    local prev = state
    state = nil
    if prev then cleanup(prev, { keepTask = true }) end
    local st = { cmd = cmd, e = e, props = {}, token = my, started = GetGameTimer() }

    if isScenario(e) then
        ClearPedTasks(ped)
        if e.d == 'ScenarioObject' then
            local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, -0.5, -0.5)
            TaskStartScenarioAtPosition(ped, e.a, pos.x, pos.y, pos.z, GetEntityHeading(ped), 0, true, false)
        else
            TaskStartScenarioInPlace(ped, e.a, 0, true)
        end
        st.scenario = true
    else
        if prev and prev.scenario then ClearPedTasks(ped) end
        if e.sd then
            Wait(math.min(e.sd, 1500))
            if not alive() then return false end
            if not HasAnimDictLoaded(e.d) and not E.loadDict(e.d) then return false, 'Animation indisponible' end
        end
        local flag = e.f or 0
        if IsPedInAnyVehicle(ped, false) then flag = e.fb and 35 or 51 end
        if opts.partner and e.at then flag = flag | 1 end   -- accroché : l'animation doit tourner en boucle
        TaskPlayAnim(ped, e.d, e.a, E.Config.BlendIn, E.Config.BlendOut, e.t or -1, flag, 0.0, false, false, false)
        RemoveAnimDict(e.d)
    end
    state = st

    if opts.partner and opts.at and DoesEntityExist(opts.partner) then
        local at = opts.at
        AttachEntityToEntity(ped, opts.partner, GetPedBoneIndex(opts.partner, at[1]),
            at[2] + 0.0, at[3] + 0.0, at[4] + 0.0, at[5] + 0.0, at[6] + 0.0, at[7] + 0.0,
            false, false, false, true, 1, true)
        st.attached = opts.partner
    end

    if e.p then attachProps(ped, e.p, st.props, function() return state == st end) end
    if state ~= st then deleteProps(st.props) return false end
    watch(st)
    return true
end

-- Animation à deux : isSource = celui qui a demandé (il se place devant l'autre, comme rpemotes)
function E.playShared(cmd, partnerSid, isSource)
    local e = ElyzeaAnims['nearby_' .. tostring(cmd)]
    if not e then return false, 'Animation inconnue' end
    local pl = GetPlayerFromServerId(partnerSid)
    local other = pl ~= -1 and GetPlayerPed(pl) or 0
    if other == 0 or not DoesEntityExist(other) then return false, 'Ton partenaire n\'est plus là' end
    local ped = PlayerPedId()
    local why = E.reason(e, ped)
    if why then return false, why end
    local partnerRole = ElyzeaAnims['nearby_' .. tostring(ElyzeaSharedPartners[cmd] or cmd)]
    if not e.at and isSource and not (partnerRole and partnerRole.at) then
        local so = e.so or { 0, 1, 0, 180 }
        local c = GetOffsetFromEntityInWorldCoords(other, so[1] + 0.0, so[2] + 0.0, so[3] + 0.0)
        SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
        SetEntityHeading(ped, (GetEntityHeading(other) - so[4]) % 360.0)
    end
    return E.play('nearby_' .. cmd, { partner = other, at = e.at })
end

-- ---------------------------------------------------------
--  Démarches et humeurs (gardées, remises après réapparition)
-- ---------------------------------------------------------
function E.setWalk(cmd, ped)
    ped = ped or PlayerPedId()
    local e = ElyzeaAnims[cmd]
    if not e or e.k ~= 'w' then return false, 'Démarche inconnue' end
    if e.reset then
        ResetPedMovementClipset(ped, 0.25)
        walk = nil
        DeleteResourceKvp('elyzea_anim_walk')
        return true
    end
    if not loadSet(e.d) then return false, 'Démarche indisponible' end
    SetPedMovementClipset(ped, e.d, 0.25)
    RemoveAnimSet(e.d)
    walk = cmd
    SetResourceKvp('elyzea_anim_walk', cmd)
    return true
end

function E.setMood(cmd, ped)
    ped = ped or PlayerPedId()
    local e = ElyzeaAnims[cmd]
    if not e or e.k ~= 'm' then return false, 'Humeur inconnue' end
    if e.reset then
        ClearFacialIdleAnimOverride(ped)
        mood = nil
        DeleteResourceKvp('elyzea_anim_mood')
        return true
    end
    SetFacialIdleAnimOverride(ped, e.d, 0)
    mood = cmd
    SetResourceKvp('elyzea_anim_mood', cmd)
    return true
end

function E.reapply()
    local ped = PlayerPedId()
    if walk and ElyzeaAnims[walk] then E.setWalk(walk, ped) end
    if mood and ElyzeaAnims[mood] then E.setMood(mood, ped) end
end

CreateThread(function()
    local last = 0
    while true do
        local ped = PlayerPedId()
        if ped ~= last and DoesEntityExist(ped) then
            last = ped
            Wait(1500)
            if PlayerPedId() == ped then E.reapply() end
        end
        Wait(1000)
    end
end)
AddEventHandler('playerSpawned', function() SetTimeout(1500, E.reapply) end)

-- ---------------------------------------------------------
function E.current() return state and state.cmd or nil end
function E.hasFx() return state ~= nil and state.e.fx ~= nil end
function E.isPlaying(cmd)
    local st = state
    if not st or (cmd and st.cmd ~= cmd) then return false end
    local ped = PlayerPedId()
    if st.scenario then return IsPedUsingAnyScenario(ped) end
    return IsEntityPlayingAnim(ped, st.e.d, st.e.a, 3) or #st.props > 0
end

-- Exports pour les autres ressources
exports('PlayEmote', function(cmd) return E.play(cmd) end)
exports('CancelEmote', function() return E.stop() end)
exports('IsInEmote', function() return state ~= nil end)
exports('CurrentEmote', function() return E.current() end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    local st = state
    state = nil
    if st then cleanup(st, { noExit = true }) end
end)
