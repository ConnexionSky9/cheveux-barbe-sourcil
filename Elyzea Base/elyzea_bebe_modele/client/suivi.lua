-- =====================================================================
--  ELYZEA BÉBÉ (modèle) - client : attache qui suit le buste (audit V9)
--  Utilisé par client/portage.lua (bébé porté, porte-bébés). Testé hors jeu : tests/test_suivi.lua
-- =====================================================================
local P = Config.Portage
-- ─────────── Suivi du buste (audit V9) ───────────
-- Avant : le bébé et les porte-bébés étaient attachés au REPÈRE GLOBAL du personnage (le bassin). Le buste bouge
-- (marche, respiration, animation des bras) mais pas ce repère : le bébé restait figé, flottait devant les bras ou
-- les traversait. Maintenant : on le place d'abord exactement comme avant (position validée sur le mannequin), puis
-- on recalcule cette même position par rapport à l'os du haut du buste (SKEL_Spine3) et on l'y attache : il suit
-- le torse et les bras. La convention d'angles de GTA est vérifiée en jeu (mesure de la position obtenue) une seule
-- fois puis mémorisée (KVP) ; si la mesure échoue, l'ancienne attache est gardée (aucune régression).
local OS_BUSTE = (P.suiviBuste and P.suiviBuste.os) or 24818
local SUIVI = not (P.suiviBuste and P.suiviBuste.actif == false)
local KVP_CONV = 'bebe_suivi_convention'
local convention = GetResourceKvpInt(KVP_CONV)   -- 0 = pas encore mesurée, 1..12 sinon
local PERMS = { { 1, 2, 3 }, { 2, 3, 1 }, { 3, 1, 2 }, { 1, 3, 2 }, { 3, 2, 1 }, { 2, 1, 3 } }

local function matrice(e)
    local r, f, u, p = GetEntityMatrix(e)
    -- M[ligne][colonne] : colonnes = axes droite, avant, haut de l'entité exprimés dans le monde
    return { { r.x, f.x, u.x }, { r.y, f.y, u.y }, { r.z, f.z, u.z } }, p
end

-- Repère de l'os du buste : petit objet LOCAL (invisible, sans collision) attaché à l'os sans décalage
local AIDE = joaat('prop_golf_ball')
local function repereOs(ped, os)
    RequestModel(AIDE)
    local t = GetGameTimer() + 2000
    while not HasModelLoaded(AIDE) and GetGameTimer() < t do Wait(0) end
    if not HasModelLoaded(AIDE) then return nil end
    local c = GetEntityCoords(ped)
    local o = CreateObjectNoOffset(AIDE, c.x, c.y, c.z - 5.0, false, false, false)
    SetModelAsNoLongerNeeded(AIDE)
    if not o or o == 0 then return nil end
    SetEntityVisible(o, false, false)
    SetEntityCollision(o, false, false)
    AttachEntityToEntity(o, ped, GetPedBoneIndex(ped, os), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    Wait(0)
    local B, pb = matrice(o)
    DeleteEntity(o)
    return B, pb
end

-- Angles (degrés) de la matrice R pour l'ordre d'axes perm (R = Ri(a)·Rj(b)·Rk(c)), signe s
local function euler(R, perm, sgn)
    local i, j, k = perm[1], perm[2], perm[3]
    local e = ((j - i + 3) % 3 == 1) and 1 or -1                       -- permutation paire (xyz, yzx, zxy) : +1
    local sb = math.max(-1.0, math.min(1.0, e * R[i][k]))
    local b = math.asin(sb)
    local a = math.atan(-e * R[j][k], R[k][k])
    local c = math.atan(-e * R[i][j], R[i][i])
    local out = { 0.0, 0.0, 0.0 }
    out[i], out[j], out[k] = math.deg(a) * sgn, math.deg(b) * sgn, math.deg(c) * sgn
    return out
end
local function candidat(L, n)   -- n = 1..12 : 6 ordres × 2 signes
    return euler(L, PERMS[(n - 1) % 6 + 1], n > 6 and -1 or 1)
end

local function ecart(e, Wref, pref)
    local W, p = matrice(e)
    local d = #(p - pref)
    for r = 1, 3 do for c = 1, 3 do d = d + math.abs(W[r][c] - Wref[r][c]) * 0.25 end end
    return d
end

-- Attache e au personnage à (pos, rot) dans le repère du personnage, puis au buste s'il le faut
local enCours = {}
local function attacherSuivi(e, ped, pos, rot, suivre)
    AttachEntityToEntity(e, ped, 0, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, false, false, false, false, 2, true)
    if not SUIVI or not suivre then return end
    local jeton = {}
    enCours[e] = jeton
    CreateThread(function()
        Wait(650)                                       -- animation de portage installée (pose stable du buste)
        if enCours[e] ~= jeton or not DoesEntityExist(e) or not IsEntityAttachedToEntity(e, ped) then return end
        local Wref, pref = matrice(e)
        local B, pb = repereOs(ped, OS_BUSTE)
        if not B or enCours[e] ~= jeton then return end
        -- L = Bᵀ·W (orientation dans le repère de l'os), position locale = Bᵀ·(p - pOs)
        local L = { {}, {}, {} }
        for r = 1, 3 do for c = 1, 3 do
            L[r][c] = B[1][r] * Wref[1][c] + B[2][r] * Wref[2][c] + B[3][r] * Wref[3][c]
        end end
        local d = pref - pb
        local lp = vector3(B[1][1] * d.x + B[2][1] * d.y + B[3][1] * d.z, B[1][2] * d.x + B[2][2] * d.y + B[3][2] * d.z,
            B[1][3] * d.x + B[2][3] * d.y + B[3][3] * d.z)
        local bone = GetPedBoneIndex(ped, OS_BUSTE)
        local essais = convention > 0 and { convention } or { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }
        local best, bestE
        for _, n in ipairs(essais) do
            if enCours[e] ~= jeton then return end
            local a = candidat(L, n)
            AttachEntityToEntity(e, ped, bone, lp.x, lp.y, lp.z, a[1], a[2], a[3], false, false, false, false, 2, true)
            Wait(0)
            local er = ecart(e, Wref, pref)
            if not bestE or er < bestE then best, bestE = n, er end
        end
        if bestE and bestE > 0.12 and convention > 0 then
            -- convention mémorisée qui ne colle plus (mise à jour du jeu ?) : nouvelle mesure complète
            SetResourceKvpInt(KVP_CONV, 0)
            convention = 0
            return attacherSuivi(e, ped, pos, rot, suivre)
        end
        if enCours[e] ~= jeton then return end
        if bestE and bestE <= 0.12 then
            local a = candidat(L, best)
            AttachEntityToEntity(e, ped, bone, lp.x, lp.y, lp.z, a[1], a[2], a[3], false, false, false, false, 2, true)
            if convention ~= best then convention = best SetResourceKvpInt(KVP_CONV, best) end
            if Config.Debug then print(('[elyzea_bebe_modele] suivi du buste : convention %d, écart %.3f'):format(best, bestE)) end
        else
            -- mesure impossible : attache d'origine (repère du personnage)
            AttachEntityToEntity(e, ped, 0, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, false, false, false, false, 2, true)
            print(('[elyzea_bebe_modele] suivi du buste indisponible (écart %.2f) : attache classique gardée'):format(bestE or -1))
        end
    end)
end

BebeAttacherSuivi = attacherSuivi
BebeSuivi = { euler = euler, candidat = candidat, matrice = matrice }
