-- Annuler / rétablir de bout en bout : vrai client/editor.lua + vrai serveur (natives simulées)
local root = ...
local T = dofile(root .. '/tests/helpers.lua')
json = dofile(root .. '/tests/json.lua')
local FILES = {}
function GetCurrentResourceName() return 'builder_studio' end
function LoadResourceFile(_, p) if FILES[p] then return FILES[p] end local f = io.open(root .. '/' .. p, 'rb') if not f then return nil end local d = f:read('a') f:close() return d end
function SaveResourceFile(_, p, d) FILES[p] = d return true end
function IsPlayerAceAllowed() return true end
function GetPlayerIdentifiers() return { 'license:test' } end
function GetPlayerName() return 'Testeur' end
function GetGameTimer() return 12345 end
function GetPlayerServerId() return 1 end
function PlayerId() return 0 end
function DoesEntityExist() return false end
local nuiMsgs = {}
function SendNUIMessage(m) nuiMsgs[#nuiMsgs + 1] = m end
T.load(root, 'config.lua')
T.shared(root)
for _, f in ipairs({ 'server/storage.lua', 'server/projects.lua' }) do T.load(root, f) end
Projects.init()
BRuntime = { hooks = {}, projects = {}, dims = {} }
T.load(root, 'client/editor.lua')

local p = Projects.create(1, 'Annuler')
BRuntime.projects[p.id] = { data = { id = p.id, elements = {} }, els = {} }
Ed.pid = p.id
-- « réseau » : le serveur applique, puis le client reçoit builder:applied
function TriggerServerEvent(ev, pid, op, seq)
    local res, err = Projects.apply(1, pid, op)
    if not res then Ed.onRejected(seq, err) return end
    local mirror = BRuntime.projects[pid].data.elements
    for _, o in ipairs(res.ops) do
        if o.kind == 'remove' then for _, id in ipairs(o.ids) do mirror[id] = nil end
        else for _, e in ipairs(o.elements) do mirror[e.id] = BCompose.deepcopy(e) end end
    end
    Ed.onApplied(seq)
end
local function count() local n = 0 for _ in pairs(p.elements) do n = n + 1 end return n end
local w = { id = 'w1', type = 'wall', kit = 'ubk', mat = 'beton', pos = { x = 0, y = 0, z = 0 }, rot = { x = 0, y = 0, z = 0 }, params = { length = 4, height = 3 } }
Ed.submit({ kind = 'add', elements = { w } }, 'Ajout')
T.ok(count() == 1, 'ajout')
local moved = BCompose.deepcopy(p.elements.w1) moved.pos.x = 10
Ed.submit({ kind = 'update', elements = { moved } }, 'Déplacement')
T.ok(p.elements.w1.pos.x == 10, 'déplacement')
Ed.doUndo()
T.ok(p.elements.w1.pos.x == 0, 'annuler le déplacement')
Ed.doUndo()
T.ok(count() == 0, 'annuler l\'ajout')
Ed.doRedo()
T.ok(count() == 1 and p.elements.w1.pos.x == 0, 'rétablir l\'ajout')
Ed.doRedo()
T.ok(p.elements.w1.pos.x == 10, 'rétablir le déplacement')
Ed.doUndo() Ed.doRedo()
T.ok(p.elements.w1.pos.x == 10 and #Ed.undo == 2 and #Ed.redo == 0, 'piles cohérentes (' .. #Ed.undo .. ' / ' .. #Ed.redo .. ')')
-- groupe + suppression puis annulation : les enfants reviennent
Ed.selOrder, Ed.selection = { 'w1' }, { w1 = true }
Ed.group()
local gid
for id, e in pairs(p.elements) do if e.type == 'group' then gid = id end end
T.ok(gid and p.elements.w1.parent == gid, 'groupement')
Ed.submit({ kind = 'remove', ids = { gid } }, 'Suppression')
T.ok(count() == 0, 'suppression du groupe et de son enfant')
Ed.doUndo()
T.ok(count() == 2 and p.elements.w1.parent == gid, 'annuler la suppression : groupe et enfant restaurés')
Ed.doUndo()
T.ok(p.elements[gid] == nil and p.elements.w1.parent == nil, 'annuler le groupement')
-- verrou : refus serveur, pas d'entrée dans l'historique
local locked = BCompose.deepcopy(p.elements.w1) locked.locked = true
Ed.submit({ kind = 'update', elements = { locked } }, 'Verrouillage')
local n = #Ed.undo
local mv = BCompose.deepcopy(p.elements.w1) mv.pos.x = 99
Ed.submit({ kind = 'update', elements = { mv } }, 'Déplacement')
T.ok(p.elements.w1.pos.x ~= 99 and #Ed.undo == n, 'action refusée : rien dans l\'historique')
local notified = false
for _, m in ipairs(nuiMsgs) do if m.action == 'notify' and m.kind == 'error' then notified = true end end
T.ok(notified, 'le refus est affiché')
return T.fails
