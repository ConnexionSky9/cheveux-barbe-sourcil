-- =========================================================
--  TENUES DE SERVICE - CLIENT (tous les joueurs)
--  La tenue n'est JAMAIS changée automatiquement (prise / fin de service, métier, grade).
--  Le joueur la met ou la retire lui-même : bouton « Mettre ma tenue » des tablettes F6
--  (exports.admin_menu:SetServiceUniform) ou commande /tenue_service.
-- =========================================================
local CFG = Config.Uniforms or {}
local COMPS = CFG.components or { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local PROPS = CFG.props or { 0, 1, 2, 6, 7 }

local Uniforms = {}
local wearing = false      -- tenue de service sur le dos
local civilian = nil       -- vêtements du joueur avant la tenue
local preview = nil        -- vêtements avant un essai (staff)

local MALE, FEMALE = `mp_m_freemode_01`, `mp_f_freemode_01`

local function gender()
    local m = GetEntityModel(PlayerPedId())
    if m == MALE then return 'male' elseif m == FEMALE then return 'female' end
end

local function snapshot()
    local ped = PlayerPedId()
    local o = { c = {}, p = {} }
    for _, c in ipairs(COMPS) do o.c[tostring(c)] = { GetPedDrawableVariation(ped, c), GetPedTextureVariation(ped, c) } end
    for _, p in ipairs(PROPS) do o.p[tostring(p)] = { GetPedPropIndex(ped, p), GetPedPropTextureIndex(ped, p) } end
    return o
end

local function apply(o)
    local ped = PlayerPedId()
    for k, v in pairs(o.c or {}) do SetPedComponentVariation(ped, tonumber(k), v[1], v[2], 0) end
    for k, v in pairs(o.p or {}) do
        if v[1] == -1 then ClearPedProp(ped, tonumber(k)) else SetPedPropIndex(ped, tonumber(k), v[1], v[2], true) end
    end
end

-- Tenue du grade, sinon celle du grade inférieur le plus proche
local function findOutfit(job, grade, g)
    local j = Uniforms[job]
    if not j or not g then return nil end
    for lvl = grade, 0, -1 do
        local e = j[tostring(lvl)]
        if e and e[g] then return e[g] end
    end
end

local function reloadSkin()
    if GetResourceState('ely_creator') == 'started' then
        pcall(function() exports.ely_creator:ReloadSkin() end)
    end
end

-- Vêtements civils sauvegardés sur le PC du joueur (par personnage) : survivent à un crash ou un redémarrage
local function charKey()
    local ok, cid = pcall(function() return (exports.elyzea_core:GetPlayerData() or {}).citizenid end)
    return 'uniform_civilian_' .. tostring(ok and cid or 'default')
end

local function storeCivilian(o)
    if o then SetResourceKvp(charKey(), json.encode(o)) else DeleteResourceKvp(charKey()) end
end

local function storedCivilian()
    local raw = GetResourceKvpString(charKey())
    return raw and json.decode(raw) or nil
end

local function takeOff()
    local o = civilian or storedCivilian()
    if o then apply(o) else reloadSkin() end
    wearing, civilian = false, nil
    storeCivilian(nil)
end

-- Métier du joueur : nom, grade
local function currentJob()
    local ok, name, grade = pcall(function()
        local j = (exports.elyzea_core:GetPlayerData() or {}).job
        if j then return j.name, (j.grade and j.grade.level) or 0 end
    end)
    if ok then return name, grade or 0 end
end

-- Mettre (on = true) ou retirer (on = false) la tenue de service, à la demande du joueur
local function setServiceUniform(on)
    if CFG.enabled == false then return false, 'Les tenues de service sont désactivées.' end
    if preview then return false, 'Essai de tenue en cours (staff).' end
    if not on then
        if not wearing and not storedCivilian() then return false, 'Vous ne portez pas de tenue de service.' end
        takeOff()
        return true, 'Vous avez remis vos vêtements.'
    end
    local name, grade = currentJob()
    local g = gender()
    local outfit = name and findOutfit(name, grade, g)
    if not outfit then return false, 'Aucune tenue de service pour votre grade (à enregistrer dans le menu admin › Métiers › Tenues).' end
    if not wearing then
        civilian = storedCivilian() or snapshot()
        storeCivilian(civilian)
    end
    apply(outfit)
    wearing = true
    return true, 'Tenue de service enfilée.'
end
exports('SetServiceUniform', setServiceUniform)
exports('IsWearingUniform', function() return wearing end)

RegisterCommand('tenue_service', function()
    local ok, msg = setServiceUniform(not wearing)
    Notify(msg, ok and 'success' or 'error')
end, false)

RegisterNetEvent('adminmenu:uniforms', function(data)
    Uniforms = type(data) == 'table' and data or {}
end)

-- Nouveau personnage : on repart de zéro (aucune tenue n'est mise ou retirée automatiquement)
RegisterNetEvent('elyzea:client:playerLoaded', function()
    wearing, civilian = false, nil
end)

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    TriggerServerEvent('adminmenu:uniforms:request')
end)

-- ---------------------------------------------------------
--  Outils du staff (onglets EMS / Police et tablettes staff des métiers)
-- ---------------------------------------------------------
local function captureOutfit()
    local g = gender()
    if not g then return nil, 'Ton personnage doit être un personnage homme ou femme du jeu (freemode).' end
    return { gender = g, outfit = snapshot() }
end

local function tryUniform(job, grade)
    local g = gender()
    local e = Uniforms[tostring(job)] and Uniforms[tostring(job)][tostring(grade)]
    local o = e and g and e[g]
    if not o then return false, ('Aucune tenue %s pour ce grade.'):format(g == 'female' and 'femme' or 'homme') end
    if not preview then preview = snapshot() end
    apply(o)
    return true
end

local function untryUniform()
    if preview then apply(preview) preview = nil end
    return true
end

exports('CaptureOutfit', captureOutfit)
exports('TryUniform', tryUniform)
exports('UntryUniform', untryUniform)
exports('IsTryingUniform', function() return preview ~= nil end)
RegisterNUICallback('uniform_capture', function(_, cb)
    local r, err = captureOutfit()
    cb(r or { error = err })
end)

RegisterNUICallback('uniform_try', function(body, cb)
    local ok, err = tryUniform(body.job, body.grade)
    cb(ok and { ok = true } or { error = err })
end)

RegisterNUICallback('uniform_untry', function(_, cb)
    untryUniform()
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and (wearing or preview) then
        if preview then apply(preview) elseif civilian then apply(civilian) end
    end
end)
