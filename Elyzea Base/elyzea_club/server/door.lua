-- =====================================================================
--  ELYZEA BOÎTE DE NUIT - serveur : entrée, bracelets, liste VIP, liste noire,
--  ouverture au public, annonces, coffre
--  · Entrée (tout joueur, au point Entrée) : refusée si la boîte est fermée au
--    public ou si le joueur est sur la liste noire ; gratuite pour le personnel
--    et la liste VIP ; sinon prix d'entrée payé (banque / espèces) → compte de la boîte.
--    Le bracelet payé reste valable Config.Entry.wristband secondes.
--  · Point Intérieur (facultatif) : l'entrée téléporte dedans, E dedans ressort.
--  · Videur (« door ») : contrôle de la personne proche (bracelet, VIP, liste noire).
--  · Listes (« lists ») : ajouter / retirer, durée pour la liste noire.
-- =====================================================================
local P = Club
local core = exports.elyzea_core
local E = Config.Entry

P.lists = {}       -- [shopId] = { vip = { [cid] = row }, ban = { [cid] = row } }
P.bands = {}       -- [shopId] = { [cid] = expire (os.time) }

local function Lists(shopId)
    P.lists[shopId] = P.lists[shopId] or { vip = {}, ban = {} }
    return P.lists[shopId]
end

P.OnReady[#P.OnReady + 1] = function()
    P.lists = {}
    for _, r in ipairs(MySQL.query.await('SELECT `id`, `shop_id`, `kind`, `citizenid`, `name`, `reason`, `expires_at`, `actor_name`, UNIX_TIMESTAMP(`created_at`) AS t FROM `cl_lists`') or {}) do
        if r.kind == 'vip' or r.kind == 'ban' then
            Lists(r.shop_id)[r.kind][r.citizenid] = { id = r.id, cid = r.citizenid, name = r.name, reason = r.reason, expires = tonumber(r.expires_at), by = r.actor_name, t = r.t }
        end
    end
    -- Stash de chaque boîte (accès revérifié par elyzea_inventory à chaque ouverture)
    for _, D in pairs(P.shops) do if not D.deleted then P.RegisterStash(D) end end
    pcall(function()
        exports.elyzea_inventory:RegisterStashAccess('club:', function(src, stashId)
            local D = P.ShopOf(src)
            return D ~= nil and stashId == ('club:%d'):format(D.id) and P.Can(src, 'stash')
        end)
    end)
end

function P.RegisterStash(D)
    pcall(function()
        exports.elyzea_inventory:RegisterStash(('club:%d'):format(D.id), ('Coffre · %s'):format(D.name), Config.Stash.slots, Config.Stash.weight * 1000)
    end)
end

local function Active(row) return row and (not row.expires or row.expires > os.time()) end
function P.IsBanned(shopId, cid) local r = Lists(shopId).ban[cid] return Active(r) and r or nil end
function P.IsVip(shopId, cid) local r = Lists(shopId).vip[cid] return Active(r) and r or nil end
function P.Band(shopId, cid) local t = (P.bands[shopId] or {})[cid] return t and t > os.time() and t or nil end
function P.PublicOpen(D) return P.ShopOpen(D) and P.Opt(D, 'publicOpen', false) == true end
function P.EntryFee(D) return P.Int(P.Opt(D, 'entryFee', E.defaultFee), 0, E.maxFee, E.defaultFee) end

local function Teleport(src, pt)
    local ped = GetPlayerPed(src)
    if ped == 0 or not pt then return end
    SetEntityCoords(ped, pt.x + 0.0, pt.y + 0.0, pt.z + 0.0, false, false, false, false)
    if pt.h then SetEntityHeading(ped, pt.h + 0.0) end
end

local function NotifyDoor(D, msg)
    for _, s in ipairs(P.CrewOnDuty(D.id)) do if P.Can(s, 'door') then P.Notify(s, msg, 'inform') end end
end

-- ---------------------------------------------------------------------
-- Entrée (tout joueur)
-- ---------------------------------------------------------------------
-- Ce que voit le joueur au point Entrée avant de payer
P.Pub.entryInfo = { fn = function(src, d)
    local D = P.shops[tonumber(d.shop) or 0]
    if not D or D.deleted or not D.points.door then return { error = 'Boîte introuvable.' } end
    if not P.NearPoint(src, D.points.door, 3.0) then return { error = 'Approchez-vous de l\'entrée.' } end
    local cid = P.Cid(src)
    local member = P.ShopOf(src)
    local staff = member and member.id == D.id
    local ban = cid and P.IsBanned(D.id, cid)
    return { shop = D.name, open = P.PublicOpen(D), fee = P.EntryFee(D), staff = staff, vip = cid and P.IsVip(D.id, cid) ~= nil or false,
        band = cid and P.Band(D.id, cid) or nil, banned = ban and { reason = ban.reason, expires = ban.expires } or nil, inside = D.points.inside ~= nil,
        now = os.time() }
end }

local entering = {}
P.Pub.enter = { fn = function(src, d)
    local D = P.shops[tonumber(d.shop) or 0]
    if not D or D.deleted or not D.points.door then return { error = 'Boîte introuvable.' } end
    if not P.NearPoint(src, D.points.door, 3.0) then return { error = 'Approchez-vous de l\'entrée.' } end
    local cid = P.Cid(src)
    if not cid then return { error = 'Personnage non chargé.' } end
    local member = P.ShopOf(src)
    local staff = member and member.id == D.id
    if not staff then
        local ban = P.IsBanned(D.id, cid)
        if ban then return { error = ('Entrée refusée : vous êtes sur la liste noire de %s%s.'):format(D.name, ban.reason and (' (' .. ban.reason .. ')') or '') } end
        if not P.PublicOpen(D) then return { error = ('%s est fermée pour le moment.'):format(D.name) } end
    end
    if entering[src] then return { error = 'Paiement en cours.' } end
    entering[src] = true
    local ok, res = pcall(function()
        local why, paid = nil, 0
        if staff then why = 'personnel'
        elseif P.Band(D.id, cid) then why = 'bracelet'
        elseif P.IsVip(D.id, cid) then why = 'VIP'
        else
            local fee = P.EntryFee(D)
            if fee > 0 then
                local method = d.method == 'cash' and 'cash' or 'bank'
                if not P.ChargeWith(src, fee, method, ('Entrée %s'):format(D.name)) then
                    return { error = method == 'cash' and 'Pas assez d\'espèces.' or 'Solde bancaire insuffisant.' }
                end
                paid = fee
                local uid = P.Uid('ENT')
                P.SocietyAdd(D, fee, ('Entrée · %s'):format(P.Name(src)))
                P.Tx(D, { type = 'in', category = 'entry', amount = fee, reason = 'Entrée', targetCid = cid, targetName = P.Name(src), ref = uid })
                MySQL.insert.await([[INSERT INTO `cl_sales` (`uid`, `shop_id`, `kind`, `price`, `method`, `buyer_cid`, `buyer_name`) VALUES (?, ?, 'entry', ?, ?, ?, ?)]],
                    { uid, D.id, fee, method, cid, P.Name(src) })
            end
            why = paid > 0 and 'payé' or 'gratuit'
        end
        if not staff then
            P.bands[D.id] = P.bands[D.id] or {}
            if not P.Band(D.id, cid) then P.bands[D.id][cid] = os.time() + E.wristband end
            NotifyDoor(D, ('Entrée : %s (%s%s).'):format(P.Name(src), why, paid > 0 and (' ' .. paid .. ' $') or ''))
        end
        if D.points.inside then Teleport(src, D.points.inside) end
        local msg = paid > 0 and ('Entrée payée : %d $. Bracelet valable %d h, bonne soirée !'):format(paid, math.floor(E.wristband / 3600))
            or ('Bienvenue à %s (%s).'):format(D.name, why)
        return { ok = true, message = msg }
    end)
    entering[src] = nil
    if not ok then print(('^1[CLUB] Entrée : %s^0'):format(tostring(res))) return { error = 'Erreur à l\'entrée.' } end
    return res
end }
AddEventHandler('playerDropped', function() entering[source] = nil end)

-- Sortie (point Intérieur) : toujours possible
P.Pub.leave = { fn = function(src, d)
    local D = P.shops[tonumber(d.shop) or 0]
    if not D or not D.points.inside or not D.points.door then return { error = 'Sortie introuvable.' } end
    if not P.NearPoint(src, D.points.inside, 3.0) then return { error = 'Approchez-vous de la sortie.' } end
    Teleport(src, D.points.door)
    return { ok = true }
end }

-- ---------------------------------------------------------------------
-- Videur : contrôle de la personne la plus proche
-- ---------------------------------------------------------------------
local function NearestOther(src, radius)
    local c = P.Coords(src)
    if not c then return nil end
    local best, bestD
    for id in pairs(core:GetPlayers()) do
        if id ~= src then
            local tc = P.Coords(id)
            local d = tc and #(tc - c) or 9999
            if d <= radius and (not bestD or d < bestD) then best, bestD = id, d end
        end
    end
    return best, bestD
end

P.Actions.doorCheck = { perm = 'door', duty = true, fn = function(src, _, D)
    local t = NearestOther(src, E.checkDistance)
    if not t then return { error = ('Personne à moins de %d m.'):format(math.floor(E.checkDistance)) } end
    local cid = P.Cid(t)
    local ban, vip, band = P.IsBanned(D.id, cid), P.IsVip(D.id, cid), P.Band(D.id, cid)
    local member = P.ShopOf(t)
    return { target = { id = t, cid = cid, name = P.Name(t), staff = member ~= nil and member.id == D.id, vip = vip ~= nil, band = band,
        banned = ban and { reason = ban.reason, expires = ban.expires } or nil }, now = os.time() }
end }

-- Retirer le bracelet (expulsion) : le joueur devra repayer pour revenir
P.Actions.doorKick = { perm = 'door', duty = true, fn = function(src, d, D)
    local t = tonumber(d.target)
    if not t or not P.GetPlayer(t) then return { error = 'Joueur introuvable.' } end
    if P.Dist(src, t) > E.checkDistance + 2.0 then return { error = 'Trop loin.' } end
    local cid = P.Cid(t)
    if P.bands[D.id] then P.bands[D.id][cid] = nil end
    if D.points.inside and D.points.door and P.Coords(t) and #(P.Coords(t) - P.Vec(D.points.inside)) < 60.0 then Teleport(t, D.points.door) end
    P.Notify(t, ('Vous avez été raccompagné à la sortie de %s.'):format(D.name), 'error')
    P.AddLog(D.id, src, cid, P.Name(t), 'Expulsion', nil, nil, nil)
    return { ok = true, message = ('%s : bracelet retiré.'):format(P.Name(t)) }
end }

-- ---------------------------------------------------------------------
-- Listes VIP / noire
-- ---------------------------------------------------------------------
P.Actions.lists = { perm = 'door', fn = function(src, _, D)
    local out = { vip = {}, ban = {} }
    for kind, set in pairs(Lists(D.id)) do
        for _, r in pairs(set) do
            if Active(r) then out[kind][#out[kind] + 1] = { cid = r.cid, name = r.name, reason = r.reason, expires = r.expires, by = r.by, t = r.t } end
        end
        table.sort(out[kind], function(a, b) return (a.name or '') < (b.name or '') end)
    end
    local bands = {}
    for cid, t in pairs(P.bands[D.id] or {}) do
        if t > os.time() then
            local s = core:GetSourceByCitizenId(cid)
            bands[#bands + 1] = { cid = cid, name = s and P.Name(s) or cid, expires = t, online = s ~= nil }
        end
    end
    table.sort(bands, function(a, b) return a.expires > b.expires end)
    return { vip = out.vip, ban = out.ban, bands = bands, canEdit = P.Can(src, 'lists'), now = os.time(), maxBanDays = E.maxBanDays }
end }

-- Ajout : par ID serveur (joueur connecté) ou par la personne la plus proche
P.Actions.listAdd = { perm = 'lists', fn = function(src, d, D)
    local kind = d.kind == 'ban' and 'ban' or d.kind == 'vip' and 'vip' or nil
    if not kind then return { error = 'Liste inconnue.' } end
    local t = tonumber(d.target)
    if d.nearest then t = NearestOther(src, E.checkDistance) end
    local cid = t and P.Cid(t)
    if not cid then return { error = d.nearest and 'Personne à proximité.' or 'Joueur introuvable (ID serveur).' } end
    local member = P.employees[cid]
    if kind == 'ban' and member and member.shop_id == D.id then return { error = 'Un employé de la boîte ne peut pas être sur la liste noire.' } end
    local days = kind == 'ban' and P.Int(d.days, 0, E.maxBanDays, 0) or 0
    local expires = days > 0 and (os.time() + days * 86400) or nil
    local reason = P.Clean(d.reason, 160)
    local name = P.Name(t)
    MySQL.query.await([[INSERT INTO `cl_lists` (`shop_id`, `kind`, `citizenid`, `name`, `reason`, `expires_at`, `actor_name`) VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `name` = VALUES(`name`), `reason` = VALUES(`reason`), `expires_at` = VALUES(`expires_at`), `actor_name` = VALUES(`actor_name`)]],
        { D.id, kind, cid, name, reason ~= '' and reason or nil, expires, P.Name(src) })
    Lists(D.id)[kind][cid] = { cid = cid, name = name, reason = reason ~= '' and reason or nil, expires = expires, by = P.Name(src), t = os.time() }
    if kind == 'ban' then
        if P.bands[D.id] then P.bands[D.id][cid] = nil end
        if D.points.inside and D.points.door and P.Coords(t) and #(P.Coords(t) - P.Vec(D.points.inside)) < 60.0 then Teleport(t, D.points.door) end
        P.Notify(t, ('Vous êtes interdit d\'entrée à %s%s.'):format(D.name, days > 0 and (' pendant ' .. days .. ' jour(s)') or ''), 'error')
    else
        P.Notify(t, ('Vous êtes sur la liste VIP de %s : entrée gratuite.'):format(D.name), 'success')
    end
    P.AddLog(D.id, src, cid, name, kind == 'ban' and 'Liste noire' or 'Liste VIP', nil, nil, reason ~= '' and reason or nil)
    return { ok = true, message = ('%s ajouté à la %s%s.'):format(name, kind == 'ban' and 'liste noire' or 'liste VIP', days > 0 and (' pour ' .. days .. ' jour(s)') or '') }
end }

P.Actions.listRemove = { perm = 'lists', fn = function(src, d, D)
    local kind = d.kind == 'ban' and 'ban' or d.kind == 'vip' and 'vip' or nil
    local cid = tostring(d.cid or '')
    local r = kind and Lists(D.id)[kind][cid]
    if not r then return { error = 'Personne introuvable dans cette liste.' } end
    MySQL.update.await('DELETE FROM `cl_lists` WHERE `shop_id` = ? AND `kind` = ? AND `citizenid` = ?', { D.id, kind, cid })
    Lists(D.id)[kind][cid] = nil
    P.AddLog(D.id, src, cid, r.name, kind == 'ban' and 'Retrait liste noire' or 'Retrait liste VIP', nil, nil, nil)
    return { ok = true, message = ('%s retiré de la %s.'):format(r.name or cid, kind == 'ban' and 'liste noire' or 'liste VIP') }
end }

-- ---------------------------------------------------------------------
-- Ouverture au public, prix d'entrée
-- ---------------------------------------------------------------------
P.Actions.openState = { perm = 'tablet', fn = function(src, _, D)
    return { publicOpen = P.PublicOpen(D), fee = P.EntryFee(D), maxFee = E.maxFee, canEdit = P.Can(src, 'open'), hasDoor = D.points.door ~= nil,
        hasInside = D.points.inside ~= nil, canAnnounce = P.Can(src, 'announce'), announceIn = math.max(0, (P.Opt(D, 'lastAnnounce', 0) + Config.Announce.cooldown) - os.time()) }
end }

P.Actions.openSet = { perm = 'open', fn = function(src, d, D)
    local msg = {}
    if d.publicOpen ~= nil then
        local on = d.publicOpen == true
        if on and not D.points.door then return { error = 'Le staff n\'a pas encore placé le point Entrée.' } end
        D.options.publicOpen = on
        msg[#msg + 1] = on and 'Boîte ouverte au public.' or 'Boîte fermée au public (le personnel entre toujours).'
        P.AddLog(D.id, src, nil, nil, on and 'Ouverture' or 'Fermeture', nil, nil, nil)
    end
    if d.fee ~= nil then
        local fee = P.Int(d.fee, 0, E.maxFee, nil)
        if not fee then return { error = ('Prix d\'entrée invalide (0 à %d $).'):format(E.maxFee) } end
        D.options.entryFee = fee
        msg[#msg + 1] = fee > 0 and ('Entrée : %d $.'):format(fee) or 'Entrée gratuite.'
        P.AddLog(D.id, src, nil, nil, 'Prix d\'entrée', nil, nil, ('%d $'):format(fee))
    end
    P.SaveShop(D)
    P.Touch()
    P.PushShop(D.id)
    return { ok = true, message = table.concat(msg, ' ') }
end }

-- ---------------------------------------------------------------------
-- Annonce à toute la ville
-- ---------------------------------------------------------------------
P.Actions.announce = { perm = 'announce', fn = function(src, d, D)
    local text = P.Clean(d.text, Config.Announce.maxLength)
    if #text < 5 then return { error = 'Annonce trop courte.' } end
    local last = P.Opt(D, 'lastAnnounce', 0)
    local left = last + Config.Announce.cooldown - os.time()
    if left > 0 then return { error = ('Prochaine annonce possible dans %d min.'):format(math.ceil(left / 60)) } end
    D.options.lastAnnounce = os.time()
    P.SaveShop(D)
    TriggerClientEvent('club:client:announce', -1, { shop = D.name, text = text, open = P.PublicOpen(D), fee = P.EntryFee(D) })
    P.AddLog(D.id, src, nil, nil, 'Annonce', nil, nil, text)
    P.Log(src, 'Annonce', ('%s : %s'):format(D.name, text))
    return { ok = true, message = 'Annonce envoyée à toute la ville.' }
end }

-- ---------------------------------------------------------------------
-- Coffre
-- ---------------------------------------------------------------------
P.Actions.stash = { perm = 'stash', fn = function(src, _, D)
    if not D.points.stash then return { error = 'Le staff n\'a pas encore placé le coffre de la boîte.' } end
    if not P.NearPoint(src, D.points.stash, 2.0) then return { error = 'Approchez-vous du coffre.' } end
    P.RegisterStash(D)
    local ok, opened = pcall(function() return exports.elyzea_inventory:OpenInventory(src, 'stash', ('club:%d'):format(D.id)) end)
    if not ok or not opened then return { error = 'Ouverture du coffre impossible.' } end
    return { ok = true }
end }
