-- Simulation serveur d'elyzea_drogues (lancée par run_drogues_sim.py)
print = _PRINT or print
local fails, n = 0, 0
local function check(c, l) n = n + 1 if c then print('  ok   ' .. l) else fails = fails + 1 print('  ÉCHEC ' .. l) end end
local function last(ev, target) for i = #SENT, 1, -1 do if SENT[i].ev == ev and (not target or SENT[i].target == target) then return SENT[i] end end end
local function use(src, item) SENT = {} local fn = USABLE[item] return fn and fn(src) end

print('[Objets utilisables]')
local count = 0 for _ in pairs(USABLE) do count = count + 1 end
local expected = 0 for _, d in pairs(Config.Drugs) do expected = expected + #d.items end
check(count == expected and USABLE.weed_pouch and USABLE.cocaine and USABLE.meth and USABLE.magic_mushroom and USABLE.dried_mushroom and USABLE.ketamine, ('toutes les drogues sont utilisables (%d objets)'):format(count))

print('[Prise]')
local r = use(1, 'cocaine')
local take = last('elyzea_drogues:take', 1)
check(r == true and take and take.args[1] == 'cocaine' and take.args[2] == 150, 'cocaïne : 1 unité consommée, effet de 150 s envoyé au joueur')
check(EMS[#EMS] and EMS[#EMS].src == 1 and EMS[#EMS].kind == 'cocaine', 'prise enregistrée pour le laboratoire EMS (cocaïne)')
r = use(1, 'cocaine')
check(r == false and NOTES[#NOTES]:find('Attends'), 'délai entre deux prises : refusé, rien consommé')
NOW = NOW + 46
r = use(1, 'cokebaggy')
take = last('elyzea_drogues:take', 1)
check(r == true and take.args[2] == 254, ('reprise : effet prolongé (%s s restants)'):format(take.args[2]))
NOW = NOW + 46
use(1, 'cocaine')
take = last('elyzea_drogues:take', 1)
check(take.args[2] <= 300, ('cumul plafonné à 2 × la durée (%s s)'):format(take.args[2]))
r = use(2, 'magic_mushroom')
check(r == true and last('elyzea_drogues:take', 2).args[1] == 'mushrooms' and EMS[#EMS].kind == 'psilocybin', 'champignons : effet « hallucinations », psilocybine pour le labo')
r = use(3, 'weed_pouch')
check(r == true and NEEDS[3] and NEEDS[3][1] == -10 and NEEDS[3][3] == -15, 'cannabis : donne faim (-10) et détend (-15 stress)')
STATES[4] = { pvpArena = true }
check(use(4, 'meth') == false, 'pendant une partie d\'arène : refusé')
STATES[5] = { emsDown = true }
check(use(5, 'meth') == false, 'à terre : refusé')

print('[Admin]')
check(AdminData(9).denied == true and select(1, AdminAction(9, 'settings_save', {})) == false, 'sans permission « drugs_effects » : refusé')
local d = AdminData(99)
check(d.available and #d.drugs == 8 and #d.creatures == #Config.Trip.creatures and #d.users >= 2, 'données du menu : 8 drogues, créatures, joueurs sous effet')
local s = { drugs = { meth = { enabled = false, duration = 5000, cooldown = 10 } }, trip = { maxCreatures = 99, spawnEvery = 3 }, creatures = { a_c_cow = false } }
local ok, msg = AdminAction(99, 'settings_save', { settings = s })
d = AdminData(99)
local meth = nil for _, x in ipairs(d.drugs) do if x.id == 'meth' then meth = x end end
check(ok and meth.enabled == false and meth.duration == 3600 and d.trip.maxCreatures == 12 and d.trip.spawnEvery == 3, 'réglages enregistrés et bornés (durée max 1 h, 12 créatures max)')
check(DBV and DBV:find('"meth"'), 'réglages gardés en base')
check(last('elyzea_drogues:settings', -1) ~= nil, 'réglages envoyés à tous les joueurs')
NOW = NOW + 100
check(use(6, 'meth') == false and NOTES[#NOTES]:find('désactivé'), 'drogue désactivée dans le menu : refusée')
local none = { creatures = {} } for _, c in ipairs(Config.Trip.creatures) do none.creatures[c.model] = false end
ok = AdminAction(99, 'settings_save', { settings = none })
check(ok == false, 'toutes les créatures désactivées : refusé')
ok = AdminAction(99, 'settings_save', { settings = { drugs = { mushrooms = { duration = 60, cooldown = 0 } } } })
use(7, 'dried_mushroom')
check(last('elyzea_drogues:take', 7).args[2] == 60, 'durée de défonce réglée dans le menu appliquée (60 s)')
ok = AdminAction(99, 'stop_player', { id = 2 })
check(ok and last('elyzea_drogues:stop', 2), 'arrêter les effets d\'un joueur')
local before = #EMS
ok = AdminAction(99, 'test_self', { id = 'ketamine' })
check(ok and last('elyzea_drogues:take', 99).args[3] == true and #EMS == before, 'test staff : effet appliqué, rien enregistré pour le labo')
AdminAction(99, 'settings_reset', {})
check(AdminData(99).drugs[1].enabled ~= nil and (function() for _, x in ipairs(AdminData(99).drugs) do if x.id == 'meth' then return x.enabled end end end)() == true, 'retour aux réglages de config.lua')

print('[Règles]')
check(DrugRules.Extend(0, 1000, 100, 2) == 1100 and DrugRules.Extend(1150, 1000, 100, 2) == 1200, 'prolongation et plafond')
check(DrugRules.DrugOfItem('crack_baggy') == 'crack' and DrugRules.DrugOfItem('bread') == nil, 'objet → drogue')
print(('Résultat : %d/%d réussis'):format(n - fails, n))
return fails
