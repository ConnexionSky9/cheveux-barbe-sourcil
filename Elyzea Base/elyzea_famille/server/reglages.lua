-- =====================================================================
--  ELYZEA FAMILLE - serveur : réglages modifiables depuis le menu admin (admin_menu › Famille)
--  · Chaque réglage a un type, des bornes strictes et une description (SCHEMA ci-dessous).
--  · Les valeurs enregistrées sont stockées dans `rp_famille_reglages` et réappliquées au démarrage.
--  · Elles remplacent les valeurs de config.lua sans toucher au fichier ; « Valeurs par défaut » revient à config.lua.
--  · Permission : admin_menu « famille_manage », vérifiée par admin_menu ET revérifiée ici.
--  · Un moment intime déjà commencé garde les réglages de son démarrage (durée, fondu…) : les nouveaux
--    réglages s'appliquent aux moments suivants.
-- =====================================================================
local RES = GetCurrentResourceName()
local PERM = 'famille_manage'

-- section, clé, chemin dans Config, type (int | num | pct | bool), bornes, libellé, aide
local SCHEMA = {
    -- Moment intime : durée
    { s = 'duree', k = 'intimite.duree', p = { 'Intimite', 'duree' }, t = 'int', min = 5, max = 600, u = 's',
      l = 'Durée de l\'écran noir', a = 'Durée du moment intime (après l\'étreinte). Doit rester entre la durée minimale et maximale ci-dessous.' },
    { s = 'duree', k = 'intimite.dureeMin', p = { 'Intimite', 'dureeMin' }, t = 'int', min = 5, max = 600, u = 's',
      l = 'Durée minimale autorisée', a = 'Garde-fou : la durée ne peut pas être réglée en dessous.' },
    { s = 'duree', k = 'intimite.dureeMax', p = { 'Intimite', 'dureeMax' }, t = 'int', min = 5, max = 600, u = 's',
      l = 'Durée maximale autorisée', a = 'Garde-fou : la durée ne peut pas être réglée au-dessus.' },
    { s = 'duree', k = 'intimite.fondu', p = { 'Intimite', 'fondu' }, t = 'int', min = 200, max = 5000, u = 'ms',
      l = 'Fondu au noir / retour', a = 'Durée du fondu d\'écran au début et à la fin.' },
    { s = 'duree', k = 'intimite.delaiAvantNoir', p = { 'Intimite', 'delaiAvantNoir' }, t = 'int', min = 0, max = 10000, u = 'ms',
      l = 'Étreinte visible avant le noir', a = 'Temps pendant lequel l\'étreinte est visible avant le fondu.' },
    -- Annulation
    { s = 'annulation', k = 'conception.siInterrompu', p = { 'Conception', 'siInterrompu' }, t = 'bool',
      l = 'Tentative même si le moment est arrêté', a = 'Désactivé (conseillé) : un moment arrêté avant la fin (X, déconnexion) ne déclenche aucune tentative. Activé : tentative si le seuil ci-dessous est atteint.' },
    { s = 'annulation', k = 'intimite.dureeMinPourConception', p = { 'Intimite', 'dureeMinPourConception' }, t = 'pct', min = 0.1, max = 1.0,
      l = 'Seuil pour un moment arrêté', a = 'Utilisé seulement si l\'option précédente est activée : part de la durée à atteindre.' },
    -- Positionnement
    { s = 'position', k = 'intimite.distanceCouple', p = { 'Intimite', 'distanceCouple' }, t = 'num', min = 0.3, max = 2.0, step = 0.05, u = 'm',
      l = 'Distance entre les deux personnages', a = 'La personne qui accepte se place face à l\'autre, à cette distance.' },
    -- Conditions de déclenchement
    { s = 'conditions', k = 'intimite.distanceMax', p = { 'Intimite', 'distanceMax' }, t = 'num', min = 1.0, max = 10.0, step = 0.5, u = 'm',
      l = 'Distance maximale pour proposer', a = 'Distance entre les deux personnes pour envoyer et accepter une demande.' },
    { s = 'conditions', k = 'intimite.expirationDemande', p = { 'Intimite', 'expirationDemande' }, t = 'int', min = 10, max = 120, u = 's',
      l = 'Temps pour répondre', a = 'Sans réponse dans ce délai, la demande est refusée.' },
    { s = 'conditions', k = 'intimite.attenteEntreDemandes', p = { 'Intimite', 'attenteEntreDemandes' }, t = 'int', min = 0, max = 3600, u = 's',
      l = 'Attente entre deux demandes', a = 'Entre deux demandes vers la même personne.' },
    { s = 'conditions', k = 'intimite.demandesParMinute', p = { 'Intimite', 'demandesParMinute' }, t = 'int', min = 1, max = 20,
      l = 'Demandes maximum par minute', a = 'Anti-abus, toutes personnes confondues.' },
    { s = 'conditions', k = 'intimite.delaiEntreMoments', p = { 'Intimite', 'delaiEntreMoments' }, t = 'int', min = 0, max = 1440, u = 'min',
      l = 'Délai après un moment terminé', a = 'Pour chaque personne, avant un nouveau moment intime (0 = aucun).' },
    -- Risque de grossesse
    { s = 'grossesse', k = 'conception.probaVolontaire', p = { 'Conception', 'probaVolontaire' }, t = 'pct', min = 0, max = 1,
      l = 'Risque si les deux souhaitent un enfant', a = 'Pour un moment terminé, sans contraception.' },
    { s = 'grossesse', k = 'conception.accidentelle', p = { 'Conception', 'accidentelle' }, t = 'bool',
      l = 'Grossesses accidentelles', a = 'Désactivé : seule une tentative où les deux ont coché « souhaiter un enfant » peut aboutir.' },
    { s = 'grossesse', k = 'conception.probaAccidentelle', p = { 'Conception', 'probaAccidentelle' }, t = 'pct', min = 0, max = 1,
      l = 'Risque accidentel', a = 'Pour un moment terminé, sans contraception, quand au moins une personne n\'a pas coché la case.' },
    { s = 'grossesse', k = 'conception.jumeaux', p = { 'Conception', 'multiples', 'jumeaux' }, t = 'pct', min = 0, max = 0.5,
      l = 'Jumeaux', a = 'Tiré séparément, seulement après une conception.' },
    { s = 'grossesse', k = 'conception.triples', p = { 'Conception', 'multiples', 'triples' }, t = 'pct', min = 0, max = 0.2,
      l = 'Triplés', a = 'Tiré séparément, seulement après une conception.' },
    { s = 'grossesse', k = 'grossesse.duree', p = { 'Grossesse', 'duree' }, t = 'int', min = 24, max = 2160, u = 'h',
      l = 'Durée de la grossesse', a = 'Heures réelles entre conception et terme (s\'applique aux nouvelles grossesses).' },
    -- Contraception
    { s = 'contraception', k = 'contraception.preservatif.fiabilite', p = { 'Contraception', 'preservatif', 'fiabilite' }, t = 'pct', min = 0, max = 1,
      l = 'Fiabilité du préservatif', a = '98 % = le risque est multiplié par 0,02.' },
    { s = 'contraception', k = 'contraception.pilule.fiabilite', p = { 'Contraception', 'pilule', 'fiabilite' }, t = 'pct', min = 0, max = 1,
      l = 'Fiabilité de la pilule', a = 'Appliquée si une prise est encore active pour la personne qui porte.' },
    { s = 'contraception', k = 'contraception.pilule.duree', p = { 'Contraception', 'pilule', 'duree' }, t = 'int', min = 1, max = 720, u = 'h',
      l = 'Protection d\'une pilule', a = 'Durée de protection après une prise.' },
    { s = 'contraception', k = 'contraception.pilule.renouvellement', p = { 'Contraception', 'pilule', 'renouvellement' }, t = 'int', min = 0, max = 720, u = 'h',
      l = 'Renouvellement de la pilule', a = 'Nouvelle prise acceptée seulement dans ces dernières heures (pas de cumul).' },
    { s = 'contraception', k = 'contraception.implant.fiabilite', p = { 'Contraception', 'implant', 'fiabilite' }, t = 'pct', min = 0, max = 1,
      l = 'Fiabilité de l\'implant', a = 'Appliquée tant que l\'implant est actif.' },
    { s = 'contraception', k = 'contraception.implant.duree', p = { 'Contraception', 'implant', 'duree' }, t = 'int', min = 24, max = 8760, u = 'h',
      l = 'Durée de l\'implant', a = 'S\'applique aux implants posés ensuite.' },
}

local SECTIONS = {
    { id = 'duree', label = 'Durée du moment intime' },
    { id = 'annulation', label = 'Annulation' },
    { id = 'position', label = 'Positionnement des personnages' },
    { id = 'conditions', label = 'Conditions de déclenchement' },
    { id = 'grossesse', label = 'Risque de grossesse' },
    { id = 'contraception', label = 'Effets de la contraception' },
}

local PAR_CLE = {}
for _, d in ipairs(SCHEMA) do PAR_CLE[d.k] = d end

local function lire(p)
    local t = Config
    for i = 1, #p do t = t and t[p[i]] end
    return t
end

local function ecrire(p, v)
    local t = Config
    for i = 1, #p - 1 do t = t[p[i]] end
    t[p[#p]] = v
end

-- Valeurs de config.lua (copie prise au démarrage, avant tout réglage enregistré)
local DEFAUTS = {}
for _, d in ipairs(SCHEMA) do DEFAUTS[d.k] = lire(d.p) end

-- Valide UNE valeur. Renvoie la valeur propre ou nil, raison
local function valider(d, v)
    if d.t == 'bool' then
        if type(v) ~= 'boolean' then return nil, 'oui / non attendu' end
        return v
    end
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil, 'nombre attendu' end
    if v < d.min or v > d.max then return nil, ('entre %s et %s'):format(d.min, d.max) end
    if d.t == 'int' then v = math.floor(v + 0.5) end
    return v
end

-- Valide un ensemble complet (règles croisées comprises). Renvoie table propre ou nil, liste d'erreurs
local function validerTout(valeurs)
    local out, err = {}, {}
    for _, d in ipairs(SCHEMA) do
        local v = valeurs[d.k]
        if v == nil then v = lire(d.p) end
        local ok, why = valider(d, v)
        if ok == nil then err[#err + 1] = ('%s : %s'):format(d.l, why) else out[d.k] = ok end
    end
    if #err == 0 then
        if out['intimite.dureeMin'] > out['intimite.dureeMax'] then err[#err + 1] = 'La durée minimale dépasse la durée maximale.' end
        local du = out['intimite.duree']
        if du < out['intimite.dureeMin'] or du > out['intimite.dureeMax'] then
            err[#err + 1] = ('La durée doit être entre %d et %d s.'):format(out['intimite.dureeMin'], out['intimite.dureeMax'])
        end
        if out['conception.jumeaux'] + out['conception.triples'] > 1 then err[#err + 1] = 'Jumeaux + triplés ne peuvent pas dépasser 100 %.' end
        if out['contraception.pilule.renouvellement'] > out['contraception.pilule.duree'] then
            err[#err + 1] = 'Le renouvellement de la pilule ne peut pas dépasser sa durée de protection.'
        end
    end
    if #err > 0 then return nil, err end
    return out
end

local function appliquer(valeurs)
    for _, d in ipairs(SCHEMA) do
        if valeurs[d.k] ~= nil then ecrire(d.p, valeurs[d.k]) end
    end
end

local function actuelles()
    local v = {}
    for _, d in ipairs(SCHEMA) do v[d.k] = lire(d.p) end
    return v
end

-- ─────────── Chargement au démarrage ───────────

function Fam.ChargerReglages()
    local rows = MySQL.query.await('SELECT `cle`, `valeur` FROM `rp_famille_reglages`') or {}
    local enregistrees = {}
    for _, r in ipairs(rows) do
        local d = PAR_CLE[r.cle]
        if d then
            local ok, v = pcall(json.decode, r.valeur)
            if ok and v ~= nil then enregistrees[r.cle] = v end
        end
    end
    if next(enregistrees) == nil then return 0 end
    local propre, err = validerTout(enregistrees)
    if not propre then
        Fam.err('réglages enregistrés invalides, valeurs de config.lua utilisées : ' .. table.concat(err, ' ; '))
        return 0
    end
    appliquer(propre)
    local n = 0
    for _ in pairs(enregistrees) do n = n + 1 end
    print(('[%s] %d réglage(s) du menu admin appliqué(s).'):format(RES, n))
    return n
end

-- ─────────── Permission (revérifiée ici, même si admin_menu l'a déjà fait) ───────────

local function autorise(src)
    src = tonumber(src)
    if src == 0 then return true end
    if not src or GetResourceState('admin_menu') ~= 'started' then return false end
    local ok, r = pcall(function() return exports.admin_menu:HasPermission(src, PERM) end)
    return ok and r == true
end

-- ─────────── Exports pour admin_menu ───────────

exports('AdminData', function(src)
    if not autorise(src) then return { available = true, denied = true } end
    local schema = {}
    for _, d in ipairs(SCHEMA) do
        schema[#schema + 1] = { section = d.s, key = d.k, type = d.t, min = d.min, max = d.max, step = d.step, unit = d.u, label = d.l, help = d.a }
    end
    return {
        available = true,
        sections = SECTIONS, schema = schema,
        values = actuelles(), defaults = DEFAUTS,
        sessions = Fam.SessionsEnCours and Fam.SessionsEnCours() or 0,
    }
end)

exports('AdminAction', function(src, name, data)
    if not autorise(src) then
        Fam.Suspect(src, 'réglages famille sans permission')
        return false, 'Permission refusée.'
    end
    local acteur = src == 0 and 'console' or ((Fam.Joueur(src) or {}).cid or ('src:' .. tostring(src)))
    if name == 'save' then
        if type(data) ~= 'table' or type(data.values) ~= 'table' then return false, 'Données invalides.' end
        local entree = {}
        for k, v in pairs(data.values) do if PAR_CLE[k] then entree[k] = v end end
        local propre, err = validerTout(entree)
        if not propre then return false, 'Refusé : ' .. table.concat(err, ' ; ') end
        local now = os.time()
        local q = {}
        for k, v in pairs(propre) do
            q[#q + 1] = { query = 'INSERT INTO `rp_famille_reglages` (`cle`, `valeur`, `updated_at`, `par`) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE `valeur` = VALUES(`valeur`), `updated_at` = VALUES(`updated_at`), `par` = VALUES(`par`)',
                values = { k, json.encode(v), now, acteur } }
        end
        if not MySQL.transaction.await(q) then return false, 'Erreur de base de données : rien n\'a été modifié.' end
        local avant = actuelles()
        appliquer(propre)
        local changes = {}
        for k, v in pairs(propre) do if avant[k] ~= v then changes[#changes + 1] = ('%s=%s'):format(k, tostring(v)) end end
        Fam.Audit(acteur, 'reglages_enregistres', nil, table.concat(changes, ', '))
        return true, #changes > 0 and ('Réglages enregistrés (%d modification(s)). Ils s\'appliquent aux prochains moments.'):format(#changes) or 'Aucune modification.'
    elseif name == 'reset' then
        if not MySQL.transaction.await({ { query = 'DELETE FROM `rp_famille_reglages`', values = {} } }) then
            return false, 'Erreur de base de données : rien n\'a été modifié.'
        end
        appliquer(DEFAUTS)
        Fam.Audit(acteur, 'reglages_reinitialises')
        return true, 'Valeurs par défaut (config.lua) rétablies.'
    end
    return false, 'Action inconnue.'
end)

-- Tables déjà prêtes (ordre de chargement différent) : appliquer tout de suite
if Fam.TablesPretes then Fam.ChargerReglages() end

-- Pour les tests
Fam.ReglagesSchema = SCHEMA
