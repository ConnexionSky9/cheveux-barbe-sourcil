-- =====================================================================
--  ELYZEA BÉBÉ (modèle) - serveur : bébés en réseau, portage, porte-bébés, poussette (V4)
--
--  Principe : chaque bébé existe UNE fois, sur le serveur. Ses pièces (corps, yeux ou paupières, cheveux) sont des
--  objets réseau créés par le serveur : tous les joueurs proches voient les mêmes entités.
--
--  États d'un bébé (un seul à la fois, changé ici sous verrou) :
--   · pose      : figé au sol (lit, berceau, banc…) ;
--   · porte     : attaché au porteur, prise « face » (contre soi), « ventral » / « dorsal » (porte-bébé équipé)
--                 ou « dorsal » (porte-bébé dorsal équipé) ;
--   · poussette : couché dans la nacelle d'une poussette (garée : figé ; poussée : attaché au pousseur).
--  Chaque changement : vérification de l'état actuel et des conditions → suppression des anciennes pièces →
--  création des nouvelles → mise à jour de l'état → attache demandée au bon joueur et vérifiée toutes les 2 s.
--  Les demandes répétées (double clic) et simultanées (deux joueurs) sont refusées tant qu'un changement est en cours.
--
--  Porte-bébés : objets 3D équipés depuis l'inventaire, attachés au personnage (visibles par tous).
--  Poussette   : objet 3D (pas un véhicule) sorti depuis l'inventaire ; garée = figée au sol, poussée = attachée
--                devant le personnage. Une poussette par personnage ; une poussette vide abandonnée est supprimée.
--  Mort, coma, déconnexion, changement de personnage, arrêt de la ressource : bébé reposé ou laissé dans la poussette
--  garée, jamais perdu ni dupliqué. Le porteur / pousseur ne peut pas frapper mais ne reçoit AUCUNE protection.
--
--  Exports serveur :
--    local id = exports.elyzea_bebe_modele:CreerBebe(apparence, coords, cap, { responsables = { citizenid, ... }, bucket = 0 })
--    exports.elyzea_bebe_modele:SupprimerBebe(id)
--    exports.elyzea_bebe_modele:EtatBebe(id) -> { etat, porteur, mode, pose, poussette, coords, apparence, endormi }
--    exports.elyzea_bebe_modele:BebePortePar(src) -> id ou nil
--    exports.elyzea_bebe_modele:AppliquerReglages(valeurs)   (appelé par elyzea_famille : menu admin)
-- =====================================================================
local P, EQ, PO = Config.Portage, Config.Equipements, Config.Poussette
local Bebes = {}          -- [id] = bébé
local parPorteur = {}     -- [src] = id du bébé porté (ou poussé dans une poussette)
local Equip = {}          -- [src] = porte-bébé équipé { type, coloris, ent, net, essais, attacheDemandee }
local Poussettes = {}     -- [pid] = poussette
local parPousseur = {}    -- [src] = pid
local occupe = {}         -- [src] = true pendant un changement (anti double clic)
-- Identifiants durables (enregistrés en base) : préfixe + 8 caractères au hasard
local ALPHA = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'
local function nouvelId(prefixe, table_)
    for _ = 1, 20 do
        local t = {}
        for i = 1, 8 do local n = math.random(1, #ALPHA) t[i] = ALPHA:sub(n, n) end
        local id = prefixe .. '-' .. table.concat(t)
        if not table_[id] then return id end
    end
end

local function log(...) if Config.Debug then print('[elyzea_bebe_modele]', ...) end end
local function notify(src, msg, kind) pcall(function() exports.elyzea_core:Notify(src, msg, kind or 'inform') end) end

local Limites = {}
local function limite(src, cle, max, ms)
    local k = src .. ':' .. cle
    local now = GetGameTimer()
    local b = Limites[k]
    if not b or now - b.t > ms then Limites[k] = { t = now, n = 1 } return true end
    b.n = b.n + 1
    return b.n <= max
end

local function vec(c) return vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0) end
local function present(src) return src and GetPlayerName(src) ~= nil end

local function citizenid(src)
    local ok, cid = pcall(function() return exports.elyzea_core:GetCitizenId(src) end)
    return ok and cid or nil
end

local function aTerre(src)
    local ped = GetPlayerPed(src)
    if ped == 0 or GetEntityHealth(ped) <= 0 then return true end
    if GetResourceState('elyzea_ems') == 'started' then
        local ok, down = pcall(function() return exports.elyzea_ems:IsDown(src) end)
        if ok and down then return true end
    end
    return false
end

local function nbObjets(src, item)
    if GetResourceState('elyzea_inventory') ~= 'started' then return 0 end
    local ok, n = pcall(function() return exports.elyzea_inventory:GetItemCount(src, item) end)
    return ok and tonumber(n) or 0
end

-- Rotation d'un décalage (repère local) par un cap (degrés, comme GetEntityHeading)
local function tourner(v, cap)
    local r = math.rad(cap)
    local c, s = math.cos(r), math.sin(r)
    return vector3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)
end

-- ─────────── Objets réseau ───────────

local function creerObjet(modele, coords, cap, figer, bucket, etats)
    local e = CreateObjectNoOffset(joaat(modele), coords.x, coords.y, coords.z, true, true, false)
    local t = GetGameTimer() + 3000
    while not DoesEntityExist(e) and GetGameTimer() < t do Wait(0) end
    if not DoesEntityExist(e) then
        print(('^1[elyzea_bebe_modele] création de %s impossible (OneSync activé ? fichier dans stream/ ?)^0'):format(modele))
        return nil
    end
    pcall(SetEntityOrphanMode, e, 2)          -- garder l'entité même si aucun joueur n'est proche
    SetEntityRoutingBucket(e, bucket or 0)
    SetEntityHeading(e, cap + 0.0)
    FreezeEntityPosition(e, figer == true)
    for k, v in pairs(etats or {}) do Entity(e).state:set(k, v, true) end
    return e, NetworkGetNetworkIdFromEntity(e)
end

local function supprimer(e) if e and DoesEntityExist(e) then DeleteEntity(e) end end

-- ─────────── Pièces du bébé ───────────

local PIECES = { 'corps', 'yeux', 'cheveux' }

local function nomsModeles(b, pose)
    local M = BebeModeles.poses[pose]
    local a = b.apparence
    local yeux = M.yeux[a.yeux]
    if b.endormi and M.paupieres and M.paupieres[a.teinte] then yeux = M.paupieres[a.teinte] end
    return {
        corps = M.corps[a.teinte .. '_' .. a.tenue],
        yeux = yeux,
        cheveux = a.coiffure ~= 'chauve' and M.cheveux[a.coiffure] or nil,
    }
end

local function supprimerEntites(b)
    for _, k in ipairs(PIECES) do supprimer(b.ents and b.ents[k]) end
    b.ents, b.nets = nil, nil
end

-- Crée les pièces d'une pose, figées (le porteur les libère en les attachant). Renvoie true ou false.
local function creerEntites(b, pose, coords, cap, figer)
    local noms = nomsModeles(b, pose)
    local ents, nets = {}, {}
    for _, k in ipairs(PIECES) do
        if noms[k] then
            local e, n = creerObjet(noms[k], coords, cap, figer, b.bucket, { bebe = b.id, bebePiece = k })
            if not e then
                b.ents = ents
                supprimerEntites(b)
                return false
            end
            ents[k], nets[k] = e, n
        end
    end
    b.ents, b.nets, b.pose = ents, nets, pose
    return true
end

local function majEtatJoueur(src)
    if not present(src) then return end
    local b = Bebes[parPorteur[src] or '']
    local po = Poussettes[parPousseur[src] or '']
    local e = nil
    if b and b.etat == 'porte' then
        e = { id = b.id, mode = b.mode, mains = P.modes[b.mode].mainsOccupees == true }
    end
    Player(src).state:set('bebePorte', e, true)
    Player(src).state:set('bebePoussette', po and { id = po.id, mains = true } or nil, true)
    Player(src).state:set('bebeEquipement', Equip[src] and Equip[src].type or nil, true)
end

-- Demande au joueur concerné d'attacher les pièces (porté : à lui ; poussette poussée : à lui, dans la nacelle)
local function demanderAttache(b)
    b.attacheDemandee = GetGameTimer()
    b.essais = (b.essais or 0) + 1
    local qui = b.etat == 'porte' and b.porteur or b.pousseur
    -- poussette poussée (V6) : le bébé est attaché à la POUSSETTE (il suit son inclinaison sur les pentes)
    local po = b.etat == 'poussette' and Poussettes[b.poussette or ''] or nil
    TriggerClientEvent('elyzea_bebe_modele:attacher', qui, b.id, b.nets, b.etat == 'porte' and b.mode or 'poussette', po and po.net or nil)
end

-- ─────────── Poussettes ───────────

local function nomPoussette(po)
    local M = BebeModeles.equipements and BebeModeles.equipements.poussette or {}
    return M[po.coloris] or M[PO.coloris] or select(2, next(M))
end

-- position du bébé couché dans la nacelle d'une poussette garée
local function nacelleMonde(po)
    local o = tourner(PO.nacelle.pos, po.cap)
    return vector3(po.coords.x + o.x, po.coords.y + o.y, po.coords.z + o.z), (po.cap + PO.nacelle.rot.z) % 360.0
end

local function creerPoussetteEnt(po, coords, cap, figer)
    supprimer(po.ent)
    -- états lus par les clients : nacelle occupée, coloris (roues locales), frein, renversée
    po.ent, po.net = creerObjet(nomPoussette(po), coords, cap, figer, po.bucket, { bebePoussette = po.id, bebeDedans = po.bebe or false,
        bebeColoris = po.coloris, bebeFrein = po.frein ~= false, bebeRenversee = po.etat == 'renversee' })
    if po.ent and po.etat == 'renversee' then pcall(SetEntityRotation, po.ent, 0.0, 80.0, cap + 0.0, 2, false) end
    return po.ent ~= nil
end

-- occupation de la nacelle, lisible par les clients (menu ALT)
local function majDedans(po)
    if po and po.ent and DoesEntityExist(po.ent) then Entity(po.ent).state:set('bebeDedans', po.bebe or false, true) end
end

-- ─────────── Placement du bébé selon son état ───────────

-- Recrée les pièces du bébé selon son état actuel et demande l'attache si nécessaire. Renvoie true ou false.
local function placer(b)
    supprimerEntites(b)
    b.essais, b.attacheDemandee = 0, nil
    if b.etat == 'pose' then
        return creerEntites(b, b.poseSol or 'allonge', b.coords, b.cap or 0.0, true)
    elseif b.etat == 'porte' then
        local ped = GetPlayerPed(b.porteur)
        if not creerEntites(b, P.modes[b.mode].pose, GetEntityCoords(ped), GetEntityHeading(ped), true) then return false end
        demanderAttache(b)
        return true
    elseif b.etat == 'poussette' then
        local po = Poussettes[b.poussette]
        if not po then return false end
        if po.etat == 'garee' or po.etat == 'libre' then
            local c, cap = nacelleMonde(po)
            return creerEntites(b, 'allonge', c, cap, true)
        end
        local ped = GetPlayerPed(po.pousseur)
        if not creerEntites(b, 'allonge', GetEntityCoords(ped), GetEntityHeading(ped), true) then return false end
        b.pousseur = po.pousseur
        demanderAttache(b)
        return true
    end
    return false
end

-- ─────────── Poser ───────────

local function lacher(b)
    local porteur = b.porteur
    if porteur then
        parPorteur[porteur] = nil
        b.porteur, b.mode = nil, nil
        if present(porteur) then
            majEtatJoueur(porteur)
            TriggerClientEvent('elyzea_bebe_modele:lache', porteur, b.id)
        end
    end
end

-- Pose le bébé (porté ou non) à un endroit. Interne : aucune vérification de distance ici.
local function poserA(b, pose, coords, cap)
    lacher(b)
    if b.poussette and Poussettes[b.poussette] then
        Poussettes[b.poussette].bebe = nil
        majDedans(Poussettes[b.poussette])
    end
    b.etat, b.poussette, b.pousseur = 'pose', nil, nil
    b.coords, b.cap, b.poseSol = coords, cap, pose
    if not placer(b) then
        b.etat = 'erreur'
        return false
    end
    log('posé', b.id, pose, coords)
    return true
end

-- Position de repli quand le porteur ne peut plus choisir (mort, déconnexion) : là où il était, au sol
local function solDe(src, sauve)
    local ped = present(src) and GetPlayerPed(src) or 0
    local c = sauve and sauve.dernierePos
    if ped ~= 0 and DoesEntityExist(ped) then
        local pc = GetEntityCoords(ped)
        if pc.x ~= 0.0 or pc.y ~= 0.0 or pc.z ~= 0.0 then c = pc end
    end
    c = c or (sauve and sauve.coords) or vector3(0.0, 0.0, 0.0)
    local z = (sauve and sauve.solZ and math.abs(sauve.solZ - (c.z - 1.0)) < 2.5) and sauve.solZ or (c.z - 0.98)
    local cap = (ped ~= 0 and DoesEntityExist(ped)) and GetEntityHeading(ped) or ((sauve and sauve.cap) or 0.0)
    return vector3(c.x + 0.0, c.y + 0.0, z + 0.0), cap
end

local function poserDeSecours(b, raison)
    local c, cap = solDe(b.porteur, b)
    log('pose de secours', b.id, raison)
    poserA(b, 'allonge', c, cap)
end

-- Gare une poussette (poussée) là où elle est ; le bébé éventuel reste dedans. frein : false = frein desserré
local function garerA(po, coords, cap, frein)
    local pousseur = po.pousseur
    if pousseur then
        parPousseur[pousseur] = nil
        po.pousseur = nil
        if present(pousseur) then
            majEtatJoueur(pousseur)
            TriggerClientEvent('elyzea_bebe_modele:poussette:lache', pousseur, po.id)
        end
    end
    po.etat, po.coords, po.cap, po.essais = 'garee', coords, cap, 0
    po.frein = frein ~= false
    po.simulateur, po.simDebut = nil, nil
    if not creerPoussetteEnt(po, coords, cap, true) then return false end
    local b = Bebes[po.bebe or '']
    if b then
        b.pousseur = nil
        if not placer(b) then poserA(b, 'allonge', coords, cap) end
    end
    return true
end

local function garerDeSecours(po, raison)
    local c, cap = solDe(po.pousseur, po)
    if po.ent and DoesEntityExist(po.ent) then
        local e = GetEntityCoords(po.ent)
        if #(vector3(e.x, e.y, 0.0) - vector3(c.x, c.y, 0.0)) < 4.0 then c = vector3(e.x, e.y, c.z) end
    end
    log('poussette garée de secours', po.id, raison)
    garerA(po, c, cap)
end

local function supprimerPoussette(po)
    if po.bebe and Bebes[po.bebe] then
        local c, cap = nacelleMonde(po)
        poserA(Bebes[po.bebe], 'allonge', vector3(c.x, c.y, po.coords.z), cap)
    end
    if po.pousseur then
        parPousseur[po.pousseur] = nil
        if present(po.pousseur) then
            majEtatJoueur(po.pousseur)
            TriggerClientEvent('elyzea_bebe_modele:poussette:lache', po.pousseur, po.id)
        end
    end
    supprimer(po.ent)
    Poussettes[po.id] = nil
    if Persist then Persist.oublierPoussette(po.id) end
end

-- ─────────── Physique : poussette lâchée sans frein (V6) ───────────
-- Le calcul (shared/physique.lua) est fait par UN client proche qui contrôle l'objet (comme les véhicules dans FiveM) :
-- tous les joueurs voient la poussette rouler. À l'arrêt, le client renvoie la position ; le serveur la vérifie,
-- regare la poussette (et le bébé dedans) à cet endroit. Client parti ou silencieux : la poussette est garée là où elle est.
local PH = PO.physique

local function simulateurPour(po, prefere)
    local function proche(src)
        return present(src) and GetPlayerRoutingBucket(src) == (po.bucket or 0)
            and #(GetEntityCoords(GetPlayerPed(src)) - po.coords) <= PH.distanceSimulation
    end
    if prefere and proche(prefere) then return prefere end
    local best, bd
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        if proche(src) then
            local d = #(GetEntityCoords(GetPlayerPed(src)) - po.coords)
            if not bd or d < bd then best, bd = src, d end
        end
    end
    return best
end

local function demarrerSimulation(po, src)
    if not PH.actif or po.frein or po.etat ~= 'garee' or not po.ent then return false end
    local sim = simulateurPour(po, src)
    if not sim then return false end
    po.etat, po.simulateur, po.simDebut = 'libre', sim, GetGameTimer()
    Entity(po.ent).state:set('bebeFrein', false, true)
    local b = Bebes[po.bebe or '']
    TriggerClientEvent('elyzea_bebe_modele:poussette:simuler', sim, po.id, po.net, b and b.nets or nil,
        { x = po.coords.x, y = po.coords.y, z = po.coords.z, cap = po.cap }, PH.parametres)
    log('poussette libre', po.id, 'simulée par', sim)
    return true
end

local function finSimulation(po, coords, cap, renversee)
    po.simulateur, po.simDebut = nil, nil
    if renversee then
        local b = Bebes[po.bebe or '']
        po.etat, po.coords, po.cap, po.frein, po.bebe = 'renversee', coords, cap, true, nil
        if b then
            -- le bébé n'est jamais perdu : il est posé au sol à côté de la poussette renversée
            local r = math.rad(cap)
            b.poussette, b.pousseur = nil, nil
            poserA(b, 'allonge', vector3(coords.x + math.cos(r) * 0.65, coords.y + math.sin(r) * 0.65, coords.z), cap)
        end
        creerPoussetteEnt(po, coords, cap, true)
        log('poussette renversée', po.id)
        return
    end
    garerA(po, coords, cap, po.frein)
end

-- ─────────── Porte-bébés ───────────

local function nomPorteBebe(e)
    local M = BebeModeles.equipements and BebeModeles.equipements[EQ[e.type].modele] or {}
    return M[e.coloris] or M[EQ.coloris] or select(2, next(M))
end

local function demanderAttacheEquipement(src)
    local e = Equip[src]
    e.attacheDemandee = GetGameTimer()
    e.essais = (e.essais or 0) + 1
    TriggerClientEvent('elyzea_bebe_modele:equipement:attacher', src, e.net, e.type)
end

local function creerEquipement(src)
    local e = Equip[src]
    supprimer(e.ent)
    local ped = GetPlayerPed(src)
    e.ent, e.net = creerObjet(nomPorteBebe(e), GetEntityCoords(ped), GetEntityHeading(ped), true, GetPlayerRoutingBucket(src),
        { bebeEquipement = e.type })
    if not e.ent then return false end
    e.essais = 0
    demanderAttacheEquipement(src)
    return true
end

local function retirerEquipement(src)
    local e = Equip[src]
    if not e then return end
    supprimer(e.ent)
    Equip[src] = nil
    majEtatJoueur(src)
end

-- ─────────── Réglages enregistrés (menu admin, via elyzea_famille) ───────────

local MODES_DEC = { 'face', 'ventral', 'dorsal' }
P.decalages = P.decalages or {}

local function publierReglages()
    GlobalState.bebeReglages = {
        ventral = EQ.ventral.actif, dorsal = EQ.dorsal.actif, poussette = PO.actif,
        courseInterdite = PO.courseInterdite, debug = Config.Debug,
        roues = PO.roues ~= false, physique = PO.physique.actif, decalages = P.decalages,
    }
end

local function appliquerReglages(v)
    if type(v) ~= 'table' then return false end
    local function bool(x, def) if type(x) == 'boolean' then return x end return def end
    EQ.ventral.actif = bool(v['bebe.ventral'], EQ.ventral.actif)
    EQ.dorsal.actif = bool(v['bebe.dorsal'], EQ.dorsal.actif)
    PO.actif = bool(v['bebe.poussette'], PO.actif)
    PO.courseInterdite = bool(v['bebe.courseInterdite'], PO.courseInterdite)
    local ab = tonumber(v['bebe.abandon'])
    if ab and ab >= 0 and ab <= 240 then PO.abandon = math.floor(ab) end    -- 0 accepté : rangée dès qu'elle est abandonnée
    Config.Debug = bool(v['bebe.diagnostic'], Config.Debug)
    -- V6
    local function num(k, min, max, cur)
        local x = tonumber(v[k])
        if x and x == x and x >= min and x <= max then return x end
        return cur
    end
    P.reserveAuxResponsables = bool(v['bebe.reserve'], P.reserveAuxResponsables)
    Config.Persistance.garderALaDeconnexion = bool(v['bebe.garder'], Config.Persistance.garderALaDeconnexion)
    PO.physique.actif = bool(v['bebe.physique'], PO.physique.actif)
    PO.roues = bool(v['bebe.roues'], PO.roues ~= false)
    local PP, D = PO.physique.parametres, Physique.defaut
    PP.crr = num('bebe.crr', 0.005, 0.2, PP.crr or D.crr)
    PP.seuilDepart = num('bebe.seuilDepart', 0.0, 0.3, PP.seuilDepart or D.seuilDepart)
    PP.vChoc = num('bebe.vChoc', 1.0, 8.0, PP.vChoc or D.vChoc)
    local M = BebeModeles.equipements or {}
    if M.pb_ventral and M.pb_ventral[v['bebe.colorisPb']] then EQ.coloris = v['bebe.colorisPb'] end
    if M.poussette and M.poussette[v['bebe.colorisPoussette']] then PO.coloris = v['bebe.colorisPoussette'] end
    for _, m in ipairs(MODES_DEC) do
        local d = P.decalages[m] or {}
        P.decalages[m] = {
            x = num(('bebe.dec.%s.x'):format(m), -20, 20, d.x or 0), y = num(('bebe.dec.%s.y'):format(m), -20, 20, d.y or 0),
            z = num(('bebe.dec.%s.z'):format(m), -20, 20, d.z or 0), rz = num(('bebe.dec.%s.rz'):format(m), -45, 45, d.rz or 0),
            rx = num(('bebe.dec.%s.rx'):format(m), -45, 45, d.rx or 0), ry = num(('bebe.dec.%s.ry'):format(m), -45, 45, d.ry or 0),
        }
    end
    publierReglages()
    return true
end

-- ─────────── Création / suppression (exports) ───────────

local function apparencePropre(a)
    a = type(a) == 'table' and a or {}
    local function un(liste, v, def) for _, x in ipairs(liste) do if x == v then return v end end return def end
    local coiffure = a.coiffure == 'chauve' and 'chauve' or un(BebeModeles.coiffures, a.coiffure, Config.Defaut.coiffure)
    return { teinte = un(BebeModeles.teintes, a.teinte, Config.Defaut.teinte), tenue = un(BebeModeles.tenues, a.tenue, Config.Defaut.tenue),
             yeux = un(BebeModeles.yeux, a.yeux, Config.Defaut.yeux), coiffure = coiffure }
end

-- opts : responsables = { citizenid… }, bucket, pose = 'allonge'|'assis', persistant (enregistré en base, ex. naissance),
--        grossesse + rang (naissance : jamais deux fois le même bébé), nom, endormi, id (restauration depuis la base)
function CreerBebe(apparence, coords, cap, opts)
    opts = type(opts) == 'table' and opts or {}
    if opts.grossesse and Persist and Persist.idNaissance then
        local deja = Persist.idNaissance(opts.grossesse, tonumber(opts.rang) or 1)
        if deja then return deja end      -- naissance déjà enregistrée : pas de second bébé
    end
    local id = type(opts.id) == 'string' and opts.id or nouvelId('BB', Bebes)
    if Bebes[id] then return nil end
    local b = { id = id, apparence = apparencePropre(apparence), responsables = opts.responsables, bucket = tonumber(opts.bucket) or 0,
                persistant = opts.persistant == true, grossesse = opts.grossesse, rang = tonumber(opts.rang), nom = opts.nom,
                endormi = opts.endormi == true }
    Bebes[id] = b
    if not poserA(b, opts.pose == 'assis' and 'assis' or 'allonge', vec(coords), tonumber(cap) or 0.0) then
        Bebes[id] = nil
        return nil
    end
    return id
end

-- Bébé « avec » un personnage (déconnecté) : aucune entité, revient à ses pieds à sa connexion (server/persistance.lua)
local function nouveauGarde(apparence, opts, gardien)
    local b = { id = opts.id, apparence = apparencePropre(apparence), responsables = opts.responsables, bucket = tonumber(opts.bucket) or 0,
                persistant = true, grossesse = opts.grossesse, rang = tonumber(opts.rang), nom = opts.nom, endormi = opts.endormi == true,
                etat = 'garde', gardien = gardien }
    Bebes[b.id] = b
    return b
end

function SupprimerBebe(id)
    local b = Bebes[id]
    if not b then return false end
    lacher(b)
    if b.poussette and Poussettes[b.poussette] then
        Poussettes[b.poussette].bebe = nil
        majDedans(Poussettes[b.poussette])
    end
    supprimerEntites(b)
    Bebes[id] = nil
    if Persist then Persist.oublierBebe(id) end
    return true
end

exports('CreerBebe', CreerBebe)
exports('SupprimerBebe', SupprimerBebe)
exports('BebePortePar', function(src) return parPorteur[tonumber(src)] end)
exports('EtatBebe', function(id)
    local b = Bebes[id]
    if not b then return nil end
    return { etat = b.etat, porteur = b.porteur, mode = b.mode, pose = b.pose, poussette = b.poussette, coords = b.coords,
             apparence = b.apparence, endormi = b.endormi == true }
end)
exports('AppliquerReglages', appliquerReglages)

-- ─────────── Vérifications communes ───────────

local function peutAgir(src)
    if occupe[src] then return 'Un instant…' end
    if aTerre(src) then return 'Impossible dans votre état.' end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return 'Impossible en véhicule.' end
    return nil
end

local function procheDe(src, ent, dist)
    if not ent or not DoesEntityExist(ent) then return false end
    return #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(ent)) <= dist
end

local function modeRefuse(src, mode)
    local m = P.modes[mode]
    if not m then return 'Prise inconnue.' end
    if m.equipement then
        local cfg = EQ[m.equipement]
        if not cfg.actif then return cfg.label .. ' : désactivé sur ce serveur.' end
        if not Equip[src] or Equip[src].type ~= m.equipement then return 'Équipez d\'abord votre ' .. cfg.label:lower() .. ' (inventaire).' end
    end
    if m.mainsOccupees and parPousseur[src] then return 'Vous tenez la poussette : garez-la d\'abord.' end
    return nil
end

-- V8 : tout le monde peut prendre un bébé (plus de réservation aux parents ni de /bebe_confier). Les responsables
-- (filiation) ne servent qu'à la garde à la déconnexion, aux notifications des besoins et à la persistance.

-- Exécute un changement sous verrou (bébé + joueur) : aucune autre demande n'est traitée pendant ce temps
local function sousVerrou(src, objets, fn)
    for _, o in ipairs(objets) do if o.verrou then return notify(src, 'Un instant…', 'error') end end
    occupe[src] = true
    for _, o in ipairs(objets) do o.verrou = true end
    local ok, err = pcall(fn)
    for _, o in ipairs(objets) do o.verrou = nil end
    occupe[src] = nil
    if not ok then print('^1[elyzea_bebe_modele] erreur : ' .. tostring(err) .. '^0') end
end

local function alias(mode) return P.alias[mode] or mode end

-- ─────────── Prendre / changer de prise / poser / dormir ───────────

RegisterNetEvent('elyzea_bebe_modele:prendre', function(id, mode)
    local src = source
    if not limite(src, 'prendre', 4, 3000) then return end
    if type(id) ~= 'string' or not Bebes[id] then return end
    mode = alias(mode)
    mode = P.modes[mode] and mode or 'face'
    local b = Bebes[id]
    local err = peutAgir(src)
        or (parPorteur[src] and 'Vous portez déjà un bébé.')
        or ((b.etat ~= 'pose' and b.etat ~= 'poussette') and 'Ce bébé n\'est pas disponible.')
        or (GetPlayerRoutingBucket(src) ~= (b.bucket or 0) and 'Bébé introuvable.')
        or (not procheDe(src, b.ents and b.ents.corps, P.distancePrendre + 0.5) and 'Le bébé est trop loin.')
        or modeRefuse(src, mode)
    local po = b.etat == 'poussette' and Poussettes[b.poussette] or nil
    if not err and po and po.etat == 'poussee' and po.pousseur ~= src then err = 'Quelqu\'un pousse cette poussette.' end
    if not err and po and po.etat == 'libre' then err = 'La poussette roule : rattrapez-la d\'abord (ALT › Pousser).' end
    if err then return notify(src, err, 'error') end
    sousVerrou(src, { b, po or {} }, function()
        if po then
            po.bebe = nil
            majDedans(po)
        end
        b.etat, b.poussette, b.pousseur = 'porte', nil, nil
        b.porteur, b.mode = src, mode
        parPorteur[src] = id
        if not placer(b) then
            parPorteur[src] = nil
            b.porteur, b.mode = nil, nil
            poserA(b, 'allonge', b.coords or GetEntityCoords(GetPlayerPed(src)), b.cap or 0.0)
            return notify(src, 'Erreur, réessayez.', 'error')
        end
        majEtatJoueur(src)
    end)
end)

RegisterNetEvent('elyzea_bebe_modele:mode', function(mode)
    local src = source
    if not limite(src, 'mode', 4, 3000) then return end
    mode = alias(mode)
    local b = Bebes[parPorteur[src] or '']
    if not b or b.etat ~= 'porte' or not P.modes[mode] or b.mode == mode then return end
    local err = peutAgir(src) or modeRefuse(src, mode)
    if err then return notify(src, err, 'error') end
    sousVerrou(src, { b }, function()
        b.mode = mode
        if not placer(b) then return poserDeSecours(b, 'erreur_mode') end
        majEtatJoueur(src)
    end)
end)

RegisterNetEvent('elyzea_bebe_modele:poser', function(pose, coords, cap)
    local src = source
    if not limite(src, 'poser', 4, 3000) then return end
    local b = Bebes[parPorteur[src] or '']
    if not b or b.etat ~= 'porte' or b.verrou then return end
    if not P.poses[pose] or type(coords) ~= 'vector3' and type(coords) ~= 'table' then return end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return end
    local pc = GetEntityCoords(GetPlayerPed(src))
    if #(vector3(pc.x, pc.y, 0.0) - vector3(x, y, 0.0)) > P.distancePoser or math.abs(pc.z - z) > 2.0 then
        return notify(src, 'Endroit trop loin.', 'error')
    end
    sousVerrou(src, { b }, function()
        poserA(b, P.poses[pose].pose, vector3(x, y, z), tonumber(cap) or GetEntityHeading(GetPlayerPed(src)))
    end)
end)

-- Endormir / réveiller : paupières fermées à la place des yeux (tout le monde le voit)
RegisterNetEvent('elyzea_bebe_modele:dormir', function(id)
    local src = source
    if not limite(src, 'dormir', 3, 3000) then return end
    local b = Bebes[id or '']
    if not b or b.verrou or b.etat == 'erreur' then return end
    local a_moi = parPorteur[src] == b.id or (b.poussette and parPousseur[src] == b.poussette)
    if not a_moi and not procheDe(src, b.ents and b.ents.corps, P.distancePrendre + 0.5) then return end
    if peutAgir(src) then return end
    sousVerrou(src, { b }, function()
        b.endormi = not b.endormi
        if not placer(b) then return poserDeSecours(b, 'erreur_dormir') end
        notify(src, b.endormi and 'Le bébé s\'endort.' or 'Le bébé se réveille.', 'inform')
    end)
end)

-- Le joueur confirme l'attache ; il envoie aussi la hauteur du sol (pour reposer le bébé au bon endroit si besoin)
RegisterNetEvent('elyzea_bebe_modele:attache', function(id)
    local src = source
    local b = Bebes[id or '']
    if b and (b.porteur == src or b.pousseur == src) then b.attacheDemandee = nil end
end)

RegisterNetEvent('elyzea_bebe_modele:sol', function(z)
    local src = source
    z = tonumber(z)
    if not z or not limite(src, 'sol', 3, 2000) then return end
    local pc = GetEntityCoords(GetPlayerPed(src))
    if math.abs(pc.z - 1.0 - z) >= 2.5 then return end
    local b = Bebes[parPorteur[src] or '']
    if b then b.solZ = z end
    local po = Poussettes[parPousseur[src] or '']
    if po then po.solZ = z end
end)

-- ─────────── Porte-bébés (objets d'inventaire) ───────────

local function equiper(src, typ)
    local cfg = EQ[typ]
    if not cfg then return end
    if not limite(src, 'equiper', 3, 3000) then return end
    local err = peutAgir(src)
    if err then return notify(src, err, 'error') end
    local b = Bebes[parPorteur[src] or '']
    local actuel = Equip[src]
    if actuel then
        if b and b.etat == 'porte' and b.mode == actuel.type then
            return notify(src, 'Sortez d\'abord le bébé du porte-bébé.', 'error')
        end
        local meme = actuel.type == typ
        retirerEquipement(src)
        notify(src, EQ[actuel.type].label .. ' retiré.', 'inform')
        if meme then return end
    end
    if not cfg.actif then return notify(src, cfg.label .. ' : désactivé sur ce serveur.', 'error') end
    if nbObjets(src, cfg.item) < 1 then return notify(src, 'Objet introuvable dans votre inventaire.', 'error') end
    occupe[src] = true
    Equip[src] = { type = typ, coloris = GetResourceKvpString('coloris_pb:' .. (citizenid(src) or src)) or EQ.coloris }
    local ok = creerEquipement(src)
    occupe[src] = nil
    if not ok then
        Equip[src] = nil
        return notify(src, 'Erreur, réessayez.', 'error')
    end
    majEtatJoueur(src)
    notify(src, cfg.label .. ' équipé. ALT sur le bébé › « ' .. P.modes[typ].label .. ' ».', 'success')
end

RegisterNetEvent('elyzea_bebe_modele:equipement:attache', function()
    local e = Equip[source]
    if e then e.attacheDemandee = nil end
end)

-- ─────────── Poussette ───────────

local function srcDeCid(cid)
    for _, s in ipairs(GetPlayers()) do
        if citizenid(tonumber(s)) == cid then return tonumber(s) end
    end
    return nil
end

local function poussetteDe(src)
    local cid = citizenid(src) or ('src:' .. src)
    for _, po in pairs(Poussettes) do if po.cid == cid then return po end end
    return nil
end

local function sortirPoussette(src, coords, cap)
    if not PO.actif then return notify(src, 'La poussette est désactivée sur ce serveur.', 'error') end
    local err = peutAgir(src)
    if err then return notify(src, err, 'error') end
    if nbObjets(src, PO.item) < 1 then return notify(src, 'Objet introuvable dans votre inventaire.', 'error') end
    if poussetteDe(src) then return notify(src, 'Votre poussette est déjà sortie (ALT dessus › Ranger).', 'error') end
    local x, y, z = tonumber(coords and coords.x), tonumber(coords and coords.y), tonumber(coords and coords.z)
    if not x or not y or not z then return end
    local pc = GetEntityCoords(GetPlayerPed(src))
    if #(vector3(pc.x, pc.y, 0.0) - vector3(x, y, 0.0)) > 3.0 or math.abs(pc.z - z) > 2.5 then return notify(src, 'Endroit trop loin.', 'error') end
    local po = { id = nouvelId('PO', Poussettes), cid = citizenid(src) or ('src:' .. src), proprio = src,
                 coloris = GetResourceKvpString('coloris_po:' .. (citizenid(src) or src)) or PO.coloris,
                 bucket = GetPlayerRoutingBucket(src), etat = 'garee' }
    Poussettes[po.id] = po
    occupe[src] = true
    local ok = garerA(po, vector3(x, y, z), tonumber(cap) or GetEntityHeading(GetPlayerPed(src)))
    occupe[src] = nil
    if not ok then
        Poussettes[po.id] = nil
        return notify(src, 'Erreur, réessayez.', 'error')
    end
    notify(src, 'Poussette sortie. ALT dessus pour la pousser, y installer le bébé ou la ranger.', 'success')
end

RegisterNetEvent('elyzea_bebe_modele:poussette:sortir', function(coords, cap)
    local src = source
    if not limite(src, 'sortir', 2, 3000) then return end
    sortirPoussette(src, coords, cap)
end)

RegisterNetEvent('elyzea_bebe_modele:poussette:pousser', function(pid)
    local src = source
    if not limite(src, 'pousser', 3, 3000) then return end
    local po = Poussettes[pid or '']
    if not po then return end
    local b = Bebes[parPorteur[src] or '']
    local err = (not PO.actif and 'La poussette est désactivée sur ce serveur.') or peutAgir(src)
        or (parPousseur[src] and 'Vous poussez déjà une poussette.')
        or (po.etat == 'poussee' and 'Quelqu\'un pousse déjà cette poussette.')
        or (po.etat == 'renversee' and 'La poussette est renversée : relevez-la d\'abord.')
        or (b and b.etat == 'porte' and P.modes[b.mode].mainsOccupees and 'Vos mains sont occupées (bébé porté contre vous).')
        or (GetPlayerRoutingBucket(src) ~= (po.bucket or 0) and 'Poussette introuvable.')
        or (not procheDe(src, po.ent, PO.distance + 0.5) and 'La poussette est trop loin.')
    if err then return notify(src, err, 'error') end
    local bb = Bebes[po.bebe or '']
    sousVerrou(src, { po, bb or {} }, function()
        if po.etat == 'libre' then
            -- rattrapée en train de rouler : le client qui la simulait arrête (sa position finale sera ignorée)
            if po.simulateur and present(po.simulateur) then TriggerClientEvent('elyzea_bebe_modele:poussette:stopsim', po.simulateur, po.id) end
            po.simulateur, po.simDebut = nil, nil
        end
        po.etat, po.pousseur, po.essais, po.frein = 'poussee', src, 0, false
        parPousseur[src] = po.id
        local ped = GetPlayerPed(src)
        if not creerPoussetteEnt(po, GetEntityCoords(ped), GetEntityHeading(ped), true) then
            return garerDeSecours(po, 'creation')
        end
        po.attacheDemandee = GetGameTimer()
        TriggerClientEvent('elyzea_bebe_modele:poussette:attacher', src, po.id, po.net)
        if bb then
            bb.pousseur = src
            if not placer(bb) then poserDeSecours(bb, 'erreur_poussette') end
        end
        majEtatJoueur(src)
    end)
end)

RegisterNetEvent('elyzea_bebe_modele:poussette:garer', function(coords, cap, sansFrein)
    local src = source
    if not limite(src, 'garer', 3, 3000) then return end
    local po = Poussettes[parPousseur[src] or '']
    if not po or po.verrou then return end
    local x, y, z = tonumber(coords and coords.x), tonumber(coords and coords.y), tonumber(coords and coords.z)
    if not x or not y or not z then return end
    local pc = GetEntityCoords(GetPlayerPed(src))
    if #(vector3(pc.x, pc.y, 0.0) - vector3(x, y, 0.0)) > 3.0 or math.abs(pc.z - z) > 2.5 then
        return garerDeSecours(po, 'position_refusee')
    end
    local bb = Bebes[po.bebe or '']
    sousVerrou(src, { po, bb or {} }, function()
        local lache = sansFrein == true and PH.actif
        garerA(po, vector3(x, y, z), tonumber(cap) or GetEntityHeading(GetPlayerPed(src)), not lache)
        if lache then
            if not demarrerSimulation(po, src) then po.frein = true Entity(po.ent).state:set('bebeFrein', true, true) end
        end
    end)
end)

-- Serrer / desserrer le frein d'une poussette garée (n'importe quel joueur à côté) ; desserré : elle peut rouler
RegisterNetEvent('elyzea_bebe_modele:poussette:frein', function(pid)
    local src = source
    if not limite(src, 'frein', 3, 3000) then return end
    local po = Poussettes[pid or '']
    if not po or po.verrou then return end
    local err = peutAgir(src) or ((po.etat ~= 'garee' and po.etat ~= 'libre') and 'Impossible maintenant.')
        or (not procheDe(src, po.ent, PO.distance + 0.5) and 'La poussette est trop loin.')
    if err then return notify(src, err, 'error') end
    if po.etat == 'libre' then
        -- serrer en roulant : le client simulateur s'arrête et renvoie la position (gérée par « fin »)
        po.frein = true
        if po.simulateur and present(po.simulateur) then TriggerClientEvent('elyzea_bebe_modele:poussette:stopsim', po.simulateur, po.id, true) end
        return notify(src, 'Frein serré.', 'inform')
    end
    po.frein = not po.frein
    Entity(po.ent).state:set('bebeFrein', po.frein, true)
    notify(src, po.frein and 'Frein serré.' or 'Frein desserré.', 'inform')
    if not po.frein then demarrerSimulation(po, src) end
end)

-- Fin de la simulation (arrêt, renversement, frein serré) : position vérifiée par le serveur
RegisterNetEvent('elyzea_bebe_modele:poussette:fin', function(pid, coords, cap, renversee)
    local src = source
    local po = Poussettes[pid or '']
    if not po or po.etat ~= 'libre' or po.simulateur ~= src or po.verrou then return end
    local x, y, z = tonumber(coords and coords.x), tonumber(coords and coords.y), tonumber(coords and coords.z)
    cap = tonumber(cap)
    if not x or not y or not z or not cap then return end
    local c = vector3(x, y, z)
    if #(c - po.coords) > PH.distanceMax then
        -- trajet invraisemblable (client modifié ?) : on garde la position connue du serveur
        log('position de poussette refusée', pid, src)
        c = po.ent and DoesEntityExist(po.ent) and GetEntityCoords(po.ent) or po.coords
        if #(c - po.coords) > PH.distanceMax then c = po.coords end
        renversee = false
    end
    local bb = Bebes[po.bebe or '']
    sousVerrou(src, { po, bb or {} }, function() finSimulation(po, c, cap % 360.0, renversee == true) end)
end)

-- Relever une poussette renversée (frein serré)
RegisterNetEvent('elyzea_bebe_modele:poussette:relever', function(pid)
    local src = source
    if not limite(src, 'relever', 3, 3000) then return end
    local po = Poussettes[pid or '']
    if not po or po.etat ~= 'renversee' or po.verrou then return end
    local err = peutAgir(src) or (not procheDe(src, po.ent, PO.distance + 0.5) and 'La poussette est trop loin.')
    if err then return notify(src, err, 'error') end
    sousVerrou(src, { po }, function() garerA(po, po.coords, po.cap, true) end)
    notify(src, 'Poussette relevée (frein serré).', 'success')
end)

RegisterNetEvent('elyzea_bebe_modele:poussette:attache', function(pid)
    local po = Poussettes[pid or '']
    if po and po.pousseur == source then po.attacheDemandee = nil end
end)

-- Installer le bébé porté dans une poussette (garée à côté, ou celle que l'on pousse)
RegisterNetEvent('elyzea_bebe_modele:poussette:installer', function(pid)
    local src = source
    if not limite(src, 'installer', 3, 3000) then return end
    local po = Poussettes[pid or '']
    local b = Bebes[parPorteur[src] or '']
    if not po or not b or b.etat ~= 'porte' then return end
    local err = (not PO.actif and 'La poussette est désactivée sur ce serveur.') or peutAgir(src)
        or (po.bebe and 'La nacelle est déjà occupée.')
        or (po.etat == 'poussee' and po.pousseur ~= src and 'Quelqu\'un pousse cette poussette.')
        or ((po.etat == 'libre' or po.etat == 'renversee') and 'Impossible maintenant (poussette qui roule ou renversée).')
        or (not procheDe(src, po.ent, PO.distance + 0.5) and 'La poussette est trop loin.')
    if err then return notify(src, err, 'error') end
    sousVerrou(src, { b, po }, function()
        lacher(b)
        b.etat, b.poussette = 'poussette', po.id
        po.bebe = b.id
        majDedans(po)
        if not placer(b) then
            po.bebe = nil
            majDedans(po)
            return poserDeSecours(b, 'erreur_installer')
        end
        notify(src, 'Bébé installé dans la poussette.', 'success')
    end)
end)

RegisterNetEvent('elyzea_bebe_modele:poussette:ranger', function(pid)
    local src = source
    if not limite(src, 'ranger', 3, 3000) then return end
    local po = Poussettes[pid or '']
    if not po then return end
    local err = (po.verrou and 'Un instant…') or ((po.etat ~= 'garee' and po.etat ~= 'renversee') and 'Garez d\'abord la poussette.')
        or (po.bebe and 'Sortez d\'abord le bébé de la poussette.')
        or (po.cid ~= (citizenid(src) or ('src:' .. src)) and not IsPlayerAceAllowed(src, 'command.' .. Config.Staff.supprimer)
            and 'Ce n\'est pas votre poussette.')
        or (not procheDe(src, po.ent, PO.distance + 0.5) and 'La poussette est trop loin.')
    if err then return notify(src, err, 'error') end
    supprimerPoussette(po)
    notify(src, 'Poussette rangée.', 'success')
end)

-- Coloris préféré (porte-bébé / poussette), mémorisé par personnage
RegisterNetEvent('elyzea_bebe_modele:coloris', function(quoi, coloris)
    local src = source
    if not limite(src, 'coloris', 3, 3000) then return end
    local M = BebeModeles.equipements or {}
    local cid = citizenid(src) or tostring(src)
    if quoi == 'pb' and M.pb_ventral and M.pb_ventral[coloris] then
        SetResourceKvp('coloris_pb:' .. cid, coloris)
        local e = Equip[src]
        if e and not occupe[src] then
            e.coloris = coloris
            occupe[src] = true
            creerEquipement(src)
            occupe[src] = nil
        end
        notify(src, 'Coloris du porte-bébé : ' .. coloris, 'success')
    elseif quoi == 'poussette' and M.poussette and M.poussette[coloris] then
        SetResourceKvp('coloris_po:' .. cid, coloris)
        notify(src, 'Coloris de la poussette : ' .. coloris .. ' (à la prochaine sortie).', 'success')
    else
        notify(src, 'Coloris inconnu.', 'error')
    end
end)

-- ─────────── Objets utilisables (inventaire existant, objets jamais consommés) ───────────

local function enregistrerObjets()
    if GetResourceState('elyzea_inventory') ~= 'started' then return end
    local defs = {
        [EQ.ventral.item] = function(src) equiper(src, 'ventral') end,
        [EQ.dorsal.item] = function(src) equiper(src, 'dorsal') end,
        [PO.item] = function(src)
            if not PO.actif then return notify(src, 'La poussette est désactivée sur ce serveur.', 'error') end
            if poussetteDe(src) then return notify(src, 'Votre poussette est déjà sortie (ALT dessus › Ranger).', 'error') end
            TriggerClientEvent('elyzea_bebe_modele:poussette:placer', src)
        end,
    }
    for item, fn in pairs(defs) do
        pcall(function()
            exports.elyzea_inventory:RegisterUsableItem(item, function(source)
                CreateThread(function() fn(source) end)
                return false        -- jamais consommé
            end)
        end)
    end
end
AddEventHandler('elyzea_inventory:ready', enregistrerObjets)

-- ─────────── Départ du joueur (déconnexion, changement de personnage) ───────────

-- Bébé enregistré (naissance) porté au moment du départ : il reste « avec » ce personnage (état « garde », aucune
-- entité dans le monde) et revient à ses pieds à sa prochaine connexion. Bébé de test : reposé au sol.
local function mettreEnGarde(b, cid)
    lacher(b)
    supprimerEntites(b)
    b.etat, b.gardien, b.poussette, b.pousseur = 'garde', cid, nil, nil
    log('bébé gardé par', cid, b.id)
end

local function liberer(src, raison, cidDepart)
    local b = Bebes[parPorteur[src] or '']
    if b then
        local cid = cidDepart or citizenid(src)
        if b.persistant and cid and Config.Persistance.garderALaDeconnexion then mettreEnGarde(b, cid)
        else poserDeSecours(b, raison) end
    end
    parPorteur[src] = nil
    local po = Poussettes[parPousseur[src] or '']
    if po then garerDeSecours(po, raison) end
    parPousseur[src] = nil
    retirerEquipement(src)
    for _, p in pairs(Poussettes) do if p.proprio == src then p.proprio = nil end end
    occupe[src] = nil
end

AddEventHandler('playerDropped', function() liberer(source, 'deconnexion') end)
AddEventHandler('elyzea:server:playerUnloaded', function(src, cid) liberer(tonumber(src) or src, 'changement_personnage', cid) end)

-- ─────────── Vérifications périodiques ───────────

local function verifier()
    for src, id in pairs(parPorteur) do
        local b = Bebes[id]
        if not b or b.etat ~= 'porte' then
            parPorteur[src] = nil
        elseif not b.verrou then
            if not present(src) then
                poserDeSecours(b, 'absent')
            elseif aTerre(src) then
                poserDeSecours(b, 'a_terre')
                notify(src, 'Vous avez lâché le bébé.', 'error')
            else
                local ped = GetPlayerPed(src)
                b.dernierePos = GetEntityCoords(ped)
                local corps = b.ents and b.ents.corps
                if not corps or not DoesEntityExist(corps) then
                    poserDeSecours(b, 'entite_perdue')
                elseif GetEntityAttachedTo(corps) ~= ped then
                    -- pas (ou plus) attaché : on redemande, puis on repose le bébé si cela échoue
                    if (b.essais or 0) >= 3 then
                        poserDeSecours(b, 'attache_impossible')
                        notify(src, 'Le bébé n\'a pas pu être porté : il a été reposé.', 'error')
                    elseif not b.attacheDemandee or GetGameTimer() - b.attacheDemandee > 4000 then
                        demanderAttache(b)
                    end
                else
                    b.essais = 0
                end
            end
        end
    end
    for src, pid in pairs(parPousseur) do
        local po = Poussettes[pid]
        if not po or po.etat ~= 'poussee' then
            parPousseur[src] = nil
        elseif not po.verrou then
            if not present(src) then
                garerDeSecours(po, 'absent')
            elseif aTerre(src) then
                garerDeSecours(po, 'a_terre')
                notify(src, 'Vous avez lâché la poussette.', 'error')
            else
                local ped = GetPlayerPed(src)
                po.dernierePos = GetEntityCoords(ped)
                if not po.ent or not DoesEntityExist(po.ent) then
                    garerDeSecours(po, 'entite_perdue')
                elseif GetEntityAttachedTo(po.ent) ~= ped then
                    if (po.essais or 0) >= 3 then
                        garerDeSecours(po, 'attache_impossible')
                    elseif not po.attacheDemandee or GetGameTimer() - po.attacheDemandee > 4000 then
                        po.essais = (po.essais or 0) + 1
                        po.attacheDemandee = GetGameTimer()
                        TriggerClientEvent('elyzea_bebe_modele:poussette:attacher', src, po.id, po.net)
                    end
                else
                    po.essais = 0
                end
                local bb = Bebes[po.bebe or '']
                if bb and not bb.verrou then
                    local corps = bb.ents and bb.ents.corps
                    if not corps or not DoesEntityExist(corps) then
                        if not placer(bb) then poserDeSecours(bb, 'entite_perdue') end
                    elseif GetEntityAttachedTo(corps) ~= po.ent then
                        if (bb.essais or 0) >= 3 then
                            po.bebe, bb.poussette, bb.pousseur = nil, nil, nil
                            majDedans(po)
                            local c, cap = solDe(src, po)
                            poserA(bb, 'allonge', c, cap)
                        elseif not bb.attacheDemandee or GetGameTimer() - bb.attacheDemandee > 4000 then
                            demanderAttache(bb)
                        end
                    else
                        bb.essais = 0
                    end
                end
            end
        end
    end
    for src, e in pairs(Equip) do
        if not present(src) then
            supprimer(e.ent)
            Equip[src] = nil
        elseif not occupe[src] then
            local ped = GetPlayerPed(src)
            if not e.ent or not DoesEntityExist(e.ent) then
                if not creerEquipement(src) then retirerEquipement(src) end
            elseif GetEntityAttachedTo(e.ent) ~= ped then
                if (e.essais or 0) >= 3 then
                    local b = Bebes[parPorteur[src] or '']
                    if b and b.mode == e.type then poserDeSecours(b, 'equipement_perdu') end
                    retirerEquipement(src)
                    notify(src, 'Le porte-bébé n\'a pas pu être équipé.', 'error')
                elseif not e.attacheDemandee or GetGameTimer() - e.attacheDemandee > 4000 then
                    demanderAttacheEquipement(src)
                end
            else
                e.essais = 0
            end
        end
    end
    -- poussettes qui roulent : client simulateur parti, ou simulation trop longue -> garées là où elles sont
    local now = GetGameTimer()
    for _, po in pairs(Poussettes) do
        if po.etat == 'libre' and not po.verrou and (not present(po.simulateur) or now - (po.simDebut or now) > PH.dureeMax * 1000) then
            local c = po.ent and DoesEntityExist(po.ent) and GetEntityCoords(po.ent) or po.coords
            if #(c - po.coords) > PH.distanceMax then c = po.coords end
            local cap = po.ent and DoesEntityExist(po.ent) and GetEntityHeading(po.ent) or po.cap
            log('poussette libre sans simulateur : garée', po.id)
            finSimulation(po, c, cap, false)
        end
    end
    -- poussettes vides abandonnées (propriétaire parti ou loin) : supprimées après PO.abandon minutes
    for _, po in pairs(Poussettes) do
        if (po.etat == 'garee' or po.etat == 'renversee') and not po.bebe and not po.verrou then
            local loin = true
            if not (po.proprio and present(po.proprio)) then po.proprio = srcDeCid(po.cid) end   -- propriétaire revenu
            if po.proprio and present(po.proprio) and po.coords then
                loin = #(GetEntityCoords(GetPlayerPed(po.proprio)) - po.coords) > PO.distanceAbandon
            end
            if loin then
                po.abandonDepuis = po.abandonDepuis or now
                if now - po.abandonDepuis >= PO.abandon * 60000 then
                    log('poussette abandonnée supprimée', po.id)
                    supprimerPoussette(po)
                end
            else
                po.abandonDepuis = nil
            end
        end
    end
end

CreateThread(function()
    enregistrerObjets()
    publierReglages()
    if GetResourceState('elyzea_famille') == 'started' then
        local ok, v = pcall(function() return exports.elyzea_famille:ReglagesBebe() end)
        if ok and v then appliquerReglages(v) end
    end
    while true do
        Wait(P.verification)
        verifier()
        if Persist then Persist.enregistrer() end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in pairs(Bebes) do supprimerEntites(b) end
    for _, po in pairs(Poussettes) do supprimer(po.ent) end
    for src, e in pairs(Equip) do supprimer(e.ent) end
    for _, t in ipairs({ parPorteur, parPousseur, Equip }) do
        for src in pairs(t) do
            if present(src) then
                Player(src).state:set('bebePorte', nil, true)
                Player(src).state:set('bebePoussette', nil, true)
                Player(src).state:set('bebeEquipement', nil, true)
            end
        end
    end
end)

-- ─────────── Combat : le porteur / pousseur ne peut pas frapper (aucune protection pour lui) ───────────

local MELEE = {}
for _, w in ipairs({ 'WEAPON_UNARMED', 'WEAPON_KNIFE', 'WEAPON_NIGHTSTICK', 'WEAPON_HAMMER', 'WEAPON_BAT', 'WEAPON_GOLFCLUB',
    'WEAPON_CROWBAR', 'WEAPON_BOTTLE', 'WEAPON_DAGGER', 'WEAPON_HATCHET', 'WEAPON_KNUCKLE', 'WEAPON_MACHETE',
    'WEAPON_SWITCHBLADE', 'WEAPON_WRENCH', 'WEAPON_BATTLEAXE', 'WEAPON_POOLCUE', 'WEAPON_STONE_HATCHET', 'WEAPON_FLASHLIGHT',
    'WEAPON_CANDYCANE' }) do
    MELEE[joaat(w)] = true
    MELEE[joaat(w) & 0xFFFFFFFF] = true
end

-- Dégâts envoyés par un porteur (ou pousseur avec un bébé) avec une attaque de mêlée : annulés (protection côté
-- serveur contre un client modifié). Les dégâts REÇUS ne sont jamais touchés.
AddEventHandler('weaponDamageEvent', function(sender, data)
    if not P.bloquerMelee then return end
    sender = tonumber(sender)
    if (parPorteur[sender] or parPousseur[sender]) and type(data) == 'table' and MELEE[tonumber(data.weaponType) or 0] then
        CancelEvent()
        log('coup annulé', sender)
    end
end)

-- ─────────── Commandes staff ───────────

local function devant(src, dist)
    local ped = GetPlayerPed(src)
    local c, cap = GetEntityCoords(ped), GetEntityHeading(ped)
    local r = math.rad(cap)
    return vector3(c.x - math.sin(r) * dist, c.y + math.cos(r) * dist, c.z - 0.98), cap
end

RegisterCommand(Config.Staff.creer, function(src, args)
    if src == 0 then return print('Commande à lancer en jeu.') end
    local c, cap = devant(src, 0.9)
    local id = CreerBebe({ teinte = args[1], yeux = args[2], coiffure = args[3], tenue = args[4] }, c, cap + 90.0, { bucket = GetPlayerRoutingBucket(src) })
    if id then
        notify(src, ('Bébé %s créé devant vous (visible par tous). ALT pour le prendre.'):format(id), 'success')
    else
        notify(src, 'Création impossible (voir la console serveur).', 'error')
    end
end, true)

RegisterCommand(Config.Staff.supprimer, function(src, args)
    -- les bébés enregistrés (nés en jeu) ne sont supprimés qu'avec « definitif » (suppression en base)
    local definitif = args[1] == 'definitif' or args[2] == 'definitif'
    if args[1] == 'tous' then
        local n, gardes = 0, 0
        for id, b in pairs(Bebes) do
            if not b.persistant or definitif then SupprimerBebe(id) n = n + 1 else gardes = gardes + 1 end
        end
        for _, po in pairs(Poussettes) do if not po.bebe then supprimerPoussette(po) end end
        local txt = ('%d bébé(s) supprimé(s), poussettes vides rangées.%s'):format(n,
            gardes > 0 and (' %d bébé(s) enregistré(s) conservé(s) (ajoutez « definitif » pour les supprimer).'):format(gardes) or '')
        return src ~= 0 and notify(src, txt, 'success') or print(txt)
    end
    if src == 0 then return print('Usage en jeu : /' .. Config.Staff.supprimer .. ' (bébé ou poussette vide le plus proche) ou « tous »') end
    local pc = GetEntityCoords(GetPlayerPed(src))
    local best, bestD, kind
    for id, b in pairs(Bebes) do
        local e = b.ents and b.ents.corps
        if e and DoesEntityExist(e) then
            local d = #(pc - GetEntityCoords(e))
            if d < 5.0 and (not bestD or d < bestD) then best, bestD, kind = id, d, 'bebe' end
        end
    end
    for id, po in pairs(Poussettes) do
        if po.ent and DoesEntityExist(po.ent) and not po.bebe then
            local d = #(pc - GetEntityCoords(po.ent))
            if d < 5.0 and (not bestD or d < bestD) then best, bestD, kind = id, d, 'poussette' end
        end
    end
    if kind == 'bebe' and Bebes[best].persistant and not definitif then
        return notify(src, 'Bébé enregistré (né en jeu) : « /' .. Config.Staff.supprimer .. ' definitif » pour le supprimer pour de bon.', 'error')
    end
    if kind == 'bebe' and SupprimerBebe(best) then return notify(src, 'Bébé supprimé.', 'success') end
    if kind == 'poussette' then supprimerPoussette(Poussettes[best]) return notify(src, 'Poussette supprimée.', 'success') end
    notify(src, 'Rien à moins de 5 m.', 'error')
end, true)

RegisterCommand(Config.Staff.ajuster, function(src, args)
    if src == 0 then return end
    local cible = (args[1] == 'equipement' or args[1] == 'poussette') and table.remove(args, 1) or 'bebe'
    if cible == 'bebe' and not parPorteur[src] then return notify(src, 'Portez d\'abord un bébé.', 'error') end
    if cible == 'equipement' and not Equip[src] then return notify(src, 'Équipez d\'abord un porte-bébé.', 'error') end
    if cible == 'poussette' and not parPousseur[src] then return notify(src, 'Poussez d\'abord une poussette.', 'error') end
    TriggerClientEvent('elyzea_bebe_modele:ajuster', src, cible, args)
end, true)

local function diagnostic()
    local lignes = {}
    for id, b in pairs(Bebes) do
        lignes[#lignes + 1] = ('bébé %s : %s%s%s%s%s%s'):format(id, b.etat, b.mode and (' · ' .. b.mode) or '', b.porteur and (' · porteur ' .. b.porteur) or '',
            b.poussette and (' · poussette ' .. b.poussette) or '', b.gardien and (' · avec ' .. b.gardien) or '',
            b.persistant and ' · enregistré' or ' · test (non enregistré)')
    end
    for id, po in pairs(Poussettes) do
        lignes[#lignes + 1] = ('poussette %s : %s%s · %s%s%s'):format(id, po.etat, po.frein == false and ' (frein desserré)' or '', po.cid or '?',
            po.pousseur and (' · pousseur ' .. po.pousseur) or '',
            po.bebe and (' · bébé ' .. po.bebe) or '')
    end
    for s, e in pairs(Equip) do lignes[#lignes + 1] = ('porte-bébé %s (%s) : joueur %s'):format(e.type, e.coloris, s) end
    table.sort(lignes)
    return lignes
end
exports('Diagnostic', diagnostic)        -- lu par le menu admin (onglet Famille)

RegisterCommand(Config.Staff.diagnostic, function(src)
    local lignes = diagnostic()
    local txt = #lignes > 0 and table.concat(lignes, '\n') or 'aucun bébé, aucune poussette, aucun porte-bébé'
    print('[elyzea_bebe_modele] diagnostic\n' .. txt)
    if src ~= 0 then notify(src, ('%d élément(s) : détail dans la console serveur.'):format(#lignes), 'inform') end
end, true)

-- Pour les tests et le diagnostic
function BebesDebug() return Bebes, parPorteur, Poussettes, parPousseur, Equip end

-- Accès interne pour server/persistance.lua (chargé après ce fichier)
BB = {
    Bebes = Bebes, Poussettes = Poussettes, parPorteur = parPorteur, parPousseur = parPousseur,
    citizenid = citizenid, notify = notify, present = present, log = log,
    poserA = poserA, garerA = garerA, nouveauGarde = nouveauGarde, placer = placer, majDedans = majDedans, devant = devant, nouvelId = nouvelId,
}
