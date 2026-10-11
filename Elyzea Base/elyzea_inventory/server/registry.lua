--[[
    ELYZEA FA — Inventaire : registre des armes
    - Chaque arme reçoit un numéro de série UNIQUE à sa création (jamais réutilisé).
    - Propriétaire enregistré : le personnage dans l'inventaire duquel l'arme a été créée
      (achat à l'armurerie, armurerie de la police, don du staff…). Le registre ne change
      pas quand l'arme passe de main en main : seuls les porteurs successifs sont notés.
    - Gravure : kit de gravure (objet « kit_gravure »), une seule fois par arme.
    - Porteurs : chaque personnage qui sort l'arme est noté (empreintes pour la police scientifique).
    Tout est fait par le serveur ; le client ne peut rien modifier.
]]
WeaponRegistry = { serials = {}, lastHandler = {}, ready = false }
local R = WeaponRegistry

CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_weapons` (
            `serial` VARCHAR(20) NOT NULL PRIMARY KEY,
            `weapon` VARCHAR(60) NOT NULL,
            `owner_cid` VARCHAR(50) NULL, `owner_name` VARCHAR(100) NULL,
            `engraving` VARCHAR(40) NULL,
            `status` VARCHAR(20) NOT NULL DEFAULT 'active',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX (`owner_cid`)) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_weapons_history` (
            `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            `serial` VARCHAR(20) NOT NULL,
            `kind` VARCHAR(20) NOT NULL,
            `cid` VARCHAR(50) NULL, `name` VARCHAR(100) NULL, `fingerprint` VARCHAR(30) NULL,
            `details` VARCHAR(255) NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX (`serial`)) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
        for _, r in ipairs(MySQL.query.await('SELECT `serial` FROM `elyzea_weapons`') or {}) do R.serials[r.serial] = true end
    end)
    if not ok then print(('^1[elyzea_inventory] Registre des armes indisponible : %s^0'):format(tostring(err))) end
    R.ready = true
end)

local function Notify(src, msg, kind) pcall(function() exports.elyzea_core:Notify(src, msg, kind or 'inform') end) end

local function CharOf(cid)
    if not cid then return nil end
    local ok, p = pcall(function() return exports.elyzea_core:GetPlayerByCitizenId(cid) end)
    p = ok and p or nil
    local ci = p and p.PlayerData.charinfo or {}
    return p and ('%s %s'):format(ci.firstname or '', ci.lastname or '') or nil, p and p.PlayerData.metadata and p.PlayerData.metadata.fingerprint or nil
end

local function History(serial, kind, cid, name, fingerprint, details)
    MySQL.insert('INSERT INTO `elyzea_weapons_history` (`serial`, `kind`, `cid`, `name`, `fingerprint`, `details`) VALUES (?, ?, ?, ?, ?, ?)',
        { serial, kind, cid, name, fingerprint, details and tostring(details):sub(1, 255) or nil })
end

-- Nouveau numéro de série, jamais attribué (ne bloque pas : appelé pendant l'ajout d'un objet)
function R.NewSerial()
    for _ = 1, 50 do
        local s = ('%s%s'):format(math.random(100000, 999999), string.char(math.random(65, 90), math.random(65, 90), math.random(65, 90)))
        if not R.serials[s] then R.serials[s] = true return s end
    end
    local s = ('%X%s'):format(os.time(), string.char(math.random(65, 90), math.random(65, 90)))
    R.serials[s] = true
    return s
end

-- Enregistre une arme qui vient d'être créée
function R.Register(serial, weapon, ownerCid)
    local name = CharOf(ownerCid)
    MySQL.insert('INSERT IGNORE INTO `elyzea_weapons` (`serial`, `weapon`, `owner_cid`, `owner_name`) VALUES (?, ?, ?, ?)', { serial, weapon, ownerCid, name })
    History(serial, 'created', ownerCid, name, nil, ownerCid and 'Propriétaire enregistré' or 'Sans propriétaire (coffre, magasin…)')
end

-- Arme créée avant le registre : enregistrée à la première sortie (propriétaire = premier porteur connu)
function R.Ensure(serial, weapon, holderCid)
    if not serial or R.serials[serial] then return end
    R.serials[serial] = true
    local name = CharOf(holderCid)
    MySQL.insert('INSERT IGNORE INTO `elyzea_weapons` (`serial`, `weapon`, `owner_cid`, `owner_name`) VALUES (?, ?, ?, ?)', { serial, weapon, holderCid, name })
    History(serial, 'created', holderCid, name, nil, 'Arme antérieure au registre : premier porteur connu')
end

-- Un personnage sort l'arme : noté comme porteur (une fois par changement de porteur)
function R.Handled(src, serial, weapon)
    if not serial then return end
    local ok, p = pcall(function() return exports.elyzea_core:GetPlayer(src) end)
    if not ok or not p then return end
    local cid = p.PlayerData.citizenid
    R.Ensure(serial, weapon, cid)
    if R.lastHandler[serial] == cid then return end
    R.lastHandler[serial] = cid
    local ci = p.PlayerData.charinfo or {}
    History(serial, 'handled', cid, ('%s %s'):format(ci.firstname or '', ci.lastname or ''), p.PlayerData.metadata and p.PlayerData.metadata.fingerprint, nil)
end

-- Fiche d'une arme (pour la police scientifique). Bloquant : à appeler depuis un thread.
function R.Get(serial)
    if type(serial) ~= 'string' or serial == '' then return nil end
    local row = MySQL.single.await('SELECT `serial`, `weapon`, `owner_cid`, `owner_name`, `engraving`, `status`, UNIX_TIMESTAMP(`created_at`) AS created FROM `elyzea_weapons` WHERE `serial` = ?', { serial })
    if not row then return nil end
    local def = Items[row.weapon]
    row.label = def and def.label or row.weapon
    row.ammoname = def and def.ammoname or nil
    row.handlers = MySQL.query.await([[SELECT `cid`, `name`, `fingerprint`, UNIX_TIMESTAMP(`created_at`) AS t FROM `elyzea_weapons_history`
        WHERE `serial` = ? AND `kind` = 'handled' ORDER BY `id` DESC LIMIT 5]], { serial }) or {}
    row.history = MySQL.query.await([[SELECT `kind`, `name`, `details`, UNIX_TIMESTAMP(`created_at`) AS t FROM `elyzea_weapons_history`
        WHERE `serial` = ? ORDER BY `id` DESC LIMIT 15]], { serial }) or {}
    return row
end

-- Statut (saisie, restitution, destruction) : seulement par le serveur d'une autre ressource
function R.SetStatus(serial, status, who, details)
    if not ({ active = true, seized = true, destroyed = true })[status] then return false end
    MySQL.update('UPDATE `elyzea_weapons` SET `status` = ? WHERE `serial` = ?', { status, serial })
    History(serial, status == 'active' and 'returned' or status, nil, who, nil, details)
    return true
end

-- Nombre d'armes enregistrées d'un modèle (rapport : « plusieurs armes compatibles »)
function R.CountModel(weapon)
    return MySQL.scalar.await('SELECT COUNT(*) FROM `elyzea_weapons` WHERE `weapon` = ? AND `status` <> \'destroyed\'', { weapon }) or 0
end

exports('GetWeaponRecord', function(serial) return R.Get(serial) end)
exports('SetWeaponStatus', function(serial, status, who, details) return R.SetStatus(serial, status, who, details) end)
exports('CountWeaponModel', function(weapon) return R.CountModel(weapon) end)

-- ---------------------------------------------------------------------
-- Gravure (kit_gravure) : texte gravé sur l'arme en main, une seule fois
-- ---------------------------------------------------------------------
local engraving = {}
RegisterNetEvent('elyzea_inv:engrave', function(text)
    local src = source
    if not engraving[src] then return end
    engraving[src] = nil
    text = tostring(text or ''):gsub('[^%w%s%-%.\'éèêàâùûôîçÉÈÀÇ]', ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 24)
    if #text < 2 then return Notify(src, 'Gravure annulée.', 'error') end
    local cur = exports.elyzea_inventory:GetCurrentWeapon(src)
    if not cur or not cur.metadata or not cur.metadata.serial then
        return Notify(src, 'Sortez l\'arme à graver.', 'error')
    end
    if cur.metadata.engraving then return Notify(src, 'Cette arme est déjà gravée.', 'error') end
    if not exports.elyzea_inventory:RemoveItem(src, 'kit_gravure', 1) then
        return Notify(src, 'Il vous faut un kit de gravure.', 'error')
    end
    local meta = Shared.Copy(cur.metadata)
    meta.engraving = text
    exports.elyzea_inventory:SetMetadata(src, cur.slot, meta)
    MySQL.update('UPDATE `elyzea_weapons` SET `engraving` = ? WHERE `serial` = ?', { text, meta.serial })
    local name = CharOf(exports.elyzea_core:GetCitizenId(src))
    History(meta.serial, 'engraved', exports.elyzea_core:GetCitizenId(src), name, nil, text)
    Notify(src, ('Arme gravée : « %s ».'):format(text), 'success')
end)

CreateThread(function()
    while not RegisterUsableItem do Wait(500) end
    Wait(500)
    RegisterUsableItem('kit_gravure', function(src)
        local cur = exports.elyzea_inventory:GetCurrentWeapon(src)
        if not cur or not cur.metadata or not cur.metadata.serial then
            Notify(src, 'Sortez d\'abord l\'arme à graver.', 'error')
            return false
        end
        if cur.metadata.engraving then
            Notify(src, 'Cette arme est déjà gravée.', 'error')
            return false
        end
        engraving[src] = true
        TriggerClientEvent('elyzea_inv:askEngraving', src)
        return false   -- l'objet n'est consommé qu'une fois la gravure faite
    end)
end)

AddEventHandler('playerDropped', function() engraving[source] = nil end)
