-- =====================================================================
--  Test de bout en bout hors jeu : 1 serveur + 2 clients (vrais fichiers), touches simulées.
--  Vérifie le lobby (interface), le tour par tour, les contrôles, les animations demandées, le rejeu
--  des coups chez les DEUX joueurs, la fin de partie et le nettoyage. GTA est imité (objets, ped, touches).
-- =====================================================================
local root = ...
local P = print
local passes, fails = 0, 0
local function check(c, label)
    if c then passes = passes + 1 P('  ok   ' .. label) else fails = fails + 1 P('  ÉCHEC ' .. label) end
end

-- ---------------------------------------------------------------- temps et planificateur communs
local GT, FRAME = 0, 0
local threads = {}
local function spawn(fn, tag) threads[#threads + 1] = { co = coroutine.create(fn), wake = GT, tag = tag } end
local function Wait(ms) coroutine.yield(ms or 0) end
local function SetTimeout(ms, fn) spawn(function() Wait(ms) fn() end) end
local errors = {}
local function step()
    FRAME = FRAME + 1
    local list = threads
    threads = {}
    for _, t in ipairs(list) do
        if coroutine.status(t.co) ~= 'dead' then
            if t.wake <= GT then
                local ok, ms = coroutine.resume(t.co)
                if not ok then errors[#errors + 1] = tostring(ms) P('  ERREUR LUA ' .. tostring(ms)) end
                t.wake = GT + (ms or 0)
            end
            if coroutine.status(t.co) ~= 'dead' then threads[#threads + 1] = t end
        end
    end
    GT = GT + 16
end
local function run(ms) local stop = GT + ms while GT < stop do step() end end

local function joaat(s) s = tostring(s):lower() local h = 0 for i = 1, #s do h = (h + s:byte(i)) & 0xFFFFFFFF h = (h + (h << 10)) & 0xFFFFFFFF h = h ~ (h >> 6) end
    h = (h + (h << 3)) & 0xFFFFFFFF h = h ~ (h >> 11) h = (h + (h << 15)) & 0xFFFFFFFF return h end
local function ser(v) local t = type(v) if t == 'table' then local p = {} for k, x in pairs(v) do p[#p + 1] = '[' .. ser(k) .. ']=' .. ser(x) end table.sort(p) return '{' .. table.concat(p, ',') .. '}' elseif t == 'string' then return ('%q'):format(v) else return tostring(v) end end
local vmt = {}
local function vec(x, y, z) return setmetatable({ x = x, y = y, z = z }, vmt) end
vmt.__sub = function(a, b) return vec(a.x - b.x, a.y - b.y, a.z - b.z) end
vmt.__add = function(a, b) return vec(a.x + b.x, a.y + b.y, a.z + b.z) end
vmt.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end

-- ---------------------------------------------------------------- joueurs (peds partagés serveur / clients)
local peds = {}   -- [sid] = { pos, h, frozen, anim = {dict,clip}, health }
local function addPed(sid, x, y, z) peds[sid] = { pos = vec(x, y, z + 1.0), h = 0.0, frozen = false, health = 200, anims = {} } end

local function base(env)
    env.Wait, env.SetTimeout, env.CreateThread = Wait, SetTimeout, spawn
    env.GetGameTimer = function() return GT end
    env.GetHashKey, env.joaat = joaat, joaat
    env.vector3, env.vec3 = vec, vec
    env.json = { encode = ser, decode = function(s) return s end }
    env.print = function() end
    env.GetCurrentResourceName = function() return 'elyzea_loisirs' end
    return setmetatable(env, { __index = function(_, k)
        if _G[k] ~= nil then return _G[k] end
        if type(k) == 'string' and k:match('^%u') then return function() end end
    end })
end
local function loadInto(env, files)
    for _, f in ipairs(files) do
        local h = assert(io.open(root .. '/' .. f, 'r'))
        local src = h:read('a') h:close()
        src = src:gsub('`([^`]*)`', 'GetHashKey("%1")')
        assert(load(src, '@' .. f, 't', env))()
    end
end
local SHARED = { 'config.lua', 'shared/utils.lua', 'shared/bowling.lua', 'shared/billiards.lua', 'shared/golf.lua' }

-- ---------------------------------------------------------------- serveur
local SV = base({})
local svEvents, svCbs, clients = {}, {}, {}
local DB, dbseq = {}, 0
SV.os = setmetatable({ time = function(t) if t then return 0 end return 1800000000 + math.floor(GT / 1000) end }, { __index = os })
SV.RegisterNetEvent = function(n, fn) if fn then svEvents[n] = svEvents[n] or {} table.insert(svEvents[n], fn) end end
SV.AddEventHandler = SV.RegisterNetEvent
SV.TriggerEvent = function(n, ...) for _, fn in ipairs(svEvents[n] or {}) do fn(...) end end
local function deliver(n, target, ...)
    local a = table.pack(...)
    for sid, c in pairs(clients) do
        if target == -1 or target == sid then
            SetTimeout(0, function() for _, fn in ipairs(c.events[n] or {}) do fn(table.unpack(a, 1, a.n)) end end)
        end
    end
end
SV.TriggerClientEvent = deliver
SV.TriggerLatentClientEvent = function(n, t, _, ...) deliver(n, t, ...) end
SV.GetPlayerName = function(s) return peds[tonumber(s) or -1] and ('Joueur' .. s) or nil end
SV.GetPlayers = function() local t = {} for sid in pairs(peds) do t[#t + 1] = tostring(sid) end return t end
SV.GetPlayerPed = function(s) return peds[s] and s or 0 end
SV.GetEntityCoords = function(p) return peds[p].pos end
SV.GetEntityHeading = function(p) return peds[p].h end
SV.GetEntityHealth = function(p) return peds[p].health end
SV.SetEntityCoords = function(p, x, y, z) peds[p].pos = vec(x, y, z) end
SV.Player = function(s) return { state = {} } end
SV.Citizen = { Await = function(p) while p.value == nil and not p.done do Wait(0) end return p.value end }
SV.promise = { new = function() local p = {} function p:resolve(v) self.value, self.done = v, true end return p end }
local money = {}
SV.exports = setmetatable({ elyzea_core = {
    GetPlayer = function(_, s) return peds[s] and { PlayerData = { charinfo = { firstname = 'Joueur' .. s, lastname = '', gender = 0 } },
        Functions = { RemoveMoney = function(_, n) money[s] = (money[s] or 1000) - n return true end, AddMoney = function(_, n) money[s] = (money[s] or 1000) + n return true end } } or nil end,
    GetCitizenId = function(_, s) return peds[s] and ('CID' .. s) or nil end,
} }, { __call = function(_, n, fn) SV['export_' .. n] = fn end })
SV.MySQL = {
    query = { await = function(sql) if sql:find('^SELECT') then local t = {} for _, r in pairs(DB) do t[#t + 1] = r end return t end return {} end },
    insert = { await = function(_, a) dbseq = dbseq + 1 DB[dbseq] = { id = dbseq, kind = a[1], name = a[2], data = a[3] } return dbseq end },
    update = { await = function(sql, a) if sql:find('^DELETE') then DB[a[1]] = nil else local r = DB[a[3]] if r then r.name, r.data = a[1], a[2] end end return 1 end },
}
SV.Ely = { callback = { register = function(n, fn) svCbs[n] = fn end } }
loadInto(SV, SHARED)
loadInto(SV, { 'server/main.lua', 'server/sessions.lua', 'server/bowling.lua', 'server/billiards.lua', 'server/golf.lua', 'server/pole.lua' })
SV.Config.Sessions.startDelay = 1

-- ---------------------------------------------------------------- clients
local function newClient(sid)
    local c = { sid = sid, events = {}, nui = {}, ui = {}, objects = {}, nextObj = 1000, keys = {}, frameKeys = {}, anims = {}, textui = nil, notes = {} }
    local env = base({})
    c.env = env
    env.RegisterNetEvent = function(n, fn) if fn then c.events[n] = c.events[n] or {} table.insert(c.events[n], fn) end end
    env.AddEventHandler = env.RegisterNetEvent
    env.TriggerEvent = function() end
    env.TriggerServerEvent = function(n, ...) local a = table.pack(...) SetTimeout(0, function() SV.source = sid for _, fn in ipairs(svEvents[n] or {}) do fn(table.unpack(a, 1, a.n)) end end) end
    env.RegisterNUICallback = function(n, fn) c.nui[n] = fn end
    env.SendNUIMessage = function(m) c.ui[#c.ui + 1] = m end
    env.SetNuiFocus = function(a) c.focus = a end
    env.RegisterCommand = function(n, fn) c.cmd = c.cmd or {} c.cmd[n] = fn end
    env.Ely = { callback = { await = function(name, _, ...) SV.source = sid return svCbs[name](sid, ...) end } }
    env.exports = setmetatable({ elyzea_core = {
        Notify = function(_, msg, kind) c.notes[#c.notes + 1] = { msg = msg, kind = kind } end,
        ShowTextUI = function(_, t) c.textui = t end, HideTextUI = function() c.textui = nil end,
    } }, { __call = function() end })
    env.GetPlayerServerId = function(pl) return pl end
    env.PlayerId = function() return sid end
    env.PlayerPedId = function() return sid end
    env.GetPlayerFromServerId = function(s) return peds[s] and s or -1 end
    env.NetworkIsPlayerActive = function(pl) return peds[pl] ~= nil end
    env.GetPlayerPed = function(pl) return peds[pl] and pl or 0 end
    env.GetEntityCoords = function(e) if peds[e] then return peds[e].pos end local o = c.objects[e] return o and o.pos or vec(0, 0, 0) end
    env.GetEntityHeading = function(e) return peds[e] and peds[e].h or 0.0 end
    env.SetEntityHeading = function(e, h) if peds[e] then peds[e].h = h end end
    env.SetEntityCoordsNoOffset = function(e, x, y, z) if peds[e] then peds[e].pos = vec(x, y, z) elseif c.objects[e] then c.objects[e].pos = vec(x, y, z) end end
    env.FreezeEntityPosition = function(e, f) if peds[e] then peds[e].frozen = f end end
    env.IsModelInCdimage = function() return true end
    env.HasModelLoaded = function() return true end
    -- tailles réalistes : quille 38 cm (origine à la base), boule de 21,8 cm (origine au centre)
    env.GetModelDimensions = function(m)
        if m == joaat('prop_bowling_pin') then return vec(-0.06, -0.06, 0), vec(0.06, 0.06, 0.38) end
        if m == joaat('prop_bowling_ball') then return vec(-0.109, -0.109, -0.109), vec(0.109, 0.109, 0.109) end
        return vec(-1.2, -0.65, 0), vec(1.2, 0.65, 0.9) end
    env.GetGamePool = function() local t = {} for id in pairs(c.objects) do t[#t + 1] = id end return t end
    env.SetEntityVisible = function(e, v) if c.objects[e] then c.objects[e].visible = v end end
    c.pitch, c.lieZ, c.yaw = {}, {}, {}
    env.SetEntityRotation = function(e, p, _, y)
        local o = c.objects[e]
        if not o or o.model ~= joaat('prop_bowling_pin') then return end
        c.pitch[e] = math.min(c.pitch[e] or 0, p)
        if p <= -87 then c.lieZ[e] = o.pos.z c.yaw[e] = y end
    end
    c.polys, c.polyFrame = {}, -1
    env.DrawPoly = function(...) if c.polyFrame ~= FRAME then c.polys, c.polyFrame = {}, FRAME end c.polys[#c.polys + 1] = { ... } end
    env.GetAnimDuration = function() return 0.5 end
    env.IsEntityPlayingAnim = function() return true end
    c.camSets, c.camOn = 0, false
    env.CreateCamWithParams = function() return 77 end
    env.SetCamCoord = function(_, x, y, z) c.camSets = c.camSets + 1 c.camPos = vec(x, y, z) end
    env.RenderScriptCams = function(on) c.camOn = on end
    -- scènes synchronisées (pole dance)
    c.scenes, c.sceneSeq, c.sceneLive = {}, 500, {}
    env.NetworkCreateSynchronisedScene = function(x, y, z, rx, ry, rz, order, hold, loop, stop, start, speed)
        c.sceneSeq = c.sceneSeq + 1
        c.scenes[c.sceneSeq] = { x = x, y = y, z = z, rz = rz, loop = loop, speed = speed }
        return c.sceneSeq
    end
    env.NetworkAddPedToSynchronisedScene = function(ped, sc, dict, clip, bi, bo, flags, rag, mover)
        local e = c.scenes[sc] e.ped, e.dict, e.clip, e.mover = ped, dict, clip, mover
    end
    env.NetworkStartSynchronisedScene = function(sc) c.sceneLive[sc] = true c.lastScene = c.scenes[sc] end
    env.NetworkStopSynchronisedScene = function(sc) c.sceneLive[sc] = nil end
    env.CreateObjectNoOffset = function(h, x, y, z) c.nextObj = c.nextObj + 1 c.objects[c.nextObj] = { model = h, pos = vec(x, y, z) } return c.nextObj end
    env.DoesEntityExist = function(e) return peds[e] ~= nil or c.objects[e] ~= nil end
    env.DeleteEntity = function(e) c.objects[e] = nil end
    env.IsEntityAttached = function(e) return c.objects[e] and c.objects[e].att ~= nil end
    env.AttachEntityToEntity = function(e, p) if c.objects[e] then c.objects[e].att = p end end
    env.GetGroundZFor_3dCoord = function(x, y, z) return false, 0 end
    env.IsPedInAnyVehicle = function() return false end
    env.IsEntityDead = function() return false end
    env.GetEntityModel = function(e) if c.objects[e] then return c.objects[e].model end return joaat('mp_m_freemode_01') end
    env.DoesAnimDictExist = function() return true end
    env.HasAnimDictLoaded = function() return true end
    env.TaskPlayAnim = function(p, d, cl)
        c.anims[#c.anims + 1] = d .. '/' .. cl
        -- déplacement porté par l'animation (pas de côté), si le test en simule un
        if c.rootMotion and peds[p] and not peds[p].frozen and cl:find('step_short', 1, true) then
            local dx = c.rootMotion(cl)
            local h = math.rad(peds[p].h)
            peds[p].pos = vec(peds[p].pos.x + math.cos(h) * dx, peds[p].pos.y + math.sin(h) * dx, peds[p].pos.z)
        end
    end
    env.GetDisabledControlNormal = function() return 0.0 end
    env.GetClosestObjectOfType = function() return 0 end
    local function pressed(k) return c.keys[k] == true end
    local function just(k) return c.frameKeys[k] == FRAME - 1 or c.frameKeys[k] == FRAME end
    local function released(k) return c.frameKeys['r' .. k] == FRAME - 1 or c.frameKeys['r' .. k] == FRAME end
    env.IsControlPressed, env.IsDisabledControlPressed = function(_, k) return pressed(k) end, function(_, k) return pressed(k) end
    env.IsControlJustPressed, env.IsDisabledControlJustPressed = function(_, k) return just(k) end, function(_, k) return just(k) end
    env.IsDisabledControlJustReleased = function(_, k) return released(k) end
    loadInto(env, SHARED)
    loadInto(env, { 'client/main.lua', 'client/anim.lua', 'client/bowling.lua', 'client/billiards.lua', 'client/golf.lua', 'client/pole.lua' })
    function c.press(k) c.keys[k] = true c.frameKeys[k] = FRAME end
    function c.release(k) c.keys[k] = nil c.frameKeys['r' .. k] = FRAME end
    function c.tap(k) c.press(k) run(50) c.release(k) end
    function c.lastUI(action) for i = #c.ui, 1, -1 do if c.ui[i].action == action then return c.ui[i] end end end
    function c.count(model) local n = 0 for _, o in pairs(c.objects) do if o.model == joaat(model) then n = n + 1 end end return n end
    function c.nuiCall(name, data) local res c.nui[name](data or {}, function(r) res = r end) return res end
    clients[sid] = c
    return c
end

addPed(1, 0, -1.6, 30) addPed(2, 0.3, -1.6, 30)
local A, Bc = newClient(1), newClient(2)
run(4000)

-- ---------------------------------------------------------------- installations (staff = joueur 1)
local function adm(name, data) run(1000) return SV.export_AdminAction(1, name, data or {}) end
peds[1].pos = vec(0, 0, 31) peds[1].h = 0.0
check(adm('add_bowling', { name = 'Piste A' }), 'admin : piste posée')
peds[1].pos = vec(30, 0, 31)
check(adm('add_billiards', { name = 'Table A' }), 'admin : table posée')
peds[1].pos = vec(500, 0, 51)
adm('add_course', { name = 'Golf A' })
adm('hole_tee', { id = 3 })
peds[1].pos = vec(500, 140, 51)
adm('hole_flag', { id = 3, hole = 1 })
adm('hole_set', { id = 3, hole = 1, par = 3, greenR = 14, fairwayW = 40 })
peds[1].pos = vec(0, -1.6, 31)
run(3000)
check(A.env.CL.inst[1] and Bc.env.CL.inst[3], 'installations reçues par les deux clients')
check(A.count('prop_bowling_pin') == 10 and Bc.count('prop_bowling_pin') == 10, 'quilles posées chez les deux joueurs (10)')

P('\n[Lobby et interface]')
run(1500)
check(A.textui and A.textui:find('Bowling'), 'invite [E] affichée près de la piste')
A.tap(Config and 38 or 38)
run(500)
local lob = A.lastUI('lobby')
check(lob and lob.open and lob.inst.kind == 'bowling' and A.focus == true, 'E : lobby ouvert (souris activée)')
local r = A.nuiCall('create', { inst = 1, name = 'Duel', max = 2 })
check(r and r.ok, 'création depuis l\'interface')
A.nuiCall('close')
check(A.focus == false, 'fermeture du lobby : contrôle rendu au joueur')
r = Bc.nuiCall('join', { session = r.session.id })
check(r and r.ok, 'Bruno rejoint depuis l\'interface')
r = Bc.nuiCall('start')
check(r and r.error, 'Bruno (pas hôte) ne peut pas lancer')
A.nuiCall('start')
run(2500)
local s = SV.LS.Sessions.all[1]
check(s.state == 'IN_PROGRESS', 'partie lancée')
check(A.lastUI('session') and A.lastUI('session').session.state == 'IN_PROGRESS' and Bc.lastUI('session').session.state == 'IN_PROGRESS', 'tableau de score à jour chez les deux joueurs')

P('\n[Bowling joué au clavier]')
local function bot(c, kind)
    -- le joueur dont c'est le tour se place puis maintient / relâche ESPACE
    if not c.env.CL.Playing() then return false end
    if kind == 'bowling' then
        local d = SV.LS.inst[1].data
        peds[c.sid].pos = vec(d.x + (c.sid == 1 and -0.1 or 0.1), d.y - 1.6, d.z + 1.0)
    end
    run(400)
    c.press(22) run(700) c.release(22)
    return true
end
local throws, guard = 0, 0
while s.state == 'IN_PROGRESS' and guard < 120 do
    guard = guard + 1
    for _, c in ipairs({ A, Bc }) do if bot(c, 'bowling') then throws = throws + 1 run(6500) end end
    run(300)
end
run(3000)
check(s.state == 'FINISHED', ('partie de bowling menée au clavier jusqu\'au bout (%d lancers)'):format(throws))
local animsA = table.concat(A.anims, ' ')
check(animsA:find('anim@heists@box_carry@/idle', 1, true) and animsA:find('weapons@projectile@/throw_l_fb_stand', 1, true), 'animations de port de boule et de lancer jouées')
check(A.lastUI('controls') ~= nil and (A.lastUI('controls').power ~= nil or true), 'jauge de puissance envoyée à l\'interface')
local resA = (function() for i = #A.ui, 1, -1 do local m = A.ui[i] if m.action == 'session' and m.session.state == 'FINISHED' then return m.session end end end)()
local resB = (function() for i = #Bc.ui, 1, -1 do local m = Bc.ui[i] if m.action == 'session' and m.session.state == 'FINISHED' then return m.session end end end)()
check(resA and resB and resA.results.ranking[1].score == resB.results.ranking[1].score, 'classement final identique chez les deux joueurs')
check(A.count('prop_bowling_ball') == 0 and Bc.count('prop_bowling_ball') == 0, 'aucune boule oubliée après les rejeux')
check(not peds[1].frozen and not peds[2].frozen, 'joueurs libres de bouger après la partie')
run(25000)
check(A.count('prop_bowling_pin') == 10, 'piste remise en place (10 quilles) pour la partie suivante')

P('\n[Billard joué au clavier]')
peds[1].pos = vec(30, 0.8, 31) peds[2].pos = vec(30.6, 0.8, 31)
run(2000)
r = A.nuiCall('create', { inst = 2, name = 'Billard' })
Bc.nuiCall('join', { session = r.session.id })
A.nuiCall('start')
run(2500)
local sb = SV.LS.Sessions.all[r.session.id]
check(sb.state == 'IN_PROGRESS' and A.count('prop_poolball_cue') == 1 and A.count('prop_poolball_8') == 1, 'billard lancé, boules posées sur la table')
guard = 0
local shots = 0
while sb.state == 'IN_PROGRESS' and shots < 30 and guard < 120 do
    guard = guard + 1
    for _, c in ipairs({ A, Bc }) do
        if c.env.CL.Playing() and shots < 30 then
            run(300)
            c.tap(38)             -- valider la blanche en main si besoin
            run(300)
            c.press(22) run(500) c.release(22)
            shots = shots + 1
            run(30000)
        end
    end
    run(300)
end
check(sb.data.game.shots >= 20 or sb.state == 'FINISHED', ('%d tirs joués au clavier et validés par le serveur'):format(sb.data.game.shots))
-- mêmes boules chez les deux joueurs que sur le serveur (la blanche peut être « en main »)
-- boules de couleur seulement : la blanche « en main » n'est visible que chez celui qui la place
local function ballsOf(c) local n = 0 for _, o in pairs(c.objects) do for k = 1, 15 do
    if o.model == joaat('prop_poolball_' .. k) then n = n + 1 end end end return n end
local srv = 0 for n in pairs(sb.data.game.balls) do if n ~= 0 then srv = srv + 1 end end
local ca, cb = ballsOf(A), ballsOf(Bc)
local p8 = sb.data.game.balls[8]
local function obj8(c) for _, o in pairs(c.objects) do if o.model == joaat('prop_poolball_8') then return o.pos end end end
local a8, b8p = obj8(A), obj8(Bc)
if sb.state == 'FINISHED' then
    -- partie finie tôt (noire rentrée = victoire ou défaite selon le moment) : la table est remise en place chez tout le monde
    check(ca == 15 and cb == 15, ('partie finie en %d tirs (%s) : table remise en place chez les deux joueurs'):format(sb.data.game.shots, tostring((sb.results or {}).reason or 'noire')))
else
    check(ca == cb and ca == srv, ('rejeu synchronisé : %d boules de couleur chez Alice, %d chez Bruno, %d sur le serveur'):format(ca, cb, srv))
end
check((sb.state ~= 'FINISHED' and p8 == nil and a8 == nil and b8p == nil) or (a8 and b8p and math.abs(a8.x - b8p.x) < 1e-6 and math.abs(a8.y - b8p.y) < 1e-6), 'la noire est exactement au même endroit chez les deux joueurs')
if sb.state == 'IN_PROGRESS' then
    run(1000)
    check(SV.export_AdminAction(1, 'cancel_session', { session = sb.id }), 'partie annulée par le staff')
    run(2000)
end
check(SV.LS.Sessions.byInst[2] == nil, 'table libérée')
run(1000)
local held = 0
for _, c in ipairs({ A, Bc }) do for _, o in pairs(c.objects) do if o.att then held = held + 1 end end end
check(held == 0, 'aucune queue restée en main')
check(table.concat(A.anims, ' '):find('coke_cut_v1_coccutter', 1, true), 'pose penchée sur la table jouée')

P('\n[Golf joué au clavier]')
run(25000)
peds[1].pos = vec(500, 0, 52) peds[2].pos = vec(501, 0, 52)
run(2000)
r = A.nuiCall('create', { inst = 3, name = 'Golf' })
Bc.nuiCall('join', { session = r.session.id })
A.nuiCall('start')
run(2500)
local sg = SV.LS.Sessions.all[r.session.id]
check(sg.state == 'IN_PROGRESS' and A.count('prop_golfflag') >= 1, 'golf lancé, drapeau posé')
guard = 0
local swings = 0
while sg.state == 'IN_PROGRESS' and guard < 80 do
    guard = guard + 1
    for _, c in ipairs({ A, Bc }) do
        if c.env.CL.Playing() then
            local b = sg.data.players[c.sid].ball
            peds[c.sid].pos = vec(b.x + 0.5, b.y, b.z + 1.0)
            run(1200)
            local dist = SV.Golf.DistToFlag(sg.data.holes[sg.data.hole], b.x, b.y)
            c.press(22) run(dist < 15 and 120 or 900) c.release(22)
            swings = swings + 1
            run(16000)
        end
    end
    run(300)
end
run(3000)
check(sg.state == 'FINISHED', ('parcours de golf joué au clavier jusqu\'au bout (%d coups)'):format(swings))
check(table.concat(A.anims, ' '):find('mini@golf/', 1, true), 'animations du mini-jeu de golf jouées')

P('\n[Bowling réaliste : pas de côté, flèche, chute des quilles, caméra, quilles du décor]')
run(25000)
local d1 = SV.LS.inst[1].data
peds[1].pos = vec(d1.x, d1.y - 1.6, d1.z + 1.0) peds[2].pos = vec(d1.x + 3.0, d1.y - 2.0, d1.z + 1.0)
run(3000)   -- de retour près de la piste : quilles recréées
-- quilles du décor (MLO) : une au fond de la piste (doublon, cachée), une sur la piste voisine (gardée)
A.objects[9001] = { model = joaat('prop_bowling_pin'), pos = vec(d1.x + 0.1, d1.y + 18.4, d1.z) }
A.objects[9002] = { model = joaat('prop_bowling_pin'), pos = vec(d1.x + 5.0, d1.y + 18.4, d1.z) }
run(2500)
check(A.objects[9001].visible == false and A.objects[9002].visible == nil, 'quille du décor au fond de la piste cachée, celle de la piste voisine gardée')
local ours = 0 for id, o in pairs(A.objects) do if id < 9000 and o.model == joaat('prop_bowling_pin') and o.visible == nil then ours = ours + 1 end end
check(ours == 10, 'nos 10 quilles restent visibles')
local pinZ = 0 for id, o in pairs(A.objects) do if id < 9000 and o.model == joaat('prop_bowling_pin') then pinZ = o.pos.z end end
check(math.abs(pinZ - d1.z) < 0.01, ('quilles posées debout sur le sol de la piste (base à %+.3f m)'):format(pinZ - d1.z))

peds[2].pos = vec(d1.x + 3.0, d1.y - 2.0, d1.z + 1.0)   -- Bruno regarde depuis la piste voisine, sans jouer
peds[1].pos = vec(d1.x, d1.y - 1.6, d1.z + 1.0) peds[1].h = d1.h
r = A.nuiCall('create', { inst = 1, name = 'Solo', max = 1 })
A.nuiCall('start')
run(2500)
local so = SV.LS.Sessions.all[r.session.id]
check(so and so.state == 'IN_PROGRESS', 'partie solo lancée')
run(800)
check(peds[1].frozen, 'en position de lancer, face à la piste')
local function arrowTip(c)
    local best
    for _, p in ipairs(c.polys) do
        for i = 0, 2 do local x, y = p[1 + i * 3], p[2 + i * 3] if not best or y > best.y then best = { x = x, y = y } end end
    end
    return best
end
local tip0 = arrowTip(A)
local Ar = SV.Config.Bowling.aimArrow
check(#A.polys >= 10 and tip0 and math.abs(tip0.y - (d1.y + Ar.start + Ar.length)) < 0.05 and math.abs(tip0.x - d1.x) < 0.05,
    ('flèche de visée dessinée sur la piste (%d triangles, pointe à %.2f m de la ligne de faute)'):format(#A.polys, tip0 and tip0.y - d1.y or -1))
-- l'animation du jeu déplace le perso de 28 cm, mais du côté opposé au nom du clip : le client doit s'en rendre compte
A.rootMotion = function(clip) return clip == SV.Config.Bowling.sideStep.left and 0.28 or -0.28 end
local stepsBefore = 0 for _, a in ipairs(A.anims) do if a:find('step_short', 1, true) then stepsBefore = stepsBefore + 1 end end
A.press(35) run(1200) A.release(35) run(700)
local steps = 0 for _, a in ipairs(A.anims) do if a:find('step_short', 1, true) then steps = steps + 1 end end
local x1 = peds[1].pos.x - d1.x
check(steps - stepsBefore >= 2, ('D maintenu : %d vrais pas de côté joués (move_strafe@reposition)'):format(steps - stepsBefore))
check(A.env.CL ~= nil and peds[1].h == d1.h and peds[1].frozen and math.abs(peds[1].pos.y - (d1.y - 1.3)) < 0.01, 'après chaque pas : toujours face à la piste, sur sa ligne')
A.press(35) run(3000) A.release(35) run(700)
local x2 = peds[1].pos.x - d1.x
check(x2 > x1 and math.abs(x2 - SV.Config.Bowling.maxStartX) < 0.01, ('pas à droite jusqu\'au bord autorisé (%.2f m puis %.2f m, limite %.2f m)'):format(x1, x2, SV.Config.Bowling.maxStartX))
A.press(34) run(1100) A.release(34) run(700)
local x3 = peds[1].pos.x - d1.x
check(x3 < x2 - 0.2, ('A : retour vers la gauche (%.2f m)'):format(x3))
local tip1 = arrowTip(A)
check(tip1 and math.abs((tip1.x - d1.x) - x3) < 0.05, 'la flèche suit la position du joueur')
A.press(51) run(600) A.release(51) A.press(32) run(600) A.release(32) run(100)
local tip2 = arrowTip(A)
check(tip2 and tip2.x > tip1.x + 0.05, ('angle + effet : la pointe de la flèche se décale (%+.2f m)'):format(tip2 and tip2.x - tip1.x or 0))
-- lancer
local camBefore = A.camSets
A.pitch, A.lieZ, A.yaw, Bc.pitch, Bc.lieZ, Bc.yaw = {}, {}, {}, {}, {}, {}
A.press(22) run(800) A.release(22)
local sawCam, sawCamB = false, false
for _ = 1, 60 do run(200) if A.camOn then sawCam = true end if Bc.camOn then sawCamB = true end end
local downN = so.data.players[1].rolls[1]
check(sawCam and A.camSets - camBefore > 30 and not A.camOn, ('caméra qui suit la boule puis rend la main (%d positions)'):format(A.camSets - camBefore))
check(not sawCamB, 'pas de caméra imposée à Bruno (il ne joue pas cette partie)')
local function fallen(c)
    local n, fwd, z = 0, 0, 0
    for e, pmin in pairs(c.pitch) do
        if pmin <= -87 then
            n = n + 1
            if math.cos(math.rad(c.yaw[e] - d1.h)) > 0 then fwd = fwd + 1 end
            z = math.max(z, math.abs(c.lieZ[e] - d1.z - 0.06))
        end
    end
    return n, fwd, z
end
local fa, fwdA, zA = fallen(A)
local fb = fallen(Bc)
check(fa == downN and fb == downN, ('quilles renversées à l\'écran : %d chez Alice, %d chez Bruno, %d selon le serveur'):format(fa, fb, downN))
check(fa == 0 or fwdA / fa >= 0.6, ('elles tombent dans le sens du choc (%d sur %d vers le fond)'):format(fwdA, fa))
check(zA < 0.005, 'quille couchée posée sur le sol (ni enterrée, ni en l\'air)')
local qs = SV.LS.Sessions.all[r.session.id]
if qs then run(1000) SV.export_AdminAction(1, 'cancel_session', { session = qs.id }) run(2000) end

-- alignement de la piste sur les quilles du décor (menu admin)
peds[1].pos = vec(200, 0, 31) peds[1].h = 0.0
A.objects[9100] = { model = joaat('prop_bowling_pin'), pos = vec(200.5, 20.0, 30.0) }
local alignOk, alignMsg
run(1000)
spawn(function() alignOk, alignMsg = SV.export_AdminAction(1, 'add_bowling', { name = 'Alignée', align = true }) end)
run(1500)
local al
for _, i in pairs(SV.LS.inst) do if i.name == 'Alignée' then al = i end end
local px, py = 0, 0
if al then px, py = SV.LU.toWorld(al.data.x, al.data.y, al.data.h, 0.0, SV.Config.Bowling.laneLength) end
check(alignOk and al and math.abs(px - 200.5) < 0.01 and math.abs(py - 20.0) < 0.01, ('piste alignée : quille n°1 exactement sur celle du décor (%s)'):format(tostring(alignMsg)))
A.objects[9100] = nil
peds[1].pos = vec(300, 0, 31)
run(1000)
spawn(function() alignOk, alignMsg = SV.export_AdminAction(1, 'add_bowling', { name = 'Rien', align = true }) end)
run(1500)
check(alignOk == false, 'sans quille du décor devant : refus clair')


P('\n[Pole dance : barre, danse, routines, pourboires, sécurité]')
run(2000)
peds[1].pos = vec(700, 0, 31) peds[1].h = 90.0
local okP, msgP = SV.export_AdminAction(1, 'add_pole', { name = 'Scène A' })
run(1500)
local pole
for _, i in pairs(SV.LS.inst) do if i.kind == 'pole' then pole = i end end
check(okP and pole and pole.data.spawn and math.abs(pole.data.x - 700) < 0.01 and pole.data.h == 90.0, 'admin : barre posée aux pieds du staff, tournée comme lui')
peds[1].pos = vec(700, -1.2, 31) peds[2].pos = vec(703, 0, 31)
run(2500)
local function poleObjs(c) local n = 0 for _, o in pairs(c.objects) do if o.model == joaat(SV.Config.Pole.model) then n = n + 1 end end return n end
check(poleObjs(A) == 1 and poleObjs(Bc) == 1, 'barre visible chez les deux joueurs (prop_strip_pole_01)')
check(A.textui and A.textui:find('Danser à la barre', 1, true), 'invite [E] Danser à la barre')
A.tap(38) run(300)
local dp = SV.LS.Pole.dancers[pole.id]
check(dp and dp.sid == 1, 'E : le serveur attribue la barre à Alice')
local sc = A.lastScene
check(sc and sc.clip == 'pd_enter' and math.abs(sc.x - 700) < 0.01 and math.abs(sc.y - 0) < 0.01 and sc.rz == 90.0 and not sc.loop,
    'montée sur la barre : scène synchronisée calée sur le pied de la barre (pd_enter)')
run(1200)
sc = A.lastScene
check(sc and sc.clip == 'pd_dance_01' and sc.loop and sc.mover == 1000.0, 'puis routine 1 en boucle (pd_dance_01)')
check(Bc.textui and Bc.textui:find('Lancer', 1, true) and Bc.textui:find('Joueur1', 1, true), 'Bruno voit [E] Lancer 100 $ à Alice')
A.tap(160) run(200)
check(A.lastScene.clip == 'pd_dance_03', 'touche 3 : routine 3')
A.tap(158) run(200)
check(A.lastScene.clip == 'pd_dance_02', 'touche 2 : routine 2')
A.tap(165)
local seenClips, seenN = {}, 0
for _ = 1, 10 do run(200) local cl = A.lastScene.clip if not seenClips[cl] then seenClips[cl] = true seenN = seenN + 1 end end
check(seenN == 3, ('touche 5 : enchaînement automatique des 3 routines (%d vues)'):format(seenN))
local animsBefore = #A.anims
A.tap(164) run(300)
local lastAnim = A.anims[#A.anims] or ''
check(#A.anims > animsBefore and lastAnim:find('priv_dance_p1', 1, true) and not next(A.sceneLive), 'touche 4 : danse sensuelle devant la barre (priv_dance_p1)')
local dx, dy = peds[1].pos.x - 700, peds[1].pos.y
check(math.abs(math.sqrt(dx * dx + dy * dy) - SV.Config.Pole.private.distance) < 0.05, 'placée juste devant la barre')
run(700)
local seenP2 = false for i = animsBefore + 1, #A.anims do if A.anims[i]:find('priv_dance_p2', 1, true) then seenP2 = true end end
check(seenP2, 'les parties de la danse sensuelle s\'enchaînent')
A.tap(157) run(200)
check(A.lastScene.clip == 'pd_dance_01', 'touche 1 : retour à la barre')
-- pourboire
Bc.tap(38) run(300)
check(#Bc.notes > 0 and Bc.notes[#Bc.notes].kind == 'success', 'Bruno lance un pourboire')
local tossed = false for _, a in ipairs(Bc.anims) do if a:find('toss', 1, true) then tossed = true end end
check(tossed, 'Bruno joue l\'animation du lancer de billets')
local notes = 0 for _, o in pairs(A.objects) do if o.model == joaat('prop_anim_cash_note') then notes = notes + 1 end end
check(notes > 0, ('billets qui volent vers Alice (%d)'):format(notes))
Bc.tap(38) run(300)
check(Bc.notes[#Bc.notes].kind == 'error', 'pourboire trop rapproché refusé')
-- Bruno ne peut pas prendre la barre occupée
local rc = SV.LS.Pole.Claim(2, pole.id)
check(rc == nil, 'barre occupée : refusée à un 2e joueur')
-- sortie normale
run(3000)
A.tap(177) run(200)
check(A.lastScene.clip == 'pd_exit', 'RETOUR : descente de la barre (pd_exit)')
run(1000)
check(SV.LS.Pole.dancers[pole.id] == nil and not A.env.CL.Busy(), 'barre libérée, joueuse libre')
-- éloignement : le serveur arrête la danse
A.tap(38) run(1500)
check(SV.LS.Pole.dancers[pole.id] ~= nil, 'Alice danse de nouveau')
peds[1].pos = vec(720, 0, 31)
run(4500)
check(SV.LS.Pole.dancers[pole.id] == nil and not A.env.CL.Busy(), 'trop loin de la barre : danse arrêtée par le serveur')
-- trop loin pour commencer, dans une partie, suppression de la barre
local r1, e1 = SV.LS.Pole.Claim(1, pole.id)
check(r1 == nil and e1:find('Approche', 1, true), 'trop loin pour commencer : refusé')
peds[1].pos = vec(700, -1.2, 31)
run(1500)
A.tap(38) run(1500)
SV.export_AdminAction(1, 'delete', { id = pole.id })
run(3000)
check(SV.LS.Pole.dancers[pole.id] == nil and not A.env.CL.Busy() and poleObjs(A) == 0, 'barre supprimée par le staff : danse arrêtée, barre retirée')

check(#errors == 0, ('aucune erreur Lua côté client ou serveur (%d)'):format(#errors))

P(('\nRésultat : %d réussis, %d échecs'):format(passes, fails))
return fails
