-- =====================================================================
--  ELYZEA CLOTHING · VÊTEMENTS CACHÉS (serveur)
--  Le staff cache un vêtement depuis la boutique : plus personne ne le voit ni ne peut l'acheter,
--  dans toutes les boutiques. Gardé en base (table elyzea_clothing_hidden), donc conservé
--  après un redémarrage ou une mise à jour de la ressource.
--  Clé d'un vêtement : par sexe et par rayon,
--    GTA  : 'g:<n° du modèle>'
--    pack : 'c:<collection>:<n° dans le pack>'  (ne change pas si on ajoute ou retire d'autres packs)
--  Un vêtement caché l'est avec tous ses coloris.
-- =====================================================================
Hidden = { list = { male = {}, female = {} }, ready = false }

local function emptyList() return { male = {}, female = {} } end

-- Clé d'un vêtement (nil si invalide). p = { drawable, col, li } déjà nettoyé
function Hidden.key(p)
    if type(p) ~= 'table' then return nil end
    if p.col and p.col ~= '' and p.li then return ('c:%s:%d'):format(p.col, p.li) end
    local d = tonumber(p.drawable)
    if not d or d < 0 then return nil end
    return ('g:%d'):format(math.floor(d))
end

function Hidden.is(sex, cat, p)
    local k = Hidden.key(p)
    local s = Hidden.list[sex]
    return k ~= nil and s ~= nil and s[cat] ~= nil and s[cat][k] == true
end

-- Liste envoyée aux joueurs : { male = { tops = { 'g:12', 'c:pack:3' } }, female = {...} }
function Hidden.public()
    local out = emptyList()
    for sex, cats in pairs(Hidden.list) do
        for cat, keys in pairs(cats) do
            local l = {}
            for k in pairs(keys) do l[#l + 1] = k end
            if #l > 0 then table.sort(l) out[sex][cat] = l end
        end
    end
    return out
end

local function broadcast(target) TriggerClientEvent('elyzea_clothing:hidden', target or -1, Hidden.public()) end

CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `elyzea_clothing_hidden` (
                `sex` VARCHAR(6) NOT NULL,
                `cat` VARCHAR(20) NOT NULL,
                `piece` VARCHAR(90) NOT NULL,
                `hidden_by` VARCHAR(64) NOT NULL DEFAULT '',
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`sex`, `cat`, `piece`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]])
        local rows = MySQL.query.await('SELECT `sex`, `cat`, `piece` FROM `elyzea_clothing_hidden`') or {}
        local l = emptyList()
        for _, r in ipairs(rows) do
            if l[r.sex] and Cat[r.cat] then
                l[r.sex][r.cat] = l[r.sex][r.cat] or {}
                l[r.sex][r.cat][r.piece] = true
            end
        end
        Hidden.list = l
    end)
    if not ok then print(('^1[elyzea_clothing] Vêtements cachés : table non lue (%s)^0'):format(tostring(err))) end
    Hidden.ready = true
    broadcast()
end)

RegisterNetEvent('elyzea_clothing:requestHidden', function() broadcast(source) end)

-- Qui peut cacher : permission admin_menu « clothing_manage », ou la permission ACE de la commande de test
function Hidden.canManage(src)
    if GetResourceState('admin_menu') == 'started' then
        local ok, yes = pcall(function() return exports.admin_menu:HasPermission(src, 'clothing_manage') end)
        if ok and yes then return true end
    end
    return Config.TestAce ~= nil and IsPlayerAceAllowed(src, Config.TestAce)
end

local busy = {}
-- Cacher / ré-afficher un vêtement : { cat, drawable, col, li }, hide = true / false
RegisterNetEvent('elyzea_clothing:setHidden', function(piece, hide)
    local src = source
    if not Hidden.canManage(src) then return TriggerClientEvent('elyzea_clothing:notify', src, 'Tu n\'as pas la permission de cacher des vêtements.', 'error') end
    if busy[src] and busy[src] > GetGameTimer() then return end
    busy[src] = GetGameTimer() + 300
    local sex = Items.sexOf(src)
    local cat = type(piece) == 'table' and piece.cat
    if not sex or not Cat[cat] then return end
    local p = Items.cleanPiece(piece)
    local k = Hidden.key(p)
    if not k or #k > 90 then return end
    Hidden.list[sex][cat] = Hidden.list[sex][cat] or {}
    local name = GetPlayerName(src) or tostring(src)
    if hide == true then
        Hidden.list[sex][cat][k] = true
        MySQL.query.await('INSERT IGNORE INTO `elyzea_clothing_hidden` (`sex`, `cat`, `piece`, `hidden_by`) VALUES (?, ?, ?, ?)', { sex, cat, k, name:sub(1, 64) })
    else
        Hidden.list[sex][cat][k] = nil
        MySQL.query.await('DELETE FROM `elyzea_clothing_hidden` WHERE `sex` = ? AND `cat` = ? AND `piece` = ?', { sex, cat, k })
    end
    print(('[elyzea_clothing] %s %s le vêtement %s / %s / %s'):format(name, hide == true and 'cache' or 'ré-affiche', sex, cat, k))
    if GetResourceState('admin_menu') == 'started' then
        pcall(function() exports.admin_menu:AddLog(src, 'Boutique de vêtements', ('%s : %s %s (%s)'):format(hide == true and 'caché' or 'ré-affiché', Cat[cat].single or cat, k, sex)) end)
    end
    broadcast()
    TriggerClientEvent('elyzea_clothing:notify', src, hide == true and 'Vêtement caché : plus personne ne le voit ni ne peut l\'acheter.' or 'Vêtement de nouveau en vente.', 'success')
end)

AddEventHandler('playerDropped', function() busy[source] = nil end)
