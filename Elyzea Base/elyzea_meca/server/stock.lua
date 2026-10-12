-- =====================================================================
--  ELYZEA MÉCANO - serveur : stock de pièces de l'entreprise
--  · Quantités en base (meca_stock), chaque mouvement journalisé (meca_stock_moves).
--  · Commande = dépense réelle sur le compte société (refusée si le solde manque),
--    les pièces sont reçues immédiatement.
--  · Les pièces liées à un article du catalogue sont vérifiées avant l'installation
--    et retirées seulement quand l'installation a réussi.
-- =====================================================================
local P = Meca

P.OnReady = P.OnReady or {}
table.insert(P.OnReady, 1, function()
    for _, p in ipairs(Config.DefaultParts) do
        MySQL.insert.await('INSERT IGNORE INTO `meca_stock` (`code`, `label`, `qty`, `min_qty`, `unit_cost`) VALUES (?, ?, 0, ?, ?)', { p.code, p.label, p.min or 0, p.cost or 0 })
    end
end)

local function Move(code, delta, reason, ref, cost, actor)
    MySQL.insert('INSERT INTO `meca_stock_moves` (`code`, `delta`, `reason`, `ref`, `cost`, `actor_name`) VALUES (?, ?, ?, ?, ?, ?)',
        { code, delta, reason, ref, cost or 0, actor })
end

function P.StockQty(code)
    return tonumber(MySQL.scalar.await('SELECT `qty` FROM `meca_stock` WHERE `code` = ?', { code })) or 0
end

-- Besoins { [code] = quantité } : renvoie true ou false, pièce manquante
function P.HasParts(need)
    for code, qty in pairs(need or {}) do
        if P.StockQty(code) < qty then return false, code end
    end
    return true
end

-- Retire les pièces (atomique pièce par pièce). force = autorisé même sans stock (reste à 0)
function P.ConsumeParts(need, reason, ref, actor, force)
    for code, qty in pairs(need or {}) do
        local n = MySQL.update.await('UPDATE `meca_stock` SET `qty` = `qty` - ? WHERE `code` = ? AND `qty` >= ?', { qty, code, qty })
        if (not n or n < 1) then
            if not force then return false, code end
            local have = P.StockQty(code)
            if have > 0 then
                MySQL.update.await('UPDATE `meca_stock` SET `qty` = 0 WHERE `code` = ?', { code })
                Move(code, -have, reason .. ' (stock insuffisant)', ref, 0, actor)
            end
        else
            Move(code, -qty, reason, ref, 0, actor)
        end
    end
    return true
end

P.Actions.stock = { perm = 'stock_view', fn = function(src)
    return { list = MySQL.query.await('SELECT * FROM `meca_stock` ORDER BY `label`') or {},
        moves = MySQL.query.await([[SELECT m.`code`, s.`label`, m.`delta`, m.`reason`, m.`ref`, m.`cost`, m.`actor_name`, UNIX_TIMESTAMP(m.`created_at`) AS t
            FROM `meca_stock_moves` m LEFT JOIN `meca_stock` s ON s.`code` = m.`code` ORDER BY m.`id` DESC LIMIT 80]]) or {},
        canManage = P.Can(src, 'stock_manage'), balance = P.Balance() }
end }

local ordering = false
P.Actions.stockOrder = { perm = 'stock_manage', fn = function(src, d)
    local code = tostring(d.code or '')
    local qty = P.Int(d.qty, 1, 1000, nil)
    if not qty then return { error = 'Quantité invalide (1 à 1000).' } end
    local part = MySQL.single.await('SELECT * FROM `meca_stock` WHERE `code` = ?', { code })
    if not part then return { error = 'Pièce inconnue.' } end
    if ordering then return { error = 'Une commande est déjà en cours.' } end
    ordering = true
    local ok, res = pcall(function()
        local cost = qty * (tonumber(part.unit_cost) or 0)
        local ref = P.Uid('CMD')
        if cost > 0 and not P.SocietyRemove(cost, ('Commande %s ×%d · %s'):format(part.label, qty, ref)) then
            return { error = ('Fonds insuffisants : la commande coûte %d $ (solde %d $).'):format(cost, P.Balance()) }
        end
        MySQL.update.await('UPDATE `meca_stock` SET `qty` = `qty` + ? WHERE `code` = ?', { qty, code })
        Move(code, qty, 'Commande reçue', ref, cost, P.Name(src))
        if cost > 0 then
            P.Tx({ txid = ref, type = 'out', category = 'parts', amount = cost, reason = ('%s ×%d'):format(part.label, qty), actorCid = P.Cid(src), actorName = P.Name(src) })
        end
        P.Log(src, 'Commande de pièces', ('%s ×%d · %d $'):format(part.label, qty, cost))
        return { ok = true, message = ('%d × %s reçus (%d $).'):format(qty, part.label, cost) }
    end)
    ordering = false
    if not ok then print(('^1[MECA] Commande : %s^0'):format(tostring(res))) return { error = 'Erreur pendant la commande : rien n\'a été débité.' } end
    return res
end }

-- Correction d'inventaire (sans argent) : casse, perte, comptage
P.Actions.stockAdjust = { perm = 'stock_manage', fn = function(src, d)
    local code = tostring(d.code or '')
    local qty = P.Int(d.qty, 0, 100000, nil)
    if not qty then return { error = 'Quantité invalide.' } end
    local cur = MySQL.single.await('SELECT `qty`, `label` FROM `meca_stock` WHERE `code` = ?', { code })
    if not cur then return { error = 'Pièce inconnue.' } end
    local reason = P.Clean(d.reason, 50)
    if #reason < 3 then return { error = 'Indiquez le motif de la correction.' } end
    MySQL.update.await('UPDATE `meca_stock` SET `qty` = ? WHERE `code` = ?', { qty, code })
    Move(code, qty - (tonumber(cur.qty) or 0), 'Correction : ' .. reason, nil, 0, P.Name(src))
    return { ok = true, message = ('%s : %d en stock.'):format(cur.label, qty) }
end }

-- Créer / modifier une pièce (nom, seuil minimum, coût d'achat)
P.Actions.stockPart = { perm = 'stock_manage', fn = function(src, d)
    local code = tostring(d.code or ''):lower():gsub('[^%w_]', ''):sub(1, 30)
    if code == '' then return { error = 'Code invalide.' } end
    local label = P.Clean(d.label, 80)
    if #label < 2 then return { error = 'Nom trop court.' } end
    local min = P.Int(d.min, 0, 100000, 0)
    local cost = P.Int(d.cost, 0, Config.Catalog.maxPrice, nil)
    if not cost then return { error = 'Coût invalide.' } end
    MySQL.query.await([[INSERT INTO `meca_stock` (`code`, `label`, `qty`, `min_qty`, `unit_cost`) VALUES (?, ?, 0, ?, ?)
        ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `min_qty` = VALUES(`min_qty`), `unit_cost` = VALUES(`unit_cost`)]], { code, label, min, cost })
    return { ok = true, message = ('Pièce « %s » enregistrée.'):format(label) }
end }
