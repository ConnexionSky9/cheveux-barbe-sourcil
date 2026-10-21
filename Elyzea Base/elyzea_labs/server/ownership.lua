-- =====================================================================
--  ELYZEA LABS · serveur : propriété
--  · Achat par le chef d'un groupe (compte du groupe), quand le laboratoire n'a pas de propriétaire.
--  · Transfert (capture ou staff) : une seule requête SQL change le propriétaire, le code et les
--    droits ; le niveau, l'expérience, les améliorations, les équipements et le coffre (liés à
--    l'identifiant du laboratoire) ne bougent pas.
-- =====================================================================
local L = Labs
Config.MaxLabsPerGroup = Config.MaxLabsPerGroup or 2

function L.LabsOf(gid)
    local n = 0
    for _, lab in pairs(L.list) do if lab.owner == gid then n = n + 1 end end
    return n
end

-- Nouveau code aléatoire : renvoie le code en clair (montré une seule fois au chef)
local function newCode()
    local code = L.RandomCode()
    local salt = L.NewSalt()
    return code, salt, L.HashCode(salt, code)
end

L.pub.buy = function(src, d)
    local lab = L.list[tonumber(d.lab) or -1]
    if not lab then return { error = 'Laboratoire introuvable.' } end
    if lab.disabled then return { error = 'Ce laboratoire est fermé.' } end
    if lab.owner then return { error = 'Ce laboratoire a déjà un propriétaire.' } end
    if L.Dist(src, lab) > Config.InteractDistance + 1.5 or GetPlayerRoutingBucket(src) ~= 0 then return { error = 'Rapproche-toi de l\'entrée.' } end
    local g = L.PlayerGroup(src)
    if not g then return { error = 'Il faut faire partie d\'un groupe illégal.' } end
    if not g.boss then return { error = 'Seul le chef du groupe peut acheter un laboratoire.' } end
    if L.LabsOf(g.id) >= Config.MaxLabsPerGroup then return { error = ('Ton groupe possède déjà %d laboratoire(s).'):format(Config.MaxLabsPerGroup) } end
    if not L.Lock('lab:' .. lab.id) then return { error = 'Une opération est déjà en cours, réessaie.' } end
    local ok, err = L.GroupPay(g.id, lab.price, ('Achat du laboratoire « %s »'):format(lab.name), src)
    if not ok then L.Unlock('lab:' .. lab.id) return { error = err or 'Paiement refusé.' } end
    local code, salt, hash = newCode()
    local n = MySQL.update.await('UPDATE `labs` SET `owner_group` = ?, `owner_since` = NOW(), `code_hash` = ?, `code_salt` = ?, `perms` = \'{}\' WHERE `id` = ? AND `owner_group` IS NULL',
        { g.id, hash, salt, lab.id })
    if (tonumber(n) or 0) ~= 1 then
        L.GroupCredit(g.id, lab.price, ('Remboursement : laboratoire « %s »'):format(lab.name), src)
        L.Unlock('lab:' .. lab.id)
        return { error = 'Achat impossible (déjà acheté ?). Le groupe a été remboursé.' }
    end
    lab.owner, lab.codeHash, lab.codeSalt, lab.perms = g.id, hash, salt, {}
    L.Unlock('lab:' .. lab.id)
    L.Log(lab.id, 'achat', L.Name(src), ('acheté par %s pour %s'):format(g.label, L.Money(lab.price)))
    L.PushLabs()
    return { ok = true, code = code, message = ('Laboratoire acheté pour %s. Code d\'accès : %s (changeable dans la tablette).'):format(L.Money(lab.price), code) }
end

-- Transfert de propriété (capture réussie, staff). newOwner = nil : plus de propriétaire.
-- Renvoie true si le transfert est fait. Le code est remplacé (l'ancien propriétaire ne peut plus entrer).
function L.Transfer(lab, newOwner, reason, actor)
    if not L.Lock('lab:' .. lab.id) then return false, 'Une opération est en cours sur ce laboratoire.' end
    local old = lab.owner
    local code, salt, hash = nil, nil, nil
    if newOwner then code, salt, hash = newCode() end
    local ok = MySQL.transaction.await({
        newOwner and { query = 'UPDATE `labs` SET `owner_group` = ?, `owner_since` = NOW(), `code_hash` = ?, `code_salt` = ?, `perms` = \'{}\' WHERE `id` = ?',
          values = { newOwner, hash, salt, lab.id } }
          or { query = 'UPDATE `labs` SET `owner_group` = NULL, `owner_since` = NULL, `code_hash` = NULL, `code_salt` = NULL, `perms` = \'{}\' WHERE `id` = ?',
          values = { lab.id } },
        { query = 'INSERT INTO `labs_logs` (`lab_id`, `kind`, `actor`, `detail`) VALUES (?, ?, ?, ?)',
          values = { lab.id, 'proprietaire', tostring(actor or ''):sub(1, 100), ('%s → %s (%s)'):format(L.GroupLabel(old), newOwner and L.GroupLabel(newOwner) or 'aucun', tostring(reason or '')):sub(1, 255) } },
    })
    if not ok then L.Unlock('lab:' .. lab.id) return false, 'Erreur de la base de données : rien n\'a changé.' end
    lab.owner, lab.codeHash, lab.codeSalt, lab.perms = newOwner, hash, salt, {}
    L.Unlock('lab:' .. lab.id)
    if L.CancelCraftsIn then L.CancelCraftsIn(lab.id) end
    L.RefreshInside(lab, L.Raids().kickOnCapture ~= false, 'Le laboratoire a changé de propriétaire : tu n\'y as plus accès.')
    if newOwner then
        L.NotifyGroup(newOwner, ('🔑 Nouveau code de « %s » : %s (changeable dans la tablette).'):format(lab.name, code), 'success', true)
    end
    L.PushLabs()
    return true, code
end
