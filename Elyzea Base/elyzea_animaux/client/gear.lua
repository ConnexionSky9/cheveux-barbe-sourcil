-- =========================================================
--  ELYZEA ANIMAUX - CLIENT : harnais et laisse visibles
--  GTA V n'a aucun modèle 3D de harnais pour chien. Le harnais est dessiné
--  chaque image, MESURÉ sur le squelette réel de l'animal (shared/harness_geom.lua) :
--  repère du torse (hanches -> épaules, épaule gauche -> droite), largeur du
--  poitrail (écart des épaules), hauteur (dos -> coudes). Il suit donc la posture
--  (debout, assis, couché, marche, course) sans traverser le corps mesuré.
--  Ajustement par race en jeu : /harnais_reglage (staff), affichage des os : /harnais_os.
--  Tout est local à chaque joueur (rien à supprimer à la déconnexion), d'après
--  la liste des animaux envoyée par le serveur.
--  Limite : pas de collision avec le décor (la laisse peut traverser un poteau).
-- =========================================================
local RANGE = 35.0

local styles, colors = {}, {}
for _, s in ipairs(Config.HarnessStyles) do styles[s.id] = s end
for _, c in ipairs(Config.HarnessColors) do colors[c.id] = c end

-- Os utilisés : nom, puis identifiant (tag) en secours, puis noms alternatifs
local BONES = {
    neck   = { 'SKEL_Neck_1', 39317, 'SKEL_Neck0' },
    head   = { 'SKEL_Head', 31086 },
    spine3 = { 'SKEL_Spine3', 24818 },
    spine2 = { 'SKEL_Spine2', 24817 },
    lua    = { 'SKEL_L_UpperArm', 45509, 'SKEL_L_Clavicle' },
    rua    = { 'SKEL_R_UpperArm', 40269, 'SKEL_R_Clavicle' },
    lfa    = { 'SKEL_L_Forearm', 61163 },
    rfa    = { 'SKEL_R_Forearm', 28252 },
    lth    = { 'SKEL_L_Thigh', 58271 },
    rth    = { 'SKEL_R_Thigh', 51826 },
}
C.HarnessBones = BONES

-- Index des os par modèle (calculé une fois)
local boneCache = {}
local function boneIndices(ped)
    local model = GetEntityModel(ped)
    local c = boneCache[model]
    if c then return c end
    c = {}
    local root = GetPedBoneIndex(ped, 0)
    for key, list in pairs(BONES) do
        local found
        for i, ref in ipairs(list) do
            if type(ref) == 'string' then
                local idx = GetEntityBoneIndexByName(ped, ref)
                if idx and idx ~= -1 then found = { idx = idx, name = ref } break end
            else
                local idx = GetPedBoneIndex(ped, ref)
                if idx and idx ~= -1 and idx ~= root then found = { idx = idx, name = list[1] .. ' (tag)' } break end
            end
        end
        c[key] = found
    end
    boneCache[model] = c
    return c
end
C.BoneIndices = boneIndices

-- Nom du modèle (pour les réglages par race)
local modelNames = {}
for _, sp in pairs(Config.Species) do
    modelNames[joaat(sp.model)] = sp.model
    for _, v in ipairs(sp.variants or {}) do if v.model then modelNames[joaat(v.model)] = v.model end end
end
function C.ModelName(ped) return modelNames[GetEntityModel(ped)] end

function C.HarnessFitFor(ped)
    local name = C.ModelName(ped)
    local live = C.FitEdit and C.FitEdit.ped == ped and C.FitEdit.fit or nil
    return live or (name and ((C.World.fit or {})[name] or Config.HarnessFit[name])) or nil
end

local function bonesOf(ped)
    local idx = boneIndices(ped)
    local b = {}
    for key, info in pairs(idx) do
        local p = GetWorldPositionOfEntityBone(ped, info.idx)
        b[key] = { x = p.x, y = p.y, z = p.z }
    end
    local _, _, up = GetEntityMatrix(ped)
    b.up = { x = up.x, y = up.y, z = up.z }
    return b
end
C.BonesOf = bonesOf

local function drawQuads(list)
    for i = 1, #list do
        local q = list[i]
        local a, b, c, d, col = q[1], q[2], q[3], q[4], q[5]
        local r, g, bl, al = col[1], col[2], col[3], col[4] or 255
        DrawPoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, r, g, bl, al)
        DrawPoly(c.x, c.y, c.z, b.x, b.y, b.z, a.x, a.y, a.z, r, g, bl, al)
        DrawPoly(a.x, a.y, a.z, c.x, c.y, c.z, d.x, d.y, d.z, r, g, bl, al)
        DrawPoly(d.x, d.y, d.z, c.x, c.y, c.z, a.x, a.y, a.z, r, g, bl, al)
    end
end

local warned = {}
local function harnessFor(ped, info)
    local h = info.harness
    local s, c = styles[h.style], colors[h.color]
    if not s or not c then return nil end
    local res = HarnessGeom.Build(bonesOf(ped), C.HarnessFitFor(ped), s, c.rgb)
    if not res then
        local m = C.ModelName(ped) or tostring(GetEntityModel(ped))
        if not warned[m] then warned[m] = true C.Issue('harness', ('Squelette non reconnu pour le harnais : %s (harnais non dessiné)'):format(m)) end
    end
    return res
end

-- Laisse : courbe avec mou (plus l'animal est près, plus elle pend)
local function norm(v) local l = #v return l > 0.0001 and v / l or vector3(0.0, 0.0, 1.0) end
local function cross(a, b) return vector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x) end
local function drawLeash(hand, clip)
    local col = Config.LeashColor
    local d = #(clip - hand)
    local length = (C.World.settings and C.World.settings.leash and C.World.settings.leash.length) or 2.6
    local sag = math.max(0.03, math.min(1.1, (length - d) * 0.45))
    local cam = GetFinalRenderedCamCoord()
    local prev, N, out = hand, 14, {}
    for i = 1, N do
        local t = i / N
        local p = hand + (clip - hand) * t - vector3(0.0, 0.0, 4.0 * sag * t * (1.0 - t))
        local side = norm(cross(norm(p - prev), norm(cam - p))) * 0.007
        out[#out + 1] = { prev - side, prev + side, p + side, p - side, col }
        prev = p
    end
    -- mousqueton au bout
    out[#out + 1] = { clip + vector3(-0.008, 0.0, -0.018), clip + vector3(0.008, 0.0, -0.018), clip + vector3(0.008, 0.0, 0.018), clip + vector3(-0.008, 0.0, 0.018), { 170, 170, 176, 255 } }
    drawQuads(out)
end

local function ownerHand(serverId)
    local pl = GetPlayerFromServerId(serverId)
    if pl == -1 then return nil end
    local ped = GetPlayerPed(pl)
    if not ped or ped == 0 or not DoesEntityExist(ped) or IsPedInAnyVehicle(ped, false) then return nil end
    return GetWorldPositionOfEntityBone(ped, GetPedBoneIndex(ped, 18905))   -- main gauche
end

-- Point d'accroche sans harnais : collier dessiné à l'encolure (ou l'os du cou, ou devant l'animal)
local function collarClip(ped)
    local res = HarnessGeom.Collar(bonesOf(ped), C.HarnessFitFor(ped))
    if res then drawQuads(res.quads) return res.clip and vector3(res.clip.x, res.clip.y, res.clip.z) end
    local idx = boneIndices(ped).neck
    if idx then return GetWorldPositionOfEntityBone(ped, idx.idx) end
    return GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.35, 0.25)
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
                        local clip
                        if info.harness then
                            local res = harnessFor(ped, info)
                            if res then
                                drawQuads(res.quads)
                                if res.clip then clip = vector3(res.clip.x, res.clip.y, res.clip.z) end
                            end
                        end
                        if info.leash then
                            clip = clip or collarClip(ped)
                            local hand = ownerHand(info.owner)
                            if hand then drawLeash(hand, clip) end
                        end
                    end
                end
            end
        end
        if C.FitEdit or C.ShowBones then drawn = true end
        Wait(drawn and 0 or 500)
    end
end)

-- ---------------------------------------------------------
--  /harnais_os : affiche les os trouvés sur son animal (diagnostic)
-- ---------------------------------------------------------
local function text3d(p, s)
    local ok, x, y = GetScreenCoordFromWorldCoord(p.x, p.y, p.z)
    if not ok then return end
    SetTextScale(0.0, 0.25)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 230)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(s)
    EndTextCommandDisplayText(x, y)
end

RegisterCommand('harnais_os', function()
    C.ShowBones = not C.ShowBones
    C.Notify(C.ShowBones and 'Os de ton animal affichés (/harnais_os pour cacher).' or 'Affichage des os coupé.', 'inform')
    if not C.ShowBones then return end
    CreateThread(function()
        while C.ShowBones do
            local id = C.NearestMine(8.0)
            local m = id and C.Mine[id]
            if m and DoesEntityExist(m.ped) then
                local idx = boneIndices(m.ped)
                for key in pairs(BONES) do
                    local info = idx[key]
                    if info then
                        local p = GetWorldPositionOfEntityBone(m.ped, info.idx)
                        DrawMarker(28, p.x, p.y, p.z, 0, 0, 0, 0, 0, 0, 0.02, 0.02, 0.02, 80, 220, 120, 220, false, false, 2, false, nil, nil, false)
                        text3d(p, key)
                    end
                end
                local missing = {}
                for key in pairs(BONES) do if not idx[key] then missing[#missing + 1] = key end end
                if #missing > 0 then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('Os manquants : ' .. table.concat(missing, ', '))
                    EndTextCommandDisplayHelp(0, false, false, -1)
                end
            end
            Wait(0)
        end
    end)
end, false)
