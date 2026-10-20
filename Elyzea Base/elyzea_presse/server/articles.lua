-- =====================================================================
--  ELYZEA PRESSE - serveur : articles (rédaction, validation, publication, archives)
--  Cycle : brouillon (draft) → soumis (pending) → publié (published) → archivé (archived)
--          renvoyé (rejected) : retour à l'auteur avec une note ; retiré (deleted) : caché, gardé en base.
--  Règles (vérifiées ici, jamais par l'interface) :
--   · un journaliste ne voit et ne touche que les articles de SA rédaction ;
--   · il ne modifie que ses propres brouillons (sauf « review » pour les soumis, « edit_any » pour les publiés) ;
--   · publier soi-même demande « publish », valider l'article d'un autre demande « review » ;
--   · une modification concurrente est refusée (numéro de version) ;
--   · un titre déjà publié dans la rédaction ces derniers jours est refusé (doublon) ;
--   · chaque action est tracée (presse_article_log).
-- =====================================================================
local P = Presse
local core = exports.elyzea_core
local A = Config.Articles

local CATS = {}
for _, c in ipairs(Config.Categories) do CATS[c.id] = c.label end
local LABEL = { draft = 'Brouillon', pending = 'Soumis', published = 'Publié', rejected = 'Renvoyé', archived = 'Archivé', deleted = 'Retiré' }
P.ArticleStatusLabel = LABEL

-- Titre normalisé (doublons) : minuscules, sans ponctuation ni espaces multiples
function P.TitleKey(t)
    return (tostring(t or ''):lower():gsub('[%p]', ' '):gsub('%s+', ' '):gsub('^ ', ''):gsub(' $', '')):sub(1, 120)
end

function P.ArticleLog(id, src, action, details)
    local cid, name
    if type(src) == 'number' and src > 0 then cid, name = P.Cid(src), P.Name(src) elseif type(src) == 'string' then name = src end
    MySQL.insert('INSERT INTO `presse_article_log` (`article_id`, `action`, `actor_cid`, `actor_name`, `details`) VALUES (?, ?, ?, ?, ?)',
        { id, action, cid, name, details and P.Clean(details, 255) or nil })
end

local function Load(id)
    id = tonumber(id)
    if not id then return nil end
    return MySQL.single.await([[SELECT *, UNIX_TIMESTAMP(`created_at`) AS c_t, UNIX_TIMESTAMP(`updated_at`) AS u_t, UNIX_TIMESTAMP(`published_at`) AS p_t,
        UNIX_TIMESTAMP(`submitted_at`) AS s_t FROM `presse_articles` WHERE `id` = ?]], { id })
end
P.LoadArticle = Load

-- Article de la rédaction du joueur (jamais celui d'une autre rédaction)
local function Mine(src, id)
    local a = Load(id)
    if not a or a.job ~= P.MyJob(src) or a.status == 'deleted' then return nil end
    return a
end

local function IsAuthor(src, a) return a.author_cid == P.Cid(src) end

-- Qui peut modifier l'article (texte) ?
local function CanEdit(src, a)
    if a.status == 'deleted' or a.status == 'archived' then return false end
    if IsAuthor(src, a) then
        if a.status == 'published' then return P.Can(src, 'publish') or P.Can(src, 'edit_any') end
        return P.Can(src, 'write')
    end
    if a.status == 'pending' then return P.Can(src, 'review') end
    if a.status == 'published' then return P.Can(src, 'edit_any') end
    return false   -- brouillon ou renvoyé d'un autre : privé
end

-- Qui peut le voir dans la tablette ?
local function CanView(src, a)
    if IsAuthor(src, a) then return true end
    if a.status == 'published' or a.status == 'archived' then return true end
    if a.status == 'pending' then return P.Can(src, 'review') end
    return false
end

local function DecodeIds(raw)
    local ok, v = pcall(json.decode, raw or '[]')
    local out = {}
    if ok and type(v) == 'table' then for _, id in ipairs(v) do if tonumber(id) then out[#out + 1] = math.floor(tonumber(id)) end end end
    return out
end

-- Médias joints : seulement ceux de la rédaction, sans doublon, limités
local function CleanMedia(job, list)
    local ids, seen = {}, {}
    for _, id in ipairs(type(list) == 'table' and list or {}) do
        id = tonumber(id)
        if id and not seen[id] and #ids < A.maxMedia then seen[id] = true ids[#ids + 1] = math.floor(id) end
    end
    if #ids == 0 then return {} end
    local ok = {}
    for _, r in ipairs(MySQL.query.await(('SELECT `id` FROM `presse_media` WHERE `job` = ? AND `id` IN (%s)'):format(table.concat(ids, ',')), { job }) or {}) do ok[r.id] = true end
    local out = {}
    for _, id in ipairs(ids) do if ok[id] then out[#out + 1] = id end end
    return out
end
P.MediaOf = function(raw)
    local ids = DecodeIds(raw)
    if #ids == 0 then return {} end
    local rows = MySQL.query.await(('SELECT `id`, `kind`, `caption`, `street`, `author_name`, `seconds`, UNIX_TIMESTAMP(`created_at`) AS t FROM `presse_media` WHERE `id` IN (%s)')
        :format(table.concat(ids, ','))) or {}
    local by = {}
    for _, r in ipairs(rows) do by[r.id] = r end
    local out = {}
    for _, id in ipairs(ids) do if by[id] then out[#out + 1] = by[id] end end
    return out
end

-- Titre déjà publié dans la rédaction (hors cet article) ?
local function Duplicate(job, key, exceptId)
    return MySQL.scalar.await([[SELECT `id` FROM `presse_articles` WHERE `job` = ? AND `title_key` = ? AND `id` <> ? AND `status` IN ('published', 'archived')
        AND `published_at` >= DATE_SUB(NOW(), INTERVAL ? DAY) LIMIT 1]], { job, key, exceptId or 0, A.duplicateDays }) ~= nil
end

local function Validate(d)
    local title = P.Clean(tostring(d.title or ''):gsub('%c', ' '), A.titleMax)
    if utf8.len(title) == nil or #title < A.titleMin then return nil, ('Titre trop court (%d caractères au moins).'):format(A.titleMin) end
    local body = P.CleanText(d.body, A.bodyMax)
    if #body < A.bodyMin then return nil, ('Article trop court (%d caractères au moins).'):format(A.bodyMin) end
    local summary = P.CleanText(d.summary, A.summaryMax):gsub('\n', ' ')
    local cat = CATS[tostring(d.category or '')] and tostring(d.category) or Config.Categories[1].id
    return { title = title, key = P.TitleKey(title), body = body, summary = summary ~= '' and summary or nil, category = cat }
end

-- Vue courte (listes)
local function Row(a)
    return { id = a.id, title = a.title, summary = a.summary, category = a.category, status = a.status, author = a.author_name, authorCid = a.author_cid,
        reviewer = a.reviewer_name, note = a.review_note, version = a.version, created = a.c_t, updated = a.u_t, published = a.p_t, submitted = a.s_t }
end

-- ---------------------------------------------------------------------
-- Listes et lecture (tablette)
-- ---------------------------------------------------------------------
local BOX = {
    mine = { where = "`author_cid` = ? AND `status` IN ('draft', 'pending', 'rejected')", mine = true },
    pending = { where = "`status` = 'pending'", perm = 'review' },
    published = { where = "`status` = 'published'" },
    archived = { where = "`status` = 'archived'" },
}

P.Actions.articles = { perm = 'tablet', fn = function(src, d)
    local box = BOX[tostring(d.box or 'published')] or BOX.published
    if box.perm and not P.Can(src, box.perm) then return { error = 'Votre grade ne permet pas de valider les articles.' } end
    local where, args = { '`job` = ?', box.where }, { P.MyJob(src) }
    if box.mine then args[#args + 1] = P.Cid(src) end
    local q = P.Clean(d.q, 60):gsub('[%%_]', '')
    if q ~= '' then
        local like = '%' .. q .. '%'
        where[#where + 1] = '(`title` LIKE ? OR `author_name` LIKE ? OR `summary` LIKE ?)'
        args[#args + 1], args[#args + 2], args[#args + 3] = like, like, like
    end
    local rows = MySQL.query.await(([[SELECT `id`, `title`, `summary`, `category`, `status`, `author_name`, `author_cid`, `reviewer_name`, `review_note`, `version`,
        UNIX_TIMESTAMP(`created_at`) AS c_t, UNIX_TIMESTAMP(`updated_at`) AS u_t, UNIX_TIMESTAMP(`published_at`) AS p_t, UNIX_TIMESTAMP(`submitted_at`) AS s_t
        FROM `presse_articles` WHERE %s ORDER BY COALESCE(`published_at`, `updated_at`) DESC LIMIT 150]]):format(table.concat(where, ' AND ')), args) or {}
    local list = {}
    for _, a in ipairs(rows) do list[#list + 1] = Row(a) end
    return { list = list, box = d.box }
end }

P.Actions.article = { perm = 'tablet', fn = function(src, d)
    local a = Mine(src, d.id)
    if not a or not CanView(src, a) then return { error = 'Article introuvable.' } end
    local v = Row(a)
    v.body, v.media = a.body, P.MediaOf(a.media)
    v.mediaIds = DecodeIds(a.media)
    v.interviewId = a.interview_id
    v.mine = IsAuthor(src, a)
    v.canEdit = CanEdit(src, a)
    v.canSubmit = v.mine and (a.status == 'draft' or a.status == 'rejected') and P.Can(src, 'write')
    v.canPublish = (v.mine and a.status ~= 'published' and P.Can(src, 'publish')) or (not v.mine and a.status == 'pending' and P.Can(src, 'review'))
    v.canReject = not v.mine and a.status == 'pending' and P.Can(src, 'review')
    v.canArchive = (a.status == 'published' or a.status == 'archived') and P.Can(src, 'archive')
    v.canDelete = (v.mine and a.status ~= 'published' and P.Can(src, 'write')) or P.Can(src, 'delete')
    if v.mine or P.Can(src, 'review') then
        v.log = MySQL.query.await([[SELECT `action`, `actor_name`, `details`, UNIX_TIMESTAMP(`created_at`) AS t FROM `presse_article_log`
            WHERE `article_id` = ? ORDER BY `id` DESC LIMIT 30]], { a.id }) or {}
    end
    return { article = v }
end }

-- ---------------------------------------------------------------------
-- Enregistrer (création ou modification)
-- ---------------------------------------------------------------------
local saving = {}
P.Actions.articleSave = { perm = 'write', fn = function(src, d)
    local v, why = Validate(d)
    if not v then return { error = why } end
    local job, cid = P.MyJob(src), P.Cid(src)
    if saving[cid] then return { error = 'Enregistrement déjà en cours.' } end
    saving[cid] = true
    local ok, res = pcall(function()
        local media = json.encode(CleanMedia(job, d.media))
        local iid = tonumber(d.interviewId)
        if iid then
            local row = MySQL.single.await('SELECT `job`, `journalist_cid` FROM `presse_interviews` WHERE `id` = ?', { iid })
            if not row or row.job ~= job or (row.journalist_cid ~= cid and not P.Can(src, 'review')) then iid = nil end
        end
        local id = tonumber(d.id)
        if not id then
            local n = MySQL.scalar.await("SELECT COUNT(*) FROM `presse_articles` WHERE `author_cid` = ? AND `job` = ? AND `status` IN ('draft', 'pending', 'rejected')", { cid, job }) or 0
            if n >= A.maxDrafts then return { error = ('Vous avez déjà %d articles en cours : publiez ou supprimez-en avant d\'en créer un autre.'):format(n) } end
            local newId = MySQL.insert.await([[INSERT INTO `presse_articles` (`job`, `title`, `title_key`, `summary`, `body`, `category`, `status`, `author_cid`, `author_name`, `editor_name`, `interview_id`, `media`)
                VALUES (?, ?, ?, ?, ?, ?, 'draft', ?, ?, ?, ?, ?)]], { job, v.title, v.key, v.summary, v.body, v.category, cid, P.Name(src), P.Name(src), iid, media })
            if not newId then return { error = 'Enregistrement impossible.' } end
            P.ArticleLog(newId, src, 'Création', v.title)
            return { ok = true, id = newId, version = 1, message = 'Brouillon enregistré.' }
        end
        local a = Mine(src, id)
        if not a then return { error = 'Article introuvable.' } end
        if not CanEdit(src, a) then return { error = 'Vous ne pouvez pas modifier cet article.' } end
        if a.status == 'published' and v.key ~= a.title_key and Duplicate(job, v.key, a.id) then
            return { error = 'Un article publié porte déjà ce titre.' }
        end
        local n = MySQL.update.await([[UPDATE `presse_articles` SET `title` = ?, `title_key` = ?, `summary` = ?, `body` = ?, `category` = ?, `interview_id` = ?, `media` = ?,
            `editor_name` = ?, `version` = `version` + 1 WHERE `id` = ? AND `version` = ? AND `status` = ?]],
            { v.title, v.key, v.summary, v.body, v.category, iid, media, P.Name(src), a.id, tonumber(d.version) or -1, a.status })
        if not n or n < 1 then return { error = 'L\'article a été modifié entre-temps (ou son statut a changé) : rechargez-le avant d\'enregistrer.', stale = true } end
        P.ArticleLog(a.id, src, a.status == 'published' and 'Correction (article publié)' or (IsAuthor(src, a) and 'Modification' or 'Correction'), v.title)
        return { ok = true, id = a.id, version = a.version + 1, message = a.status == 'published' and 'Correction publiée.' or 'Article enregistré.' }
    end)
    saving[cid] = nil
    if not ok then print(('^1[PRESSE] Article : %s^0'):format(tostring(res))) return { error = 'Erreur pendant l\'enregistrement.' } end
    return res
end }

-- ---------------------------------------------------------------------
-- Soumettre, publier, renvoyer, archiver, retirer
-- ---------------------------------------------------------------------
-- Change le statut seulement s'il n'a pas changé entre-temps (deux clics, deux validateurs)
local function SetStatus(a, from, to, extra, args)
    local sql = ('UPDATE `presse_articles` SET `status` = ?%s WHERE `id` = ? AND `status` = ?'):format(extra or '')
    local params = { to }
    for _, x in ipairs(args or {}) do params[#params + 1] = x end
    params[#params + 1] = a.id
    params[#params + 1] = from
    local n = MySQL.update.await(sql, params)
    return n and n > 0
end

local function NotifyAuthor(a, msg, kind)
    local s = core:GetSourceByCitizenId(a.author_cid)
    if s then P.Notify(s, msg, kind) end
end

P.Actions.articleSubmit = { perm = 'write', fn = function(src, d)
    local a = Mine(src, d.id)
    if not a or not IsAuthor(src, a) then return { error = 'Article introuvable.' } end
    if a.status ~= 'draft' and a.status ~= 'rejected' then return { error = 'Cet article n\'est pas un brouillon.' } end
    if not SetStatus(a, a.status, 'pending', ', `submitted_at` = NOW(), `review_note` = NULL') then return { error = 'Le statut a changé entre-temps.' } end
    P.ArticleLog(a.id, src, 'Soumis à validation', nil)
    for _, id in ipairs(P.CrewOnDuty('review', a.job)) do
        if id ~= src then P.Notify(id, ('Article à valider : « %s » (%s).'):format(a.title, P.Name(src)), 'inform') end
    end
    return { ok = true, message = 'Article soumis à la validation de la rédaction.' }
end }

local lastPublish, lastAnnounce, publishing = {}, {}, {}

P.Actions.articlePublish = { perm = 'tablet', fn = function(src, d)
    local a = Mine(src, d.id)
    if not a then return { error = 'Article introuvable.' } end
    local own = IsAuthor(src, a)
    if a.status == 'published' then return { error = 'Cet article est déjà publié.' } end
    if a.status == 'archived' then return { error = 'Article archivé : remettez-le en ligne depuis les archives.' } end
    if own then
        if not P.Can(src, 'publish') then return { error = 'Votre grade demande une validation : soumettez l\'article.' } end
    else
        if a.status ~= 'pending' or not P.Can(src, 'review') then return { error = 'Vous ne pouvez pas publier cet article.' } end
    end
    if #tostring(a.body or '') < A.bodyMin or #tostring(a.title or '') < A.titleMin then return { error = 'Article incomplet.' } end
    if Duplicate(a.job, a.title_key, a.id) then return { error = ('Un article portant ce titre a déjà été publié ces %d derniers jours (doublon).'):format(A.duplicateDays) } end
    local now = os.time()
    if lastPublish[a.author_cid] and now - lastPublish[a.author_cid] < A.publishCooldown then
        return { error = ('Patientez %d s avant une nouvelle publication de cet auteur.'):format(A.publishCooldown - (now - lastPublish[a.author_cid])) }
    end
    if publishing[a.id] then return { error = 'Publication déjà en cours.' } end
    publishing[a.id] = true
    local done
    if own then done = SetStatus(a, a.status, 'published', ', `published_at` = NOW(), `reviewer_name` = NULL, `review_note` = NULL')
    else done = SetStatus(a, a.status, 'published', ', `published_at` = NOW(), `reviewer_name` = ?, `review_note` = NULL', { P.Name(src) }) end
    publishing[a.id] = nil
    if not done then return { error = 'Le statut a changé entre-temps.' } end
    lastPublish[a.author_cid] = now
    P.ArticleLog(a.id, src, own and 'Publié' or 'Validé et publié', nil)
    P.Log(src, 'Article publié', ('%s · %s'):format(a.title, P.AgencyLabel(a.job)))
    if not own then NotifyAuthor(a, ('Votre article « %s » est publié.'):format(a.title), 'success') end
    -- Annonce à tout le serveur : seulement si la personne qui publie a le droit de diffuser
    local announced = false
    if Config.Publish.announce and P.Can(src, 'flash') and (not lastAnnounce[a.job] or now - lastAnnounce[a.job] >= Config.Publish.announceCooldown) then
        lastAnnounce[a.job] = now
        announced = true
        if P.Broadcast then P.Broadcast(a.job, 'publish', 'Nouvel article', a.title, P.Name(src)) end
    end
    return { ok = true, message = announced and 'Article publié et annoncé.' or 'Article publié.' }
end }

P.Actions.articleReject = { perm = 'review', fn = function(src, d)
    local a = Mine(src, d.id)
    if not a or a.status ~= 'pending' then return { error = 'Article introuvable ou déjà traité.' } end
    if IsAuthor(src, a) then return { error = 'Vous ne pouvez pas renvoyer votre propre article.' } end
    local note = P.Clean(d.note, 255)
    if #note < 3 then return { error = 'Indiquez à l\'auteur ce qu\'il faut corriger.' } end
    if not SetStatus(a, 'pending', 'rejected', ', `reviewer_name` = ?, `review_note` = ?', { P.Name(src), note }) then return { error = 'Le statut a changé entre-temps.' } end
    P.ArticleLog(a.id, src, 'Renvoyé à l\'auteur', note)
    NotifyAuthor(a, ('Article « %s » renvoyé : %s'):format(a.title, note), 'error')
    return { ok = true, message = 'Article renvoyé à son auteur.' }
end }

P.Actions.articleArchive = { perm = 'archive', fn = function(src, d)
    local a = Mine(src, d.id)
    if not a then return { error = 'Article introuvable.' } end
    local on = d.on ~= false
    if on and a.status ~= 'published' then return { error = 'Seul un article publié s\'archive.' } end
    if not on and a.status ~= 'archived' then return { error = 'Cet article n\'est pas archivé.' } end
    if not SetStatus(a, a.status, on and 'archived' or 'published', on and ', `archived_at` = NOW()' or ', `archived_at` = NULL') then return { error = 'Le statut a changé entre-temps.' } end
    P.ArticleLog(a.id, src, on and 'Archivé' or 'Remis en ligne', nil)
    return { ok = true, message = on and 'Article archivé (toujours lisible dans les archives du journal).' or 'Article remis en ligne.' }
end }

P.Actions.articleDelete = { perm = 'tablet', fn = function(src, d)
    local a = Mine(src, d.id)
    if not a then return { error = 'Article introuvable.' } end
    local own = IsAuthor(src, a)
    local allowed = (own and a.status ~= 'published' and a.status ~= 'archived' and P.Can(src, 'write')) or P.Can(src, 'delete')
    if not allowed then return { error = 'Vous ne pouvez pas retirer cet article.' } end
    local reason = P.Clean(d.reason, 160)
    if not own and #reason < 3 then return { error = 'Indiquez le motif.' } end
    if not SetStatus(a, a.status, 'deleted', ', `deleted_at` = NOW(), `delete_reason` = ?', { reason ~= '' and reason or nil }) then return { error = 'Le statut a changé entre-temps.' } end
    P.ArticleLog(a.id, src, 'Retiré', reason ~= '' and reason or nil)
    P.Log(src, 'Article retiré', ('%s · %s'):format(a.title, reason))
    if not own then NotifyAuthor(a, ('Votre article « %s » a été retiré : %s'):format(a.title, reason), 'error') end
    return { ok = true, message = 'Article retiré.' }
end }

-- ---------------------------------------------------------------------
-- Tableau de bord
-- ---------------------------------------------------------------------
P.Actions.dashboard = { perm = 'tablet', fn = function(src)
    local job, cid = P.MyJob(src), P.Cid(src)
    local counts = {}
    for _, r in ipairs(MySQL.query.await('SELECT `status`, COUNT(*) AS n FROM `presse_articles` WHERE `job` = ? GROUP BY `status`', { job }) or {}) do counts[r.status] = tonumber(r.n) or 0 end
    local mine = {}
    for _, r in ipairs(MySQL.query.await('SELECT `status`, COUNT(*) AS n FROM `presse_articles` WHERE `job` = ? AND `author_cid` = ? GROUP BY `status`', { job, cid }) or {}) do mine[r.status] = tonumber(r.n) or 0 end
    local week = MySQL.scalar.await("SELECT COUNT(*) FROM `presse_articles` WHERE `job` = ? AND `status` IN ('published', 'archived') AND `published_at` >= DATE_SUB(NOW(), INTERVAL 7 DAY)", { job }) or 0
    local last = MySQL.query.await([[SELECT `id`, `title`, `author_name`, `category`, UNIX_TIMESTAMP(`published_at`) AS t FROM `presse_articles`
        WHERE `job` = ? AND `status` = 'published' ORDER BY `published_at` DESC LIMIT 6]], { job }) or {}
    local crew = {}
    for _, id in ipairs(P.CrewOnDuty(nil, job)) do crew[#crew + 1] = P.CrewInfo(id) end
    table.sort(crew, P.SortCrew)
    local e, g = P.Employee(src), P.Grade(src)
    return { counts = counts, mine = mine, week = week, last = last, crew = crew, agency = P.AgencyLabel(job),
        me = { name = P.Name(src), grade = g and g.name or '?', matricule = e and e.matricule or '?', duty = P.OnDuty(src), status = P.status[src] or 'available', times = P.MyTimes(src) },
        interview = P.ActiveInterviewOf and P.ActiveInterviewOf(src) or nil }
end }

-- ---------------------------------------------------------------------
-- Journal public (tous les joueurs) : articles publiés de toutes les rédactions
-- ---------------------------------------------------------------------
P.PubActions.news = { fn = function(src, d)
    if not P.NearKiosk(src) then return { error = 'Consultez le journal à un présentoir.' } end
    local where, args = { "`status` = ?" }, { d.archives == true and 'archived' or 'published' }
    local job = tostring(d.job or '')
    if job ~= '' and P.agencies[job] then where[#where + 1] = '`job` = ?' args[#args + 1] = job end
    local cat = tostring(d.category or '')
    if CATS[cat] then where[#where + 1] = '`category` = ?' args[#args + 1] = cat end
    local q = P.Clean(d.q, 60):gsub('[%%_]', '')
    if q ~= '' then
        local like = '%' .. q .. '%'
        where[#where + 1] = '(`title` LIKE ? OR `summary` LIKE ? OR `author_name` LIKE ?)'
        args[#args + 1], args[#args + 2], args[#args + 3] = like, like, like
    end
    local page = P.Int(d.page, 0, 500, 0)
    args[#args + 1] = A.readerPage + 1
    args[#args + 1] = page * A.readerPage
    local rows = MySQL.query.await(([[SELECT `id`, `job`, `title`, `summary`, `category`, `author_name`, UNIX_TIMESTAMP(`published_at`) AS t
        FROM `presse_articles` WHERE %s ORDER BY `published_at` DESC LIMIT ? OFFSET ?]]):format(table.concat(where, ' AND ')), args) or {}
    local more = #rows > A.readerPage
    if more then rows[#rows] = nil end
    for _, r in ipairs(rows) do
        local ag = P.agencies[r.job]
        r.agency, r.color = ag and ag.label or r.job, ag and ag.color or nil
    end
    local agencies = {}
    for _, a in ipairs(P.agencyList) do agencies[#agencies + 1] = { job = a.job, label = a.label, color = a.color } end
    return { list = rows, more = more, page = page, agencies = agencies, categories = Config.Categories, staff = P.IsStaff(src),
        ads = P.ActiveAds and P.ActiveAds() or {} }
end }

P.PubActions.newsGet = { fn = function(src, d)
    if not P.NearKiosk(src) then return { error = 'Consultez le journal à un présentoir.' } end
    local a = Load(d.id)
    if not a or (a.status ~= 'published' and a.status ~= 'archived') then return { error = 'Article introuvable ou retiré.' } end
    local ag = P.agencies[a.job]
    return { article = { id = a.id, title = a.title, summary = a.summary, body = a.body, category = a.category, author = a.author_name, reviewer = a.reviewer_name,
        published = a.p_t, updated = a.u_t, archived = a.status == 'archived', agency = ag and ag.label or a.job, color = ag and ag.color or nil, media = P.MediaOf(a.media) },
        staff = P.IsStaff(src) }
end }

-- Staff : retirer un article de n'importe quelle rédaction
P.PubActions.modArticle = { staff = true, fn = function(src, d)
    local a = Load(d.id)
    if not a or a.status == 'deleted' then return { error = 'Article introuvable.' } end
    local reason = P.Clean(d.reason, 160)
    if #reason < 3 then return { error = 'Indiquez le motif.' } end
    if not SetStatus(a, a.status, 'deleted', ', `deleted_at` = NOW(), `delete_reason` = ?', { 'Staff : ' .. reason }) then return { error = 'Le statut a changé entre-temps.' } end
    P.ArticleLog(a.id, ('Staff · %s'):format(GetPlayerName(src) or '?'), 'Retiré par le staff', reason)
    P.Log(src, 'Staff : article retiré', ('%s · %s'):format(a.title, reason))
    NotifyAuthor(a, ('Votre article « %s » a été retiré par le staff : %s'):format(a.title, reason), 'error')
    return { ok = true, message = 'Article retiré du journal.' }
end }

-- Archivage automatique des vieux articles
CreateThread(function()
    while true do
        Wait(30 * 60000)
        if P.ready and (A.autoArchiveDays or 0) > 0 then
            pcall(MySQL.update.await, "UPDATE `presse_articles` SET `status` = 'archived', `archived_at` = NOW() WHERE `status` = 'published' AND `published_at` < DATE_SUB(NOW(), INTERVAL ? DAY)",
                { A.autoArchiveDays })
        end
    end
end)

AddEventHandler('playerDropped', function() local cid = P.Cid(source) if cid then saving[cid] = nil end end)
