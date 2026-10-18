-- =====================================================================
--  ELYZEA BÉBÉ (modèle) - client : porter, poser, changer de prise (bébé réseau, visible par tous)
--  Le serveur crée les objets et décide de qui porte quoi (server/bebes.lua). Ici :
--   · attache des pièces au personnage quand le serveur le demande (l'attache est synchronisée par FiveM) ;
--   · animation de portage ;
--   · pendant le portage : coups de poing / pied / mêlée bloqués (le serveur annule aussi ces dégâts),
--     aucune protection pour le porteur ;
--   · menu ALT (fournisseur « elyzea_bebe_modele ») et commandes.
-- =====================================================================
local P = Config.Portage
local Notify = BebeNotify
local porte = nil   -- { id, mode, nets = {...}, pos, rot }

-- Attaques de mêlée (coups de poing, de pied, crosse, arme blanche) : toujours bloquées pendant le portage
local CONTROLES_MELEE = { 140, 141, 142, 143, 263, 264 }
-- « Attaquer » (24 / 257) : bloqué seulement poings ou arme de mêlée en main (pour une arme à feu, c'est le tir :
-- non concerné ; en pratique l'arme est rangée dans les prises « mains occupées »)
local CONTROLES_ATTAQUE = { 24, 257 }
local UNARMED = joaat('WEAPON_UNARMED')
local GROUPE_MELEE, GROUPE_POINGS = 3566412244, 2685387236

local function armeDeMelee(ped)
    local w = GetSelectedPedWeapon(ped)
    if w == UNARMED or w == 0 then return true end
    local g = GetWeapontypeGroup(w)
    return g == GROUPE_MELEE or g == GROUPE_POINGS or g == -728555052 or g == -1609580060
end

local function etat() return LocalPlayer.state.bebePorte end

local function entite(net, delai)
    local t = GetGameTimer() + (delai or 5000)
    while not NetworkDoesNetworkIdExist(net) or not NetworkDoesEntityExistWithNetworkId(net) do
        if GetGameTimer() > t then return nil end
        Wait(50)
    end
    return NetworkGetEntityFromNetworkId(net)
end

local function controle(e)
    local t = GetGameTimer() + 3000
    NetworkRequestControlOfEntity(e)
    while not NetworkHasControlOfEntity(e) do
        if GetGameTimer() > t then return false end
        NetworkRequestControlOfEntity(e)
        Wait(50)
    end
    return true
end

local function jouerAnim(anim)
    local ped = PlayerPedId()
    if not anim then return end
    RequestAnimDict(anim.dict)
    local t = GetGameTimer() + 5000
    while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < t do Wait(0) end
    if HasAnimDictLoaded(anim.dict) then
        TaskPlayAnim(ped, anim.dict, anim.clip, 3.0, 3.0, -1, anim.flag or 49, 0.0, false, false, false)
    end
end

local function arreterAnim()
    local ped = PlayerPedId()
    for _, m in pairs(P.modes) do
        if m.anim and IsEntityPlayingAnim(ped, m.anim.dict, m.anim.clip, 3) then
            StopAnimTask(ped, m.anim.dict, m.anim.clip, 2.0)
        end
    end
end

-- Attache demandée par le serveur (prise en main ou changement de prise)
RegisterNetEvent('elyzea_bebe_modele:attacher', function(id, nets, mode)
    local m = P.modes[mode]
    if not m or type(nets) ~= 'table' then return end
    local ped = PlayerPedId()
    local corps = nets.corps and entite(nets.corps)
    if not corps or not controle(corps) then return end
    for _, k in ipairs({ 'yeux', 'cheveux' }) do
        local e = nets[k] and entite(nets[k])
        if e and controle(e) then
            SetEntityCollision(e, false, false)
            FreezeEntityPosition(e, false)
            AttachEntityToEntity(e, corps, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
        end
    end
    local pos, rot = m.pos, m.rot
    if porte and porte.id == id and porte.mode == mode and porte.pos then pos, rot = porte.pos, porte.rot end
    SetEntityCollision(corps, false, false)
    FreezeEntityPosition(corps, false)
    AttachEntityToEntity(corps, ped, 0, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, false, false, false, false, 2, true)
    porte = { id = id, mode = mode, nets = nets, pos = pos, rot = rot }
    if m.mainsOccupees and P.rangerArme then SetCurrentPedWeapon(ped, UNARMED, true) end
    arreterAnim()
    jouerAnim(m.anim)
    TriggerServerEvent('elyzea_bebe_modele:attache', id)
end)

-- Le serveur a reposé ou retiré le bébé
RegisterNetEvent('elyzea_bebe_modele:lache', function(id)
    if porte and porte.id ~= id then return end
    porte = nil
    arreterAnim()
end)

-- Boucle pendant le portage : mêlée bloquée, arme rangée (mains occupées), animation maintenue
CreateThread(function()
    local dernierSol = 0
    while true do
        local e = etat()
        if e then
            local ped = PlayerPedId()
            if P.bloquerMelee then
                for _, c in ipairs(CONTROLES_MELEE) do DisableControlAction(0, c, true) end
                if armeDeMelee(ped) then
                    for _, c in ipairs(CONTROLES_ATTAQUE) do DisableControlAction(0, c, true) end
                end
            end
            if e.mains and P.rangerArme and GetSelectedPedWeapon(ped) ~= UNARMED then
                SetCurrentPedWeapon(ped, UNARMED, true)
            end
            local m = P.modes[e.mode]
            if m and m.anim and porte and not IsPedRagdoll(ped) and not IsEntityDead(ped)
                and not IsEntityPlayingAnim(ped, m.anim.dict, m.anim.clip, 3) and not IsPedInAnyVehicle(ped, false) then
                jouerAnim(m.anim)
            end
            if GetGameTimer() - dernierSol > 3000 then
                dernierSol = GetGameTimer()
                local c = GetEntityCoords(ped)
                local ok, z = GetGroundZFor_3dCoord(c.x, c.y, c.z, false)
                if ok then TriggerServerEvent('elyzea_bebe_modele:sol', z) end
            end
            Wait(0)
        else
            if porte then porte = nil arreterAnim() end
            Wait(250)
        end
    end
end)

-- ─────────── Actions ───────────

local function bebeAuSolProche(rayon)
    local pc = GetEntityCoords(PlayerPedId())
    local best, bestD
    for _, obj in ipairs(GetGamePool('CObject')) do
        local st = Entity(obj).state
        if st.bebePiece == 'corps' and st.bebe and not IsEntityAttached(obj) then
            local d = #(pc - GetEntityCoords(obj))
            if d <= rayon and (not bestD or d < bestD) then best, bestD = obj, d end
        end
    end
    return best
end

local function prendre(mode, obj)
    obj = obj or bebeAuSolProche(P.distancePrendre)
    if not obj then return Notify('Aucun bébé à portée.', 'error') end
    TriggerServerEvent('elyzea_bebe_modele:prendre', Entity(obj).state.bebe, mode or 'bras')
end

local function poser(pose)
    if not etat() then return Notify('Vous ne portez pas de bébé.', 'error') end
    local ped = PlayerPedId()
    local c = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.65, 0.0)
    local ok, z = GetGroundZFor_3dCoord(c.x, c.y, c.z + 0.5, false)
    if not ok then z = GetEntityCoords(ped).z - 0.98 end
    TriggerServerEvent('elyzea_bebe_modele:poser', pose or 'allonge', vector3(c.x, c.y, z), GetEntityHeading(ped) + 90.0)
end

local function changerMode(mode)
    if not etat() then return Notify('Vous ne portez pas de bébé.', 'error') end
    if not P.modes[mode] then return Notify('Prises : bras, face, portebebe', 'error') end
    TriggerServerEvent('elyzea_bebe_modele:mode', mode)
end

RegisterCommand(Config.Commandes.prendre, function(_, args) prendre(args[1]) end, false)
RegisterCommand(Config.Commandes.poser, function(_, args) poser(args[1]) end, false)
RegisterCommand(Config.Commandes.mode, function(_, args) changerMode(args[1]) end, false)

-- /bebe_ajuster (staff, autorisé par le serveur) : déplace le bébé porté en direct et affiche les valeurs à recopier
RegisterNetEvent('elyzea_bebe_modele:ajuster', function(args)
    if not porte then return end
    local v = {}
    for i = 1, 6 do v[i] = tonumber(args and args[i]) end
    if v[1] then
        porte.pos = vector3(v[1] or porte.pos.x, v[2] or porte.pos.y, v[3] or porte.pos.z)
        porte.rot = vector3(v[4] or porte.rot.x, v[5] or porte.rot.y, v[6] or porte.rot.z)
        local corps = porte.nets.corps and NetworkGetEntityFromNetworkId(porte.nets.corps)
        if corps and corps ~= 0 and controle(corps) then
            AttachEntityToEntity(corps, PlayerPedId(), 0, porte.pos.x, porte.pos.y, porte.pos.z, porte.rot.x, porte.rot.y, porte.rot.z, false, false, false, false, 2, true)
        end
    end
    print(('[elyzea_bebe_modele] Config.Portage.modes.%s : pos = vector3(%.3f, %.3f, %.3f), rot = vector3(%.1f, %.1f, %.1f),'):format(
        porte.mode, porte.pos.x, porte.pos.y, porte.pos.z, porte.rot.x, porte.rot.y, porte.rot.z))
    Notify('Valeurs affichées dans la console F8 (à recopier dans config.lua).', 'success')
end)

-- ─────────── Menu ALT (fournisseur « elyzea_bebe_modele » avec cibles propres) ───────────

local function corpsPorte()
    if not porte or not porte.nets.corps then return nil end
    local e = NetworkGetEntityFromNetworkId(porte.nets.corps)
    return e ~= 0 and DoesEntityExist(e) and e or nil
end

exports('AltTarget', function(ent)
    if ent and ent ~= 0 and DoesEntityExist(ent) and Entity(ent).state.bebe then return 'Bébé' end
    return nil
end)

exports('AltNearby', function()
    local mien = etat() and corpsPorte()
    if mien then return mien, 'Bébé (porté)' end
    local obj = bebeAuSolProche(P.distancePrendre)
    if obj then return obj, 'Bébé' end
    return nil
end)

exports('AltOptions', function(ctx)
    local out = {}
    if type(ctx) ~= 'table' or not ctx.entity then return out end
    local e = etat()
    if e and corpsPorte() == ctx.entity then
        for k, p in pairs(P.poses) do out[#out + 1] = { id = 'poser:' .. k, label = p.label, icon = 'out' } end
        for k, m in pairs(P.modes) do
            if k ~= e.mode then out[#out + 1] = { id = 'mode:' .. k, label = 'Prise : ' .. m.label, icon = 'carry' } end
        end
    elseif not e and Entity(ctx.entity).state.bebe then
        for k, m in pairs(P.modes) do out[#out + 1] = { id = 'prendre:' .. k, label = 'Prendre · ' .. m.label, icon = 'carry' } end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end)

exports('AltSelect', function(id, ctx)
    local action, arg = tostring(id):match('^(%w+):(%w+)$')
    CreateThread(function()
        if action == 'prendre' then prendre(arg, ctx and ctx.entity)
        elseif action == 'poser' then poser(arg)
        elseif action == 'mode' then changerMode(arg) end
    end)
    return true
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and porte then arreterAnim() end
end)
