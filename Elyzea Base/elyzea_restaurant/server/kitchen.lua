-- =====================================================================
--  ELYZEA RESTAURANT - serveur : stations de cuisine et mini-jeux
--  · Station (E) : l'employé (permission « cook », en service) choisit une ligne
--    d'une de SES commandes « En préparation » que la station sait préparer.
--  · cookStart : le serveur crée le défi (shared/games.lua), garde ses paramètres
--    et un jeton à usage unique.
--  · cookFinish : jeton, durée (ni trop courte ni trop longue), distance à la
--    station, propriétaire de la commande, puis réponses vérifiées par le jeu.
--    Échec : rien n'est préparé, on peut recommencer.
--  · Toutes les lignes prêtes → commande « Terminée » + sac (restaurant_bag)
--    dans l'inventaire de l'employé.
-- =====================================================================
local P = Resto
local core = exports.elyzea_core
local K = Config.Kitchen

P.cook = {}   -- [src] = défi en cours

function P.CancelCook(orderId)
    for src, c in pairs(P.cook) do if c.order == orderId then P.cook[src] = nil end end
end
AddEventHandler('playerDropped', function() P.cook[source] = nil end)

local function Station(D, i)
    local s = ((D.points or {}).stations or {})[tonumber(i) or -1]
    return s
end
local function StationDoes(s, product)
    for _, t in ipairs(s.types or {}) do if t == product.station then return true end end
    return false
end

-- Lignes de MES commandes que cette station peut préparer
P.Actions.stationOptions = { perm = 'cook', duty = true, fn = function(src, d, D)
    local s = Station(D, d.station)
    if not s then return { error = 'Station introuvable.' } end
    if not P.NearPoint(src, s, K.stationDistance) then return { error = 'Approchez-vous de la station.' } end
    local cid = P.Cid(src)
    local list = {}
    for _, o in pairs(P.orders) do
        if o.shop == D.id and o.status == 'preparing' and o.emp == cid then
            for li, l in ipairs(o.lines) do
                local p = P.Products[l.p]
                if p and (l.done or 0) < l.qty and StationDoes(s, p) then
                    list[#list + 1] = { order = o.id, num = P.Num(o), line = li, label = l.label, qty = l.qty, done = l.done or 0, image = p.image or (p.item .. '.png'),
                        game = p.game, gameLabel = (Config.MiniGames[p.game] or {}).label or p.game, difficulty = p.difficulty }
                end
            end
        end
    end
    table.sort(list, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.line < b.line end)
    local labels = {}
    for _, t in ipairs(s.types or {}) do labels[#labels + 1] = (Config.StationTypes[t] or {}).label or t end
    return { list = list, station = tonumber(d.station), label = table.concat(labels, ' · '),
        empty = #list == 0 and 'Rien à préparer ici : prenez une commande dans l\'appli « Commande », puis venez à la station de ses produits.' or nil }
end }

P.Actions.cookStart = { perm = 'cook', duty = true, fn = function(src, d, D)
    local si = tonumber(d.station)
    local s = Station(D, si)
    if not s then return { error = 'Station introuvable.' } end
    if not P.NearPoint(src, s, K.stationDistance) then return { error = 'Approchez-vous de la station.' } end
    local o = P.orders[tonumber(d.order) or -1]
    local cid = P.Cid(src)
    if not o or o.shop ~= D.id then return { error = 'Commande introuvable.' } end
    if o.status ~= 'preparing' or o.emp ~= cid then return { error = 'Cette commande n\'est pas en préparation à votre nom.' } end
    local l = o.lines[tonumber(d.line) or -1]
    local p = l and P.Products[l.p]
    if not p then return { error = 'Produit introuvable.' } end
    if (l.done or 0) >= l.qty then return { error = 'Ce produit est déjà prêt.' } end
    if not StationDoes(s, p) then return { error = 'Ce produit ne se prépare pas à cette station.' } end
    local params = RSGames.Generate(p.game, p.difficulty, p.steps, nil, p)
    if not params then return { error = ('Mini-jeu « %s » inconnu (config.lua).'):format(tostring(p.game)) } end
    local now = GetGameTimer()
    local token = P.Uid('CK')
    local units = math.min(math.max(1, tonumber(K.unitsPerGame) or 1), l.qty - (l.done or 0))
    P.cook[src] = { token = token, shop = D.id, order = o.id, line = tonumber(d.line), station = si, game = p.game, params = params, t0 = now,
        deadline = now + ((tonumber(p.duration) or 30) + (tonumber(K.graceSeconds) or 4)) * 1000, units = units }
    return { ok = true, token = token, game = p.game, params = params, duration = tonumber(p.duration) or 30, difficulty = p.difficulty, steps = p.steps,
        label = p.label, image = p.image or (p.item .. '.png'), units = units, num = P.Num(o), gameLabel = (Config.MiniGames[p.game] or {}).label }
end }

-- Commande terminée : sac dans l'inventaire de l'employé
function P.GiveBag(o, src)
    local D = P.shops[o.shop]
    local parts = {}
    for _, l in ipairs(o.lines) do parts[#parts + 1] = ('%d × %s'):format(l.qty, l.label) end
    local meta = {
        uid = o.bag, order = o.id, num = P.Num(o), shop = D and D.name or '?', customer = o.cname,
        label = ('Sac %s · %s'):format(D and D.name or 'restaurant', P.Num(o)),
        description = ('Commande %s pour %s : %s'):format(P.Num(o), o.cname or '?', table.concat(parts, ', ')),
    }
    local inv = exports.elyzea_inventory
    local okC, can = pcall(function() return inv:CanCarryItem(src, Config.Bag.item, 1, meta) end)
    if okC and can then
        local okA, added = pcall(function() return inv:AddItem(src, Config.Bag.item, 1, meta) end)
        if okA and added then o.bagGiven = true return true end
    end
    o.bagGiven = false
    return false
end

function P.FinishOrder(o, src)
    local D = P.shops[o.shop]
    o.status = 'ready'
    o.bag = o.bag or P.Uid('BAG')
    local left = {}
    for i, l in ipairs(o.lines) do left[i] = { p = l.p, item = l.item, label = l.label, qty = l.qty } end
    P.SaveOrder(o, ', `bag_uid` = ?, `bag_left` = ?, `ready_at` = NOW()', { o.bag, json.encode(left) })
    local given = P.GiveBag(o, src)
    P.NotifyCid(o.cid, ('Votre commande %s chez %s est prête ! Un employé va vous la remettre.'):format(P.Num(o), D and D.name or ''), 'success')
    P.PushOrders()
    return given
end

P.Actions.cookFinish = { perm = 'cook', duty = true, fn = function(src, d, D)
    local c = P.cook[src]
    if not c or c.token ~= tostring(d.token or '') then return { error = 'Préparation expirée : recommencez.' } end
    P.cook[src] = nil   -- jeton à usage unique
    if d.fail == true then return { ok = false, failed = true, message = 'Raté ! Rien n\'est préparé : vous pouvez recommencer.' } end
    local now = GetGameTimer()
    local ms = now - c.t0
    if now > c.deadline then return { ok = false, failed = true, message = 'Trop lent : recommencez.' } end
    local min = (Config.MiniGames[c.game] or {}).minMs or 1000
    if ms < min then
        P.Log(src, 'Cuisine : résultat refusé (trop rapide)', ('%s · %d ms'):format(c.game, ms))
        return { ok = false, failed = true, message = 'Préparation refusée : trop rapide.' }
    end
    local s = Station(D, c.station)
    if c.shop ~= D.id or not s or not P.NearPoint(src, s, K.stationDistance) then return { ok = false, failed = true, message = 'Vous avez quitté la station.' } end
    local o = P.orders[c.order]
    if not o or o.status ~= 'preparing' or o.emp ~= P.Cid(src) then return { error = 'La commande n\'est plus à votre nom.' } end
    local l = o.lines[c.line]
    if not l or (l.done or 0) >= l.qty then return { error = 'Ce produit est déjà prêt.' } end
    local ok, why = RSGames.Check(c.game, c.params, type(d.result) == 'table' and d.result or {}, ms)
    if not ok then return { ok = false, failed = true, message = ('Raté : %s Rien n\'est préparé, recommencez.'):format(why or '') } end
    l.done = math.min(l.qty, (l.done or 0) + c.units)
    local units, done = P.Units(o)
    if done >= units then
        local given = P.FinishOrder(o, src)
        return { ok = true, complete = true, message = given
            and ('Commande %s terminée ! Le sac est dans votre inventaire : remettez-le au client (%s).'):format(P.Num(o), o.cname or '?')
            or ('Commande %s terminée, mais votre inventaire est plein : faites de la place puis « Prendre le sac » dans l\'appli.'):format(P.Num(o)) }
    end
    P.SaveOrder(o)
    P.PushOrders()
    return { ok = true, message = ('%s : %d / %d prêt(s). Commande %s : %d / %d.'):format(l.label, l.done, l.qty, P.Num(o), done, units), done = l.done, qty = l.qty }
end }

-- Abandon du mini-jeu (fermeture) : le jeton est simplement oublié
P.Actions.cookCancel = { perm = nil, open = false, fn = function(src) P.cook[src] = nil return { ok = true } end }

-- Sac non reçu (inventaire plein) : le récupérer
P.Actions.orderBag = { perm = 'orders', duty = true, fn = function(src, d, D)
    local o = P.orders[tonumber(d.id) or -1]
    if not o or o.shop ~= D.id then return { error = 'Commande introuvable.' } end
    if o.status ~= 'ready' or o.emp ~= P.Cid(src) then return { error = 'Ce n\'est pas votre commande terminée.' } end
    if o.bagGiven ~= false then return { error = 'Le sac a déjà été remis.' } end
    if not P.GiveBag(o, src) then return { error = 'Inventaire plein : faites de la place.' } end
    P.PushOrders()
    return { ok = true, message = ('Sac de la commande %s ajouté à votre inventaire.'):format(P.Num(o)) }
end }
