-- =====================================================================
--  ELYZEA FAMILLE - serveur : commande staff de vérification
--  /famille_etat [id] : état contraceptif, grossesse en cours, dernières tentatives (ACE command.famille_etat)
--  Réservée au staff : ces informations sont privées pour les joueurs.
-- =====================================================================
local function ligne(src, txt)
    if src == 0 then print(txt) else TriggerClientEvent('chat:addMessage', src, { args = { 'Famille', txt } }) end
end

local function date(ts)
    ts = tonumber(ts) or 0
    if ts <= 0 then return '—' end
    return os.date('%d/%m %H:%M', ts)
end

RegisterCommand(Config.Staff.etat, function(src, args)
    local cible = tonumber(args[1]) or src
    if cible == 0 then return ligne(src, 'Usage : /' .. Config.Staff.etat .. ' [id joueur]') end
    local j = Fam.Joueur(cible)
    if not j then return ligne(src, 'Joueur introuvable ou personnage non chargé.') end
    local now = os.time()
    local e = Fam.EtatContraception(j.cid)
    ligne(src, ('%s (%s) · sexe %s · né(e) le %s'):format(j.nom, j.cid, j.gender == 1 and 'F' or 'M', tostring(j.birthdate)))
    ligne(src, ('Pilule : %s (%s) · implant : %s (%s) · ordonnance : %s'):format(
        Regles.etatMethode(e.pill_until, now), date(e.pill_until), Regles.etatMethode(e.implant_until, now), date(e.implant_until), date(e.prescription_until)))
    local g = MySQL.single.await("SELECT `id`, `bebes`, `conceived_at`, `due_at`, `discovered_at` FROM `rp_pregnancies` WHERE `active_key` = ?", { j.cid })
    if g then
        ligne(src, ('Grossesse %s : %d bébé(s), conçue le %s, terme le %s, découverte : %s'):format(g.id, g.bebes, date(g.conceived_at), date(g.due_at), date(g.discovered_at)))
    else
        ligne(src, 'Aucune grossesse en cours.')
    end
    local t = MySQL.query.await("SELECT `session_id`, `resultat`, `raison`, `probabilite`, `protections`, `created_at` FROM `rp_conception_attempts` WHERE `porteur_cid` = ? OR `partenaire_cid` = ? ORDER BY `id` DESC LIMIT 3", { j.cid, j.cid }) or {}
    for _, r in ipairs(t) do
        ligne(src, ('%s · %s%s · p = %.2f %% · protections : %s · %s'):format(r.session_id, r.resultat, r.raison and (' (' .. r.raison .. ')') or '',
            (tonumber(r.probabilite) or 0) * 100, (r.protections and r.protections ~= '') and r.protections or 'aucune', date(r.created_at)))
    end
    ligne(src, ('Moments intimes en cours sur le serveur : %d'):format(Fam.SessionsEnCours()))
    local acteur = src == 0 and 'console' or ((Fam.Joueur(src) or {}).cid or ('src:' .. src))
    Fam.Audit(acteur, 'staff_etat', j.cid)
end, true)
