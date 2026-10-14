-- =====================================================================
--  BLACKPHONE - serveur
--  · Ouverture UNIQUEMENT depuis l'objet de l'inventaire : elyzea_inventory appelle
--    exports.blackphone:useBlackphone (déclaré dans shared/items.lua : server = { export = ... }).
--  · Chaque téléphone a un numéro de série (métadonnée « serial »), enregistré dans bp_devices.
--    Il est attribué au premier usage et ne change plus (donner, poser, reconnecter : même appareil).
--  · Le client ne peut pas ouvrir le téléphone seul : il reçoit l'ordre du serveur, et le serveur
--    revérifie régulièrement que l'objet est toujours sur le joueur.
-- =====================================================================
local INV = 'elyzea_inventory'

local function inv(fn, ...)
    if GetResourceState(INV) ~= 'started' then return nil end
    local args = { ... }
    local ok, a, b = pcall(function() return exports[INV][fn](exports[INV], table.unpack(args)) end)
    if not ok then print(('^1[BLACKPHONE] %s : %s^0'):format(fn, tostring(a))) return nil end
    return a, b
end
local function cidOf(src)
    local ok, cid = pcall(function() return exports.elyzea_core:GetCitizenId(src) end)
    return ok and cid or nil
end
local function hasPhone(src) return (tonumber((inv('GetItemCount', src, Config.Item))) or 0) > 0 end

local seq = 0
local function newSerial()
    seq = (seq + 1) % 1000
    return ('BP-%s-%03d%02d'):format(os.date('%y%m%d%H%M%S'), seq, math.random(0, 99))
end

-- Numéro de série de l'appareil utilisé (attribué au premier usage)
local function ensureSerial(src, slot)
    local s = type(slot) == 'table' and slot or nil
    local md = s and type(s.metadata) == 'table' and s.metadata or {}
    if md.serial then
        MySQL.update('UPDATE `bp_devices` SET `last_cid` = ?, `last_used` = NOW() WHERE `serial` = ?', { cidOf(src), md.serial })
        return md.serial
    end
    local serial = newSerial()
    local meta = {}
    for k, v in pairs(md) do meta[k] = v end
    meta.serial = serial
    if s and s.slot then inv('SetMetadata', src, s.slot, meta) end
    MySQL.insert('INSERT INTO `bp_devices` (`serial`, `owner_cid`, `last_cid`, `last_used`) VALUES (?, ?, ?, NOW())', { serial, cidOf(src), cidOf(src) })
    return serial
end

-- Appelé par elyzea_inventory quand le joueur utilise l'objet : (« usingItem », { id = src }, emplacement)
exports('useBlackphone', function(_, who, slot)
    local src = type(who) == 'table' and tonumber(who.id) or tonumber(who)
    if not src or not hasPhone(src) then return false end
    local serial = ensureSerial(src, slot)
    TriggerClientEvent('blackphone:client:open', src, { serial = serial })
    return false   -- l'objet n'est jamais consommé
end)

-- Vérification régulière demandée par le client tant que le téléphone est ouvert
Ely.callback.register('blackphone:check', function(src) return { ok = hasPhone(src) } end)

CreateThread(function()
    local ok, err = pcall(MySQL.query.await, [[CREATE TABLE IF NOT EXISTS `bp_devices` (
        `serial` VARCHAR(32) NOT NULL PRIMARY KEY, `owner_cid` VARCHAR(64) NULL, `last_cid` VARCHAR(64) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `last_used` TIMESTAMP NULL) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    if not ok then print('^1[BLACKPHONE] Table bp_devices : ' .. tostring(err) .. '^0') end
    print('^2[BLACKPHONE] Prêt.^0')
end)
