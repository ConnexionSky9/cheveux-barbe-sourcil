-- =====================================================================
--  ELYZEA DYNASTY 8 - serveur : améliorations des logements
--  · « Améliorer mon logement » : caméras de surveillance, danseuse privée, culture de cannabis.
--  · Achat lié au contrat en cours (comme la décoration) ; tout est gardé en base :
--      d8_upgrades (améliorations achetées), d8_cameras (caméras posées),
--      d8_cam_spots (emplacements imposés par le staff), d8_plants (pots et plantes).
--  · Chaque action est revérifiée ici : droits du joueur sur le bien (titulaire ou locataire
--    avec le bon droit), amélioration achetée, limites (caméras, danseuses, 3 pots), distances.
--  · Danseuse : état gardé par le serveur ; chaque joueur présent dans le logement affiche un
--    PNJ local (jamais deux fois le même), retiré automatiquement à la fin de la durée.
--  · Téléphone (elyzea_aura, appli MAISON) : exports.elyzea_dynasty:PhoneCall(src, action, data).
--  · Administration (admin_menu) : exports.elyzea_dynasty:AdminSummary / AdminAction.
-- =====================================================================
local P = Dynasty
local KINDS = { 'cameras', 'dancer', 'cannabis' }
local KLABEL = { cameras = 'Caméras de surveillance', dancer = 'Danseuse privée', cannabis = 'Culture de cannabis' }

-- ---------------------------------------------------------------------
-- Tables et colonnes (créées au démarrage, jamais supprimées)
-- ---------------------------------------------------------------------
P.Tables.d8_upgrades = [[ (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `property_id` INT NOT NULL,
    `contract_id` INT NOT NULL,
    `kind` VARCHAR(16) NOT NULL,
    `price` INT NOT NULL DEFAULT 0,
    `data` LONGTEXT NULL,
    `bought_by` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `prop_contract_kind` (`property_id`, `contract_id`, `kind`) ) ]]
P.Tables.d8_cameras = [[ (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `property_id` INT NOT NULL,
    `contract_id` INT NOT NULL,
    `label` VARCHAR(40) NOT NULL,
    `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL,
    `rx` DOUBLE NOT NULL DEFAULT 0, `rz` DOUBLE NOT NULL DEFAULT 0, `fov` DOUBLE NOT NULL DEFAULT 60,
    `spot_id` INT NULL,
    `placed_by` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`property_id`) ) ]]
P.Tables.d8_cam_spots = [[ (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `property_id` INT NOT NULL,
    `label` VARCHAR(40) NOT NULL,
    `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL,
    `rx` DOUBLE NOT NULL DEFAULT -10, `rz` DOUBLE NOT NULL DEFAULT 0, `fov` DOUBLE NOT NULL DEFAULT 60,
    `yaw_range` DOUBLE NOT NULL DEFAULT 45, `pitch_range` DOUBLE NOT NULL DEFAULT 20,
    `created_by` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`property_id`) ) ]]
P.Tables.d8_plants = [[ (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `property_id` INT NOT NULL,
    `contract_id` INT NOT NULL,
    `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `h` DOUBLE NOT NULL DEFAULT 0,
    `seed` VARCHAR(60) NULL,
    `progress` DOUBLE NOT NULL DEFAULT 0,
    `water` DOUBLE NOT NULL DEFAULT 0,
    `health` DOUBLE NOT NULL DEFAULT 100,
    `fertilized` TINYINT(1) NOT NULL DEFAULT 0,
    `planted_by` VARCHAR(100) NULL,
    `planted_at` INT NULL,
    `updated_at` INT NOT NULL,
    INDEX (`property_id`) ) ]]
for _, t in ipairs({ 'd8_upgrades', 'd8_cameras', 'd8_cam_spots', 'd8_plants' }) do P.TableOrder[#P.TableOrder + 1] = t end

local function HasColumn(tbl, col)
    return (tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?]], { tbl, col })) or 0) > 0
end
P.Migrations = P.Migrations or {}
P.Migrations[#P.Migrations + 1] = function()
    -- Nouveaux droits des locataires ajoutés (améliorations, caméras, danseuse, code)
    for _, col in ipairs({ 'can_upgrades', 'can_cameras', 'can_dancer', 'can_code' }) do
        if not HasColumn('d8_access', col) then
            MySQL.query.await(('ALTER TABLE `d8_access` ADD COLUMN `%s` TINYINT(1) NOT NULL DEFAULT 0'):format(col))
        end
    end
end

-- ---------------------------------------------------------------------
-- Réglages : valeurs de config.lua, remplacées par celles du staff (d8_settings « upgrades »)
-- ---------------------------------------------------------------------
local EDIT = {
    cameras = { enabled = 'bool', price = 'int', payTo = 'pay', max = 'int', radius = 'num', fovMin = 'int', fovMax = 'int' },
    dancer = { enabled = 'bool', price = 'int', payTo = 'pay', max = 'int', maxMinutes = 'int', cooldownSeconds = 'int', animsOn = 'map' },
    cannabis = { enabled = 'bool', price = 'int', payTo = 'pay', maxPots = 'int', speed = 'num' },
}
local LIMITS = {
    price = { 0, Config.Prices.max }, max = { 0, 12 }, radius = { 5, 80 }, fovMin = { 10, 80 }, fovMax = { 30, 120 },
    maxMinutes = { 1, 240 }, cooldownSeconds = { 0, 600 }, maxPots = { 0, 12 }, speed = { 0.1, 20 },
}
local function Copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = Copy(v) end
    return o
end
local cfgCache = nil
function P.UpCfg()
    if cfgCache then return cfgCache end
    local c = Copy(Config.Upgrades)
    local saved = P.GetSetting('upgrades', {})
    for kind, over in pairs(type(saved) == 'table' and saved or {}) do
        if c[kind] and EDIT[kind] and type(over) == 'table' then
            for k, v in pairs(over) do if EDIT[kind][k] then c[kind][k] = v end end
        end
    end
    -- Animations : activées / désactivées par le staff
    local on = c.dancer.animsOn or {}
    for _, a in ipairs(c.dancer.anims) do if on[a.id] ~= nil then a.on = on[a.id] == true end end
    if c.cameras.fovMin > c.cameras.fovMax then c.cameras.fovMin, c.cameras.fovMax = c.cameras.fovMax, c.cameras.fovMin end
    cfgCache = c
    return c
end

-- ---------------------------------------------------------------------
-- Outils
-- ---------------------------------------------------------------------
local function dec(raw) local ok, v = pcall(json.decode, raw or '') return ok and type(v) == 'table' and v or nil end
local function r2(v) return math.floor((tonumber(v) or 0) * 100 + 0.5) / 100 end
local function V3(t) return vector3((tonumber(t.x) or 0) + 0.0, (tonumber(t.y) or 0) + 0.0, (tonumber(t.z) or 0) + 0.0) end
local function Clamp(v, a, b) v = tonumber(v) or a return math.max(a, math.min(b, v)) end
local function AngleDiff(a, b) local d = ((a - b + 180) % 360) - 180 return math.abs(d) end
local inv = function() return exports.elyzea_inventory end
local function Count(src, item) local ok, n = pcall(function() return inv():GetItemCount(src, item) end) return ok and tonumber(n) or 0 end
local function Remove(src, item, n) local ok, r = pcall(function() return inv():RemoveItem(src, item, n) end) return ok and r == true end
local function Add(src, item, n) local ok, r = pcall(function() return inv():AddItem(src, item, n) end) return ok and r == true end
local function CanCarry(src, item, n)
    local ok, r = pcall(function() return inv():CanCarryItems(src, { { name = item, count = n } }) end)
    if not ok then return true end   -- ancienne version de l'inventaire : AddItem refusera si besoin
    return r ~= false
end

local busy = {}
local function Lock(key) if busy[key] then return false end busy[key] = true return true end
local function Unlock(key) busy[key] = nil end

-- Bien + droits du joueur (titulaire, ou locataire avec le droit demandé)
local function Resident(src, pid, need)
    local pr = P.props[tonumber(pid) or 0]
    if not pr or not pr.enabled then return nil, 'Logement introuvable.' end
    local role, rights = P.RoleOf(src, pr.id)
    if not role then return nil, 'Vous n\'avez aucun droit sur ce logement.' end
    if need and not rights[need] then return nil, 'Le titulaire ne vous a pas donné ce droit.' end
    local c = P.Contract(pr.id)
    if not c then return nil, 'Aucun contrat actif.' end
    return pr, rights, c, role
end
local function InsideHome(src, pid) local i = P.inside[src] return i ~= nil and i.pid == pid and i.area == 'home' end
local function InsideList(pid)
    local l = {}
    for s, i in pairs(P.inside) do if i.pid == pid and i.area == 'home' then l[#l + 1] = s end end
    return l
end

-- ---------------------------------------------------------------------
-- Améliorations achetées (cache par bien, recalculé à chaque changement de contrat)
-- ---------------------------------------------------------------------
local ups = {}      -- [pid] = { cid = contrat, list = { [kind] = { id, price, data, by, at } } }
local function Ups(pid)
    local c = P.Contract(pid)
    if not c then ups[pid] = nil return {} end
    local u = ups[pid]
    if u and u.cid == c.id then return u.list end
    local list = {}
    for _, r in ipairs(MySQL.query.await('SELECT `id`, `kind`, `price`, `data`, `bought_by`, UNIX_TIMESTAMP(`created_at`) AS t FROM `d8_upgrades` WHERE `property_id` = ? AND `contract_id` = ?', { pid, c.id }) or {}) do
        list[r.kind] = { id = r.id, price = tonumber(r.price) or 0, data = dec(r.data) or {}, by = r.bought_by, at = tonumber(r.t) }
    end
    ups[pid] = { cid = c.id, list = list }
    return list
end
P.Ups = Ups
function P.HasUpgrade(pid, kind) return Ups(pid)[kind] ~= nil end
local function SaveUpData(pid, kind)
    local u = Ups(pid)[kind]
    if u then MySQL.update.await('UPDATE `d8_upgrades` SET `data` = ? WHERE `id` = ?', { json.encode(u.data or {}), u.id }) end
end

local function CamRows(pid, cid)
    return MySQL.query.await('SELECT `id`, `label`, `x`, `y`, `z`, `rx`, `rz`, `fov`, `spot_id` FROM `d8_cameras` WHERE `property_id` = ? AND `contract_id` = ? ORDER BY `id`', { pid, cid }) or {}
end
local function SpotRows(pid)
    return MySQL.query.await('SELECT `id`, `label`, `x`, `y`, `z`, `rx`, `rz`, `fov`, `yaw_range`, `pitch_range` FROM `d8_cam_spots` WHERE `property_id` = ? ORDER BY `id`', { pid }) or {}
end
local function PlantRows(pid, cid)
    return MySQL.query.await('SELECT * FROM `d8_plants` WHERE `property_id` = ? AND `contract_id` = ? ORDER BY `id`', { pid, cid }) or {}
end

-- ---------------------------------------------------------------------
-- Cannabis : croissance calculée à partir des dates (continue hors ligne et après un redémarrage)
-- ---------------------------------------------------------------------
local function Variety(seed)
    for _, v in ipairs(Config.Upgrades.cannabis.varieties) do if v.seed == seed then return v end end
end
local function Grow(p, now)
    local C = P.UpCfg().cannabis
    now = now or os.time()
    local dt = math.max(0, (now - (tonumber(p.updated_at) or now)) / 3600)
    local water, health, progress = tonumber(p.water) or 0, tonumber(p.health) or 100, tonumber(p.progress) or 0
    local decay = math.max(0.01, C.water.decayPerHour)
    local v = p.seed and Variety(p.seed)
    if v and health > 0 and progress < 100 then
        local wet = math.min(dt, water / decay)
        local rate = 100 / math.max(1, v.minutes / 60) * (C.speed or 1) * ((tonumber(p.fertilized) == 1 or p.fertilized == true) and C.fertilizer.boost or 1)
        progress = math.min(100, progress + wet * rate)
        health = math.max(0, health - (dt - wet) * C.healthLossPerHourDry)
    end
    water = math.max(0, water - decay * dt)
    p.water, p.health, p.progress, p.updated_at = water, health, progress, now
    return p
end
local function StageOf(progress)
    local st = Config.Upgrades.cannabis.stages[1]
    for _, s in ipairs(Config.Upgrades.cannabis.stages) do if progress >= s.pct then st = s end end
    return st
end
local function PlantView(p)
    local v = p.seed and Variety(p.seed)
    local st = StageOf(p.progress or 0)
    return { id = p.id, x = p.x, y = p.y, z = p.z, h = p.h, seed = p.seed, variety = v and v.label or nil,
        progress = math.floor((p.progress or 0) * 10) / 10, water = math.floor(p.water or 0), health = math.floor(p.health or 0),
        fertilized = tonumber(p.fertilized) == 1 or p.fertilized == true, dead = p.seed ~= nil and (p.health or 0) <= 0,
        stage = p.seed and st.label or 'Pot vide', model = p.seed and st.model or nil, ready = p.seed ~= nil and (p.progress or 0) >= 100 and (p.health or 0) > 0 }
end
local function SavePlant(p)
    MySQL.update.await('UPDATE `d8_plants` SET `seed` = ?, `progress` = ?, `water` = ?, `health` = ?, `fertilized` = ?, `planted_by` = ?, `planted_at` = ?, `updated_at` = ? WHERE `id` = ?',
        { p.seed, r2(p.progress), r2(p.water), r2(p.health), (tonumber(p.fertilized) == 1 or p.fertilized == true) and 1 or 0, p.planted_by, p.planted_at, p.updated_at, p.id })
end
local function PlantsRefresh(pid) for _, s in ipairs(InsideList(pid)) do TriggerClientEvent('d8:client:plantsRefresh', s, pid) end end

-- ---------------------------------------------------------------------
-- Danseuse (état serveur ; PNJ local chez chaque joueur présent)
-- ---------------------------------------------------------------------
P.dancers = {}      -- [pid] = { list = { { n, model, anim, x, y, z, h, ends } }, by, last }
local function AnimOf(id)
    for _, a in ipairs(P.UpCfg().dancer.anims) do if a.id == id and a.on then return a end end
end
local function DancerView(pid)
    local d = P.dancers[pid]
    if not d or #d.list == 0 then return nil end
    local out = {}
    for _, x in ipairs(d.list) do
        local a = AnimOf(x.anim) or {}
        out[#out + 1] = { n = x.n, model = x.model, anim = x.anim, dict = a.dict, clip = a.clip, label = a.label, x = x.x, y = x.y, z = x.z, h = x.h, left = math.max(0, x.ends - os.time()) }
    end
    return out
end
local function DancerBroadcast(pid)
    local v = DancerView(pid)
    for _, s in ipairs(InsideList(pid)) do TriggerClientEvent('d8:client:dancer', s, pid, v) end
end
local function DancerStopAll(pid, reason)
    if not P.dancers[pid] then return end
    P.dancers[pid] = nil
    DancerBroadcast(pid)
    if reason then P.PropLog(pid, 'Danseuse partie', reason, 'Système') end
end

-- ---------------------------------------------------------------------
-- Vue des améliorations d'un logement (zone de gestion, téléphone)
-- ---------------------------------------------------------------------
function P.UpgradesView(src, pid)
    local pr = P.props[pid]
    local c = P.Contract(pid)
    if not pr or not c then return nil end
    local cfg = P.UpCfg()
    local _, rights = P.RoleOf(src, pid)
    rights = rights or {}
    local u = Ups(pid)
    local out = { list = {}, rights = rights }
    for _, k in ipairs(KINDS) do
        local kc = cfg[k]
        out.list[#out.list + 1] = { kind = k, label = KLABEL[k], enabled = kc.enabled, price = kc.price, owned = u[k] ~= nil, at = u[k] and u[k].at or nil, by = u[k] and u[k].by or nil }
    end
    if u.cameras then
        local cams = CamRows(pid, c.id)
        out.cameras = { list = cams, max = cfg.cameras.max, spots = #SpotRows(pid) }
    end
    if u.dancer then
        local anims = {}
        for _, a in ipairs(cfg.dancer.anims) do if a.on then anims[#anims + 1] = { id = a.id, label = a.label } end end
        out.dancer = { active = DancerView(pid), spot = u.dancer.data and u.dancer.data.spot ~= nil, anims = anims, models = cfg.dancer.models,
            durations = cfg.dancer.durations, maxMinutes = cfg.dancer.maxMinutes, max = cfg.dancer.max }
    end
    if u.cannabis then
        local plants = {}
        for _, p in ipairs(PlantRows(pid, c.id)) do plants[#plants + 1] = PlantView(Grow(p)) end
        out.cannabis = { plants = plants, max = cfg.cannabis.maxPots }
    end
    return out
end

-- ---------------------------------------------------------------------
-- Achat d'une amélioration
-- ---------------------------------------------------------------------
function P.BuyUpgrade(src, pid, kind, method)
    local pr, err, c = Resident(src, pid, 'upgrades')
    if not pr then return { error = err } end
    local kc = P.UpCfg()[kind or '']
    if not kc then return { error = 'Amélioration inconnue.' } end
    if not kc.enabled then return { error = 'Cette amélioration est désactivée par l\'administration.' } end
    if pr.category == 'garage' then return { error = 'Un garage ne peut pas recevoir d\'amélioration.' } end
    if Ups(pr.id)[kind] then return { error = 'Cette amélioration est déjà installée.' } end
    method = method == 'cash' and 'cash' or 'bank'
    local key = 'buy:' .. pr.id
    if not Lock(key) then return { error = 'Achat déjà en cours.' } end
    local ok, res = pcall(function()
        local price = math.max(0, math.floor(tonumber(kc.price) or 0))
        local reason = ('Amélioration %s · %s'):format(KLABEL[kind], pr.name)
        local paid = P.ChargeWith(src, price, method, reason)
        if not paid then return { error = method == 'cash' and 'Espèces insuffisantes.' or 'Solde bancaire insuffisant.' } end
        if price > 0 and kc.payTo == 'agency' then
            if not P.SocietyAdd(price, reason, pr.job) then
                P.Refund(P.Cid(src), price, method, 'Remboursement ' .. reason)
                return { error = 'Erreur de paiement : vous avez été remboursé.' }
            end
            P.Tx({ job = pr.job, type = 'in', category = 'other', amount = price, reason = reason, actorCid = P.Cid(src), actorName = P.Name(src),
                targetCid = P.Cid(src), targetName = P.Name(src), ref = ('#%d'):format(pr.id) })
        end
        local id = MySQL.insert.await('INSERT IGNORE INTO `d8_upgrades` (`property_id`, `contract_id`, `kind`, `price`, `data`, `bought_by`) VALUES (?, ?, ?, ?, ?, ?)',
            { pr.id, c.id, kind, price, '{}', P.Name(src) })
        if not id or id == 0 then
            if price > 0 then P.Refund(P.Cid(src), price, method, 'Remboursement ' .. reason) end
            return { error = 'Cette amélioration est déjà installée (remboursé).' }
        end
        ups[pr.id] = nil
        P.PropLog(pr.id, 'Amélioration achetée', ('%s · %d $'):format(KLABEL[kind], price), src)
        P.Log(src, 'Amélioration achetée', ('#%d %s · %s · %d $'):format(pr.id, pr.name, KLABEL[kind], price))
        local tips = { cameras = 'Installez vos caméras depuis l\'appli MAISON, près du logement.',
            dancer = 'Choisissez son emplacement dans le logement (Gérer mon logement › Améliorations).',
            cannabis = ('Posez jusqu\'à %d pots dans le logement (Gérer mon logement › Améliorations).'):format(P.UpCfg().cannabis.maxPots) }
        return { ok = true, message = ('%s installée. %s'):format(KLABEL[kind], tips[kind] or '') }
    end)
    Unlock(key)
    if not ok then print(('^1[D8] Achat amélioration : %s^0'):format(tostring(res))) return { error = 'Erreur pendant l\'achat.' } end
    return res
end

-- ---------------------------------------------------------------------
-- Caméras
-- ---------------------------------------------------------------------
local function CamCheck(src, pid)
    local pr, err, c = Resident(src, pid, 'cameras')
    if not pr then return nil, err end
    if not P.UpCfg().cameras.enabled then return nil, 'Les caméras sont désactivées par l\'administration.' end
    if not Ups(pr.id).cameras then return nil, 'Achetez d\'abord l\'amélioration « Caméras de surveillance ».' end
    return pr, c
end

-- Données pour placer une caméra (le joueur doit être près du logement)
function P.CamPlaceInfo(src, pid)
    local pr, c = CamCheck(src, pid)
    if not pr then return { error = c } end
    local cfg = P.UpCfg().cameras
    local e = pr.points.enter or (pr.garage and pr.garage.points and pr.garage.points.enter)
    if not e then return { error = 'Ce logement n\'a pas d\'entrée placée.' } end
    if P.inside[src] then return { error = 'Sortez du logement : les caméras se posent autour, à l\'extérieur.' } end
    local pc = P.Coords(src)
    if not pc or #(pc - V3(e)) > cfg.radius + 10.0 then return { error = ('Approchez-vous du logement (moins de %d m de l\'entrée).'):format(math.floor(cfg.radius)) } end
    local cams = CamRows(pr.id, c.id)
    if #cams >= cfg.max then return { error = ('%d caméra(s) maximum : retirez-en une pour en poser une autre.'):format(cfg.max) } end
    local used = {}
    for _, x in ipairs(cams) do if x.spot_id then used[tonumber(x.spot_id)] = true end end
    local spots = {}
    for _, s in ipairs(SpotRows(pr.id)) do if not used[tonumber(s.id)] then spots[#spots + 1] = s end end
    local all = #SpotRows(pr.id)
    if all > 0 and #spots == 0 then return { error = 'Tous les emplacements prévus pour les caméras sont déjà équipés.' } end
    return { ok = true, pid = pr.id, name = pr.name, enter = { x = e.x, y = e.y, z = e.z }, radius = cfg.radius, spots = all > 0 and spots or nil,
        fovMin = cfg.fovMin, fovMax = cfg.fovMax, fov = cfg.fovDefault, pitchMin = cfg.pitchMin, pitchMax = cfg.pitchMax, count = #cams, max = cfg.max }
end

function P.CamPlace(src, d)
    local pr, c = CamCheck(src, d.pid)
    if not pr then return { error = c } end
    if P.inside[src] then return { error = 'Sortez du logement pour poser une caméra.' } end
    local cfg = P.UpCfg().cameras
    local key = 'cam:' .. pr.id
    if not Lock(key) then return { error = 'Pose déjà en cours.' } end
    local ok, res = pcall(function()
        local cams = CamRows(pr.id, c.id)
        if #cams >= cfg.max then return { error = ('%d caméra(s) maximum.'):format(cfg.max) } end
        local e = pr.points.enter or (pr.garage and pr.garage.points and pr.garage.points.enter)
        if not e then return { error = 'Ce logement n\'a pas d\'entrée placée.' } end
        local pos = { x = tonumber(d.x), y = tonumber(d.y), z = tonumber(d.z) }
        if not pos.x or not pos.y or not pos.z then return { error = 'Position invalide.' } end
        local rz, rx = (tonumber(d.rz) or 0) % 360, Clamp(d.rx, cfg.pitchMin, cfg.pitchMax)
        local fov = Clamp(d.fov, cfg.fovMin, cfg.fovMax)
        local spotId = nil
        local spots = SpotRows(pr.id)
        if #spots > 0 then
            -- Emplacements imposés par le staff : position du point, orientation dans la plage permise
            local s
            for _, x in ipairs(spots) do if tonumber(x.id) == tonumber(d.spot) then s = x end end
            if not s then return { error = 'Choisissez un des emplacements prévus.' } end
            for _, x in ipairs(cams) do if tonumber(x.spot_id) == tonumber(s.id) then return { error = 'Cet emplacement a déjà une caméra.' } end end
            if AngleDiff(rz, tonumber(s.rz) or 0) > (tonumber(s.yaw_range) or 45) + 0.5 then return { error = 'Orientation hors de la plage permise pour cet emplacement.' } end
            if math.abs(rx - (tonumber(s.rx) or 0)) > (tonumber(s.pitch_range) or 20) + 0.5 then return { error = 'Inclinaison hors de la plage permise pour cet emplacement.' } end
            pos = { x = tonumber(s.x), y = tonumber(s.y), z = tonumber(s.z) }
            spotId = tonumber(s.id)
        else
            if #(V3(pos) - V3(e)) > cfg.radius + 0.5 then return { error = ('La caméra doit rester à moins de %d m de l\'entrée.'):format(math.floor(cfg.radius)) } end
            local pc = P.Coords(src)
            if not pc or #(pc - V3(pos)) > 15.0 then return { error = 'Restez près de la caméra que vous posez.' } end
        end
        local label = P.Clean(d.label, 40)
        if #label < 1 then label = ('Caméra %d'):format(#cams + 1) end
        MySQL.insert.await('INSERT INTO `d8_cameras` (`property_id`, `contract_id`, `label`, `x`, `y`, `z`, `rx`, `rz`, `fov`, `spot_id`, `placed_by`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { pr.id, c.id, label, r2(pos.x), r2(pos.y), r2(pos.z), r2(rx), r2(rz), r2(fov), spotId, P.Name(src) })
        P.PropLog(pr.id, 'Caméra posée', label, src)
        return { ok = true, message = ('« %s » installée (%d / %d).'):format(label, #cams + 1, cfg.max) }
    end)
    Unlock(key)
    if not ok then print(('^1[D8] Caméra : %s^0'):format(tostring(res))) return { error = 'Erreur pendant la pose.' } end
    return res
end

function P.CamRemove(src, pid, id)
    local pr, c = CamCheck(src, pid)
    if not pr then return { error = c } end
    local n = MySQL.update.await('DELETE FROM `d8_cameras` WHERE `id` = ? AND `property_id` = ? AND `contract_id` = ?', { tonumber(id) or 0, pr.id, c.id })
    if (tonumber(n) or 0) == 0 then return { error = 'Caméra introuvable.' } end
    P.PropLog(pr.id, 'Caméra retirée', ('#%s'):format(tostring(id)), src)
    return { ok = true, message = 'Caméra retirée.' }
end

function P.CamRename(src, pid, id, label)
    local pr, c = CamCheck(src, pid)
    if not pr then return { error = c } end
    label = P.Clean(label, 40)
    if #label < 1 then return { error = 'Nom vide.' } end
    MySQL.update.await('UPDATE `d8_cameras` SET `label` = ? WHERE `id` = ? AND `property_id` = ? AND `contract_id` = ?', { label, tonumber(id) or 0, pr.id, c.id })
    return { ok = true, message = 'Caméra renommée.' }
end

-- Images en direct : positions des caméras (le client crée la vue ; le serveur contrôle les droits)
function P.CamView(src, pid)
    local pr, c = CamCheck(src, pid)
    if not pr then return { error = c } end
    local cams = CamRows(pr.id, c.id)
    if #cams == 0 then return { error = 'Aucune caméra installée.' } end
    return { ok = true, pid = pr.id, name = pr.name, cams = cams, modifier = P.UpCfg().cameras.modifier }
end

-- ---------------------------------------------------------------------
-- Danseuse privée
-- ---------------------------------------------------------------------
local function DancerCheck(src, pid)
    local pr, err, c = Resident(src, pid, 'dancer')
    if not pr then return nil, err end
    if not P.UpCfg().dancer.enabled then return nil, 'La danseuse privée est désactivée par l\'administration.' end
    if not Ups(pr.id).dancer then return nil, 'Achetez d\'abord l\'amélioration « Danseuse privée ».' end
    return pr, c
end

function P.DancerSpot(src, pid)
    local pr, c = DancerCheck(src, pid)
    if not pr then return { error = c } end
    if not InsideHome(src, pr.id) then return { error = 'Entrez dans le logement pour choisir l\'emplacement.' } end
    local ped = GetPlayerPed(src)
    local pc = GetEntityCoords(ped)
    local exit = pr.points.exit
    if exit and #(pc - V3(exit)) > Config.Deco.maxDistance then return { error = 'Trop loin de l\'entrée du logement.' } end
    local u = Ups(pr.id).dancer
    u.data = u.data or {}
    u.data.spot = { x = r2(pc.x), y = r2(pc.y), z = r2(pc.z - 1.0), h = r2(GetEntityHeading(ped)) }
    SaveUpData(pr.id, 'dancer')
    local d = P.dancers[pr.id]
    if d then
        for i, x in ipairs(d.list) do
            local off = (i - 1) * 1.2
            local rad = math.rad(u.data.spot.h + 90.0)
            x.x, x.y, x.z, x.h = u.data.spot.x + math.cos(rad) * off, u.data.spot.y + math.sin(rad) * off, u.data.spot.z, u.data.spot.h
        end
        DancerBroadcast(pr.id)
    end
    P.PropLog(pr.id, 'Emplacement de la danseuse', nil, src)
    return { ok = true, message = 'Emplacement de la danseuse enregistré (elle regardera dans la même direction que vous).' }
end

function P.DancerStart(src, pid, d)
    local pr, c = DancerCheck(src, pid)
    if not pr then return { error = c } end
    local cfg = P.UpCfg().dancer
    local u = Ups(pr.id).dancer
    local spot = u.data and u.data.spot
    if not spot then return { error = 'Choisissez d\'abord l\'emplacement de la danseuse dans le logement.' } end
    local anim = AnimOf(tostring(d.anim or ''))
    if not anim then return { error = 'Animation indisponible.' } end
    local model = tostring(d.model or cfg.models[1] or '')
    local okModel = false
    for _, m in ipairs(cfg.models) do if m == model then okModel = true end end
    if not okModel then return { error = 'Modèle indisponible.' } end
    local minutes = P.Int(d.minutes, 1, cfg.maxMinutes, math.min(10, cfg.maxMinutes))
    local st = P.dancers[pr.id] or { list = {}, last = 0 }
    if #st.list >= math.max(1, cfg.max) then return { error = ('%d danseuse(s) maximum en même temps.'):format(math.max(1, cfg.max)) } end
    if os.time() - (st.last or 0) < cfg.cooldownSeconds then return { error = 'Patientez quelques secondes.' } end
    local n = #st.list + 1
    local off = (n - 1) * 1.2
    local rad = math.rad(spot.h + 90.0)
    st.list[n] = { n = n, model = model, anim = anim.id, x = spot.x + math.cos(rad) * off, y = spot.y + math.sin(rad) * off, z = spot.z, h = spot.h, ends = os.time() + minutes * 60 }
    st.last, st.by = os.time(), P.Name(src)
    P.dancers[pr.id] = st
    DancerBroadcast(pr.id)
    P.PropLog(pr.id, 'Danseuse arrivée', ('%s · %d min'):format(anim.label, minutes), src)
    return { ok = true, message = ('La danseuse est arrivée (%d min).'):format(minutes) }
end

function P.DancerAnim(src, pid, animId)
    local pr, c = DancerCheck(src, pid)
    if not pr then return { error = c } end
    local d = P.dancers[pr.id]
    if not d then return { error = 'Aucune danseuse en ce moment.' } end
    local anim = AnimOf(tostring(animId or ''))
    if not anim then return { error = 'Animation indisponible.' } end
    for _, x in ipairs(d.list) do x.anim = anim.id end
    DancerBroadcast(pr.id)
    return { ok = true, message = ('Animation : %s.'):format(anim.label) }
end

function P.DancerStop(src, pid)
    local pr, c = DancerCheck(src, pid)
    if not pr then return { error = c } end
    if not P.dancers[pr.id] then return { error = 'Aucune danseuse en ce moment.' } end
    DancerStopAll(pr.id)
    P.PropLog(pr.id, 'Danseuse renvoyée', nil, src)
    return { ok = true, message = 'La danseuse est partie.' }
end

-- ---------------------------------------------------------------------
-- Cannabis (3 pots par logement, vérifié ici)
-- ---------------------------------------------------------------------
local function PlantCheck(src, pid, nearId)
    local pr, err, c = Resident(src, pid, 'upgrades')
    if not pr then return nil, err end
    if not P.UpCfg().cannabis.enabled then return nil, 'La culture est désactivée par l\'administration.' end
    if not Ups(pr.id).cannabis then return nil, 'Achetez d\'abord l\'amélioration « Culture de cannabis ».' end
    if not InsideHome(src, pr.id) then return nil, 'Vous devez être dans le logement.' end
    local p
    if nearId then
        p = MySQL.single.await('SELECT * FROM `d8_plants` WHERE `id` = ? AND `property_id` = ? AND `contract_id` = ?', { tonumber(nearId) or 0, pr.id, c.id })
        if not p then return nil, 'Pot introuvable.' end
        local pc = P.Coords(src)
        if not pc or #(pc - V3(p)) > 3.0 then return nil, 'Approchez-vous du pot.' end
        Grow(p)
    end
    return pr, c, p
end

P.Pub.plantList = { fn = function(src, d)
    local pid = tonumber(d.pid) or 0
    local c = P.Contract(pid)
    if not InsideHome(src, pid) or not c or not Ups(pid).cannabis then return { list = {} } end
    local list = {}
    for _, p in ipairs(PlantRows(pid, c.id)) do list[#list + 1] = PlantView(Grow(p)) end
    local _, rights = P.RoleOf(src, pid)
    return { list = list, canCare = rights ~= nil and rights.upgrades == true }
end }

P.Pub.plantPlace = { fn = function(src, d)
    local pr, c = PlantCheck(src, d.pid)
    if not pr then return { error = c } end
    local cfg = P.UpCfg().cannabis
    local key = 'plant:' .. pr.id
    if not Lock(key) then return { error = 'Patientez.' } end
    local ok, res = pcall(function()
        local rows = PlantRows(pr.id, c.id)
        if #rows >= cfg.maxPots then return { error = ('%d pots maximum dans ce logement.'):format(cfg.maxPots) } end
        local pos = { x = tonumber(d.x), y = tonumber(d.y), z = tonumber(d.z) }
        if not pos.x or not pos.y or not pos.z then return { error = 'Position invalide.' } end
        local pc = P.Coords(src)
        if not pc or #(pc - V3(pos)) > 3.5 then return { error = 'Posez le pot près de vous.' } end
        if pr.points.exit and #(V3(pos) - V3(pr.points.exit)) > Config.Deco.maxDistance then return { error = 'Trop loin de l\'entrée du logement.' } end
        for _, x in ipairs(rows) do if #(V3(x) - V3(pos)) < cfg.minDistance then return { error = 'Trop près d\'un autre pot.' } end end
        MySQL.insert.await('INSERT INTO `d8_plants` (`property_id`, `contract_id`, `x`, `y`, `z`, `h`, `updated_at`) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { pr.id, c.id, r2(pos.x), r2(pos.y), r2(pos.z), r2(tonumber(d.h) or 0), os.time() })
        PlantsRefresh(pr.id)
        return { ok = true, message = ('Pot posé (%d / %d).'):format(#rows + 1, cfg.maxPots) }
    end)
    Unlock(key)
    if not ok then print(('^1[D8] Pot : %s^0'):format(tostring(res))) return { error = 'Erreur.' } end
    return res
end }

P.Pub.plantAction = { fn = function(src, d)
    local pr, c, p = PlantCheck(src, d.pid, d.id)
    if not pr then return { error = c } end
    local cfg = P.UpCfg().cannabis
    local key = 'pot:' .. p.id
    if not Lock(key) then return { error = 'Patientez.' } end
    local ok, res = pcall(function()
        local a = tostring(d.action or '')
        if a == 'seed' then
            if p.seed then return { error = 'Ce pot contient déjà une plante.' } end
            local v
            for _, x in ipairs(Config.Upgrades.cannabis.varieties) do
                if (not d.seed or d.seed == x.seed) and Count(src, x.seed) > 0 then v = x break end
            end
            if not v then return { error = 'Il vous faut une graine de cannabis.' } end
            if not Remove(src, v.seed, 1) then return { error = 'Graine introuvable.' } end
            p.seed, p.progress, p.water, p.health, p.fertilized = v.seed, 0, 30, 100, 0
            p.planted_by, p.planted_at, p.updated_at = P.Name(src), os.time(), os.time()
            SavePlant(p)
            P.PropLog(pr.id, 'Plante semée', v.label, src)
            return { ok = true, message = ('%s plantée. Arrosez-la régulièrement.'):format(v.label) }
        elseif a == 'water' then
            if not p.seed then return { error = 'Plantez d\'abord une graine.' } end
            if p.health <= 0 then return { error = 'La plante est morte.' } end
            if p.water >= cfg.water.max - 5 then return { error = 'Le pot est déjà bien arrosé.' } end
            if not Remove(src, cfg.water.item, 1) then return { error = 'Il vous faut une bouteille d\'eau.' } end
            p.water = math.min(cfg.water.max, p.water + cfg.water.perUse)
            SavePlant(p)
            return { ok = true, message = ('Plante arrosée (%d %%).'):format(math.floor(p.water)) }
        elseif a == 'feed' then
            if not p.seed or p.health <= 0 then return { error = 'Aucune plante vivante.' } end
            if tonumber(p.fertilized) == 1 then return { error = 'Engrais déjà ajouté.' } end
            if not Remove(src, cfg.fertilizer.item, 1) then return { error = 'Il vous faut de l\'engrais.' } end
            p.fertilized = 1
            SavePlant(p)
            return { ok = true, message = 'Engrais ajouté : la plante pousse plus vite.' }
        elseif a == 'harvest' then
            if not p.seed or p.health <= 0 or p.progress < 100 then return { error = 'La plante n\'est pas prête.' } end
            local v = Variety(p.seed)
            if not v then return { error = 'Variété inconnue.' } end
            local n = math.random(v.yield[1], v.yield[2])
            if not CanCarry(src, v.leaf, n) then return { error = 'Vous n\'avez pas assez de place.' } end
            if not Add(src, v.leaf, n) then return { error = 'Vous n\'avez pas assez de place.' } end
            p.seed, p.progress, p.water, p.health, p.fertilized, p.planted_at = nil, 0, 0, 100, 0, nil
            p.updated_at = os.time()
            SavePlant(p)
            P.PropLog(pr.id, 'Récolte', ('%s · %d feuille(s)'):format(v.label, n), src)
            return { ok = true, message = ('Récolte : %d feuille(s) de %s.'):format(n, v.label) }
        elseif a == 'clear' then
            if not p.seed then return { error = 'Le pot est déjà vide.' } end
            p.seed, p.progress, p.water, p.health, p.fertilized, p.planted_at = nil, 0, 0, 100, 0, nil
            p.updated_at = os.time()
            SavePlant(p)
            return { ok = true, message = 'Pot vidé.' }
        elseif a == 'remove' then
            MySQL.update.await('DELETE FROM `d8_plants` WHERE `id` = ?', { p.id })
            P.PropLog(pr.id, 'Pot retiré', p.seed and 'plante perdue' or nil, src)
            return { ok = true, message = 'Pot retiré.' }
        end
        return { error = 'Action inconnue.' }
    end)
    Unlock(key)
    if not ok then print(('^1[D8] Plante : %s^0'):format(tostring(res))) return { error = 'Erreur.' } end
    if res.ok then PlantsRefresh(pr.id) end
    return res
end }

-- ---------------------------------------------------------------------
-- Actions depuis le logement (zone de gestion, client)
-- ---------------------------------------------------------------------
P.Pub.upBuy = { fn = function(src, d) return P.BuyUpgrade(src, tonumber(d.pid), tostring(d.kind or ''), d.method) end }
P.Pub.upView = { fn = function(src, d)
    local pid = tonumber(d.pid) or 0
    if not P.RoleOf(src, pid) then return { error = 'Vous n\'avez aucun droit sur ce logement.' } end
    return { ok = true, upgrades = P.UpgradesView(src, pid) }
end }
P.Pub.camInfo = { fn = function(src, d) return P.CamPlaceInfo(src, d.pid) end }
P.Pub.camPlace = { fn = function(src, d) return P.CamPlace(src, d) end }
P.Pub.camView = { fn = function(src, d) return P.CamView(src, d.pid) end }
P.Pub.dancerSpot = { fn = function(src, d) return P.DancerSpot(src, d.pid) end }
P.Pub.dancerStart = { fn = function(src, d) return P.DancerStart(src, d.pid, d) end }
P.Pub.dancerAnim = { fn = function(src, d) return P.DancerAnim(src, d.pid, d.anim) end }
P.Pub.dancerStop = { fn = function(src, d) return P.DancerStop(src, d.pid) end }
P.Pub.dancerState = { fn = function(src, d)
    local pid = tonumber(d.pid) or 0
    if not InsideHome(src, pid) then return { list = nil } end
    return { list = DancerView(pid) }
end }

-- ---------------------------------------------------------------------
-- Téléphone : appli MAISON (elyzea_aura)
-- ---------------------------------------------------------------------
local function PropCard(src, pid, role, rights)
    local pr = P.props[pid]
    local c = P.Contract(pid)
    local u = Ups(pid)
    local cfg = P.UpCfg()
    local owned = {}
    for _, k in ipairs(KINDS) do if u[k] then owned[#owned + 1] = k end end
    local e = pr.points.enter or (pr.garage and pr.garage.points and pr.garage.points.enter)
    return {
        id = pr.id, name = pr.name, address = pr.address, category = pr.category, catLabel = Config.Categories[pr.category],
        role = role, rights = rights, kind = c and c.kind, ends = c and c.ends, holder = c and c.holder_name,
        status = pr.status, statusLabel = (Config.PropertyStatuses[pr.status] or {}).label,
        upgrades = owned, hasCode = pr.code ~= nil, inside = P.InsideCount and P.InsideCount(pid) or 0,
        dancer = P.dancers[pid] ~= nil, garage = pr.garage and pr.garage.enabled and P.GarageCapacity(pr) or 0,
        stash = pr.stashSlots, gps = e and { x = e.x, y = e.y } or nil,
        cameras = u.cameras and cfg.cameras.enabled and true or false,
    }
end

local Phone = {}
function Phone.home(src)
    local cid = P.Cid(src)
    if not cid then return { ok = false, error = 'Personnage non chargé.' } end
    local list = {}
    for _, h in ipairs(P.PropertiesOf(cid)) do
        local role, rights = P.RoleOf(src, h.id)
        if role and P.props[h.id] and P.props[h.id].enabled then list[#list + 1] = PropCard(src, h.id, role, rights) end
    end
    table.sort(list, function(a, b) if a.role ~= b.role then return a.role == 'holder' end return a.name < b.name end)
    return { ok = true, list = list, bells = P.BellsFor and P.BellsFor(src) or {} }
end
function Phone.has(src)
    local cid = P.Cid(src)
    return { ok = true, has = cid ~= nil and #P.PropertiesOf(cid) > 0 }
end
function Phone.prop(src, d)
    local pid = tonumber(d.pid) or 0
    local role, rights = P.RoleOf(src, pid)
    local pr = P.props[pid]
    if not role or not pr or not pr.enabled then return { ok = false, error = 'Vous n\'avez aucun droit sur ce logement.' } end
    local c = P.Contract(pid)
    local card = PropCard(src, pid, role, rights)
    card.upgrades = P.UpgradesView(src, pid)
    if rights.code or rights.manage then card.code = pr.code end
    card.grants = (rights.code or rights.holder) and P.GrantsView(pid) or nil
    if rights.holder then
        card.tenants = {}
        for tcid, a in pairs(c.access) do card.tenants[#card.tenants + 1] = P.TenantView(tcid, a) end
        table.sort(card.tenants, function(a, b) return (a.name or '') < (b.name or '') end)
        card.near = {}
        for _, id in ipairs(GetPlayers()) do
            local s = tonumber(id)
            if s ~= src and P.Dist(src, s) <= 5.0 and P.GetPlayer(s) and not c.access[P.Cid(s)] then card.near[#card.near + 1] = { id = s, name = P.Name(s) } end
        end
    end
    card.contract = { kind = c.kind, starts = c.starts, ends = c.ends, uid = c.uid, holder = c.holder_name }
    card.codeLength = Config.CodeLength
    card.bellChoices = Config.Bell.choices
    card.tenantRights = P.TenantRights
    return { ok = true, prop = card }
end
function Phone.buy(src, d) return P.BuyUpgrade(src, tonumber(d.pid), tostring(d.kind or ''), d.method) end
function Phone.setCode(src, d)
    local pr, err, rights = P.props[tonumber(d.pid) or 0], nil, nil
    local role
    role, rights = P.RoleOf(src, tonumber(d.pid) or 0)
    if not pr or not role then return { error = 'Vous n\'avez aucun droit sur ce logement.' } end
    if not (rights.code or rights.manage) then return { error = 'Le titulaire ne vous a pas donné ce droit.' } end
    return P.SetCode(src, pr, d.code)
end
function Phone.bellAnswer(src, d) return P.BellAnswer(src, d.id, d.accept == true, d.minutes) end
function Phone.grantRevoke(src, d)
    local pr, err = Resident(src, d.pid)
    if not pr then return { error = err } end
    local _, rights = P.RoleOf(src, pr.id)
    if not (rights.code or rights.holder) then return { error = 'Le titulaire ne vous a pas donné ce droit.' } end
    if not P.RevokeGrant(pr.id, tonumber(d.target) or 0, src) then return { error = 'Accès introuvable.' } end
    return { ok = true, message = 'Accès retiré.' }
end
function Phone.grantInvite(src, d)
    local pr, err = Resident(src, d.pid)
    if not pr then return { error = err } end
    local _, rights = P.RoleOf(src, pr.id)
    if not (rights.code or rights.holder) then return { error = 'Le titulaire ne vous a pas donné ce droit.' } end
    local t = tonumber(d.target)
    if not t or t == src or not P.GetPlayer(t) then return { error = 'Joueur introuvable (identifiant de connexion).' } end
    if P.RoleOf(t, pr.id) then return { error = 'Cette personne a déjà accès au logement.' } end
    local mins = P.Int(d.minutes, 1, Config.Bell.maxAccessMinutes or 240, Config.Bell.accessMinutes)
    P.GiveGrant(pr.id, t, 'invite', mins, src)
    P.Notify(t, ('%s vous autorise à entrer dans « %s » pendant %d min.'):format(P.Name(src), pr.name, mins), 'success')
    return { ok = true, message = ('%s peut entrer pendant %d min.'):format(P.Name(t), mins) }
end
function Phone.tenantAdd(src, d)
    local pr, err = Resident(src, d.pid)
    if not pr then return { error = err } end
    local _, rights = P.RoleOf(src, pr.id)
    if not rights.holder then return { error = 'Seul le titulaire du contrat ajoute des locataires.' } end
    return P.AddTenant(src, pr, d)
end
function Phone.tenantSet(src, d)
    local pr, err = Resident(src, d.pid)
    if not pr then return { error = err } end
    local _, rights = P.RoleOf(src, pr.id)
    if not rights.holder then return { error = 'Seul le titulaire du contrat règle les droits.' } end
    return P.SetTenant(src, pr, d)
end
function Phone.camView(src, d) return P.CamView(src, d.pid) end
function Phone.camRemove(src, d) return P.CamRemove(src, d.pid, d.id) end
function Phone.camRename(src, d) return P.CamRename(src, d.pid, d.id, d.label) end
function Phone.camInfo(src, d) return P.CamPlaceInfo(src, d.pid) end
function Phone.dancerStart(src, d) return P.DancerStart(src, d.pid, d) end
function Phone.dancerAnim(src, d) return P.DancerAnim(src, d.pid, d.anim) end
function Phone.dancerStop(src, d) return P.DancerStop(src, d.pid) end

local phoneRate = {}
exports('PhoneCall', function(src, action, data)
    src = tonumber(src)
    local f = Phone[tostring(action or '')]
    if not src or not f then return { ok = false, error = 'Action inconnue.' } end
    if not P.ready then return { ok = false, error = 'Dynasty 8 démarre, réessayez dans un instant.' } end
    local now = GetGameTimer()
    local r = phoneRate[src]
    if not r or now - r.t > 1000 then phoneRate[src] = { t = now, n = 1 } else r.n = r.n + 1 if r.n > 10 then return { ok = false, error = 'Trop de demandes.' } end end
    local ok, res = pcall(f, src, type(data) == 'table' and data or {})
    if not ok then print(('^1[D8/téléphone] %s : %s^0'):format(tostring(action), tostring(res))) return { ok = false, error = 'Erreur serveur.' } end
    res = res or {}
    if res.error then res.ok = false end
    return res
end)
exports('HasHome', function(src) local cid = P.Cid(tonumber(src)) return cid ~= nil and #P.PropertiesOf(cid) > 0 end)

-- ---------------------------------------------------------------------
-- Administration (admin_menu › Gestion immobilière) : réglages et suivi des améliorations
-- ---------------------------------------------------------------------
local function AdminProps()
    local list = {}
    for _, pr in pairs(P.props) do
        local c = P.Contract(pr.id)
        local u = c and Ups(pr.id) or {}
        local owned = {}
        for _, k in ipairs(KINDS) do if u[k] then owned[#owned + 1] = k end end
        local pts = pr.points or {}
        local g = pr.garage or {}
        list[#list + 1] = {
            id = pr.id, name = pr.name, address = pr.address, category = pr.category, enabled = pr.enabled, status = pr.status, interiorId = pr.interiorId,
            salePrice = pr.salePrice, rentPrice = pr.rentPrice, holder = c and c.holder_name or nil, kind = c and c.kind or nil, upgrades = owned,
            cams = c and (tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `d8_cameras` WHERE `property_id` = ? AND `contract_id` = ?', { pr.id, c.id })) or 0) or 0,
            pots = c and (tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `d8_plants` WHERE `property_id` = ? AND `contract_id` = ?', { pr.id, c.id })) or 0) or 0,
            dancer = P.dancers[pr.id] ~= nil,
            points = { enter = pts.enter ~= nil, bell = pts.bell ~= nil, exit = pts.exit ~= nil, manage = pts.manage ~= nil, stash = pts.stash ~= nil,
                garage = g.enabled == true, gEnter = g.points and g.points.enter ~= nil, gSpawn = g.points and g.points.spawn ~= nil,
                gInside = g.points and g.points.inside ~= nil, gExit = g.points and g.points.exit ~= nil, slots = #(g.slots or {}) },
            gSize = g.size, gCapacity = g.capacity, gInterior = g.interiorId,
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function P.AdminSummary(src)
    local cfg = P.UpCfg()
    local spots = {}
    for _, s in ipairs(MySQL.query.await('SELECT * FROM `d8_cam_spots` ORDER BY `property_id`, `id`') or {}) do
        spots[#spots + 1] = { id = s.id, pid = s.property_id, label = s.label, x = s.x, y = s.y, z = s.z, rx = s.rx, rz = s.rz, fov = s.fov, yaw = s.yaw_range, pitch = s.pitch_range }
    end
    local interiors = {}
    for _, i in pairs(P.interiors) do if i.enabled then interiors[#interiors + 1] = { id = i.id, label = i.label, kind = i.kind } end end
    table.sort(interiors, function(a, b) if a.kind ~= b.kind then return a.kind < b.kind end return a.label < b.label end)
    local agencies = {}
    for _, a in ipairs(P.agencyList or {}) do agencies[#agencies + 1] = { job = a.job, label = a.label } end
    local inside = P.inside[src]
    return {
        cfg = { cameras = cfg.cameras, dancer = cfg.dancer, cannabis = { enabled = cfg.cannabis.enabled, price = cfg.cannabis.price, payTo = cfg.cannabis.payTo, maxPots = cfg.cannabis.maxPots, speed = cfg.cannabis.speed } },
        props = AdminProps(), spots = spots, interiors = interiors, categories = Config.Categories, sizes = Config.GarageSizes, agencies = agencies,
        inside = inside and { pid = inside.pid, area = inside.area } or nil,
    }
end

local function SaveCfg(kind, patch)
    local saved = P.GetSetting('upgrades', {})
    saved = type(saved) == 'table' and saved or {}
    saved[kind] = type(saved[kind]) == 'table' and saved[kind] or {}
    local base = P.UpCfg()[kind]
    for k, v in pairs(patch) do
        local t = EDIT[kind][k]
        if t == 'bool' then saved[kind][k] = v == true
        elseif t == 'int' or t == 'num' then
            local lim = LIMITS[k] or { 0, 1e9 }
            local n = tonumber(v)
            if n then n = math.max(lim[1], math.min(lim[2], n)) saved[kind][k] = t == 'int' and math.floor(n) or n end
        elseif t == 'pay' then saved[kind][k] = (v == 'none') and 'none' or 'agency'
        elseif t == 'map' and type(v) == 'table' then
            local m = {}
            for _, a in ipairs(base.anims or {}) do if v[a.id] ~= nil then m[a.id] = v[a.id] == true end end
            saved[kind][k] = m
        end
    end
    P.SetSetting('upgrades', saved)
    cfgCache = nil
end

local function StaffCamPos(src)
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    return { x = r2(c.x), y = r2(c.y), z = r2(c.z + 0.9), rz = r2(GetEntityHeading(ped)) }
end

-- Remise à zéro d'une amélioration (contrat en cours) : caméras / pots supprimés, danseuse renvoyée
local function ResetUpgrade(pid, kind)
    local c = P.Contract(pid)
    if not c then return false, 'Aucun contrat actif sur ce bien.' end
    if kind == 'cameras' then MySQL.update.await('DELETE FROM `d8_cameras` WHERE `property_id` = ? AND `contract_id` = ?', { pid, c.id }) end
    if kind == 'cannabis' then MySQL.update.await('DELETE FROM `d8_plants` WHERE `property_id` = ? AND `contract_id` = ?', { pid, c.id }) PlantsRefresh(pid) end
    if kind == 'dancer' then DancerStopAll(pid) end
    MySQL.update.await('DELETE FROM `d8_upgrades` WHERE `property_id` = ? AND `contract_id` = ? AND `kind` = ?', { pid, c.id, kind })
    ups[pid] = nil
    return true
end

local AdminActs = {}
function AdminActs.upSettings(src, d)
    local kind = tostring(d.kind or '')
    if not EDIT[kind] or type(d.patch) ~= 'table' then return false, 'Réglage inconnu.' end
    SaveCfg(kind, d.patch)
    if kind == 'dancer' and P.UpCfg().dancer.enabled == false then for pid in pairs(P.dancers) do DancerStopAll(pid, 'désactivée par le staff') end end
    P.AdminLog(src, 'Améliorations : réglages', KLABEL[kind])
    return true, ('Réglages « %s » enregistrés.'):format(KLABEL[kind])
end
function AdminActs.upDefaults(src)
    P.SetSetting('upgrades', {})
    cfgCache = nil
    P.AdminLog(src, 'Améliorations : réglages de config.lua', nil)
    return true, 'Réglages des améliorations remis à ceux de config.lua.'
end
function AdminActs.upReset(src, d)
    local pid, kind = tonumber(d.pid) or 0, tostring(d.kind or '')
    if not P.props[pid] or not EDIT[kind] then return false, 'Bien ou amélioration inconnu.' end
    local ok, err = ResetUpgrade(pid, kind)
    if not ok then return false, err end
    P.PropLog(pid, 'Amélioration réinitialisée (staff)', KLABEL[kind], src)
    P.AdminLog(src, 'Amélioration réinitialisée', ('#%d · %s'):format(pid, KLABEL[kind]))
    return true, ('%s réinitialisée sur le bien #%d.'):format(KLABEL[kind], pid)
end
function AdminActs.dancerStop(src, d)
    local pid = tonumber(d.pid) or 0
    if not P.dancers[pid] then return false, 'Aucune danseuse sur ce bien.' end
    DancerStopAll(pid, 'renvoyée par le staff')
    return true, 'Danseuse renvoyée.'
end
function AdminActs.spotAdd(src, d)
    local pr = P.props[tonumber(d.pid) or 0]
    if not pr then return false, 'Bien introuvable.' end
    if P.inside[src] then return false, 'Sortez de l\'intérieur : les caméras se placent dehors.' end
    local p = StaffCamPos(src)
    local label = P.Clean(d.label, 40)
    local n = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `d8_cam_spots` WHERE `property_id` = ?', { pr.id })) or 0
    if n >= 12 then return false, '12 emplacements maximum par bien.' end
    if #label < 1 then label = ('Emplacement %d'):format(n + 1) end
    MySQL.insert.await('INSERT INTO `d8_cam_spots` (`property_id`, `label`, `x`, `y`, `z`, `rx`, `rz`, `fov`, `yaw_range`, `pitch_range`, `created_by`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { pr.id, label, p.x, p.y, p.z, Clamp(d.rx or -10, -89, 45), tonumber(d.rz) or p.rz, Clamp(d.fov or 60, 10, 120), Clamp(d.yaw or 45, 0, 180), Clamp(d.pitch or 20, 0, 90), P.Name(src) })
    P.PropLog(pr.id, 'Emplacement caméra ajouté (staff)', label, src)
    return true, ('« %s » ajouté à ta position (orientation : là où tu regardes).'):format(label)
end
function AdminActs.spotEdit(src, d)
    local id = tonumber(d.id) or 0
    local s = MySQL.single.await('SELECT * FROM `d8_cam_spots` WHERE `id` = ?', { id })
    if not s then return false, 'Emplacement introuvable.' end
    local x, y, z, rz = s.x, s.y, s.z, d.rz ~= nil and tonumber(d.rz) or s.rz
    if d.here == true then local p = StaffCamPos(src) x, y, z = p.x, p.y, p.z if d.rz == nil then rz = p.rz end end
    MySQL.update.await('UPDATE `d8_cam_spots` SET `label` = ?, `x` = ?, `y` = ?, `z` = ?, `rx` = ?, `rz` = ?, `fov` = ?, `yaw_range` = ?, `pitch_range` = ? WHERE `id` = ?',
        { P.Clean(d.label or s.label, 40), x, y, z, Clamp(d.rx or s.rx, -89, 45), (tonumber(rz) or 0) % 360, Clamp(d.fov or s.fov, 10, 120), Clamp(d.yaw or s.yaw_range, 0, 180), Clamp(d.pitch or s.pitch_range, 0, 90), id })
    return true, 'Emplacement enregistré.'
end
function AdminActs.spotDel(src, d)
    local id = tonumber(d.id) or 0
    local n = MySQL.update.await('DELETE FROM `d8_cam_spots` WHERE `id` = ?', { id })
    if (tonumber(n) or 0) == 0 then return false, 'Emplacement introuvable.' end
    -- Les caméras déjà posées dessus restent (leur position est gardée)
    MySQL.update.await('UPDATE `d8_cameras` SET `spot_id` = NULL WHERE `spot_id` = ?', { id })
    return true, 'Emplacement supprimé.'
end
function AdminActs.spotTest(src, d)
    local s = MySQL.single.await('SELECT * FROM `d8_cam_spots` WHERE `id` = ?', { tonumber(d.id) or 0 })
    if not s then return false, 'Emplacement introuvable.' end
    TriggerClientEvent('d8:client:camPreview', src, { x = s.x, y = s.y, z = s.z, rx = s.rx, rz = s.rz, fov = s.fov, label = s.label, yaw = s.yaw_range, pitch = s.pitch_range })
    return true, nil
end

-- Staff : se mettre (ou mettre un joueur) titulaire d'un logement, sans paiement, pour tester.
-- Contrat de vente à 0 $ marqué « Staff (test) » dans l'historique ; un contrat existant est d'abord terminé.
function AdminActs.setOwner(src, d)
    local pr = P.props[tonumber(d.pid) or 0]
    if not pr then return false, 'Bien introuvable.' end
    if not pr.enabled then return false, 'Activez d\'abord ce logement (Valider et activer).' end
    local target = tonumber(d.target) or src
    local cid = P.Cid(target)
    if not cid then return false, 'Joueur introuvable (ID serveur).' end
    local c = P.Contract(pr.id)
    if c then
        if c.holder_cid == cid then return false, ('%s est déjà titulaire de ce logement.'):format(P.Name(target)) end
        if d.replace ~= true then return false, ('Ce logement appartient à %s : cochez « remplacer » pour terminer son contrat.'):format(c.holder_name or '?') end
        P.EndContract(pr.id, 'ended', 'staff : remplacé pour test', src)
    end
    local uid = P.Uid('STF')
    local ok, id = pcall(function()
        return MySQL.insert.await([[INSERT INTO `d8_contracts` (`job`, `uid`, `property_id`, `kind`, `holder_cid`, `holder_name`, `price`, `rate`, `days`, `paid_total`, `method`,
            `started_at`, `employee_name`) VALUES (?, ?, ?, 'sale', ?, ?, 0, 0, 0, 0, NULL, NOW(), ?)]], { pr.job or P.MainJob(), uid, pr.id, cid, P.Name(target), ('Staff (test) · %s'):format(P.Name(src)) })
    end)
    if not ok or not id then return false, 'Contrat non enregistré.' end
    MySQL.update.await('UPDATE `d8_contracts` SET `stash_id` = ? WHERE `id` = ?', { P.StashId(pr.id, id), id })
    pr.contractId, pr.status, pr.reservedBy = id, 'sold', nil
    P.SaveProp(pr)
    P.LoadContract(pr.id)
    ups[pr.id] = nil
    if P.EndVisit then P.EndVisit(pr.id, 'le bien vient d\'être attribué') end
    P.PropLog(pr.id, 'Titulaire (staff, test)', P.Name(target), src)
    P.AdminLog(src, 'Titulaire de test', ('#%d %s → %s'):format(pr.id, pr.name, P.Name(target)))
    P.Touch()
    if target ~= src then P.Notify(target, ('Le staff vous a donné « %s » (test).'):format(pr.name), 'success') end
    return true, ('%s est titulaire de « %s » (test, 0 $). Appli Maison et toutes les fonctions disponibles.'):format(P.Name(target), pr.name)
end
function AdminActs.clearOwner(src, d)
    local pr = P.props[tonumber(d.pid) or 0]
    if not pr or not P.Contract(pr.id) then return false, 'Aucun contrat sur ce logement.' end
    P.EndContract(pr.id, 'ended', 'staff : libéré', src)
    P.AdminLog(src, 'Logement libéré', ('#%d %s'):format(pr.id, pr.name))
    return true, ('« %s » est de nouveau disponible.'):format(pr.name)
end

-- Actions techniques existantes (création, points, garage, activation…) passées par l'export admin
local PASS = { quickCreate = true, propSave = true, propEnable = true, propDelete = true, point = true, garageSave = true, slot = true, teleport = true, propInterior = true }

exports('AdminSummary', function(src)
    src = tonumber(src)
    if not P.ready or not P.IsStaffAdmin(src) then return nil end
    return P.AdminSummary(src)
end)
exports('AdminAction', function(src, name, data)
    src = tonumber(src)
    if not P.ready then return false, 'Dynasty 8 démarre, réessayez dans un instant.' end
    if not P.IsStaffAdmin(src) then return false, 'Réservé au staff (permission « Gestion immobilière »).' end
    data = type(data) == 'table' and data or {}
    name = tostring(name or '')
    local ok, a, b
    if AdminActs[name] then
        ok, a, b = pcall(AdminActs[name], src, data)
    elseif PASS[name] and P.Admin[name] then
        ok, a = pcall(P.Admin[name].fn, src, data)
        if ok and type(a) == 'table' then
            if a.confirm then return true, a.message, a end
            return a.error == nil, a.error or a.message, a
        end
    else
        return false, 'Action inconnue.'
    end
    if not ok then print(('^1[D8] Admin « %s » : %s^0'):format(name, tostring(a))) return false, 'Erreur serveur.' end
    return a, b
end)

-- ---------------------------------------------------------------------
-- Cycle de vie : fin de contrat, entrées, déconnexions, redémarrage
-- ---------------------------------------------------------------------
P.OnContractEnded = function(pid)
    ups[pid] = nil
    DancerStopAll(pid)
end

-- Joueur qui entre dans un logement : danseuse et plantes affichées par le client (dancerState / plantList)
-- Danseuses arrivées au bout de leur durée
CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for pid, d in pairs(P.dancers) do
            local changed = false
            for i = #d.list, 1, -1 do if now >= d.list[i].ends then table.remove(d.list, i) changed = true end end
            if #d.list == 0 then P.dancers[pid] = nil DancerBroadcast(pid)
            elseif changed then for i, x in ipairs(d.list) do x.n = i end DancerBroadcast(pid) end
        end
    end
end)

AddEventHandler('playerDropped', function() phoneRate[source] = nil end)
