-- =====================================================================
--  ELYZEA BÉBÉ (modèle) - client : porter, porte-bébés, poussette (bébé réseau, visible par tous) — V4
--  Le serveur crée les objets et décide de qui porte / pousse quoi (server/bebes.lua). Ici :
--   · attache des pièces au personnage quand le serveur le demande (l'attache est synchronisée par FiveM) ;
--   · animations natives (bébé contre soi dans les bras croisés, pousser la poussette) ;
--   · poussette : pas de course (réglable), arrêt devant un obstacle, hauteur ajustée au relief ;
--   · pendant le portage / la poussée : coups bloqués (le serveur annule aussi ces dégâts), aucune protection ;
--   · menu ALT (fournisseur « elyzea_bebe_modele ») et commandes.
-- =====================================================================
local P, EQ, PO = Config.Portage, Config.Equipements, Config.Poussette
local Notify = BebeNotify
local porte = nil        -- bébé porté : { id, mode, nets, pos, rot }
local pousse = nil       -- poussette poussée : { id, net, zoff, bebe = { id, nets } }
local equipement = nil   -- porte-bébé équipé : { net, type, pos, rot }

-- Attaques de mêlée (coups de poing, de pied, crosse, arme blanche) : toujours bloquées pendant le portage
local CONTROLES_MELEE = { 140, 141, 142, 143, 263, 264 }
-- « Attaquer » (24 / 257) : bloqué seulement poings ou arme de mêlée en main
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
local function etatPoussette() return LocalPlayer.state.bebePoussette end
local function equipeType() return LocalPlayer.state.bebeEquipement end
local function reglages() return GlobalState.bebeReglages or {} end

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

-- animation de poussée choisie dans le menu admin (V8)
local function animPoussee()
    local r = GlobalState.bebeReglages or {}
    return PO.anims[r.animPoussee or PO.animChoix] or PO.anims[PO.animChoix]
end

local function arreterAnim(seulement)
    local ped = PlayerPedId()
    local liste = {}
    if seulement ~= 'poussette' then for _, m in pairs(P.modes) do if m.anim then liste[#liste + 1] = m.anim end end end
    if seulement ~= 'bebe' then for _, a in pairs(PO.anims) do liste[#liste + 1] = a end end
    for _, a in ipairs(liste) do
        if IsEntityPlayingAnim(ped, a.dict, a.clip, 3) then StopAnimTask(ped, a.dict, a.clip, 2.0) end
    end
end

-- Personnage féminin (ou autre morphologie déclarée) : décalage du bébé et du porte-bébé, selon la prise
local function morpho(mode)
    local m = P.morphologies[GetEntityModel(PlayerPedId())]
    if not m then return vector3(0.0, 0.0, 0.0) end
    return m[mode] or m.defaut or vector3(0.0, 0.0, 0.0)
end

-- Attache les pièces du bébé à un parent (le personnage, ou la poussette)
local function attacherPieces(nets, pos, rot, parent)
    local ped = parent or PlayerPedId()
    local corps = nets.corps and entite(nets.corps)
    if not corps or not controle(corps) then return false end
    for _, k in ipairs({ 'yeux', 'cheveux' }) do
        local e = nets[k] and entite(nets[k])
        if e and controle(e) then
            SetEntityCollision(e, false, false)
            FreezeEntityPosition(e, false)
            AttachEntityToEntity(e, corps, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
        end
    end
    SetEntityCollision(corps, false, false)
    FreezeEntityPosition(corps, false)
    AttachEntityToEntity(corps, ped, 0, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, false, false, false, false, 2, true)
    return true
end

-- Attache demandée par le serveur (prise en main, changement de prise, bébé dans la poussette poussée)
-- Bébé dans la poussette POUSSÉE (V8) : attaché au personnage, à l'endroit de la nacelle. La position de la nacelle dans
-- le repère du personnage = attache de la poussette (PO.pos, hauteur zoff) + nacelle tournée du tangage de la poussette.
local function nacellePoussee(zoff, tangage)
    local t = math.rad(tangage or 0.0)
    local n = PO.nacelle.pos
    local y = n.y * math.cos(t) - n.z * math.sin(t)
    local z = n.y * math.sin(t) + n.z * math.cos(t)
    local rz = PO.rot.z + PO.nacelle.rot.z
    -- la nacelle est tournée de 180° : le tangage de la poussette devient une bascule opposée dans le repère du bébé
    local rx = math.abs((PO.nacelle.rot.z % 360.0) - 180.0) < 1.0 and -(tangage or 0.0) or (tangage or 0.0)
    local d = decPoussette()
    return vector3(PO.pos.x + n.x, PO.pos.y + d.y + y, PO.pos.z + d.z + (zoff or 0.0) + z), vector3(rx, 0.0, rz)
end

RegisterNetEvent('elyzea_bebe_modele:attacher', function(id, nets, mode)
    if type(nets) ~= 'table' then return end
    local ped = PlayerPedId()
    if mode == 'poussette' then
        local zoff = pousse and pousse.zoff or 0.0
        local tangage = pousse and pousse.tangage or 0.0
        local pos, rot = nacellePoussee(zoff, tangage)
        if attacherPieces(nets, pos, rot, ped) then
            if pousse then pousse.bebe = { id = id, nets = nets } end
            TriggerServerEvent('elyzea_bebe_modele:attache', id)
        end
        return
    end
    local m = P.modes[mode]
    if not m then return end
    local dec = (reglages().decalages or {})[mode]          -- décalage réglé dans le menu admin (cm, degrés)
    local pos, rot = m.pos + morpho(mode), m.rot
    if type(dec) == 'table' then
        pos = pos + vector3((dec.x or 0) / 100.0, (dec.y or 0) / 100.0, (dec.z or 0) / 100.0)
        rot = rot + vector3(dec.rx or 0.0, dec.ry or 0.0, dec.rz or 0.0)
    end
    if porte and porte.id == id and porte.mode == mode and porte.pos then pos, rot = porte.pos, porte.rot end
    if not attacherPieces(nets, pos, rot) then return end
    porte = { id = id, mode = mode, nets = nets, pos = pos, rot = rot }
    if m.mainsOccupees and P.rangerArme then SetCurrentPedWeapon(ped, UNARMED, true) end
    arreterAnim('bebe')
    jouerAnim(m.anim)
    TriggerServerEvent('elyzea_bebe_modele:attache', id)
end)

-- Le serveur a reposé ou retiré le bébé
RegisterNetEvent('elyzea_bebe_modele:lache', function(id)
    if porte and porte.id ~= id then return end
    porte = nil
    arreterAnim('bebe')
end)

-- ─────────── Porte-bébé ───────────

RegisterNetEvent('elyzea_bebe_modele:equipement:attacher', function(net, typ)
    local cfg = EQ[typ]
    local e = cfg and net and entite(net)
    if not e or not controle(e) then return end
    local pos, rot = cfg.pos + morpho(typ), cfg.rot
    if equipement and equipement.type == typ and equipement.pos then pos, rot = equipement.pos, equipement.rot end
    SetEntityCollision(e, false, false)
    FreezeEntityPosition(e, false)
    AttachEntityToEntity(e, PlayerPedId(), 0, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, false, false, false, false, 2, true)
    equipement = { net = net, type = typ, pos = pos, rot = rot }
    TriggerServerEvent('elyzea_bebe_modele:equipement:attache')
end)

-- ─────────── Poussette ───────────

-- décalage de la poussette réglé dans le menu admin (cm), selon l'animation de poussée
local function decPoussette()
    local d = (GlobalState.bebeReglages or {}).decPoussette or {}
    return vector3(0.0, (tonumber(d.y) or 0) / 100.0, (tonumber(d.z) or 0) / 100.0)
end

local function attacherPoussette(e, zoff, tangage)
    local p = PO.pos + decPoussette()
    AttachEntityToEntity(e, PlayerPedId(), 0, p.x, p.y, p.z + (zoff or 0.0), PO.rot.x + (tangage or 0.0), PO.rot.y, PO.rot.z,
        false, false, false, false, 2, true)
end

RegisterNetEvent('elyzea_bebe_modele:poussette:attacher', function(pid, net)
    local e = net and entite(net)
    if not e or not controle(e) then return end
    SetEntityCollision(e, false, false)
    FreezeEntityPosition(e, false)
    local zoff = (pousse and pousse.id == pid) and pousse.zoff or 0.0
    local tangage = (pousse and pousse.id == pid) and pousse.tangage or 0.0
    attacherPoussette(e, zoff, tangage)
    pousse = { id = pid, net = net, zoff = zoff, tangage = tangage, bebe = pousse and pousse.id == pid and pousse.bebe or nil }
    SetCurrentPedWeapon(PlayerPedId(), UNARMED, true)
    arreterAnim('poussette')
    jouerAnim(animPoussee())
    TriggerServerEvent('elyzea_bebe_modele:poussette:attache', pid)
end)

RegisterNetEvent('elyzea_bebe_modele:poussette:lache', function(pid)
    if pousse and pousse.id ~= pid then return end
    pousse = nil
    arreterAnim('poussette')
end)

-- Point au sol devant soi (sortir / garer la poussette)
local function solDevant(dist)
    local ped = PlayerPedId()
    local c = GetOffsetFromEntityInWorldCoords(ped, 0.0, dist, 0.0)
    local ok, z = GetGroundZFor_3dCoord(c.x, c.y, c.z + 0.6, false)
    if not ok then z = GetEntityCoords(ped).z - 0.98 end
    return vector3(c.x, c.y, z), GetEntityHeading(ped)
end

RegisterNetEvent('elyzea_bebe_modele:poussette:placer', function()
    if IsPedInAnyVehicle(PlayerPedId(), false) then return Notify('Impossible en véhicule.', 'error') end
    local c, cap = solDevant(1.0)
    TriggerServerEvent('elyzea_bebe_modele:poussette:sortir', c, cap)
end)

local function garer(sansFrein)
    if not pousse then return Notify('Vous ne poussez pas de poussette.', 'error') end
    local e = NetworkGetEntityFromNetworkId(pousse.net)
    local ped = PlayerPedId()
    local c
    if e ~= 0 and DoesEntityExist(e) then c = GetEntityCoords(e) else c = GetOffsetFromEntityInWorldCoords(ped, 0.0, PO.pos.y, 0.0) end
    local ok, z = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)
    if not ok then z = GetEntityCoords(ped).z + PO.pos.z end
    TriggerServerEvent('elyzea_bebe_modele:poussette:garer', vector3(c.x, c.y, z), GetEntityHeading(ped) + PO.rot.z, sansFrein == true)
end

-- Obstacle devant la poussette (mur, voiture, objet) : rayon depuis la hauteur de la nacelle
local function obstacleDevant()
    local ped = PlayerPedId()
    local depart = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.25, -0.35)
    local fin = GetOffsetFromEntityInWorldCoords(ped, 0.0, PO.pos.y + PO.obstacle - 0.5, -0.35)
    local ignorer = pousse and NetworkGetEntityFromNetworkId(pousse.net) or ped
    local h = StartShapeTestCapsule(depart.x, depart.y, depart.z, fin.x, fin.y, fin.z, 0.22, 1 + 16, ignorer, 7)
    local _, touche = GetShapeTestResult(h)
    return touche == 1 or touche == true
end

-- Sol sous la poussette poussée : hauteur ET inclinaison (sol sous l'essieu avant et sous l'essieu arrière).
-- Réattache seulement si l'écart est sensible ; le bébé, attaché à la poussette, suit.
local PH = Physique and Physique.defaut or { yAvant = 0.31, yArriere = -0.27 }
local function suivreSol()
    if not pousse or not PO.suiviSol then return end
    local e = NetworkGetEntityFromNetworkId(pousse.net)
    if e == 0 or not DoesEntityExist(e) then return end
    local ped = PlayerPedId()
    local function solA(dy)
        local c = GetOffsetFromEntityInWorldCoords(ped, 0.0, PO.pos.y + dy, 0.0)
        local ok, z = GetGroundZFor_3dCoord(c.x, c.y, c.z + 0.6, false)
        return ok and z or nil
    end
    local zAv, zAr = solA(PH.yAvant), solA(PH.yArriere)
    if not zAv or not zAr then return end
    local voulu = (zAv + zAr) / 2 - (GetEntityCoords(ped).z + PO.pos.z)
    if math.abs(voulu) > 0.45 then return end
    local tangage = math.deg(math.atan((zAv - zAr) / (PH.yAvant - PH.yArriere)))
    tangage = math.max(-20.0, math.min(20.0, tangage))
    if math.abs(voulu - (pousse.zoff or 0.0)) < 0.03 and math.abs(tangage - (pousse.tangage or 0.0)) < 1.5 then return end
    pousse.zoff, pousse.tangage = voulu, tangage
    attacherPoussette(e, voulu, tangage)
    -- le bébé (attaché au personnage) suit la nacelle
    local bb = pousse.bebe and pousse.bebe.nets and pousse.bebe.nets.corps
    local corps = bb and NetworkGetEntityFromNetworkId(bb)
    if corps and corps ~= 0 and DoesEntityExist(corps) and IsEntityAttachedToEntity(corps, ped) then
        local pos, rot = nacellePoussee(voulu, tangage)
        AttachEntityToEntity(corps, ped, 0, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, false, false, false, false, 2, true)
    end
end

-- Boucle pendant le portage / la poussée : mêlée bloquée, arme rangée (mains occupées), animations maintenues
CreateThread(function()
    local dernierSol, dernierObstacle, dernierSuivi, obstacle = 0, 0, 0, false
    while true do
        local e, ep = etat(), etatPoussette()
        if e or ep then
            local ped = PlayerPedId()
            local now = GetGameTimer()
            if P.bloquerMelee then
                for _, c in ipairs(CONTROLES_MELEE) do DisableControlAction(0, c, true) end
                if armeDeMelee(ped) then
                    for _, c in ipairs(CONTROLES_ATTAQUE) do DisableControlAction(0, c, true) end
                end
            end
            if ((e and e.mains) or ep) and P.rangerArme and GetSelectedPedWeapon(ped) ~= UNARMED then
                SetCurrentPedWeapon(ped, UNARMED, true)
            end
            local libre = not IsPedRagdoll(ped) and not IsEntityDead(ped) and not IsPedInAnyVehicle(ped, false)
            local m = e and P.modes[e.mode]
            if m and m.anim and porte and libre and not IsEntityPlayingAnim(ped, m.anim.dict, m.anim.clip, 3) then
                jouerAnim(m.anim)
            end
            if ep and pousse then
                local ap = animPoussee()
                if libre and not IsEntityPlayingAnim(ped, ap.dict, ap.clip, 3) then arreterAnim('poussette') jouerAnim(ap) end
                local r = reglages()
                if r.courseInterdite ~= false and PO.courseInterdite then DisableControlAction(0, 21, true) end   -- sprint
                if now - dernierObstacle > 200 then
                    dernierObstacle = now
                    obstacle = obstacleDevant()
                end
                if obstacle then DisableControlAction(0, 32, true) end                                     -- avancer
                if now - dernierSuivi > 300 then
                    dernierSuivi = now
                    suivreSol()
                end
            end
            if now - dernierSol > 3000 then
                dernierSol = now
                local c = GetEntityCoords(ped)
                local ok, z = GetGroundZFor_3dCoord(c.x, c.y, c.z, false)
                if ok then TriggerServerEvent('elyzea_bebe_modele:sol', z) end
            end
            Wait(0)
        else
            if porte then porte = nil arreterAnim('bebe') end
            if pousse then pousse = nil arreterAnim('poussette') end
            Wait(250)
        end
        if not equipeType() and equipement then equipement = nil end
    end
end)

-- ─────────── Actions ───────────

local function objetsProches(cle, rayon, filtre)
    local pc = GetEntityCoords(PlayerPedId())
    local best, bestD
    for _, obj in ipairs(GetGamePool('CObject')) do
        local st = Entity(obj).state
        if st[cle] and (not filtre or filtre(obj, st)) then
            local d = #(pc - GetEntityCoords(obj))
            if d <= rayon and (not bestD or d < bestD) then best, bestD = obj, d end
        end
    end
    return best
end

local function bebeProche(rayon)
    -- bébé posé ou couché dans une poussette garée (pas un bébé porté par quelqu'un)
    return objetsProches('bebe', rayon, function(obj, st) return st.bebePiece == 'corps' and not IsEntityAttached(obj) end)
end

local function poussetteProche(rayon) return objetsProches('bebePoussette', rayon) end

-- Geste natif court (se pencher pour prendre / déposer), jamais bloquant : arrêté au bout de sa durée
local function geste(anim)
    local ped = PlayerPedId()
    if not anim or IsPedInAnyVehicle(ped, false) then return end
    RequestAnimDict(anim.dict)
    local t = GetGameTimer() + 1500
    while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < t do Wait(0) end
    if not HasAnimDictLoaded(anim.dict) then return end
    TaskPlayAnim(ped, anim.dict, anim.clip, 4.0, 4.0, anim.duree or 1000, 0, 0.0, false, false, false)
    Wait(math.floor((anim.duree or 1000) * 0.7))
end

local function prendre(mode, obj)
    obj = obj or bebeProche(P.distancePrendre)
    if not obj then return Notify('Aucun bébé à portée.', 'error') end
    geste(P.gestes and P.gestes.prendre)
    TriggerServerEvent('elyzea_bebe_modele:prendre', Entity(obj).state.bebe, P.alias[mode] or mode or 'face')
end

local function poser(pose)
    if not etat() then return Notify('Vous ne portez pas de bébé.', 'error') end
    local c, cap = solDevant(0.65)
    geste(P.gestes and P.gestes.poser)
    TriggerServerEvent('elyzea_bebe_modele:poser', pose or 'allonge', c, cap + 90.0)
end

local function changerMode(mode)
    if not etat() then return Notify('Vous ne portez pas de bébé.', 'error') end
    mode = P.alias[mode] or mode
    if not P.modes[mode] then return Notify('Prises : contre, ventral, dorsal', 'error') end
    TriggerServerEvent('elyzea_bebe_modele:mode', mode)
end

local function installer(obj)
    obj = obj or (pousse and NetworkGetEntityFromNetworkId(pousse.net)) or poussetteProche(PO.distance)
    if not obj or obj == 0 then return Notify('Aucune poussette à portée.', 'error') end
    TriggerServerEvent('elyzea_bebe_modele:poussette:installer', Entity(obj).state.bebePoussette)
end

RegisterCommand(Config.Commandes.prendre, function(_, args) prendre(args[1]) end, false)
RegisterCommand(Config.Commandes.poser, function(_, args) poser(args[1]) end, false)
RegisterCommand(Config.Commandes.mode, function(_, args) changerMode(args[1]) end, false)
RegisterCommand('bebe_dormir', function()
    local id = (etat() and etat().id) or (pousse and pousse.bebe and pousse.bebe.id)
    if not id then
        local obj = bebeProche(P.distancePrendre)
        id = obj and Entity(obj).state.bebe
    end
    if not id then return Notify('Aucun bébé à portée.', 'error') end
    TriggerServerEvent('elyzea_bebe_modele:dormir', id)
end, false)
RegisterCommand('poussette', function(_, args)
    if args[1] == 'garer' or (not args[1] and pousse) then return garer() end
    if args[1] == 'lacher' then return garer(true) end
    if args[1] == 'installer' then return installer() end
    local obj = poussetteProche(PO.distance)
    if not obj then return Notify('Aucune poussette à portée.', 'error') end
    if args[1] == 'ranger' then return TriggerServerEvent('elyzea_bebe_modele:poussette:ranger', Entity(obj).state.bebePoussette) end
    TriggerServerEvent('elyzea_bebe_modele:poussette:pousser', Entity(obj).state.bebePoussette)
end, false)
RegisterCommand('coloris_porte_bebe', function(_, args) TriggerServerEvent('elyzea_bebe_modele:coloris', 'pb', args[1]) end, false)
RegisterCommand('coloris_poussette', function(_, args) TriggerServerEvent('elyzea_bebe_modele:coloris', 'poussette', args[1]) end, false)

-- /bebe_ajuster (staff, autorisé par le serveur) : déplace en direct et affiche les valeurs à recopier dans config.lua
RegisterNetEvent('elyzea_bebe_modele:ajuster', function(cible, args)
    local v = {}
    for i = 1, 6 do v[i] = tonumber(args and args[i]) end
    local ped = PlayerPedId()
    local function appliquer(cur)
        if v[1] then
            cur.pos = vector3(v[1] or cur.pos.x, v[2] or cur.pos.y, v[3] or cur.pos.z)
            cur.rot = vector3(v[4] or cur.rot.x, v[5] or cur.rot.y, v[6] or cur.rot.z)
        end
    end
    if cible == 'equipement' and equipement then
        appliquer(equipement)
        local e = NetworkGetEntityFromNetworkId(equipement.net)
        if e ~= 0 and controle(e) then
            AttachEntityToEntity(e, ped, 0, equipement.pos.x, equipement.pos.y, equipement.pos.z, equipement.rot.x, equipement.rot.y, equipement.rot.z,
                false, false, false, false, 2, true)
        end
        print(('[elyzea_bebe_modele] Config.Equipements.%s : pos = vector3(%.3f, %.3f, %.3f), rot = vector3(%.1f, %.1f, %.1f),'):format(
            equipement.type, equipement.pos.x, equipement.pos.y, equipement.pos.z, equipement.rot.x, equipement.rot.y, equipement.rot.z))
    elseif cible == 'poussette' and pousse then
        local cur = { pos = PO.pos, rot = PO.rot }
        appliquer(cur)
        PO.pos, PO.rot = cur.pos, cur.rot
        local e = NetworkGetEntityFromNetworkId(pousse.net)
        if e ~= 0 and controle(e) then attacherPoussette(e, pousse.zoff) end
        print(('[elyzea_bebe_modele] Config.Poussette : pos = vector3(%.3f, %.3f, %.3f), rot = vector3(%.1f, %.1f, %.1f),'):format(
            PO.pos.x, PO.pos.y, PO.pos.z, PO.rot.x, PO.rot.y, PO.rot.z))
    elseif porte then
        appliquer(porte)
        local corps = porte.nets.corps and NetworkGetEntityFromNetworkId(porte.nets.corps)
        if corps and corps ~= 0 and controle(corps) then
            AttachEntityToEntity(corps, ped, 0, porte.pos.x, porte.pos.y, porte.pos.z, porte.rot.x, porte.rot.y, porte.rot.z, false, false, false, false, 2, true)
        end
        print(('[elyzea_bebe_modele] Config.Portage.modes.%s : pos = vector3(%.3f, %.3f, %.3f), rot = vector3(%.1f, %.1f, %.1f),'):format(
            porte.mode, porte.pos.x, porte.pos.y, porte.pos.z, porte.rot.x, porte.rot.y, porte.rot.z))
    else
        return
    end
    Notify('Valeurs affichées dans la console F8 (à recopier dans config.lua).', 'success')
end)

-- ─────────── Menu ALT (fournisseur « elyzea_bebe_modele » avec cibles propres) ───────────

local function corpsPorte()
    if not porte or not porte.nets.corps then return nil end
    local e = NetworkGetEntityFromNetworkId(porte.nets.corps)
    return e ~= 0 and DoesEntityExist(e) and e or nil
end

local function modesPossibles()
    local r, eq = reglages(), equipeType()
    local out = {}
    for k, m in pairs(P.modes) do
        local ok = true
        if m.equipement then ok = eq == m.equipement and r[m.equipement] ~= false end
        if m.mainsOccupees and etatPoussette() then ok = false end
        if ok then out[k] = m end
    end
    return out
end

-- « Prendre contre soi » (seule prise à la main) ; porte-bébés : proposés seulement quand ils sont équipés
local function libellePrendre(k, m)
    return k == 'face' and 'Prendre contre soi' or ('Prendre · ' .. m.label)
end

exports('AltTarget', function(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    local st = Entity(ent).state
    if st.bebe then return 'Bébé' end
    if st.bebePoussette then return 'Poussette' end
    return nil
end)

exports('AltNearby', function()
    local mien = etat() and corpsPorte()
    if mien then return mien, 'Bébé (porté)' end
    if pousse then
        local e = NetworkGetEntityFromNetworkId(pousse.net)
        if e ~= 0 and DoesEntityExist(e) then return e, 'Poussette' end
    end
    local obj = bebeProche(P.distancePrendre)
    if obj then return obj, 'Bébé' end
    obj = poussetteProche(PO.distance)
    if obj then return obj, 'Poussette' end
    return nil
end)

exports('AltOptions', function(ctx)
    local out = {}
    if type(ctx) ~= 'table' or not ctx.entity then return out end
    local st = Entity(ctx.entity).state
    local e = etat()
    local r = reglages()
    if e and corpsPorte() == ctx.entity then
        for k, p in pairs(P.poses) do out[#out + 1] = { id = 'poser:' .. k, label = p.label, icon = 'out' } end
        for k, m in pairs(modesPossibles()) do
            if k ~= e.mode then out[#out + 1] = { id = 'mode:' .. k, label = 'Prise : ' .. m.label, icon = 'carry' } end
        end
        if r.poussette ~= false and (pousse or poussetteProche(PO.distance)) then
            out[#out + 1] = { id = 'installer:x', label = 'Installer dans la poussette', icon = 'carry' }
        end
        out[#out + 1] = { id = 'dormir:' .. st.bebe, label = 'Endormir / réveiller', icon = 'out' }
    elseif st.bebePoussette then
        local mienne = pousse and pousse.id == st.bebePoussette
        if mienne then
            out[#out + 1] = { id = 'garer:x', label = 'Garer la poussette (frein serré)', icon = 'out' }
            out[#out + 1] = { id = 'lacher:x', label = 'Lâcher la poussette (sans frein)', icon = 'out' }
        elseif st.bebeRenversee then
            out[#out + 1] = { id = 'relever:' .. st.bebePoussette, label = 'Relever la poussette', icon = 'carry' }
        elseif not (e and e.mains) then
            out[#out + 1] = { id = 'pousser:' .. st.bebePoussette, label = 'Pousser la poussette', icon = 'carry' }
        end
        if not mienne and not st.bebeRenversee then
            out[#out + 1] = { id = 'frein:' .. st.bebePoussette, label = st.bebeFrein == false and 'Serrer le frein' or 'Desserrer le frein', icon = 'out' }
        end
        if e and not st.bebeDedans then
            out[#out + 1] = { id = 'installer:' .. st.bebePoussette, label = 'Installer le bébé dans la poussette', icon = 'carry' }
        end
        if st.bebeDedans and not e then
            for k, m in pairs(modesPossibles()) do
                out[#out + 1] = { id = 'prendrepo:' .. k, label = k == 'face' and 'Sortir le bébé et le prendre contre soi' or ('Sortir le bébé · ' .. m.label), icon = 'carry' }
            end
            out[#out + 1] = { id = 'dormir:' .. st.bebeDedans, label = 'Endormir / réveiller le bébé', icon = 'out' }
        end
        if not mienne and not st.bebeDedans then
            out[#out + 1] = { id = 'ranger:' .. st.bebePoussette, label = 'Ranger la poussette', icon = 'out' }
        end
    elseif not e and st.bebe then
        for k, m in pairs(modesPossibles()) do out[#out + 1] = { id = 'prendre:' .. k, label = libellePrendre(k, m), icon = 'carry' } end
        out[#out + 1] = { id = 'dormir:' .. st.bebe, label = 'Endormir / réveiller', icon = 'out' }
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end)

exports('AltSelect', function(id, ctx)
    local action, arg = tostring(id):match('^(%w+):([%w%-_]+)$')
    local ent = ctx and ctx.entity
    CreateThread(function()
        if action == 'prendre' then prendre(arg, ent)
        elseif action == 'prendrepo' then
            local bid = ent and Entity(ent).state.bebeDedans
            if bid then TriggerServerEvent('elyzea_bebe_modele:prendre', bid, arg) end
        elseif action == 'poser' then poser(arg)
        elseif action == 'mode' then changerMode(arg)
        elseif action == 'dormir' then TriggerServerEvent('elyzea_bebe_modele:dormir', arg)
        elseif action == 'installer' then installer(arg ~= 'x' and ent or nil)
        elseif action == 'pousser' then TriggerServerEvent('elyzea_bebe_modele:poussette:pousser', arg)
        elseif action == 'garer' then garer()
        elseif action == 'lacher' then garer(true)
        elseif action == 'frein' then TriggerServerEvent('elyzea_bebe_modele:poussette:frein', arg)
        elseif action == 'relever' then TriggerServerEvent('elyzea_bebe_modele:poussette:relever', arg)
        elseif action == 'ranger' then TriggerServerEvent('elyzea_bebe_modele:poussette:ranger', arg) end
    end)
    return true
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and (porte or pousse) then arreterAnim() end
end)

-- Outils partagés avec client/poussette.lua (simulation, roues)
BebeClient = { entite = entite, controle = controle, attacherPieces = attacherPieces }
