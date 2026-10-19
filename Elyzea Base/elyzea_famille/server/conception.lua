-- =====================================================================
--  ELYZEA FAMILLE - serveur : tentative de conception et création de la grossesse
--  Appelé une seule fois à la fin d'un moment intime. Le tirage est fait ici, côté serveur, une fois :
--  la contrainte unique `rp_conception_attempts.session_id` empêche tout second calcul.
--  Rien n'est annoncé aux joueurs : la grossesse se découvre plus tard (symptômes, test, examen).
-- =====================================================================
local function grossesseEnCours(cid)
    return MySQL.scalar.await("SELECT `id` FROM `rp_pregnancies` WHERE `active_key` = ? LIMIT 1", { cid }) ~= nil
end

local function derniereFin(cid)
    -- une grossesse de test terminée par l'administration ne bloque pas une nouvelle conception
    return tonumber(MySQL.scalar.await("SELECT MAX(`ended_at`) FROM `rp_pregnancies` WHERE `porteur_cid` = ? AND `ended_at` IS NOT NULL AND (`end_reason` IS NULL OR `end_reason` <> 'reinitialisation_test')", { cid }))
end

local function rng() return math.random() end

function Fam.ResoudreConception(s, pct, interrompu)
    if not Config.Modules.conception then return end
    local now = os.time()
    local a, b = s.ja, s.jb
    local e = {
        volontaire = s.volontaire, preservatif = s.preservatif ~= nil, dureePct = pct, interrompu = interrompu == true,
        a = a, b = b,
        etatA = Fam.EtatContraception(a.cid), etatB = Fam.EtatContraception(b.cid),
        enceinteA = grossesseEnCours(a.cid), enceinteB = grossesseEnCours(b.cid),
        derniereFinA = derniereFin(a.cid), derniereFinB = derniereFin(b.cid),
    }
    local d = Regles.decider(e, Config, now, rng)
    local porteur = d.porteur == 'a' and a or d.porteur == 'b' and b or nil
    local partenaire = d.porteur == 'a' and b or d.porteur == 'b' and a or nil
    local methodes = {}
    for _, m in ipairs(d.protections) do methodes[#methodes + 1] = m.methode end

    -- 1. la tentative (échoue si cette session a déjà été traitée)
    local ok, err = pcall(MySQL.insert.await,
        'INSERT INTO `rp_conception_attempts` (`session_id`, `porteur_cid`, `partenaire_cid`, `resultat`, `raison`, `volontaire`, `protections`, `probabilite`, `tirage`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { s.id, porteur and porteur.cid, partenaire and partenaire.cid, d.resultat, d.raison, s.volontaire and 1 or 0,
          table.concat(methodes, ','), d.probabilite, d.tirage, now })
    if not ok then
        Fam.log('tentative déjà traitée ou erreur', s.id, tostring(err))
        return
    end
    Fam.log(('session %s : %s (p = %.4f, tirage = %s)'):format(s.id, d.resultat, d.probabilite, tostring(d.tirage)))
    if d.resultat ~= 'conception' and d.resultat ~= 'echec_contraception' then return end

    -- 2. la grossesse (transaction : grossesse + événement + lien sur la tentative)
    local gid = Fam.NouvelId('GRS')
    local terme = Regles.terme(now, Config.Grossesse)
    local donnees = json.encode({ bebes = d.bebes, volontaire = s.volontaire, protections = methodes })
    local reussi = MySQL.transaction.await({
        { query = 'INSERT INTO `rp_pregnancies` (`id`, `porteur_cid`, `partenaire_cid`, `session_id`, `bebes`, `conceived_at`, `due_at`, `status`, `active_key`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, ?, \'en_cours\', ?, ?)',
          values = { gid, porteur.cid, partenaire.cid, s.id, d.bebes, now, terme, porteur.cid, now } },
        { query = 'INSERT INTO `rp_pregnancy_events` (`pregnancy_id`, `kind`, `at`, `data`) VALUES (?, \'conception\', ?, ?)',
          values = { gid, now, donnees } },
        { query = 'UPDATE `rp_conception_attempts` SET `pregnancy_id` = ? WHERE `session_id` = ?',
          values = { gid, s.id } },
    })
    if not reussi then
        -- cas rare : une autre grossesse a été créée entre-temps (index unique active_key)
        MySQL.update.await("UPDATE `rp_conception_attempts` SET `resultat` = 'impossible', `raison` = 'deja_enceinte' WHERE `session_id` = ?", { s.id })
        return
    end
    Fam.Audit(porteur.cid, 'conception', gid, { session = s.id, bebes = d.bebes, terme = terme })
    TriggerEvent('elyzea_famille:server:conception', gid, porteur.cid, partenaire.cid, d.bebes)
end
