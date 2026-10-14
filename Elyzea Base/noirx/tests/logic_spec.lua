--[[
    NOIR X — tests du lot 2 : logique déterministe et sécurité SANS base de données.
    Exécution : lua tests/logic_spec.lua (ou via le lanceur du projet).
    Couvre ce qui ne dépend pas du SQL : calculs de blanchiment, génération/anti-triche du duel,
    normalisation Ratline, validation des pseudos, validation des réglages admin, et le filtrage
    des appels RPC (jeton, rejeu, limite de fréquence, application désactivée, arguments).
    Les flux persistés (chat, achats, paiements) se vérifient en jeu : voir la checklist du README.
]]

-- ─── Environnement FiveM minimal ───────────────────────────────
local clock = 0
local threads, netHandlers, eventHandlers, exported, sent = {}, {}, {}, {}, {}
local players = { [1] = 'Alpha', [2] = 'Bravo' }
local aces = {}

function GetGameTimer() return clock end
function CreateThread() end
function Wait() end
function SetTimeout() end
function GetResourceState() return 'missing' end
function GetCurrentResourceName() return 'noirx' end
function GetPlayerName(src) return players[src] end
function GetPlayers() return { '1', '2' } end
function GetPlayerIdentifierByType(src, kind) if kind == 'license' and players[src] then return 'license:p' .. src end end
function IsPlayerAceAllowed(src, ace) return aces[src .. ace] == true end
function GetInvokingResource() return nil end
function RegisterNetEvent(n, f) netHandlers[n] = f end
function AddEventHandler(n, f) eventHandlers[n] = f end
function RegisterCommand() end
function TriggerClientEvent(n, s, ...) sent[#sent + 1] = { name = n, src = s, args = { ... } } end
function TriggerEvent() end
exports = setmetatable({}, { __call = function(_, n, f) exported[n] = f end })
json = { encode = function() return '{}' end, decode = function() return {} end }

dofile('config.lua')
dofile('shared/utils.lua')
DB = { driver = 'none', ready = true }
function DB.Query() return {} end
function DB.Single() return nil end
function DB.Execute() return 0 end
function DB.Insert() return nil end

dofile('bridge/server/identity.lua')
dofile('bridge/server/devtest.lua')
dofile('bridge/server/inventory.lua')
dofile('bridge/server/custom_inventory.lua')
dofile('bridge/server/economy.lua')
dofile('bridge/server/custom_economy.lua')
dofile('bridge/server/admin.lua')
dofile('server/audit.lua')
dofile('server/core/players.lua')
dofile('server/core/locks.lua')
dofile('server/core/settings.lua')
dofile('server/core/boot.lua')
dofile('server/phone.lua')
dofile('server/core/rpc.lua')
dofile('server/core/payouts.lua')
dofile('server/apps/ghostline.lua')
dofile('server/apps/ratline.lua')
dofile('server/apps/launder.lua')
Config.Debug = false
Config.Identity.provider = 'license'  -- tests génériques ; le pont Elyzea est testé dans elyzea_spec.lua

-- ─── Framework ──────────────────────────────────────────────────
local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1; print('  ok   ' .. name)
    else failed = failed + 1; print('  FAIL ' .. name .. '\n       ' .. tostring(err)) end
end
local function eq(a, b, m) if a ~= b then error((m or '') .. ' attendu ' .. tostring(b) .. ', obtenu ' .. tostring(a), 2) end end
local function truthy(v, m) if not v then error(m or 'faux', 2) end end

print('NOIR X — tests logique & sécurité (lot 2)')

-- ── Blanchiment : calculs ──
test('Launder.Fee = pourcentage configuré', function()
    Config.Laundering.feePercent = 30
    eq(Launder.Fee(10000), 3000)
    eq(Launder.Fee(1234), 370)
end)

test('Launder.Duration croît avec le montant et plafonne', function()
    Config.Laundering.baseSeconds = 60
    Config.Laundering.secondsPer1000 = 6
    Config.Laundering.maxSeconds = 900
    eq(Launder.Duration(1000), 66)
    eq(Launder.Duration(10000), 120)
    truthy(Launder.Duration(10000000) == 900, 'plafond non respecté')
end)

test('ligne de duel : longueur dans les bornes', function()
    for _ = 1, 200 do
        local line = Launder.GenerateLine(26, 40)
        truthy(#line >= 26 and #line <= 40, 'longueur ' .. #line)
        truthy(not line:find('\n'), 'saut de ligne interdit')
    end
end)

test('anti-triche : délai humain minimal cohérent', function()
    Config.Laundering.hack.maxHumanCps = 16
    local line = string.rep('a', 32)
    -- 32 / 16 = 2 s + 300 ms
    eq(Launder.MinHumanMs(line), 2300)
end)

-- ── Ratline : normalisation ──
test('Ratline.Normalize retire accents et ponctuation', function()
    eq(Ratline.Normalize('Où sont les Champs ?!'), 'ou sont les champs ')
    eq(Ratline.Normalize('DÉALER, coke'), 'dealer coke')
end)

-- ── Ghostline : pseudos ──
test('Ghost.ValidHandle applique les règles', function()
    Config.Chat.handleMin = 3; Config.Chat.handleMax = 20
    truthy(Ghost.ValidHandle('corvus_07'))
    truthy(Ghost.ValidHandle('a.b-c'))
    eq(Ghost.ValidHandle('ab'), nil, 'trop court accepté :')
    eq(Ghost.ValidHandle('with space'), nil, 'espace accepté :')
    eq(Ghost.ValidHandle('bad/slash'), nil, 'caractère interdit accepté :')
    eq(Ghost.ValidHandle(string.rep('a', 21)), nil, 'trop long accepté :')
end)

-- ── Réglages admin ──
test('Settings : type respecté, chemins verrouillés et inconnus refusés', function()
    truthy(Settings.Set('Laundering.feePercent', 22))
    eq(Config.Laundering.feePercent, 22)
    truthy(not Settings.Set('Laundering.feePercent', 'x'), 'type incohérent accepté')
    truthy(not Settings.Set('Laundering.feePercent', 0 / 0), 'NaN accepté')
    truthy(not Settings.Set('Inventory.provider', 'esx'), 'chemin verrouillé modifié')
    truthy(not Settings.Set('Rien.De.Tout', 5), 'chemin inconnu accepté')
    local ok, err = Settings.Set('Laundering.hack', {})
    truthy(not ok and err == 'table_not_allowed')
    Settings.Set('Laundering.feePercent', 30)
end)

test('Settings : booléen imbriqué modifiable (app activée)', function()
    local before = Config.Apps[1].enabled
    truthy(Settings.Set('Apps.1.enabled', not before))
    eq(Config.Apps[1].enabled, not before)
    Settings.Set('Apps.1.enabled', before)
end)

-- ── RPC : sécurité ──
-- Ouvre une "session" factice pour le joueur 1 via l'export réel.
Config.Inventory.provider = 'devtest'
aces['1noirx.devtest'] = true   -- possède l'item simulé
exported.UseNoirphone(1)
local tok
for i = #sent, 1, -1 do if sent[i].name == 'noirx:client:open' then tok = sent[i].args[1].token break end end
truthy(tok, 'session de test non ouverte')

-- Handlers de test sans base
local calls = 0
Rpc.Register('test.echo', { db = false, rate = { 100, 100 } }, function(src, ctx, args)
    return { ok = true, charId = ctx.charId, got = args.v }
end)
Rpc.Register('test.rate', { db = false, rate = { 3, 100 } }, function()
    calls = calls + 1
    return { ok = true }
end)
Rpc.Register('test.disabled', { db = false, app = 'app_inexistante' }, function() return { ok = true } end)

local rid = 0
-- Connexion par burner obligatoire : le joueur de test est connecté
local function loginAll() for _, c in pairs(Players.cache or {}) do Auth.logins[c] = { id = 1, handle = 'test', exp = os.time() + 3600 } end end
local function dispatch(token, name, args)
    loginAll()
    local cid = Players.CharOf(1)
    if cid then Auth.logins[cid] = { id = 1, handle = 'test', exp = os.time() + 3600 } end
    rid = rid + 1; return Rpc.Dispatch(1, token, rid, name, args or {})
end

test('RPC : appel valide passe et reçoit charId', function()
    local r = dispatch(tok, 'test.echo', { v = 42 })
    truthy(r.ok); eq(r.got, 42); truthy(r.charId)
end)

test('RPC : mauvais jeton rejeté', function()
    local r = Rpc.Dispatch(1, 'faux', 9999, 'test.echo', {})
    truthy(not r.ok); eq(r.error, 'session')
end)

test('RPC : reqId rejoué/inférieur rejeté', function()
    local r = Rpc.Dispatch(1, tok, 1, 'test.echo', {})
    truthy(not r.ok); eq(r.error, 'replay')
end)

test('RPC : action inconnue rejetée', function()
    local r = dispatch(tok, 'test.inexistant', {})
    truthy(not r.ok); eq(r.error, 'unknown')
end)

test('RPC : application désactivée rejetée', function()
    local r = dispatch(tok, 'test.disabled', {})
    truthy(not r.ok); eq(r.error, 'disabled')
end)

test('RPC : limite de fréquence respectée', function()
    local allowed = 0
    for _ = 1, 6 do
        local r = dispatch(tok, 'test.rate', {})
        if r.ok then allowed = allowed + 1 end
    end
    eq(allowed, 3, 'quota non appliqué :')
    eq(calls, 3, 'handler exécuté au-delà du quota :')
end)

test('RPC : handler exigeant la base rejeté sans base', function()
    Rpc.Register('test.needdb', { db = true }, function() return { ok = true } end)
    local r = dispatch(tok, 'test.needdb', {})
    truthy(not r.ok); eq(r.error, 'no_database')
end)

test('RPC : arguments non-table rejetés', function()
    local r = Rpc.Dispatch(1, tok, 10000, 'test.echo', 'pas une table')
    truthy(not r.ok); eq(r.error, 'bad_args')
end)

-- ── Verrous ──
test('Locks empêche la réentrance sur la même clé', function()
    local inside = false
    local reentered = false
    Locks.Run('k', function()
        inside = true
        local ok = Locks.Run('k', function() reentered = true end)
        eq(ok, false, 'réentrance autorisée :')
    end)
    truthy(inside); truthy(not reentered)
end)

-- ── Payouts sûrs sans base ──
test('Payouts sans base ne plante pas et ne verse rien', function()
    local id = Payouts.Queue('char:x', 'clean', 5000, 'test', 'ref')
    eq(id, nil)
    local n = Payouts.Deliver(1)
    eq(n, 0)
end)

-- ── Wallet via devtest (sans base) ──
test('Wallet lit l\'inventaire/économie simulés (devtest)', function()
    Config.Economy.provider = 'devtest'
    local w = Wallet.Get(1)
    truthy(w.dirty ~= nil and w.dirty >= 0)
    truthy(w.clean ~= nil and w.clean >= 0)
end)

test('Validation des montants d\'inventaire (négatifs, fractions, NaN)', function()
    eq(Inventory.AddItem(1, 'x', -5), false)
    eq(Inventory.AddItem(1, 'x', 1.5), false)
    eq(Inventory.AddItem(1, 'x', 0 / 0), false)
    eq(Inventory.RemoveItem(1, 'x', 0), false)
end)

print(('\n%d réussis, %d échoués'):format(passed, failed))
if failed > 0 then os.exit(1) end
