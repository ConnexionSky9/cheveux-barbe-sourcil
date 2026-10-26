-- Test hors jeu de client/suivi.lua (audit V9) : le bébé attaché au buste doit se retrouver EXACTEMENT à la position
-- validée (repère du personnage), quelle que soit la convention d'angles de GTA (inconnue : simulée de 3 façons).
-- Lancement : lua5.4 tests/test_suivi.lua  (depuis le dossier de la ressource)
local ok_total, fails = 0, 0
local function check(c, label)
    if c then ok_total = ok_total + 1 print('  ok   ' .. label) else fails = fails + 1 print('  ÉCHEC ' .. label) end
end

-- ---------- vecteurs ----------
local V = {}
V.__index = V
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__len = function(a) return math.sqrt(a.x ^ 2 + a.y ^ 2 + a.z ^ 2) end

-- ---------- matrices 3x3 (lignes) ----------
local function Rx(d) local a = math.rad(d) return { { 1, 0, 0 }, { 0, math.cos(a), -math.sin(a) }, { 0, math.sin(a), math.cos(a) } } end
local function Ry(d) local a = math.rad(d) return { { math.cos(a), 0, math.sin(a) }, { 0, 1, 0 }, { -math.sin(a), 0, math.cos(a) } } end
local function Rz(d) local a = math.rad(d) return { { math.cos(a), -math.sin(a), 0 }, { math.sin(a), math.cos(a), 0 }, { 0, 0, 1 } } end
local function mul(A, B)
    local C = { {}, {}, {} }
    for i = 1, 3 do for j = 1, 3 do C[i][j] = A[i][1] * B[1][j] + A[i][2] * B[2][j] + A[i][3] * B[3][j] end end
    return C
end
local function app(A, v) return vector3(A[1][1] * v.x + A[1][2] * v.y + A[1][3] * v.z, A[2][1] * v.x + A[2][2] * v.y + A[2][3] * v.z, A[3][1] * v.x + A[3][2] * v.y + A[3][3] * v.z) end

-- ---------- monde simulé ----------
local CONV          -- convention de GTA simulée : fonction(x, y, z) -> matrice
local W = { now = 0, kvp = {}, modelOk = true }
local ENT = {}      -- [id] = { R, p } (personnage) ou { parent, bone, off, rot }
local nextId = 100
local PED = 1
local BONE_INDEX = 77
-- os du buste : orientation quelconque (axes de GTA inconnus), un peu au-dessus et devant le bassin
local BONE_R = mul(mul(Rz(12.0), Ry(-83.0)), Rx(7.0))
local BONE_OFF = vector3(0.02, 0.04, 0.42)
local function frameOf(id)
    local e = ENT[id]
    if e.R then return e.R, e.p end
    local PR, Pp = frameOf(e.parent)
    local BR, Bp = PR, Pp
    if e.bone == BONE_INDEX then BR, Bp = mul(PR, BONE_R), Pp + app(PR, BONE_OFF) end
    return mul(BR, CONV(e.rot.x, e.rot.y, e.rot.z)), Bp + app(BR, e.off)
end
function GetEntityMatrix(id)
    local R, p = frameOf(id)
    return vector3(R[1][1], R[2][1], R[3][1]), vector3(R[1][2], R[2][2], R[3][2]), vector3(R[1][3], R[2][3], R[3][3]), p
end
function AttachEntityToEntity(c, parent, bone, x, y, z, rx, ry, rz)
    ENT[c] = { parent = parent, bone = bone, off = vector3(x, y, z), rot = vector3(rx, ry, rz) }
end
function GetPedBoneIndex(_, os) return os == 24818 and BONE_INDEX or 0 end
function IsEntityAttachedToEntity(c, p) return ENT[c] and ENT[c].parent == p end
function DoesEntityExist(id) return ENT[id] ~= nil end
function GetEntityCoords(id) local _, p = frameOf(id) return p end
function joaat() return 5 end
function RequestModel() end
function HasModelLoaded() return W.modelOk end
function SetModelAsNoLongerNeeded() end
function CreateObjectNoOffset() nextId = nextId + 1 ENT[nextId] = { R = Rz(0), p = vector3(0, 0, 0) } return nextId end
function SetEntityVisible() end
function SetEntityCollision() end
function DeleteEntity(id) ENT[id] = nil end
function GetGameTimer() return W.now end
function GetResourceKvpInt(k) return W.kvp[k] or 0 end
function SetResourceKvpInt(k, v) W.kvp[k] = v end
local threads = {}
function CreateThread(fn) threads[#threads + 1] = coroutine.create(fn) end
function Wait(ms) W.now = W.now + (ms or 0) coroutine.yield() end
local function run() for _ = 1, 200 do local alive = false for _, co in ipairs(threads) do if coroutine.status(co) ~= 'dead' then alive = true assert(coroutine.resume(co)) end end if not alive then break end end threads = {} end
Config = { Portage = { suiviBuste = { actif = true, os = 24818 } }, Debug = false }
print = print

dofile('client/suivi.lua')

-- ---------- scénarios ----------
local conventions = {
    { nom = 'Rz·Ry·Rx', f = function(x, y, z) return mul(mul(Rz(z), Ry(y)), Rx(x)) end },
    { nom = 'Ry·Rx·Rz', f = function(x, y, z) return mul(mul(Ry(y), Rx(x)), Rz(z)) end },
    { nom = 'Rx·Ry·Rz (sens inverse)', f = function(x, y, z) return mul(mul(Rx(-x), Ry(-y)), Rz(-z)) end },
}
local pos, rot = vector3(0.06, 0.22, 0.27), vector3(0.0, -20.0, -90.0)   -- prise « contre soi » (config.lua)
for _, cv in ipairs(conventions) do
    CONV = cv.f
    W.kvp = {}
    ENT = { [PED] = { R = Rz(37.0), p = vector3(120.0, -45.0, 30.0) } }
    local BABY = 50
    ENT[BABY] = { R = Rz(0), p = vector3(0, 0, 0) }
    -- référence : position validée (attache au repère du personnage)
    AttachEntityToEntity(BABY, PED, 0, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z)
    local r1, f1, u1, p1 = GetEntityMatrix(BABY)
    BebeAttacherSuivi(BABY, PED, pos, rot, true)
    run()
    local r2, f2, u2, p2 = GetEntityMatrix(BABY)
    local err = #(p2 - p1) + #(r2 - r1) + #(f2 - f1) + #(u2 - u1)
    check(ENT[BABY].bone == BONE_INDEX, ('convention %s : bébé attaché à l\'os du buste'):format(cv.nom))
    check(err < 1e-4, ('convention %s : même position et orientation qu\'avant (écart %.1e)'):format(cv.nom, err))
    check((W.kvp.bebe_suivi_convention or 0) > 0, ('convention %s : mesurée et mémorisée (n° %d)'):format(cv.nom, W.kvp.bebe_suivi_convention or 0))
end

-- Le buste bouge (marche / respiration) : le bébé suit l'os
CONV = conventions[1].f
local BABY = 50
local r_before, _, _, p_before = GetEntityMatrix(BABY)
BONE_OFF = vector3(0.02, 0.07, 0.45)      -- le buste avance de 3 cm et monte de 3 cm
local _, _, _, p_after = GetEntityMatrix(BABY)
check(#(p_after - p_before) > 0.03, ('le buste bouge : le bébé suit (%.1f cm)'):format(#(p_after - p_before) * 100))
BONE_OFF = vector3(0.02, 0.04, 0.42)

-- Convention mémorisée qui ne correspond plus (mise à jour du jeu) : nouvelle mesure, résultat toujours exact
do
    AttachEntityToEntity(BABY, PED, 0, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z)
    local _, _, _, p1 = GetEntityMatrix(BABY)
    BebeAttacherSuivi(BABY, PED, pos, rot, true)   -- mémorisée : n° 7 (dernier scénario) ; jeu actuel : convention 1
    run()
    local _, _, _, p2 = GetEntityMatrix(BABY)
    check(ENT[BABY].bone == BONE_INDEX and #(p2 - p1) < 1e-4 and W.kvp.bebe_suivi_convention == 5,
        'convention mémorisée périmée : nouvelle mesure automatique, position exacte')
end

-- Prise suivante : convention mémorisée, une seule mesure
local tries = 0
local orig = AttachEntityToEntity
AttachEntityToEntity = function(...) tries = tries + 1 return orig(...) end
BebeAttacherSuivi(BABY, PED, pos, rot, true)
run()
AttachEntityToEntity = orig
check(tries <= 4, ('convention mémorisée : prise suivante sans nouvelle série d\'essais (%d attaches)'):format(tries))

-- Mesure impossible (modèle d'aide absent) : l'attache d'origine reste
W.modelOk = false
BebeAttacherSuivi(BABY, PED, pos, rot, true)
run()
check(ENT[BABY].bone == 0, 'mesure impossible : attache d\'origine gardée (aucune régression)')
W.modelOk = true

-- Désactivé (Config.Portage.suiviBuste.actif = false) : attache d'origine
BebeAttacherSuivi(BABY, PED, pos, rot, false)
run()
check(ENT[BABY].bone == 0, 'poussette / suivi désactivé : attache au repère du personnage')

-- Euler : aller-retour exact pour les 12 conventions
local maxe = 0
for n = 1, 12 do
    local R = mul(mul(Rz(33.0), Ry(-21.0)), Rx(57.0))
    local a = BebeSuivi.candidat(R, n)
    -- reconstruit la matrice avec l'ordre / le signe du candidat n et compare
    local perms = { { 1, 2, 3 }, { 2, 3, 1 }, { 3, 1, 2 }, { 1, 3, 2 }, { 3, 2, 1 }, { 2, 1, 3 } }
    local pm, sg = perms[(n - 1) % 6 + 1], n > 6 and -1 or 1
    local rots = { Rx, Ry, Rz }
    local M = mul(mul(rots[pm[1]](a[pm[1]] * sg), rots[pm[2]](a[pm[2]] * sg)), rots[pm[3]](a[pm[3]] * sg))
    for i = 1, 3 do for j = 1, 3 do maxe = math.max(maxe, math.abs(M[i][j] - R[i][j])) end end
end
check(maxe < 1e-9, ('angles : aller-retour exact pour les 12 conventions (écart %.1e)'):format(maxe))

print(('\n%d échec(s)'):format(fails))
os.exit(fails == 0 and 0 or 1)
