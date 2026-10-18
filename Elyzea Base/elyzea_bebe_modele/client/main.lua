-- =====================================================================
--  ELYZEA BÉBÉ (modèle) - client : APERÇUS LOCAUX (staff) et fonctions d'affichage
--  Ce fichier ne crée que des objets locaux (visibles par ce joueur seulement), pour contrôler les
--  variantes. Le bébé « réel », visible par tous et portable : client/portage.lua + server/bebes.lua.
--
--  Exports client :
--    local b = exports.elyzea_bebe_modele:Creer(pose, apparence, coords, cap)   -- aperçu local
--    exports.elyzea_bebe_modele:Supprimer(b)
--    exports.elyzea_bebe_modele:Poses()
-- =====================================================================
local M = BebeModeles
local tests = {}

function BebeNotify(msg, kind) pcall(function() exports.elyzea_core:Notify(msg, kind or 'inform') end) end
local Notify = BebeNotify

function BebeChargerModele(name)
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

local function Creer(pose, apparence, coords, cap)
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
        local h, err = BebeChargerModele(n)
        if not h then return nil, err end
        hashes[k] = h
    end
    coords = coords or GetEntityCoords(PlayerPedId())
    local b = { pose = pose, apparence = { teinte = teinte, yeux = yeux, coiffure = coiffure } }
    for _, k in ipairs({ 'corps', 'yeux', 'cheveux' }) do
        if hashes[k] then
            local o = CreateObjectNoOffset(hashes[k], coords.x, coords.y, coords.z, false, false, false)
            SetEntityHeading(o, cap or 0.0)
            SetEntityCollision(o, false, false)
            FreezeEntityPosition(o, true)
            b[k] = o
        end
    end
    for _, h in pairs(hashes) do SetModelAsNoLongerNeeded(h) end
    return b
end

local function Supprimer(b)
    if not b then return end
    for _, k in ipairs({ 'cheveux', 'yeux', 'corps' }) do
        if b[k] and DoesEntityExist(b[k]) then DeleteEntity(b[k]) end
        b[k] = nil
    end
end

exports('Creer', Creer)
exports('Supprimer', Supprimer)
exports('Poses', function()
    local out = {}
    for k, p in pairs(M.poses) do out[#out + 1] = { id = k, label = p.label } end
    return out
end)

-- ─────────── Aperçus locaux (ordre envoyé par le serveur après vérification de la permission) ───────────

local function ViderTests()
    for _, b in ipairs(tests) do Supprimer(b) end
    tests = {}
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
        return Notify('Aperçus retirés.', 'success')
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
        return Notify(('Aperçu local : pose « %s », 6 teintes.'):format(pose), 'success')
    end
    ViderTests()
    local pose = args[1] or 'allonge'
    if not M.poses[pose] then return Notify('Poses : allonge, porte, assis, ventral', 'error') end
    local coords, cap = DevantMoi(1.2)
    local b, err = Creer(pose, { teinte = args[2], yeux = args[3], coiffure = args[4] }, coords, cap + 180.0)
    if not b then return Notify(err, 'error') end
    tests[#tests + 1] = b
    Notify(('Aperçu local : %s · %s · yeux %s · %s'):format(pose, b.apparence.teinte, b.apparence.yeux, b.apparence.coiffure), 'success')
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then ViderTests() end
end)
