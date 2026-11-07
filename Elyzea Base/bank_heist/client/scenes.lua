-- =====================================================================
--  BANK HEIST - client : scènes animées du braquage (animations des braquages de GTA Online)
--  Scènes synchronisées en réseau : tout le monde voit le braqueur, son sac et ses outils bouger ensemble.
--    · décryptage : sac posé, ordinateur ouvert, carte insérée (anim@heists@ornate_bank@hack)
--    · C4 : sac, charge posée sur la porte (anim@heists@ornate_bank@thermal_charge)
--    · ramassage : billets / lingots attrapés et glissés dans le sac (anim@heists@ornate_bank@grab_cash)
--    · perceuse : perceuse de coffre en main, étincelles, son (anim@heists@fleeca_bank@drilling)
--  Chaque scène a un repli (animation simple) si le dictionnaire manque : rien ne bloque.
--  Objets créés avec un délai maximal de chargement et toujours supprimés à la fin.
-- =====================================================================
local C = BHC
local S = {}
C.Scenes = S

local BAG = 'hei_p_m_bag_var22_arm_s'

local function obj(model, at)
    local hash = C.LoadModel(model, 3000)
    if not hash then return nil end
    local o = CreateObject(hash, at.x, at.y, at.z, true, true, false)
    SetModelAsNoLongerNeeded(hash)
    if o == 0 then return nil end
    SetEntityCollision(o, false, false)
    return o
end
local function del(list) for _, o in pairs(list or {}) do if o and DoesEntityExist(o) then DeleteEntity(o) end end end

-- Scène réseau : ped + objets (chacun avec son clip), retourne l'identifiant
local function scene(dict, pos, rot, ped, clip, ents, loop, hold)
    local id = NetworkCreateSynchronisedScene(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, 2, hold or false, loop or false, 1065353216, 0, 1.3)
    NetworkAddPedToSynchronisedScene(ped, id, dict, clip, 1.5, -4.0, 1, 16, 1148846080, 0)
    for _, e in ipairs(ents or {}) do
        if e[1] and DoesEntityExist(e[1]) then NetworkAddEntityToSynchronisedScene(e[1], id, dict, e[2], 4.0, -8.0, 1) end
    end
    NetworkStartSynchronisedScene(id)
    return id
end
local function sceneTime(id)
    local local_ = NetworkGetLocalSceneFromNetworkId(id)
    return local_ ~= -1 and GetSynchronizedScenePhase(local_) or 1.0
end
-- Attend la fin d'une scène (phase ≥ fin) ou le délai maximal, en surveillant l'annulation
local function waitScene(id, maxMs, cancel)
    local t = GetGameTimer() + maxMs
    Wait(100)
    while GetGameTimer() < t do
        if cancel and cancel() then return false end
        if sceneTime(id) >= 0.98 then return true end
        Wait(0)
    end
    return true
end

-- ---------------------------------------------------------------------
-- Décryptage : entrée (sac posé, ordinateur sorti), boucle pendant le mini-jeu, sortie
-- ---------------------------------------------------------------------
function S.HackBegin(p)
    local ped = PlayerPedId()
    local dict = 'anim@heists@ornate_bank@hack'
    local h = { ped = ped, props = {} }
    if not C.LoadDict(dict) then
        -- repli : tablette en main
        C.PlayAnim(ped, { dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', name = 'base', flag = 49 })
        h.props.laptop = C.HoldProp('prop_laptop_01a', 60309, vector3(0.025, -0.05, 0.08), vector3(-50.0, 290.0, 0.0))
        h.fallback = true
        return h
    end
    local here = GetEntityCoords(ped)
    local rot = vector3(0.0, 0.0, (p.h or GetEntityHeading(ped)) + 0.0)
    local pos = vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0)
    h.props.bag = obj(BAG, here)
    h.props.laptop = obj('hei_prop_hst_laptop', here)
    h.props.card = obj('hei_prop_heist_card_hack_02', here)
    h.dict, h.pos, h.rot = dict, pos, rot
    local id = scene(dict, pos, rot, ped, 'hack_enter', { { h.props.bag, 'hack_enter_bag' }, { h.props.laptop, 'hack_enter_laptop' }, { h.props.card, 'hack_enter_card' } })
    waitScene(id, 6500)
    h.loop = scene(dict, pos, rot, ped, 'hack_loop', { { h.props.bag, 'hack_loop_bag' }, { h.props.laptop, 'hack_loop_laptop' }, { h.props.card, 'hack_loop_card' } }, true)
    return h
end

function S.HackEnd(h)
    if not h then return end
    if not h.fallback and h.dict and DoesEntityExist(h.ped) and not IsEntityDead(h.ped) then
        local id = scene(h.dict, h.pos, h.rot, h.ped, 'hack_exit', { { h.props.bag, 'hack_exit_bag' }, { h.props.laptop, 'hack_exit_laptop' }, { h.props.card, 'hack_exit_card' } })
        waitScene(id, 4500)
        NetworkStopSynchronisedScene(id)
    end
    if h.loop then NetworkStopSynchronisedScene(h.loop) end
    del(h.props)
    ClearPedTasks(h.ped)
end

-- ---------------------------------------------------------------------
-- C4 : le braqueur sort la charge du sac et la colle sur la porte (durée = plantTime)
-- ---------------------------------------------------------------------
function S.PlantC4(p, model, duration, cancel)
    local ped = PlayerPedId()
    local dict = 'anim@heists@ornate_bank@thermal_charge'
    local props = {}
    local ok = true
    local here = GetEntityCoords(ped)
    if C.LoadDict(dict) then
        props.bag = obj(BAG, here)
        props.charge = C.HoldProp(model, 28422, vector3(0.0, 0.0, 0.0), vector3(0.0, 0.0, 180.0))
        local pos = vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0)
        local id = scene(dict, pos, vector3(0.0, 0.0, (p.h or 0.0) + 0.0), ped, 'thermal_charge', { { props.bag, 'bag_thermal_charge' } })
        local t = GetGameTimer() + duration * 1000
        while GetGameTimer() < t do
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)
            if cancel and cancel() then ok = false break end
            Wait(0)
        end
        NetworkStopSynchronisedScene(id)
    else
        C.PlayAnim(ped, { dict = 'anim@heists@ornate_bank@thermal_charge', name = 'thermal_charge', flag = 0 })
        props.charge = C.HoldProp(model, 28422, vector3(0.0, 0.0, 0.0), vector3(0.0, 0.0, 0.0))
        local t = GetGameTimer() + duration * 1000
        while GetGameTimer() < t do
            if cancel and cancel() then ok = false break end
            Wait(0)
        end
    end
    del(props)
    ClearPedTasks(ped)
    return ok
end

-- ---------------------------------------------------------------------
-- Ramassage : entrée, boucle (tant que le serveur verse dans le sac), sortie
-- ---------------------------------------------------------------------
function S.GrabBegin(kind, target, pile)
    local ped = PlayerPedId()
    local g = { ped = ped, props = {}, kind = kind }
    local dict = kind == 'table' and 'anim@scripted@heist@ig1_table_grab@cash@male@' or 'anim@heists@ornate_bank@grab_cash'
    if not C.LoadDict(dict) then dict = 'anim@heists@ornate_bank@grab_cash' end
    if not C.LoadDict(dict) then
        C.PlayAnim(ped, { dict = 'random@domestic', name = 'pickup_low', flag = 1 })
        g.fallback = true
        return g
    end
    g.dict = dict
    local here = GetEntityCoords(ped)
    g.props.bag = obj(BAG, here)
    -- position de la scène : la cible (chariot ou table), orientée face au joueur
    local tp = target and DoesEntityExist(target) and GetEntityCoords(target) or here
    local th = target and DoesEntityExist(target) and GetEntityHeading(target) or GetEntityHeading(ped)
    g.pos, g.rot = tp, vector3(0.0, 0.0, th)
    if dict == 'anim@heists@ornate_bank@grab_cash' then
        g.props.pile = obj(pile or 'hei_prop_heist_cash_pile', here)
        if g.props.pile then AttachEntityToEntity(g.props.pile, ped, GetPedBoneIndex(ped, 60309), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 0, true) SetEntityVisible(g.props.pile, false, false) end
        local id = scene(dict, g.pos, g.rot, ped, 'intro', { { g.props.bag, 'bag_intro' } })
        waitScene(id, 2500)
        g.loopClip, g.bagClip, g.exitClip, g.bagExit = 'grab', 'bag_grab', 'exit', 'bag_exit'
    else
        local id = scene(dict, g.pos, g.rot, ped, 'enter', { { g.props.bag, 'enter_bag' } })
        waitScene(id, 2500)
        g.loopClip, g.bagClip, g.exitClip, g.bagExit = 'grab', 'grab_bag', 'exit', 'exit_bag'
    end
    g.loop = scene(dict, g.pos, g.rot, ped, g.loopClip, { { g.props.bag, g.bagClip } }, true)
    return g
end

-- Liasse visible dans la main à chaque prise (rythme de l'animation)
function S.GrabTick(g)
    if g and g.props.pile and DoesEntityExist(g.props.pile) then
        SetEntityVisible(g.props.pile, true, false)
        SetTimeout(450, function() if g.props.pile and DoesEntityExist(g.props.pile) then SetEntityVisible(g.props.pile, false, false) end end)
    end
end

function S.GrabEnd(g)
    if not g then return end
    if not g.fallback and g.dict and DoesEntityExist(g.ped) and not IsEntityDead(g.ped) then
        local id = scene(g.dict, g.pos, g.rot, g.ped, g.exitClip, { { g.props.bag, g.bagExit } })
        waitScene(id, 2500)
        NetworkStopSynchronisedScene(id)
    end
    if g.loop then NetworkStopSynchronisedScene(g.loop) end
    del(g.props)
    ClearPedTasks(g.ped)
end

-- ---------------------------------------------------------------------
-- Perceuse : en main, étincelles et son pendant le perçage
-- ---------------------------------------------------------------------
function S.DrillBegin(model)
    local ped = PlayerPedId()
    local d = { ped = ped, props = {} }
    local dict = 'anim@heists@fleeca_bank@drilling'
    d.props.drill = C.HoldProp(model or 'hei_prop_heist_drill', 57005, vector3(0.14, 0.0, -0.01), vector3(90.0, -90.0, 180.0))
    if C.LoadDict(dict) then
        d.dict = dict
        TaskPlayAnim(ped, dict, 'drill_straight_idle', 3.0, 3.0, -1, 1, 0.0, false, false, false)
    else
        C.PlayAnim(ped, { dict = 'anim@heists@fleeca_bank@drilling', name = 'drill_straight_idle', flag = 1 })
    end
    d.sound = GetSoundId()
    return d
end

-- pression > 0 : perçage (animation + son + étincelles), 0 : perceuse au repos
function S.DrillPress(d, pressing)
    if not d or d.pressing == pressing then return end
    d.pressing = pressing
    if d.dict then TaskPlayAnim(d.ped, d.dict, pressing and 'drill_straight_start' or 'drill_straight_idle', 3.0, 3.0, -1, 1, 0.0, false, false, false) end
    if pressing then
        if d.props.drill then PlaySoundFromEntity(d.sound, 'Drill', d.props.drill, 'DLC_HEIST_FLEECA_SOUNDSET', true, 0) end
        RequestNamedPtfxAsset('core')
        if HasNamedPtfxAssetLoaded('core') and d.props.drill then
            UseParticleFxAssetNextCall('core')
            d.fx = StartParticleFxLoopedOnEntity('ent_brk_sparking_wires', d.props.drill, 0.0, -0.45, 0.0, 0.0, 0.0, 0.0, 0.8, false, false, false)
        end
    else
        StopSound(d.sound)
        if d.fx then StopParticleFxLooped(d.fx, false) d.fx = nil end
    end
end

function S.DrillEnd(d)
    if not d then return end
    S.DrillPress(d, false)
    ReleaseSoundId(d.sound)
    del(d.props)
    ClearPedTasks(d.ped)
end

-- ---------------------------------------------------------------------
-- Braqueur qui menace le banquier (le temps que le serveur valide)
-- ---------------------------------------------------------------------
function S.Threaten(target)
    local ped = PlayerPedId()
    if target and DoesEntityExist(target) then TaskAimGunAtEntity(ped, target, 2500, false) end
end
