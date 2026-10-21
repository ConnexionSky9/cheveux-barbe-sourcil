-- =====================================================================
--  ELYZEA LABS · serveur : équipements (achat, placement, déplacement, rangement, revente)
--  · Droit « equipment », catégorie débloquée par le niveau du laboratoire, limite par niveau.
--  · Position revérifiée : dans la zone de l'intérieur, loin de la sortie / du cercle bleu /
--    du coffre, à distance des autres équipements, près du joueur.
--  · Paiement avec le compte du groupe, sous verrou (pas de double achat).
-- =====================================================================
local L = Labs
L.equipBusy = {}   -- [equipmentId] = src qui l'utilise

function L.PlacedList(lab)
    local list = {}
    for _, e in pairs(lab.equipment) do
        if e.placed then list[#list + 1] = { id = e.id, type = e.type, x = e.x, y = e.y, z = e.z, rx = e.rx, ry = e.ry, rz = e.rz } end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function L.EquipCount(lab)
    local n, placed = 0, 0
    for _, e in pairs(lab.equipment) do n = n + 1 if e.placed then placed = placed + 1 end end
    return n, placed
end

function L.PushEquipment(lab)
    local list = L.PlacedList(lab)
    for src, i in pairs(L.inside) do if i.lab == lab.id then TriggerClientEvent('elyzea_labs:equipment', src, list) end end
end

-- Contrôles communs : dans le laboratoire, droit « equipment »
local function check(src, d)
    local lab = L.list[tonumber(d.lab) or -1]
    if not lab then return nil, 'Laboratoire introuvable.' end
    if not L.InsideLab(src, lab.id) then return nil, 'Tu dois être dans le laboratoire.' end
    if not L.Can(src, lab, 'equipment') then return nil, 'Tu n\'as pas le droit de gérer les équipements.' end
    return lab
end

local function unlockedType(lab, typ)
    local e = Config.Equipment[typ]
    if not e then return nil, 'Équipement inconnu.' end
    local need = LabRules.EquipmentLevel(typ)
    if lab.level < need then return nil, ('Équipement verrouillé : niveau %d requis.'):format(need) end
    return e
end

-- Position valide dans l'intérieur ? exceptId : équipement déplacé (ignoré pour l'espacement)
function L.ValidPos(src, lab, d, exceptId)
    local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z then return nil, 'Position invalide.' end
    local it = L.Interior(lab.interior)
    local b = it.bounds
    local p = vector3(x, y, z)
    if #(vector2(x, y) - vector2(b.x, b.y)) > b.r or z < b.minZ or z > b.maxZ then return nil, 'Emplacement hors du laboratoire.' end
    for _, k in ipairs({ 'spawn', 'manage', 'stash' }) do
        if it[k] and #(p - L.Vec(it[k])) < Config.KeepClear then return nil, 'Emplacement interdit (passage à garder libre).' end
    end
    for _, e in pairs(lab.equipment) do
        if e.placed and e.id ~= exceptId and #(p - vector3(e.x, e.y, e.z)) < Config.MinSpacing then return nil, 'Trop près d\'un autre équipement.' end
    end
    if src and L.Dist(src, p) > 10.0 then return nil, 'Place l\'équipement près de toi.' end
    local r = function(v) v = tonumber(v) or 0.0 if v ~= v then v = 0.0 end return math.floor((v % 360) * 100 + 0.5) / 100 end
    return { x = x, y = y, z = z, rx = r(d.rx), ry = r(d.ry), rz = r(d.rz) }
end

local function maxEquip(lab) return LabRules.Level(lab.level).maxEquipment or 8 end

-- Acheter (et poser si une position est donnée) : un seul paiement, sous verrou
local function buy(src, lab, typ, pos)
    local e, err = unlockedType(lab, typ)
    if not e then return { error = err } end
    local n = L.EquipCount(lab)
    if n >= maxEquip(lab) then return { error = ('Limite atteinte : %d équipements au niveau %d.'):format(maxEquip(lab), lab.level) } end
    if not L.Lock('lab:' .. lab.id) then return { error = 'Une opération est déjà en cours, réessaie.' } end
    local ok, perr = L.GroupPay(lab.owner, e.price, ('Équipement « %s » (%s)'):format(e.label, lab.name), src)
    if not ok then L.Unlock('lab:' .. lab.id) return { error = perr or 'Paiement refusé.' } end
    pos = pos or { x = 0.0, y = 0.0, z = 0.0, rx = 0.0, ry = 0.0, rz = 0.0 }
    local id = MySQL.insert.await('INSERT INTO `labs_equipment` (`lab_id`, `type`, `placed`, `x`, `y`, `z`, `rx`, `ry`, `rz`, `price`, `bought_by`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { lab.id, typ, pos.placed and 1 or 0, pos.x, pos.y, pos.z, pos.rx, pos.ry, pos.rz, e.price, L.Name(src) })
    if not id then
        L.GroupCredit(lab.owner, e.price, ('Remboursement : %s'):format(e.label), src)
        L.Unlock('lab:' .. lab.id)
        return { error = 'Erreur de la base de données : le groupe a été remboursé.' }
    end
    lab.equipment[id] = { id = id, type = typ, placed = pos.placed == true, price = e.price, x = pos.x, y = pos.y, z = pos.z, rx = pos.rx, ry = pos.ry, rz = pos.rz }
    L.Unlock('lab:' .. lab.id)
    L.Log(lab.id, 'equipement', L.Name(src), ('achat %s (%s)'):format(typ, L.Money(e.price)))
    if pos.placed then L.PushEquipment(lab) end
    return { ok = true, id = id, message = ('« %s » acheté (%s)%s.'):format(e.label, L.Money(e.price), pos.placed and ' et installé' or ', rangé dans la réserve') }
end

-- Tablette : acheter sans poser (réserve)
L.pub.equipBuy = function(src, d)
    local lab, err = check(src, d)
    if not lab then return { error = err } end
    return buy(src, lab, tostring(d.type or ''), nil)
end

-- Éditeur : poser (achat + pose, ou équipement de la réserve, ou déplacement)
L.pub.equipPlace = function(src, d)
    local lab, err = check(src, d)
    if not lab then return { error = err } end
    local id = tonumber(d.id)
    local pos, perr = L.ValidPos(src, lab, d, id)
    if not pos then return { error = perr } end
    pos.placed = true
    if not id then return buy(src, lab, tostring(d.type or ''), pos) end
    local e = lab.equipment[id]
    if not e then return { error = 'Équipement introuvable.' } end
    if L.equipBusy[id] then return { error = 'Quelqu\'un utilise cet équipement.' } end
    if not unlockedType(lab, e.type) then return { error = 'Équipement verrouillé à ce niveau.' } end
    MySQL.update.await('UPDATE `labs_equipment` SET `placed` = 1, `x` = ?, `y` = ?, `z` = ?, `rx` = ?, `ry` = ?, `rz` = ? WHERE `id` = ? AND `lab_id` = ?',
        { pos.x, pos.y, pos.z, pos.rx, pos.ry, pos.rz, id, lab.id })
    e.placed, e.x, e.y, e.z, e.rx, e.ry, e.rz = true, pos.x, pos.y, pos.z, pos.rx, pos.ry, pos.rz
    L.PushEquipment(lab)
    return { ok = true, message = ('« %s » installé.'):format(Config.Equipment[e.type].label) }
end

L.pub.equipStore = function(src, d)
    local lab, err = check(src, d)
    if not lab then return { error = err } end
    local e = lab.equipment[tonumber(d.id) or -1]
    if not e then return { error = 'Équipement introuvable.' } end
    if L.equipBusy[e.id] then return { error = 'Quelqu\'un utilise cet équipement.' } end
    MySQL.update.await('UPDATE `labs_equipment` SET `placed` = 0 WHERE `id` = ? AND `lab_id` = ?', { e.id, lab.id })
    e.placed = false
    L.PushEquipment(lab)
    return { ok = true, message = 'Équipement rangé dans la réserve.' }
end

L.pub.equipSell = function(src, d)
    local lab, err = check(src, d)
    if not lab then return { error = err } end
    local e = lab.equipment[tonumber(d.id) or -1]
    if not e then return { error = 'Équipement introuvable.' } end
    if L.equipBusy[e.id] then return { error = 'Quelqu\'un utilise cet équipement.' } end
    if not L.Lock('lab:' .. lab.id) then return { error = 'Une opération est déjà en cours, réessaie.' } end
    local n = MySQL.update.await('DELETE FROM `labs_equipment` WHERE `id` = ? AND `lab_id` = ?', { e.id, lab.id })
    if (tonumber(n) or 0) ~= 1 then L.Unlock('lab:' .. lab.id) return { error = 'Équipement introuvable.' } end
    lab.equipment[e.id] = nil
    local refund = math.floor((e.price or 0) * Config.SellRefund / 100)
    if refund > 0 then L.GroupCredit(lab.owner, refund, ('Revente d\'équipement (%s)'):format(lab.name), src) end
    L.Unlock('lab:' .. lab.id)
    L.Log(lab.id, 'equipement', L.Name(src), ('revente %s (%s)'):format(e.type, L.Money(refund)))
    L.PushEquipment(lab)
    return { ok = true, message = ('Équipement revendu : %s rendus au groupe.'):format(L.Money(refund)) }
end

-- Cercle bleu : catalogue (débloqué / verrouillé), réserve et équipements posés
L.pub.editorData = function(src, d)
    local lab, err = check(src, d)
    if not lab then return { error = err } end
    local total = L.EquipCount(lab)
    local out = { lab = lab.id, level = lab.level, count = total, max = maxEquip(lab), catalog = {}, owned = {},
        minSpacing = Config.MinSpacing, keepClear = Config.KeepClear }
    for typ, e in pairs(Config.Equipment) do
        local need = LabRules.EquipmentLevel(typ)
        out.catalog[#out.catalog + 1] = { type = typ, label = e.label, price = e.price, level = need, unlocked = lab.level >= need,
            category = (Config.Categories[e.category] or {}).label, icon = (Config.Categories[e.category] or {}).icon }
    end
    table.sort(out.catalog, function(a, b) if a.level ~= b.level then return a.level < b.level end return a.label < b.label end)
    for _, e in pairs(lab.equipment) do
        out.owned[#out.owned + 1] = { id = e.id, type = e.type, label = (Config.Equipment[e.type] or { label = e.type }).label, placed = e.placed,
            busy = L.equipBusy[e.id] ~= nil, refund = math.floor((e.price or 0) * Config.SellRefund / 100) }
    end
    table.sort(out.owned, function(a, b) return a.id < b.id end)
    return out
end
