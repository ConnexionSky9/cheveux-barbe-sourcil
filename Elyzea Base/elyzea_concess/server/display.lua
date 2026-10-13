-- =====================================================================
--  ELYZEA CONCESSION - serveur : véhicules en exposition
--  · Emplacements créés par le staff ; un employé autorisé (« display ») y place
--    un modèle exposable de SA concession, le retire, le remplace ou le tourne.
--  · Un emplacement = un véhicule au plus (clé primaire slot_id : aucun doublon).
--  · Les véhicules exposés sont affichés par chaque joueur comme objets LOCAUX
--    (non réseau) : personne ne peut y monter, les voler, les déplacer ni en avoir
--    les clés, et ils ne sont jamais enregistrés dans un garage. Ils sont
--    restaurés automatiquement après un redémarrage (table cd_display).
--  · Une vente ne retire pas le véhicule exposé : l'acheteur reçoit un véhicule neuf.
-- =====================================================================
local P = Concess

P.slots = {}     -- [shop][slot] = { id, shop_id, label, x, y, z, h, enabled }
P.display = {}   -- [shop][slot] = { slot_id, model_id, model, h, color1, color2, placed_by }

local function Load()
    P.slots, P.display = {}, {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `cd_slots`') or {}) do
        P.slots[r.shop_id] = P.slots[r.shop_id] or {}
        P.slots[r.shop_id][r.id] = { id = r.id, shop_id = r.shop_id, label = r.label, x = tonumber(r.x), y = tonumber(r.y), z = tonumber(r.z), h = tonumber(r.h) or 0,
            enabled = r.enabled == 1 or r.enabled == true }
    end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `cd_display`') or {}) do
        P.display[r.shop_id] = P.display[r.shop_id] or {}
        P.display[r.shop_id][r.slot_id] = { slot_id = r.slot_id, model_id = r.model_id, model = r.model, h = tonumber(r.h), color1 = tonumber(r.color1),
            color2 = tonumber(r.color2), placed_by = r.placed_by }
    end
end

-- Liste publiée à tous les joueurs (affichage local)
function P.PublishDisplay()
    local list = {}
    for sid, slots in pairs(P.display) do
        local D = P.shops[sid]
        if P.ShopOpen(D) then
            for slotId, d in pairs(slots) do
                local s = P.slots[sid] and P.slots[sid][slotId]
                local m = P.models[d.model_id]
                if s and s.enabled and m and not m.removed and m.enabled then
                    list[#list + 1] = { shop = sid, slot = slotId, x = s.x, y = s.y, z = s.z, h = d.h or s.h, model = d.model, c1 = d.color1, c2 = d.color2, label = m.label }
                end
            end
        end
    end
    GlobalState.concessDisplay = list
end

function P.ClearSlot(shopId, slotId)
    if not (P.display[shopId] and P.display[shopId][slotId]) then return end
    MySQL.update.await('DELETE FROM `cd_display` WHERE `slot_id` = ?', { slotId })
    P.display[shopId][slotId] = nil
end
-- Retire un modèle de toutes les expositions (ou d'une seule concession)
function P.ClearDisplayOf(modelId, why, onlyShop)
    local changed = false
    for sid, slots in pairs(P.display) do
        if not onlyShop or sid == onlyShop then
            for slotId, d in pairs(slots) do
                if d.model_id == modelId then P.ClearSlot(sid, slotId) changed = true print(('^3[CONCESS] Exposition retirée (%s) : %s^0'):format(why or '', d.model)) end
            end
        end
    end
    if changed then P.PublishDisplay() end
end
function P.ClearShopDisplay(shopId)
    for slotId in pairs(P.display[shopId] or {}) do P.ClearSlot(shopId, slotId) end
    P.PublishDisplay()
end

P.OnReady[#P.OnReady + 1] = function()
    Load()
    P.PublishDisplay()
end

-- ---------------------------------------------------------------------
-- Employés
-- ---------------------------------------------------------------------
local function SlotView(D, s)
    local d = P.display[D.id] and P.display[D.id][s.id]
    local m = d and P.models[d.model_id]
    return { id = s.id, label = s.label or ('Emplacement %d'):format(s.id), enabled = s.enabled, x = s.x, y = s.y, h = d and d.h or s.h,
        model = d and d.model or nil, modelId = d and d.model_id or nil, modelLabel = m and m.label or nil, placedBy = d and d.placed_by or nil }
end

P.Actions.displayList = { perm = 'catalog', fn = function(src, _, D)
    local list = {}
    for _, s in pairs(P.slots[D.id] or {}) do list[#list + 1] = SlotView(D, s) end
    table.sort(list, function(a, c) return a.id < c.id end)
    local models = {}
    for _, o in ipairs(P.ShopOffers(D, 'all')) do if o.displayable then models[#models + 1] = { id = o.id, label = o.label, category = o.category } end end
    return { list = list, models = models, canDisplay = P.Can(src, 'display') }
end }

local function Slot(D, id)
    local s = P.slots[D.id] and P.slots[D.id][tonumber(id) or 0]
    if not s then return nil, 'Emplacement introuvable.' end
    if not s.enabled then return nil, 'Emplacement désactivé par le staff.' end
    return s
end

-- Placer (ou remplacer avec replace = true) un modèle sur un emplacement
P.Actions.displayPlace = { perm = 'display', duty = true, fn = function(src, d, D)
    local s, why = Slot(D, d.slot)
    if not s then return { error = why } end
    local m = P.models[tonumber(d.model) or 0]
    local o = m and P.Offer(D, m)
    if not o then return { error = 'Ce modèle n\'est pas proposé par votre concession.' } end
    if not o.displayable then return { error = 'Ce modèle n\'est pas autorisé en exposition dans votre concession.' } end
    P.display[D.id] = P.display[D.id] or {}
    local cur = P.display[D.id][s.id]
    if cur and d.replace ~= true then return { error = ('Emplacement occupé par %s : choisissez « Remplacer ».'):format(cur.model), occupied = true } end
    local h = d.h ~= nil and ((tonumber(d.h) or s.h) % 360) or s.h
    local c1, c2 = P.Int(d.color1, 0, 160, nil), P.Int(d.color2, 0, 160, nil)
    MySQL.query.await([[INSERT INTO `cd_display` (`slot_id`, `shop_id`, `model_id`, `model`, `h`, `color1`, `color2`, `placed_by`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `model_id` = VALUES(`model_id`), `model` = VALUES(`model`), `h` = VALUES(`h`), `color1` = VALUES(`color1`), `color2` = VALUES(`color2`),
        `placed_by` = VALUES(`placed_by`), `placed_at` = NOW()]], { s.id, D.id, m.id, m.model, h, c1, c2, P.Name(src) })
    P.display[D.id][s.id] = { slot_id = s.id, model_id = m.id, model = m.model, h = h, color1 = c1, color2 = c2, placed_by = P.Name(src) }
    P.PublishDisplay()
    P.Log(src, cur and 'Exposition remplacée' or 'Mise en exposition', ('%s · %s · %s'):format(D.name, s.label or ('#' .. s.id), m.label))
    return { ok = true, message = ('%s exposé sur %s.'):format(m.label, s.label or ('l\'emplacement %d'):format(s.id)) }
end }

P.Actions.displayRemove = { perm = 'display', duty = true, fn = function(src, d, D)
    local s = P.slots[D.id] and P.slots[D.id][tonumber(d.slot) or 0]
    if not s or not (P.display[D.id] and P.display[D.id][s.id]) then return { error = 'Aucun véhicule sur cet emplacement.' } end
    local model = P.display[D.id][s.id].model
    P.ClearSlot(D.id, s.id)
    P.PublishDisplay()
    P.Log(src, 'Retrait d\'exposition', ('%s · %s · %s'):format(D.name, s.label or ('#' .. s.id), model))
    return { ok = true, message = 'Véhicule retiré de l\'exposition.' }
end }

P.Actions.displayRotate = { perm = 'display', duty = true, fn = function(_, d, D)
    local s, why = Slot(D, d.slot)
    if not s then return { error = why } end
    local cur = P.display[D.id] and P.display[D.id][s.id]
    if not cur then return { error = 'Aucun véhicule sur cet emplacement.' } end
    cur.h = ((tonumber(cur.h) or s.h) + (tonumber(d.delta) or 15)) % 360
    MySQL.update.await('UPDATE `cd_display` SET `h` = ? WHERE `slot_id` = ?', { cur.h, s.id })
    P.PublishDisplay()
    return { ok = true }
end }
