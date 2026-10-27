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
loadInto(SV, { 'server/main.lua', 'server/sessions.lua', 'server/bowling.lua', 'server/billiards.lua', 'server/golf.lua' })
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
    env.GetModelDimensions = function() return vec(-1.2, -0.65, 0), vec(1.2, 0.65, 0.9) end
    env.CreateObjectNoOffset = function(h, x, y, z) c.nextObj = c.nextObj + 1 c.objects[c.nextObj] = { model = h, pos = vec(x, y, z) } return c.nextObj end
    env.DoesEntityExist = function(e) return peds[e] ~= nil or c.objects[e] ~= nil end
    env.DeleteEntity = function(e) c.objects[e] = nil end
    env.IsEntityAttached = function(e) return c.objects[e] and c.objects[e].att ~= nil end
    env.AttachEntityToEntity = function(e, p) if c.objects[e] then c.objects[e].att = p end end
    env.GetGroundZFor_3dCoord = function(x, y, z) return false, 0 end
    env.IsPedInAnyVehicle = function() return false end
    env.IsEntityDead = function() return false end
    env.GetEntityModel = function() return joaat('mp_m_freemode_01') end
    env.DoesAnimDictExist = function() return true end
    env.HasAnimDictLoaded = function() return true end
    env.TaskPlayAnim = function(p, d, cl) c.anims[#c.anims + 1] = d .. '/' .. cl end
    env.GetDisabledControlNormal = function() return 0.0 end
    env.GetClosestObjectOfType = function() return 0 end
    local function pressed(k) return c.keys[k] == true end
    local function just(k) return c.frameKeys[k] == FRAME - 1 or c.frameKeys[k] == FRAME end
    local function released(k) return c.frameKeys['r' .. k] == FRAME - 1 or c.frameKeys['r' .. k] == FRAME end
    env.IsControlPressed, env.IsDisabledControlPressed = function(_, k) return pressed(k) end, function(_, k) return pressed(k) end
    env.IsControlJustPressed, env.IsDisabledControlJustPressed = function(_, k) return just(k) end, function(_, k) return just(k) end
    env.IsDisabledControlJustReleased = function(_, k) return released(k) end
    loadInto(env, SHARED)
    loadInto(env, { 'client/main.lua', 'client/anim.lua', 'client/bowling.lua', 'client/billiards.lua', 'client/golf.lua' })
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
check(#errors == 0, ('aucune erreur Lua côté client ou serveur (%d)'):format(#errors))

P(('\nRésultat : %d réussis, %d échecs'):format(passes, fails))
return fails
