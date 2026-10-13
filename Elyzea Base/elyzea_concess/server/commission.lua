-- =====================================================================
--  ELYZEA CONCESSION - serveur : commission (%) par grade
--  · Même système que la police, les EMS, le mécano et Dynasty 8 : la direction
--    (permission « payroll ») fixe dans Finance le pourcentage versé au vendeur
--    sur chaque vente qu'il conclut.
--  · Prise sur le compte de la concession APRÈS l'encaissement, versée sur la
--    banque du vendeur (connecté ou non), journalisée ; annulée si le versement échoue.
-- =====================================================================
local P = Concess
P.CommissionMax = 50
local rates = {}   -- [grade_id] = %

P.OnReady[#P.OnReady + 1] = function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `cd_commission` (
        `grade_id` INT NOT NULL PRIMARY KEY,
        `pct` TINYINT UNSIGNED NOT NULL DEFAULT 0,
        `actor_name` VARCHAR(100) NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    for _, r in ipairs(MySQL.query.await('SELECT `grade_id`, `pct` FROM `cd_commission`') or {}) do rates[tonumber(r.grade_id)] = tonumber(r.pct) or 0 end
end

function P.CommissionRate(gradeId) return rates[tonumber(gradeId) or -1] or 0 end

-- Verse au vendeur (citizenid) sa commission sur un encaissement. Renvoie le montant versé.
function P.Commission(D, cid, amount, label, ref)
    local e = cid and P.employees[cid]
    if not e or e.shop_id ~= D.id then return 0 end
    local pct = P.CommissionRate(e.grade_id)
    local com = math.floor((tonumber(amount) or 0) * pct / 100)
    if com <= 0 then return 0 end
    local why = ('Commission %d %% · %s'):format(pct, label or '')
    if not P.SocietyRemove(D, com, why) then
        print(('^3[CONCESS] Commission non versée (fonds insuffisants) : %s^0'):format(why))
        return 0
    end
    local ok, s = P.PayBank(cid, com, why)
    if not ok then P.SocietyAdd(D, com, 'Annulation : ' .. why) return 0 end
    P.Tx(D, { type = 'out', category = 'commission', amount = com, reason = why, actorName = 'Système', targetCid = cid, targetName = e.name, ref = ref })
    if s then P.Notify(s, ('Commission reçue en banque : %d $ (%d %% · %s).'):format(com, pct, label or ''), 'success') end
    return com
end

P.Actions.financeCommission = { perm = 'payroll', fn = function(src, d, D)
    local g = P.grades[tonumber(d.id) or 0]
    if not g or g.shop_id ~= D.id then return { error = 'Grade introuvable.' } end
    if not P.CanEditGrade(src, g) then return { error = 'Vous ne pouvez fixer la commission que des grades inférieurs au vôtre.' } end
    local pct = P.Int(d.pct, 0, P.CommissionMax, nil)
    if not pct then return { error = ('Pourcentage invalide (0 à %d %%).'):format(P.CommissionMax) } end
    local old = P.CommissionRate(g.id)
    if pct == old then return { ok = true } end
    MySQL.query.await('INSERT INTO `cd_commission` (`grade_id`, `pct`, `actor_name`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `pct` = VALUES(`pct`), `actor_name` = VALUES(`actor_name`)',
        { g.id, pct, P.Name(src) })
    rates[g.id] = pct
    P.AddLog(D.id, src, nil, nil, 'Commission', nil, g.name, ('%d %% → %d %%'):format(old, pct))
    return { ok = true, message = ('%s : %d %% de commission sur les ventes à partir de maintenant.'):format(g.name, pct) }
end }
