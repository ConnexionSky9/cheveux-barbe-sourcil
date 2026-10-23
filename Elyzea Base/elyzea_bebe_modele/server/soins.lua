-- =====================================================================
--  ELYZEA BÉBÉ - serveur : soins et besoins du bébé (V8)
--  · Trois jauges par bébé, de 0 à 100 : faim (et soif : le biberon de lait fait les deux), fatigue, couche.
--    Elles évoluent avec le temps (Config.Soins, réglables dans le menu admin) et sont enregistrées en base
--    (rp_bebes.besoins, server/persistance.lua) : elles reprennent après une reconnexion ou un redémarrage.
--  · Soins (menu ALT sur le bébé, ou objet utilisé depuis l'inventaire) : donner le biberon, changer la couche,
--    habiller / déshabiller. Le serveur vérifie tout : distance, objet présent, un seul soin à la fois par bébé
--    et par joueur ; l'objet est retiré UNE fois, au début du soin.
--  · Notifications discrètes au porteur, sinon au pousseur, sinon aux parents connectés (responsables) ; seuils,
--    rappels espacés, aucune répétition tant que le besoin ne change pas de niveau.
-- =====================================================================
local SO = Config.Soins
local enSoin = {}            -- [src] = id du bébé dont le joueur s'occupe

local function clamp(x) return math.max(0.0, math.min(100.0, x)) end

local function besoins(b)
    if type(b.besoins) ~= 'table' then b.besoins = { faim = 20, fatigue = 10, couche = 0 } end
    local n = b.besoins
    n.faim, n.fatigue, n.couche = tonumber(n.faim) or 20, tonumber(n.fatigue) or 10, tonumber(n.couche) or 0
    n.at = tonumber(n.at) or os.time()
    return n
end

-- Fait avancer les jauges jusqu'à « now » (secondes réelles × vitesse)
local function avancer(b, now)
    local n = besoins(b)
    local dt = now - n.at
    n.at = now
    if dt <= 0 or b.etat == 'erreur' then return end
    if b.etat == 'garde' and SO.pauseGarde then return end
    dt = math.min(dt, (tonumber(SO.rattrapageMax) or 12) * 3600)
    local h = dt * (tonumber(SO.vitesse) or 1) / 3600
    n.faim = clamp(n.faim + SO.parHeure.faim * h)
    n.couche = clamp(n.couche + SO.parHeure.couche * h)
    if b.endormi then
        local couche = b.etat == 'pose' or b.etat == 'poussette'
        n.fatigue = clamp(n.fatigue - (couche and SO.recuperation.couche or SO.recuperation.porte) * h)
    else
        n.fatigue = clamp(n.fatigue + SO.parHeure.fatigue * h)
    end
end

-- Qui prévenir : le porteur, sinon le pousseur, sinon les parents connectés. Bébé « avec » un personnage
-- déconnecté : personne (ses besoins sont en pause).
local function destinataires(b)
    if b.etat == 'porte' and b.porteur and BB.present(b.porteur) then return { b.porteur } end
    if b.etat == 'garde' then return {} end
    if b.etat == 'poussette' then
        local po = BB.Poussettes[b.poussette or '']
        if po and po.pousseur and BB.present(po.pousseur) then return { po.pousseur } end
    end
    local out = {}
    if type(b.responsables) == 'table' then
        for _, s in ipairs(GetPlayers()) do
            local src = tonumber(s)
            local cid = BB.citizenid(src)
            for _, r in ipairs(b.responsables) do if cid and r == cid then out[#out + 1] = src break end end
        end
    end
    return out
end

local MSG = {
    faim = { 'Le bébé commence à avoir faim.', 'Le bébé a faim et soif : donnez-lui un biberon.' },
    fatigue = { 'Le bébé a sommeil.', 'Le bébé est épuisé : couchez-le pour qu\'il dorme.' },
    couche = { 'Le bébé a besoin d\'être changé.', 'Le bébé pleure : sa couche doit être changée.' },
}
local BESOINS = { 'faim', 'fatigue', 'couche' }

local function niveau(v)
    if v >= SO.seuilUrgent then return 2 end
    if v >= SO.seuilAlerte then return 1 end
    return 0
end

-- Notifications sans spam : une seule par niveau atteint, puis un rappel au plus toutes les « rappel » minutes ;
-- un nouveau porteur est prévenu tout de suite des besoins en cours.
local function alerter(b, now)
    b.alertes = b.alertes or {}
    local d = destinataires(b)
    for _, k in ipairs(BESOINS) do
        local nv = niveau(b.besoins[k])
        if k == 'fatigue' and b.endormi then nv = 0 end
        local a = b.alertes[k] or { niveau = 0, at = 0 }
        if nv == 0 then
            a.niveau, a.dest = 0, nil
        elseif #d > 0 and (nv > a.niveau or a.dest ~= d[1] or now - a.at >= (tonumber(SO.rappel) or 10) * 60) then
            local txt = (b.nom and (b.nom .. ' : ') or '') .. MSG[k][nv]
            for _, s in ipairs(d) do BB.notify(s, txt, nv == 2 and 'error' or 'inform') end
            a.niveau, a.at, a.dest = nv, now, d[1]
        end
        b.alertes[k] = a
    end
end

local function tick()
    if not SO.actif then return end
    local now = os.time()
    for _, b in pairs(BB.Bebes) do
        avancer(b, now)
        if b.endormi and SO.reveilAuto and b.besoins.fatigue <= 0 and not b.verrou and not b.soin and b.etat ~= 'garde' then
            b.endormi = false
            if b.ents then BB.sousVerrou(0, { b }, function() if not BB.placer(b) then BB.poserDeSecours(b, 'erreur_reveil') end end) end
            for _, s in ipairs(destinataires(b)) do BB.notify(s, 'Le bébé se réveille, bien reposé.', 'inform') end
        end
        alerter(b, now)
    end
end

CreateThread(function()
    while true do
        Wait(math.max(1, tonumber(SO.intervalle) or 10) * 1000)
        local ok, err = pcall(tick)
        if not ok then print('^1[elyzea_bebe_modele] soins : ' .. tostring(err) .. '^0') end
    end
end)

-- ─────────── Soins ───────────

local function inventaire(fn, ...)
    if GetResourceState('elyzea_inventory') ~= 'started' then return false end
    local args = { ... }
    local ok, r = pcall(function() return exports.elyzea_inventory[fn](exports.elyzea_inventory, table.unpack(args)) end)
    return ok and r
end

local function itemDeTenue(tenue)
    for item, v in pairs(SO.vetements) do if v.tenue == tenue then return item end end
end

local function tenueDisponible(tenue)
    for _, t in ipairs(BebeModeles.tenues or {}) do if t == tenue then return true end end
    return false
end

-- Bébé sur lequel le joueur peut agir : celui qu'il porte, ou un bébé posé / dans une poussette garée tout près
local function bebeCible(src, id)
    local b = BB.Bebes[id or '']
    if not b or b.etat == 'garde' or b.etat == 'erreur' or not b.ents then return nil, 'Bébé introuvable.' end
    if b.etat == 'porte' then
        if b.porteur ~= src then return nil, 'Quelqu\'un d\'autre porte ce bébé.' end
        return b
    end
    if b.etat == 'poussette' then
        local po = BB.Poussettes[b.poussette or '']
        if po and po.etat == 'libre' then return nil, 'La poussette roule.' end
        if po and po.etat == 'poussee' and po.pousseur ~= src then return nil, 'Quelqu\'un pousse cette poussette.' end
        if po and po.etat == 'poussee' then return b end
    end
    if not BB.procheDe(src, b.ents.corps, SO.distance + 0.5) then return nil, 'Le bébé est trop loin.' end
    return b
end

-- Bébé visé par un objet utilisé depuis l'inventaire : celui que l'on porte, sinon le plus proche
local function bebeProche(src, filtre)
    local b = BB.Bebes[BB.parPorteur[src] or '']
    if b and (not filtre or filtre(b)) then return b end
    local pc = GetEntityCoords(GetPlayerPed(src))
    local best, bestD
    for _, x in pairs(BB.Bebes) do
        local e = x.ents and x.ents.corps
        if e and DoesEntityExist(e) and x.etat ~= 'porte' and (not filtre or filtre(x)) then
            local d = #(pc - GetEntityCoords(e))
            if d <= SO.distance + 0.5 and (not bestD or d < bestD) then best, bestD = x, d end
        end
    end
    return best
end

local function finSoin(src, b)
    b.soin = nil
    enSoin[src] = nil
    if BB.present(src) then TriggerClientEvent('elyzea_bebe_modele:soin:fin', src) end
end

local function commencer(src, b, action)
    local err = BB.peutAgir(src)
        or (enSoin[src] and 'Vous êtes déjà en train de vous occuper d\'un bébé.')
        or ((b.soin or b.verrou) and 'Quelqu\'un s\'occupe déjà de ce bébé.')
    if err then return BB.notify(src, err, 'error') end
    b.soin, enSoin[src] = action, b.id
    return true
end

local function nourrir(src, b)
    local n = besoins(b)
    if n.faim < 5 then return BB.notify(src, 'Le bébé n\'a pas faim.', 'inform') end
    if BB.nbObjets(src, SO.itemBiberon) < 1 then return BB.notify(src, 'Il vous faut un biberon (vendu par la puéricultrice).', 'error') end
    if not commencer(src, b, 'nourrir') then return end
    if not inventaire('RemoveItem', src, SO.itemBiberon, 1) then
        finSoin(src, b)
        return BB.notify(src, 'Le biberon n\'a pas pu être utilisé.', 'error')
    end
    local M = BebeModeles.equipements and BebeModeles.equipements[SO.biberon.modele] or {}
    local modele = select(2, next(M))
    local prop, net
    if modele then
        local ped = GetPlayerPed(src)
        prop, net = BB.creerObjet(modele, GetEntityCoords(ped), GetEntityHeading(ped), false, GetPlayerRoutingBucket(src), { bebeBiberon = true })
    end
    TriggerClientEvent('elyzea_bebe_modele:soin:debut', src, 'nourrir', net, SO.dureeBiberon, b.etat == 'porte', b.nets and b.nets.corps)
    BB.log('biberon', b.id, src)
    SetTimeout(math.floor(SO.dureeBiberon * 1000), function()
        BB.supprimer(prop)
        n.faim = 0.0
        if b.alertes then b.alertes.faim = nil end
        finSoin(src, b)
        if BB.present(src) then BB.notify(src, 'Le bébé a bu tout son biberon : il n\'a plus faim ni soif.', 'success') end
    end)
end

local function changer(src, b)
    if b.etat ~= 'pose' then return BB.notify(src, 'Posez d\'abord le bébé (allongé) pour le changer.', 'error') end
    if BB.nbObjets(src, SO.itemCouche) < 1 then return BB.notify(src, 'Il vous faut une couche propre (vendue par la puéricultrice).', 'error') end
    if not commencer(src, b, 'changer') then return end
    if not inventaire('RemoveItem', src, SO.itemCouche, 1) then
        finSoin(src, b)
        return BB.notify(src, 'La couche n\'a pas pu être utilisée.', 'error')
    end
    TriggerClientEvent('elyzea_bebe_modele:soin:debut', src, 'changer', nil, SO.dureeCouche, false, b.nets and b.nets.corps)
    BB.log('couche', b.id, src)
    SetTimeout(math.floor(SO.dureeCouche * 1000), function()
        besoins(b).couche = 0.0
        if b.alertes then b.alertes.couche = nil end
        finSoin(src, b)
        if BB.present(src) then BB.notify(src, 'Couche changée : le bébé est propre.', 'success') end
    end)
end

-- Habiller avec un vêtement de l'inventaire (item = nom de l'objet ; nil = le premier vêtement possédé, autre que la tenue actuelle)
local function habiller(src, b, item)
    if b.etat ~= 'pose' and not (b.etat == 'porte' and b.porteur == src) then
        return BB.notify(src, 'Posez le bébé ou portez-le pour l\'habiller.', 'error')
    end
    local actuelle = b.apparence.tenue
    if not item then
        for it, v in pairs(SO.vetements) do
            if v.tenue ~= actuelle and BB.nbObjets(src, it) > 0 then item = it break end
        end
        if not item then return BB.notify(src, 'Aucun vêtement de bébé dans votre inventaire (puéricultrice).', 'error') end
    end
    local V = SO.vetements[item]
    if not V then return end
    if V.tenue == actuelle then return BB.notify(src, 'Le bébé porte déjà ce vêtement.', 'inform') end
    if not tenueDisponible(V.tenue) then return BB.notify(src, 'Ce vêtement n\'a pas de modèle installé sur le serveur.', 'error') end
    if BB.nbObjets(src, item) < 1 then return BB.notify(src, 'Vous n\'avez pas ce vêtement.', 'error') end
    local ancien = itemDeTenue(actuelle)
    if ancien and not inventaire('CanCarryItem', src, ancien, 1) then
        return BB.notify(src, 'Inventaire plein : impossible de reprendre le vêtement actuel du bébé.', 'error')
    end
    if not commencer(src, b, 'habiller') then return end
    if not inventaire('RemoveItem', src, item, 1) then finSoin(src, b) return BB.notify(src, 'Vêtement introuvable.', 'error') end
    if ancien then inventaire('AddItem', src, ancien, 1) end
    BB.sousVerrou(src, { b }, function()
        b.apparence.tenue = V.tenue
        if not BB.placer(b) then BB.poserDeSecours(b, 'erreur_habiller') end
    end)
    finSoin(src, b)
    BB.log('habillé', b.id, V.tenue, src)
    BB.notify(src, ('Bébé habillé : %s.'):format(V.label), 'success')
end

local function deshabiller(src, b)
    local ancien = itemDeTenue(b.apparence.tenue)
    if not ancien then return BB.notify(src, 'Le bébé ne porte que sa couche.', 'inform') end
    if b.etat ~= 'pose' and not (b.etat == 'porte' and b.porteur == src) then
        return BB.notify(src, 'Posez le bébé ou portez-le pour le déshabiller.', 'error')
    end
    if not inventaire('CanCarryItem', src, ancien, 1) then return BB.notify(src, 'Inventaire plein.', 'error') end
    if not commencer(src, b, 'habiller') then return end
    if not inventaire('AddItem', src, ancien, 1) then finSoin(src, b) return BB.notify(src, 'Inventaire plein.', 'error') end
    BB.sousVerrou(src, { b }, function()
        b.apparence.tenue = 'couche'
        if not BB.placer(b) then BB.poserDeSecours(b, 'erreur_habiller') end
    end)
    finSoin(src, b)
    BB.notify(src, 'Pyjama retiré (rangé dans votre inventaire) : le bébé garde sa couche.', 'success')
end

local function texteEtat(b)
    local n = besoins(b)
    local function mot(v) return v >= SO.seuilUrgent and 'urgent' or (v >= SO.seuilAlerte and 'à surveiller' or 'bien') end
    return ('Faim et soif %d %% (%s) · Sommeil %d %% (%s)%s · Couche %d %% (%s)'):format(math.floor(n.faim), mot(n.faim),
        math.floor(n.fatigue), mot(n.fatigue), b.endormi and ', endormi' or '', math.floor(n.couche), mot(n.couche))
end

RegisterNetEvent('elyzea_bebe_modele:soin', function(action, id, arg)
    local src = source
    if not SO.actif then return BB.notify(src, 'Les soins du bébé sont désactivés sur ce serveur.', 'error') end
    if not BB.limite(src, 'soin', 4, 3000) or type(action) ~= 'string' then return end
    local b, err = bebeCible(src, id)
    if not b then return BB.notify(src, err, 'error') end
    avancer(b, os.time())
    if action == 'nourrir' then nourrir(src, b)
    elseif action == 'changer' then changer(src, b)
    elseif action == 'habiller' then habiller(src, b, type(arg) == 'string' and SO.vetements[arg] and arg or nil)
    elseif action == 'deshabiller' then deshabiller(src, b)
    elseif action == 'etat' then BB.notify(src, texteEtat(b), 'inform') end
end)

-- Objets utilisés depuis l'inventaire (jamais consommés automatiquement : le soin retire l'objet lui-même)
local function enregistrer()
    if GetResourceState('elyzea_inventory') ~= 'started' then return end
    local defs = {
        [SO.itemBiberon] = function(src)
            local b = bebeProche(src)
            if not b then return BB.notify(src, 'Portez le bébé ou placez-vous à côté de lui.', 'error') end
            local ok, err = bebeCible(src, b.id)
            if not ok then return BB.notify(src, err, 'error') end
            avancer(b, os.time()) nourrir(src, b)
        end,
        [SO.itemCouche] = function(src)
            local b = bebeProche(src, function(x) return x.etat == 'pose' end)
            if not b then return BB.notify(src, 'Posez le bébé (allongé) et placez-vous à côté de lui.', 'error') end
            local ok, err = bebeCible(src, b.id)
            if not ok then return BB.notify(src, err, 'error') end
            avancer(b, os.time()) changer(src, b)
        end,
    }
    for item in pairs(SO.vetements) do
        defs[item] = function(src)
            local b = bebeProche(src)
            if not b then return BB.notify(src, 'Portez le bébé ou placez-vous à côté de lui.', 'error') end
            local ok, err = bebeCible(src, b.id)
            if not ok then return BB.notify(src, err, 'error') end
            habiller(src, b, item)
        end
    end
    for item, fn in pairs(defs) do
        pcall(function()
            exports.elyzea_inventory:RegisterUsableItem(item, function(source)
                CreateThread(function() fn(source) end)
                return false
            end)
        end)
    end
end
AddEventHandler('elyzea_inventory:ready', enregistrer)
CreateThread(function() Wait(1500) enregistrer() end)

AddEventHandler('playerDropped', function() enSoin[source] = nil end)

-- ─────────── Réglages du menu admin (via elyzea_famille, clés « bebe.soins.* ») ───────────
function BB.appliquerSoins(v, num, bool)
    SO.actif = bool(v['bebe.soins.actif'], SO.actif)
    SO.vitesse = num('bebe.soins.vitesse', 0, 3600, SO.vitesse)
    SO.parHeure.faim = num('bebe.soins.faim', 0, 1000, SO.parHeure.faim)
    SO.parHeure.fatigue = num('bebe.soins.fatigue', 0, 1000, SO.parHeure.fatigue)
    SO.parHeure.couche = num('bebe.soins.couche', 0, 1000, SO.parHeure.couche)
    SO.recuperation.couche = num('bebe.soins.sommeilCouche', 0, 1000, SO.recuperation.couche)
    SO.recuperation.porte = num('bebe.soins.sommeilPorte', 0, 1000, SO.recuperation.porte)
    SO.seuilAlerte = num('bebe.soins.seuilAlerte', 1, 100, SO.seuilAlerte)
    SO.seuilUrgent = math.max(SO.seuilAlerte, num('bebe.soins.seuilUrgent', 1, 100, SO.seuilUrgent))
    SO.rappel = num('bebe.soins.rappel', 0, 240, SO.rappel)
    SO.dureeBiberon = num('bebe.soins.dureeBiberon', 0, 120, SO.dureeBiberon)
    SO.dureeCouche = num('bebe.soins.dureeCouche', 0, 120, SO.dureeCouche)
    SO.pauseGarde = bool(v['bebe.soins.pauseGarde'], SO.pauseGarde)
    SO.reveilAuto = bool(v['bebe.soins.reveilAuto'], SO.reveilAuto)
end

-- Diagnostic et tests
function BB.texteBesoins(b) return b.besoins and texteEtat(b) or nil end
BB.soins = { avancer = avancer, tick = tick, enSoin = enSoin }

-- Test rapide (staff) : /bebe_besoins [faim] [fatigue] [couche] sur le bébé porté ou le plus proche
RegisterCommand('bebe_besoins', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'command.bebe_besoins') then return end
    local b = src ~= 0 and bebeProche(src)
    if not b then return src ~= 0 and BB.notify(src, 'Aucun bébé porté ou proche.', 'error') end
    local n = besoins(b)
    for i, k in ipairs(BESOINS) do local x = tonumber(args[i]) if x then n[k] = clamp(x) end end
    b.alertes = nil
    BB.notify(src, texteEtat(b), 'inform')
end, true)
