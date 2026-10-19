-- =====================================================================
--  ELYZEA BÉBÉ (modèle) - serveur : persistance en base (V6)
--  Tables (créées au démarrage, rien n'est supprimé) :
--   · rp_bebes      : un enregistrement par bébé né en jeu (parents, grossesse + rang = jamais deux fois le même bébé),
--                     état de transport au repos (posé, poussette, « avec » un personnage), position, sommeil ;
--   · rp_poussettes : poussettes sorties (propriétaire, coloris, position).
--  Écriture : toutes les 2 s, seulement ce qui a changé (état, position arrondie, sommeil).
--  Démarrage : poussettes remises garées (frein serré), bébés remis à leur place ; un bébé qui était porté
--  revient aux pieds de son porteur dès qu'il est connecté.
-- =====================================================================
if not Config.Persistance.actif then return end

local RES = GetCurrentResourceName()
Persist = {}
local pret = false
local ecritB, ecritP = {}, {}     -- dernier état écrit (clé texte) par identifiant

local TABLES = {
    [[CREATE TABLE IF NOT EXISTS `rp_bebes` (
        `id`            VARCHAR(16) NOT NULL,
        `nom`           VARCHAR(64) NULL,
        `apparence`     TEXT        NOT NULL,
        `responsables`  TEXT        NULL,
        `pregnancy_id`  VARCHAR(16) NULL,
        `rang`          TINYINT     NULL,
        `etat`          VARCHAR(16) NOT NULL DEFAULT 'pose',
        `gardien_cid`   VARCHAR(64) NULL,
        `x` DOUBLE NULL, `y` DOUBLE NULL, `z` DOUBLE NULL, `cap` DOUBLE NULL,
        `pose_sol`      VARCHAR(16) NULL,
        `poussette_id`  VARCHAR(16) NULL,
        `endormi`       TINYINT(1)  NOT NULL DEFAULT 0,
        `bucket`        INT         NOT NULL DEFAULT 0,
        `created_at`    BIGINT      NOT NULL,
        `updated_at`    BIGINT      NOT NULL,
        `deleted_at`    BIGINT      NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `uniq_naissance` (`pregnancy_id`, `rang`),
        KEY `idx_gardien` (`gardien_cid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
    [[CREATE TABLE IF NOT EXISTS `rp_poussettes` (
        `id`         VARCHAR(16) NOT NULL,
        `cid`        VARCHAR(64) NOT NULL,
        `coloris`    VARCHAR(16) NULL,
        `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `cap` DOUBLE NOT NULL,
        `bucket`     INT         NOT NULL DEFAULT 0,
        `updated_at` BIGINT      NOT NULL,
        PRIMARY KEY (`id`),
        KEY `idx_cid` (`cid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
}

local function arrondi(v, pas) return v and math.floor(v / pas + 0.5) * pas or nil end

local function coordsPoussette(po)
    if po.etat == 'poussee' and po.pousseur and BB.present(po.pousseur) then
        return GetEntityCoords(GetPlayerPed(po.pousseur)), GetEntityHeading(GetPlayerPed(po.pousseur))
    end
    if po.ent and DoesEntityExist(po.ent) and po.etat ~= 'poussee' then return GetEntityCoords(po.ent), GetEntityHeading(po.ent) end
    return po.coords, po.cap
end

-- État « au repos » d'un bébé tel qu'il doit être retrouvé après un redémarrage
local function etatBebe(b)
    local e = { etat = b.etat, endormi = b.endormi and 1 or 0, bucket = b.bucket or 0 }
    if b.etat == 'pose' then
        e.x, e.y, e.z, e.cap, e.pose_sol = b.coords.x, b.coords.y, b.coords.z, b.cap or 0.0, b.poseSol or 'allonge'
    elseif b.etat == 'porte' then
        -- porté : « avec » le porteur ; position approximative (1 m) pour un retour au sol si besoin
        local cid = BB.citizenid(b.porteur)
        if not cid then return nil end
        local c = b.dernierePos or GetEntityCoords(GetPlayerPed(b.porteur))
        e.etat, e.gardien = 'garde', cid
        e.x, e.y, e.z = arrondi(c.x, 1), arrondi(c.y, 1), arrondi(c.z, 1)
    elseif b.etat == 'garde' then
        e.gardien = b.gardien
    elseif b.etat == 'poussette' then
        e.poussette = b.poussette
        local po = BB.Poussettes[b.poussette or '']
        local c = po and coordsPoussette(po)      -- position de repli si la poussette n'existe plus au redémarrage
        if c then e.x, e.y, e.z = arrondi(c.x, 1), arrondi(c.y, 1), arrondi(c.z, 1) end
    else
        return nil            -- état transitoire / erreur : on garde le dernier état écrit
    end
    return e
end

local function ecrireBebe(b, e)
    local now = os.time()
    MySQL.insert([[INSERT INTO `rp_bebes` (`id`, `nom`, `apparence`, `responsables`, `pregnancy_id`, `rang`, `etat`, `gardien_cid`, `x`, `y`, `z`, `cap`,
            `pose_sol`, `poussette_id`, `endormi`, `bucket`, `created_at`, `updated_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `etat` = VALUES(`etat`), `gardien_cid` = VALUES(`gardien_cid`), `x` = VALUES(`x`), `y` = VALUES(`y`),
            `z` = VALUES(`z`), `cap` = VALUES(`cap`), `pose_sol` = VALUES(`pose_sol`), `poussette_id` = VALUES(`poussette_id`),
            `endormi` = VALUES(`endormi`), `bucket` = VALUES(`bucket`), `responsables` = VALUES(`responsables`), `updated_at` = VALUES(`updated_at`)]],
        { b.id, b.nom, json.encode(b.apparence), b.responsables and json.encode(b.responsables) or nil, b.grossesse, b.rang,
          e.etat, e.gardien, e.x, e.y, e.z, e.cap, e.pose_sol, e.poussette, e.endormi, e.bucket, now, now })
end

local function ecrirePoussette(po, c, cap)
    MySQL.insert([[INSERT INTO `rp_poussettes` (`id`, `cid`, `coloris`, `x`, `y`, `z`, `cap`, `bucket`, `updated_at`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `x` = VALUES(`x`), `y` = VALUES(`y`), `z` = VALUES(`z`), `cap` = VALUES(`cap`), `coloris` = VALUES(`coloris`),
            `bucket` = VALUES(`bucket`), `updated_at` = VALUES(`updated_at`)]],
        { po.id, po.cid, po.coloris, c.x, c.y, c.z, cap or 0.0, po.bucket or 0, os.time() })
end

-- Appelé toutes les 2 s par server/bebes.lua
function Persist.enregistrer()
    if not pret then return end
    for id, b in pairs(BB.Bebes) do
        if b.persistant then
            local e = etatBebe(b)
            if e then
                local cle = json.encode(e)
                if ecritB[id] ~= cle then ecritB[id] = cle ecrireBebe(b, e) end
            end
        end
    end
    for id, po in pairs(BB.Poussettes) do
        if po.cid and not po.cid:find('^src:') then
            local c, cap = coordsPoussette(po)
            if c then
                c = vector3(arrondi(c.x, 0.25), arrondi(c.y, 0.25), arrondi(c.z, 0.25))
                cap = arrondi(cap or 0.0, 5)
                local cle = ('%s|%s|%s|%s|%s|%s'):format(c.x, c.y, c.z, cap, po.coloris, po.bucket or 0)
                if ecritP[id] ~= cle then ecritP[id] = cle ecrirePoussette(po, c, cap) end
            end
        end
    end
end

function Persist.oublierBebe(id)
    ecritB[id] = nil
    if pret then MySQL.update('UPDATE `rp_bebes` SET `deleted_at` = ? WHERE `id` = ?', { os.time(), id }) end
end

function Persist.oublierPoussette(id)
    ecritP[id] = nil
    if pret then MySQL.update('DELETE FROM `rp_poussettes` WHERE `id` = ?', { id }) end
    -- un bébé enregistré dont la poussette disparaît a déjà été reposé au sol par server/bebes.lua
end

-- Bébé déjà né pour cette grossesse et ce rang ? (aucun doublon, même si la naissance est rejouée)
function Persist.idNaissance(gid, rang)
    for id, b in pairs(BB.Bebes) do if b.grossesse == gid and b.rang == rang then return id end end
    if not pret then return nil end
    return MySQL.scalar.await('SELECT `id` FROM `rp_bebes` WHERE `pregnancy_id` = ? AND `rang` = ? AND `deleted_at` IS NULL', { gid, rang })
end

-- ─────────── Retour d'un bébé « avec » un personnage ───────────

local function srcDeCid(cid)
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        if BB.citizenid(src) == cid then return src end
    end
end

function Persist.rendre(src)
    local cid = BB.citizenid(src)
    if not cid then return 0 end
    local n = 0
    for _, b in pairs(BB.Bebes) do
        if b.etat == 'garde' and b.gardien == cid then
            local c, cap = BB.devant(src, 0.6)
            b.bucket = GetPlayerRoutingBucket(src)
            b.gardien = nil
            if BB.poserA(b, 'allonge', c, cap) then n = n + 1 end
        end
    end
    if n > 0 then BB.notify(src, n == 1 and 'Votre bébé est avec vous (posé à vos pieds).' or ('Vos %d bébés sont avec vous.'):format(n), 'inform') end
    return n
end

AddEventHandler('elyzea:server:playerLoaded', function(src)
    src = tonumber(src)
    SetTimeout(3000, function() if src and BB.present(src) then Persist.rendre(src) end end)
end)

-- ─────────── Chargement au démarrage ───────────

local function charger()
    for _, q in ipairs(TABLES) do
        local ok, err = pcall(MySQL.query.await, q)
        if not ok then print(('^1[%s] création de table : %s^0'):format(RES, tostring(err))) end
    end
    local nP, nB = 0, 0
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `rp_poussettes`') or {}) do
        if not BB.Poussettes[r.id] then
            local po = { id = r.id, cid = r.cid, coloris = r.coloris, bucket = tonumber(r.bucket) or 0, etat = 'garee', restauree = true }
            BB.Poussettes[r.id] = po
            if BB.garerA(po, vector3(r.x + 0.0, r.y + 0.0, r.z + 0.0), r.cap + 0.0) then nP = nP + 1 else BB.Poussettes[r.id] = nil end
        end
    end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `rp_bebes` WHERE `deleted_at` IS NULL') or {}) do
        if not BB.Bebes[r.id] then
            local okA, app = pcall(json.decode, r.apparence or '{}')
            local okR, resp = pcall(json.decode, r.responsables or 'null')
            local opts = { id = r.id, persistant = true, grossesse = r.pregnancy_id, rang = tonumber(r.rang), nom = r.nom,
                           endormi = tonumber(r.endormi) == 1, bucket = tonumber(r.bucket) or 0, responsables = okR and resp or nil }
            local po = r.poussette_id and BB.Poussettes[r.poussette_id]
            local b
            if r.etat == 'garde' or (r.etat == 'poussette' and not po and r.x == nil) then
                -- avec un personnage (ou poussette disparue sans position) : aucune entité tant qu'il n'est pas là
                b = BB.nouveauGarde(okA and app or {}, opts, r.gardien_cid)
            elseif r.etat == 'poussette' and po and not po.bebe then
                local c = po.coords
                if CreerBebe(okA and app or {}, c, po.cap or 0.0, opts) then
                    b = BB.Bebes[r.id]
                    b.etat, b.poussette = 'poussette', po.id
                    po.bebe = b.id
                    BB.majDedans(po)
                    if not BB.placer(b) then BB.poserA(b, 'allonge', c, po.cap or 0.0) end
                end
            elseif r.x ~= nil then
                if CreerBebe(okA and app or {}, vector3(r.x + 0.0, r.y + 0.0, r.z + 0.0), (r.cap or 0.0) + 0.0,
                    (function() opts.pose = r.pose_sol return opts end)()) then b = BB.Bebes[r.id] end
            end
            if b then nB = nB + 1 else print(('^1[%s] bébé %s non restauré (état %s)^0'):format(RES, r.id, tostring(r.etat))) end
        end
    end
    pret = true
    print(('^2[%s] Persistance : %d poussette(s), %d bébé(s) restauré(s).^0'):format(RES, nP, nB))
    -- personnages déjà connectés (redémarrage de la ressource seule)
    for _, s in ipairs(GetPlayers()) do Persist.rendre(tonumber(s)) end
end

MySQL.ready(function()
    local ok, err = pcall(charger)
    if not ok then print(('^1[%s] persistance : %s^0'):format(RES, tostring(err))) end
end)

-- Pour les tests
Persist.srcDeCid = srcDeCid
