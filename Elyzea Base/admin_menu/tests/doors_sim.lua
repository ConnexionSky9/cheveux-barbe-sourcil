-- Simulation hors jeu : accès des portes par métier et pupitres de commande (server/door_access.lua)
local root = ...
dofile(root .. '/server/door_access.lua')
local DA = DoorAccess
local fails, n = 0, 0
local function check(name, cond)
    n = n + 1
    if cond then print('OK   ' .. name) else fails = fails + 1 print('FAIL ' .. name) end
end
local cfg = { jobCategories = { { key = 'police' }, { key = 'ems' }, { key = 'meca' }, { key = 'd8' }, { key = 'concess' } } }

-- Joueurs types
local cop    = { state = { police = { job = 'lspd', duty = true } }, job = 'lspd', duty = true }
local copOff = { state = { police = { job = 'bcso', duty = false } }, job = 'bcso', duty = false }
local medic  = { state = { ems = { job = 'ems', duty = true } }, job = 'ems', duty = true }
local civ    = { state = {}, job = 'unemployed', duty = true }
local taxi   = { state = {}, job = 'taxi', duty = true }
local function inj(p, keys, c) return DA.InJobs(p.state, p.job, p.duty, keys, c or cfg) end

check('police : catégorie « police » ouvre', inj(cop, { 'police' }))
check('police : métier précis « lspd » ouvre', inj(cop, { 'lspd' }))
check('BCSO hors « lspd » refusé', not inj(copOff, { 'lspd' }))
check('BCSO dans catégorie police (sans service exigé)', inj(copOff, { 'police' }))
check('BCSO hors service refusé si service exigé', not inj(copOff, { 'police' }, { jobCategories = cfg.jobCategories, jobNeedDuty = true }))
check('policier en service accepté si service exigé', inj(cop, { 'police' }, { jobCategories = cfg.jobCategories, jobNeedDuty = true }))
check('EMS refusé sur porte police', not inj(medic, { 'police' }))
check('EMS accepté si ems dans la liste', inj(medic, { 'police', 'ems' }))
check('civil refusé', not inj(civ, { 'police', 'ems' }))
check('métier du core (taxi) accepté', inj(taxi, { 'taxi' }))
check('liste vide = personne', not inj(cop, {}))
check('liste nil = personne', not inj(cop, nil))

-- Rôles
local door = { id = 1, owners = { { id = 'CID1' } }, jobs = { 'police' } }
local function role(p, isAdmin, cid, d) return DA.Role(isAdmin, cid, d or door, function(k) return inj(p, k) end) end
check('staff = admin', role(civ, true, 'X') == 'admin')
check('clés = owner', role(civ, false, 'CID1') == 'owner')
check('policier = job', role(cop, false, 'CID9') == 'job')
check('civil = visitor', role(civ, false, 'CID9') == 'visitor')
check('porte sans métier : policier = visitor', role(cop, false, 'CID9', { id = 2, owners = {} }) == 'visitor')
check('cid nil ne correspond à aucun propriétaire', role(civ, false, nil, { id = 3, owners = { { id = nil } } }) == 'visitor')
check('job peut ouvrir/fermer', DA.CanToggle('job'))
check('visitor ne peut pas ouvrir sans code', not DA.CanToggle('visitor'))
check('job ne gère pas le code invité', not DA.CanManageCode('job'))
check('owner gère le code', DA.CanManageCode('owner'))

-- Nettoyage
local jobs = DA.CleanJobs({ 'Police', 'police', ' lspd ', '<script>', '', 42, 'a-b_c' }, 10)
check('CleanJobs : minuscules, sans doublon, filtré', table.concat(jobs, ',') == 'police,lspd,script,42,a-b_c')
check('CleanJobs : limite', #DA.CleanJobs({ 'a', 'b', 'c', 'd' }, 2) == 2)
check('CleanJobs : pas une table', #DA.CleanJobs('police') == 0)
local exists = function(id) return id == 1 or id == 2 or id == 5 end
local ids = DA.CleanDoorIds({ 1, '2', 2, 3, -1, 5.7, 'x' }, exists, 40)
check('CleanDoorIds : existantes et sans doublon', table.concat(ids, ',') == '1,2,5')

-- Pupitres
local panel = { id = 1, jobs = { 'lspd' }, doors = { 1, 2 } }
local function canUse(p, isAdmin, pn) return DA.CanUsePanel(isAdmin, pn or panel, function(k) return inj(p, k) end) end
check('pupitre : LSPD accepté', canUse(cop, false))
check('pupitre : BCSO refusé (pupitre LSPD)', not canUse(copOff, false))
check('pupitre : civil refusé', not canUse(civ, false))
check('pupitre : staff accepté', canUse(civ, true))
check('pupitre sans métier : seul le staff', not canUse(cop, false, { jobs = {}, doors = {} }) and canUse(civ, true, { jobs = {}, doors = {} }))
check('pupitre : porte reliée', DA.PanelHasDoor(panel, 2) and DA.PanelHasDoor(panel, '1'))
check('pupitre : porte non reliée refusée', not DA.PanelHasDoor(panel, 3) and not DA.PanelHasDoor(panel, nil))

print(('\n%d/%d'):format(n - fails, n))
return fails
