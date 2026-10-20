-- Tests hors jeu des règles du laboratoire (shared/lab_rules.lua) : lancés par run_lab_sim.py
local fails, n = 0, 0
local function check(c, l) n = n + 1 if c then print('  ok   ' .. l) else fails = fails + 1 print('  ÉCHEC ' .. l) end end
local H = 3600
local NOW = 1800000000
local cfg = Config.Lab
local all = { thc = true, cocaine = true, mdma = true, amphetamines = true, opiates = true }

print('[Alcool]')
local function drinks(list) local o = {} for _, d in ipairs(list) do o[#o + 1] = { at = NOW - d[1] * 60, amount = d[2] } end return o end
local a = LabRules.Alcohol({}, NOW, NOW - 30 * 24 * H, cfg.alcohol)
check(a.status == 'negative' and a.present == false and a.bac == 0 and a.level == 'nul', 'aucune consommation, suivi complet : négatif, taux 0, niveau nul')
a = LabRules.Alcohol({}, NOW, NOW - 2 * H, cfg.alcohol)
check(a.status == 'indeterminate' and a.present == nil and a.bac == nil, 'suivi démarré il y a 2 h : indéterminé (pas de négatif inventé)')
a = LabRules.Alcohol(drinks({ { 20, 14 } }), NOW, NOW - 30 * 24 * H, cfg.alcohol)
check(a.status == 'positive' and a.present and a.bac > 0 and a.bac < 0.5 and a.level == 'faible' and a.recency.recent, ('1 cocktail il y a 20 min : positif, faible (%.2f g/L), récent'):format(a.bac))
a = LabRules.Alcohol(drinks({ { 60, 14 }, { 45, 14 }, { 30, 14 }, { 15, 14 }, { 5, 10 } }), NOW, NOW - 30 * 24 * H, cfg.alcohol)
check(a.status == 'positive' and a.level == 'eleve' and a.bac >= 1.0, ('5 verres en 1 h : élevé (%.2f g/L)'):format(a.bac))
a = LabRules.Alcohol(drinks({ { 40, 14 }, { 30, 14 }, { 20, 12 } }), NOW, NOW - 30 * 24 * H, cfg.alcohol)
check(a.level == 'modere', ('3 verres : modéré (%.2f g/L)'):format(a.bac))
a = LabRules.Alcohol(drinks({ { 8 * 60, 14 } }), NOW, NOW - 30 * 24 * H, cfg.alcohol)
check(a.status == 'negative' and a.note, '1 verre il y a 8 h : éliminé, négatif avec mention')
a = LabRules.Alcohol(drinks({ { 3 * 60, 30 } }), NOW, NOW - 30 * 24 * H, cfg.alcohol)
check(a.status == 'positive' and not a.recency.recent, 'grosse consommation il y a 3 h : encore positif, consommation non récente')
a = LabRules.Alcohol({ { at = NOW + 600, amount = 50 } }, NOW, NOW - 30 * 24 * H, cfg.alcohol)
check(a.status == 'negative', 'verre bu APRÈS le prélèvement : ignoré')
a = LabRules.Alcohol(drinks({ { 20, 14 } }), NOW, NOW - 1 * H, cfg.alcohol)
check(a.status == 'positive', 'suivi récent mais consommation enregistrée : positif quand même (données réelles)')
local b1 = LabRules.Alcohol(drinks({ { 20, 14 } }), NOW, 0, cfg.alcohol).bac
local b2 = LabRules.Alcohol(drinks({ { 20, 14 } }), NOW, 0, cfg.alcohol).bac
check(b1 == b2, 'mêmes données, même résultat (aucun hasard)')

print('[Substances]')
local sub = cfg.substances[1]
local s = LabRules.Substance(sub, {}, NOW, NOW - 30 * 24 * H, true)
check(s.status == 'negative', 'aucune prise, suivi complet : négatif')
s = LabRules.Substance(sub, {}, NOW, NOW - 10 * H, true)
check(s.status == 'indeterminate' and s.note, 'suivi plus court que la fenêtre de détection (72 h) : indéterminé')
s = LabRules.Substance(sub, {}, NOW, NOW - 30 * 24 * H, false)
check(s.status == 'indeterminate' and s.note:find('reliée'), 'substance sans source de données : indéterminé')
s = LabRules.Substance(sub, { { at = NOW - 2 * H, amount = 1 } }, NOW, NOW - 30 * 24 * H, true)
check(s.status == 'positive' and s.recency.recent, 'prise il y a 2 h : positif, récent')
s = LabRules.Substance(sub, { { at = NOW - 40 * H, amount = 1 } }, NOW, NOW - 30 * 24 * H, true)
check(s.status == 'positive' and not s.recency.recent, 'prise il y a 40 h (fenêtre 72 h) : positif, plus ancien')
s = LabRules.Substance(sub, { { at = NOW - 80 * H, amount = 1 } }, NOW, NOW - 30 * 24 * H, true)
check(s.status == 'negative', 'prise il y a 80 h : hors fenêtre, négatif')
s = LabRules.Substance(sub, { { at = NOW + 60, amount = 1 } }, NOW, NOW - 30 * 24 * H, true)
check(s.status == 'negative', 'prise après le prélèvement : ignorée')

print('[Analyse complète]')
local r = LabRules.Analyze({ cocaine = { { at = NOW - H, amount = 1 } }, alcohol = { { at = NOW - 600, amount = 14 } } }, NOW, NOW - 30 * 24 * H, cfg, all)
local by = {} for _, x in ipairs(r.substances) do by[x.id] = x.status end
check(#r.substances == #cfg.substances and r.alcohol.status == 'positive', 'toutes les substances de la config sont listées, alcool positif')
check(by.cocaine == 'positive' and by.thc == 'negative' and by.ketamine == 'indeterminate', 'cocaïne positive, cannabis négatif, kétamine (sans source) indéterminée')
print(('Résultat : %d/%d réussis'):format(n - fails, n))
return fails
