-- =====================================================================
--  BANK HEIST - serveur : socle
--  Tables : bh_settings (réglages), bh_laptops (tentatives par ordinateur), bh_state (délais par banque),
--  bh_logs (journal). Requêtes client : Ely.callback 'bh:req' (action, données) ; le client n'envoie
--  que des identifiants et ses réponses aux mini-jeux, jamais de montant ni d'état.
-- =====================================================================
BHS = { S = nil, Req = {}, uid = 0 }
local P = BHS

local TABLES = {
    bh_settings = [[(`k` VARCHAR(32) NOT NULL PRIMARY KEY, `v` LONGTEXT NULL)]],
    bh_laptops = [[(`serial` VARCHAR(24) NOT NULL PRIMARY KEY, `attempts` INT NOT NULL DEFAULT 3, `owner_cid` VARCHAR(64) NULL,
        `last_bank` VARCHAR(32) NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)]],
    bh_state = [[(`bank_id` VARCHAR(32) NOT NULL PRIMARY KEY, `cooldown_until` INT NOT NULL DEFAULT 0, `active_session` VARCHAR(24) NULL)]],
    bh_logs = [[(`id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `kind` VARCHAR(16) NOT NULL, `ref` VARCHAR(32) NULL, `cid` VARCHAR(64) NULL, `name` VARCHAR(100) NULL,
        `details` TEXT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX (`kind`), INDEX (`created_at`))]],
}

local function installDB()
    for name, def in pairs(TABLES) do
        local ok, err = pcall(MySQL.query.await, ('CREATE TABLE IF NOT EXISTS `%s` %s DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'):format(name, def))
        if not ok then print(('^1[BANK] Table %s : %s^0'):format(name, tostring(err))) end
    end
end

function P.Uid(prefix)
    P.uid = (P.uid + 1) % 1000
    return ('%s%s%03d%02d'):format(prefix, os.date('%y%m%d%H%M%S'), P.uid, math.random(0, 99))
end

function P.Log(kind, ref, src, details)
    local cid, name = nil, nil
    if src and src > 0 then cid, name = Adapters.Perms.CitizenId(src), Adapters.Perms.Name(src) end
    MySQL.insert('INSERT INTO `bh_logs` (`kind`, `ref`, `cid`, `name`, `details`) VALUES (?, ?, ?, ?, ?)',
        { kind, ref and tostring(ref):sub(1, 32) or nil, cid, name, tostring(details or ''):sub(1, 2000) })
    if kind == 'anomaly' then print(('^3[BANK] Anomalie (%s) : %s · %s^0'):format(tostring(name or src), tostring(ref), tostring(details))) end
end

function P.Notify(src, text, kind) Adapters.Notify.Send(src, text, kind) end

-- Limite de fréquence et verrous
local hits = {}
function P.RateOk(src)
    local now = GetGameTimer()
    local h = hits[src]
    if not h or now - h.t > 3000 then hits[src] = { t = now, n = 1 } return true end
    h.n = h.n + 1
    if h.n > P.S.security.rateLimit then
        if h.n == P.S.security.rateLimit + 1 then P.Log('anomaly', 'rate', src, 'Trop de requêtes en 3 s') end
        return false
    end
    return true
end
local locks = {}
function P.Lock(k) if locks[k] then return false end locks[k] = true return true end
function P.Unlock(k) locks[k] = nil end

-- Positions lues par le serveur
function P.PedPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped), GetEntityHeading(ped)
end
function P.Near(src, p, dist)
    local pos = P.PedPos(src)
    return pos ~= nil and p ~= nil and #(pos - vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0)) <= dist + 0.5
end
function P.IsDown(src)
    if Player(src).state.emsDown then return true end
    local ped = GetPlayerPed(src)
    return ped and ped ~= 0 and GetEntityHealth(ped) <= 0
end
function P.InVehicle(src) local ped = GetPlayerPed(src) return ped ~= 0 and GetVehiclePedIsIn(ped, false) ~= 0 end
function P.Armed(src)
    local ped = GetPlayerPed(src)
    local w = ped ~= 0 and GetSelectedPedWeapon(ped) or 0
    return w ~= 0 and (w & 0xFFFFFFFF) ~= (joaat('WEAPON_UNARMED') & 0xFFFFFFFF)
end

Ely.callback.register('bh:req', function(src, action, data)
    local fn = P.Req[tostring(action or '')]
    if not fn then return { error = 'Action inconnue.' } end
    if not P.RateOk(src) then return { error = 'Patientez un instant.' } end
    local ok, res = pcall(fn, src, type(data) == 'table' and data or {})
    if not ok then print(('^1[BANK] Erreur %s : %s^0'):format(tostring(action), tostring(res))) return { error = 'Erreur serveur.' } end
    return type(res) == 'table' and res or {}
end)

AddEventHandler('playerDropped', function() hits[source] = nil end)

CreateThread(function()
    installDB()
    P.LoadSettings()
    P.LoadState()
    MySQL.query('DELETE FROM `bh_logs` WHERE `created_at` < (NOW() - INTERVAL ? DAY)', { P.S.security.logRetentionDays })
    if not Adapters.Bag.Ready() then print('^1[BANK] jewelry_heist n\'est pas démarré : la collecte des billets (sac) est impossible.^0') end
    print('^2[BANK] Braquage de banque prêt.^0')
end)
