-- =====================================================================
--  Tests hors jeu d'elyzea_tv : 1 serveur + 2 joueurs (vrais fichiers), GTA / FiveM imités.
--  Liens YouTube, télés à écran plat (ALT, télécommande, synchro, son selon la distance, écran du modèle),
--  écrans du staff (éditeur, jeton, taille, panneau 3D), sécurité (distance, délai, permissions).
-- =====================================================================
local root = ...
local P = print
local passes, fails = 0, 0
local function check(c, label)
    if c then passes = passes + 1 P('  ok   ' .. label) else fails = fails + 1 P('  ÉCHEC ' .. label) end
end

-- ---------------------------------------------------------------- temps et planificateur
local GT, NOW = 0, 1800000000
local threads = {}
local function spawn(fn) threads[#threads + 1] = { co = coroutine.create(fn), wake = GT } end
local function Wait(ms) coroutine.yield(ms or 0) end
local errors = {}
local function step()
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
    if GT % 1008 < 16 then NOW = NOW + 1 end
end
local function run(ms) local stop = GT + ms while GT < stop do step() end end

local function joaat(s) s = tostring(s):lower() local h = 0 for i = 1, #s do h = (h + s:byte(i)) & 0xFFFFFFFF h = (h + (h << 10)) & 0xFFFFFFFF h = h ~ (h >> 6) end
    h = (h + (h << 3)) & 0xFFFFFFFF h = h ~ (h >> 11) h = (h + (h << 15)) & 0xFFFFFFFF return h end
local function signed(h) if h >= 2147483648 then return h - 4294967296 end return h end
local vmt = {}
local function vec(x, y, z) return setmetatable({ x = x, y = y, z = z }, vmt) end
vmt.__sub = function(a, b) return vec(a.x - b.x, a.y - b.y, a.z - b.z) end
vmt.__add = function(a, b) return vec(a.x + b.x, a.y + b.y, a.z + b.z) end
vmt.__mul = function(a, k) return vec(a.x * k, a.y * k, a.z * k) end
vmt.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
local function enc(v)
    local t = type(v)
    if t == 'table' then
        local n, isArr = 0, true
        for k in pairs(v) do n = n + 1 if type(k) ~= 'number' then isArr = false end end
        local parts = {}
        if isArr and n == #v then for _, x in ipairs(v) do parts[#parts + 1] = enc(x) end return '[' .. table.concat(parts, ',') .. ']' end
        for k, x in pairs(v) do parts[#parts + 1] = ('%q:%s'):format(tostring(k), enc(x)) end
        return '{' .. table.concat(parts, ',') .. '}'
    elseif t == 'string' then return ('%q'):format(v) elseif t == 'nil' then return 'null' else return tostring(v) end
end
local function dec(s) return s end

local function base(env)
    env.Wait, env.CreateThread, env.SetTimeout = Wait, spawn, function(ms, fn) spawn(function() Wait(ms) fn() end) end
    env.GetGameTimer = function() return GT end
    env.vector3, env.vec3 = vec, vec
    env.json = { encode = function(t) return t end, decode = dec }
    env.print = function(...) local m = table.concat((function(...) local t = {} for i = 1, select('#', ...) do t[i] = tostring((select(i, ...))) end return t end)(...), ' ')
        if m:find('^1', 1, true) then errors[#errors + 1] = m P('  ERREUR ' .. m) end end
    env.GetCurrentResourceName = function() return 'elyzea_tv' end
    return setmetatable(env, { __index = function(_, k)
        if _G[k] ~= nil then return _G[k] end
        if type(k) == 'string' and k:match('^%u') then return function() end end
    end })
end
local function loadInto(env, files)
    for _, f in ipairs(files) do
        local h = assert(io.open(root .. '/' .. f, 'r'))
        local src = h:read('a') h:close()
        assert(load(src, '@' .. f, 't', env))()
    end
end

-- ---------------------------------------------------------------- monde commun
local peds = {}
local function addPed(sid, x, y, z) peds[sid] = { pos = vec(x, y, z + 1.0), h = 0.0 } end
-- objets de la carte (identiques chez tous les joueurs) : 2 télés plates, 1 vieille télé, 1 mur
local world = {
    [9001] = { model = joaat('prop_tv_flat_01'), pos = vec(100.0, 200.0, 31.2) },
    [9002] = { model = joaat('prop_tv_flat_02'), pos = vec(103.0, 200.0, 31.2) },
    [9003] = { model = joaat('prop_tv_02'), pos = vec(98.0, 200.0, 31.0) },          -- télé cathodique : pas utilisable
}

-- ---------------------------------------------------------------- serveur
local SV = base({})
local svEvents, svCbs, clients = {}, {}, {}
local DB, dbseq = {}, 0
local staff = { [1] = true }
SV.os = setmetatable({ time = function() return NOW end }, { __index = os })
SV.GetHashKey = function(s) return signed(joaat(s)) end
SV.RegisterNetEvent = function(n, fn) if fn then svEvents[n] = svEvents[n] or {} table.insert(svEvents[n], fn) end end
SV.AddEventHandler = SV.RegisterNetEvent
local function deliver(n, target, ...)
    local a = table.pack(...)
    for sid, c in pairs(clients) do
        if target == -1 or target == sid then
            spawn(function() for _, fn in ipairs(c.events[n] or {}) do fn(table.unpack(a, 1, a.n)) end end)
        end
    end
end
SV.TriggerClientEvent = deliver
SV.GetPlayerName = function(s) return peds[tonumber(s) or -1] and ('Joueur' .. s) or nil end
SV.GetPlayerPed = function(s) return peds[s] and s or 0 end
SV.GetEntityCoords = function(p) return peds[p].pos end
SV.SetEntityCoords = function(p, x, y, z) peds[p].pos = vec(x, y, z) end
local logs = {}
SV.exports = setmetatable({
    elyzea_core = { GetPlayer = function(_, s) return peds[s] and { PlayerData = { charinfo = { firstname = 'Joueur' .. s, lastname = '' } } } or nil end },
    admin_menu = { HasPermission = function(_, s, perm) return perm == 'tv_manage' and staff[s] == true end, AddLog = function(_, s, a, d) logs[#logs + 1] = d end },
}, { __call = function(_, n, fn) SV['export_' .. n] = fn end })
SV.MySQL = {
    query = { await = function(sql) if sql:find('^SELECT') then local t = {} for _, r in pairs(DB) do t[#t + 1] = r end return t end return {} end },
    insert = { await = function(_, a) dbseq = dbseq + 1 DB[dbseq] = { id = dbseq, name = a[1], data = a[2] } return dbseq end },
    update = { await = function(sql, a) if sql:find('^DELETE') then DB[a[1]] = nil else local r = DB[a[3]] if r then r.name, r.data = a[1], a[2] end end return 1 end },
}
SV.Ely = { callback = { register = function(n, fn) svCbs[n] = fn end } }
local notes = {}
loadInto(SV, { 'config.lua', 'shared/youtube.lua', 'server/main.lua' })

-- ---------------------------------------------------------------- joueurs
local function newClient(sid)
    local c = { sid = sid, events = {}, nui = {}, ui = {}, exp = {}, keys = {}, frameKeys = {}, duis = {}, polys = 0, sprites = {}, rtLinked = {}, rtReg = {}, focus = false, notes = {} }
    local env = base({})
    c.env = env
    env.RegisterNetEvent = function(n, fn) if fn then c.events[n] = c.events[n] or {} table.insert(c.events[n], fn) end end
    env.AddEventHandler = env.RegisterNetEvent
    env.TriggerServerEvent = function(n, ...) local a = table.pack(...) spawn(function() SV.source = sid for _, fn in ipairs(svEvents[n] or {}) do fn(table.unpack(a, 1, a.n)) end end) end
    env.RegisterNUICallback = function(n, fn) c.nui[n] = fn end
    c.cmd = {}
    env.RegisterCommand = function(n, fn) c.cmd[n] = fn end
    env.SendNUIMessage = function(m) c.ui[#c.ui + 1] = m end
    env.SetNuiFocus = function(a) c.focus = a end
    env.exports = setmetatable({ elyzea_core = {
        Notify = function(_, msg, kind) c.notes[#c.notes + 1] = { msg = msg, kind = kind } end,
        ShowTextUI = function(_, t) c.textui = t end, HideTextUI = function() c.textui = nil end,
    } }, { __call = function(_, n, fn) c.exp[n] = fn end })
    env.Ely = { callback = { await = function(name, _, ...) SV.source = sid return svCbs[name](sid, ...) end } }
    env.GetHashKey = function(s) return signed(joaat(s)) end            -- signé
    env.GetEntityModel = function(e) return world[e] and world[e].model or 0 end   -- non signé : la ressource doit s'y retrouver
    env.GetEntityCoords = function(e) if peds[e] then return peds[e].pos end return world[e] and world[e].pos or vec(0, 0, 0) end
    env.DoesEntityExist = function(e) return peds[e] ~= nil or world[e] ~= nil end
    env.GetGamePool = function() local t = {} for id in pairs(world) do t[#t + 1] = id end return t end
    env.GetClosestObjectOfType = function(x, y, z, r, model)
        for id, o in pairs(world) do if signed(o.model) == signed(model) and #(o.pos - vec(x, y, z)) <= r then return id end end
        return 0
    end
    env.PlayerPedId = function() return sid end
    env.PlayerId = function() return sid end
    env.NetworkIsPlayerActive = function() return true end
    env.IsPedInAnyVehicle = function() return false end
    env.GetFinalRenderedCamCoord = function() return peds[sid].pos end
    env.GetFinalRenderedCamRot = function() return vec(0, 0, peds[sid].h) end
    env.GetCloudTimeAsInt = function() return NOW end
    -- pages vidéo (DUI) et textures
    local duiSeq = 0
    env.CreateDui = function(url, w, h) duiSeq = duiSeq + 1 c.duis[duiSeq] = { url = url, w = w, h = h, msgs = {}, alive = true } return duiSeq end
    env.GetDuiHandle = function(d) return 'h' .. d end
    env.IsDuiAvailable = function(d) return c.duis[d] and c.duis[d].alive end
    env.SendDuiMessage = function(d, m) local x = c.duis[d] if x then x.msgs[#x.msgs + 1] = m end end
    env.DestroyDui = function(d) if c.duis[d] then c.duis[d].alive = false end end
    -- écran d'origine des télés du jeu
    env.IsNamedRendertargetRegistered = function(n) return c.rtReg[n] == true end
    env.RegisterNamedRendertarget = function(n) c.rtReg[n] = true return true end
    env.LinkNamedRendertarget = function(m) c.rtLinked[signed(m)] = true end
    -- comme chez le joueur qui a signalé le problème : le jeu ne confirme jamais le lien télé ↔ écran d'origine
    env.IsNamedRendertargetLinked = function(m) if c.neverLinked then return false end return c.rtLinked[signed(m)] == true end
    -- télés : 1,2 m de large, 10 cm d'épaisseur, 80 cm de haut, posées sans rotation
    env.GetModelDimensions = function() return vec(-0.6, -0.05, -0.4), vec(0.6, 0.05, 0.4) end
    env.GetOffsetFromEntityInWorldCoords = function(e, x, y, z) local p = world[e].pos return vec(p.x + x, p.y + y, p.z + z) end
    env.GetOffsetFromEntityGivenWorldCoords = function(e, x, y, z) local p = world[e].pos return vec(x - p.x, y - p.y, z - p.z) end
    env.GetNamedRendertargetRenderId = function(n) return c.rtReg[n] and 42 or -1 end
    env.ReleaseNamedRendertarget = function(n) c.rtReg[n] = nil c.released = (c.released or 0) + 1 end
    env.SetTextRenderId = function(id) c.renderId = id end
    env.GetDefaultScriptRendertargetRenderId = function() return 1 end
    env.DrawSprite = function(dict, tex) if c.renderId == 42 then c.sprites[#c.sprites + 1] = { dict = dict, tex = tex, t = GT } end end
    c.texAt, c.badFloat = {}, 0
    -- comme sur un serveur où le nom « DrawTexturedPoly » n'existe pas : seul l'appel par identifiant marche
    env.DrawTexturedPoly = function() error('attempt to call a nil value (global \'DrawTexturedPoly\')') end
    env.Citizen = { InvokeNative = function(h, ...)
        if h ~= 0x29280002282F1928 then return end
        local a = { ... }
        for _, i in ipairs({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 16, 17, 18, 19, 20, 21, 22, 23, 24 }) do if math.type(a[i]) ~= 'float' then c.badFloat = c.badFloat + 1 end end
        c.polys = c.polys + 1 c.lastPoly = a c.texAt[a[15]] = GT
        if tostring(a[15]):match('^v%d+$') then c.vidPoly = a end
    end }
    -- touches
    env.IsControlJustPressed = function(_, k) return c.frameKeys[k] ~= nil and GT - c.frameKeys[k] <= 16 end
    env.IsDisabledControlJustPressed = env.IsControlJustPressed
    env.IsDisabledControlPressed = function(_, k) return c.keys[k] == true end
    function c.tap(k) c.frameKeys[k] = GT c.keys[k] = true run(32) c.keys[k] = nil end
    function c.hold(k, ms) c.keys[k] = true run(ms) c.keys[k] = nil end
    function c.last(action) for i = #c.ui, 1, -1 do if c.ui[i].action == action then return c.ui[i] end end end
    function c.nuiCall(name, data) local res c.nui[name](data or {}, function(r) res = r end) run(100) return res end
    function c.liveDuis() local n = 0 for _, d in pairs(c.duis) do if d.alive then n = n + 1 end end return n end
    function c.lastMsg(type_) local best for _, d in pairs(c.duis) do if d.alive then for _, m in ipairs(d.msgs) do if m.type == type_ then best = m end end end end return best end
    loadInto(env, { 'config.lua', 'shared/youtube.lua', 'client/main.lua', 'client/render.lua', 'client/remote.lua', 'client/editor.lua' })
    clients[sid] = c
    return c
end

addPed(1, 100.0, 198.5, 30.0)        -- Alice, devant la télé n°9001
addPed(2, 101.0, 197.0, 30.0)        -- Bruno, à côté
local A, B = newClient(1), newClient(2)
A.neverLinked = true
run(4000)

P('[Liens YouTube]')
local Y = SV.YT
local id, t = Y.Parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=1m30s')
check(id == 'dQw4w9WgXcQ' and t == 90, 'youtube.com/watch?v=…&t=1m30s → identifiant + départ à 90 s')
check(Y.Parse('https://youtu.be/dQw4w9WgXcQ?t=42') == 'dQw4w9WgXcQ' and select(2, Y.Parse('youtu.be/dQw4w9WgXcQ?t=42')) == 42, 'youtu.be (avec ou sans https)')
check(Y.Parse('https://www.youtube.com/shorts/dQw4w9WgXcQ') == 'dQw4w9WgXcQ' and Y.Parse('https://m.youtube.com/watch?feature=x&v=dQw4w9WgXcQ') == 'dQw4w9WgXcQ'
    and Y.Parse('https://www.youtube.com/embed/dQw4w9WgXcQ') == 'dQw4w9WgXcQ' and Y.Parse('https://www.youtube.com/live/dQw4w9WgXcQ') == 'dQw4w9WgXcQ', 'shorts, mobile, embed, live')
check(Y.Parse('dQw4w9WgXcQ') == 'dQw4w9WgXcQ', 'identifiant seul')
check(not Y.Parse('https://evil.com/watch?v=dQw4w9WgXcQ') and not Y.Parse('https://youtube.com.evil.com/watch?v=dQw4w9WgXcQ') and not Y.Parse('https://www.youtube.com/watch?v=abc')
    and not Y.Parse('javascript:alert(1)') and not Y.Parse('https://www.youtube.com/watch?v=dQw4w9WgXc"') and not Y.Parse(nil), 'refusés : autre site, faux domaine, identifiant invalide, script')

P('\n[Télés à écran plat : ALT]')
local flatKey = A.env.TVC.FlatKey(9001)
check(A.exp.AltTarget(9001) == '📺 Télévision' and A.exp.AltTarget(9002) ~= nil, 'ALT reconnaît les télés à écran plat (modèle lu en non signé, config en signé)')
check(A.exp.AltTarget(9003) == nil, 'la vieille télé cathodique n\'est pas une télé utilisable')
local ent, title = A.exp.AltNearby()
check(ent == 9001 and title == '📺 Télévision', 'ALT sans viser : la télé la plus proche (< 2,5 m)')
local opts = A.exp.AltOptions({ kind = 'ext', entity = 9001 })
check(#opts == 1 and opts[1].id == 'remote', 'télé éteinte : une seule option « Télécommande »')
A.exp.AltSelect('remote', { kind = 'ext', entity = 9001 })
run(200)
local rm = A.last('remote')
check(A.focus == true and rm and rm.open and rm.state == nil, 'Télécommande ouverte (souris), écran éteint')

P('\n[Lecture]')
local r = A.nuiCall('remote', { cmd = 'play', url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=30' })
run(600)
local st = SV.TV.states[flatKey]
check(st and st.id == 'dQw4w9WgXcQ' and st.offset == 30 and st.by == 'Joueur1', 'le serveur lance la vidéo (départ à 30 s, lancée par Alice)')
check(A.env.TVC.states[flatKey] and B.env.TVC.states[flatKey] and B.env.TVC.states[flatKey].id == 'dQw4w9WgXcQ', 'les deux joueurs reçoivent l\'état')
check(A.liveDuis() == 1 and B.liveDuis() == 1, 'une page vidéo créée chez chacun')
local dA = A.duis[1]
check(dA.url == 'https://cfx-nui-elyzea_tv/html/player.html' and dA.w == 1280 and dA.h == 720, 'page vidéo de la ressource (origine https, exigée par YouTube), 1280 × 720')
local la, lb = A.lastMsg('load'), B.lastMsg('load')
check(la and lb and la.id == 'dQw4w9WgXcQ' and la.at >= 30 and math.abs(la.at - lb.at) <= 1, ('même vidéo, même position chez les deux (%d s / %d s)'):format(la and la.at or -1, lb and lb.at or -1))
local va, vb = A.lastMsg('volume'), B.lastMsg('volume')
check(va and vb and va.v > vb.v and va.v > 0, ('son plus fort pour Alice (1,5 m) que pour Bruno (3 m) : %.2f / %.2f'):format(va and va.v or 0, vb and vb.v or 0))
run(800)
local spr = A.sprites[#A.sprites]
check(spr and spr.dict == 'elyzea_tv' and spr.tex == 'v1', 'image dessinée sur l\'écran d\'origine de la télé, même si le jeu ne confirme pas le lien')
local vp = A.vidPoly
local ys, xmin, xmax, zmin, zmax = {}, math.huge, -math.huge, math.huge, -math.huge
if vp then for i = 0, 2 do local x, y, z = vp[1 + i * 3], vp[2 + i * 3], vp[3 + i * 3] ys[#ys + 1] = y xmin, xmax = math.min(xmin, x), math.max(xmax, x) zmin, zmax = math.min(zmin, z), math.max(zmax, z) end end
check(vp and vp[15] == 'v1' and math.abs(ys[1] - 199.94) < 0.001 and xmin >= 99.4 and xmax <= 100.6 and zmax <= 31.6 and zmax > 31.5,
    'image aussi posée sur la face avant de la télé, côté joueur, dans le cadre (16:9, en haut)')
local lines = {}
local oldPrint = A.env.print
A.env.print = function(...) local t = {} for i = 1, select('#', ...) do t[i] = tostring((select(i, ...))) end lines[#lines + 1] = table.concat(t, ' ') end
A.cmd.tv_debug()
A.env.print = oldPrint
local dbgOut = table.concat(lines, '\n')
check(A.badFloat == 0, 'dessin par identifiant : toutes les coordonnées et UV envoyées en décimaux')
-- une erreur d'affichage ne coupe plus rien : la face avant plante une fois, l'écran d'origine continue
local orig = A.env.GetOffsetFromEntityGivenWorldCoords
A.env.GetOffsetFromEntityGivenWorldCoords = function() error('panne simulée') end
local nSpr = #A.sprites
run(300)
A.env.GetOffsetFromEntityGivenWorldCoords = orig
-- l'erreur simulée a été signalée une seule fois dans F8 : on la retire du décompte des vraies erreurs
local simulated = 0
for i = #errors, 1, -1 do if errors[i]:find('panne simulée', 1, true) then table.remove(errors, i) simulated = simulated + 1 end end
check(simulated == 1, 'erreur d\'affichage signalée une seule fois dans F8 (pas de spam)')
run(300)
check(#A.sprites > nSpr and A.env.TVC.drawErrors['face avant'] and A.vidPoly and GT - A.texAt.v1 < 50, 'une panne de la face avant n\'arrête ni l\'écran d\'origine ni l\'affichage suivant')
A.env.TVC.drawErrors = {}
check(dbgOut:find('prop_tv_flat_01', 1, true) and dbgOut:find('tvscreen', 1, true) and dbgOut:find('dQw4w9WgXcQ', 1, true) and dbgOut:find('prête', 1, true),
    '/tv_debug : modèle, écran d\'origine, vidéo et page affichés dans F8')
-- Bruno s'éloigne : le son baisse puis se coupe, l'image s'arrête au-delà de la portée
peds[2].pos = vec(110.0, 200.0, 31.0) run(600)
local v2 = B.lastMsg('volume')
peds[2].pos = vec(130.0, 200.0, 31.0) run(800)
check(v2 and v2.v < vb.v and B.liveDuis() == 0, 'Bruno s\'éloigne : son plus faible, puis page fermée au-delà de 25 m')
check((B.released or 0) >= 1, 'écran de la télé rendu au jeu quand plus rien n\'y est diffusé')
peds[2].pos = vec(101.0, 197.0, 30.0) run(800)
check(B.liveDuis() == 1, 'Bruno revient : la vidéo reprend au bon endroit')

P('\n[Commandes]')
NOW = NOW + 20
local expect = SV.TV.Position(SV.TV.states[flatKey])
A.nuiCall('remote', { cmd = 'pause' }) run(600)
st = SV.TV.states[flatKey]
check(st.paused and math.abs(st.pausedAt - expect) <= 1, ('pause : position figée (%d s, attendu %d s)'):format(st.pausedAt or -1, expect))
local frozen = st.pausedAt
local lp = B.lastMsg('load')
check(lp and lp.paused == true, 'Bruno voit la pause aussitôt')
NOW = NOW + 30
A.nuiCall('remote', { cmd = 'resume' }) run(600)
st = SV.TV.states[flatKey]
check(not st.paused and math.abs(SV.TV.Position(st) - frozen) <= 1, 'reprise là où on s\'était arrêté (pas de saut, malgré 30 s de pause)')
local before = SV.TV.Position(SV.TV.states[flatKey])
A.nuiCall('remote', { cmd = 'seek', by = 10 }) run(600)
check(math.abs(SV.TV.Position(SV.TV.states[flatKey]) - (before + 10)) <= 1, 'avance de 10 s')
A.nuiCall('remote', { cmd = 'volume', v = 25 }) run(800)
check(SV.TV.states[flatKey].volume == 25 and A.lastMsg('volume').v < va.v, 'volume réglé à 25 % pour tout le monde')
local opts2 = B.exp.AltOptions({ kind = 'ext', entity = 9001 })
local ids = {} for _, o in ipairs(opts2) do ids[o.id] = true end
check(ids.remote and ids.pause and ids.volup and ids.voldown and ids.stop, 'ALT sur une télé allumée : télécommande, pause, volume +/−, éteindre')
B.exp.AltSelect('volup', { kind = 'ext', entity = 9001 }) run(600)
check(SV.TV.states[flatKey].volume == 35, 'Bruno monte le volume par ALT (+10)')

P('\n[Sécurité]')
run(400)
local rr = svCbs['elyzea_tv:play'](2, flatKey, 'https://evil.com/x')
check(rr.error and rr.error:find('YouTube', 1, true), 'lien qui n\'est pas YouTube : refusé par le serveur')
run(400)
rr = svCbs['elyzea_tv:play'](1, flatKey, 'https://youtu.be/aaaaaaaaaaa')
run(400)
local rr2 = svCbs['elyzea_tv:play'](1, flatKey, 'https://youtu.be/eeeeeeeeeee')
check(rr.ok and rr2.error and rr2.error:find('Doucement', 1, true), 'changement de vidéo trop rapproché : refusé')
run(400)
peds[3] = { pos = vec(300, 300, 31) }
rr = svCbs['elyzea_tv:play'](3, flatKey, 'https://youtu.be/aaaaaaaaaaa')
check(rr.error and rr.error:find('Approche', 1, true), 'joueur loin de la télé : refusé')
run(400)
rr = svCbs['elyzea_tv:play'](2, ('m%d|98.0|200.0|31.0'):format(signed(joaat('prop_tv_02'))), 'https://youtu.be/aaaaaaaaaaa')
check(rr.error and rr.error:find('plat', 1, true), 'vieille télé (pas un écran plat) : refusée même avec une clé fabriquée')
run(400)
rr = svCbs['elyzea_tv:play'](2, 'm123|1|2', 'https://youtu.be/aaaaaaaaaaa')
check(rr.error and rr.error:find('plat', 1, true), 'clé mal formée : refusée')
peds[3] = nil

P('\n[Deux télés, une image chacune]')
NOW = NOW + 5
B.nuiCall('remote', { cmd = 'close' })
peds[2].pos = vec(103.0, 198.5, 30.0)
local k2 = B.env.TVC.FlatKey(9002)
run(400)
rr = svCbs['elyzea_tv:play'](2, k2, 'https://www.youtube.com/watch?v=bbbbbbbbbbb')
run(1200)
check(rr.ok and A.liveDuis() == 2, 'deux télés allumées : deux pages vidéo chez Alice')
local nearTex = A.sprites[#A.sprites].tex
check(nearTex == 'v1', 'l\'écran d\'origine montre la télé la plus proche d\'Alice')
local own = 0 for tex, at in pairs(A.texAt) do if tex:match('^v%d+$') and GT - at < 200 then own = own + 1 end end
check(own == 2, 'face avant : chaque télé affiche sa propre vidéo (2 images différentes)')
A.cmd.tv_test() run(300)
check(A.texAt.mire and GT - A.texAt.mire < 50 and A.sprites[#A.sprites].tex == 'mire', '/tv_test : mire de couleurs sur la télé (face avant et écran d\'origine)')
run(10500)
check(not A.env.TVC.test and GT - A.texAt.mire > 300, '/tv_test : la mire s\'arrête après 10 s')
check(B.focus == false, 'télécommande fermée : souris rendue au joueur')

P('\n[Écran géant posé par le staff]')
peds[1].pos = vec(500.0, 500.0, 31.0) peds[1].h = 0.0
run(1500)
check(A.liveDuis() == 0, 'loin des télés : plus aucune page vidéo (performances)')
A.env.StartExpensiveSynchronousShapeTestLosProbe = function() return 1 end
A.env.GetShapeTestResult = function() return 1, true, vec(500.0, 520.0, 38.0), vec(0.0, -1.0, 0.0) end
local okN, msgN = SV.export_AdminAction(1, 'screen_new', { name = 'Écran géant', w = 16, h = 9 })
run(300)
check(okN and A.env.TVC.editing ~= nil and A.last('editor').open, 'admin : placement en jeu lancé (aperçu + aide)')
local pBefore = A.polys
run(200)
check(A.polys > pBefore, 'aperçu de l\'écran dessiné pendant le placement')
A.tap(24) run(100)          -- figer l'endroit visé
A.tap(15) run(100)          -- molette : plus grand
local ed = A.last('editor')
check(ed and ed.w > 16 and math.abs(ed.w / ed.h - 16 / 9) < 0.01, ('molette : taille augmentée en gardant le format (%.2f × %.2f)'):format(ed.w, ed.h))
A.hold(10, 160) run(50)     -- monter un peu
A.tap(191) run(800)         -- ENTRÉE : enregistrer
local scr = SV.TV.screens[1]
check(scr and scr.name == 'Écran géant' and scr.data.w > 16 and scr.data.z > 38.0, 'écran enregistré (nom, taille, hauteur)')
check(math.abs(scr.data.h - 180.0) < 0.5, ('écran tourné vers le staff (cap %.1f°)'):format(scr.data.h))
check(math.abs(scr.data.remote.x - 500) < 0.01 and math.abs(scr.data.remote.y - 500) < 0.01, 'télécommande là où se tenait le staff')
check(A.env.TVC.screens[1] and B.env.TVC.screens[1], 'écran envoyé à tous les joueurs')
-- jeton : impossible d'enregistrer sans passer par le menu admin
SV.source = 2
for _, fn in ipairs(svEvents['elyzea_tv:server:editorSave']) do fn('faux', { x = 1, y = 1, z = 1, h = 0, w = 50, hgt = 30 }, 'pirate') end
run(100)
local count = 0 for _ in pairs(SV.TV.screens) do count = count + 1 end
check(count == 1, 'enregistrement sans jeton du staff : refusé')
-- éteint : l'écran est dessiné (couleur unie) ; allumé : la vidéo
run(300)
check(A.lastPoly and A.lastPoly[14] == 'elyzea_tv' and (A.lastPoly[15] == 'idle'), 'écran éteint : visible (couleur unie)')
check(A.textui and A.textui:find('Télécommande', 1, true), 'invite [E] Télécommande au point de commande')
A.tap(38) run(200)
check(A.focus == true and A.last('remote').name == 'Écran géant', 'E : télécommande de l\'écran géant')
A.nuiCall('remote', { cmd = 'play', url = 'https://youtu.be/ccccccccccc' }) run(800)
local usedVideo = false
for tex, at in pairs(A.texAt) do if tex:match('^v%d+$') and GT - at < 200 then usedVideo = true end end
check(usedVideo, 'écran géant : la vidéo est dessinée sur l\'écran')
check(A.liveDuis() == 1 and A.lastMsg('load').id == 'ccccccccccc', 'page vidéo de l\'écran géant')
-- un joueur loin du point de commande ne peut pas changer la vidéo d'un écran public
rr = svCbs['elyzea_tv:play'](2, 's1', 'https://youtu.be/ddddddddddd')
check(rr.error, 'écran du staff : il faut être à sa télécommande')
-- écran réservé au staff
SV.export_AdminAction(1, 'screen_set', { id = 1, public = false })
run(300)
peds[2].pos = vec(500.0, 500.5, 31.0)
NOW = NOW + 10
rr = svCbs['elyzea_tv:play'](2, 's1', 'https://youtu.be/ddddddddddd')
check(rr.error and rr.error:find('staff', 1, true), 'écran « staff seulement » : refusé à un joueur, même à la télécommande')
-- taille modifiée depuis le menu
local okS = SV.export_AdminAction(1, 'screen_size', { id = 1, w = 30, h = 16.875 })
check(okS and SV.TV.screens[1].data.w == 30, 'taille changée depuis le menu (30 × 16,9 m)')
check(not SV.export_AdminAction(1, 'screen_size', { id = 1, w = 500, h = 2 }), 'taille hors limites : refusée')
local data = SV.export_AdminData()
check(#data.screens == 1 and data.screens[1].state and #data.flats == 2, 'onglet admin : écran + 2 télés allumées')
SV.export_AdminAction(1, 'stop_all', {}) run(800)
check(next(SV.TV.states) == nil and A.liveDuis() == 0, 'tout éteindre : plus aucune vidéo, pages fermées')
SV.export_AdminAction(1, 'screen_delete', { id = 1 }) run(500)
check(not A.env.TVC.screens[1], 'écran supprimé chez tout le monde')
A.nuiCall('remote', { cmd = 'close' })

check(#errors == 0, ('aucune erreur Lua (%d)'):format(#errors))
P(('\nRésultat : %d réussis, %d échecs'):format(passes, fails))
return fails
