-- =====================================================================
--  ELYZEA PRESSE - serveur : photos (appareil photo) et séquences (caméra)
--  · Un cliché ou une séquence = une fiche (légende, lieu, heure, auteur) que l'on
--    joint aux articles. Aucune image ni vidéo n'est capturée ou envoyée : c'est
--    une trace RP du reportage, honnêtement présentée comme telle.
--  · Le lieu vient de la position du joueur lue par le serveur ; la durée d'une
--    séquence est comptée par le serveur (début → fin), jamais par le client.
--  · Objet nécessaire sur soi (appareil photo / caméra), en service, limite par heure.
-- =====================================================================
local P = Presse
local M = Config.Media

local filming = {}   -- [src] = os.time() du début de la séquence

local function Has(src, item)
    local ok, n = pcall(function() return exports.elyzea_inventory:GetItemCount(src, item) end)
    return ok and (tonumber(n) or 0) > 0
end

local function Quota(src)
    local n = MySQL.scalar.await('SELECT COUNT(*) FROM `presse_media` WHERE `author_cid` = ? AND `created_at` >= DATE_SUB(NOW(), INTERVAL 1 HOUR)', { P.Cid(src) }) or 0
    return n < M.perHour
end

P.Actions.videoStart = { perm = 'media', duty = true, fn = function(src)
    if not Has(src, Config.Items.camera) then return { error = 'Il vous faut la caméra de la rédaction.' } end
    filming[src] = os.time()
    return { ok = true }
end }

P.Actions.videoCancel = { perm = nil, fn = function(src) filming[src] = nil return { ok = true } end }

P.Actions.mediaSave = { perm = 'media', duty = true, fn = function(src, d)
    local kind = d.kind == 'video' and 'video' or 'photo'
    if not Has(src, kind == 'video' and Config.Items.camera or Config.Items.photo) then
        return { error = kind == 'video' and 'Il vous faut la caméra de la rédaction.' or 'Il vous faut l\'appareil photo de la rédaction.' }
    end
    local seconds = nil
    if kind == 'video' then
        local st = filming[src]
        if not st then return { error = 'Aucune séquence en cours.' } end
        filming[src] = nil
        seconds = math.min(os.time() - st, M.maxVideoMinutes * 60)
        if seconds < M.minVideoSeconds then return { error = 'Séquence trop courte : rien n\'est enregistré.' } end
    end
    if not Quota(src) then return { error = ('Limite de %d photos / séquences par heure atteinte.'):format(M.perHour) } end
    local caption = P.Clean(tostring(d.caption or ''):gsub('%c', ' '), M.captionMax)
    if #caption < 3 then caption = kind == 'video' and 'Séquence sans titre' or 'Photo sans légende' end
    local c = P.Coords(src)
    local street = P.Clean(tostring(d.street or ''):gsub('%c', ' '), 120)
    local id = MySQL.insert.await([[INSERT INTO `presse_media` (`job`, `kind`, `author_cid`, `author_name`, `caption`, `street`, `x`, `y`, `z`, `seconds`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], { P.MyJob(src), kind, P.Cid(src), P.Name(src), caption, street ~= '' and street or nil,
        c and c.x or nil, c and c.y or nil, c and c.z or nil, seconds })
    if not id then return { error = 'Enregistrement impossible.' } end
    return { ok = true, id = id, message = kind == 'video' and ('Séquence enregistrée (%d s) : disponible dans la tablette.'):format(seconds)
        or 'Photo enregistrée : disponible dans la tablette.' }
end }

P.Actions.media = { perm = 'tablet', fn = function(src, d)
    local mine = d.mine == true
    local rows = MySQL.query.await(([[SELECT `id`, `kind`, `caption`, `street`, `author_name`, `author_cid`, `seconds`, UNIX_TIMESTAMP(`created_at`) AS t
        FROM `presse_media` WHERE `job` = ?%s ORDER BY `id` DESC LIMIT 150]]):format(mine and ' AND `author_cid` = ?' or ''), mine and { P.MyJob(src), P.Cid(src) } or { P.MyJob(src) }) or {}
    local me = P.Cid(src)
    for _, r in ipairs(rows) do r.mine = r.author_cid == me r.author_cid = nil end
    return { list = rows, canDeleteAll = P.Can(src, 'review') }
end }

P.Actions.mediaCaption = { perm = 'media', fn = function(src, d)
    local r = MySQL.single.await('SELECT `job`, `author_cid` FROM `presse_media` WHERE `id` = ?', { tonumber(d.id) or 0 })
    if not r or r.job ~= P.MyJob(src) or r.author_cid ~= P.Cid(src) then return { error = 'Média introuvable.' } end
    local caption = P.Clean(tostring(d.caption or ''):gsub('%c', ' '), M.captionMax)
    if #caption < 3 then return { error = 'Légende trop courte.' } end
    MySQL.update.await('UPDATE `presse_media` SET `caption` = ? WHERE `id` = ?', { caption, tonumber(d.id) })
    return { ok = true, message = 'Légende enregistrée.' }
end }

P.Actions.mediaDelete = { perm = 'tablet', fn = function(src, d)
    local r = MySQL.single.await('SELECT `job`, `author_cid` FROM `presse_media` WHERE `id` = ?', { tonumber(d.id) or 0 })
    if not r or r.job ~= P.MyJob(src) then return { error = 'Média introuvable.' } end
    if r.author_cid ~= P.Cid(src) and not P.Can(src, 'review') then return { error = 'Vous ne pouvez supprimer que vos propres médias.' } end
    MySQL.update.await('DELETE FROM `presse_media` WHERE `id` = ?', { tonumber(d.id) })
    return { ok = true, message = 'Média supprimé (il disparaît des articles où il était joint).' }
end }

AddEventHandler('playerDropped', function() filming[source] = nil end)
