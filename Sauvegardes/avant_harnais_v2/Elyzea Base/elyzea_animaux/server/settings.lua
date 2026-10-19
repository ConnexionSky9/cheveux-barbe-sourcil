-- =========================================================
--  ELYZEA ANIMAUX - SERVEUR : réglages effectifs
--  config.lua donne les valeurs par défaut ; le menu admin enregistre
--  ses changements dans la table elyzea_animaux_config, une ligne par
--  section (settings, species, vendors, farm, scan). Réinitialiser une
--  section ne touche jamais aux autres ni aux animaux possédés.
-- =========================================================
A = {
    Ready = false,
    S = {},            -- réglages généraux (Config.Defaults)
    Species = {},      -- surcharges : [espèce] = { enabled, price, fees, variants = { [id] = { enabled, label, extra } }, custom = { ... } }
    Vendors = {},      -- liste des vendeurs
    Farm = {},         -- ferme (réglages + enclos)
    Scan = {},         -- [modèle] = résultat du dernier scan staff
    Diag = { saveErrors = {}, loadErrors = {}, clientIssues = {} },
}

-- ---------------------------------------------------------
--  Schéma des réglages généraux (bornes + libellés du menu)
-- ---------------------------------------------------------
A.Sections = {
    { id = 'general', label = 'Général' }, { id = 'follow', label = 'Suivi du propriétaire' },
    { id = 'needs', label = 'Besoins (faim, soif, santé)' }, { id = 'harness', label = 'Harnais' }, { id = 'leash', label = 'Laisse' },
    { id = 'vehicle', label = 'Véhicules' }, { id = 'exotic', label = 'Animaux exotiques' }, { id = 'vet', label = 'Vétérinaire' },
}
A.Schema = {
    { key = 'general.enabled', type = 'bool', label = 'Système d\'animaux activé', help = 'Coupé : plus d\'achat ni de sortie (les animaux sortis sont rangés).' },
    { key = 'general.maxOwned', type = 'int', min = 1, max = 20, label = 'Animaux possédés (max)', help = 'Par personnage.' },
    { key = 'general.maxOut', type = 'int', min = 1, max = 5, label = 'Animaux sortis en même temps (max)', help = 'Par personnage.' },
    { key = 'general.invincible', type = 'bool', label = 'Animaux invincibles', help = 'Sinon ils peuvent être blessés et deviennent indisponibles jusqu\'aux soins.' },
    { key = 'general.autoStoreDistance', type = 'int', min = 50, max = 2000, unit = 'm', label = 'Rangement automatique au-delà de', help = 'Propriétaire trop loin de son animal.' },
    { key = 'general.storeDelay', type = 'int', min = 5, max = 600, unit = 's', label = 'Délai avant rangement automatique', help = 'Temps passé au-delà de la distance.' },
    { key = 'follow.distance', type = 'num', min = 1.0, max = 8.0, step = 0.1, unit = 'm', label = 'Distance de suivi', help = 'Derrière le propriétaire (multipliée pour les chats et grands animaux).' },
    { key = 'follow.side', type = 'num', min = 0.0, max = 3.0, step = 0.1, unit = 'm', label = 'Décalage sur le côté', help = 'Évite que l\'animal marche dans les jambes.' },
    { key = 'follow.stuckTeleport', type = 'bool', label = 'Replacer un animal bloqué', help = 'Seulement s\'il est loin, immobile et hors de l\'écran.' },
    { key = 'follow.teleportDistance', type = 'int', min = 15, max = 200, unit = 'm', label = 'Distance « bloqué »', help = 'À partir de laquelle un animal immobile est replacé.' },
    { key = 'needs.enabled', type = 'bool', label = 'Besoins activés', help = 'Faim et soif baissent et abîment la santé ; coupé : rien ne change.' },
    { key = 'needs.interval', type = 'int', min = 1, max = 240, unit = 'min', label = 'Intervalle', help = 'Entre deux baisses.' },
    { key = 'needs.hungerRate', type = 'num', min = 0, max = 50, step = 0.5, label = 'Faim perdue par intervalle', help = 'Sur 100, animal sorti.' },
    { key = 'needs.thirstRate', type = 'num', min = 0, max = 50, step = 0.5, label = 'Soif perdue par intervalle', help = 'Sur 100, animal sorti.' },
    { key = 'needs.storedFactor', type = 'num', min = 0, max = 1, step = 0.05, label = 'Facteur quand l\'animal est rangé', help = '0 = rien ne baisse à la maison, 1 = comme dehors.' },
    { key = 'needs.lowThreshold', type = 'int', min = 0, max = 90, label = 'Seuil de fatigue', help = 'En dessous : plus lent, refuse les tours.' },
    { key = 'needs.damage', type = 'num', min = 0, max = 50, step = 0.5, label = 'Santé perdue à 0 de faim ou de soif', help = 'Par intervalle.' },
    { key = 'needs.recoveryHours', type = 'int', min = 0, max = 720, unit = 'h', label = 'Guérison seule après', help = '0 = un animal blessé attend des soins.' },
    { key = 'harness.enabled', type = 'bool', label = 'Harnais activés', help = 'Coupé : on ne peut plus en équiper (ceux portés restent visibles jusqu\'au rangement).' },
    { key = 'leash.enabled', type = 'bool', label = 'Laisses activées', help = 'Coupé : les laisses tenues se détachent.' },
    { key = 'leash.requireItem', type = 'bool', label = 'Laisse dans l\'inventaire obligatoire', help = 'Objet « Laisse ».' },
    { key = 'leash.requireHarness', type = 'bool', label = 'Harnais obligatoire pour la laisse', help = 'Sinon elle s\'accroche au collier.' },
    { key = 'leash.length', type = 'num', min = 1.2, max = 6.0, step = 0.1, unit = 'm', label = 'Longueur de la laisse', help = 'Distance de promenade.' },
    { key = 'leash.breakDistance', type = 'int', min = 6, max = 40, unit = 'm', label = 'Détachement au-delà de', help = 'Téléportation, chute, séparation.' },
    { key = 'vehicle.enabled', type = 'bool', label = 'Monter en véhicule', help = 'L\'animal qui suit monte avec son propriétaire (selon l\'espèce).' },
    { key = 'vehicle.boardDistance', type = 'int', min = 2, max = 25, unit = 'm', label = 'Distance pour monter', help = 'Entre l\'animal et le véhicule.' },
    { key = 'exotic.enabled', type = 'bool', label = 'Vente d\'exotiques', help = 'Coupé : les vendeurs n\'en proposent plus.' },
    { key = 'exotic.maxOwned', type = 'int', min = 0, max = 10, label = 'Exotiques possédés (max)', help = 'Par personnage.' },
    { key = 'exotic.requireItem', type = 'str', max = 40, label = 'Objet obligatoire (exotiques)', help = 'Nom d\'objet d\'inventaire (ex. un permis). Vide = aucun.' },
    { key = 'vet.price', type = 'int', min = 0, max = 100000, unit = '$', label = 'Prix des soins vétérinaires', help = 'Au comptoir d\'un vendeur avec « vétérinaire ».' },
}
A.AccessoryKinds = {
    { id = 'harness', label = 'Harnais', item = 'harness' }, { id = 'leash', label = 'Laisse', item = 'leash' },
    { id = 'food', label = 'Croquettes', item = 'food' }, { id = 'treat', label = 'Friandise', item = 'treat' },
    { id = 'medkit', label = 'Trousse vétérinaire', item = 'medkit' }, { id = 'feed', label = 'Aliment pour bétail', item = 'feed' },
}

local function getPath(t, key)
    local a, b = key:match('^(%w+)%.(%w+)$')
    return t[a] and t[a][b]
end
local function setPath(t, key, v)
    local a, b = key:match('^(%w+)%.(%w+)$')
    t[a] = t[a] or {}
    t[a][b] = v
end

function A.SanitizeSettings(d, base)
    d, base = type(d) == 'table' and d or {}, base or Config.Defaults
    local out = Ani.Copy(Config.Defaults)
    for _, f in ipairs(A.Schema) do
        local def = getPath(base, f.key)
        if def == nil then def = getPath(Config.Defaults, f.key) end
        local v = getPath(d, f.key)
        if f.type == 'bool' then v = Ani.Bool(v, def)
        elseif f.type == 'int' then v = Ani.Int(v, f.min, f.max, def)
        elseif f.type == 'num' then v = Ani.Clamp(v, f.min, f.max, def) v = math.floor(v * 100 + 0.5) / 100
        elseif f.type == 'str' then
            if v == '' then v = '' else v = (type(v) == 'string' and v:match('^[%w_%-]*$') and #v <= (f.max or 40)) and v or def end
        end
        setPath(out, f.key, v)
    end
    local acc = type(d.accessories) == 'table' and d.accessories or {}
    local accBase = type(base.accessories) == 'table' and base.accessories or Config.Defaults.accessories
    for _, k in ipairs(A.AccessoryKinds) do
        local a, b = type(acc[k.id]) == 'table' and acc[k.id] or {}, accBase[k.id] or Config.Defaults.accessories[k.id]
        out.accessories[k.id] = { enabled = Ani.Bool(a.enabled, b.enabled), price = Ani.Int(a.price, 0, 1000000, b.price) }
    end
    return out
end

-- ---------------------------------------------------------
--  Espèces : surcharges du menu
-- ---------------------------------------------------------
local function cleanVariant(v, sp)
    if type(v) ~= 'table' then return nil end
    local id = Ani.Id(v.id, 24)
    if not id then return nil end
    local model = v.model
    if model ~= nil and (type(model) ~= 'string' or not model:match('^[%w_]+$') or #model > 40) then return nil end
    return { id = id, label = Ani.Text(v.label, 40, 'Robe ' .. id), model = model, c = Ani.Int(v.c, 0, 11, 0), d = Ani.Int(v.d, 0, 50, 0),
        t = Ani.Int(v.t, 0, 50, 0), extra = Ani.Int(v.extra, 0, 1000000, 0), custom = true }
end

function A.SanitizeSpecies(d)
    d = type(d) == 'table' and d or {}
    local out = {}
    for sid, sp in pairs(Config.Species) do
        local o = type(d[sid]) == 'table' and d[sid] or {}
        local r = {
            enabled = Ani.Bool(o.enabled, true),
            price = o.price ~= nil and Ani.Int(o.price, 0, 10000000, sp.price) or nil,
            fees = o.fees ~= nil and Ani.Int(o.fees, 0, 10000000, sp.fees or 0) or nil,
            variants = {}, custom = {},
        }
        local known = {}
        for _, v in ipairs(sp.variants) do known[v.id] = true end
        for _, cv in ipairs(type(o.custom) == 'table' and o.custom or {}) do
            local c = cleanVariant(cv, sp)
            if c and not known[c.id] and #r.custom < 30 then known[c.id] = true r.custom[#r.custom + 1] = c end
        end
        for vid, vo in pairs(type(o.variants) == 'table' and o.variants or {}) do
            if type(vid) == 'string' and known[vid] and type(vo) == 'table' then
                r.variants[vid] = { enabled = Ani.Bool(vo.enabled, true), label = Ani.Text(vo.label, 40, nil),
                    extra = vo.extra ~= nil and Ani.Int(vo.extra, 0, 1000000, 0) or nil }
            end
        end
        out[sid] = r
    end
    return out
end

-- Espèce telle qu'elle s'applique (config + menu)
function A.SpeciesEff(sid)
    local sp = Config.Species[sid]
    if not sp then return nil end
    local o = A.Species[sid] or { variants = {}, custom = {} }
    local variants = {}
    local function add(v)
        local vo = o.variants[v.id] or {}
        variants[#variants + 1] = { id = v.id, label = vo.label or v.label, model = v.model or sp.model, c = v.c or 0, d = v.d or 0, t = v.t or 0,
            extra = vo.extra or v.extra or 0, enabled = vo.enabled ~= false, addon = v.addon == true, custom = v.custom == true }
    end
    for _, v in ipairs(sp.variants) do add(v) end
    for _, v in ipairs(o.custom or {}) do add(v) end
    return {
        id = sid, label = sp.label, cat = sp.cat, exotic = sp.exotic == true, farm = sp.farm == true, profile = sp.profile, model = sp.model,
        price = o.price or sp.price, fees = o.fees or sp.fees or 0, enabled = o.enabled ~= false, variants = variants,
    }
end

function A.Variant(sid, vid)
    local sp = A.SpeciesEff(sid)
    if not sp then return nil end
    for _, v in ipairs(sp.variants) do if v.id == vid then return v, sp end end
    return nil, sp
end

-- Pelage réellement disponible : d'après le dernier scan staff du modèle ;
-- sans scan, seuls les pelages du jeu de base (non « addon ») sont acceptés.
function A.VariantUsable(v)
    if not v then return false end
    local s = A.Scan[v.model]
    if s then
        if not s.exists then return false end
        local comp = s.comps and s.comps[tostring(v.c)]
        if not comp then return v.c == 0 and v.d == 0 and v.t == 0 end
        local n = comp.textures and tonumber(comp.textures[tostring(v.d)]) or 0
        return v.d < (tonumber(comp.drawables) or 0) and v.t < n
    end
    return not v.addon
end

-- ---------------------------------------------------------
--  Vendeurs
-- ---------------------------------------------------------
local function inList(list, v) for _, x in ipairs(list) do if x == v then return true end end return false end

function A.SanitizeVendor(v, old)
    if type(v) ~= 'table' then return nil end
    old = old or {}
    local id = Ani.Id(v.id or old.id, 40)
    if not id then return nil end
    local x, y, z, h = Ani.Num(v.x), Ani.Num(v.y), Ani.Num(v.z), Ani.Num(v.h)
    if not (x and y and z) or math.abs(x) > 12000 or math.abs(y) > 12000 or z < -200 or z > 2500 then return nil end
    local catalog, seen = {}, {}
    for _, sid in ipairs(type(v.catalog) == 'table' and v.catalog or {}) do
        if type(sid) == 'string' and Config.Species[sid] and not seen[sid] then seen[sid] = true catalog[#catalog + 1] = sid end
    end
    local prices = {}
    for sid, p in pairs(type(v.prices) == 'table' and v.prices or {}) do
        if type(sid) == 'string' and Config.Species[sid] and Ani.Num(p) then prices[sid] = Ani.Int(p, 0, 10000000, 0) end
    end
    local b = type(v.blip) == 'table' and v.blip or {}
    local ob = old.blip or {}
    return {
        id = id, label = Ani.Text(v.label, 50, old.label or 'Vendeur'), enabled = Ani.Bool(v.enabled, old.enabled ~= false),
        x = math.floor(x * 100 + 0.5) / 100, y = math.floor(y * 100 + 0.5) / 100, z = math.floor(z * 100 + 0.5) / 100,
        h = math.floor(((h or 0) % 360) * 10 + 0.5) / 10,
        model = (type(v.model) == 'string' and inList(Config.VendorModels, v.model)) and v.model or (old.model or Config.VendorModels[1]),
        scenario = (type(v.scenario) == 'string' and inList(Config.VendorScenarios, v.scenario)) and v.scenario or (old.scenario or Config.VendorScenarios[1]),
        catalog = catalog, prices = prices,
        accessories = Ani.Bool(v.accessories, old.accessories == true), vet = Ani.Bool(v.vet, old.vet == true),
        distance = Ani.Clamp(v.distance, 1.0, 10.0, old.distance or 2.5),
        blip = { enabled = Ani.Bool(b.enabled, ob.enabled ~= false), sprite = Ani.Int(b.sprite, 1, 900, ob.sprite or 463), color = Ani.Int(b.color, 0, 85, ob.color or 5) },
    }
end

function A.SanitizeVendors(list)
    local out, seen = {}, {}
    for _, v in ipairs(type(list) == 'table' and list or {}) do
        local c = A.SanitizeVendor(v)
        if c and not seen[c.id] and #out < 40 then seen[c.id] = true out[#out + 1] = c end
    end
    return out
end

function A.Vendor(id) for _, v in ipairs(A.Vendors) do if v.id == id then return v end end end

-- Prix : prix du vendeur (ou de l'espèce) + supplément du pelage + frais (exotiques)
function A.PriceOf(vendor, sid, vid)
    local v, sp = A.Variant(sid, vid)
    if not sp then return nil end
    local base = (vendor and vendor.prices and vendor.prices[sid]) or sp.price
    local extra = v and v.extra or 0
    return { base = base, extra = extra, fees = sp.fees or 0, total = base + extra + (sp.fees or 0) }
end

-- ---------------------------------------------------------
--  Ferme
-- ---------------------------------------------------------
function A.SanitizeEnclosure(e, old)
    if type(e) ~= 'table' then return nil end
    old = old or {}
    local id = Ani.Id(e.id or old.id, 40)
    local x, y, z = Ani.Num(e.x), Ani.Num(e.y), Ani.Num(e.z)
    if not id or not (x and y and z) or math.abs(x) > 12000 or math.abs(y) > 12000 then return nil end
    local animals, total = {}, 0
    for sid, n in pairs(type(e.animals) == 'table' and e.animals or {}) do
        n = Ani.Int(n, 0, 12, 0)
        if type(sid) == 'string' and Config.Species[sid] and n > 0 and total + n <= 20 then animals[sid] = n total = total + n end
    end
    return { id = id, label = Ani.Text(e.label, 50, old.label or 'Enclos'), x = math.floor(x * 100 + 0.5) / 100, y = math.floor(y * 100 + 0.5) / 100,
        z = math.floor(z * 100 + 0.5) / 100, radius = Ani.Clamp(e.radius, 3.0, 60.0, old.radius or 10.0), animals = animals,
        enabled = Ani.Bool(e.enabled, old.enabled ~= false) }
end

function A.SanitizeFarm(d, base)
    d, base = type(d) == 'table' and d or {}, base or Config.Farm
    local p, bp = type(d.produce) == 'table' and d.produce or {}, base.produce or Config.Farm.produce
    local out = {
        enabled = Ani.Bool(d.enabled, base.enabled),
        activation = Ani.Int(d.activation, 40, 500, base.activation),
        hungerRate = Ani.Clamp(d.hungerRate, 0, 50, base.hungerRate),
        feedValue = Ani.Int(d.feedValue, 1, 100, base.feedValue),
        careValue = Ani.Int(d.careValue, 1, 100, base.careValue),
        produce = { enabled = Ani.Bool(p.enabled, bp.enabled), cooldown = Ani.Int(p.cooldown, 1, 1440, bp.cooldown),
            minHunger = Ani.Int(p.minHunger, 0, 100, bp.minHunger), minHealth = Ani.Int(p.minHealth, 0, 100, bp.minHealth) },
        enclosures = {},
    }
    local seen = {}
    local src = type(d.enclosures) == 'table' and d.enclosures or base.enclosures or {}
    for _, e in ipairs(src) do
        local c = A.SanitizeEnclosure(e)
        if c and not seen[c.id] and #out.enclosures < 30 then seen[c.id] = true out.enclosures[#out.enclosures + 1] = c end
    end
    return out
end

-- ---------------------------------------------------------
--  Scan des modèles (fait par un staff en jeu : /animaux_scan ou le menu)
-- ---------------------------------------------------------
function A.SanitizeScan(d)
    local out = {}
    for model, s in pairs(type(d) == 'table' and d or {}) do
        if type(model) == 'string' and model:match('^[%w_]+$') and type(s) == 'table' then
            local comps = {}
            for c, cv in pairs(type(s.comps) == 'table' and s.comps or {}) do
                local ci = Ani.Int(c, 0, 11, nil)
                if ci and type(cv) == 'table' then
                    local tex = {}
                    for dI, n in pairs(type(cv.textures) == 'table' and cv.textures or {}) do
                        local di = Ani.Int(dI, 0, 50, nil)
                        if di then tex[tostring(di)] = Ani.Int(n, 0, 64, 0) end
                    end
                    comps[tostring(ci)] = { drawables = Ani.Int(cv.drawables, 0, 64, 0), textures = tex }
                end
            end
            out[model] = { exists = s.exists == true, comps = comps, by = Ani.Text(s.by, 60, '?'), at = Ani.Int(s.at, 0, 2 ^ 31, 0) }
        end
    end
    return out
end

-- ---------------------------------------------------------
--  Base de données
-- ---------------------------------------------------------
function A.SaveSection(name, value)
    local ok, err = pcall(function()
        MySQL.query.await('INSERT INTO `elyzea_animaux_config` (`k`, `v`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `v` = VALUES(`v`)', { name, json.encode(value) })
    end)
    if not ok then
        A.Diag.saveErrors[#A.Diag.saveErrors + 1] = { at = os.time(), what = name, err = tostring(err) }
        while #A.Diag.saveErrors > 20 do table.remove(A.Diag.saveErrors, 1) end
        print(('^1[ANIMAUX] Sauvegarde « %s » impossible : %s^7'):format(name, tostring(err)))
    end
    return ok
end

function A.DeleteSection(name)
    pcall(function() MySQL.query.await('DELETE FROM `elyzea_animaux_config` WHERE `k` = ?', { name }) end)
end

A.Tables = {
[[CREATE TABLE IF NOT EXISTS `elyzea_animaux` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `chip` VARCHAR(16) NOT NULL,
    `citizenid` VARCHAR(64) NOT NULL,
    `species` VARCHAR(40) NOT NULL,
    `variant` VARCHAR(24) NOT NULL,
    `name` VARCHAR(40) NOT NULL,
    `status` VARCHAR(12) NOT NULL DEFAULT 'stored',
    `hunger` FLOAT NOT NULL DEFAULT 100,
    `thirst` FLOAT NOT NULL DEFAULT 100,
    `health` FLOAT NOT NULL DEFAULT 100,
    `gear` TEXT NULL,
    `price` INT NOT NULL DEFAULT 0,
    `vendor` VARCHAR(40) NULL,
    `injured_at` INT NULL,
    `acquired_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `chip` (`chip`),
    KEY `citizenid` (`citizenid`)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
[[CREATE TABLE IF NOT EXISTS `elyzea_animaux_config` (
    `k` VARCHAR(40) NOT NULL PRIMARY KEY,
    `v` LONGTEXT NOT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
[[CREATE TABLE IF NOT EXISTS `elyzea_animaux_farm` (
    `enclosure` VARCHAR(40) NOT NULL,
    `slot` INT NOT NULL,
    `species` VARCHAR(40) NOT NULL,
    `variant` VARCHAR(24) NOT NULL,
    `hunger` FLOAT NOT NULL DEFAULT 100,
    `health` FLOAT NOT NULL DEFAULT 100,
    `last_produce` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`enclosure`, `slot`)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
}

function A.Load()
    for _, sql in ipairs(A.Tables) do MySQL.query.await(sql) end
    local rows = MySQL.query.await('SELECT `k`, `v` FROM `elyzea_animaux_config`') or {}
    local saved = {}
    for _, r in ipairs(rows) do
        local ok, v = pcall(json.decode, r.v)
        if ok and type(v) == 'table' then saved[r.k] = v
        else A.Diag.loadErrors[#A.Diag.loadErrors + 1] = ('Section « %s » illisible : valeurs par défaut utilisées.'):format(tostring(r.k)) end
    end
    A.S = A.SanitizeSettings(saved.settings or {}, Config.Defaults)
    A.Species = A.SanitizeSpecies(saved.species or {})
    A.Vendors = saved.vendors and A.SanitizeVendors(saved.vendors) or A.SanitizeVendors(Config.Vendors)
    A.Farm = A.SanitizeFarm(saved.farm or {}, Config.Farm)
    A.Scan = A.SanitizeScan(saved.scan or {})
end
