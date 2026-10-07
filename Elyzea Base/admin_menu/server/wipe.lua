-- =========================================================
--  WIPE D'UN PERSONNAGE (permission « wipe_character »)
--  ID du joueur → ses personnages → suppression totale d'un personnage
--  (double confirmation : « Êtes-vous sûr ? » puis écrire ElyzeaFA).
-- =========================================================
local AM = AdminMenu
local CONFIRM = 'ElyzeaFA'
local Lookups = {}   -- [staff] = { target, license, name, chars = { ... } }

local function db(method, query, params)
    return MySQL[method].await(query, params or {})
end

local function licenseOf(src)
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData(src) end)
    if ok and pd and pd.license then return pd.license end
    return GetPlayerIdentifierByType(src, 'license2') or GetPlayerIdentifierByType(src, 'license')
end

-- Tables nettoyées en plus de celles de la base Elyzea (si elles existent) : tout ce qui est lié au personnage
local EXTRA = {
    'player_vehicles', 'playerskins', 'player_outfits', 'ely_characters', 'ely_licenses', 'elyzea_permis',
    'police_records', 'police_fines', 'police_warrants', 'police_jail', 'lscustom_invoices',
}

local function deleteCharacter(cid)
    -- La base Elyzea supprime le personnage de ses tables (players, métiers, véhicules, apparence)
    local done = pcall(function() exports.elyzea_core:DeleteCharacter(cid) end)
    if not done then db('update', 'DELETE FROM players WHERE citizenid = ?', { cid }) end
    for _, t in ipairs(EXTRA) do
        pcall(db, 'update', ('DELETE FROM `%s` WHERE citizenid = ?'):format(t), { cid })
    end
    pcall(db, 'update', 'DELETE FROM players WHERE citizenid = ?', { cid })
end

local A = AM.Actions
A.wipe_lookup = { perm = 'wipe_character', fn = function(src, d)
    local t = tonumber(d.target)
    if not t or not GetPlayerName(t) then Lookups[src] = { error = ('Aucun joueur connecté avec l\'ID %s.'):format(tostring(d.target)) } return end
    local lic = licenseOf(t)
    if not lic then Lookups[src] = { error = 'Licence du joueur introuvable.' } return end
    local current = Bridge.GetCharId(t)
    local l1 = GetPlayerIdentifierByType(t, 'license') or lic
    local rows = db('query', 'SELECT citizenid, cid, charinfo, money, job FROM players WHERE license = ? OR license = ? ORDER BY cid', { lic, l1 }) or {}
    local chars = {}
    for _, r in ipairs(rows) do
        local ci = json.decode(r.charinfo or '{}') or {}
        local money = json.decode(r.money or '{}') or {}
        local job = json.decode(r.job or '{}') or {}
        chars[#chars + 1] = {
            citizenid = r.citizenid, slot = r.cid, name = ('%s %s'):format(ci.firstname or '?', ci.lastname or ''),
            birthdate = ci.birthdate, job = job.label or job.name, bank = math.floor(tonumber(money.bank) or 0),
            cash = math.floor(tonumber(money.cash) or 0), active = r.citizenid == current,
        }
    end
    Lookups[src] = { target = t, license = lic, rp = GetPlayerName(t), chars = chars }
end }

A.wipe_character = { perm = 'wipe_character', fn = function(src, d)
    local L = Lookups[src]
    local cid = tostring(d.citizenid or '')
    if tostring(d.confirm or '') ~= CONFIRM then return AM.notify(src, ('Confirmation incorrecte : écris exactement %s.'):format(CONFIRM), 'error') end
    if not L or not L.chars then return AM.notify(src, 'Recherche d\'abord le joueur par son ID.', 'error') end
    local char
    for _, c in ipairs(L.chars) do if c.citizenid == cid then char = c end end
    if not char then return AM.notify(src, 'Ce personnage n\'appartient pas à ce joueur.', 'error') end
    if L.target and GetPlayerName(L.target) and not AM.checkHierarchy(src, L.target) then return end

    -- Le joueur joue ce personnage : il est d'abord déconnecté
    if L.target and GetPlayerName(L.target) and Bridge.GetCharId(L.target) == cid then
        DropPlayer(L.target, 'Ton personnage a été supprimé par le staff. Reconnecte-toi pour en créer un nouveau.')
        Wait(2000)
    end
    deleteCharacter(cid)
    AM.addLog(src, 'WIPE personnage', ('%s (%s) · joueur %s · %s'):format(char.name, cid, L.rp or '?', L.license))
    AM.notify(src, ('Le personnage %s a été supprimé définitivement.'):format(char.name), 'success')
    -- Liste mise à jour
    local still = {}
    for _, c in ipairs(L.chars) do if c.citizenid ~= cid then still[#still + 1] = c end end
    L.chars = still
end }

A.wipe_clear = { perm = 'wipe_character', fn = function(src) Lookups[src] = nil end }

table.insert(AM.DataHooks, function(src, data)
    if AM.hasPerm(src, 'wipe_character') then data.wipe = { lookup = Lookups[src] or false, confirm = CONFIRM } end
end)
AddEventHandler('playerDropped', function() Lookups[source] = nil end)
