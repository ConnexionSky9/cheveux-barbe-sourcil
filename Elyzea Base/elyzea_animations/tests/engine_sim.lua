-- =========================================================
--  ELYZEA ANIMATIONS - simulation du moteur (hors jeu)
--  Le vrai client_engine.lua + client.lua tournent avec des natives simulées qui notent
--  tout ce qui est demandé au jeu (animation, drapeau, durée, objets, effets, attaches, démarches…).
--  TOUTES les animations du menu sont lancées puis arrêtées une par une.
--  Lancer : python3 tests/run_engine_sim.py
--  Ne remplace pas un essai en jeu : ici on vérifie ce qui est DEMANDÉ au jeu, pas le rendu.
-- =========================================================
local PASS, FAIL = 0, 0
local function check(cond, label)
    if cond then PASS = PASS + 1 print('  ok   ' .. label) else FAIL = FAIL + 1 print('  ÉCHEC ' .. label) end
end
local function section(t) print('\n[' .. t .. ']') end

json = { encode = pyjson_encode, decode = pyjson_decode }
setmetatable(_G, { __index = function(_, k) if type(k) == 'string' and k:match('^%u') then return function() end end end })

local vec = {}
vec.__index = vec
vec.__sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, vec) end
vec.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
local function v3(x, y, z) return setmetatable({ x = x, y = y, z = z or 0 }, vec) end

-- ---------------------------------------------------------------- monde simulé
local ME, OTHER = 100, 200
local NOW = 0
local W
local function reset()
    W = { anim = {}, scen = {}, objects = {}, attach = {}, pos = { [ME] = v3(0, 0, 30), [OTHER] = v3(1, 0, 30) }, head = { [ME] = 0.0, [OTHER] = 90.0 },
          veh = false, male = true, dead = false, missing = {}, fx = {}, nextFx = 1, clipset = nil, face = nil, kvp = {}, nui = {},
          nextObj = 5000, tasks = 0, cleared = 0, log = {} }
    LocalPlayer = { state = {} }
end
reset()
function GetGameTimer() return NOW end
function PlayerPedId() return ME end
function PlayerId() return 1 end
function GetActivePlayers() return { 1, 2 } end
function GetPlayerPed(pid) return pid == 1 and ME or pid == 2 and OTHER or 0 end
function GetPlayerServerId(pid) return pid end
function GetPlayerFromServerId(sid) return (sid == 1 or sid == 2) and sid or -1 end
function GetEntityCoords(e) return W.pos[e] or v3(0, 0) end
function GetEntityHeading(e) return W.head[e] or 0.0 end
function SetEntityHeading(e, h) W.head[e] = h end
function SetEntityCoordsNoOffset(e, x, y, z) W.pos[e] = v3(x, y, z) end
function GetOffsetFromEntityInWorldCoords(e, x, y, z) local p = W.pos[e] return v3(p.x + x, p.y + y, p.z + z) end
function IsPedInAnyVehicle() return W.veh end
function IsPedMale() return W.male end
function IsEntityDead() return W.dead end
function IsPedSwimming() return false end
function IsPedFalling() return false end
function IsPedRagdoll() return W.ragdoll == true end
function DoesAnimDictExist(d) return not W.missing[d] end
function HasAnimDictLoaded() return true end
function IsModelInCdimage() return true end
function HasModelLoaded() return true end
function HasAnimSetLoaded() return true end
function HasNamedPtfxAssetLoaded() return true end
function GetHashKey(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 4294967296 end return h end
function GetPedBoneIndex(_, bone) return bone end
function TaskPlayAnim(ped, d, a, bi, bo, dur, flag)
    W.anim[ped] = { d = d, a = a, dur = dur, flag = flag, bi = bi, bo = bo }
    W.scen[ped] = nil
    W.tasks = W.tasks + 1
end
function IsEntityPlayingAnim(ped, d, a) local x = W.anim[ped] return x ~= nil and x.d == d and x.a == a end
function StopAnimTask(ped, d, a) local x = W.anim[ped] if x and x.d == d and x.a == a then W.anim[ped] = nil end end
function ClearPedTasks(ped) W.anim[ped] = nil W.scen[ped] = nil W.cleared = W.cleared + 1 end
ClearPedTasksImmediately = ClearPedTasks
function TaskStartScenarioInPlace(ped, name) W.scen[ped] = { name = name, at = false } W.anim[ped] = nil end
function TaskStartScenarioAtPosition(ped, name) W.scen[ped] = { name = name, at = true } W.anim[ped] = nil end
function IsPedUsingAnyScenario(ped) return W.scen[ped] ~= nil end
function IsPedUsingScenario(ped, n) return W.scen[ped] ~= nil and W.scen[ped].name == n end
function CreateObject(hash, x, y, z, net) W.nextObj = W.nextObj + 1 W.objects[W.nextObj] = { model = hash, net = net } return W.nextObj end
function DoesEntityExist(e) return e == ME or e == OTHER or (W.objects[e] ~= nil) end
function AttachEntityToEntity(e, to, bone, x, y, z, rx, ry, rz)
    if W.objects[e] then W.objects[e].to = to W.objects[e].bone = bone W.objects[e].off = { x, y, z, rx, ry, rz }
    else W.attach[e] = { to = to, bone = bone, off = { x, y, z, rx, ry, rz } } end
end
function IsEntityAttached(e) return W.attach[e] ~= nil end
function DetachEntity(e) if W.objects[e] then W.objects[e].to = nil else W.attach[e] = nil end end
function DeleteEntity(e) W.objects[e] = nil end
function UseParticleFxAssetNextCall(a) W.fxAsset = a end
function StartNetworkedParticleFxLoopedOnEntity(name, ent) local h = W.nextFx W.nextFx = h + 1 W.fx[h] = { name = name, ent = ent, asset = W.fxAsset } return h end
function StartNetworkedParticleFxLoopedOnEntityBone(name, ent, x, y, z, rx, ry, rz, bone) local h = W.nextFx W.nextFx = h + 1 W.fx[h] = { name = name, ent = ent, bone = bone, asset = W.fxAsset } return h end
function StopParticleFxLooped(h) W.fx[h] = nil end
function SetPedMovementClipset(_, c) W.clipset = c end
function ResetPedMovementClipset() W.clipset = nil end
function SetFacialIdleAnimOverride(_, a) W.face = a end
function ClearFacialIdleAnimOverride() W.face = nil end
function GetResourceKvpString(k) return W.kvp[k] end
function SetResourceKvp(k, v) W.kvp[k] = v end
function DeleteResourceKvp(k) W.kvp[k] = nil end
function GetCurrentResourceName() return 'elyzea_animations' end
function SendNUIMessage(m) W.nui[#W.nui + 1] = m end
function TriggerServerEvent(name, ...) W.log[#W.log + 1] = { name, ... } end

-- Fils : coroutines ; step() fait avancer le temps de 250 ms
local threads = {}
local function spawn(fn)
    local co = coroutine.create(fn)
    local ok, err = coroutine.resume(co)
    if not ok then error(err) end
    if coroutine.status(co) ~= 'dead' then threads[#threads + 1] = co end
    return co
end
function CreateThread(fn) spawn(fn) end
function SetTimeout(_, fn) spawn(fn) end
function Wait() NOW = NOW + 5 if coroutine.isyieldable() then coroutine.yield() end end
local function step(n)
    for _ = 1, n or 1 do
        NOW = NOW + 250
        local cur = threads
        threads = {}
        for _, co in ipairs(cur) do
            local ok, err = coroutine.resume(co)
            if not ok then error(err) end
            if coroutine.status(co) ~= 'dead' then threads[#threads + 1] = co end
        end
    end
end
-- Exécute fn dans un fil et attend qu'il finisse (les chargements rendent la main)
local function run(fn)
    local res
    local co = coroutine.create(function() res = { fn() } end)
    for _ = 1, 2000 do
        local ok, err = coroutine.resume(co)
        if not ok then error(err) end
        if coroutine.status(co) == 'dead' then return table.unpack(res) end
        NOW = NOW + 10
    end
    error('fil jamais terminé (blocage)')
end

local commands, events, nui, exported, keymaps = {}, {}, {}, {}, {}
function RegisterCommand(name, fn) commands[name] = fn end
function RegisterKeyMapping(cmd, _, _, key) keymaps[cmd] = key end
function RegisterNetEvent(name, fn) if fn then events[name] = fn end end
local listeners = {}
function AddEventHandler(name, fn)
    listeners[name] = listeners[name] or {}
    table.insert(listeners[name], fn)
    events[name] = function(...) for _, f in ipairs(listeners[name]) do f(...) end end
end
function RegisterNUICallback(name, fn) nui[name] = fn end
exports = setmetatable({}, { __call = function(_, name, fn) exported[name] = fn end })

for _, f in ipairs({ 'anim_data.lua', 'shared_emotes.lua', 'interactions.lua', 'client_engine.lua', 'client.lua', 'client_interactions.lua' }) do
    local chunk, err = load(read_fivem(f), '@' .. f)
    assert(chunk, err)
    chunk()
end
local E = ElyEngine
local function objectsOn(ped) local n = 0 for _, o in pairs(W.objects) do if o.to == ped then n = n + 1 end end return n end
local function objectCount() local n = 0 for _ in pairs(W.objects) do n = n + 1 end return n end
local function fxCount() local n = 0 for _ in pairs(W.fx) do n = n + 1 end return n end

-- =========================================================
section('Données')
local menu = MENU_ITEMS   -- fourni par le lanceur Python (html/emotes.js)
local inMenu, missing = {}, {}
for _, cmd in ipairs(menu) do
    inMenu[cmd] = true
    if not ElyzeaAnims[cmd] then missing[#missing + 1] = cmd end
end
check(#missing == 0, ('chaque animation du menu existe dans anim_data.lua (%d dans le menu)'):format(#menu) .. (#missing > 0 and (' : manque ' .. table.concat(missing, ', ')) or ''))
local notInMenu = {}
for cmd in pairs(ElyzeaAnims) do if not inMenu[cmd] then notInMenu[#notInMenu + 1] = cmd end end
check(#notInMenu == 0, 'chaque animation de anim_data.lua est dans le menu' .. (#notInMenu > 0 and (' : ' .. table.concat(notInMenu, ', ')) or ''))
local badExit, badProp, badFx, badShared = {}, {}, {}, {}
for cmd, e in pairs(ElyzeaAnims) do
    if e.x and not ElyzeaExits[e.x] then badExit[#badExit + 1] = cmd .. '->' .. e.x end
    for _, p in ipairs(e.p or {}) do
        if type(p[1]) ~= 'string' or #p ~= 8 then badProp[#badProp + 1] = cmd end
        for i = 2, 8 do if type(p[i]) ~= 'number' then badProp[#badProp + 1] = cmd end end
    end
    if e.fx and (type(e.fx.asset) ~= 'string' or type(e.fx.name) ~= 'string' or #(e.fx.pl or {}) ~= 7) then badFx[#badFx + 1] = cmd end
    if e.k == 'e' and not e.reset and (type(e.d) ~= 'string' or type(e.a) ~= 'string') then badProp[#badProp + 1] = cmd .. '(d/a)' end
end
for cmd, other in pairs(ElyzeaSharedPartners) do
    if not ElyzeaAnims['nearby_' .. cmd] or not ElyzeaAnims['nearby_' .. other] then badShared[#badShared + 1] = cmd end
end
check(#badExit == 0, 'chaque animation de sortie existe (se relever, ranger…)' .. table.concat(badExit, ' '))
check(#badProp == 0, 'objets : modèle + os + 6 nombres' .. table.concat(badProp, ' '))
check(#badFx == 0, 'effets : asset, nom, placement complet' .. table.concat(badFx, ' '))
check(#badShared == 0, 'animations à deux : les deux rôles existent' .. table.concat(badShared, ' '))

-- =========================================================
section('Toutes les animations, une par une')
local cmds = {}
for cmd, e in pairs(ElyzeaAnims) do if e.k == 'e' then cmds[#cmds + 1] = cmd end end
table.sort(cmds)
local stats = { anim = 0, scen = 0, props = 0, fx = 0, exits = 0, veh = 0 }
local errors = {}
local function err(cmd, msg) if #errors < 25 then errors[#errors + 1] = cmd .. ' : ' .. msg end end
for _, cmd in ipairs(cmds) do
    local e = ElyzeaAnims[cmd]
    reset()
    W.veh = e.v == 1
    W.male = e.d ~= 'MaleScenario' or true
    local ok, why = run(function() return E.play(cmd) end)
    if not ok then
        err(cmd, 'refusée : ' .. tostring(why))
    elseif E.isScenario(e) then
        stats.scen = stats.scen + 1
        if not W.scen[ME] or W.scen[ME].name ~= e.a then err(cmd, 'scénario non lancé') end
        if (e.d == 'ScenarioObject') ~= W.scen[ME].at then err(cmd, 'mauvais type de scénario') end
    else
        stats.anim = stats.anim + 1
        local a = W.anim[ME]
        local wantFlag = e.f or 0
        if W.veh then wantFlag = e.fb and 35 or 51 stats.veh = stats.veh + 1 end
        if not a or a.d ~= e.d or a.a ~= e.a then err(cmd, 'animation non jouée')
        elseif a.flag ~= wantFlag then err(cmd, ('drapeau %s au lieu de %s'):format(a.flag, wantFlag))
        elseif a.dur ~= (e.t or -1) then err(cmd, ('durée %s au lieu de %s'):format(a.dur, e.t or -1)) end
    end
    -- Objets : tous créés, réseau, attachés au bon os avec le bon placement
    local n = #(e.p or {})
    if n > 0 then stats.props = stats.props + 1 end
    if objectsOn(ME) ~= n then err(cmd, ('%d objet(s) au lieu de %d'):format(objectsOn(ME), n)) end
    for _, o in pairs(W.objects) do
        local found = false
        for _, p in ipairs(e.p or {}) do
            if o.model == GetHashKey(p[1]) and o.bone == p[2] and math.abs(o.off[1] - p[3]) < 1e-6 and math.abs(o.off[6] - p[8]) < 1e-6 then found = true end
        end
        if not found then err(cmd, 'objet mal placé') end
        if o.net ~= true then err(cmd, 'objet non visible par les autres (pas en réseau)') end
    end
    -- Effet (touche G)
    if e.fx and ok then
        stats.fx = stats.fx + 1
        commands['+elyzea_anim_fx']()
        local f = W.fx[1]
        if not f or f.name ~= e.fx.name or f.asset ~= e.fx.asset then err(cmd, 'effet non lancé')
        else
            local onProp = W.objects[f.ent] ~= nil
            if e.fx.noProp and onProp then err(cmd, 'effet sur l\'objet au lieu du personnage') end
            if not e.fx.noProp and n > 0 and not onProp then err(cmd, 'effet pas sur l\'objet') end
        end
        commands['-elyzea_anim_fx']()
        step(12)
        if fxCount() ~= 0 then err(cmd, 'effet jamais arrêté') end
    end
    -- Arrêt : objets supprimés, animation coupée ou sortie jouée
    run(function() return E.stop() end)
    step(2)
    if objectCount() ~= 0 then err(cmd, 'objet(s) restés après l\'arrêt') end
    if fxCount() ~= 0 then err(cmd, 'effet resté après l\'arrêt') end
    if e.x and not W.veh then
        stats.exits = stats.exits + 1
        local x = ElyzeaExits[e.x]
        if not W.anim[ME] or W.anim[ME].d ~= x.d then err(cmd, 'animation de sortie non jouée (' .. e.x .. ')') end
    elseif E.isScenario(e) then
        if W.scen[ME] then err(cmd, 'scénario non arrêté') end
    elseif W.anim[ME] then err(cmd, 'animation non arrêtée') end
    if E.current() ~= nil then err(cmd, 'toujours marquée en cours') end
    threads = {}
end
for _, m in ipairs(errors) do print('       ' .. m) end
check(#errors == 0, ('%d animations lancées et arrêtées sans erreur (%d animations, %d scénarios, %d avec objets, %d avec effet, %d avec sortie, %d en véhicule)')
    :format(#cmds, stats.anim, stats.scen, stats.props, stats.fx, stats.exits, stats.veh))

-- =========================================================
section('Démarches et humeurs (toutes)')
local bad = {}
for cmd, e in pairs(ElyzeaAnims) do
    if e.k == 'w' then
        reset()
        local ok = run(function() return E.setWalk(cmd) end)
        if not ok or (e.reset and W.clipset ~= nil) or (not e.reset and W.clipset ~= e.d) then bad[#bad + 1] = cmd end
        if not e.reset and W.kvp.elyzea_anim_walk ~= cmd then bad[#bad + 1] = cmd .. '(non gardée)' end
    elseif e.k == 'm' then
        reset()
        local ok = E.setMood(cmd)
        if not ok or (e.reset and W.face ~= nil) or (not e.reset and W.face ~= e.d) then bad[#bad + 1] = cmd end
    end
end
check(#bad == 0, 'chaque démarche / humeur est appliquée et gardée' .. (#bad > 0 and (' : ' .. table.concat(bad, ', ')) or ''))
reset()
run(function() E.setWalk('walk_Alien') E.setMood('mood_Angry') end)
W.clipset, W.face = nil, nil   -- réapparition : nouveau personnage sans style
run(function() E.reapply() end)
check(W.clipset == ElyzeaAnims.walk_Alien.d and W.face == ElyzeaAnims.mood_Angry.d, 'après réapparition : démarche et humeur remises')
run(function() E.setWalk('walk_reset') E.setMood('mood_reset') end)
check(W.clipset == nil and W.face == nil and W.kvp.elyzea_anim_walk == nil and W.kvp.elyzea_anim_mood == nil, '« Par défaut » / « Neutre » : retour normal, plus rien de gardé')

-- =========================================================
section('Animations à deux (tous les rôles)')
local sharedErr = {}
local nPairs = 0
for cmd, other in pairs(ElyzeaSharedPartners) do
    local e, o = ElyzeaAnims['nearby_' .. cmd], ElyzeaAnims['nearby_' .. other]
    nPairs = nPairs + 1
    reset()
    local ok, why = run(function() return E.playShared(cmd, 2, true) end)
    if not ok then sharedErr[#sharedErr + 1] = cmd .. ' (' .. tostring(why) .. ')'
    else
        if not W.anim[ME] or W.anim[ME].a ~= e.a then sharedErr[#sharedErr + 1] = cmd .. ' : clip' end
        if e.at then
            if not W.attach[ME] or W.attach[ME].to ~= OTHER or W.attach[ME].bone ~= e.at[1] then sharedErr[#sharedErr + 1] = cmd .. ' : pas accroché' end
            if W.anim[ME] and W.anim[ME].flag % 2 ~= 1 then sharedErr[#sharedErr + 1] = cmd .. ' : accroché sans boucle' end
        elseif not (o and o.at) then
            local so = e.so or { 0, 1, 0, 180 }
            local p = W.pos[ME]
            if math.abs(p.x - (1 + so[1])) > 1e-6 or math.abs(p.y - so[2]) > 1e-6 then sharedErr[#sharedErr + 1] = cmd .. ' : mal placé' end
            if math.abs(W.head[ME] - ((90 - so[4]) % 360)) > 1e-6 then sharedErr[#sharedErr + 1] = cmd .. ' : mauvais angle' end
        elseif W.pos[ME].x ~= 0 then sharedErr[#sharedErr + 1] = cmd .. ' : déplacé alors que le partenaire s\'accroche' end
        if objectsOn(ME) ~= #(e.p or {}) then sharedErr[#sharedErr + 1] = cmd .. ' : objets' end
        run(function() E.stop() end)
        if W.attach[ME] or objectCount() > 0 then sharedErr[#sharedErr + 1] = cmd .. ' : reste accroché / objet' end
    end
    -- Rôle de la cible : jamais déplacée (sauf accroche)
    reset()
    ok = run(function() return E.playShared(other, 2, false) end)
    if ok and not o.at and W.pos[ME].x ~= 0 then sharedErr[#sharedErr + 1] = other .. ' (cible) : déplacée' end
    run(function() E.stop() end)
    threads = {}
end
check(#sharedErr == 0, ('%d rôles d\'animations à deux joués, placés / accrochés puis libérés'):format(nPairs) .. (#sharedErr > 0 and (' : ' .. table.concat(sharedErr, ', ')) or ''))
reset()
local okGone, whyGone = run(function() return E.playShared('hug', 9, true) end)
check(not okGone and tostring(whyGone):find('plus là'), 'partenaire parti : rien lancé, message clair')

-- =========================================================
section('Cas particuliers')
reset()
run(function() return E.play('wave') end)
local okSwitch = run(function() return E.play('phone') end)
check(okSwitch and W.anim[ME].d == ElyzeaAnims.phone.d and objectsOn(ME) == 1, 'enchaîner deux animations : la nouvelle remplace l\'ancienne, un seul objet')
W.missing[ElyzeaAnims.dance.d] = true
local okMiss, whyMiss = run(function() return E.play('dance') end)
check(not okMiss and tostring(whyMiss):find('indisponible') and W.anim[ME].d == ElyzeaAnims.phone.d and objectsOn(ME) == 1,
    'fichier absent : refus clair, l\'animation en cours continue avec son objet')
run(function() E.stop() end)

local ncmd
for _, cmd in ipairs(cmds) do if ElyzeaAnims[cmd].n then ncmd = cmd break end end
reset()
W.veh = true
local okV, whyV = run(function() return E.play(ncmd) end)
check(not okV and tostring(whyV):find('véhicule') and W.anim[ME] == nil, 'animation « pas en véhicule » refusée en véhicule (' .. ncmd .. ')')
W.veh = false
local vcmd
for cmd, e in pairs(ElyzeaAnims) do if e.v then vcmd = cmd break end end
okV, whyV = run(function() return E.play(vcmd) end)
check(not okV and tostring(whyV):find('seulement dans un véhicule'), 'animation de véhicule refusée à pied (' .. tostring(vcmd) .. ')')
W.male = false
local mcmd
for cmd, e in pairs(ElyzeaAnims) do if e.d == 'MaleScenario' then mcmd = cmd break end end
okV, whyV = run(function() return E.play(mcmd) end)
check(not okV and tostring(whyV):find('masculins'), 'scénario masculin refusé pour un personnage féminin (' .. tostring(mcmd) .. ')')
reset()
LocalPlayer.state.cuffed = true
okV = run(function() return E.play('wave') end)
check(not okV and W.anim[ME] == nil, 'menotté : rien lancé')
LocalPlayer.state.cuffed = nil

-- Fin naturelle / interruption
reset()
local ended = nil
local prevEnded = E.onEnded
E.onEnded = function(cmd, why) ended = why prevEnded(cmd, why) end
local shortCmd
for _, cmd in ipairs(cmds) do local e = ElyzeaAnims[cmd] if e.t and not e.p and not e.fx and (e.f or 0) % 2 == 0 and not E.isScenario(e) then shortCmd = cmd break end end
run(function() return E.play(shortCmd) end)
W.anim[ME] = nil   -- le jeu a fini l'animation (durée écoulée)
step(8)
check(ended == 'finished' and E.current() == nil, 'animation courte finie toute seule : libérée (' .. shortCmd .. ')')
reset() ended = nil
run(function() return E.play('cig') end)
W.anim[ME] = nil   -- « cig » : allumage fini, la cigarette reste en main
step(8)
check(ended == nil and E.current() == 'cig' and objectsOn(ME) == 1, 'cigarette allumée : l\'objet reste en main jusqu\'à X')
commands['+elyzea_anim_fx']()
check(fxCount() == 1, 'G maintenu : fumée lancée (visible par tous)')
commands['-elyzea_anim_fx']()
check(fxCount() == 0, 'G relâché : fumée arrêtée')
run(function() E.stop() end)
check(objectCount() == 0, 'X : cigarette retirée')
reset() ended = nil
run(function() return E.play('dance') end)
W.anim[ME] = nil   -- une autre ressource a coupé l'animation en boucle
step(8)
check(ended == 'interrupted' and E.current() == nil, 'animation en boucle coupée par autre chose : libérée')
reset() ended = nil
run(function() return E.play('phone') end)
W.dead = true
step(8)
check(ended == 'dead' and objectCount() == 0, 'mort pendant l\'animation : objet retiré, animation libérée')
E.onEnded = prevEnded

-- =========================================================
section('Menu : lancer, arrêter, raccourcis')
reset()
nui.playEmote({ emote = 'wave', type = 'emote', label = 'Wave' }, function() end)
step(1)
check(W.anim[ME] and W.anim[ME].a == ElyzeaAnims.wave.a, 'clic dans le menu : animation jouée')
nui.stopEmote({}, function() end)
check(W.anim[ME] == nil, 'Arrêter : animation coupée')
local stopped = false for _, m in ipairs(W.nui) do if m.action == 'stopped' then stopped = true end end
check(stopped, 'le menu est prévenu de l\'arrêt')
reset()
nui.playEmote({ emote = 'walk_Alien', type = 'walk', label = 'Alien' }, function() end)
step(1)
check(W.clipset == ElyzeaAnims.walk_Alien.d, 'démarche choisie dans le menu : appliquée')
nui.playEmote({ emote = 'mood_Happy', type = 'mood', label = 'Happy' }, function() end)
check(W.face == ElyzeaAnims.mood_Happy.d, 'humeur choisie dans le menu : appliquée')
reset()
W.veh = true
nui.playEmote({ emote = ncmd, type = 'emote', label = 'Sit' }, function() end)
step(1)
local msg = '' for _, m in ipairs(W.nui) do if m.action == 'notify' then msg = msg .. m.text end end
check(W.anim[ME] == nil and msg:find('véhicule'), 'refus expliqué dans le menu (en véhicule)')
reset()
commands.anim(nil, { 'wave' })
step(1)
check(W.anim[ME] and W.anim[ME].a == ElyzeaAnims.wave.a, '/anim wave')
commands.anim(nil, {})
check(W.anim[ME] == nil, '/anim seul : arrêt')
check(keymaps['+elyzea_anim_fx'] == 'G', 'touche d\'effet G enregistrée (modifiable dans les raccourcis GTA)')
check(exported.PlayEmote and exported.CancelEmote and exported.IsInEmote, 'exports pour les autres ressources : PlayEmote, CancelEmote, IsInEmote')

print(('\n%d ok, %d échec(s)'):format(PASS, FAIL))
return FAIL
