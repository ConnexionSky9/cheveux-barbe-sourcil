-- =========================================================
--  ZONES : safe zones, quartiers, zones à message
--  - Message personnalisé à l'entrée et à la sortie
--  - Safe zone : pas d'armes ni de coups, joueurs invincibles,
--    limite de vitesse, exception police possible
--  - Dessin libre (coins posés un par un) ou cercle
-- =========================================================
local ZC = Config.Zones
local colorById = {}
for _, c in ipairs(ZC.colors) do colorById[c.id] = c end

local inside = {}        -- [idZone] = true
local zoneBlips = {}
local safeActive = nil   -- réglages cumulés des safe zones où l'on se trouve
local wasInvincible, noDriveBy, limitedSpeed = false, false, false

local function rgb(hex)
    hex = (hex or '#4fb3a9'):gsub('#', '')
    return tonumber(hex:sub(1, 2), 16) or 79, tonumber(hex:sub(3, 4), 16) or 179, tonumber(hex:sub(5, 6), 16) or 169
end

-- Point dans un polygone (2D)
local function inPoly(pts, x, y)
    local inside2, j = false, #pts
    for i = 1, #pts do
        local xi, yi, xj, yj = pts[i].x, pts[i].y, pts[j].x, pts[j].y
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / ((yj - yi) ~= 0 and (yj - yi) or 0.0001) + xi) then
            inside2 = not inside2
        end
        j = i
    end
    return inside2
end

local function inZone(z, p)
    if p.z < z.minZ or p.z > z.maxZ then return false end
    if z.shape == 'circle' then
        local dx, dy = p.x - z.center.x, p.y - z.center.y
        return dx * dx + dy * dy <= z.radius * z.radius
    end
    if not z._box then
        local b = { minX = math.huge, minY = math.huge, maxX = -math.huge, maxY = -math.huge }
        for _, q in ipairs(z.points) do
            b.minX, b.minY = math.min(b.minX, q.x), math.min(b.minY, q.y)
            b.maxX, b.maxY = math.max(b.maxX, q.x), math.max(b.maxY, q.y)
        end
        z._box = b
    end
    local b = z._box
    if p.x < b.minX or p.x > b.maxX or p.y < b.minY or p.y > b.maxY then return false end
    return inPoly(z.points, p.x, p.y)
end

-- Le point est-il dans une safe zone ? (utilisé par l'événement zombies)
function IsInSafeZone(p)
    for _, z in ipairs((Editor and Editor.zones) or {}) do
        if z.safe and inZone(z, p) then return true end
    end
    return false
end

local function zoneCenter(z)
    if z.shape == 'circle' then return z.center.x, z.center.y, z.radius end
    local cx, cy = 0.0, 0.0
    for _, q in ipairs(z.points) do cx, cy = cx + q.x, cy + q.y end
    cx, cy = cx / #z.points, cy / #z.points
    local r = 0.0
    for _, q in ipairs(z.points) do r = math.max(r, math.sqrt((q.x - cx) ^ 2 + (q.y - cy) ^ 2)) end
    return cx, cy, r
end

-- ---------------------------------------------------------
--  Blips et synchro
-- ---------------------------------------------------------
function RefreshZones()
    for _, b in ipairs(zoneBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    zoneBlips = {}
    for _, z in ipairs(Editor.zones or {}) do
        z._box = nil
        if z.blip then
            local cx, cy, r = zoneCenter(z)
            local col = (colorById[z.color] or {}).blip or 2
            local area = AddBlipForRadius(cx, cy, 0.0, r + 0.0)
            SetBlipColour(area, col)
            SetBlipAlpha(area, 90)
            local b = AddBlipForCoord(cx, cy, 0.0)
            local sprite = tonumber(z.blipSprite) or 0
            SetBlipSprite(b, sprite > 0 and sprite or (z.safe and 487 or 1))
            SetBlipColour(b, col)
            SetBlipScale(b, (tonumber(z.blipScale) or 0.8) + 0.0)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(z.name)
            EndTextCommandSetBlipName(b)
            zoneBlips[#zoneBlips + 1] = area
            zoneBlips[#zoneBlips + 1] = b
        end
    end
    -- Zones supprimées : on en sort proprement
    local ids = {}
    for _, z in ipairs(Editor.zones or {}) do ids[z.id] = true end
    for id in pairs(inside) do if not ids[id] then inside[id] = nil end end
    if RefreshVoiceZones then RefreshVoiceZones() end
end

local function isPolice()
    local ok, job = pcall(function()
        local pd = exports.elyzea_core:GetPlayerData()
        return pd and pd.job
    end)
    if ok and job then
        for _, j in ipairs(Config.PoliceJobs or {}) do
            if job.name == j and job.onduty ~= false then return true end
        end
    end
    return false
end

-- ---------------------------------------------------------
--  Entrée / sortie (4 fois par seconde)
-- ---------------------------------------------------------
CreateThread(function()
    while true do
        Wait(250)
        local zones = Editor.zones or {}
        if #zones > 0 then
            local p = GetEntityCoords(PlayerPedId())
            local safe = nil
            for _, z in ipairs(zones) do
                local now = inZone(z, p)
                if now and not inside[z.id] then
                    inside[z.id] = true
                    local msg = (z.enterMsg and z.enterMsg ~= '') and z.enterMsg or nil
                    if msg then SendNUIMessage({ action = 'zonemsg', text = msg, color = (colorById[z.color] or {}).hex, safe = z.safe }) end
                elseif not now and inside[z.id] then
                    inside[z.id] = nil
                    if z.exitMsg and z.exitMsg ~= '' then
                        SendNUIMessage({ action = 'zonemsg', text = z.exitMsg, color = (colorById[z.color] or {}).hex })
                    end
                end
                if now and z.safe and not (z.exemptPolice and isPolice()) then
                    safe = safe or { noWeapons = false, invincible = false, speedLimit = 0 }
                    safe.noWeapons = safe.noWeapons or z.noWeapons
                    safe.invincible = safe.invincible or z.invincible
                    if z.speedLimit > 0 and (safe.speedLimit == 0 or z.speedLimit < safe.speedLimit) then safe.speedLimit = z.speedLimit end
                end
            end
            safeActive = safe
        else
            safeActive = nil
        end
    end
end)

-- Effets de la safe zone (à chaque image seulement quand on y est)
CreateThread(function()
    local UNARMED = GetHashKey('WEAPON_UNARMED')
    local BLOCKED = { 24, 25, 37, 45, 47, 58, 140, 141, 142, 143, 257, 263, 264 }   -- créée une seule fois
    while true do
        local s = safeActive
        if s then
            local ped, pid = PlayerPedId(), PlayerId()
            if s.noWeapons then
                DisablePlayerFiring(pid, true)
                for i = 1, #BLOCKED do DisableControlAction(0, BLOCKED[i], true) end
                if GetSelectedPedWeapon(ped) ~= UNARMED then SetCurrentPedWeapon(ped, UNARMED, true) end
                SetPlayerCanDoDriveBy(pid, false)
                noDriveBy = true
            end
            if s.invincible then
                SetEntityInvincible(ped, true)
                wasInvincible = true
            end
            if s.speedLimit > 0 then
                local veh = GetVehiclePedIsIn(ped, false)
                if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                    SetVehicleMaxSpeed(veh, s.speedLimit / 3.6)
                    limitedSpeed = true
                end
            end
            Wait(0)
        else
            -- Sortie de safe zone : on rend tout comme avant
            if wasInvincible then
                wasInvincible = false
                if not State.godmode and not IsNoclipActive() then SetEntityInvincible(PlayerPedId(), false) end
            end
            if noDriveBy then noDriveBy = false SetPlayerCanDoDriveBy(PlayerId(), true) end
            if limitedSpeed then
                limitedSpeed = false
                local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                if veh ~= 0 then SetVehicleMaxSpeed(veh, 0.0) end
            end
            while not safeActive do Wait(250) end
        end
    end
end)

-- ---------------------------------------------------------
--  Limites visibles (pour tous si la zone le demande,
--  pour le staff si « Afficher les limites » est activé)
-- ---------------------------------------------------------
local function drawWall(a, b, zMin, zMax, r, g, bl, al)
    DrawPoly(a.x, a.y, zMin, b.x, b.y, zMin, b.x, b.y, zMax, r, g, bl, al)
    DrawPoly(a.x, a.y, zMin, b.x, b.y, zMax, a.x, a.y, zMax, r, g, bl, al)
    DrawPoly(b.x, b.y, zMax, b.x, b.y, zMin, a.x, a.y, zMin, r, g, bl, al)
    DrawPoly(a.x, a.y, zMax, b.x, b.y, zMax, a.x, a.y, zMin, r, g, bl, al)
end

local function drawZone(z, p)
    local r, g, b = rgb((colorById[z.color] or {}).hex)
    local zMin, zMax = p.z - 2.0, p.z + 8.0
    if z.soundproof then zMin, zMax = z.minZ, z.maxZ end   -- la vraie boîte (pièce insonorisée)
    if z.shape == 'circle' then
        DrawMarker(1, z.center.x, z.center.y, zMin, 0, 0, 0, 0, 0, 0, z.radius * 2.0, z.radius * 2.0, zMax - zMin,
            r, g, b, 45, false, false, 2, false, nil, nil, false)
        return
    end
    local n = #z.points
    for i = 1, n do
        local a, c = z.points[i], z.points[i % n + 1]
        drawWall(a, c, zMin, zMax, r, g, b, 45)
        DrawLine(a.x, a.y, zMin, c.x, c.y, zMin, r, g, b, 220)
        DrawLine(a.x, a.y, zMax, c.x, c.y, zMax, r, g, b, 220)
    end
end

-- Zones d'interaction des PNJ (or), visibles pour le staff avec « Afficher les limites »
local function drawNpcAreas(p)
    local any = false
    for _, r in ipairs(Editor.peds or {}) do
        local a = r.npc and r.npc.area
        if a and (p.x - r.x) ^ 2 + (p.y - r.y) ^ 2 < 150.0 ^ 2 then
            any = true
            if a.shape == 'circle' then
                DrawMarker(1, r.x, r.y, r.z - 1.0, 0, 0, 0, 0, 0, 0, a.radius * 2.0, a.radius * 2.0, 1.2,
                    217, 181, 106, 70, false, false, 2, false, nil, nil, false)
            else
                local n = #a.points
                for i = 1, n do
                    local q, c = a.points[i], a.points[i % n + 1]
                    drawWall(q, c, a.minZ, math.min(a.maxZ, a.minZ + 4.0), 217, 181, 106, 40)
                    DrawLine(q.x, q.y, a.minZ + 0.05, c.x, c.y, a.minZ + 0.05, 217, 181, 106, 230)
                end
            end
            DrawText3D(vector3(r.x, r.y, r.z + 1.2), ('Zone : %s'):format(r.name ~= '' and r.name or ('PNJ #' .. r.id)), 0.3)
        end
    end
    return any
end

CreateThread(function()
    while true do
        local zones = Editor.zones or {}
        local any = false
        if State.showZones then any = drawNpcAreas(GetEntityCoords(PlayerPedId())) or any end
        if #zones > 0 then
            local p = GetEntityCoords(PlayerPedId())
            for _, z in ipairs(zones) do
                if z.showBorder or State.showZones then
                    local cx, cy, rad = zoneCenter(z)
                    if (p.x - cx) ^ 2 + (p.y - cy) ^ 2 < (rad + 200.0) ^ 2 then
                        any = true
                        drawZone(z, p)
                    end
                end
            end
        end
        Wait(any and 0 or 500)
    end
end)

-- ---------------------------------------------------------
--  MODE DESSIN : on pose les coins un par un
-- ---------------------------------------------------------
local drawing = nil

function IsZoneDraw() return drawing ~= nil end
function CancelZoneDraw() drawing = nil end

local function aimPoint()
    local rot = GetGameplayCamRot(2)
    local zr, xr = math.rad(rot.z), math.rad(rot.x)
    local n = math.abs(math.cos(xr))
    local dir = vector3(-math.sin(zr) * n, math.cos(zr) * n, math.sin(xr))
    local from = GetGameplayCamCoord()
    local to = from + dir * 200.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1, PlayerPedId(), 7)
    local _, hit, pos = GetShapeTestResult(ray)
    if hit == 1 then return pos end
    return GetEntityCoords(PlayerPedId())
end

function ZoneDrawKey(id)
    if not drawing then return false end
    if id == 'confirm' then
        local p = drawing.aim
        local tg = drawing.target
        if tg and tg.sharkSpawns then
            local sp, err = SharkSpawnAt(p or GetEntityCoords(PlayerPedId()), tg)
            if not sp then
                PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                return true, Notify(err, 'error')
            end
            if #drawing.points >= Sharks.Cfg.maxSpawnsPerArea then return true, Notify(('%d points maximum par zone.'):format(Sharks.Cfg.maxSpawnsPerArea), 'error') end
            drawing.points[#drawing.points + 1] = sp
            PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            return true
        end
        if p and tg and tg.pvpSpawns then
            -- apparition d'équipe : au sol visé, tournée dans la direction de la caméra
            if #drawing.points >= 20 then return true, Notify('20 apparitions maximum par équipe.', 'error') end
            local z = tg.zone
            if z and #(z.points or {}) >= 3 and (not inPoly(z.points, p.x, p.y) or (z.minZ and p.z + 1.0 < z.minZ) or (z.maxZ and p.z + 1.0 > z.maxZ)) then
                PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                return true, Notify('Ce point est hors de la zone de combat : vise à l\'intérieur.', 'error')
            end
            drawing.points[#drawing.points + 1] = { x = p.x, y = p.y, z = p.z + 1.0, h = (GetGameplayCamRot(2).z + 360.0) % 360.0 }
            PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        elseif p then
            drawing.points[#drawing.points + 1] = { x = p.x, y = p.y, z = p.z }
            PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        end
    elseif id == 'cancel' then
        if #drawing.points > 0 then
            table.remove(drawing.points)
        else
            drawing = nil
            Notify('Dessin de la zone annulé.', 'info')
        end
    elseif id == 'finish' then
        local tg = drawing.target
        if tg and tg.sharkSpawns then
            -- remplace les points d'apparition de la zone ; le serveur revérifie tout (zone, nombre, permission)
            TriggerServerEvent('adminmenu:action', 'sharks_spawns_save', { id = tg.sharkSpawns, points = drawing.points })
            drawing = nil
            return true
        end
        if tg and tg.pvpSpawns then
            if #drawing.points < 1 then return true, Notify('Pose au moins une apparition.', 'error') end
            -- remplace les apparitions de l'équipe ; pvp_arena revérifie tout (zone, nombre, permission)
            TriggerServerEvent('adminmenu:action', 'pvp', { name = 'arena_spawns', data = { id = tg.pvpSpawns, team = tg.team, points = drawing.points } })
            drawing = nil
            return true
        end
        if #drawing.points < 3 then return true, Notify('Pose au moins 3 coins.', 'error') end
        if tg and tg.sharkZone then
            TriggerServerEvent('adminmenu:action', 'sharks_zone_save', { id = tg.sharkZone ~= 0 and tg.sharkZone or nil, name = tg.name, points = drawing.points })
            drawing = nil
            return true
        end
        if tg and tg.pvpZone then
            -- zone de combat d'une arène PvP : coins + sol (coin le plus bas − profondeur) et plafond (coin le plus haut + hauteur)
            local st = drawing.settings or {}
            local lo, hi = math.huge, -math.huge
            for _, q in ipairs(drawing.points) do lo, hi = math.min(lo, q.z), math.max(hi, q.z) end
            TriggerServerEvent('adminmenu:action', 'pvp', { name = 'arena_zone', data = { id = tg.pvpZone, points = drawing.points,
                minZ = lo - (tonumber(st.depth) or 3.0), maxZ = hi + (tonumber(st.height) or 30.0) } })
            drawing = nil
            return true
        end
        if drawing.target and drawing.target.agency then
            -- zone d'alerte d'une agence (elyzea_agences) : ajoutée comme nouvelle forme
            TriggerServerEvent('elyzea_agences:server:worldZone', drawing.target.agency, drawing.points)
        elseif drawing.target and drawing.target.ped then
            -- zone pour parler à un PNJ
            TriggerServerEvent('adminmenu:action', 'editor_npc_area', { id = drawing.target.ped, points = drawing.points })
        else
            TriggerServerEvent('adminmenu:action', 'editor_save_zone', {
                id = drawing.id, shape = 'poly', points = drawing.points, settings = drawing.settings,
            })
        end
        drawing = nil
    end
    return true
end

-- Mode « apparitions d'une équipe » (arène PvP) : zone de l'arène affichée, une flèche par point posé
local TEAMCOL = { A = { 34, 211, 238 }, B = { 249, 115, 98 } }
local function drawPvpSpawns(d, aim)
    local tg = d.target
    local col = TEAMCOL[tg.team] or TEAMCOL.A
    local other = TEAMCOL[tg.team == 'A' and 'B' or 'A']
    local z = tg.zone or {}
    local zp = z.points or {}
    local inside = #zp < 3 or (inPoly(zp, aim.x, aim.y) and not (z.minZ and aim.z + 1.0 < z.minZ) and not (z.maxZ and aim.z + 1.0 > z.maxZ))
    -- contour de la zone de combat
    if #zp >= 3 then
        local z0 = z.minZ or (aim.z - 2.0)
        local z1 = math.min(z.maxZ or (aim.z + 10.0), z0 + 40.0)
        for i = 1, #zp do
            local p, q = zp[i], zp[i % #zp + 1]
            DrawLine(p.x, p.y, z0, q.x, q.y, z0, 34, 211, 238, 255)
            DrawLine(p.x, p.y, z1, q.x, q.y, z1, 34, 211, 238, 200)
            drawWall(p, q, z0, z1, 34, 211, 238, 25)
        end
    end
    -- apparitions de l'autre équipe (repère)
    for _, sp in ipairs(tg.others or {}) do
        DrawMarker(1, sp.x, sp.y, sp.z - 1.0, 0, 0, 0, 0, 0, 0, 0.8, 0.8, 1.0, other[1], other[2], other[3], 110, false, false, 2, false, nil, nil, false)
    end
    -- points posés
    for i, sp in ipairs(d.points) do
        local h = math.rad(sp.h or 0)
        DrawMarker(1, sp.x, sp.y, sp.z - 1.0, 0, 0, 0, 0, 0, 0, 0.9, 0.9, 1.6, col[1], col[2], col[3], 170, false, false, 2, false, nil, nil, false)
        DrawLine(sp.x, sp.y, sp.z - 0.6, sp.x - math.sin(h) * 1.6, sp.y + math.cos(h) * 1.6, sp.z - 0.6, col[1], col[2], col[3], 255)
        DrawText3D(vector3(sp.x, sp.y, sp.z + 1.1), ('%s n°%d'):format(tg.teamName or tg.team, i), 0.32)
    end
    -- curseur : couleur de l'équipe dans la zone, rouge dehors ; flèche = direction de la caméra
    local cr, cg, cb = col[1], col[2], col[3]
    if not inside then cr, cg, cb = 230, 40, 40 end
    local h = math.rad(GetGameplayCamRot(2).z)
    DrawMarker(1, aim.x, aim.y, aim.z, 0, 0, 0, 0, 0, 0, 0.9, 0.9, 0.4, cr, cg, cb, 160, false, false, 2, false, nil, nil, false)
    DrawLine(aim.x, aim.y, aim.z + 0.3, aim.x - math.sin(h) * 2.0, aim.y + math.cos(h) * 2.0, aim.z + 0.3, cr, cg, cb, 255)
    local rows = {
        { keys = { EK('confirm') }, label = inside and 'Poser une apparition ici (tournée comme la caméra)' or 'Hors de la zone : impossible ici' },
        { keys = { EK('cancel') }, label = #d.points > 0 and 'Retirer la dernière' or 'Annuler' },
        { keys = { EK('finish') }, label = 'Enregistrer (remplace les apparitions de l\'équipe)' },
    }
    ShowKeysHud('zonedraw', ('Apparitions %s · %s'):format(tg.teamName or tg.team, tg.name or 'arène'), rows,
        ('%d apparition(s) posée(s) · 1 minimum, 20 maximum · mets-en au moins une par joueur'):format(#d.points))
end

-- Point d'apparition d'un requin : dans la zone, au-dessus d'une eau assez profonde, à C.depth m sous la surface
function SharkSpawnAt(p, tg)
    local C = Sharks.Cfg
    local zp = (tg.zone and tg.zone.points) or {}
    if #zp >= 3 and not Sharks.inPoly(zp, p.x, p.y) then return nil, 'Ce point est hors de la zone des requins : vise à l\'intérieur.' end
    local okW, wz = GetWaterHeightNoWaves(p.x, p.y, p.z + 0.5)
    if not okW then okW, wz = GetWaterHeight(p.x, p.y, p.z + 0.5) end
    if not okW or wz < p.z - 1.5 then return nil, 'Pas d\'eau ici : vise le fond de l\'eau (ou mets-toi dans l\'eau).' end
    -- p est le fond visé (ou ta position si tu nages) : on reste au moins 1 m au-dessus du fond
    local ok, ground = GetGroundZFor_3dCoord(p.x, p.y, wz, false)
    local bottom
    if ok and ground < wz then bottom = ground
    elseif p.z < wz - 0.5 then bottom = p.z           -- fond touché par la visée
    else bottom = wz - 50.0 end                        -- en surface, fond introuvable : eau profonde
    if wz - bottom < C.minWaterDepth then return nil, ('Eau trop peu profonde ici (%.1f m, %.1f m minimum).'):format(wz - bottom, C.minWaterDepth) end
    local z = math.max(bottom + 1.0, wz - C.depth)
    return { x = p.x, y = p.y, z = z, count = 1 }
end

local function drawSharkSpawns(d, aim)
    local tg = d.target
    local zp = (tg.zone and tg.zone.points) or {}
    local okSpot = SharkSpawnAt(aim, tg) ~= nil
    if #zp >= 3 then
        local z0 = aim.z - 1.0
        local okW, wz = GetWaterHeightNoWaves(aim.x, aim.y, aim.z + 0.5)
        if okW then z0 = wz end
        for i = 1, #zp do
            local p, q = zp[i], zp[i % #zp + 1]
            DrawLine(p.x, p.y, z0, q.x, q.y, z0, 239, 68, 68, 255)
            drawWall(p, q, z0 - 3.0, z0 + 3.0, 239, 68, 68, 30)
        end
    end
    for i, sp in ipairs(d.points) do
        DrawMarker(28, sp.x, sp.y, sp.z, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 239, 68, 68, 170, false, false, 2, false, nil, nil, false)
        DrawText3D(vector3(sp.x, sp.y, sp.z + 1.4), ('Requin n°%d (x%d)'):format(i, sp.count or 1), 0.32)
    end
    local cr, cg, cb = 34, 211, 238
    if not okSpot then cr, cg, cb = 230, 40, 40 end
    DrawMarker(1, aim.x, aim.y, aim.z, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 0.5, cr, cg, cb, 160, false, false, 2, false, nil, nil, false)
    local rows = {
        { keys = { EK('confirm') }, label = okSpot and 'Poser un point d\'apparition ici' or 'Impossible ici (hors zone, pas d\'eau ou trop peu profond)' },
        { keys = { EK('cancel') }, label = #d.points > 0 and 'Retirer le dernier' or 'Annuler' },
        { keys = { EK('finish') }, label = 'Enregistrer (remplace les points de la zone)' },
    }
    ShowKeysHud('zonedraw', ('Apparitions des requins · %s'):format(tg.name or 'zone'), rows,
        ('%d point(s) · %d maximum · vise le fond de l\'eau ou place-toi dans l\'eau · le nombre de requins par point se règle dans le menu'):format(#d.points, Sharks.Cfg.maxSpawnsPerArea))
end

local function drawLoop()
    while drawing do
        Wait(0)
        local d = drawing
        if not d then break end -- terminé ou annulé pendant l'attente
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        local aim = aimPoint()
        d.aim = aim
        local r, g, b = rgb((colorById[(d.settings or {}).color] or {}).hex)
        DrawMarker(28, aim.x, aim.y, aim.z, 0, 0, 0, 0, 0, 0, 0.35, 0.35, 0.35, r, g, b, 220, false, false, 2, false, nil, nil, false)

        -- Hauteur / profondeur réglées en direct : ↑ ↓ (hauteur), ← → (profondeur)
        local st = d.settings or {}
        d.settings = st
        local tg = d.target
        if tg and tg.pvpSpawns then drawPvpSpawns(d, aim) goto continue end
        if tg and tg.sharkSpawns then drawSharkSpawns(d, aim) goto continue end
        local hasH = not tg or tg.pvpZone ~= nil   -- zones de l'éditeur et arènes PvP (pas les zones de PNJ / d'agence)
        local hgt = hasH and (tonumber(st.height) or ZC.height) or 5.0
        local dep = hasH and (tonumber(st.depth) or ZC.depth) or 0.5
        if hasH then
            for _, c in ipairs({ 172, 173, 174, 175 }) do DisableControlAction(0, c, true) end
            local step = (IsControlPressed(0, 21) or IsDisabledControlPressed(0, 21)) and 5.0 or 0.5   -- Maj = pas de 5 m
            if IsDisabledControlJustPressed(0, 172) then hgt = math.min(500.0, hgt + step) end
            if IsDisabledControlJustPressed(0, 173) then hgt = math.max(0.5, hgt - step) end
            if IsDisabledControlJustPressed(0, 175) then dep = math.min(200.0, dep + step) end
            if IsDisabledControlJustPressed(0, 174) then dep = math.max(0.0, dep - step) end
            st.height, st.depth = hgt, dep
        end

        local pts = d.points
        local lo, hi = aim.z, aim.z
        for _, p in ipairs(pts) do lo, hi = math.min(lo, p.z), math.max(hi, p.z) end
        local wMin, wMax = lo - dep, hi + hgt
        for i, p in ipairs(pts) do
            DrawMarker(1, p.x, p.y, p.z - 1.0, 0, 0, 0, 0, 0, 0, 0.6, 0.6, 6.0, r, g, b, 200, false, false, 2, false, nil, nil, false)
            DrawText3D(vector3(p.x, p.y, p.z + 1.5), ('Coin %d'):format(i), 0.32)
            local nx = pts[i + 1] or aim
            DrawLine(p.x, p.y, p.z + 0.2, nx.x, nx.y, nx.z + 0.2, r, g, b, 255)
            drawWall(p, nx, wMin, wMax, r, g, b, 50)
            DrawLine(p.x, p.y, wMax, nx.x, nx.y, wMax, r, g, b, 230)
        end
        if #pts >= 2 then
            DrawLine(aim.x, aim.y, aim.z + 0.2, pts[1].x, pts[1].y, pts[1].z + 0.2, r, g, b, 120)
        end

        local rows = {
            { keys = { EK('confirm') }, label = 'Poser un coin ici' },
            { keys = { EK('cancel') }, label = #pts > 0 and 'Retirer le dernier coin' or 'Annuler' },
            { keys = { EK('finish') }, label = 'Terminer la zone' },
        }
        if hasH then
            rows[#rows + 1] = { keys = { '↑', '↓' }, label = ('Hauteur : +%.1f m (Maj = 5 m)'):format(hgt) }
            rows[#rows + 1] = { keys = { '←', '→' }, label = ('Profondeur : -%.1f m'):format(dep) }
        end
        if tg and tg.pvpZone then
            -- apparitions déjà posées : on voit si elles resteront dans la zone
            for t, col in pairs({ A = { 34, 211, 238 }, B = { 249, 115, 98 } }) do
                for _, sp in ipairs((tg.spawns or {})[t] or {}) do
                    DrawMarker(1, sp.x, sp.y, sp.z - 1.0, 0, 0, 0, 0, 0, 0, 0.8, 0.8, 1.2, col[1], col[2], col[3], 140, false, false, 2, false, nil, nil, false)
                end
            end
        end
        ShowKeysHud('zonedraw', tg and (tg.sharkZone and ('Zone des requins : ' .. (tg.name or 'nouvelle zone')) or tg.pvpZone and ('Zone de combat : ' .. (tg.name or 'arène')) or tg.agency and ('Zone d\'alerte : ' .. (tg.name or 'agence')) or 'Zone pour parler au PNJ') or 'Dessiner la zone', rows, ('%d coin(s) posé(s)%s'):format(#pts, #pts < 3 and ' · 3 minimum' or ''))
        ::continue::
    end
    if HudOwner == 'zonedraw' then HideKeysHud() end
end

function StartZoneDraw(id, settings, target)
    if drawing then return end
    if IsPlacing() then return Notify('Termine d\'abord le placement en cours.', 'error') end
    drawing = { id = id, settings = settings, points = {}, target = target }
    if target and target.sharkSpawns and type(target.existing) == 'table' then
        for _, sp in ipairs(target.existing) do drawing.points[#drawing.points + 1] = { x = sp.x, y = sp.y, z = sp.z, count = sp.count or 1 } end
    end
    Notify(target and target.sharkSpawns and 'Vise le fond de l\'eau (ou place-toi dans l\'eau) et pose les points où les requins apparaissent et réapparaissent.'
        or target and target.sharkZone and 'Pose les coins de la zone des requins dans l\'ordre du tour (3 minimum). Les requins ne pourront pas en sortir et n\'attaqueront que les nageurs à l\'intérieur.'
        or target and target.pvpSpawns and ('Vise le sol et pose les apparitions de l\'équipe %s une par une, la caméra donne la direction (le noclip marche aussi).'):format(target.teamName or target.team)
        or target and target.pvpZone and 'Pose les coins de la zone de combat dans l\'ordre du tour (3 minimum). ↑ ↓ règle le plafond, ← → le sol. Les joueurs ne pourront pas en sortir.'
        or target and target.agency and 'Pose les coins de la zone d\'alerte un par un (le noclip marche aussi, vise le sol jusqu\'à 200 m).'
        or target and 'Pose les coins de la zone dans laquelle on pourra parler au PNJ (le noclip marche aussi).'
        or 'Vise le sol et pose les coins de la zone un par un (le noclip marche aussi).', 'info')
    CreateThread(function()
        local ok, err = pcall(drawLoop)
        if not ok then
            print(('^1[AdminMenu] Erreur dessin de zone : %s^7'):format(tostring(err)))
            drawing = nil
            HideKeysHud()
        end
    end)
end

-- Zone d'alerte d'une agence (elyzea_agences › « Dessiner en jeu ») ; le serveur
-- d'elyzea_agences revérifie la permission « agencies_manage »
AddEventHandler('adminmenu:client:drawAgencyZone', function(id, name)
    if not tonumber(id) then return end
    StartZoneDraw(nil, { color = 'blue', name = name }, { agency = tonumber(id), name = name })
end)

-- ---------------------------------------------------------
--  ZONES INSONORISÉES (pma-voice)
--  Chaque joueur décide à qui il ENVOIE sa voix : seulement aux joueurs de la même zone
--  insonorisée (ou à ceux hors de toute zone insonorisée s'il est dehors). Comme tout le monde
--  applique la même règle, dedans on n'entend que ceux de dedans, et dehors on n'entend pas dedans.
--  Les appels téléphoniques et la radio ne sont pas concernés.
-- ---------------------------------------------------------
local voiceZones = {}
local voiceHooked = false
local myVZ, myVZAt = 0, 0

local function voiceZoneAt(p)
    for i = 1, #voiceZones do
        local z = voiceZones[i]
        if inZone(z, p) then return z.id end
    end
    return 0
end

local function proximityCheck(ply)
    local me = GetEntityCoords(PlayerPedId())
    local tp = GetEntityCoords(GetPlayerPed(ply))
    local range = MumbleGetTalkerProximity()
    if GetConvar('voice_useNativeAudio', 'false') == 'true' then range = range * 3 end
    local d = #(me - tp)
    if d >= range then return false, d end
    if #voiceZones == 0 then return true, d end
    local now = GetGameTimer()
    if now - myVZAt > 150 then myVZ, myVZAt = voiceZoneAt(me), now end
    return voiceZoneAt(tp) == myVZ, d
end

local function hookVoice()
    if GetResourceState('pma-voice') ~= 'started' then voiceHooked = false return end
    if #voiceZones > 0 then
        local ok, err = pcall(function() exports['pma-voice']:overrideProximityCheck(proximityCheck) end)
        if not ok then print(('^3[AdminMenu] Zones insonorisées : pma-voice trop ancien (overrideProximityCheck absent) : %s^7'):format(tostring(err))) end
        voiceHooked = ok
    elseif voiceHooked then
        pcall(function() exports['pma-voice']:resetProximityCheck() end)
        voiceHooked = false
    end
end

function RefreshVoiceZones()
    local list = {}
    for _, z in ipairs(Editor.zones or {}) do if z.soundproof then list[#list + 1] = z end end
    voiceZones = list
    myVZAt = 0
    hookVoice()
end

AddEventHandler('onClientResourceStart', function(res)
    if res == 'pma-voice' then SetTimeout(1000, hookVoice) end
end)

-- Indicateur pour le joueur (et export pour d'autres ressources)
exports('IsInSoundproofZone', function() return voiceZoneAt(GetEntityCoords(PlayerPedId())) ~= 0 end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if voiceHooked then pcall(function() exports['pma-voice']:resetProximityCheck() end) end
    for _, b in ipairs(zoneBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    if wasInvincible and not State.godmode then SetEntityInvincible(PlayerPedId(), false) end
    SetPlayerCanDoDriveBy(PlayerId(), true)
end)
