-- =====================================================================
--  ELYZEA LABS · serveur : améliorations (niveau suivant)
--  Conditions : droit « améliorations », expérience suffisante, niveau suivant existant,
--  paiement du compte du groupe. Mise à jour SQL conditionnelle (level = niveau actuel) :
--  deux achats simultanés ne peuvent pas payer deux fois le même niveau.
--  Rien d'autre ne change (équipements, coffre, expérience gardés).
-- =====================================================================
local L = Labs

L.pub.upgrade = function(src, d)
    local lab = L.list[tonumber(d.lab) or -1]
    if not lab or not L.InsideLab(src, lab.id) then return { error = 'Tu dois être dans le laboratoire.' } end
    if not L.Can(src, lab, 'upgrade') then return { error = 'Tu n\'as pas le droit d\'acheter les améliorations.' } end
    local nextLv = lab.level + 1
    local def = Config.Levels[nextLv]
    if not def then return { error = 'Niveau maximum atteint.' } end
    if lab.xp < def.xp then return { error = ('Expérience insuffisante : %d / %d XP.'):format(lab.xp, def.xp) } end
    if not L.Lock('lab:' .. lab.id) then return { error = 'Une opération est déjà en cours, réessaie.' } end
    local ok, err = L.GroupPay(lab.owner, def.price, ('Amélioration %s (%s)'):format(def.label, lab.name), src)
    if not ok then L.Unlock('lab:' .. lab.id) return { error = err or 'Paiement refusé.' } end
    local ups = LabRules.copy(lab.upgrades)
    ups[#ups + 1] = { level = nextLv, price = def.price, by = L.Name(src), group = lab.owner, t = os.time() }
    local n = MySQL.update.await('UPDATE `labs` SET `level` = ?, `upgrades` = ? WHERE `id` = ? AND `level` = ?', { nextLv, json.encode(ups), lab.id, lab.level })
    if (tonumber(n) or 0) ~= 1 then
        L.GroupCredit(lab.owner, def.price, ('Remboursement : amélioration %s'):format(def.label), src)
        L.Unlock('lab:' .. lab.id)
        return { error = 'Amélioration impossible (déjà achetée ?). Le groupe a été remboursé.' }
    end
    lab.level, lab.upgrades = nextLv, ups
    L.Unlock('lab:' .. lab.id)
    L.Log(lab.id, 'amelioration', L.Name(src), ('%s (%s)'):format(def.label, L.Money(def.price)))
    L.RefreshInside(lab, false)
    local cats = {}
    for _, c in ipairs(def.unlocks or {}) do cats[#cats + 1] = (Config.Categories[c] or { label = c }).label end
    return { ok = true, message = ('%s acheté : %s débloqué(s).'):format(def.label, table.concat(cats, ', ')) }
end
