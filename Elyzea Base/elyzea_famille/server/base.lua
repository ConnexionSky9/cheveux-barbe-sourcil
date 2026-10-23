-- =====================================================================
--  ELYZEA FAMILLE - serveur : socle commun
--  Adaptateurs vers les ressources du serveur (elyzea_core, elyzea_inventory, elyzea_ems, elyzea_police),
--  identifiants, limitation des appels, journal d'audit, création des tables.
-- =====================================================================
Fam = {}
local RES = GetCurrentResourceName()

function Fam.log(...) if Config.Debug then print(('[%s]'):format(RES), ...) end end
function Fam.err(...) print(('^1[%s]'):format(RES), ..., '^0') end

local function started(res) return GetResourceState(res) == 'started' end

-- ─────────── Joueurs (elyzea_core) ───────────

-- Fiche minimale d'un joueur connecté avec un personnage chargé, ou nil
function Fam.Joueur(src)
    src = tonumber(src)
    if not src or src <= 0 or not GetPlayerName(src) then return nil end
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData(src) end)
    if not ok or type(pd) ~= 'table' or not pd.citizenid then return nil end
    local ci = pd.charinfo or {}
    return {
        src = src,
        cid = pd.citizenid,
        gender = tonumber(ci.gender) or 0,
        birthdate = ci.birthdate,
        nom = ('%s %s'):format(ci.firstname or '?', ci.lastname or '?'),
    }
end

function Fam.Notify(src, msg, kind)
    pcall(function() exports.elyzea_core:Notify(src, msg, kind or 'inform') end)
end

-- ─────────── Inventaire (elyzea_inventory) ───────────

function Fam.Compte(src, item)
    if not started('elyzea_inventory') then return 0 end
    local ok, n = pcall(function() return exports.elyzea_inventory:GetItemCount(src, item) end)
    return ok and tonumber(n) or 0
end

-- Retire 1 objet : true seulement si l'inventaire confirme le retrait
function Fam.Retirer(src, item)
    if not started('elyzea_inventory') then return false end
    local ok, res = pcall(function() return exports.elyzea_inventory:RemoveItem(src, item, 1) end)
    return ok and res == true
end

-- Rend un objet retiré quand l'opération échoue ensuite (aucune perte en cas d'erreur)
function Fam.Rendre(src, item)
    if not started('elyzea_inventory') then return false end
    local ok, res = pcall(function() return exports.elyzea_inventory:AddItem(src, item, 1) end)
    return ok and res == true
end

local usables = {}
function Fam.Utilisable(item, fn) usables[item] = fn end

local function registerUsables()
    if not started('elyzea_inventory') then return end
    for item, fn in pairs(usables) do
        local ok, err = pcall(function()
            -- Le rappel de l'inventaire ne peut pas attendre la base : on renvoie false (pas de consommation
            -- automatique) et c'est notre code qui retire l'objet, une seule fois, après validation.
            exports.elyzea_inventory:RegisterUsableItem(item, function(source, it)
                CreateThread(function() fn(source, it) end)
                return false
            end)
        end)
        if not ok then Fam.err(('objet utilisable %s : %s'):format(item, tostring(err))) end
    end
end
AddEventHandler('elyzea_inventory:ready', registerUsables)
CreateThread(function() Wait(500) registerUsables() end)

-- ─────────── EMS / police (facultatifs) ───────────

function Fam.EmsEnService(src)
    if not started('elyzea_ems') then return false end
    local ok, r = pcall(function() return exports.elyzea_ems:IsOnDuty(src) end)
    return ok and r == true
end

-- Personnage indisponible (à terre ou menotté) : aucune interaction intime possible
function Fam.Indisponible(src)
    if started('elyzea_ems') then
        local ok, down = pcall(function() return exports.elyzea_ems:IsDown(src) end)
        if ok and down then return 'à terre' end
    end
    if started('elyzea_police') then
        local ok, cuffed = pcall(function() return exports.elyzea_police:IsCuffed(src) end)
        if ok and cuffed then return 'menotté(e)' end
    end
    local ped = GetPlayerPed(src)
    if ped ~= 0 and GetEntityHealth(ped) <= 0 then return 'inconscient(e)' end
    return nil
end

function Fam.Distance(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if pa == 0 or pb == 0 then return math.huge end
    local ca, cb = GetEntityCoords(pa), GetEntityCoords(pb)
    if ca.x == 0.0 and ca.y == 0.0 and ca.z == 0.0 then return nil end -- pas de OneSync : position inconnue côté serveur
    return #(ca - cb)
end

-- ─────────── Identifiants ───────────

local ALPHA = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'
function Fam.NouvelId(prefixe)
    local t = {}
    for i = 1, 8 do
        local n = math.random(1, #ALPHA)
        t[i] = ALPHA:sub(n, n)
    end
    return prefixe .. '-' .. table.concat(t)
end

-- ─────────── Limitation des appels ───────────

local buckets = {}
-- true si l'appel est autorisé (max appels par fenêtre de secondes, par joueur et par clé)
function Fam.Limite(src, cle, max, fenetre)
    local k = src .. ':' .. cle
    local now = GetGameTimer()
    local b = buckets[k]
    if not b or now - b.debut > fenetre * 1000 then
        buckets[k] = { debut = now, n = 1 }
        return true
    end
    b.n = b.n + 1
    return b.n <= max
end
AddEventHandler('playerDropped', function()
    local p = tostring(source) .. ':'
    for k in pairs(buckets) do if k:sub(1, #p) == p then buckets[k] = nil end end
end)

-- ─────────── Journal d'audit ───────────

function Fam.Audit(acteur, action, cible, details)
    if type(details) == 'table' then details = json.encode(details) end
    MySQL.insert('INSERT INTO `rp_famille_logs` (`at`, `acteur`, `action`, `cible`, `details`) VALUES (?, ?, ?, ?, ?)',
        { os.time(), acteur, action, cible, details })
end

-- Événement réseau suspect (paramètres invalides, appel hors contexte) : journalisé, ignoré
function Fam.Suspect(src, quoi)
    local j = Fam.Joueur(src)
    Fam.Audit(j and j.cid or ('src:' .. tostring(src)), 'suspect', nil, quoi)
    Fam.log('suspect', src, quoi)
end

-- ─────────── Tables ───────────

Fam.Pret = false
MySQL.ready(function()
    local sql = LoadResourceFile(RES, 'sql/install.sql') or ''
    sql = sql:gsub('%-%-[^\n]*', '')
    for stmt in sql:gmatch('[^;]+') do
        if stmt:match('%S') then
            local ok, err = pcall(MySQL.query.await, stmt)
            if not ok then Fam.err('création de table : ' .. tostring(err)) end
        end
    end
    -- Mises à jour d'une installation existante (colonnes ajoutées depuis la version 0.1)
    local function colonne(tbl, col, def)
        local n = MySQL.scalar.await('SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?', { tbl, col })
        if (tonumber(n) or 0) == 0 then
            local ok, err = pcall(MySQL.query.await, ('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(tbl, col, def))
            if ok then print(('[%s] colonne %s.%s ajoutée'):format(RES, tbl, col)) else Fam.err('mise à jour : ' .. tostring(err)) end
        end
    end
    colonne('rp_pregnancies', 'bebes_connus', 'TINYINT(1) NOT NULL DEFAULT 0 AFTER `bebes`')
    colonne('rp_pregnancies', 'end_reason', 'VARCHAR(32) NULL AFTER `ended_at`')   -- V5 : accouchement, naissance_auto, fin_staff…
    colonne('rp_pregnancies', 'trimestre', 'TINYINT NOT NULL DEFAULT 1 AFTER `due_at`')   -- V7 : trimestre déjà atteint (ne recule jamais)
    colonne('rp_pregnancies', 'terme_at', 'BIGINT NULL AFTER `trimestre`')               -- V7 : heure où le terme a été atteint
    colonne('rp_pregnancies', 'travail_etape', 'VARCHAR(24) NULL AFTER `terme_at`')     -- V8 : dernière étape de l'accouchement
    colonne('rp_pregnancies', 'travail', 'TEXT NULL AFTER `travail_etape`')             -- V8 : détail (EMS, heures, péridurale)
    -- Un redémarrage interrompt les moments intimes en cours : aucune conception pour eux
    MySQL.update.await("UPDATE `rp_intimacy_sessions` SET `status` = 'interrompue', `ended_at` = ?, `end_reason` = 'redemarrage' WHERE `status` = 'active'", { os.time() })
    Fam.TablesPretes = true
    if Fam.ChargerReglages then Fam.ChargerReglages() end   -- sinon : appelé par reglages.lua à son chargement
    Fam.Pret = true
    print(('^2[%s] Prêt (modules : intimité %s, contraception %s, conception %s).^0'):format(RES,
        tostring(Config.Modules.intimite), tostring(Config.Modules.contraception), tostring(Config.Modules.conception)))
end)
