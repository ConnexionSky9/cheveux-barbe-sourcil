-- =========================================================
--  ELYZEA ANIMAUX - CLIENT : harnais et laisse visibles
--  Aucun modèle 3D de harnais n'existe dans GTA V : les sangles sont
--  dessinées chaque image autour du corps de l'animal, à partir de ses
--  os (encolure, poitrail, ventre). Elles suivent donc la posture
--  (assis, couché, en marche). La laisse relie la main du propriétaire
--  au collier ou à l'anneau du harnais, avec un mou qui dépend de la
--  distance : elle ne peut pas « flotter » ni se détacher visuellement.
--  Tout est dessiné localement par chaque joueur (rien à supprimer à
--  la déconnexion), d'après la liste des animaux envoyée par le serveur.
--  Limite : les sangles et la laisse ne gèrent pas les collisions
--  (la laisse peut traverser un poteau).
-- =========================================================
local RANGE = 35.0
local SEG = 12

local styles, colors = {}, {}
for _, s in ipairs(Config.HarnessStyles) do styles[s.id] = s end
for _, c in ipairs(Config.HarnessColors) do colors[c.id] = c end

local function norm(v)
    local l = #v
    return l > 0.0001 and v / l or vector3(0.0, 0.0, 1.0)
end
local function cross(a, b) return vector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x) end

local function tri(a, b, c, r, g, bl, al)
    DrawPoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, r, g, bl, al)
    DrawPoly(c.x, c.y, c.z, b.x, b.y, b.z, a.x, a.y, a.z, r, g, bl, al)
end
local function quad(a, b, c, d, col)
    tri(a, b, c, col[1], col[2], col[3], col[4] or 255)
    tri(a, c, d, col[1], col[2], col[3], col[4] or 255)
end

local function bone(ped, name)
    local i = GetEntityBoneIndexByName(ped, name)
    if i == -1 then return nil end
    return GetWorldPositionOfEntityBone(ped, i)
end

-- Repère du corps de l'animal : axe (arrière -> avant), haut, droite
local function frame(ped)
    local neck = bone(ped, 'SKEL_Neck_1') or bone(ped, 'SKEL_Head')
    local chest = bone(ped, 'SKEL_Spine3') or bone(ped, 'SKEL_Spine2')
    local belly = bone(ped, 'SKEL_Spine1') or bone(ped, 'SKEL_Spine0')
    local _, fwdE, upE, pos = GetEntityMatrix(ped)
    if not neck or not chest then
        local min, max = GetModelDimensions(GetEntityModel(ped))
        local h = (max.z - min.z)
        neck = GetOffsetFromEntityInWorldCoords(ped, 0.0, max.y * 0.55, h * 0.25)
        chest = GetOffsetFromEntityInWorldCoords(ped, 0.0, max.y * 0.3, h * 0.15)
        belly = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.0, h * 0.12)
    end
    belly = belly or (chest - norm(neck - chest) * 0.2)
    local axis = norm(neck - belly)
    local right = norm(cross(axis, upE))
    local up = norm(cross(right, axis))
    return { neck = neck, chest = chest, belly = belly, axis = axis, up = up, right = right, pos = pos, fwd = fwdE }
end

-- Point du cercle de rayon r autour de centre (plan perpendiculaire à l'axe)
local function ringPoint(f, center, r, a) return center + f.right * (math.cos(a) * r) + f.up * (math.sin(a) * r) end

local function band(f, center, r, width, col)
    local half = f.axis * (width / 2)
    for i = 0, SEG - 1 do
        local a1, a2 = (i / SEG) * math.pi * 2, ((i + 1) / SEG) * math.pi * 2
        local p1, p2 = ringPoint(f, center, r, a1), ringPoint(f, center, r, a2)
        quad(p1 - half, p2 - half, p2 + half, p1 + half, col)
    end
end

-- Centre du corps : les os de la colonne sont sur le dos, le tronc est en dessous
local function centers(f, info)
    local r, n = info.radius or 0.15, info.neck or 0.1
    return {
        neck = { c = f.neck - f.up * (n * 0.55), r = n },
        chest = { c = f.chest - f.up * (r * 0.6), r = r },
        belly = { c = f.belly - f.up * (r * 0.55), r = r * 0.92 },
    }
end

local function drawHarness(ped, info, f, cs)
    local h = info.harness
    local s, c = styles[h.style], colors[h.color]
    if not s or not c then return nil end
    local col = { c.rgb[1], c.rgb[2], c.rgb[3], 255 }
    for _, b in ipairs(s.bands) do
        local z = cs[b.at]
        if z then band(f, z.c, z.r * 1.04, b.width, col) end
    end
    local ring = cs.chest.c + f.up * (cs.chest.r * 1.06)
    if s.back then
        local from = cs.neck.c + f.up * (cs.neck.r * 1.04)
        local to = (cs.belly.c + f.up * (cs.belly.r * 1.04))
        local w = f.right * 0.018
        quad(from - w, from + w, to + w, to - w, col)
    end
    -- anneau métallique où s'accroche la laisse
    band(f, ring + f.up * 0.012, 0.018, 0.012, { 180, 180, 185, 255 })
    return ring + f.up * 0.02
end

local function collar(f, cs)
    local z = cs.neck
    band(f, z.c, z.r * 1.05, 0.028, { 40, 30, 24, 255 })
    return z.c + f.up * (z.r * 1.05) + f.axis * 0.01
end

-- Laisse : courbe avec mou (plus le chien est près, plus elle pend)
local function drawLeash(hand, clip)
    local col = Config.LeashColor
    local d = #(clip - hand)
    local length = (C.World.settings and C.World.settings.leash and C.World.settings.leash.length) or 2.6
    local sag = math.max(0.03, math.min(1.1, (length - d) * 0.45))
    local cam = GetFinalRenderedCamCoord()
    local prev = hand
    local N = 14
    for i = 1, N do
        local t = i / N
        local p = hand + (clip - hand) * t - vector3(0.0, 0.0, 4.0 * sag * t * (1.0 - t))
        local dir = norm(p - prev)
        local side = norm(cross(dir, norm(cam - p))) * 0.007
        quad(prev - side, prev + side, p + side, p - side, col)
        prev = p
    end
end

local function ownerHand(serverId)
    local pl = GetPlayerFromServerId(serverId)
    if pl == -1 then return nil end
    local ped = GetPlayerPed(pl)
    if not ped or ped == 0 or not DoesEntityExist(ped) or IsPedInAnyVehicle(ped, false) then return nil end
    local i = GetPedBoneIndex(ped, 18905)   -- main gauche
    return GetWorldPositionOfEntityBone(ped, i)
end

CreateThread(function()
    while true do
        local drawn = false
        local me = GetEntityCoords(PlayerPedId())
        for netKey, info in pairs(C.Active) do
            if info.harness or info.leash then
                local netId = tonumber(netKey)
                if netId and NetworkDoesNetworkIdExist(netId) then
                    local ped = NetToPed(netId)
                    if ped ~= 0 and DoesEntityExist(ped) and IsEntityVisible(ped) and #(GetEntityCoords(ped) - me) < RANGE and (info.leash or IsEntityOnScreen(ped)) then
                        drawn = true
                        local f = frame(ped)
                        local cs = centers(f, info)
                        local clip = info.harness and drawHarness(ped, info, f, cs) or nil
                        if info.leash then
                            if not clip then clip = collar(f, cs) end
                            local hand = ownerHand(info.owner)
                            if hand then drawLeash(hand, clip) end
                        end
                    end
                end
            end
        end
        Wait(drawn and 0 or 500)
    end
end)
