-- ely_creator — serveur (base Elyzea)
local core = exports.elyzea_core

local creating = {} -- [src] = true quand le créateur est ouvert pour ce joueur
local saving   = {}
local checked  = {}

-- ─────────────────────────────────────────────────────────────
-- Base de données
-- ─────────────────────────────────────────────────────────────

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `ely_characters` (
            `identifier`  VARCHAR(64)  NOT NULL,
            `firstname`   VARCHAR(32)  NOT NULL,
            `lastname`    VARCHAR(32)  NOT NULL,
            `dateofbirth` VARCHAR(10)  NOT NULL,
            `sex`         CHAR(1)      NOT NULL,
            `height`      SMALLINT     NOT NULL,
            `nationality` VARCHAR(32)  NOT NULL,
            `skin`        LONGTEXT     NOT NULL,
            `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
end)

-- Identifiant du personnage chargé (citizenid), nil si aucun
local function getIdentifier(src)
    return core:GetCitizenId(src)
end

-- ─────────────────────────────────────────────────────────────
-- Validation
-- ─────────────────────────────────────────────────────────────

local function trim(s)
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function validName(n)
    if type(n) ~= 'string' then return nil end
    n = trim(n):gsub('%s+', ' ')
    local len = utf8.len(n)
    if not len or len < Config.Identity.nameMin or len > Config.Identity.nameMax then return nil end
    if n:find('[%d<>%%%$#@!%?%*%^&%(%)%[%]{}=%+_/\\|;:",%.~`]') then return nil end
    local lower = n:lower()
    for _, bad in ipairs(Config.Identity.blacklist) do
        if lower:find(bad, 1, true) then return nil end
    end
    return n
end

local function validDate(str)
    if type(str) ~= 'string' then return nil end
    local y, m, d = str:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not y then return nil end
    local t = os.time({ year = y, month = m, day = d, hour = 12 })
    if not t then return nil end
    local back = os.date('*t', t)
    if back.year ~= y or back.month ~= m or back.day ~= d then return nil end

    local now = os.date('*t')
    local age = now.year - y
    if now.month < m or (now.month == m and now.day < d) then age = age - 1 end
    if age < Config.Identity.minAge or age > Config.Identity.maxAge then return nil end
    return str, age
end

local function num(v, def, mn, mx)
    v = tonumber(v) or def
    if v ~= v then v = def end -- NaN
    if mn and v < mn then v = mn end
    if mx and v > mx then v = mx end
    return v
end

local function int(v, def, mn, mx)
    return math.floor(num(v, def, mn, mx))
end

-- Vêtement de pack : collection (nom) + n° dans le pack, en plus du n° global
local function packRef(src, dst)
    if type(src.col) == 'string' and src.col ~= '' and #src.col <= 64 and tonumber(src.li) then
        dst.col = src.col:lower():gsub('[^%w_%-]', '')
        dst.li = int(src.li, 0, 0, 5000)
    end
    return dst
end

local function sanitizeSkin(s, sex)
    if type(s) ~= 'table' then return nil end
    local out = {
        sex = sex,
        heritage = {},
        faceFeatures = {},
        eyeColor = int(s.eyeColor, 0, 0, 31),
        overlays = {},
        hair = {},
        components = {},
        props = {}
    }

    local h = type(s.heritage) == 'table' and s.heritage or {}
    out.heritage.mom      = int(h.mom, 21, 0, 45)
    out.heritage.dad      = int(h.dad, 0, 0, 45)
    out.heritage.shapeMix = num(h.shapeMix, 0.5, 0.0, 1.0)
    out.heritage.skinMix  = num(h.skinMix, 0.5, 0.0, 1.0)

    local f = type(s.faceFeatures) == 'table' and s.faceFeatures or {}
    for i = 1, 20 do out.faceFeatures[i] = num(f[i], 0.0, -1.0, 1.0) end

    local ov = type(s.overlays) == 'table' and s.overlays or {}
    for id = 0, 12 do
        local o = type(ov[tostring(id)]) == 'table' and ov[tostring(id)] or {}
        out.overlays[tostring(id)] = {
            style   = int(o.style, -1, -1, 254),
            opacity = num(o.opacity, 1.0, 0.0, 1.0),
            color   = int(o.color, 0, 0, 63)
        }
    end

    local hr = type(s.hair) == 'table' and s.hair or {}
    out.hair = {
        style     = int(hr.style, 0, 0, 1000),
        texture   = int(hr.texture, 0, 0, 100),
        color     = int(hr.color, 0, 0, 63),
        highlight = int(hr.highlight, 0, 0, 63)
    }

    local comps = type(s.components) == 'table' and s.components or {}
    for _, id in ipairs(Config.ComponentIds) do
        local c = type(comps[tostring(id)]) == 'table' and comps[tostring(id)] or {}
        out.components[tostring(id)] = packRef(c, {
            drawable = int(c.drawable, 0, 0, 5000),
            texture  = int(c.texture, 0, 0, 200)
        })
    end

    local props = type(s.props) == 'table' and s.props or {}
    for _, id in ipairs(Config.PropIds) do
        local p = type(props[tostring(id)]) == 'table' and props[tostring(id)] or {}
        out.props[tostring(id)] = packRef(p, {
            drawable = int(p.drawable, -1, -1, 5000),
            texture  = int(p.texture, 0, 0, 200)
        })
    end

    return out
end

-- ─────────────────────────────────────────────────────────────
-- Ouverture
-- ─────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────
-- Personnages, connexion, apparition
-- ─────────────────────────────────────────────────────────────

local function licenses(src)
    local l1 = GetPlayerIdentifierByType(src, 'license')
    local l2 = GetPlayerIdentifierByType(src, 'license2')
    return l1 or l2 or '', l2 or l1 or ''
end

local function listCharacters(src)
    local l1, l2 = licenses(src)
    local rows = MySQL.query.await('SELECT `citizenid`, `cid`, `charinfo` FROM `players` WHERE `license` = ? OR `license` = ? ORDER BY `cid` ASC', { l1, l2 }) or {}
    local list = {}
    for _, r in ipairs(rows) do
        local info = json.decode(r.charinfo or '{}') or {}
        local ely = MySQL.single.await('SELECT `skin`, `height`, `dateofbirth`, `nationality` FROM `ely_characters` WHERE `identifier` = ?', { r.citizenid })
        list[#list + 1] = {
            citizenid   = r.citizenid,
            cid         = r.cid,
            firstname   = info.firstname or '?',
            lastname    = info.lastname or '?',
            birthdate   = ely and ely.dateofbirth or info.birthdate,
            sex         = info.gender == 1 and 'f' or 'm',
            nationality = ely and ely.nationality or info.nationality,
            height      = ely and ely.height or nil,
            skin        = ely and ely.skin and json.decode(ely.skin) or nil
        }
    end
    return list
end

local loggingIn = {}

local function spawnCharacter(src, isNew)
    local player = core:GetPlayer(src)
    if not player then return end
    local citizenid = player.PlayerData.citizenid
    local row = MySQL.single.await('SELECT `skin` FROM `ely_characters` WHERE `identifier` = ?', { citizenid })
    local pos = player.PlayerData.position
    local position = nil
    if not isNew and pos and pos.x then
        local w = 0.0
        pcall(function() w = pos.w or 0.0 end)
        position = { x = pos.x, y = pos.y, z = pos.z, w = w }
    end
    SetPlayerRoutingBucket(src, 0)
    TriggerClientEvent('ely_creator:spawn', src, {
        position = position,
        skin     = row and row.skin and json.decode(row.skin) or nil,
        isNew    = isNew
    })
end

local function loginCharacter(src, citizenid)
    if loggingIn[src] or core:GetPlayer(src) then return end
    local owned = false
    for _, c in ipairs(listCharacters(src)) do
        if c.citizenid == citizenid then owned = true break end
    end
    if not owned then return end
    loggingIn[src] = true
    local ok = core:Login(src, citizenid)
    loggingIn[src] = nil
    if ok then spawnCharacter(src, false) end
end

local function openFor(src)
    creating[src] = true
    SetPlayerRoutingBucket(src, Config.BucketOffset + src)
    TriggerClientEvent('ely_creator:open', src)
end

RegisterNetEvent('ely_creator:start', function()
    local src = source
    if core:GetPlayer(src) then return end
    local chars = listCharacters(src)
    local max = Config.MaxCharacters

    if #chars == 0 then
        return openFor(src)
    end
    if max <= 1 then
        return loginCharacter(src, chars[1].citizenid)
    end
    SetPlayerRoutingBucket(src, Config.BucketOffset + src)
    TriggerClientEvent('ely_creator:select', src, chars, #chars < max)
end)

RegisterNetEvent('ely_creator:play', function(citizenid)
    loginCharacter(source, citizenid)
end)

RegisterNetEvent('ely_creator:new', function()
    local src = source
    if core:GetPlayer(src) then return end
    if #listCharacters(src) >= Config.MaxCharacters then return end
    openFor(src)
end)

-- ─────────────────────────────────────────────────────────────
-- Sauvegarde
-- ─────────────────────────────────────────────────────────────

local function reply(src, ok, msg, skin, isNew, spawn)
    TriggerClientEvent('ely_creator:saveResult', src, { ok = ok, msg = msg, skin = skin, isNew = isNew, spawn = spawn })
end

-- Point « nouveaux arrivants » défini dans admin_menu (Éditeur > Points de spawn)
local function adminSpawn()
    local res = Config.WelcomeResource or 'admin_menu'
    if GetResourceState(res) ~= 'started' then return nil end
    local ok, sp = pcall(function() return exports[res]:GetNewcomerSpawn() end)
    if ok and type(sp) == 'table' and sp.x then
        return { x = sp.x, y = sp.y, z = sp.z, h = sp.h or 0.0 }
    end
    return nil
end

RegisterNetEvent('ely_creator:save', function(identity, rawSkin)
    local src = source
    if not creating[src] then return reply(src, false, "Le créateur n'est pas ouvert pour vous.") end
    if saving[src] then return reply(src, false, 'Enregistrement déjà en cours.') end
    saving[src] = true

    local function fail(msg)
        saving[src] = nil
        reply(src, false, msg)
    end

    if type(identity) ~= 'table' then return fail('Identité invalide.') end

    local firstname = validName(identity.firstname)
    if not firstname then return fail('Prénom invalide : lettres uniquement, ' .. Config.Identity.nameMin .. ' à ' .. Config.Identity.nameMax .. ' caractères.') end

    local lastname = validName(identity.lastname)
    if not lastname then return fail('Nom invalide : lettres uniquement, ' .. Config.Identity.nameMin .. ' à ' .. Config.Identity.nameMax .. ' caractères.') end

    local dob = validDate(identity.dob)
    if not dob then return fail('Date de naissance invalide : âge entre ' .. Config.Identity.minAge .. ' et ' .. Config.Identity.maxAge .. ' ans.') end

    local sex = identity.sex == 'f' and 'f' or 'm'

    local height = tonumber(identity.height)
    if not height or height < Config.Identity.heightMin or height > Config.Identity.heightMax then
        return fail('Taille invalide.')
    end
    height = math.floor(height)

    local nationality = 'Autre'
    for _, n in ipairs(Config.Nationalities) do
        if n == identity.nationality then nationality = n break end
    end

    local skin = sanitizeSkin(rawSkin, sex == 'f' and 1 or 0)
    if not skin then return fail('Apparence invalide.') end

    local identifier = getIdentifier(src)
    local isNew = false

    if not identifier then
        -- Nouveau personnage : création dans la base Elyzea
        local chars = listCharacters(src)
        if #chars >= Config.MaxCharacters then return fail('Nombre maximum de personnages atteint.') end
        local used, cid = {}, 1
        for _, c in ipairs(chars) do used[tonumber(c.cid) or 0] = true end
        while used[cid] do cid = cid + 1 end
        local charinfo = {
            firstname = firstname, lastname = lastname, birthdate = dob,
            gender = sex == 'f' and 1 or 0, nationality = nationality, cid = cid
        }
        local loggedIn = core:Login(src, nil, { cid = cid, charinfo = charinfo })
        if not loggedIn then return fail('Création du personnage impossible.') end
        identifier = getIdentifier(src)
        isNew = true
    else
        -- Modification d'un personnage existant (/creator) : on met à jour l'identité
        local player = core:GetPlayer(src)
        if player then
            local info = player.PlayerData.charinfo or {}
            info.firstname, info.lastname, info.birthdate = firstname, lastname, dob
            info.gender, info.nationality = sex == 'f' and 1 or 0, nationality
            core:SetPlayerData(src, 'charinfo', info)
        end
    end

    if not identifier then return fail('Identifiant introuvable, reconnectez-vous.') end

    local encoded = json.encode(skin)

    local ok = pcall(function()
        MySQL.query.await([[
            INSERT INTO `ely_characters` (`identifier`, `firstname`, `lastname`, `dateofbirth`, `sex`, `height`, `nationality`, `skin`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                `firstname` = VALUES(`firstname`), `lastname` = VALUES(`lastname`),
                `dateofbirth` = VALUES(`dateofbirth`), `sex` = VALUES(`sex`),
                `height` = VALUES(`height`), `nationality` = VALUES(`nationality`),
                `skin` = VALUES(`skin`)
        ]], { identifier, firstname, lastname, dob, sex, height, nationality, encoded })

    end)

    if not ok then return fail('Erreur base de données. Réessayez dans un instant.') end

    creating[src] = nil
    saving[src] = nil
    SetPlayerRoutingBucket(src, 0)
    reply(src, true, nil, skin, isNew, isNew and adminSpawn() or nil)

    TriggerEvent('ely_creator:characterCreated', src, {
        firstname = firstname, lastname = lastname, dateofbirth = dob,
        sex = sex, height = height, nationality = nationality
    })
end)

-- ─────────────────────────────────────────────────────────────
-- Tenue portée (elyzea_clothing, tenues de service…)
-- ─────────────────────────────────────────────────────────────

local lastOutfit = {}
RegisterNetEvent('ely_creator:saveOutfit', function(comps, props)
    local src = source
    if type(comps) ~= 'table' or type(props) ~= 'table' then return end
    local now = GetGameTimer()
    if lastOutfit[src] and now - lastOutfit[src] < 1500 then return end
    lastOutfit[src] = now
    local identifier = getIdentifier(src)
    if not identifier then return end
    local row = MySQL.single.await('SELECT `skin`, `sex` FROM `ely_characters` WHERE `identifier` = ?', { identifier })
    if not row then return end
    local ok, skin = pcall(json.decode, row.skin)
    if not ok or type(skin) ~= 'table' then return end
    local clean = sanitizeSkin({
        heritage = skin.heritage, faceFeatures = skin.faceFeatures, eyeColor = skin.eyeColor,
        overlays = skin.overlays, hair = skin.hair, components = comps, props = props,
    }, row.sex == 'f' and 1 or 0)
    if not clean then return end
    MySQL.update('UPDATE `ely_characters` SET `skin` = ? WHERE `identifier` = ?', { json.encode(clean), identifier })
end)
AddEventHandler('playerDropped', function() lastOutfit[source] = nil end)

-- ─────────────────────────────────────────────────────────────
-- Commande admin
-- ─────────────────────────────────────────────────────────────

RegisterCommand(Config.AdminCommand, function(src, args)
    local target = tonumber(args[1]) or src
    if target <= 0 or not GetPlayerName(target) then
        if src > 0 then core:Notify(src, 'Joueur introuvable.', 'error') end
        return
    end
    openFor(target)
end, true)

AddEventHandler('playerDropped', function()
    local src = source
    creating[src], saving[src], checked[src], loggingIn[src] = nil, nil, nil, nil
end)

-- ─────────────────────────────────────────────────────────────
-- Exports serveur
-- ─────────────────────────────────────────────────────────────

exports('GetCharacter', function(src)
    local identifier = getIdentifier(src)
    if not identifier then return nil end
    local row = MySQL.single.await('SELECT * FROM `ely_characters` WHERE `identifier` = ?', { identifier })
    if row and row.skin then row.skin = json.decode(row.skin) end
    return row
end)

exports('OpenCreator', function(src)
    openFor(src)
end)
