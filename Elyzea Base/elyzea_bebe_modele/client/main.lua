-- =====================================================================
--  ELYZEA BÉBÉ (modèle) - client : affichage du bébé
--  Un bébé affiché = 3 objets de la même pose (corps, yeux, cheveux) qui partagent la même
--  origine : les yeux et les cheveux s'attachent au corps sans aucun décalage.
--
--  Exports (pour les ressources famille / crèche / poussette) :
--    local b = exports.elyzea_bebe_modele:Creer(pose, apparence, coords, cap, reseau)
--        apparence = { teinte = 'peau1'..'peau6', yeux = 'bleu'…, coiffure = 'duvet_brun'… ou 'chauve' }
--    exports.elyzea_bebe_modele:Supprimer(b)
--    exports.elyzea_bebe_modele:Attacher(b, entite, os, pos, rot)
--    exports.elyzea_bebe_modele:Porter(b, ped, preset)   preset = 'porte' | 'ventral'
--    exports.elyzea_bebe_modele:Poses()  -> liste des poses disponibles
--  Le serveur reste maître de l'identité et de l'emplacement de l'enfant : ce fichier n'affiche que le modèle.
-- =====================================================================
local M = BebeModeles
local tests = {}          -- bébés créés par les commandes de test
local porte = nil         -- bébé de test porté par le joueur { bebe, preset, pos, rot }

local function Notify(msg, kind) pcall(function() exports.elyzea_core:Notify(msg, kind or 'inform') end) end

local function LoadModel(name)
    local hash = joaat(name)
    if not IsModelInCdimage(hash) then return nil, ('modèle absent du jeu : %s'):format(name) end
    RequestModel(hash)
    local t = GetGameTimer() + 10000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > t then return nil, ('chargement trop long : %s'):format(name) end
        Wait(0)
    end
    return hash
end

local function pick(list, value, default)
    if value and list[value] then return value end
    return default
end

-- Crée les objets d'un bébé. Renvoie { corps, yeux, cheveux, pose } ou nil, erreur
local function Creer(pose, apparence, coords, cap, reseau)
    local P = M.poses[pose or '']
    if not P then return nil, ('pose inconnue : %s'):format(tostring(pose)) end
    apparence = apparence or {}
    local teinte = pick(P.corps, apparence.teinte, Config.Defaut.teinte)
    local yeux = pick(P.yeux, apparence.yeux, Config.Defaut.yeux)
    local coiffure = apparence.coiffure == 'chauve' and 'chauve' or pick(P.cheveux, apparence.coiffure, Config.Defaut.coiffure)

    local noms = { corps = P.corps[teinte], yeux = P.yeux[yeux] }
    if coiffure ~= 'chauve' then noms.cheveux = P.cheveux[coiffure] end

    local hashes = {}
    for k, n in pairs(noms) do
        local h, err = LoadModel(n)
        if not h then return nil, err end
        hashes[k] = h
    end

    coords = coords or GetEntityCoords(PlayerPedId())
    local b = { pose = pose, apparence = { teinte = teinte, yeux = yeux, coiffure = coiffure } }
    b.corps = CreateObjectNoOffset(hashes.corps, coords.x, coords.y, coords.z, reseau == true, false, false)
    SetEntityHeading(b.corps, cap or 0.0)
    SetEntityCollision(b.corps, false, false)
    FreezeEntityPosition(b.corps, true)
    for _, k in ipairs({ 'yeux', 'cheveux' }) do
        if hashes[k] then
            local o = CreateObjectNoOffset(hashes[k], coords.x, coords.y, coords.z, reseau == true, false, false)
            SetEntityCollision(o, false, false)
            AttachEntityToEntity(o, b.corps, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
            b[k] = o
        end
    end
    for _, h in pairs(hashes) do SetModelAsNoLongerNeeded(h) end
    return b
end

local function Supprimer(b)
    if not b then return end
    for _, k in ipairs({ 'cheveux', 'yeux', 'corps' }) do
        if b[k] and DoesEntityExist(b[k]) then
            DetachEntity(b[k], false, false)
            DeleteEntity(b[k])
        end
        b[k] = nil
    end
end

local function Attacher(b, entite, os, pos, rot)
    if not b or not b.corps then return false end
    FreezeEntityPosition(b.corps, false)
    local idx = os and os > 0 and GetPedBoneIndex(entite, os) or 0
    AttachEntityToEntity(b.corps, entite, idx, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, false, false, false, false, 2, true)
    return true
end

local function JouerAnim(ped, anim)
    if not anim then return end
    RequestAnimDict(anim.dict)
    local t = GetGameTimer() + 5000
    while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < t do Wait(0) end
    if HasAnimDictLoaded(anim.dict) then
        TaskPlayAnim(ped, anim.dict, anim.clip, 3.0, 3.0, -1, anim.flag or 49, 0.0, false, false, false)
    end
end

local function Porter(b, ped, preset)
    local c = Config.Porter[preset or b.pose]
    if not c then return false end
    Attacher(b, ped, 0, c.pos, c.rot)
    JouerAnim(ped, c.anim)
    return true
end

exports('Creer', Creer)
exports('Supprimer', Supprimer)
exports('Attacher', Attacher)
exports('Porter', Porter)
exports('Poses', function()
    local out = {}
    for k, p in pairs(M.poses) do out[#out + 1] = { id = k, label = p.label } end
    return out
end)

-- ─────────── Commandes de test (ordre envoyé par le serveur après vérification de la permission) ───────────

local function ViderTests()
    for _, b in ipairs(tests) do Supprimer(b) end
    tests = {}
    if porte then
        ClearPedTasks(PlayerPedId())
        porte = nil
    end
end

local function DevantMoi(dist)
    local ped = PlayerPedId()
    local c = GetOffsetFromEntityInWorldCoords(ped, 0.0, dist or 1.2, 0.0)
    local ok, z = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)
    return vector3(c.x, c.y, ok and z or (c.z - 0.95)), GetEntityHeading(ped)
end

RegisterNetEvent('elyzea_bebe_modele:test', function(action, args)
    args = args or {}
    if action == 'retirer' then
        ViderTests()
        return Notify('Bébés de test retirés.', 'success')
    end

    if action == 'galerie' then
        ViderTests()
        local pose = M.poses[args[1] or ''] and args[1] or 'allonge'
        local base, cap = DevantMoi(1.5)
        local ped = PlayerPedId()
        for i, teinte in ipairs(M.teintes) do
            local off = GetOffsetFromEntityInWorldCoords(ped, (i - 3.5) * 0.45, 1.5, 0.0)
            local b, err = Creer(pose, { teinte = teinte, yeux = M.yeux[((i - 1) % #M.yeux) + 1], coiffure = M.coiffures[i] }, vector3(off.x, off.y, base.z), cap + 180.0)
            if not b then return Notify(err, 'error') end
            tests[#tests + 1] = b
        end
        return Notify(('Galerie : pose « %s », 6 teintes de peau.'):format(pose), 'success')
    end

    if action == 'ajuster' then
        if not porte then return Notify('Porte d\'abord un bébé : /bebe_test porte', 'error') end
        local v = {}
        for i = 1, 6 do v[i] = tonumber(args[i]) end
        if not v[1] then
            return Notify(('Actuel : pos %.3f %.3f %.3f · rot %.1f %.1f %.1f'):format(porte.pos.x, porte.pos.y, porte.pos.z, porte.rot.x, porte.rot.y, porte.rot.z), 'inform')
        end
        porte.pos = vector3(v[1] or porte.pos.x, v[2] or porte.pos.y, v[3] or porte.pos.z)
        porte.rot = vector3(v[4] or porte.rot.x, v[5] or porte.rot.y, v[6] or porte.rot.z)
        Attacher(porte.bebe, PlayerPedId(), 0, porte.pos, porte.rot)
        local line = ('pos = vector3(%.3f, %.3f, %.3f), rot = vector3(%.1f, %.1f, %.1f),'):format(
            porte.pos.x, porte.pos.y, porte.pos.z, porte.rot.x, porte.rot.y, porte.rot.z)
        print(('[elyzea_bebe_modele] Config.Porter.%s : %s'):format(porte.preset, line))
        return Notify('Nouvelles valeurs dans la console F8 (à recopier dans config.lua).', 'success')
    end

    -- test : /bebe_test [pose] [teinte] [yeux] [coiffure|chauve]
    ViderTests()
    local pose = args[1] or 'porte'
    if not M.poses[pose] then return Notify('Poses : allonge, porte, assis, ventral', 'error') end
    local apparence = { teinte = args[2], yeux = args[3], coiffure = args[4] }
    local ped = PlayerPedId()
    local coords, cap = DevantMoi(1.2)
    local b, err = Creer(pose, apparence, coords, cap + 180.0)
    if not b then return Notify(err, 'error') end
    tests[#tests + 1] = b
    if Config.Porter[pose] then
        Porter(b, ped, pose)
        local c = Config.Porter[pose]
        porte = { bebe = b, preset = pose, pos = c.pos, rot = c.rot }
    end
    Notify(('Bébé de test : %s · %s · yeux %s · %s'):format(pose, b.apparence.teinte, b.apparence.yeux, b.apparence.coiffure), 'success')
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then ViderTests() end
end)
