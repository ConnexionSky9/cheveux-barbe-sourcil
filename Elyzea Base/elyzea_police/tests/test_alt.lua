-- Test hors du jeu du choix de la cible du menu ALT (client/alt.lua, fonction Context) : bébé visé, bébé à côté d'un joueur,
-- bébé porté, poussette visée, plusieurs ressources. Les fonctions du jeu sont simulées (rayon du curseur, entités, joueurs).
-- Lancement depuis le dossier de la ressource : lua5.4 tests/test_alt.lua
local OK, KO = 0, 0
local function check(nom, cond, detail)
    if cond then OK = OK + 1 print('OK     ' .. nom) else KO = KO + 1 print('ÉCHEC  ' .. nom .. '  ' .. tostring(detail or '')) end
end

local vmt = {}
vmt.__index = vmt
vmt.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
vmt.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
vmt.__mul = function(a, k) return vector3(a.x * k, a.y * k, a.z * k) end
vmt.__div = function(a, k) return vector3(a.x / k, a.y / k, a.z / k) end
vmt.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, vmt) end

-- monde : moi (ped 1) en (0,0,0) regardant vers +Y ; entités { pos, kind = 'ped'|'player'|'object'|'vehicle', state }
local E = {}
local RAY = nil                      -- entité touchée par le rayon du curseur (nil = rien)
local ME = 1
E[ME] = { pos = vector3(0, 0, 0), kind = 'player' }
function PlayerPedId() return ME end
function PlayerId() return 0 end
function GetEntityCoords(e) return E[e].pos end
function GetEntityForwardVector() return vector3(0, 1, 0) end
function DoesEntityExist(e) return E[e] ~= nil end
function IsEntityAPed(e) return E[e].kind == 'ped' or E[e].kind == 'player' end
function IsPedAPlayer(e) return E[e].kind == 'player' end
function IsEntityAVehicle(e) return E[e].kind == 'vehicle' end
function IsPedInAnyVehicle() return false end
function Entity(e) return { state = E[e].state or {} } end
function GetActivePlayers() local t = { 0 } for id, x in pairs(E) do if x.kind == 'player' and id ~= ME then t[#t + 1] = id end end return t end
function GetPlayerPed(pid) return pid == 0 and ME or pid end
function GetPlayerServerId(pid) return pid end
function NetworkGetPlayerIndexFromPed(p) return p end
function GetControlNormal() return 0.5 end
function GetGameplayCamRot() return vector3(0, 0, 0) end
function GetGameplayCamCoord() return vector3(0, 0, 1.5) end
function GetGameplayCamFov() return 50.0 end
function GetAspectRatio() return 16 / 9 end
local FLAGS
function StartExpensiveSynchronousShapeTestLosProbe(_, _, _, _, _, _, flags) FLAGS = flags return 1 end
function GetShapeTestResult() if RAY then return 2, true, nil, nil, RAY end return 2, false, nil, nil, 0 end
function GetResourceState(r) return (r == 'elyzea_bebe_modele' or r == 'jewelry_heist') and 'started' or 'missing' end
function RegisterNUICallback() end
function RegisterCommand() end
function RegisterKeyMapping() end
function CreateThread() end

-- ressources : bébé (cible = entités avec state.bebe / bebePoussette ; proche = bébé à 2 m) ; bijouterie (sac à 1,5 m)
local NEAR = { elyzea_bebe_modele = nil, jewelry_heist = nil }
exports = setmetatable({}, { __index = function(_, res)
    return {
        AltTarget = function(_, ent)
            local st = E[ent] and E[ent].state or {}
            if res == 'elyzea_bebe_modele' and st.bebe then return 'Bébé' end
            if res == 'elyzea_bebe_modele' and st.bebePoussette then return 'Poussette' end
            if res == 'jewelry_heist' and st.butin then return 'Sac' end
        end,
        AltNearby = function() local n = NEAR[res] if n then return n, res == 'jewelry_heist' and 'Sac' or 'Bébé' end end,
        AltOptions = function() return {} end,
    }
end })

PoliceC = { ui = {}, IsCarrying = function() return false end, InTrunk = function() return false end }
Config = { Distances = { alt = 3.0, vehicle = 5.0 }, Keys = { alt = 'LMENU' } }
dofile('client/alt.lua')
local Context = PoliceC.AltContext

-- 1. le rayon vise un OBJET bébé (ex. sur un lit, avec collision ou non selon le modèle)
E[10] = { pos = vector3(0, 1.5, 0), kind = 'object', state = { bebe = 'BB-1', bebePiece = 'corps' } }
RAY = 10
local c = Context()
check('1. bébé visé au curseur : cible « Bébé » de elyzea_bebe_modele', c.kind == 'ext' and c.entity == 10 and c.provider == 'elyzea_bebe_modele', c.kind)
check('1. le rayon inclut les objets (filtre 16)', FLAGS & 16 == 16, FLAGS)

-- 2. rien sous le curseur, un AUTRE joueur juste devant à 1,8 m, le bébé posé à 1,2 m : le bébé (plus proche) l'emporte
RAY = nil
E[20] = { pos = vector3(0, 1.8, 0), kind = 'player' }
NEAR.elyzea_bebe_modele = 10
E[10].pos = vector3(0.3, 1.2, 0)
c = Context()
check('2. bébé à 1,2 m et joueur à 1,8 m : bébé proposé (avant : le joueur masquait le bébé)', c.kind == 'ext' and c.entity == 10, c.kind)

-- 3. joueur plus proche que le bébé : le joueur est proposé (pas de régression des interactions entre joueurs)
E[20].pos = vector3(0, 0.8, 0)
c = Context()
check('3. joueur à 0,8 m, bébé à 1,2 m : joueur proposé', c.kind == 'player' and c.entity == 20, c.kind)

-- 4. le curseur vise le joueur : toujours le joueur, même avec un bébé plus proche
RAY = 20
E[10].pos = vector3(0, 0.3, 0)
c = Context()
check('4. joueur visé au curseur : joueur, même si un bébé est plus proche', c.kind == 'player' and c.sid == 20)

-- 5. plusieurs ressources : la cible la plus proche gagne (avant : la bijouterie, listée avant, gagnait toujours)
RAY = nil
E[20] = nil
E[30] = { pos = vector3(0, 1.5, 0), kind = 'object', state = { butin = true } }
NEAR.jewelry_heist = 30
E[10].pos = vector3(0, 0.6, 0)
c = Context()
check('5. sac à 1,5 m et bébé à 0,6 m : bébé', c.kind == 'ext' and c.entity == 10 and c.provider == 'elyzea_bebe_modele', c.provider)
E[10].pos = vector3(0, 2.5, 0)
c = Context()
check('5. sac à 1,5 m et bébé à 2,5 m : sac', c.kind == 'ext' and c.entity == 30 and c.provider == 'jewelry_heist', c.provider)

-- 6. poussette visée au curseur (collision du modèle V7)
E[40] = { pos = vector3(0, 1.4, 0), kind = 'object', state = { bebePoussette = 'PO-1' } }
RAY = 40
c = Context()
check('6. poussette visée : cible « Poussette »', c.kind == 'ext' and c.entity == 40 and c.title == 'Poussette')

-- 7. objet quelconque (sans cible de ressource) : pas de menu parasite, repli sur les cibles proches
E[50] = { pos = vector3(0, 1.0, 0), kind = 'object', state = {} }
RAY = 50
NEAR.jewelry_heist, NEAR.elyzea_bebe_modele = nil, nil
c = Context()
check('7. objet du décor visé, rien à proximité : aucune cible', c.kind == 'none')

-- 8. objet visé trop loin (10 m) : ignoré
E[10].pos = vector3(0, 10, 0)
RAY = 10
c = Context()
check('8. bébé visé à 10 m : hors de portée', c.kind == 'none')

print(('\n%d contrôles réussis, %d échec(s)'):format(OK, KO))
os.exit(KO == 0 and 0 or 1)
