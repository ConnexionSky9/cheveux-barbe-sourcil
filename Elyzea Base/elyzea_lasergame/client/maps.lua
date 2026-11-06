-- =====================================================================
--  ELYZEA LASERGAME - ARÈNE EN PARTIE (client)
--  L'arène est un endroit du monde GTA choisi par le staff : zone de combat (polygone + sol / plafond),
--  apparitions des deux équipes, heure et météo facultatives. Le décor est celui posé avec l'éditeur
--  de map d'admin_menu (objets locaux chez chaque joueur : ils existent aussi dans l'instance).
--  En partie : mur invisible (retour à la dernière position valide) et paroi laser visible près du bord.
-- =====================================================================
Map = { data = nil, zone = nil, center = nil, built = false }

local function v3(p) return vector3(p.x + 0.0, p.y + 0.0, (p.z or 0) + 0.0) end

-- Points à précharger : centre, apparitions, coins (collisions + objets de l'éditeur de map autour)
local function preloadPoints(info)
    local pts = {}
    if info.center then pts[#pts + 1] = info.center end
    for _, t in ipairs({ 'A', 'B' }) do
        for _, p in ipairs(((info.spawns or {})[t]) or {}) do pts[#pts + 1] = p end
    end
    for _, p in ipairs(((info.zone or {}).points) or {}) do pts[#pts + 1] = p end
    return pts
end

-- Préparation (progressive, jamais bloquante : au plus ~3 s, la partie démarre même si tout n'est pas chargé)
function Map.Build(info, onProgress)
    Map.Unload()
    if type(info) ~= 'table' or type(info.zone) ~= 'table' then
        C.Notify('Arène introuvable.', 'error')
        return false
    end
    Map.data = info
    local z = info.zone
    Map.zone = { points = {}, minZ = tonumber(z.minZ) or -1000.0, maxZ = tonumber(z.maxZ) or 3000.0 }
    for _, p in ipairs(z.points or {}) do Map.zone.points[#Map.zone.points + 1] = { x = p.x + 0.0, y = p.y + 0.0 } end
    Map.center = info.center and v3(info.center) or nil
    local pts = preloadPoints(info)
    local t0, dur = GetGameTimer(), 2600
    while GetGameTimer() - t0 < dur do
        for i = 1, #pts do RequestCollisionAtCoord(pts[i].x + 0.0, pts[i].y + 0.0, (pts[i].z or 0) + 0.0) end
        if onProgress then onProgress(math.min(0.98, (GetGameTimer() - t0) / dur)) end
        Wait(100)
    end
    Map.built = true
    if onProgress then onProgress(1.0) end
    -- heure et météo de l'arène (seulement pour ce joueur, pendant la partie)
    if info.time then NetworkOverrideClockTime(math.floor(info.time), 0, 0) end
    if info.weather then
        SetWeatherTypeOvertimePersist(info.weather, 1.0)
        SetWeatherTypeNowPersist(info.weather)
    end
    return true
end

function Map.Unload()
    if Map.built and Map.data then
        if Map.data.time then NetworkClearClockTimeOverride() end
        if Map.data.weather then ClearOverrideWeather() ClearWeatherTypePersist() end
    end
    Map.built, Map.data, Map.zone, Map.center = false, nil, nil, nil
end

-- ---------------------------------------------------------------- rendu par image (seulement en partie)
local lastValid = nil

local function inZone(p)
    if not Map.zone then return true end
    if p.z < Map.zone.minZ or p.z > Map.zone.maxZ then return false end
    return LGU.PointInPolygon(Map.zone.points, p.x, p.y)
end
Map.InZone = inZone

-- Paroi laser violette : seulement la portion du bord à moins de 6 m du joueur (visible des deux côtés)
local function drawWalls(pos)
    local pts = Map.zone and Map.zone.points
    if not pts or #pts < 3 then return end
    local r, g, b = 170, 90, 255
    for i = 1, #pts do
        local a, c = pts[i], pts[(i % #pts) + 1]
        local dx, dy = c.x - a.x, c.y - a.y
        local l2 = dx * dx + dy * dy
        local t = l2 > 0 and LGU.Clamp(((pos.x - a.x) * dx + (pos.y - a.y) * dy) / l2, 0, 1) or 0
        local px, py = a.x + dx * t, a.y + dy * t
        local d = math.sqrt((pos.x - px) ^ 2 + (pos.y - py) ^ 2)
        if d < 6.0 then
            local alpha = math.floor(110 * (1 - d / 6.0))
            local z0 = math.max(Map.zone.minZ, pos.z - 1.5)
            local z1 = math.min(Map.zone.maxZ, pos.z + 3.5)
            local half = 6.0 / math.max(0.001, math.sqrt(l2))
            local t0, t1 = LGU.Clamp(t - half, 0, 1), LGU.Clamp(t + half, 0, 1)
            local ax, ay, bx, by = a.x + dx * t0, a.y + dy * t0, a.x + dx * t1, a.y + dy * t1
            DrawPoly(ax, ay, z0, bx, by, z0, bx, by, z1, r, g, b, alpha)
            DrawPoly(bx, by, z1, ax, ay, z1, ax, ay, z0, r, g, b, alpha)
            DrawPoly(bx, by, z1, bx, by, z0, ax, ay, z0, r, g, b, alpha)
            DrawPoly(ax, ay, z0, ax, ay, z1, bx, by, z1, r, g, b, alpha)
            DrawLine(ax, ay, z0, bx, by, z0, r, g, b, math.min(255, alpha * 2))
        end
    end
end

-- Appelé chaque image par la boucle de partie
function Map.Tick(ped, pos, canMove)
    if not Map.built then return end
    -- mur invisible : retour à la dernière position valide
    if canMove and Map.zone then
        if inZone(pos) then lastValid = pos
        elseif lastValid then
            SetEntityCoordsNoOffset(ped, lastValid.x, lastValid.y, lastValid.z, false, false, false)
            SetEntityVelocity(ped, 0.0, 0.0, 0.0)
        end
        drawWalls(pos)
    end
end

function Map.ResetWall(p) lastValid = p and vector3(p.x, p.y, p.z) or nil end

-- Renvoi par le serveur (sortie de zone)
RegisterNetEvent('elyzea_lasergame:pushBack', function(p)
    if not C.inGame or type(p) ~= 'table' then return end
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, p.x + 0.0, p.y + 0.0, p.z + 0.0, false, false, false)
    Map.ResetWall(p)
    C.Notify('Zone interdite.', 'error')
end)

-- ---------------------------------------------------------------- aperçu staff (zone + apparitions, 60 s)
-- Dessine le contour de la zone (sol et plafond), les apparitions de chaque équipe (flèche = direction)
-- pour le staff seul, dans le monde normal : pratique pendant la décoration avec l'éditeur de map.
local showing = nil
function Map.DrawArena(info)
    local z = info.zone or {}
    local pts = z.points or {}
    local cam = GetFinalRenderedCamCoord()
    if #pts >= 3 then
        local z0 = tonumber(z.minZ) or (cam.z - 2.0)
        local z1 = math.min(tonumber(z.maxZ) or (z0 + 10.0), z0 + 60.0)
        for i = 1, #pts do
            local a, b = pts[i], pts[(i % #pts) + 1]
            DrawLine(a.x, a.y, z0, b.x, b.y, z0, 170, 90, 255, 255)
            DrawLine(a.x, a.y, z1, b.x, b.y, z1, 170, 90, 255, 150)
            DrawLine(a.x, a.y, z0, a.x, a.y, z1, 170, 90, 255, 110)
        end
    end
    for _, team in ipairs({ 'A', 'B' }) do
        local r, g, b = C.TeamColor(team)
        for i, s in ipairs(((info.spawns or {})[team]) or {}) do
            local h = math.rad(s.h or 0)
            DrawMarker(1, s.x, s.y, s.z - 1.0, 0, 0, 0, 0, 0, 0, 0.9, 0.9, 1.4, r, g, b, 150, false, false, 2, false, nil, nil, false)
            DrawLine(s.x, s.y, s.z - 0.6, s.x - math.sin(h) * 1.6, s.y + math.cos(h) * 1.6, s.z - 0.6, r, g, b, 255)
            if #(cam - vector3(s.x, s.y, s.z)) < 40.0 then
                SetDrawOrigin(s.x, s.y, s.z + 1.0, 0)
                SetTextScale(0.0, 0.3) SetTextFont(4) SetTextCentre(true) SetTextOutline()
                SetTextColour(255, 255, 255, 230)
                BeginTextCommandDisplayText('STRING')
                AddTextComponentSubstringPlayerName(('%s n°%d'):format(Config.Teams[team].name, i))
                EndTextCommandDisplayText(0.0, 0.0)
                ClearDrawOrigin()
            end
        end
    end
end

RegisterNetEvent('elyzea_lasergame:adminShowArena', function(info)
    if C.inGame or type(info) ~= 'table' then return end
    C.CloseUI()
    local token = {}
    showing = token
    C.Notify(('Arène « %s » affichée pendant 60 s.'):format(info.label or '?'), 'info')
    CreateThread(function()
        local stop = GetGameTimer() + 60000
        while showing == token and GetGameTimer() < stop and not C.inGame do
            Map.DrawArena(info)
            Wait(0)
        end
        if showing == token then showing = nil end
    end)
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then Map.Unload() end end)
