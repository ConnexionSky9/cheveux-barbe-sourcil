-- Simulation hors jeu : liaison admin_menu <-> elyzea_lasergame (vrais fichiers, faux FiveM)
--  · permission « lasergame_manage » déclarée et donnée au SuperAdmin ;
--  · rôle de PNJ « LaserGame » enregistré par l'éditeur + export GetLaserGameNpcs ;
--  · onglet « LaserGame » : données réservées à la permission, ouverture du panneau, arrêt d'une partie ;
--  · elyzea_lasergame : la permission staff vient d'admin_menu (l'ACE ne compte plus quand admin_menu tourne).
local root = ...
local fails, n = 0, 0
local function check(name, cond)
    n = n + 1
    if cond then print('OK   ' .. name) else fails = fails + 1 print('FAIL ' .. name) end
end

local function stub() return setmetatable({}, { __index = function() return stub() end, __call = function() return nil end }) end
local sent, notes, logs = {}, {}, {}
RegisterNetEvent = function() end
AddEventHandler = function() end
RegisterCommand = function() end
CreateThread = function() end
SetTimeout = function(_, fn) fn() end
Wait = function() end
GetGameTimer = function() return 0 end
GetHashKey = function(s) return #s end
TriggerEvent = function() end
TriggerClientEvent = function(name, target, ...) sent[#sent + 1] = { name = name, target = target, args = { ... } } end
TriggerLatentClientEvent = function() end
GetCurrentResourceName = function() return 'admin_menu' end
GetPlayerName = function(s) return 'J' .. tostring(s) end
GetPlayerPed = function(s) return s end
GetPlayers = function() return {} end
GetEntityCoords = function() return { x = 0, y = 0, z = 0 } end
json = { encode = function() return '' end, decode = function() return {} end }
local STARTED = { elyzea_lasergame = true, admin_menu = true }
GetResourceState = function(r) return STARTED[r] and 'started' or 'missing' end

-- Exports : ceux d'admin_menu sont rangés dans EXP ; ceux d'elyzea_lasergame sont simulés
EXP = {}
local LG_EXP = {
    AdminSummary = function() return { games = { { uid = 'g1', mode = 'pvp', name = 'Finale', phase = 'playing', players = {} } }, stats = { players = 3 }, command = 'lgadmin' } end,
    AdminStopGame = function(src, uid) LG_STOPPED = { src = src, uid = uid } return true, 'Partie arrêtée.' end,
}
exports = setmetatable({}, {
    __call = function(_, name, fn) EXP[name] = fn end,
    __index = function(_, res)
        if res == 'elyzea_lasergame' then return setmetatable({}, { __index = function(_, f) return function(_, ...) return LG_EXP[f](...) end end }) end
        return stub()
    end,
})

local perms = { [1] = true }   -- 1 : staff avec la case LaserGame · 2 : staff sans
Storage = { load = function(_, def) return def end, saveLater = function() end, save = function() end }
Bridge = setmetatable({}, { __index = function() return function() end end })
AdminMenu = {
    Actions = {}, DataHooks = {},
    rateLimit = function() return true end,
    notify = function(src, msg, kind) notes[#notes + 1] = { src = src, msg = msg, kind = kind } end,
    addLog = function(src, a, d) logs[#logs + 1] = { src = src, a = a, d = d } end,
    hasPerm = function(src, p) return p == 'lasergame_manage' and perms[src] == true or src == 1 end,
    getLevel = function() return 100 end,
    onDuty = function() return true end,
}
setmetatable(_G, { __index = function() return stub() end })
dofile(root .. '/config.lua')
dofile(root .. '/server/editor.lua')
dofile(root .. '/server/lasergame.lua')
setmetatable(_G, nil)

print('— Permission')
local found
for _, p in ipairs(Config.Permissions or {}) do if p.key == 'lasergame_manage' then found = p end end
check('case « LaserGame » dans Staff › Rangs (lasergame_manage)', found ~= nil)
local sa = Config.DefaultRanks and Config.DefaultRanks.superadmin
local inSA = false
for _, k in ipairs((sa and sa.perms) or {}) do if k == 'lasergame_manage' then inSA = true end end
check('donnée au SuperAdmin par défaut', inSA)
local mainSrc = io.open(root .. '/server/main.lua'):read('a')
-- Ancien config.lua sans la permission : permissions_extra.lua l'ajoute (rien à recopier)
for i = #Config.Permissions, 1, -1 do if Config.Permissions[i].key == 'lasergame_manage' then table.remove(Config.Permissions, i) end end
dofile(root .. '/permissions_extra.lua')
local back = 0
for _, p in ipairs(Config.Permissions) do if p.key == 'lasergame_manage' then back = back + 1 end end
check('ancien config.lua (non remplacé) : la case apparaît quand même, une seule fois', back == 1)
dofile(root .. '/permissions_extra.lua')
back = 0
for _, p in ipairs(Config.Permissions) do if p.key == 'lasergame_manage' then back = back + 1 end end
check('pas de doublon si les deux la contiennent', back == 1)
check('rangs déjà enregistrés : ajout automatique au SuperAdmin (migration lasergame1)', mainSrc:find('meta.lasergame1', 1, true) ~= nil and mainSrc:find('perms.lasergame_manage = true', 1, true) ~= nil)

print('— Rôle de PNJ « LaserGame » (éditeur de map)')
local A = AdminMenu.Actions
A.editor_save_ped.fn(1, { model = 's_m_y_ammucity_01', x = 10, y = 20, z = 30, h = 90, name = 'Accueil', npc = { lasergame = { name = '  LaserGame Vespucci  ' } } })
A.editor_save_ped.fn(1, { model = 'a_m_y_hipster_01', x = 1, y = 2, z = 3, h = 0, name = 'Autre', npc = { lasergame = { name = '' } } })
A.editor_save_ped.fn(1, { model = 'a_m_y_hipster_01', x = 5, y = 5, z = 5, h = 0, name = 'Sans rôle' })
local list = EXP.GetLaserGameNpcs()
check('export GetLaserGameNpcs : les 2 PNJ LaserGame (pas celui sans rôle)', #list == 2)
check('nom nettoyé et position transmise', list[1].name == 'LaserGame Vespucci' and list[1].x == 10 and list[1].y == 20 and list[1].z == 30)
check('nom par défaut « LaserGame ElyzeaFA »', list[2].name == 'LaserGame ElyzeaFA')

print('— Onglet « LaserGame »')
local data2, data1 = {}, {}
for _, h in ipairs(AdminMenu.DataHooks) do h(2, data2) h(1, data1) end
check('staff sans la permission : pas de données LaserGame', data2.lasergame == nil)
check('staff avec la permission : parties en cours reçues', data1.lasergame and data1.lasergame.available and #data1.lasergame.games == 1)
local LG = A.lasergame
check('action protégée par la permission lasergame_manage', LG and LG.perm == 'lasergame_manage')
sent = {}
LG.fn(1, { name = 'open' })
check('« Ouvrir le panneau » : ouvre /lgadmin chez le staff', sent[1] and sent[1].name == 'elyzea_lasergame:openAdmin' and sent[1].target == 1)
LG.fn(1, { name = 'stop', data = { uid = 'g1' } })
check('« Arrêter » : transmis à elyzea_lasergame (qui revérifie) et journalisé', LG_STOPPED and LG_STOPPED.uid == 'g1' and logs[#logs].a == 'LaserGame')
STARTED.elyzea_lasergame = nil
local d3 = {}
for _, h in ipairs(AdminMenu.DataHooks) do h(1, d3) end
check('ressource arrêtée : onglet en « ne répond pas »', d3.lasergame and d3.lasergame.available == false)
notes = {}
LG.fn(1, { name = 'open' })
check('ressource arrêtée : message d\'erreur au staff', notes[1] and notes[1].kind == 'error')

print('— elyzea_lasergame : permission staff venant d\'admin_menu')
local env = setmetatable({}, { __index = _G })
local ace = { [2] = true, [3] = true }
env.Config = { Permission = 'lasergame_manage', AcePermission = 'elyzea_lasergame.admin', Framework = 'auto' }
env.IsPlayerAceAllowed = function(src) return ace[src] == true end
env.GetResourceState = function(r) return (r == 'admin_menu' and STARTED.admin_menu) and 'started' or 'missing' end
env.exports = setmetatable({}, { __index = function(_, res)
    if res == 'admin_menu' then return { HasPermission = function(_, src, p) return p == 'lasergame_manage' and perms[src] == true end, AddLog = function() end } end
    return stub()
end })
assert(load(io.open(root .. '/../elyzea_lasergame/server/bridge.lua'):read('a'), 'bridge', 't', env))()
local B = env.Bridge
check('staff avec la case LaserGame : autorisé', B.IsAdmin(1) == true)
check('ACE seule sans la case (admin_menu démarré) : refusé', B.IsAdmin(2) == false)
check('joueur sans rien : refusé', B.IsAdmin(4) == false)
check('console : autorisée', B.IsAdmin(0) == true)
STARTED.admin_menu = nil
check('sans admin_menu : l\'ACE prend le relais', B.IsAdmin(3) == true and B.IsAdmin(1) == false)

print(('\n%d vérifications, %d échec(s)'):format(n, fails))
return fails
