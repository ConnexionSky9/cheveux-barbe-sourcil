-- Simulation hors jeu du menu ALT : contour de surbrillance (caméra simulée) et choix de la cible (bébé).
-- Écrit aussi les traits dessinés dans OUT_LINES pour l'aperçu (run_alt_sim.py).
local ROOT = ...
local fails, n = 0, 0
local function check(c, l) n = n + 1 if c then print('  ok   ' .. l) else fails = fails + 1 print('  ÉCHEC ' .. l) end end
-- ---------------- vecteurs
local V = {}
V.__index = V
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end
V.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__mul = function(a, b) if type(a) == 'number' then a, b = b, a end return vector3(a.x * b, a.y * b, a.z * b) end
V.__div = function(a, b) return vector3(a.x / b, a.y / b, a.z / b) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
-- ---------------- caméra : en (0,0,1.6), regarde vers +Y, champ 50°, écran 16:9
local CAM, FOV, AR = vector3(0, 0, 1.6), 50.0, 16 / 9
function GetGameplayCamCoord() return CAM end
function GetGameplayCamRot() return vector3(0, 0, 0) end
function GetGameplayCamFov() return FOV end
function GetAspectRatio() return AR end
function GetScreenCoordFromWorldCoord(x, y, z)
    local d = vector3(x, y, z) - CAM
    if d.y <= 0.05 then return false, 0, 0 end
    local t = math.tan(math.rad(FOV) / 2)
    local sx = (d.x / d.y) / (t * AR) * 0.5 + 0.5
    local sy = -(d.z / d.y) / t * 0.5 + 0.5
    return sx >= 0 and sx <= 1 and sy >= 0 and sy <= 1, sx, sy
end
function GetControlNormal(_, c) return c == 239 and 0.5 or 0.5 end
-- ---------------- entités simulées
ENTS = {}
function DoesEntityExist(e) return ENTS[e] ~= nil end
function GetEntityCoords(e) if e == 1 then return vector3(0, 0, 1) end return ENTS[e].pos end
function IsEntityAPed(e) return ENTS[e] and ENTS[e].kind == 'ped' end
function IsEntityAVehicle(e) return ENTS[e] and ENTS[e].kind == 'veh' end
function GetEntityModel(e) return ENTS[e].model end
local DIMS = {}
function GetModelDimensions(m) local d = DIMS[m] return d[1], d[2] end
function GetOffsetFromEntityInWorldCoords(e, x, y, z) local p = ENTS[e].pos return vector3(p.x + x, p.y + y, p.z + z) end
local BONES = { [31086] = { 0, 0, 0.62 }, [39317] = { 0, 0, 0.5 }, [64729] = { -0.12, 0, 0.42 }, [10706] = { 0.12, 0, 0.42 }, [45509] = { -0.2, 0, 0.38 }, [40269] = { 0.2, 0, 0.38 },
    [61163] = { -0.24, 0, 0.12 }, [28252] = { 0.24, 0, 0.12 }, [18905] = { -0.26, 0, -0.1 }, [57005] = { 0.26, 0, -0.1 }, [24818] = { 0, 0, 0.3 }, [11816] = { 0, 0, 0 },
    [58271] = { -0.1, 0, -0.05 }, [51826] = { 0.1, 0, -0.05 }, [63931] = { -0.11, 0, -0.5 }, [36864] = { 0.11, 0, -0.5 }, [14201] = { -0.12, 0, -0.92 }, [52301] = { 0.12, 0, -0.92 },
    [20781] = { 0.12, -0.1, -0.97 }, [2108] = { -0.12, -0.1, -0.97 } }
function GetPedBoneCoords(e, b) local p, o = ENTS[e].pos, BONES[b] return vector3(p.x + o[1], p.y + o[2], p.z + o[3]) end
function GetGameTimer() return 0 end
LINES = {}
function DrawLine(x1, y1, z1, x2, y2, z2, r, g, b, a) LINES[#LINES + 1] = { x1, y1, z1, x2, y2, z2, a } end
function DrawRect() end function SetTextFont() end function SetTextScale() end function SetTextCentre() end function SetTextOutline() end function SetTextColour() end
function BeginTextCommandDisplayText() end function AddTextComponentSubstringPlayerName() end function EndTextCommandDisplayText() end
function DrawPoly() error('DrawPoly ne doit plus être utilisé (faces)') end
function DrawMarker() error('DrawMarker ne doit plus être utilisé (cercle au sol)') end
function SetEntityDrawOutline() error('contour natif interdit (plantage)') end
-- ---------------- chargement d'alt.lua
PoliceC = { ui = {} }
Config = { Distances = { alt = 3.0, vehicle = 5.0 }, Keys = { alt = 'LMENU' } }
function RegisterNUICallback() end function RegisterCommand() end function RegisterKeyMapping() end function CreateThread() end function AddEventHandler() end
local src = io.open(ROOT .. '/client/alt.lua'):read('a')
assert(load(src, '=alt.lua'))()
local C = PoliceC
-- ---------------- tests du contour
local function project(l) local _, ax, ay = GetScreenCoordFromWorldCoord(l[1], l[2], l[3]) local _, bx, by = GetScreenCoordFromWorldCoord(l[4], l[5], l[6]) return ax, ay, bx, by end
local function inside(poly, x, y) -- point dans le polygone (rayons)
    local c = false
    for i = 1, #poly do local a, b = poly[i], poly[i % #poly + 1]
        if ((a[2] > y) ~= (b[2] > y)) and (x < (b[1] - a[1]) * (y - a[2]) / (b[2] - a[2]) + a[1]) then c = not c end end
    return c
end
OUT = {}
local function run(name, ent, wantNotBox)
    LINES = {}
    C.AltHighlight(ent, 'player', name)
    local core = {}
    for _, l in ipairs(LINES) do if l[7] >= 150 then local ax, ay = project(l) core[#core + 1] = { ax, ay } end end
    OUT[name] = LINES
    -- toutes les parties de l'entité sont à l'intérieur du contour
    local allIn = true
    local pts = {}
    if IsEntityAPed(ent) then for b in pairs(BONES) do pts[#pts + 1] = GetPedBoneCoords(ent, b) end
    elseif IsEntityAVehicle(ent) then
        local mn, mx = GetModelDimensions(GetEntityModel(ent))
        local zm = mn.z + (mx.z - mn.z) * 0.5
        for _, q in ipairs({ { mn.x * 0.9, mn.z + 0.2 }, { mx.x * 0.9, mn.z + 0.2 }, { mn.x * 0.85, zm }, { mx.x * 0.85, zm }, { 0, mx.z * 0.9 } }) do pts[#pts + 1] = GetOffsetFromEntityInWorldCoords(ent, q[1], 0, q[2]) end
    else local mn, mx = GetModelDimensions(GetEntityModel(ent)) for _, x in ipairs({ mn.x * 0.9, mx.x * 0.9 }) do for _, z in ipairs({ mn.z + 0.2, mx.z * 0.9 }) do pts[#pts + 1] = GetOffsetFromEntityInWorldCoords(ent, x, 0, z) end end end
    for _, p in ipairs(pts) do local _, sx, sy = GetScreenCoordFromWorldCoord(p.x, p.y, p.z) if not inside(core, sx, sy) then allIn = false end end
    return #core, allIn
end
ENTS[10] = { kind = 'ped', pos = vector3(0.4, 5, 1.0), model = 'ped' } DIMS.ped = { vector3(-0.3, -0.2, -1), vector3(0.3, 0.2, 0.8) }
ENTS[11] = { kind = 'veh', pos = vector3(-1.0, 9, 0.6), model = 'car' } DIMS.car = { vector3(-0.95, -2.3, -0.55), vector3(0.95, 2.3, 0.85) }
ENTS[12] = { kind = 'obj', pos = vector3(1.2, 4, 0.4), model = 'box' } DIMS.box = { vector3(-0.3, -0.3, -0.4), vector3(0.3, 0.3, 0.4) }
local nP, inP = run('personnage', 10)
check(nP >= 8 and inP, ('personnage : contour fermé de %d segments qui entoure tout le corps'):format(nP))
local nV, inV = run('voiture', 11)
check(nV >= 6 and inV, ('véhicule : contour fermé de %d segments qui entoure la carrosserie'):format(nV))
local nO, inO = run('objet', 12)
check(nO >= 4 and inO, ('objet : contour extérieur seul (%d segments, pas d\'arêtes intérieures)'):format(nO))
check(#OUT.personnage == nP * 3, 'trois traits concentriques (cœur lumineux + halo), aucune boîte, aucune face, aucun cercle au sol')
LINES = {} C.AltHighlight(99, 'player', 'x') check(#LINES == 0, 'cible disparue : rien n\'est dessiné, pas d\'erreur')
ENTS[13] = { kind = 'ped', pos = vector3(0, -3, 1.0), model = 'ped' }
LINES = {} C.AltHighlight(13, 'player', 'x') check(#LINES == 0, 'cible derrière la caméra : rien n\'est dessiné')
-- ---------------- choix de la cible : le bébé (elyzea_bebe_modele)
ENTS[1] = { kind = 'ped', pos = vector3(0, 0, 1) }
function PlayerPedId() return 1 end
function GetEntityForwardVector() return vector3(0, 1, 0) end
function PlayerId() return 0 end
ACTIVE = { 0 }
function GetActivePlayers() return ACTIVE end
function GetPlayerPed(pid) return pid == 0 and 1 or 20 end
function GetPlayerServerId() return 7 end
function NetworkGetPlayerIndexFromPed() return 1 end
function IsPedAPlayer(e) return e == 1 or e == 20 end
function IsPedInAnyVehicle() return false end
function Entity() return { state = {} } end
RAYHIT = nil
function StartExpensiveSynchronousShapeTestLosProbe(_, _, _, _, _, _, flags) return flags end
function GetShapeTestResult(flags) if RAYHIT and (flags == 16) == (RAYHIT.obj == true) then return 2, true, nil, nil, RAYHIT.ent end return 2, false, nil, nil, 0 end
STARTED = { elyzea_bebe_modele = true }
function GetResourceState(r) return STARTED[r] and 'started' or 'missing' end
BEBE = { nearby = nil, target = {} }
exports = setmetatable({}, { __index = function(_, res)
    if res == 'elyzea_bebe_modele' then return {
        AltNearby = function() if BEBE.nearby then return BEBE.nearby, BEBE.title end end,
        AltTarget = function(_, e) return BEBE.target[e] end } end
    return { AltNearby = function() return nil end, AltTarget = function() return nil end }
end })
C.IsCarrying = function() return false end C.InTrunk = function() return false end
ENTS[20] = { kind = 'ped', pos = vector3(0, 1.4, 1) }       -- un autre joueur en face, à 1,4 m
ENTS[30] = { kind = 'obj', pos = vector3(0.3, 0.6, 0.9) }   -- bébé posé à 0,7 m
ACTIVE = { 0, 1 }
BEBE.nearby, BEBE.title = 30, 'Bébé'
local ctx = C.AltContext()
check(ctx.kind == 'ext' and ctx.entity == 30 and ctx.provider == 'elyzea_bebe_modele', 'rien de visé : le bébé plus proche que le joueur en face est proposé')
ENTS[30].pos = vector3(0, 2.4, 0.9)
ctx = C.AltContext()
check(ctx.kind == 'player' and ctx.entity == 20, 'joueur plus proche que le bébé : le joueur est proposé (comme avant)')
ENTS[31] = { kind = 'obj', pos = vector3(0, 0.35, 1.0) }    -- bébé porté (collé au joueur)
BEBE.nearby, BEBE.title = 31, 'Bébé (porté)'
ctx = C.AltContext()
check(ctx.kind == 'ext' and ctx.entity == 31, 'bébé porté : ses options (poser, installer dans la poussette…) passent avant la personne en face')
ENTS[32] = { kind = 'obj', pos = vector3(0, 0.8, 0.6) }     -- poussette poussée
BEBE.nearby, BEBE.title = 32, 'Poussette'
ctx = C.AltContext()
check(ctx.kind == 'ext' and ctx.entity == 32, 'poussette poussée : garer, lâcher, installer le bébé proposés')
BEBE.nearby = nil
BEBE.target[33] = 'Poussette' ENTS[33] = { kind = 'obj', pos = vector3(0.5, 2.0, 0.6) }
RAYHIT = { ent = 33, obj = true }
ctx = C.AltContext()
check(ctx.kind == 'ext' and ctx.entity == 33 and ctx.title == 'Poussette', 'poussette visée au curseur : reconnue (cible de elyzea_bebe_modele)')
RAYHIT = nil STARTED.elyzea_bebe_modele = nil
ctx = C.AltContext()
check(ctx.kind == 'player', 'ressource bébé absente : le ALT marche comme avant, sans erreur')
print(('Résultat : %d/%d réussis'):format(n - fails, n))
return fails
