-- Simulation hors jeu : vrai server/editor.lua chargé avec de faux FiveM.
-- Vérifie les actions staff (métiers, pupitres) et les événements joueurs (E sur une porte, pupitre).
local root = ...
local fails, n = 0, 0
local function check(name, cond)
    n = n + 1
    if cond then print('OK   ' .. name) else fails = fails + 1 print('FAIL ' .. name) end
end

-- ---------- faux FiveM ----------
local function stub() return setmetatable({}, { __index = function() return stub() end, __call = function() return nil end }) end
vector3 = function(x, y, z)
    return setmetatable({ x = x, y = y, z = z }, { __sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end,
        __len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end })
end
local events, sent, notes, saved = {}, {}, {}, {}
RegisterNetEvent = function(name, fn) events[name] = fn end
AddEventHandler = function() end
RegisterCommand = function() end
CreateThread = function() end
SetTimeout = function(_, fn) fn() end
Wait = function() end
GetGameTimer = function() return 0 end
GetHashKey = function(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end return h end
TriggerEvent = function() end
TriggerClientEvent = function(name, target, ...) sent[#sent + 1] = { name = name, target = target, args = { ... } } end
TriggerLatentClientEvent = function() end
GetCurrentResourceName = function() return 'admin_menu' end
exports = stub()
json = { encode = function() return '' end, decode = function() return {} end }

local players = {}   -- [src] = { pos, state, job, duty, cid, admin }
GetPlayerPed = function(src) return src end
GetEntityCoords = function(ped) return players[ped].pos end
GetPlayerName = function(src) return players[src] and ('J' .. src) or nil end
Player = function(src) return { state = players[src].state } end

Storage = { load = function(_, def) return def end, saveLater = function(name) saved[name] = (saved[name] or 0) + 1 end, save = function() end }
Bridge = setmetatable({
    GetCharId = function(src) return players[src].cid end,
    GetCharName = function(src) return 'Nom' .. src end,
    GetJob = function(src) local p = players[src] return p.job, 0, p.duty end,
}, { __index = function() return function() end end })
AdminMenu = {
    Actions = {}, DataHooks = {},
    rateLimit = function() return true end,
    notify = function(src, msg, kind) notes[#notes + 1] = { src = src, msg = msg, kind = kind } end,
    addLog = function() end,
    hasPerm = function(src) return players[src] and players[src].admin == true end,
    getLevel = function(src) return players[src] and players[src].admin and 100 or 0 end,
    onDuty = function(src) return players[src] and players[src].admin == true end,
}
setmetatable(_G, { __index = function(_, k) return stub() end })

dofile(root .. '/config.lua')
dofile(root .. '/server/door_access.lua')
dofile(root .. '/server/editor.lua')
setmetatable(_G, nil)

local A = AdminMenu.Actions
local function act(name, src, d) return A[name].fn(src, d) end
local function fire(name, src, ...) source = src return events[name](...) end
local function lastSent(name, target)
    for i = #sent, 1, -1 do if sent[i].name == name and sent[i].target == target then return sent[i] end end
end
local function lastNote(src) for i = #notes, 1, -1 do if notes[i].src == src then return notes[i] end end end

-- Joueurs : 1 staff, 2 policier LSPD, 3 civil, 4 BCSO, 5 policier loin du pupitre
players[1] = { pos = vector3(0, 0, 0), state = {}, job = 'staff', duty = true, cid = 'S1', admin = true }
players[2] = { pos = vector3(10, 0, 0), state = { police = { job = 'lspd', duty = true } }, job = 'lspd', duty = true, cid = 'P1' }
players[3] = { pos = vector3(10, 0, 0), state = {}, job = 'unemployed', duty = true, cid = 'C1' }
players[4] = { pos = vector3(10, 0, 0), state = { police = { job = 'bcso', duty = true } }, job = 'bcso', duty = true, cid = 'B1' }
players[5] = { pos = vector3(300, 0, 0), state = { police = { job = 'lspd', duty = true } }, job = 'lspd', duty = true, cid = 'P2' }

-- Le staff crée 2 cellules près du joueur 2/3/4 (x=10)
act('editor_add_door', 1, { name = 'Cellule 1', leaves = { { model = 123, x = 10.5, y = 0, z = 0 } } })
act('editor_add_door', 1, { name = 'Cellule 2', leaves = { { model = 123, x = 11, y = 0, z = 0 } } })
act('editor_add_door', 1, { name = 'Bureau du chef', leaves = { { model = 9, x = 10.8, y = 0, z = 0 } } })
local function lastSync(kind)
    for i = #sent, 1, -1 do local e = sent[i] if e.name == 'adminmenu:editor:sync' and e.args[1] == kind then return e.args[2] end end
end
local L = lastSync('doors')
check('3 portes créées et verrouillées', L and #L == 3 and L[1].locked and L[2].locked and L[3].locked)

-- Porte 1 réservée à la police (toutes agences), porte 3 au métier précis lspd
act('editor_door_add_job', 1, { id = 1, job = 'police' })
act('editor_door_add_job', 1, { id = 3, job = 'LSPD' })
act('editor_door_add_job', 1, { id = 1, job = 'police' })
check('doublon de métier refusé', lastNote(1).kind == 'info')

-- E sur la porte 1
sent = {}
fire('adminmenu:door:interact', 3, 1)
check('civil : porte métier refusée', lastNote(3) and lastNote(3).kind == 'error')
fire('adminmenu:door:interact', 2, 1)
check('LSPD : porte police déverrouillée avec E', lastNote(2) and lastNote(2).msg:find('déverrouillée') ~= nil)
fire('adminmenu:door:interact', 4, 1)
check('BCSO : porte « police » (catégorie) reverrouillée', lastNote(4) and lastNote(4).msg:find('verrouillée') ~= nil and lastNote(4).kind == 'success')
notes = {}
fire('adminmenu:door:interact', 4, 3)
check('BCSO : porte réservée « lspd » refusée', lastNote(4) and lastNote(4).kind == 'error')
fire('adminmenu:door:interact', 2, 3)
check('LSPD : porte « lspd » ouverte', lastNote(2) and lastNote(2).msg:find('déverrouillée') ~= nil)
notes = {}
fire('adminmenu:door:managecode', 2, 1)
check('métier : ne peut pas gérer le code invité', lastNote(2) and lastNote(2).kind == 'error')
fire('adminmenu:door:setcode', 2, 1, '1234')
check('métier : ne peut pas créer de code', lastNote(2) and lastNote(2).kind == 'error')

-- Retrait du métier
act('editor_door_remove_job', 1, { id = 3, job = 'lspd' })
notes = {}
fire('adminmenu:door:interact', 2, 3)
check('métier retiré : LSPD refusé', lastNote(2) and lastNote(2).kind == 'error')

-- Pupitre : posé par le staff à x=0 ; on le déplace ensuite près des joueurs
act('editor_add_doorpanel', 1, { name = 'PC cellules', radius = 2, jobs = { 'lspd' }, doors = { 1, 2, 99, 2 } })
players[1].pos = vector3(10, 1, 0)
act('editor_doorpanel_move', 1, { id = 1 })
sent = {}
fire('adminmenu:doorpanel:open', 2, 1)
local s = lastSent('adminmenu:doorpanel:show', 2)
check('LSPD : pupitre ouvert', s ~= nil)
check('pupitre : portes inexistantes et doublons ignorés', s and #s.args[1].doors == 2)
notes = {}
fire('adminmenu:doorpanel:open', 4, 1)
check('BCSO : pupitre LSPD refusé', lastSent('adminmenu:doorpanel:show', 4) == nil and lastNote(4).kind == 'error')
fire('adminmenu:doorpanel:open', 3, 1)
check('civil : pupitre refusé', lastSent('adminmenu:doorpanel:show', 3) == nil)
fire('adminmenu:doorpanel:open', 5, 1)
check('policier trop loin : rien', lastSent('adminmenu:doorpanel:show', 5) == nil)

-- Ouvrir la cellule 2 à distance
sent = {}
fire('adminmenu:doorpanel:set', 2, 1, 2, false)
s = lastSent('adminmenu:doorpanel:show', 2)
local function stateOf(list, id) for _, d in ipairs(list) do if d.id == id then return d.locked end end end
check('cellule 2 ouverte à distance', s and stateOf(s.args[1].doors, 2) == false)
fire('adminmenu:doorpanel:set', 2, 1, 2, true)
s = lastSent('adminmenu:doorpanel:show', 2)
check('cellule 2 refermée à distance', s and stateOf(s.args[1].doors, 2) == true)
sent = {}
fire('adminmenu:doorpanel:set', 2, 1, 3, false)
check('porte hors pupitre : refusée', lastSent('adminmenu:doorpanel:show', 2) == nil)
fire('adminmenu:doorpanel:set', 4, 1, 2, false)
check('BCSO ne peut pas commander', lastSent('adminmenu:doorpanel:show', 4) == nil)
fire('adminmenu:doorpanel:all', 2, 1, false)
s = lastSent('adminmenu:doorpanel:show', 2)
check('tout ouvrir', s and stateOf(s.args[1].doors, 1) == false and stateOf(s.args[1].doors, 2) == false)
fire('adminmenu:doorpanel:all', 2, 1, true)
s = lastSent('adminmenu:doorpanel:show', 2)
check('tout verrouiller', s and stateOf(s.args[1].doors, 1) == true and stateOf(s.args[1].doors, 2) == true)
check('sauvegarde des portes et des pupitres', (saved.doors or 0) > 0 and (saved.door_panels or 0) > 0)

-- Staff : utilise tout pupitre ; modification ; suppression
fire('adminmenu:doorpanel:open', 1, 1)
check('staff : pupitre ouvert', lastSent('adminmenu:doorpanel:show', 1) ~= nil)
act('editor_doorpanel_update', 1, { id = 1, name = 'PC cellules LSPD', jobs = { 'police' }, doors = { 2 } })
sent = {}
fire('adminmenu:doorpanel:open', 4, 1)
s = lastSent('adminmenu:doorpanel:show', 4)
check('après modification : BCSO (catégorie police) accepté, 1 porte', s and #s.args[1].doors == 1 and s.args[1].name == 'PC cellules LSPD')
A.editor_delete.fn(1, { kind = 'doorpanel', id = 1 })
sent = {}
fire('adminmenu:doorpanel:open', 4, 1)
check('pupitre supprimé : plus rien', lastSent('adminmenu:doorpanel:show', 4) == nil)

-- La liste envoyée aux clients contient les métiers des portes
act('editor_door_add_job', 1, { id = 2, job = 'ems' })
L = lastSync('doors')
check('liste publique : métiers inclus, sans le code', L and L[2].jobs and L[2].jobs[1] == 'ems' and L[1].jobs[1] == 'police' and L[1].codeHash == nil)

print(('\n%d/%d'):format(n - fails, n))
return fails
