-- =====================================================================
--  ELYZEA BÉBÉ (modèle) - serveur : bébés en réseau et portage
--
--  Principe : chaque bébé existe UNE fois, sur le serveur. Ses pièces (corps, yeux, cheveux) sont des objets
--  réseau créés par le serveur : tous les joueurs proches voient les mêmes entités.
--   · posé  : les 3 pièces sont figées au même endroit et dans le même angle (elles ont la même origine,
--             elles se superposent exactement, aucun client n'est nécessaire) ;
--   · porté : le porteur prend le contrôle des pièces et les attache à son personnage (l'attache est
--             synchronisée par FiveM pour tout le monde) ; le serveur vérifie l'attache toutes les 2 s.
--  Mort, coma, déconnexion, arrêt de la ressource : le bébé est reposé (ou supprimé à l'arrêt), jamais perdu
--  ni dupliqué. Le porteur ne peut pas frapper (contrôles bloqués chez lui + dégâts de mêlée annulés ici)
--  et ne reçoit AUCUNE protection : les autres joueurs peuvent le frapper normalement.
--
--  Exports serveur (pour la future ressource enfants / naissance) :
--    local id = exports.elyzea_bebe_modele:CreerBebe(apparence, coords, cap, { responsables = { citizenid, ... }, bucket = 0 })
--    exports.elyzea_bebe_modele:SupprimerBebe(id)
--    exports.elyzea_bebe_modele:EtatBebe(id) -> { etat = 'pose' | 'porte', porteur, mode, pose, coords }
--    exports.elyzea_bebe_modele:BebePortePar(src) -> id ou nil
-- =====================================================================
local P = Config.Portage
local Bebes = {}        -- [id] = bébé
local parPorteur = {}   -- [src] = id du bébé porté
local seq = 0

local function log(...) if Config.Debug then print('[elyzea_bebe_modele]', ...) end end
local function notify(src, msg, kind) pcall(function() exports.elyzea_core:Notify(src, msg, kind or 'inform') end) end

local function limite(src, cle, max, ms)
    Limites = Limites or {}
    local k = src .. ':' .. cle
    local now = GetGameTimer()
    local b = Limites[k]
    if not b or now - b.t > ms then Limites[k] = { t = now, n = 1 } return true end
    b.n = b.n + 1
    return b.n <= max
end

local function vec(c) return vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0) end

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

-- ─────────── Entités ───────────

local PIECES = { 'corps', 'yeux', 'cheveux' }

local function nomsModeles(b, pose)
    local M = BebeModeles.poses[pose]
    local a = b.apparence
    return {
        corps = M.corps[a.teinte .. '_' .. a.tenue],
        yeux = M.yeux[a.yeux],
        cheveux = a.coiffure ~= 'chauve' and M.cheveux[a.coiffure] or nil,
    }
end

local function supprimerEntites(b)
    for _, k in ipairs(PIECES) do
        local e = b.ents and b.ents[k]
        if e and DoesEntityExist(e) then DeleteEntity(e) end
    end
    b.ents, b.nets = nil, nil
end

-- Crée les pièces d'une pose, figées (le porteur les libère en les attachant). Renvoie true ou false.
local function creerEntites(b, pose, coords, cap, figer)
    local noms = nomsModeles(b, pose)
    local ents, nets = {}, {}
    for _, k in ipairs(PIECES) do
        if noms[k] then
            local e = CreateObjectNoOffset(joaat(noms[k]), coords.x, coords.y, coords.z, true, true, false)
            local t = GetGameTimer() + 3000
            while not DoesEntityExist(e) and GetGameTimer() < t do Wait(0) end
            if not DoesEntityExist(e) then
                b.ents = ents
                supprimerEntites(b)
                print(('^1[elyzea_bebe_modele] création de %s impossible (OneSync activé ?)^0'):format(noms[k]))
                return false
            end
            pcall(SetEntityOrphanMode, e, 2)          -- garder l'entité même si aucun joueur n'est proche
            SetEntityRoutingBucket(e, b.bucket or 0)
            SetEntityHeading(e, cap + 0.0)
            FreezeEntityPosition(e, figer == true)
            Entity(e).state:set('bebe', b.id, true)
            Entity(e).state:set('bebePiece', k, true)
            ents[k] = e
            nets[k] = NetworkGetNetworkIdFromEntity(e)
        end
    end
    b.ents, b.nets, b.pose = ents, nets, pose
    return true
end

local function majEtatJoueur(src, b)
    Player(src).state:set('bebePorte', b and { id = b.id, mode = b.mode, mains = P.modes[b.mode].mainsOccupees == true } or nil, true)
end

-- Demande au porteur d'attacher les pièces à son personnage
local function demanderAttache(b)
    b.attacheDemandee = GetGameTimer()
    b.essais = (b.essais or 0) + 1
    TriggerClientEvent('elyzea_bebe_modele:attacher', b.porteur, b.id, b.nets, b.mode)
end

-- ─────────── Poser ───────────

-- Pose le bébé (porté ou non) à un endroit. Interne : aucune vérification de distance ici.
local function poserA(b, pose, coords, cap)
    local porteur = b.porteur
    supprimerEntites(b)
    b.etat, b.porteur, b.mode, b.essais = 'pose', nil, nil, 0
    b.coords, b.cap = coords, cap
    if porteur then
        parPorteur[porteur] = nil
        if GetPlayerName(porteur) then
            majEtatJoueur(porteur, nil)
            TriggerClientEvent('elyzea_bebe_modele:lache', porteur, b.id)
        end
    end
    if not creerEntites(b, pose, coords, cap, true) then
        b.etat = 'erreur'
        return false
    end
    log('posé', b.id, pose, coords)
    return true
end

-- Position de repli quand le porteur ne peut plus choisir (mort, déconnexion) : là où il était, au sol
local function poserDeSecours(b, raison)
    local src = b.porteur
    local ped = src and GetPlayerPed(src) or 0
    local c = b.dernierePos
    if ped ~= 0 and DoesEntityExist(ped) then
        local pc = GetEntityCoords(ped)
        if pc.x ~= 0.0 or pc.y ~= 0.0 then c = pc end
    end
    c = c or b.coords
    local z = (b.solZ and c and math.abs(b.solZ - (c.z - 1.0)) < 2.5) and b.solZ or (c.z - 0.98)
    local cap = (ped ~= 0 and DoesEntityExist(ped)) and GetEntityHeading(ped) or (b.cap or 0.0)
    log('pose de secours', b.id, raison)
    poserA(b, 'allonge', vector3(c.x + 0.0, c.y + 0.0, z + 0.0), cap)
end

-- ─────────── Création / suppression (exports) ───────────

local function apparencePropre(a)
    a = type(a) == 'table' and a or {}
    local function un(liste, v, def) for _, x in ipairs(liste) do if x == v then return v end end return def end
    local coiffure = a.coiffure == 'chauve' and 'chauve' or un(BebeModeles.coiffures, a.coiffure, Config.Defaut.coiffure)
    return { teinte = un(BebeModeles.teintes, a.teinte, Config.Defaut.teinte), tenue = un(BebeModeles.tenues, a.tenue, Config.Defaut.tenue),
             yeux = un(BebeModeles.yeux, a.yeux, Config.Defaut.yeux), coiffure = coiffure }
end

function CreerBebe(apparence, coords, cap, opts)
    opts = type(opts) == 'table' and opts or {}
    seq = seq + 1
    local id = ('BB-%d-%d'):format(os.time() % 100000, seq)
    local b = { id = id, apparence = apparencePropre(apparence), responsables = opts.responsables, bucket = tonumber(opts.bucket) or 0 }
    Bebes[id] = b
    if not poserA(b, opts.pose == 'assis' and 'assis' or 'allonge', vec(coords), tonumber(cap) or 0.0) then
        Bebes[id] = nil
        return nil
    end
    return id
end

function SupprimerBebe(id)
    local b = Bebes[id]
    if not b then return false end
    if b.porteur then
        parPorteur[b.porteur] = nil
        if GetPlayerName(b.porteur) then
            majEtatJoueur(b.porteur, nil)
            TriggerClientEvent('elyzea_bebe_modele:lache', b.porteur, b.id)
        end
    end
    supprimerEntites(b)
    Bebes[id] = nil
    return true
end

exports('CreerBebe', CreerBebe)
exports('SupprimerBebe', SupprimerBebe)
exports('BebePortePar', function(src) return parPorteur[tonumber(src)] end)
exports('EtatBebe', function(id)
    local b = Bebes[id]
    if not b then return nil end
    return { etat = b.etat, porteur = b.porteur, mode = b.mode, pose = b.pose, coords = b.coords, apparence = b.apparence }
end)

-- ─────────── Prendre / changer de mode / poser (demandes des joueurs) ───────────

local function peutPrendre(src, b)
    if b.etat ~= 'pose' or b.verrou then return 'Ce bébé n\'est pas disponible.' end
    if parPorteur[src] then return 'Vous portez déjà un bébé.' end
    if aTerre(src) then return 'Impossible dans votre état.' end
    local ped = GetPlayerPed(src)
    if GetVehiclePedIsIn(ped, false) ~= 0 then return 'Impossible en véhicule.' end
    if GetPlayerRoutingBucket(src) ~= (b.bucket or 0) then return 'Bébé introuvable.' end
    local corps = b.ents and b.ents.corps
    if not corps or not DoesEntityExist(corps) then return 'Bébé introuvable.' end
    if #(GetEntityCoords(ped) - GetEntityCoords(corps)) > P.distancePrendre + 0.5 then return 'Le bébé est trop loin.' end
    if P.reserveAuxResponsables and type(b.responsables) == 'table' and #b.responsables > 0 then
        local cid = citizenid(src)
        local ok = false
        for _, r in ipairs(b.responsables) do if r == cid then ok = true end end
        if not ok then return 'Ce n\'est pas votre enfant.' end
    end
    return nil
end

RegisterNetEvent('elyzea_bebe_modele:prendre', function(id, mode)
    local src = source
    if not limite(src, 'prendre', 4, 3000) then return end
    if type(id) ~= 'string' or not Bebes[id] then return end
    mode = P.modes[mode] and mode or 'bras'
    local b = Bebes[id]
    local err = peutPrendre(src, b)
    if err then return notify(src, err, 'error') end
    b.verrou = true
    local ped = GetPlayerPed(src)
    supprimerEntites(b)
    local ok = creerEntites(b, P.modes[mode].pose, GetEntityCoords(ped), GetEntityHeading(ped), true)
    b.verrou = nil
    if not ok then
        poserA(b, 'allonge', b.coords, b.cap or 0.0)
        return notify(src, 'Erreur, réessayez.', 'error')
    end
    b.etat, b.porteur, b.mode, b.essais = 'porte', src, mode, 0
    parPorteur[src] = id
    majEtatJoueur(src, b)
    demanderAttache(b)
end)

RegisterNetEvent('elyzea_bebe_modele:mode', function(mode)
    local src = source
    if not limite(src, 'mode', 4, 3000) then return end
    local b = Bebes[parPorteur[src] or '']
    if not b or not P.modes[mode] or b.mode == mode then return end
    local pose = P.modes[mode].pose
    if pose ~= b.pose then
        local ped = GetPlayerPed(src)
        supprimerEntites(b)
        if not creerEntites(b, pose, GetEntityCoords(ped), GetEntityHeading(ped), true) then
            return poserDeSecours(b, 'erreur_mode')
        end
    end
    b.mode, b.essais = mode, 0
    majEtatJoueur(src, b)
    demanderAttache(b)
end)

RegisterNetEvent('elyzea_bebe_modele:poser', function(pose, coords, cap)
    local src = source
    if not limite(src, 'poser', 4, 3000) then return end
    local b = Bebes[parPorteur[src] or '']
    if not b then return end
    if not P.poses[pose] or type(coords) ~= 'vector3' and type(coords) ~= 'table' then return end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return end
    local pc = GetEntityCoords(GetPlayerPed(src))
    local c = vector3(x, y, z)
    if #(vector3(pc.x, pc.y, 0.0) - vector3(x, y, 0.0)) > P.distancePoser or math.abs(pc.z - z) > 2.0 then
        return notify(src, 'Endroit trop loin.', 'error')
    end
    poserA(b, P.poses[pose].pose, c, tonumber(cap) or GetEntityHeading(GetPlayerPed(src)))
end)

-- Le porteur confirme l'attache ; il envoie aussi la hauteur du sol (pour reposer le bébé au bon endroit si besoin)
RegisterNetEvent('elyzea_bebe_modele:attache', function(id)
    local src = source
    local b = Bebes[id or '']
    if b and b.porteur == src then b.attacheDemandee = nil end
end)

RegisterNetEvent('elyzea_bebe_modele:sol', function(z)
    local src = source
    local b = Bebes[parPorteur[src] or '']
    z = tonumber(z)
    if not b or not z or not limite(src, 'sol', 3, 2000) then return end
    local pc = GetEntityCoords(GetPlayerPed(src))
    if math.abs(pc.z - 1.0 - z) < 2.5 then b.solZ = z end
end)

-- ─────────── Vérifications périodiques ───────────

CreateThread(function()
    while true do
        Wait(P.verification)
        for src, id in pairs(parPorteur) do
            local b = Bebes[id]
            if not b then
                parPorteur[src] = nil
            elseif not GetPlayerName(src) then
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
end)

AddEventHandler('playerDropped', function()
    local src = source
    local b = Bebes[parPorteur[src] or '']
    if b then poserDeSecours(b, 'deconnexion') end
    parPorteur[src] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in pairs(Bebes) do supprimerEntites(b) end
    for src in pairs(parPorteur) do if GetPlayerName(src) then Player(src).state:set('bebePorte', nil, true) end end
end)

-- ─────────── Combat : le porteur ne peut pas frapper (aucune protection pour lui) ───────────

local MELEE = {}
for _, w in ipairs({ 'WEAPON_UNARMED', 'WEAPON_KNIFE', 'WEAPON_NIGHTSTICK', 'WEAPON_HAMMER', 'WEAPON_BAT', 'WEAPON_GOLFCLUB',
    'WEAPON_CROWBAR', 'WEAPON_BOTTLE', 'WEAPON_DAGGER', 'WEAPON_HATCHET', 'WEAPON_KNUCKLE', 'WEAPON_MACHETE',
    'WEAPON_SWITCHBLADE', 'WEAPON_WRENCH', 'WEAPON_BATTLEAXE', 'WEAPON_POOLCUE', 'WEAPON_STONE_HATCHET', 'WEAPON_FLASHLIGHT',
    'WEAPON_CANDYCANE' }) do
    MELEE[joaat(w)] = true
    MELEE[joaat(w) & 0xFFFFFFFF] = true
end

-- Dégâts envoyés par un porteur avec une attaque de mêlée : annulés (protection côté serveur contre un client modifié).
-- Les dégâts REÇUS par le porteur ne sont jamais touchés.
AddEventHandler('weaponDamageEvent', function(sender, data)
    if not P.bloquerMelee then return end
    if parPorteur[tonumber(sender)] and type(data) == 'table' and MELEE[tonumber(data.weaponType) or 0] then
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
    if args[1] == 'tous' then
        local n = 0
        for id in pairs(Bebes) do SupprimerBebe(id) n = n + 1 end
        return src ~= 0 and notify(src, ('%d bébé(s) supprimé(s).'):format(n), 'success') or print(n .. ' bébé(s) supprimé(s)')
    end
    if src == 0 then return print('Usage en jeu : /' .. Config.Staff.supprimer .. ' (bébé le plus proche) ou « tous »') end
    local pc = GetEntityCoords(GetPlayerPed(src))
    local best, bestD
    for id, b in pairs(Bebes) do
        local e = b.ents and b.ents.corps
        if e and DoesEntityExist(e) then
            local d = #(pc - GetEntityCoords(e))
            if d < 5.0 and (not bestD or d < bestD) then best, bestD = id, d end
        end
    end
    if best and SupprimerBebe(best) then notify(src, 'Bébé supprimé.', 'success') else notify(src, 'Aucun bébé à moins de 5 m.', 'error') end
end, true)

RegisterCommand(Config.Staff.ajuster, function(src, args)
    if src == 0 or not parPorteur[src] then return src ~= 0 and notify(src, 'Portez d\'abord un bébé.', 'error') end
    TriggerClientEvent('elyzea_bebe_modele:ajuster', src, args)
end, true)

-- Pour les tests et le diagnostic
function BebesDebug() return Bebes, parPorteur end
