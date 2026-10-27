-- =====================================================================
--  Simulation hors jeu : tatouages et multipersonnage (audit)
--  Vrais fichiers : tattoo_data.lua, server/storage.lua, server/tattoo.lua, client/tattoo.lua.
--  Le serveur et le client tournent chacun dans leur propre environnement ; le ped, les
--  « décorations » (tatouages GTA), le disque (data/*.json) et le réseau sont imités.
--  Lancement : python3 tests/run_tattoo_multichar_sim.py   (depuis admin_menu/)
--  Ne remplace pas un essai en jeu (rendu réel des tatouages, réseau réel).
-- =====================================================================
local ROOT = ...
local passes, fails = 0, 0
local function check(c, label)
    if c then passes = passes + 1 print('  ok   ' .. label) else fails = fails + 1 print('  ÉCHEC ' .. label) end
end

-- ---------------------------------------------------------------- outils
local function joaat(s)
    s = tostring(s):lower()
    local h = 0
    for i = 1, #s do
        h = (h + s:byte(i)) & 0xFFFFFFFF
        h = (h + (h << 10)) & 0xFFFFFFFF
        h = h ~ (h >> 6)
    end
    h = (h + (h << 3)) & 0xFFFFFFFF
    h = h ~ (h >> 11)
    h = (h + (h << 15)) & 0xFFFFFFFF
    return h
end
-- « JSON » du disque imité : sérialisation Lua relue telle quelle
local function ser(v)
    local t = type(v)
    if t == 'table' then
        local parts = {}
        for k, x in pairs(v) do parts[#parts + 1] = ('[%s]=%s'):format(ser(k), ser(x)) end
        return '{' .. table.concat(parts, ',') .. '}'
    elseif t == 'string' then return ('%q'):format(v)
    else return tostring(v) end
end
local json = {
    encode = function(v) return ser(v) end,
    decode = function(s) local f = load('return ' .. s) return f and f() end,
}
local function readFile(rel)
    local f = assert(io.open(ROOT .. '/' .. rel, 'r'))
    local s = f:read('a') f:close()
    return (s:gsub('`([^`]*)`', 'GetHashKey("%1")'))
end

-- ---------------------------------------------------------------- planificateur commun
local TIME, threads = 0, {}
local function spawn(fn) threads[#threads + 1] = { co = coroutine.create(fn), wake = TIME } end
local function tick(n)
    for _ = 1, n or 1 do
        TIME = TIME + 50
        local list = threads
        threads = {}
        for _, t in ipairs(list) do
            if coroutine.status(t.co) ~= 'dead' then
                if t.wake <= TIME then
                    local ok, ms = coroutine.resume(t.co)
                    if not ok then error(ms) end
                    t.wake = TIME + (ms or 0)
                end
                if coroutine.status(t.co) ~= 'dead' then threads[#threads + 1] = t end
            end
        end
    end
end
local function Wait(ms) coroutine.yield(ms or 0) end
local function SetTimeout(ms, fn) spawn(function() Wait(ms) fn() end) end

-- ---------------------------------------------------------------- monde
local FILES = {}                 -- disque du serveur (data/*.json)
local CID = nil                  -- personnage chargé (nil = écran de sélection)
local GENDER = { A = 0, B = 0 }
local MALE = joaat('mp_m_freemode_01')
local ped = { model = MALE, decos = {} }
local wallet = { A = 5000, B = 5000 }
local SV, CL                     -- environnements serveur / client
local svEvents, clEvents, nui = {}, {}, {}

local function natives(env)
    env.GetHashKey, env.joaat = joaat, joaat
    env.json = json
    env.Wait, env.SetTimeout = Wait, SetTimeout
    env.CreateThread = spawn
    env.print = function() end
    env.GetResourceState = function(r) return r == 'admin_menu' and 'started' or 'missing' end
    env.GetCurrentResourceName = function() return 'admin_menu' end
    return setmetatable(env, { __index = function(_, k)
        if _G[k] ~= nil then return _G[k] end
        if type(k) == 'string' and k:match('^%u') then return function() end end
    end })
end

local function startServer()
    svEvents = {}
    SV = natives({})
    SV.RegisterNetEvent = function(n, fn) if fn then svEvents[n] = svEvents[n] or {} table.insert(svEvents[n], fn) end end
    SV.AddEventHandler = SV.RegisterNetEvent
    SV.TriggerEvent = function() end
    SV.TriggerClientEvent = function(n, _, ...) local a = table.pack(...) SetTimeout(0, function() for _, fn in ipairs(clEvents[n] or {}) do fn(table.unpack(a, 1, a.n)) end end) end
    SV.TriggerLatentClientEvent = function(n, s, _, ...) SV.TriggerClientEvent(n, s, ...) end
    SV.LoadResourceFile = function(_, f) return FILES[f] end
    SV.SaveResourceFile = function(_, f, data) FILES[f] = data return true end
    SV.exports = setmetatable({
        elyzea_core = {
            GetCitizenId = function() return CID end,
            GetPlayer = function() return CID and { PlayerData = { charinfo = { gender = GENDER[CID] } } } or nil end,
        },
    }, { __call = function(_, name, fn) SV['export_' .. name] = fn end })
    SV.Config = { Tattoo = { sources = {}, defaultPrices = { head = 300, torso = 450, left_arm = 250, right_arm = 250, left_leg = 250, right_leg = 250, remove = 200 } } }
    SV.AdminMenu = {
        rateLimit = function() return true end, notify = function() end, getLicense = function() return 'license:compte' end,
        EditorPeds = { check = function() return { id = 7, npc = { payment = 'cash', tattoo = { prices = {}, payChoice = true, removal = true } } } end },
    }
    SV.Bridge = {
        GetMoney = function() return CID and wallet[CID] or 0 end,
        RemoveMoney = function(_, _, _, n) if not CID then return false end wallet[CID] = wallet[CID] - n return true end,
        GetLabel = function() end, GetCharId = function() return CID or 'license:compte' end,
    }
    for _, f in ipairs({ 'tattoo_data.lua', 'server/storage.lua' }) do assert(load(readFile(f), '@' .. f, 't', SV))() end
    SV.TattooData.custom = {
        { label = 'Rose', collection = 'mpbeach_overlays', male = 'T_ROSE_M', female = 'T_ROSE_F', zone = 'ZONE_TORSO' },
        { label = 'Ancre', collection = 'mpbeach_overlays', male = 'T_ANCRE_M', female = 'T_ANCRE_F', zone = 'ZONE_LEFT_ARM' },
        { label = 'Crâne', collection = 'multiplayer_overlays', male = 'T_CRANE_M', female = 'T_CRANE_F', zone = 'ZONE_RIGHT_ARM' },
        { label = 'Étoile', collection = 'multiplayer_overlays', male = 'T_ETOILE_M', female = 'T_ETOILE_F', zone = 'ZONE_HEAD' },
    }
    assert(load(readFile('server/tattoo.lua'), '@server/tattoo.lua', 't', SV))()
    tick(40)   -- catalogue construit (Wait 1500)
end

local function startClient()
    clEvents, nui = {}, {}
    CL = natives({})
    CL.RegisterNetEvent = function(n, fn) if fn then clEvents[n] = clEvents[n] or {} table.insert(clEvents[n], fn) end end
    CL.AddEventHandler = CL.RegisterNetEvent
    CL.TriggerEvent = function() end
    CL.TriggerServerEvent = function(n, ...)
        local a = table.pack(...)
        SetTimeout(0, function()
            SV.source = 1
            for _, fn in ipairs(svEvents[n] or {}) do fn(table.unpack(a, 1, a.n)) end
        end)
    end
    CL.RegisterNUICallback = function(n, fn) nui[n] = fn end
    CL.SendNUIMessage = function() end
    CL.Notify = function() end
    CL.Config = { Tattoo = {} }
    CL.BarberOpen, CL.MarketOpen = false, false
    CL.GetGameTimer = function() return TIME end
    CL.exports = setmetatable({ elyzea_core = { GetCitizenId = function() return CID end } }, { __call = function() end })
    CL.PlayerPedId = function() return ped end
    CL.PlayerId = function() return 1 end
    CL.NetworkIsPlayerActive = function() return true end
    CL.GetEntityModel = function(p) return p.model end
    CL.ClearPedDecorations = function(p) p.decos = {} end
    CL.AddPedDecorationFromHashes = function(p, c, o) p.decos[#p.decos + 1] = { c, o } end
    CL.GetPedDecorations = function(p) local t = {} for i, d in ipairs(p.decos) do t[i] = { d[1], d[2] } end return t end
    CL.GetLabelText = function() return 'NULL' end
    CL.GetPedBoneCoords = function() return { x = 0.0, y = 0.0, z = 0.0 } end
    CL.GetEntityCoords = function() return { x = 0.0, y = 0.0, z = 0.0 } end
    CL.GetEntityHeading = function() return 0.0 end
    CL.GetFrameTime = function() return 0.016 end
    CL.IsEntityDead = function() return false end
    CL.IsPedInAnyVehicle = function() return false end
    CL.IsRadarHidden = function() return false end
    CL.GetPedDrawableVariation = function() return 0 end
    CL.GetPedTextureVariation = function() return 0 end
    CL.GetPedPropIndex = function() return -1 end
    CL.GetPedPropTextureIndex = function() return 0 end
    assert(load(readFile('client/tattoo.lua'), '@client/tattoo.lua', 't', CL))()
end
local function fire(n, ...) for _, fn in ipairs(clEvents[n] or {}) do fn(...) end end

-- ---------------------------------------------------------------- aides
local function H(name) return joaat(name) end
local function has(name) for _, d in ipairs(ped.decos) do if d[2] == H(name) then return true end end return false end
local function count() return #ped.decos end
local function idOf(label) for _, e in ipairs(SV.exports and SV.export_GetTattooCatalog() or {}) do if e.label == label then return e.id end end end
local function savedOf(cid)
    local data = json.decode(FILES['data/tattoo_looks.json'] or '{}') or {}
    local out = {}
    for _, d in ipairs(data[cid] or {}) do out[#out + 1] = d[2] end
    return out
end
local function savedHas(cid, name) for _, h in ipairs(savedOf(cid)) do if h == H(name) then return true end end return false end
local function login(cid) CID = cid fire('ely_creator:loaded') fire('elyzea:client:playerLoaded') tick(200) end
local function logout() fire('elyzea:client:playerUnloaded') CID = nil tick(20) end
local function shop(add, remove)
    fire('adminmenu:tattoo:show', { id = 7, name = 'Salon', prices = {}, removal = true, payChoice = true, version = 1 })
    tick(10)
    for _, l in ipairs(add or {}) do nui.tattoo_add({ id = idOf(l), on = true }, function() end) end
    for _, l in ipairs(remove or {}) do nui.tattoo_remove({ id = idOf(l), on = true }, function() end) end
    tick(2)
    nui.tattoo_pay({ method = 'cash' }, function() end)
    tick(4)
end

-- =====================================================================
startServer()
startClient()
tick(20)

print('[Test 1] Personnage A : plusieurs tatouages, application immédiate, sauvegarde, reconnexion')
login('A')
check(count() == 0, 'A (nouveau) : aucun tatouage au départ')
shop({ 'Rose', 'Ancre' })
check(has('T_ROSE_M') and has('T_ANCRE_M') and count() == 2, 'A : les 2 tatouages apparaissent tout de suite (avant toute déconnexion)')
check(savedHas('A', 'T_ROSE_M') and savedHas('A', 'T_ANCRE_M') and #savedOf('A') == 2, 'A : enregistrés sur le disque immédiatement (sans attendre)')
check(wallet.A == 5000 - 450 - 250, ('A : payé (%d $ restants)'):format(wallet.A))
tick(40)
logout()
login('A')
check(has('T_ROSE_M') and has('T_ANCRE_M') and count() == 2, 'A après reconnexion : ses 2 tatouages sont là')

print('\n[Test 2] Isolation A / B')
logout()
check(count() == 0, 'retour à la sélection : plus aucun tatouage sur le ped')
login('B')
check(count() == 0, 'B : AUCUN tatouage de A (cause du bug d\'origine)')
shop({ 'Crâne' })
check(has('T_CRANE_M') and count() == 1, 'B : son tatouage apparaît, sans ceux de A')
check(#savedOf('B') == 1 and savedHas('B', 'T_CRANE_M'), 'B : enregistré séparément (1 tatouage)')
check(#savedOf('A') == 2 and not savedHas('A', 'T_CRANE_M'), 'A : inchangé sur le disque')
check(wallet.A == 4300 and wallet.B == 5000 - 250, 'argent : seul B a payé son tatouage')
tick(40)
logout()
login('A')
check(has('T_ROSE_M') and has('T_ANCRE_M') and not has('T_CRANE_M') and count() == 2, 'retour sur A : uniquement ses tatouages')
logout()
login('B')
check(has('T_CRANE_M') and count() == 1, 'retour sur B : uniquement son tatouage')

print('\n[Test 3] Retrait volontaire sur A')
logout()
login('A')
shop(nil, { 'Rose' })
check(not has('T_ROSE_M') and has('T_ANCRE_M') and count() == 1, 'A : la rose disparaît tout de suite, l\'ancre reste')
check(not savedHas('A', 'T_ROSE_M') and savedHas('A', 'T_ANCRE_M'), 'A : retrait enregistré, l\'autre tatouage conservé')
check(#savedOf('B') == 1 and savedHas('B', 'T_CRANE_M'), 'B : pas touché par le retrait')
tick(40)
logout()
login('A')
check(not has('T_ROSE_M') and has('T_ANCRE_M'), 'A après reconnexion : la rose ne réapparaît pas')

print('\n[Test 4] Redémarrage de admin_menu (serveur + client) puis du serveur complet')
startServer()
startClient()
tick(20)
login('A')
check(has('T_ANCRE_M') and count() == 1, 'après redémarrage : A retrouve exactement ses tatouages')
logout()
login('B')
check(has('T_CRANE_M') and count() == 1, 'après redémarrage : B retrouve exactement les siens')

print('\n[Test 8] Changements répétés A ↔ B')
local okLoop = true
for _ = 1, 5 do
    logout() login('A')
    if not (has('T_ANCRE_M') and count() == 1) then okLoop = false end
    logout() login('B')
    if not (has('T_CRANE_M') and count() == 1) then okLoop = false end
end
check(okLoop, '5 allers-retours : chaque personnage garde exactement ses tatouages')

print('\n[Sécurités]')
-- ped « pollué » (ancien bug, autre script) : l'achat n'enregistre que les tatouages de A + le nouveau
logout()
login('A')
ped.decos[#ped.decos + 1] = { H('mpbeach_overlays'), H('T_CRANE_M') }
shop({ 'Étoile' })
check(savedHas('A', 'T_ETOILE_M') and savedHas('A', 'T_ANCRE_M') and not savedHas('A', 'T_CRANE_M'),
    'tatouage d\'un autre personnage resté sur le ped : JAMAIS enregistré sur A')
check(not has('T_CRANE_M') and count() == 2, 'après l\'achat, le ped est remis aux seuls tatouages de A')
tick(40)
-- réponse en retard destinée à A arrivant pendant que B est chargé
logout()
login('B')
fire('adminmenu:tattoo:saved', { { H('mpbeach_overlays'), H('T_ANCRE_M') } }, 'A')
tick(100)
check(not has('T_ANCRE_M') and count() == 1, 'réponse en retard pour A : ignorée sur B')
-- écran de sélection : aucun personnage, rien n'est lu ni écrit
logout()
local before = FILES['data/tattoo_looks.json']
SV.source = 1
for _, fn in ipairs(svEvents['adminmenu:tattoo:pay']) do fn(7, { add = { idOf('Rose') }, remove = {} }, {}, 'cash') end
tick(4)
check(FILES['data/tattoo_looks.json'] == before, 'sans personnage chargé : aucun enregistrement')
-- anciennes données rangées par licence : plus jamais lues
local data = json.decode(FILES['data/tattoo_looks.json'])
data['license:compte'] = { { H('mpbeach_overlays'), H('T_ROSE_M') } }
FILES['data/tattoo_looks.json'] = json.encode(data)
startServer()
startClient()
tick(20)
login('B')
check(not has('T_ROSE_M') and count() == 1, 'ancienne entrée « licence » (commune au compte) ignorée')
-- écran de sélection : liste par personnage pour l'aperçu
local la, lb = SV.export_GetTattoosByCid('A'), SV.export_GetTattoosByCid('B')
check(la and lb and #la == 2 and #lb == 1, 'aperçu de la sélection : tatouages fournis par personnage (A : 2, B : 1)')

print(('\nRésultat : %d réussis, %d échecs'):format(passes, fails))
return fails
