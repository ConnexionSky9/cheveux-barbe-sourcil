--[[
    NOIR X — tests de la logique serveur du lot 1, hors FiveM.
    Exécution depuis le dossier de la ressource :   lua5.4 tests/server_spec.lua
    Les natives FiveM sont simulées ; seules les règles de NOIR X sont testées
    (vérification de possession, session/jeton, anti-spam, validation des réglages,
    fermeture sur perte d'item, déconnexion). Ce n'est PAS un test en jeu.
]]

-- ─── Simulation minimale de l'environnement FiveM ───────────────
local clock = 0
local threads, netHandlers, eventHandlers, exported, sent = {}, {}, {}, {}, {}
local players = { [1] = 'Alpha', [2] = 'Bravo' }
local aces = {}

function GetGameTimer() return clock end
function CreateThread(fn) threads[#threads + 1] = fn end
function Wait() end
function GetResourceState() return 'missing' end
function GetCurrentResourceName() return 'noirx' end
function GetPlayerName(src) return players[src] end
function GetPlayerIdentifierByType(src, kind)
    if kind == 'license' and players[src] then return 'license:test' .. src end
    return nil
end
function IsPlayerAceAllowed(src, ace) return aces[src .. ace] == true end
function RegisterNetEvent(name, fn) netHandlers[name] = fn end
function AddEventHandler(name, fn) eventHandlers[name] = fn end
function TriggerClientEvent(name, src, ...) sent[#sent + 1] = { name = name, src = src, args = { ... } } end
exports = setmetatable({}, { __call = function(_, name, fn) exported[name] = fn end })

-- encodeur JSON minimal pour Audit (non vérifié par les tests)
json = { encode = function() return '{}' end, decode = function() return {} end }

local function fire(name, src, ...)
    source = src
    return netHandlers[name](...)
end
local function last(name, src)
    for i = #sent, 1, -1 do
        if sent[i].name == name and (not src or sent[i].src == src) then return sent[i] end
    end
end

-- ─── Chargement de la ressource ─────────────────────────────────
for _, f in ipairs({
    'config.lua', 'shared/utils.lua',
    'bridge/server/database.lua', 'bridge/server/identity.lua',
    'bridge/server/inventory.lua', 'bridge/server/custom_inventory.lua',
    'server/audit.lua',
    'server/core/players.lua', 'server/core/locks.lua',
    'server/phone.lua',
}) do dofile(f) end
Config.Debug = false
Config.Identity.provider = 'license'  -- tests génériques ; le pont Elyzea est testé dans elyzea_spec.lua
DB.driver = 'none'

-- Modules du lot 2 référencés par phone.lua mais hors du périmètre de ce test (lot 1).
Push = { Notify = function(src, title, body)
    if not Inventory.HasItem(src, Config.Item.name) then return false end
    TriggerClientEvent('noirx:client:notify', src, title, body); return true
end }
Payouts = { Deliver = function() return 0 end }

-- Inventaire simulé, branché via l'adaptateur comme le ferait un vrai serveur
local owned = {}
InventoryCustom.Implemented = true
InventoryCustom.HasItem = function(src, item) return item == 'noirphone' and owned[src] == true end

-- ─── Mini framework de tests ────────────────────────────────────
local passed, failed = 0, 0
local tok2 -- jeton courant du joueur 2, partagé entre tests
local function test(name, fn)
    sent = {}
    clock = clock + 10000
    local ok, err = pcall(fn)
    if ok then passed = passed + 1; print('  ok   ' .. name)
    else failed = failed + 1; print('  FAIL ' .. name .. '\n       ' .. tostring(err)) end
end
local function eq(a, b, msg) if a ~= b then error((msg or '') .. ' attendu ' .. tostring(b) .. ', obtenu ' .. tostring(a), 2) end end

print('NOIR X — tests serveur (lot 1)')

test('refuse l\'ouverture sans item', function()
    owned[1] = false
    eq(exported.UseNoirphone(1), false)
    eq(last('noirx:client:open', 1), nil)
end)

test('ouvre avec item et transmet un jeton', function()
    owned[1] = true
    eq(exported.UseNoirphone(1), true)
    local m = last('noirx:client:open', 1)
    assert(m, 'aucun événement open')
    assert(type(m.args[1].token) == 'string' and #m.args[1].token >= 16, 'jeton invalide')
    assert(m.args[1].serial:match('^NX%-%w%w%w%w%-%w%w%w%w$'), 'série invalide')
    eq(exported.IsPhoneOpen(1), true)
end)

test('l\'usage ne modifie pas l\'inventaire (aucune duplication)', function()
    -- l'API de NOIR X n'appelle ni AddItem ni RemoveItem à l'ouverture
    local calls = 0
    InventoryCustom.AddItem = function() calls = calls + 1 return true end
    InventoryCustom.RemoveItem = function() calls = calls + 1 return true end
    exported.ForceClose(1, 'test')
    exported.UseNoirphone(1)
    eq(calls, 0)
end)

test('anti-spam : deux ouvertures rapprochées', function()
    exported.ForceClose(1, 'test')
    clock = clock + 5000
    eq(exported.UseNoirphone(1), true)
    exported.ForceClose(1, 'test')
    clock = clock + 100
    eq(exported.UseNoirphone(1), false, 'cooldown ignoré :')
end)

test('fermeture refusée avec un mauvais jeton', function()
    exported.UseNoirphone(1)
    fire('noirx:server:closed', 1, 'faux-jeton')
    eq(exported.IsPhoneOpen(1), true)
    local token = last('noirx:client:open', 1) and last('noirx:client:open', 1).args[1].token
    if not token then error('pas de session ouverte pour le test') end
end)

test('un joueur ne peut pas utiliser le jeton d\'un autre', function()
    exported.ForceClose(1, 'test'); sent = {}
    clock = clock + 5000
    exported.UseNoirphone(1)
    local token1 = last('noirx:client:open', 1).args[1].token
    owned[2] = true
    exported.UseNoirphone(2)
    fire('noirx:server:closed', 2, token1)
    eq(exported.IsPhoneOpen(2), true, 'session 2 fermée avec jeton 1 :')
    fire('noirx:server:closed', 1, token1)
    eq(exported.IsPhoneOpen(1), false)
end)

test('réglages : valeurs valides acceptées et bornées', function()
    exported.ForceClose(2, 'test'); clock = clock + 5000
    exported.UseNoirphone(2)
    local tok = last('noirx:client:open', 2).args[1].token
    fire('noirx:server:saveSettings', 2, tok, { wallpaper = 'grid', volume = 7, sounds = false, battery = 3 })
    exported.ForceClose(2, 'test'); clock = clock + 5000; sent = {}
    exported.UseNoirphone(2)
    local m = last('noirx:client:open', 2)
    tok2 = m.args[1].token
    local s = m.args[1].settings
    eq(s.wallpaper, 'grid'); eq(s.volume, 1.0); eq(s.sounds, false); eq(s.battery, Config.UI.battery.min)
end)

test('réglages : valeur hors liste rejetée en bloc', function()
    fire('noirx:server:saveSettings', 2, tok2, { wallpaper = '../../etc', volume = 0.1 })
    exported.ForceClose(2, 'test'); clock = clock + 5000; sent = {}
    exported.UseNoirphone(2)
    local m = last('noirx:client:open', 2)
    tok2 = m.args[1].token
    local s = m.args[1].settings
    eq(s.wallpaper, 'grid'); eq(s.volume, 1.0)
end)

test('réglages : NaN et types invalides rejetés', function()
    fire('noirx:server:saveSettings', 2, tok2, { volume = 0 / 0 })
    fire('noirx:server:saveSettings', 2, tok2, { sounds = 'oui' })
    fire('noirx:server:saveSettings', 2, tok2, 'pas une table')
    exported.ForceClose(2, 'test'); clock = clock + 5000; sent = {}
    exported.UseNoirphone(2)
    local s = last('noirx:client:open', 2).args[1].settings
    eq(s.volume, 1.0); eq(s.sounds, false)
end)

test('perte de l\'item pendant l\'ouverture → fermeture forcée', function()
    owned[2] = false
    -- exécute une itération de la boucle de revérification
    local loop
    for _, t in ipairs(threads) do
        local info = debug.getinfo(t, 'S')
        if info.source:match('phone%.lua') and info.linedefined > 200 then loop = t end
    end
    assert(loop, 'boucle de revérification introuvable')
    local co = coroutine.create(loop)
    local realWait = Wait
    Wait = function() coroutine.yield() end
    coroutine.resume(co)   -- jusqu'au premier Wait
    coroutine.resume(co)   -- une itération complète
    Wait = realWait
    eq(exported.IsPhoneOpen(2), false)
    local m = last('noirx:client:forceClose', 2)
    assert(m and m.args[1] == 'item_lost', 'raison attendue item_lost')
end)

test('déconnexion → session nettoyée', function()
    owned[1] = true; clock = clock + 5000
    exported.UseNoirphone(1)
    source = 1
    eventHandlers.playerDropped()
    eq(exported.IsPhoneOpen(1), false)
end)

test('inventaire non relié → ouverture refusée', function()
    InventoryCustom.Implemented = false
    clock = clock + 5000
    eq(exported.UseNoirphone(1), false)
    InventoryCustom.Implemented = true
end)

test('Notify refusé sans item', function()
    owned[1] = false
    eq(exported.Notify(1, 'T', 'B'), false)
    owned[1] = true
    eq(exported.Notify(1, 'T', 'B'), true)
end)

print(('\n%d réussis, %d échoués'):format(passed, failed))
if failed > 0 then os.exit(1) end
