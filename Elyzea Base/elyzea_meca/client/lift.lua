-- =====================================================================
--  ELYZEA MÉCANO - client : ponts roulants posés sur les points d'atelier
--  Visible par tous les joueurs proches. Par défaut le pont est dessiné en 3D par le
--  script (deux colonnes, chariots et bras qui suivent le dessous du véhicule) : le jeu
--  de base n'a pas de modèle de pont garanti. Si ta map ou un pack fournit un modèle,
--  mets son nom dans Config.Interventions.lift.models : il est alors utilisé à la place.
-- =====================================================================
local C = MecaC
local LC = (Config.Interventions or {}).lift or {}
local COL = LC.color or { 235, 180, 20 }      -- jaune atelier
local DARK = LC.darkColor or { 60, 60, 66 }

-- ---------------------------------------------------------------------
-- Dessin d'un pavé orienté (6 faces, visibles des deux côtés)
-- ---------------------------------------------------------------------
local function quad(a, b, c, d, r, g, bl, al)
    DrawPoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, r, g, bl, al)
    DrawPoly(a.x, a.y, a.z, c.x, c.y, c.z, d.x, d.y, d.z, r, g, bl, al)
    DrawPoly(c.x, c.y, c.z, b.x, b.y, b.z, a.x, a.y, a.z, r, g, bl, al)
    DrawPoly(d.x, d.y, d.z, c.x, c.y, c.z, a.x, a.y, a.z, r, g, bl, al)
end
-- centre (monde), demi-dimensions (repère local), cap en degrés, couleur
local function box(c, hx, hy, hz, heading, rgb, a)
    local h = math.rad(heading)
    local cs, sn = math.cos(h), math.sin(h)
    local function P(x, y, z) return vector3(c.x + x * cs - y * sn, c.y + x * sn + y * cs, c.z + z) end
    local p = {
        P(-hx, -hy, -hz), P(hx, -hy, -hz), P(hx, hy, -hz), P(-hx, hy, -hz),
        P(-hx, -hy, hz), P(hx, -hy, hz), P(hx, hy, hz), P(-hx, hy, hz),
    }
    local r, g, b = rgb[1], rgb[2], rgb[3]
    a = a or 255
    quad(p[1], p[2], p[3], p[4], r, g, b, a) quad(p[5], p[6], p[7], p[8], r, g, b, a)
    quad(p[1], p[2], p[6], p[5], r, g, b, a) quad(p[2], p[3], p[7], p[6], r, g, b, a)
    quad(p[3], p[4], p[8], p[7], r, g, b, a) quad(p[4], p[1], p[5], p[8], r, g, b, a)
end
-- Barre entre deux points (bras du pont)
local function bar(a, b, w, rgb)
    local mid = vector3((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2)
    local len = #(b - a)
    local yaw = math.deg(math.atan(b.y - a.y, b.x - a.x)) - 90.0
    box(mid, w, len / 2, w * 0.6, yaw, rgb)
end

-- ---------------------------------------------------------------------
-- Ponts publiés par le serveur (GlobalState.mecaWorkshops, champ lift)
-- ---------------------------------------------------------------------
local lifts = {}        -- [id du point] = { coords, ground, h, veh, half, model obj }
local function Ground(c)
    local ok, z = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)
    if ok and math.abs(z - c.z) < 3.0 then return z end
    return c.z - 1.0
end

local function LoadModel(list)
    for _, name in ipairs(list or {}) do
        local h = GetHashKey(name)
        if IsModelInCdimage(h) and IsModelValid(h) then
            RequestModel(h)
            local t = GetGameTimer() + 3000
            while not HasModelLoaded(h) and GetGameTimer() < t do Wait(10) end
            if HasModelLoaded(h) then return h end
        end
    end
end

-- Véhicule garé sur le pont (le plus proche du centre)
local function VehicleOn(l)
    local best, bestD = nil, (l.radius or 3.5) + 1.0
    for _, v in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(v).xy - l.coords.xy)
        if d < bestD then best, bestD = v, d end
    end
    return best
end

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local seen = {}
        for _, w in ipairs(C.Workshops()) do
            if w.lift then
                seen[w.id] = true
                local l = lifts[w.id]
                if not l then
                    l = { coords = w.coords, ground = Ground(w.coords), h = tonumber(w.lift.h) or 0.0, radius = w.radius }
                    lifts[w.id] = l
                end
                l.near = #(pos - w.coords) < (LC.drawDistance or 45.0)
                if l.near then
                    l.veh = VehicleOn(l)
                    if l.veh then
                        local min, max = GetModelDimensions(GetEntityModel(l.veh))
                        l.half, l.len, l.minZ = math.max(0.8, max.x), math.max(1.8, max.y - min.y), min.z
                    end
                    -- Modèle réel configuré (optionnel)
                    if LC.models and #LC.models > 0 and not (l.obj and DoesEntityExist(l.obj)) then
                        local m = LoadModel(LC.models)
                        if m then
                            l.obj = CreateObjectNoOffset(m, l.coords.x, l.coords.y, l.ground + (LC.offsetZ or 0.0), false, false, false)
                            SetEntityHeading(l.obj, (l.h + (LC.heading or 0.0)) % 360.0)
                            FreezeEntityPosition(l.obj, true)
                            SetModelAsNoLongerNeeded(m)
                        end
                    end
                elseif l.obj and DoesEntityExist(l.obj) then DeleteObject(l.obj) l.obj = nil end
            end
        end
        for id, l in pairs(lifts) do
            if not seen[id] then if l.obj and DoesEntityExist(l.obj) then DeleteObject(l.obj) end lifts[id] = nil end
        end
        Wait(500)
    end
end)

-- Dessin du pont « script » (colonnes, chariots et bras au niveau du dessous du véhicule)
CreateThread(function()
    while true do
        local any = false
        for _, l in pairs(lifts) do
            if l.near and not l.obj then
                any = true
                local veh = l.veh and DoesEntityExist(l.veh) and l.veh or nil
                local heading = veh and GetEntityHeading(veh) or l.h
                local half = veh and l.half or 1.0
                local cx, cy = l.coords.x, l.coords.y
                if veh then local vp = GetEntityCoords(veh) cx, cy = vp.x, vp.y end
                local g = l.ground
                local postH = LC.postHeight or 2.9
                local armZ = g + 0.12
                if veh then armZ = math.max(g + 0.12, GetEntityCoords(veh).z + l.minZ - 0.03) end
                armZ = math.min(armZ, g + postH - 0.2)
                local hr = math.rad(heading)
                local function W(x, y, z) return vector3(cx + x * math.cos(hr) - y * math.sin(hr), cy + x * math.sin(hr) + y * math.cos(hr), z) end
                local px = half + 0.45
                for _, side in ipairs({ -1, 1 }) do
                    local base = W(side * px, 0.0, g)
                    box(W(side * px, 0.0, g + 0.03), 0.32, 0.32, 0.03, heading, DARK)                    -- platine au sol
                    box(W(side * px, 0.0, g + postH / 2), 0.13, 0.13, postH / 2, heading, COL)           -- colonne
                    box(W(side * px, 0.0, g + postH + 0.04), 0.18, 0.18, 0.04, heading, DARK)            -- chapeau
                    box(W(side * px, 0.0, armZ + 0.12), 0.18, 0.2, 0.16, heading, DARK)                  -- chariot (monte avec la voiture)
                    local root = W(side * (px - 0.12), 0.0, armZ)
                    local len = (l.len or 4.4) * 0.32
                    bar(root, W(side * half * 0.55, len, armZ), 0.05, DARK)                            -- bras avant
                    bar(root, W(side * half * 0.55, -len, armZ), 0.05, DARK)                           -- bras arrière
                    box(W(side * half * 0.55, len, armZ + 0.03), 0.09, 0.09, 0.03, heading, COL)        -- tampons
                    box(W(side * half * 0.55, -len, armZ + 0.03), 0.09, 0.09, 0.03, heading, COL)
                end
                box(W(0.0, 0.0, g + postH + 0.06), px, 0.06, 0.04, heading, COL)                      -- traverse haute
            end
        end
        Wait(any and 0 or 500)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, l in pairs(lifts) do if l.obj and DoesEntityExist(l.obj) then DeleteObject(l.obj) end end
end)

-- Retirer le pont du point où l'on se trouve (direction) : il revient dans l'inventaire
RegisterCommand('meca_pont_retirer', function() C.Do('liftRemove') end, false)

-- Hauteur à laquelle le pont lève ce véhicule pour qu'un mécanicien tienne debout dessous
function C.LiftHeightFor(veh)
    local min = GetModelDimensions(GetEntityModel(veh))
    local under = GetEntityHeightAboveGround(veh) + min.z          -- garde au sol actuelle (souvent ~0,15 m)
    return math.max(0.6, (LC.clearance or 1.95) - under)
end
