-- =====================================================================
--  ELYZEA DYNASTY 8 - serveur : décoration intérieure
--  · Props décoratifs uniquement (modèles autorisés : config + ajouts du staff).
--  · Sauvegardés en base (modèle, position, rotation, bien, contrat), réaffichés à chaque entrée.
--  · Liés au contrat : un nouveau résident ne récupère pas la décoration de l'ancien
--    (elle reste en base, en réserve). Changement d'intérieur : objets mis en réserve,
--    le résident les replace.
-- =====================================================================
local P = Dynasty

function P.DecoCatalog()
    local list, seen = {}, {}
    for _, c in ipairs(Config.Deco.catalog) do list[#list + 1] = c seen[c.model:lower()] = true end
    for _, c in ipairs(P.GetSetting('decoExtra', {})) do
        if type(c) == 'table' and c.model and not seen[tostring(c.model):lower()] then list[#list + 1] = c seen[c.model:lower()] = true end
    end
    return list
end
local function Allowed(model)
    model = tostring(model or ''):lower()
    for _, c in ipairs(P.DecoCatalog()) do if c.model:lower() == model then return c end end
end

function P.DecoSummary(pid, contractId)
    local pr = P.props[pid]
    local placed = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `d8_deco` WHERE `property_id` = ? AND `contract_id` = ? AND `stored` = 0', { pid, contractId })) or 0
    local reserve = MySQL.query.await('SELECT `id`, `model` FROM `d8_deco` WHERE `property_id` = ? AND `contract_id` = ? AND `stored` = 1', { pid, contractId }) or {}
    return { placed = placed, limit = pr and pr.decoLimit or 0, reserve = reserve, catalog = P.DecoCatalog() }
end

-- Objets à afficher (tout joueur présent dans le logement)
P.Pub.decoList = { fn = function(src, d)
    local pid = tonumber(d.pid) or 0
    local i = P.inside[src]
    local c = P.Contract(pid)
    if not i or i.pid ~= pid or i.area ~= 'home' or not c then return { list = {} } end
    return { list = MySQL.query.await('SELECT `id`, `model`, `x`, `y`, `z`, `rx`, `ry`, `rz` FROM `d8_deco` WHERE `property_id` = ? AND `contract_id` = ? AND `stored` = 0', { pid, c.id }) or {} }
end }

local function DecoCheck(src, pid)
    local pr = P.props[tonumber(pid) or 0]
    if not pr then return nil, 'Bien introuvable.' end
    local i = P.inside[src]
    if not i or i.pid ~= pr.id or i.area ~= 'home' then return nil, 'Vous devez être dans le logement.' end
    local role, rights = P.RoleOf(src, pr.id)
    if not role or not rights.manage then return nil, 'Seuls les résidents autorisés à gérer le logement décorent.' end
    return pr, P.Contract(pr.id)
end

local function ValidPos(pr, d)
    local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
    if not x or not y or not z then return nil end
    local anchor = pr.points.exit or (P.interiors[pr.interiorId or 0])
    if anchor and #(vector3(x, y, z) - vector3(anchor.x, anchor.y, anchor.z)) > Config.Deco.maxDistance then return nil end
    local r = function(v) v = tonumber(v) or 0.0 return math.floor((v % 360) * 100) / 100 end
    return { x = x, y = y, z = z, rx = r(d.rx), ry = r(d.ry), rz = r(d.rz) }
end

local function Refresh(pid)
    for s, i in pairs(P.inside) do if i.pid == pid and i.area == 'home' then TriggerClientEvent('d8:client:decoRefresh', s) end end
end

P.Pub.decoPlace = { fn = function(src, d)
    local pr, c = DecoCheck(src, d.pid)
    if not pr then return { error = c } end
    local item = Allowed(d.model)
    if not item then return { error = 'Objet non autorisé.' } end
    local p = ValidPos(pr, d)
    if not p then return { error = 'Position hors du logement.' } end
    local n = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `d8_deco` WHERE `property_id` = ? AND `contract_id` = ? AND `stored` = 0', { pr.id, c.id })) or 0
    if n >= pr.decoLimit then return { error = ('Limite atteinte (%d objets).'):format(pr.decoLimit) } end
    MySQL.insert.await('INSERT INTO `d8_deco` (`property_id`, `contract_id`, `interior_id`, `model`, `x`, `y`, `z`, `rx`, `ry`, `rz`, `placed_by`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { pr.id, c.id, pr.interiorId, item.model, p.x, p.y, p.z, p.rx, p.ry, p.rz, P.Name(src) })
    Refresh(pr.id)
    return { ok = true, message = ('« %s » placé (%d/%d).'):format(item.label, n + 1, pr.decoLimit) }
end }

-- Déplacer un objet placé, ou replacer un objet de la réserve
P.Pub.decoMove = { fn = function(src, d)
    local pr, c = DecoCheck(src, d.pid)
    if not pr then return { error = c } end
    local row = MySQL.single.await('SELECT `id`, `stored` FROM `d8_deco` WHERE `id` = ? AND `property_id` = ? AND `contract_id` = ?', { tonumber(d.id) or 0, pr.id, c.id })
    if not row then return { error = 'Objet introuvable.' } end
    local p = ValidPos(pr, d)
    if not p then return { error = 'Position hors du logement.' } end
    if row.stored == 1 or row.stored == true then
        local n = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `d8_deco` WHERE `property_id` = ? AND `contract_id` = ? AND `stored` = 0', { pr.id, c.id })) or 0
        if n >= pr.decoLimit then return { error = ('Limite atteinte (%d objets).'):format(pr.decoLimit) } end
    end
    MySQL.update.await('UPDATE `d8_deco` SET `x` = ?, `y` = ?, `z` = ?, `rx` = ?, `ry` = ?, `rz` = ?, `stored` = 0, `interior_id` = ? WHERE `id` = ?',
        { p.x, p.y, p.z, p.rx, p.ry, p.rz, pr.interiorId, row.id })
    Refresh(pr.id)
    return { ok = true, message = 'Objet placé.' }
end }

P.Pub.decoDelete = { fn = function(src, d)
    local pr, c = DecoCheck(src, d.pid)
    if not pr then return { error = c } end
    local n = MySQL.update.await('DELETE FROM `d8_deco` WHERE `id` = ? AND `property_id` = ? AND `contract_id` = ?', { tonumber(d.id) or 0, pr.id, c.id })
    if (tonumber(n) or 0) == 0 then return { error = 'Objet introuvable.' } end
    Refresh(pr.id)
    return { ok = true, message = 'Objet retiré.' }
end }

-- Staff : modèles supplémentaires autorisés
P.Admin.decoModel = { fn = function(src, d)
    local list = P.GetSetting('decoExtra', {})
    local model = tostring(d.model or ''):gsub('[^%w_%-]', ''):sub(1, 60)
    if model == '' then return { error = 'Modèle invalide.' } end
    if d.remove then
        for i = #list, 1, -1 do if tostring(list[i].model):lower() == model:lower() then table.remove(list, i) end end
    else
        for _, c in ipairs(Config.Deco.catalog) do if c.model:lower() == model:lower() then return { error = 'Déjà dans le catalogue de base.' } end end
        for _, c in ipairs(list) do if tostring(c.model):lower() == model:lower() then return { error = 'Déjà ajouté.' } end end
        list[#list + 1] = { model = model, label = P.Clean(d.label, 40) ~= '' and P.Clean(d.label, 40) or model, cat = P.Clean(d.cat, 30) ~= '' and P.Clean(d.cat, 30) or 'Divers' }
    end
    P.SetSetting('decoExtra', list)
    P.AdminLog(src, d.remove and 'Modèle de décoration retiré' or 'Modèle de décoration ajouté', model)
    return { ok = true, message = d.remove and 'Modèle retiré (les objets déjà placés restent).' or 'Modèle ajouté au catalogue.' }
end }
