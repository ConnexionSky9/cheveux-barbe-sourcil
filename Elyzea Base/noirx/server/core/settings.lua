--[[
    NOIR X — Paramètres persistants modifiables par le staff
    Chaque valeur de config.lua est adressée par un chemin, par ex. :
      'Laundering.feePercent', 'Laundering.hack.npcChance', 'Burner.price', 'Apps.4.enabled'
    Un réglage n'est accepté que si le chemin existe déjà dans config.lua et que le
    nouveau type est identique (nombre → nombre, booléen → booléen, chaîne → chaîne).
    Les valeurs sont enregistrées dans noirx_settings et réappliquées au démarrage.
]]

Settings = {}

-- Chemins que le staff ne peut pas modifier en jeu (structurels ou sensibles).
local LOCKED = {
    ['Database.driver'] = true,
    ['Inventory.provider'] = true,
    ['Economy.provider'] = true,
    ['Database.autoInstall'] = true,
    ['Admin.ace'] = true,
    ['Admin.resource'] = true,
    ['Admin.permission'] = true,
    ['Identity.provider'] = true,
    ['Item.name'] = true,
    ['Money.dirtyItem'] = true,
}

local function split(path)
    local parts = {}
    for p in tostring(path):gmatch('[^%.]+') do
        parts[#parts + 1] = tonumber(p) or p
    end
    return parts
end

local function resolve(path)
    local parts = split(path)
    if #parts < 2 then return nil end
    local node = Config
    for i = 1, #parts - 1 do
        node = node[parts[i]]
        if type(node) ~= 'table' then return nil end
    end
    return node, parts[#parts]
end

function Settings.Get(path)
    local node, key = resolve(path)
    if not node then return nil end
    return node[key]
end

--- Modifie un réglage (validation de type) et l'enregistre. Retourne true ou false, raison.
function Settings.Set(path, value, actor)
    if LOCKED[path] then return false, 'locked' end
    local node, key = resolve(path)
    if not node or node[key] == nil then return false, 'unknown_path' end
    local current = node[key]
    if type(value) ~= type(current) then return false, 'type_mismatch' end
    if type(value) == 'table' then return false, 'table_not_allowed' end
    if type(value) == 'number' and (value ~= value or value == math.huge or value == -math.huge) then
        return false, 'invalid_number'
    end
    node[key] = value
    if DB.driver ~= 'none' then
        local encoded = json.encode({ v = value })
        local updated = DB.Execute('UPDATE noirx_settings SET value = ?, updated_by = ?, updated_at = ? WHERE path = ?',
            { encoded, tostring(actor or 'system'), os.time(), path })
        if (updated or 0) == 0 then
            DB.Insert('INSERT INTO noirx_settings (path, value, updated_by, updated_at) VALUES (?, ?, ?, ?)',
                { path, encoded, tostring(actor or 'system'), os.time() })
        end
    end
    Audit.Log(0, 'admin.setting', { path = path, value = value, actor = actor })
    return true
end

--- Supprime la surcharge (retour à config.lua au prochain redémarrage).
function Settings.Reset(path, actor)
    if DB.driver == 'none' then return false, 'no_database' end
    DB.Execute('DELETE FROM noirx_settings WHERE path = ?', { path })
    Audit.Log(0, 'admin.setting_reset', { path = path, actor = actor })
    return true
end

function Settings.LoadOverrides()
    if DB.driver == 'none' then return end
    local rows = DB.Query('SELECT path, value FROM noirx_settings', {})
    local applied = 0
    for _, row in ipairs(rows) do
        local ok, decoded = pcall(json.decode, row.value)
        if ok and type(decoded) == 'table' and decoded.v ~= nil then
            local node, key = resolve(row.path)
            if node and node[key] ~= nil and type(node[key]) == type(decoded.v) and not LOCKED[row.path] then
                node[key] = decoded.v
                applied = applied + 1
            end
        end
    end
    if applied > 0 then NoirX.Debug(('%d réglage(s) persistant(s) appliqué(s)'):format(applied)) end
end
