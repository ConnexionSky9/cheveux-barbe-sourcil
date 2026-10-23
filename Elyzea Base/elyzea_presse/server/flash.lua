-- =====================================================================
--  ELYZEA PRESSE - serveur : flash info (bandeau à tout le serveur)
--  · Réservé à la permission « flash », en service ; délai par rédaction ET par auteur
--    pour éviter le spam ; chaque diffusion est gardée (presse_flashes) et journalisée.
--  · P.Broadcast sert aussi à l'annonce d'un nouvel article et aux annonces payantes « diffusées ».
-- =====================================================================
local P = Presse
local F = Config.Flash

local lastJob, lastAuthor = {}, {}

-- kind : 'flash' | 'publish' | 'ad'
function P.Broadcast(job, kind, title, text, author, authorCid)
    local a = P.agencies[job] or {}
    MySQL.insert('INSERT INTO `presse_flashes` (`job`, `kind`, `author_cid`, `author_name`, `title`, `text`) VALUES (?, ?, ?, ?, ?, ?)',
        { job, kind, authorCid, author, title, text })
    TriggerClientEvent('presse:client:flash', -1, { kind = kind, agency = a.label or Config.Job.label, short = a.short, color = a.color,
        title = title, text = text, author = kind ~= 'ad' and author or nil, seconds = F.seconds })
end

P.Actions.flashSend = { perm = 'flash', duty = true, fn = function(src, d)
    local job, cid = P.MyJob(src), P.Cid(src)
    local title = P.Clean(tostring(d.title or ''):gsub('%c', ' '), F.titleMax)
    local text = P.Clean(tostring(d.text or ''):gsub('%c', ' '), F.maxLength)
    if #text < 10 then return { error = 'Message trop court (10 caractères au moins).' } end
    if title == '' then title = 'Flash info' end
    local now = os.time()
    if lastJob[job] and now - lastJob[job] < F.cooldown then
        return { error = ('Un flash de votre rédaction vient d\'être diffusé : patientez %d s.'):format(F.cooldown - (now - lastJob[job])) }
    end
    if lastAuthor[cid] and now - lastAuthor[cid] < F.authorCooldown then
        return { error = ('Vous avez déjà diffusé un flash : patientez %d s.'):format(F.authorCooldown - (now - lastAuthor[cid])) }
    end
    lastJob[job], lastAuthor[cid] = now, now
    P.Broadcast(job, 'flash', title, text, P.Name(src), cid)
    P.Log(src, 'Flash info', ('%s : %s'):format(title, text))
    return { ok = true, message = 'Flash info diffusé à tout le serveur.' }
end }

P.Actions.flashes = { perm = 'tablet', fn = function(src)
    local job = P.MyJob(src)
    local now = os.time()
    return { list = MySQL.query.await([[SELECT `kind`, `author_name`, `title`, `text`, UNIX_TIMESTAMP(`created_at`) AS t FROM `presse_flashes`
        WHERE `job` = ? ORDER BY `id` DESC LIMIT 40]], { job }) or {},
        wait = math.max(0, lastJob[job] and (F.cooldown - (now - lastJob[job])) or 0),
        waitMe = math.max(0, lastAuthor[P.Cid(src)] and (F.authorCooldown - (now - lastAuthor[P.Cid(src)])) or 0) }
end }
