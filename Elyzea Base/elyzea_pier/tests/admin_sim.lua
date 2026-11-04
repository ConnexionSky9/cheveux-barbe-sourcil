-- Réglages du parc depuis admin_menu (voir run_admin_sim.py)
local PASS, FAIL = 0, 0
local function check(c, l) if c then PASS = PASS + 1 SIM.print('  ok   ' .. l) else FAIL = FAIL + 1 SIM.print('  ÉCHEC ' .. l) end end
local function section(t) SIM.print('\n[' .. t .. (RUN == 2 and ' · après redémarrage' or '') .. ']') end
json = { encode = function(t) return py_json_encode(t) end, decode = function(s) return py_json_decode(s) end }
function GetResourceKvpString(k) return py_kvp_get(k) end
function SetResourceKvp(k, v) py_kvp_set(k, v) end
function SetEntityCoords(ped, x, y, z) SIM.players[ped - 1000].pos = vector3(x, y, z) end
local LOGS = {}
local realState = GetResourceState
function GetResourceState(r) if r == 'admin_menu' then return 'started' end return realState(r) end
exports.admin_menu = { HasPermission = function(_, src, perm) return SIM.players[src] and SIM.players[src].perms and SIM.players[src].perms[perm] == true end,
    AddLog = function(_, src, a, msg) LOGS[#LOGS + 1] = msg end }
for _, f in ipairs(SIM_FILES) do assert(load(py_read(f), '@' .. f))() end
SIM.run(1000)
local EX = {}
-- exports déclarés par la ressource
local SUM, ACT = PierSettings.Summary, PierSettings.Action
SIM.addPlayer(1, vector3(-1500.0, -1100.0, 13.0), 1000, 10000)
SIM.addPlayer(2, vector3(-1500.0, -1100.0, 13.0), 1000, 10000)
SIM.players[1].perms = { pier_manage = true }
local function act(src, name, data) return SIM.call(function() return ACT(src, name, data or {}) end) end
local S = PierSettings.Get

if RUN == 1 then
    section('Permissions')
    check(SUM(2) == nil and act(2, 'settings', { wheelPrice = 1 }) == false, 'sans la permission « pier_manage » : tout est refusé')
    check(S().wheelPrice == Config.Tickets.wheel.price and GlobalState.pierPublic and GlobalState.pierPublic.npc, 'au démarrage : valeurs de config.lua, état public envoyé aux joueurs')
    local sum = SUM(1)
    check(sum and sum.wheel.capacity == 32 and sum.coaster.capacity == 8 and sum.coaster.natural > 50, 'résumé : capacités, durée réelle du parcours')
    check(#sum.players == 2, 'résumé : joueurs connectés (pour offrir des tickets)')

    section('Réglages')
    check(act(1, 'settings', { wheelPrice = 400, coasterPrice = 600, maxPerPurchase = 99, turnDuration = 10, stopDuration = 20, boardingTime = 40 }), 'réglages envoyés')
    check(Config.Tickets.wheel.price == 400 and Config.Tickets.coaster.price == 600, 'prix appliqués tout de suite (sans redémarrage)')
    check(Config.MaxTicketsPerPurchase == 50 and Config.Wheel.turnDuration == 60, 'valeurs hors limites ramenées (50 tickets max, tour de 60 s min)')
    check(Config.Wheel.stopDuration == 20 and Config.Coaster.boardingTime == 40, 'arrêt en gare 20 s, embarquement 40 s')
    act(1, 'settings', { cash = false, bank = false })
    check(Config.Accounts.cash == true and Config.Accounts.bank == false, 'au moins un moyen de paiement reste accepté')
    act(1, 'settings', { bank = true, cash = true })
    act(1, 'settings', { wheelEnabled = false })
    check(Config.Wheel.enabled == false and GlobalState.pierPublic.wheelEnabled == false and Wheel.Status() == 'fermée', 'grande roue fermée (joueurs prévenus)')
    act(1, 'settings', { wheelEnabled = true })
    -- achat au nouveau prix
    local npc = Config.Npc.coords
    SIM.move(2, vector3(npc.x, npc.y, npc.z))
    local ok = SIM.rpc(2, 'buy', 'wheel', 2, 'cash')
    check(ok and SIM.money[2].cash == 200, 'billetterie : 2 tickets au nouveau prix (800 $)')

    section('Durée du parcours pendant un trajet')
    Coaster._S.phase = 'running'
    act(1, 'settings', { coasterDuration = 90 })
    check(Config.Coaster.duration == nil and SUM(1).pendingDuration, 'train en route : la nouvelle durée attend le retour en gare')
    Coaster._S.phase = 'idle'
    SIM.run(2500)
    check(Config.Coaster.duration == 90 and not SUM(1).pendingDuration, 'train en gare : durée de 90 s appliquée')

    section('Vendeur de tickets')
    SIM.move(1, vector3(-1640.0, -1100.0, 14.0))
    check(act(1, 'npcHere'), 'placer le vendeur à ma position')
    check(math.abs(Config.Npc.coords.x + 1640.0) < 0.01 and math.abs(Config.Npc.coords.z - 13.0) < 0.01 and Config.Npc.coords.w == 90.0, 'position et orientation de l\'admin (au sol)')
    check(GlobalState.pierPublic.npc.x == -1640.0, 'nouvelle position envoyée aux joueurs')
    act(1, 'npc', { model = 'A_M_Y_Beach_01!', scenario = 'world_human_smoke', blip = false })
    check(Config.Npc.model == 'a_m_y_beach_01' and Config.Npc.scenario == 'WORLD_HUMAN_SMOKE' and Config.Npc.blip.enabled == false, 'modèle, animation, icône (textes nettoyés)')
    SIM.move(2, vector3(-1640.0, -1100.0, 14.0))
    check(SIM.rpc(2, 'buy', 'wheel', 1, 'bank') and SIM.money[2].bank == 9600, 'la billetterie suit le vendeur déplacé')
    SIM.call(function() SIM.commands.pier_info(1, {}) end)
    check(SIM.last(1, 'elyzea_pier:notify') ~= nil, '« pier_manage » donne aussi accès aux commandes /pier_info…')

    section('Actions')
    act(1, 'teleport', { to = 'coaster' })
    check(math.abs(SIM.players[1].pos.x - Config.Coaster.entry.x) < 0.01, '« Y aller » : montagnes russes')
    check(act(1, 'give', { target = 2, kind = 'coaster', qty = 3 }) and SIM.items[2][Config.Tickets.coaster.item] == 3, '3 tickets offerts à un joueur')
    check(act(1, 'give', { target = 99, kind = 'coaster', qty = 3 }) == false, 'joueur inconnu : refusé')
    check(act(1, 'give', { target = 2, kind = 'coaster', qty = 500 }) == false, 'quantité excessive : refusée')
    check(act(1, 'reset', { what = 'all' }), 'remise à zéro des deux attractions')
    check(act(1, 'defaults', {}) == false, 'retour à config.lua sans confirmation : refusé')
    check(#LOGS >= 8, ('actions journalisées dans admin_menu (%d)'):format(#LOGS))
else
    section('Conservation')
    check(Config.Tickets.wheel.price == 400 and Config.Tickets.coaster.price == 600, 'prix conservés')
    check(Config.Wheel.stopDuration == 20 and Config.Coaster.boardingTime == 40 and Config.Coaster.duration == 90, 'durées conservées')
    check(math.abs(Config.Npc.coords.x + 1640.0) < 0.01 and Config.Npc.model == 'a_m_y_beach_01' and GlobalState.pierPublic.npc.x == -1640.0, 'vendeur conservé (position, modèle) et envoyé aux joueurs')
    check(act(1, 'defaults', { confirm = true }) and Config.Tickets.wheel.price == 150 and Config.Coaster.duration == nil, 'retour aux réglages de config.lua')
end
SIM.print(('\n%d ok, %d échec(s), %d erreur(s)'):format(PASS, FAIL, #SIM.errors))
return FAIL + #SIM.errors
