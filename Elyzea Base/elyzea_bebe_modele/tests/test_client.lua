-- Test hors du jeu de la logique client (client/portage.lua) : options du menu ALT selon l'état,
-- position du bébé dans la poussette poussée. Les fonctions du jeu sont simulées.
-- Lancement depuis le dossier de la ressource : lua5.4 tests/test_client.lua
local OK, KO = 0, 0
local function check(nom, cond, detail)
    if cond then OK = OK + 1 print('OK     ' .. nom) else KO = KO + 1 print('ÉCHEC  ' .. nom .. '  ' .. tostring(detail or '')) end
end

-- ── simulations
local vmt = {}
vmt.__index = vmt
vmt.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
vmt.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
vmt.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, vmt) end
function GetHashKey(s) local h = 0 for i = 1, #s do h = (h + s:byte(i)) * 31 % 4294967296 end return h end
joaat = GetHashKey
local ENT = {}            -- [id] = { pos, state, attached }
local PED = 1
LocalPlayer = { state = {} }
GlobalState = { bebeReglages = { ventral = true, dorsal = true, poussette = true } }
function Entity(e) return { state = ENT[e] and ENT[e].state or {} } end
function PlayerPedId() return PED end
function GetEntityCoords(e) return e == PED and vector3(0, 0, 0) or ENT[e].pos end
function GetGamePool() local t = {} for id in pairs(ENT) do t[#t + 1] = id end return t end
function IsEntityAttached(e) return ENT[e].attached ~= nil end
function DoesEntityExist(e) return ENT[e] ~= nil or e == PED end
function NetworkGetEntityFromNetworkId(n) return n - 1000 end
function GetEntityModel() return GetHashKey('mp_m_freemode_01') end
local EXP = {}
exports = function(nom, fn) EXP[nom] = fn end
function RegisterNetEvent() end
function RegisterCommand() end
function AddEventHandler() end
function CreateThread() end
BebeNotify = function() end

dofile('shared/modeles.lua')
dofile('config.lua')
dofile('client/portage.lua')

local function options(ent)
    local ids = {}
    for _, o in ipairs(EXP.AltOptions({ entity = ent })) do ids[#ids + 1] = o.id end
    return table.concat(ids, ' ')
end

-- ── bébé posé, joueur sans équipement
ENT[10] = { pos = vector3(1, 0, 0), state = { bebe = 'BB-1', bebePiece = 'corps' } }
local o = options(10)
check('1. bébé posé, sans porte-bébé : prises bras / face seulement', o:find('prendre:bras') and o:find('prendre:face')
    and not o:find('ventral') and not o:find('dorsal'), o)
check('1. option « endormir »', o:find('dormir:BB%-1'), o)

-- ── avec le porte-bébé ventral équipé
LocalPlayer.state.bebeEquipement = 'ventral'
o = options(10)
check('2. porte-bébé ventral équipé : prise ventrale proposée, pas la dorsale', o:find('prendre:ventral') and not o:find('dorsal'), o)
GlobalState.bebeReglages.ventral = false
o = options(10)
check('2. ventral désactivé dans le menu admin : plus proposé', not o:find('ventral'), o)
GlobalState.bebeReglages.ventral = true

-- ── poussette garée vide, joueur qui porte le bébé dans les bras
ENT[20] = { pos = vector3(1.5, 0, 0), state = { bebePoussette = 'PO-1', bebeDedans = false } }
LocalPlayer.state.bebePorte = { id = 'BB-1', mode = 'bras', mains = true }
o = options(20)
check('3. poussette vide + bébé dans les bras : « installer », pas « pousser » (mains occupées)', o:find('installer:PO%-1')
    and not o:find('pousser'), o)
check('3. poussette vide : « ranger » proposé', o:find('ranger:PO%-1'), o)

-- ── poussette occupée, joueur mains libres
LocalPlayer.state.bebePorte = nil
ENT[20].state.bebeDedans = 'BB-1'
o = options(20)
check('4. poussette avec bébé : pousser, sortir le bébé (bras / face / ventral), endormir', o:find('pousser:PO%-1')
    and o:find('prendrepo:bras') and o:find('prendrepo:ventral') and o:find('dormir:BB%-1'), o)
check('4. poussette avec bébé : pas de « ranger »', not o:find('ranger'), o)

-- ── position du bébé dans la poussette poussée = attache de la poussette + nacelle
local PO = Config.Poussette
local pos = PO.pos + vector3(PO.nacelle.pos.x, PO.nacelle.pos.y, PO.nacelle.pos.z)
check('5. nacelle : décalage cohérent (devant le joueur, au-dessus du sol)', pos.y > 0.3 and pos.z > -0.6 and pos.z < 0.0,
    ('%.3f %.3f %.3f'):format(pos.x, pos.y, pos.z))

-- ── personnages féminins : décalage déclaré et appliqué
local d = Config.Portage.morphologies[GetHashKey('mp_f_freemode_01')]
check('6. morphologie féminine : décalage par prise (ventral, dorsal), vers le bas', d and d.ventral.z < 0 and d.dorsal.z < 0
    and d.ventral.y ~= d.dorsal.y, d and d.ventral.y)

print(('\n%d contrôles réussis, %d échec(s)'):format(OK, KO))
os.exit(KO == 0 and 0 or 1)
