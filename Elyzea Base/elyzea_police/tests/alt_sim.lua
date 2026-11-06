-- Simulation hors jeu du menu ALT : surbrillance (cadre de visée violet, contour natif) et choix de la cible (bébé).
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
    [20781] = { -0.12, -0.12, -0.97 }, [35502] = { 0.12, -0.12, -0.97 } }
function GetPedBoneCoords(e, b) local p, o = ENTS[e].pos, BONES[b] return vector3(p.x + o[1], p.y + o[2], p.z + o[3]) end
CLOCK = 0
function GetGameTimer() CLOCK = CLOCK + 400 return CLOCK end   -- chaque appel avance (caches de 300 / 800 ms)
LINES = {}
function DrawLine(x1, y1, z1, x2, y2, z2, r, g, b, a) LINES[#LINES + 1] = { x1, y1, z1, x2, y2, z2, a } end
RECTS = {}
function DrawRect(x, y, w, h, r, g, b, a) RECTS[#RECTS + 1] = { x, y, w, h, r, g, b, a } end
function SetTextFont() end function SetTextScale() end function SetTextCentre() end function SetTextOutline() end function SetTextColour() end
function BeginTextCommandDisplayText() end function AddTextComponentSubstringPlayerName() end function EndTextCommandDisplayText() end
function DrawPoly() error('DrawPoly ne doit plus être utilisé (faces)') end
function DrawMarker() error('DrawMarker ne doit plus être utilisé (cercle au sol)') end
OUTLINED = {}
function SetEntityDrawOutline(e, on)
    if ENTS[e] and ENTS[e].kind == 'ped' then error('contour natif sur un personnage : plantage') end
    OUTLINED[e] = on or nil
end
function SetEntityDrawOutlineColor() end
function IsPedHuman(e) return ENTS[e].human ~= false end
-- ---------------- chargement d'alt.lua
PoliceC = { ui = {} }
Config = { Distances = { alt = 3.0, vehicle = 5.0 }, Keys = { alt = 'LMENU' } }
CMDS, THREADS = {}, {}
function RegisterNUICallback() end function RegisterCommand(n, fn) CMDS[n] = fn end function RegisterKeyMapping() end
function CreateThread(fn) THREADS[#THREADS + 1] = coroutine.create(fn) end function AddEventHandler() end
exports = setmetatable({}, { __call = function() end })   -- exports('OpenFor', …) au chargement d'alt.lua
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
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
ENTS[10] = { kind = 'ped', pos = vector3(0.4, 4, 1.0), model = 'ped' } DIMS.ped = { vector3(-0.3, -0.2, -1), vector3(0.3, 0.2, 0.8) }
ENTS[11] = { kind = 'veh', pos = vector3(-1.0, 9, 0.6), model = 'car' } DIMS.car = { vector3(-0.95, -2.3, -0.55), vector3(0.95, 2.3, 0.85) }
ENTS[12] = { kind = 'obj', pos = vector3(1.2, 4, 0.4), model = 'box' } DIMS.box = { vector3(-0.3, -0.3, -0.4), vector3(0.3, 0.3, 0.4) }
ENTS[14] = { kind = 'ped', human = false, pos = vector3(-0.8, 4, 0.4), model = 'dog' } DIMS.dog = { vector3(-0.2, -0.5, -0.4), vector3(0.2, 0.5, 0.3) }
-- personne : cadre de visée (4 coins violets) autour du corps, jamais le contour natif, aucun trait 3D
local function box(rects)   -- rectangle englobant des coins dessinés (hors voile et étiquette)
    local x0, y0, x1, y1 = 1, 1, 0, 0
    for _, r in ipairs(rects) do if r[8] >= 150 and r[3] < 0.1 and r[4] < 0.1 and r[4] ~= 0.03 and r[5] == 155 then
        x0, x1, y0, y1 = math.min(x0, r[1] - r[3] / 2), math.max(x1, r[1] + r[3] / 2), math.min(y0, r[2] - r[4] / 2), math.max(y1, r[2] + r[4] / 2) end end
    return x0, y0, x1, y1
end
local function proj(x, y, z) local _, sx, sy = GetScreenCoordFromWorldCoord(x, y, z) return sx, sy end
RECTS, LINES = {}, {}
C.AltHighlight(10, 'player', 'Personne · ID 7  ·  3 actions')
local x0, y0, x1, y1 = box(RECTS)
local hx, hy = proj(0.4, 4, 1.62 + 0.2)
local _, fy = proj(0.4, 4, 1.0 - 0.92)
local lhx = proj(0.4 - 0.26, 4, 0.9)
check(#LINES == 0 and count(OUTLINED) == 0, 'personne : aucun contour natif (plantage), aucun trait 3D coûteux')
check(x0 < lhx and y0 < hy and y1 > fy and y1 - fy < 0.05 and hy - y0 < 0.05, 'le cadre entoure la personne de la tête aux pieds, au plus près')
local violet, label = 0, false
for _, r in ipairs(RECTS) do if r[5] == 155 and r[6] == 92 and r[7] == 255 then violet = violet + 1 end if r[5] == 13 and r[6] == 8 and r[7] == 32 then label = true end end
check(violet >= 8 and label, ('couleurs du logo : coins violet néon (%d éléments) et étiquette nuit'):format(violet))
check(#RECTS <= 24, ('dessin léger : %d rectangles par image (avant : ~6 000 calculs et des centaines de traits)'):format(#RECTS))
-- véhicule et objet : contour natif exact, violet
RECTS, LINES = {}, {}
C.AltHighlight(11, 'vehicle', 'Véhicule')
check(OUTLINED[11] and #LINES == 0, 'véhicule : contour natif du jeu, pile sur la carrosserie')
C.AltHighlight(12, 'ext', 'Objet')
check(OUTLINED[12] and not OUTLINED[11], 'objet : contour natif ; l\'ancienne cible est éteinte (une seule à la fois)')
C.AltHighlight(10, 'player', 'Personne')
check(count(OUTLINED) == 0, 'passage sur une personne : le contour natif est retiré')
RECTS = {} C.AltHighlight(14, 'ext', 'Chien')
check(#RECTS >= 8 and count(OUTLINED) == 0, 'animal : cadre de visée, jamais le contour natif')
C.AltHighlight(12, 'ext', 'Objet') C.ClearOutline()
check(count(OUTLINED) == 0, 'ALT relâché / menu fermé : plus rien d\'allumé')
RECTS = {} C.AltHighlight(99, 'player', 'x') check(#RECTS == 0, 'cible disparue : rien n\'est dessiné, pas d\'erreur')
ENTS[13] = { kind = 'ped', pos = vector3(0, -3, 1.0), model = 'ped' }
RECTS = {} C.AltHighlight(13, 'player', 'x') check(#RECTS == 0, 'cible derrière la caméra : rien n\'est dessiné')
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
-- ---------------- boucle ALT : recherche limitée, sécurité Alt+Tab
STARTED = {}
RAYS = 0
function StartExpensiveSynchronousShapeTestLosProbe(_, _, _, _, _, _, flags) RAYS = RAYS + 1 return flags end
function Wait() coroutine.yield() end
function SetMouseCursorActiveThisFrame() CURSOR = CURSOR + 1 end
function DisableControlAction() end
KEY_ALT = true
function IsControlPressed(_, c) return c == 19 and KEY_ALT end
function IsDisabledControlPressed() return false end
function IsDisabledControlJustPressed() return false end
function IsPauseMenuActive() return false end
function IsEntityDead() return false end
LocalPlayer = { state = {} }
C.AnyOpen = function() return false end
C.OnDuty = function() return false end
C.CitizenOptions = function(ctx, out) if ctx.kind == 'player' then out[#out + 1] = { id = 'carry', label = 'Porter', icon = 'carry' } end end
ENTS[30], ENTS[31], ENTS[32], ENTS[33] = nil, nil, nil, nil
local function frames(k, step)
    for _ = 1, k do
        CLOCK = CLOCK + 16   -- une image = 16 ms
        for i = #THREADS, 1, -1 do
            local co = THREADS[i]
            if coroutine.status(co) == 'dead' then table.remove(THREADS, i) else
                local ok, err = coroutine.resume(co)
                if not ok then error(err) end
            end
        end
        if step then step() end
    end
end
function GetGameTimer() return CLOCK end
CURSOR, THREADS = 0, {}
CMDS['+police_alt']()
frames(62)   -- ~1 seconde à 60 images/s
check(RAYS >= 10 and RAYS <= 26, ('cible recherchée ~11 fois par seconde : %d rayons en 1 s (avant : jusqu\'à 120)'):format(RAYS))
check(CURSOR >= 60, 'curseur actif à chaque image tant que ALT est tenu')
-- Alt+Tab : le relâchement de la touche n'arrive jamais au jeu
KEY_ALT = false
local before = CURSOR
frames(10)
check(#THREADS == 0 and CURSOR - before <= 4 and count(OUTLINED) == 0, 'ALT perdu (Alt+Tab) : la boucle s\'arrête seule en 4 images, curseur rendu, rien d\'allumé')
KEY_ALT = true
CMDS['+police_alt']() frames(2)
check(#THREADS == 1, 'ALT de nouveau : le menu repart normalement')
CMDS['-police_alt']() frames(2)
check(#THREADS == 0, 'ALT relâché : arrêt immédiat')
-- joueur qui a remplacé ALT par une autre touche : jamais fermé par erreur
KEY_ALT = false
CMDS['+police_alt']() frames(30)
check(#THREADS == 1, 'touche ALT remplacée par une autre : le menu reste ouvert tant que la touche est tenue')
CMDS['-police_alt']() frames(2)
print(('Résultat : %d/%d réussis'):format(n - fails, n))
return fails
