-- =====================================================================
--  ELYZEA FAMILLE - serveur : effets d'une grossesse et fin de grossesse
--  · Toutes les Config.Grossesse.suivi secondes : étape, symptômes (faim, nausées, vomissements, démarche),
--    envoyés à la seule personne concernée (rien n'est publié aux autres joueurs).
--  · Fin : accouchement par un EMS (menu ALT, consentement), automatique après le terme, ou par le staff.
--    La grossesse est close en base (une seule fois, même en cas de demandes simultanées), les effets s'arrêtent
--    et le ou les bébés sont créés dans le jeu (elyzea_bebe_modele).
--  Tout est recalculé à partir des dates enregistrées : rien n'est perdu après une déconnexion ou un redémarrage.
-- =====================================================================
local G = Config.Grossesse
local HEURE = 3600

local suivis = {}      -- [src] = { gid, cid, faim, nausee, vomi, etat }

local function started(res) return GetResourceState(res) == 'started' end

local function evenement(gid, kind, data)
    MySQL.insert('INSERT INTO `rp_pregnancy_events` (`pregnancy_id`, `kind`, `at`, `data`) VALUES (?, ?, ?, ?)',
        { gid, kind, os.time(), data and json.encode(data) or nil })
end

local function envoyerEtat(src, st, etat)
    local cle = etat and json.encode(etat) or 'false'
    if st and st.etat == cle then return end
    if st then st.etat = cle end
    TriggerClientEvent('elyzea_famille:client:grossesseEtat', src, etat or false)
end

local function arreter(src)
    if suivis[src] then
        suivis[src] = nil
        TriggerClientEvent('elyzea_famille:client:grossesseEtat', src, false)
    end
end

local function besoinsGeles(src)
    local ok, gele = pcall(function() return Player(src).state.elyNeedsFrozen end)
    return ok and gele == true
end

-- ─────────── Fin de grossesse ───────────

-- Crée les bébés à côté de la patiente (si elyzea_bebe_modele est démarrée). Renvoie la liste des identifiants.
local function creerBebes(g, src)
    local F, ids = G.fin, {}
    if not F.bebesEnJeu or not src or not GetPlayerName(src) or not started('elyzea_bebe_modele') then return ids end
    local ped = GetPlayerPed(src)
    if ped == 0 then return ids end
    local c = GetEntityCoords(ped)
    if c.x == 0.0 and c.y == 0.0 and c.z == 0.0 then return ids end   -- pas de OneSync : position inconnue
    local cap = GetEntityHeading and GetEntityHeading(ped) or 0.0
    local r = math.rad(cap)
    for i = 1, tonumber(g.bebes) or 1 do
        local dx = 0.45 * (i - ((tonumber(g.bebes) or 1) + 1) / 2)
        local pos = vector3(c.x - math.sin(r) * 0.7 + math.cos(r) * dx, c.y + math.cos(r) * 0.7 + math.sin(r) * dx, c.z - 0.98)
        local ok, id = pcall(function()
            return exports.elyzea_bebe_modele:CreerBebe(F.apparenceBebe, pos, cap, { responsables = { g.porteur_cid, g.partenaire_cid } })
        end)
        if ok and id then ids[#ids + 1] = id else Fam.err('naissance : bébé non créé (' .. tostring(id) .. ')') end
    end
    return ids
end

-- raison : 'accouchement' (EMS) | 'naissance_auto' | 'naissance_staff' | 'fin_staff'
-- Renvoie true, ids des bébés ; false si la grossesse était déjà terminée.
function Fam.TerminerGrossesse(g, raison, src, par)
    local naissance = raison ~= 'fin_staff'
    local now = os.time()
    local n = MySQL.update.await("UPDATE `rp_pregnancies` SET `status` = ?, `active_key` = NULL, `ended_at` = ?, `end_reason` = ? WHERE `id` = ? AND `active_key` IS NOT NULL",
        { naissance and 'accouchee' or 'terminee', now, raison, g.id })
    if (tonumber(n) or 0) < 1 then return false end
    local ids = naissance and creerBebes(g, src) or {}
    evenement(g.id, naissance and 'naissance' or 'fin', { raison = raison, par = par, bebes = naissance and g.bebes or 0, entites = ids })
    Fam.Audit(par or 'serveur', 'grossesse_fin', g.porteur_cid, { grossesse = g.id, raison = raison, bebes = #ids })
    if src then arreter(src) end
    TriggerEvent('elyzea_famille:server:finGrossesse', g.id, g.porteur_cid, raison, ids)
    return true, ids
end

-- ─────────── Effets (un joueur) ───────────

local function suivre(src, cid, g, now)
    local st = suivis[src]
    if not g then return arreter(src) end
    if not st or st.gid ~= g.id then
        st = { gid = g.id, cid = cid, faim = now }
        suivis[src] = st
    end
    local av = Regles.avancement(g, now, G)
    local F = G.fin
    if av.terme and (F.naissanceAuto or 0) > 0 and now >= tonumber(g.due_at) + F.naissanceAuto * HEURE then
        if Fam.TerminerGrossesse(g, 'naissance_auto', src, 'serveur') then
            Fam.Notify(src, 'Le travail a commencé… votre bébé est né.', 'success')
        end
        return
    end
    local S = Regles.symptomesActifs(av.numeroEtape, G.symptomes)
    -- faim plus rapide (au rythme du core)
    if S.faim and not besoinsGeles(src) then
        if now - st.faim >= (S.faim.intervalle or 5) * 60 then
            st.faim = now
            local extra = Regles.faimSupplementaire(S.faim)
            if extra > 0 and started('elyzea_core') then pcall(function() exports.elyzea_core:AddNeeds(src, -extra, 0, 0) end) end
        end
    else
        st.faim = now
    end
    -- nausées / vomissements : moments tirés au hasard autour de la fréquence réglée
    for nom, champ in pairs({ nausees = 'nausee', vomissements = 'vomi' }) do
        local c = S[nom]
        if not c then st[champ] = nil
        elseif not st[champ] or st[champ .. 'F'] ~= c.parHeure then   -- 1re fois, ou fréquence changée dans le menu admin
            st[champ .. 'F'] = c.parHeure
            st[champ] = now + (Regles.delaiSymptome(c.parHeure, math.random) or 10 * 365 * 24 * HEURE)
        elseif now >= st[champ] then
            st[champ] = now + (Regles.delaiSymptome(c.parHeure, math.random) or 10 * 365 * 24 * HEURE)
            TriggerClientEvent('elyzea_famille:client:symptome', src, nom, { duree = c.duree, intensite = c.intensite })
        end
    end
    local R = S.ralentissement
    envoyerEtat(src, st, {
        etape = av.numeroEtape, pct = math.floor(av.pct * 1000) / 1000,
        ralenti = R and { demarche = R.demarche, courseInterdite = R.courseInterdite == true } or false,
    })
end

local function actives()
    local t = {}
    for _, g in ipairs(MySQL.query.await("SELECT * FROM `rp_pregnancies` WHERE `active_key` IS NOT NULL") or {}) do t[g.porteur_cid] = g end
    return t
end

local function tick()
    local ok, err = pcall(function()
        if not Config.Modules.conception then
            for src in pairs(suivis) do arreter(src) end
            return
        end
        local now, a = os.time(), actives()
        for _, s in ipairs(GetPlayers()) do
            local src = tonumber(s)
            local j = Fam.Joueur(src)
            if j then suivre(src, j.cid, a[j.cid], now) elseif suivis[src] then arreter(src) end
        end
    end)
    if not ok then Fam.err('suivi des grossesses : ' .. tostring(err)) end
    SetTimeout(math.max(10, tonumber(G.suivi) or 60) * 1000, tick)
end
SetTimeout(5000, tick)

-- Connexion / changement de personnage : effets appliqués tout de suite (pas d'attente du prochain calcul)
function Fam.SuivreJoueur(src)
    local j = Fam.Joueur(src)
    if suivis[src] and (not j or suivis[src].cid ~= j.cid) then arreter(src) end
    if not j or not Config.Modules.conception then return end
    local g = Fam.GrossesseEnCours and Fam.GrossesseEnCours(j.cid)
    if g then suivre(src, j.cid, g, os.time()) end
end
AddEventHandler('elyzea:server:playerLogin', function(src) SetTimeout(2000, function() Fam.SuivreJoueur(src) end) end)
AddEventHandler('elyzea:server:playerUnloaded', function(src) arreter(tonumber(src)) end)
AddEventHandler('playerDropped', function() suivis[source] = nil end)
AddEventHandler('elyzea_famille:server:conception', function(_, cid)
    for _, s in ipairs(GetPlayers()) do
        local j = Fam.Joueur(tonumber(s))
        if j and j.cid == cid then Fam.SuivreJoueur(tonumber(s)) end
    end
end)

-- ─────────── Accouchement par un EMS (menu ALT) ───────────

local enCours = {}     -- [cid patiente] = true pendant l'accouchement
RegisterNetEvent('elyzea_famille:accouchement', function(cible)
    local src = source
    if not Config.Modules.conception then return end
    if type(cible) ~= 'number' then return Fam.Suspect(src, 'accouchement invalide') end
    if not Fam.Limite(src, 'accouchement', 4, 60) then return Fam.Notify(src, 'Patientez un peu.', 'error') end
    if not Fam.EmsEnService(src) then return Fam.Suspect(src, 'accouchement sans être EMS en service') end
    local ems, patient = Fam.Joueur(src), Fam.Joueur(cible)
    if not ems or not patient or cible == src then return Fam.Notify(src, 'Patiente introuvable.', 'error') end
    local d = Fam.Distance(src, cible)
    if d and d > 3.0 then return Fam.Notify(src, 'La patiente est trop loin.', 'error') end
    if enCours[patient.cid] then return Fam.Notify(src, 'Un accouchement est déjà en cours.', 'error') end
    local g = Fam.GrossesseEnCours(patient.cid)
    if not g then return Fam.Notify(src, 'Pas de grossesse : aucun accouchement possible.', 'inform') end
    if not Regles.accouchementPossible(Regles.avancement(g, os.time(), G), G.fin) then
        return Fam.Notify(src, 'Le travail n\'a pas commencé : il est trop tôt pour accoucher.', 'inform')
    end
    local envoye = Fam.Consentement(cible, { type = 'medical', titre = 'Accouchement',
        texte = 'Un EMS propose de vous accompagner pour l\'accouchement.' }, 30, function(accepte)
        if not accepte then return Fam.Notify(src, 'La patiente a refusé.', 'inform') end
        if enCours[patient.cid] or not Fam.EmsEnService(src) then return end
        enCours[patient.cid] = true
        local duree = math.max(5, tonumber(G.fin.dureeAccouchement) or 20)
        TriggerClientEvent('elyzea_famille:client:accouchement', cible, 'patiente', duree)
        TriggerClientEvent('elyzea_famille:client:accouchement', src, 'ems', duree)
        SetTimeout(duree * 1000, function()
            enCours[patient.cid] = nil
            local ok, err = pcall(function()
                local p2 = Fam.Joueur(cible)
                local d2 = Fam.Distance(src, cible)
                if not p2 or p2.cid ~= patient.cid or not Fam.EmsEnService(src) or (d2 and d2 > 5.0) then
                    Fam.Notify(src, 'Accouchement interrompu.', 'error')
                    if GetPlayerName(cible) then Fam.Notify(cible, 'Accouchement interrompu.', 'error') end
                    return
                end
                local g2 = Fam.GrossesseEnCours(patient.cid)
                if not g2 or g2.id ~= g.id then return end
                local fait, ids = Fam.TerminerGrossesse(g2, 'accouchement', cible, ems.cid)
                if not fait then return end
                local txt = g2.bebes == 1 and 'un bébé' or (g2.bebes == 2 and 'des jumeaux' or 'des triplés')
                Fam.Notify(src, ('Accouchement réussi : %s.'):format(txt), 'success')
                Fam.Notify(cible, ('Félicitations : %s !'):format(txt), 'success')
                if G.fin.bebesEnJeu and #ids == 0 then Fam.Notify(src, 'Le bébé n\'a pas pu être placé dans le jeu (voir la console serveur).', 'error') end
            end)
            if not ok then Fam.err('accouchement : ' .. tostring(err)) end
        end)
    end)
    if not envoye then Fam.Notify(src, 'La patiente a déjà une demande en attente.', 'error') end
end)

-- ─────────── Fin par le staff ───────────

RegisterCommand(Config.Staff.fin, function(src, args)
    local function dire(t) if src == 0 then print(t) else TriggerClientEvent('chat:addMessage', src, { args = { 'Famille', t } }) end end
    local cible = tonumber(args[1])
    if not cible then return dire('Usage : /' .. Config.Staff.fin .. ' [id joueur] [naissance]') end
    local j = Fam.Joueur(cible)
    if not j then return dire('Joueur introuvable ou personnage non chargé.') end
    local g = Fam.GrossesseEnCours(j.cid)
    if not g then return dire('Aucune grossesse en cours pour ce personnage.') end
    local acteur = src == 0 and 'console' or ((Fam.Joueur(src) or {}).cid or ('src:' .. src))
    local fait, ids = Fam.TerminerGrossesse(g, args[2] == 'naissance' and 'naissance_staff' or 'fin_staff', cible, acteur)
    dire(fait and ('Grossesse %s terminée (%s, %d bébé(s) placé(s)).'):format(g.id, args[2] == 'naissance' and 'naissance' or 'sans naissance', #ids)
        or 'Déjà terminée.')
end, true)

-- Pour les tests
Fam.Suivis = suivis
