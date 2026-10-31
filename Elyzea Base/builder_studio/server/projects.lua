-- =========================================================
--  BUILDER STUDIO - PROJETS ET OPÉRATIONS (serveur, autorité)
--  Toute modification passe par Projects.apply() : permissions ACE,
--  verrous, limites, validation des données. Le client n'est jamais cru.
-- =========================================================
Projects = { loaded = {}, index = nil, dims = {}, custom = {}, pieceCount = {}, dirty = {}, lastVersion = {} }
local L = Config.Limits

-- ---------------------------------------------------------
--  Permissions
-- ---------------------------------------------------------
Perm = {}
-- Permission staff d'admin_menu (export HasPermission), sans erreur si admin_menu est arrêté
local function adminMenu(src, perm)
    local am = Config.AdminMenu
    if not am or not am.enabled or not perm or GetResourceState(am.resource) ~= 'started' then return false end
    local ok, res = pcall(function() return exports[am.resource]:HasPermission(src, perm) end)
    return ok and res == true
end
Perm.adminMenu = adminMenu
function Perm.has(src, key)
    if src == 0 then return true end
    local ace = Config.Ace[key]
    if not ace then return false end
    local am = Config.AdminMenu
    if am and am.enabled and (adminMenu(src, am.all) or adminMenu(src, am.perms[key])) then return true end
    return IsPlayerAceAllowed(src, ace) or IsPlayerAceAllowed(src, Config.Ace.admin)
end
function Perm.all(src)
    local out = {}
    for k in pairs(Config.Ace) do out[k] = Perm.has(src, k) end
    return out
end
local function ownerOf(src)
    if src == 0 then return 'console' end
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:find('^license:') then return id end
    end
    return 'joueur:' .. tostring(src)
end
Perm.ownerOf = ownerOf
local function nameOf(src)
    if src == 0 then return 'Console' end
    return GetPlayerName(src) or ('Joueur ' .. src)
end
Perm.nameOf = nameOf

-- Le propriétaire ou un admin peut supprimer / gérer un projet
function Perm.canManage(src, p)
    return src == 0 or Perm.has(src, 'admin') or p.owner == ownerOf(src)
end

-- ---------------------------------------------------------
--  Chargement
-- ---------------------------------------------------------
function Projects.init()
    Projects.index = Store.loadIndex()
    Projects.dims = Store.loadDims()
    Projects.custom = Store.loadCustom()
end

-- Dimensions connues (kit vanilla) pour le calcul serveur des pièces
function Projects.measured(model)
    local d = Projects.dims[model]
    if d and d.min and d.max then return d end
    return nil
end

local function ctx() return { measured = Projects.measured } end
Projects.ctx = ctx

function Projects.get(id)
    if type(id) ~= 'string' or not BSchema.id(id) then return nil end
    local p = Projects.loaded[id]
    if p then return p end
    if not Projects.index.projects[id] then return nil end
    p = Store.loadProject(id)
    if p then
        Projects.loaded[id] = p
        Projects.recount(p)
    end
    return p
end

function Projects.recount(p)
    local counts, total = {}, 0
    local c = ctx()
    for id, el in pairs(p.elements) do
        local n = #BGeo.pieces(el, c)
        counts[id] = n
        total = total + n
    end
    Projects.pieceCount[p.id] = { per = counts, total = total }
end

function Projects.summary(p)
    local n = 0
    for _ in pairs(p.elements) do n = n + 1 end
    local pc = Projects.pieceCount[p.id]
    return {
        id = p.id, name = p.name, owner = p.owner, ownerName = p.ownerName, updated = p.updated, created = p.created,
        active = p.active == true, elements = n, pieces = pc and pc.total or 0, origin = p.origin,
        versions = (Projects.index.projects[p.id] or {}).versions or {},
    }
end

function Projects.list()
    local out = {}
    for id, e in pairs(Projects.index.projects) do
        out[#out + 1] = {
            id = id, name = e.name, owner = e.owner, ownerName = e.ownerName, updated = e.updated, active = e.active == true,
            elements = e.elements or 0, pieces = e.pieces or 0, versions = e.versions or {}, origin = e.origin,
        }
    end
    table.sort(out, function(a, b) return (a.updated or 0) > (b.updated or 0) end)
    return out
end

local function touchIndex(p)
    local s = Projects.summary(p)
    local e = Projects.index.projects[p.id] or {}
    e.name, e.owner, e.ownerName, e.updated, e.active = s.name, s.owner, s.ownerName, s.updated, s.active
    e.elements, e.pieces, e.origin = s.elements, s.pieces, s.origin
    e.versions = e.versions or {}
    Projects.index.projects[p.id] = e
end
Projects.touchIndex = touchIndex

function Projects.markDirty(p)
    p.updated = os.time()
    Projects.dirty[p.id] = true
    touchIndex(p)
end

function Projects.saveNow(id)
    local p = Projects.loaded[id]
    if not p then return false end
    local ok = Store.saveProject(p)
    if ok then Projects.dirty[id] = nil end
    Store.saveIndex(Projects.index)
    return ok
end

function Projects.flush()
    for id in pairs(Projects.dirty) do Projects.saveNow(id) end
    Store.saveIndex(Projects.index)
end

-- ---------------------------------------------------------
--  Projets : création, renommage, duplication, suppression
-- ---------------------------------------------------------
local function newProjectId()
    return ('p%d%04d'):format(os.time(), math.random(0, 9999))
end

function Projects.create(src, name, origin)
    if not Perm.has(src, 'build') then return nil, 'Permission refusée (construction).' end
    local n = 0
    for _ in pairs(Projects.index.projects) do n = n + 1 end
    if n >= L.maxProjects then return nil, 'Nombre maximal de projets atteint.' end
    local id = newProjectId()
    while Projects.index.projects[id] do id = newProjectId() end
    local p = BSchema.newProject(id, name, ownerOf(src), origin)
    p.ownerName = nameOf(src)
    Projects.loaded[id] = p
    Projects.pieceCount[id] = { per = {}, total = 0 }
    Projects.markDirty(p)
    Projects.log(p, src, 'Création du projet', 0)
    Projects.saveNow(id)
    return p
end

function Projects.rename(src, id, name)
    local p = Projects.get(id)
    if not p then return nil, 'Projet introuvable.' end
    if not Perm.has(src, 'edit') then return nil, 'Permission refusée (modification).' end
    local clean = BSchema.text(name, 48)
    if not clean or clean == '' then return nil, 'Nom invalide.' end
    p.name = clean
    Projects.markDirty(p)
    Projects.log(p, src, 'Renommé en « ' .. clean .. ' »', 0)
    return p
end

function Projects.duplicate(src, id, name)
    local p = Projects.get(id)
    if not p then return nil, 'Projet introuvable.' end
    local copy, err = Projects.create(src, name or (p.name .. ' (copie)'), p.origin)
    if not copy then return nil, err end
    copy.elements = BCompose.deepcopy(p.elements)
    copy.textures = BCompose.deepcopy(p.textures)
    copy.meta = BCompose.deepcopy(p.meta)
    Projects.recount(copy)
    Projects.markDirty(copy)
    Projects.log(copy, src, 'Dupliqué depuis « ' .. p.name .. ' »', 0)
    Projects.saveNow(copy.id)
    return copy
end

function Projects.delete(src, id)
    local p = Projects.get(id)
    if not p then return nil, 'Projet introuvable.' end
    if not Perm.has(src, 'delete') then return nil, 'Permission refusée (suppression).' end
    if not Perm.canManage(src, p) then return nil, 'Seul le propriétaire ou un admin peut supprimer ce projet.' end
    for _, v in ipairs((Projects.index.projects[id] or {}).versions or {}) do Store.deleteVersion(id, v.n) end
    Projects.index.projects[id] = nil
    Projects.loaded[id] = nil
    Projects.pieceCount[id] = nil
    Projects.dirty[id] = nil
    Store.deleteProject(id)
    Store.saveIndex(Projects.index)
    return true
end

function Projects.setActive(src, id, active)
    local p = Projects.get(id)
    if not p then return nil, 'Projet introuvable.' end
    if not Perm.has(src, 'edit') then return nil, 'Permission refusée (modification).' end
    p.active = active == true
    Projects.markDirty(p)
    Projects.log(p, src, p.active and 'Publié en jeu (visible par tous)' or 'Retiré du jeu', 0)
    return p
end

-- ---------------------------------------------------------
--  Historique et points de restauration
-- ---------------------------------------------------------
function Projects.log(p, src, label, count)
    p.history = p.history or {}
    p.history[#p.history + 1] = { t = os.time(), by = nameOf(src), label = label, n = count or 0 }
    while #p.history > L.maxHistory do table.remove(p.history, 1) end
end

function Projects.snapshot(src, id, label, auto)
    local p = Projects.get(id)
    if not p then return nil, 'Projet introuvable.' end
    if not auto and not Perm.has(src, 'build') then return nil, 'Permission refusée.' end
    local e = Projects.index.projects[id]
    e.versions = e.versions or {}
    local n = 1
    for _, v in ipairs(e.versions) do if v.n >= n then n = v.n + 1 end end
    if not Store.saveVersion(id, n, p) then return nil, 'Écriture du point de restauration impossible.' end
    local s = Projects.summary(p)
    e.versions[#e.versions + 1] = { n = n, t = os.time(), label = BSchema.text(label, 48) or 'Point de restauration', by = nameOf(src), elements = s.elements, auto = auto or nil }
    -- on garde les plus récents
    while #e.versions > L.maxVersionsPerProject do
        local old = table.remove(e.versions, 1)
        Store.deleteVersion(id, old.n)
    end
    Projects.lastVersion[id] = os.time()
    Store.saveIndex(Projects.index)
    return n
end

function Projects.restore(src, id, n)
    local p = Projects.get(id)
    if not p then return nil, 'Projet introuvable.' end
    if not Perm.has(src, 'edit') then return nil, 'Permission refusée (modification).' end
    local found
    for _, v in ipairs((Projects.index.projects[id] or {}).versions or {}) do if v.n == n then found = v end end
    if not found then return nil, 'Point de restauration introuvable.' end
    local old = Store.loadVersion(id, n)
    if not old then return nil, 'Fichier du point de restauration illisible.' end
    Projects.snapshot(src, id, 'Avant restauration', true)
    p.elements = old.elements or {}
    p.textures = old.textures or {}
    p.origin = old.origin or p.origin
    Projects.recount(p)
    Projects.markDirty(p)
    Projects.log(p, src, ('Restauration du point n°%d (%s)'):format(n, found.label or ''), 0)
    return p
end

-- ---------------------------------------------------------
--  Opérations sur les éléments
--  op = { kind = 'add', elements = {...} }
--     | { kind = 'update', elements = {...} }   (éléments complets)
--     | { kind = 'remove', ids = {...} }        (les enfants des groupes suivent)
--     | { kind = 'batch', ops = {...} }
-- ---------------------------------------------------------
local function deepEqual(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
Projects.deepEqual = deepEqual

local function withoutLock(e)
    local c = {}
    for k, v in pairs(e) do if k ~= 'locked' then c[k] = v end end
    return c
end

-- Vérifie et prépare une opération sur un état de travail (copie)
local function check(src, p, work, op, out, counts)
    if type(op) ~= 'table' then return 'opération invalide' end
    local c = ctx()
    if op.kind == 'add' then
        if not Perm.has(src, 'build') then return 'Permission refusée (construction).' end
        if type(op.elements) ~= 'table' then return 'liste vide' end
        for _, raw in ipairs(op.elements) do
            local el, err = BSchema.element(raw)
            if not el then return err end
            if work[el.id] then return 'identifiant déjà utilisé : ' .. el.id end
            if el.parent and not work[el.parent] then el.parent = nil end
            work[el.id] = el
            local n = #BGeo.pieces(el, c)
            counts.total = counts.total + n
            counts.per[el.id] = n
            out.elements[#out.elements + 1] = el
        end
    elseif op.kind == 'update' then
        if not Perm.has(src, 'edit') then return 'Permission refusée (modification).' end
        if type(op.elements) ~= 'table' then return 'liste vide' end
        for _, raw in ipairs(op.elements) do
            local el, err = BSchema.element(raw)
            if not el then return err end
            local old = work[el.id]
            if not old then return 'élément introuvable : ' .. el.id end
            if old.locked and el.locked then return ('« %s » est verrouillé.'):format(old.name or el.id) end
            if old.locked and not deepEqual(withoutLock(old), withoutLock(el)) then
                return ('« %s » est verrouillé : déverrouille-le d\'abord.'):format(old.name or el.id)
            end
            if el.parent then
                if not work[el.parent] or el.parent == el.id then el.parent = nil end
                -- pas de boucle dans la hiérarchie
                local cur, guard = el.parent, 0
                while cur and guard < 200 do
                    if cur == el.id then return 'hiérarchie en boucle' end
                    cur = work[cur] and work[cur].parent
                    guard = guard + 1
                end
            end
            work[el.id] = el
            local n = #BGeo.pieces(el, c)
            counts.total = counts.total - (counts.per[el.id] or 0) + n
            counts.per[el.id] = n
            out.elements[#out.elements + 1] = el
        end
    elseif op.kind == 'remove' then
        if not Perm.has(src, 'delete') then return 'Permission refusée (suppression).' end
        if type(op.ids) ~= 'table' then return 'liste vide' end
        local all = {}
        for _, id in ipairs(op.ids) do
            if type(id) == 'string' and work[id] then
                all[#all + 1] = id
                for _, d in ipairs(BCompose.descendants(work, id)) do all[#all + 1] = d end
            end
        end
        for _, id in ipairs(all) do
            local e = work[id]
            if e then
                if e.locked then return ('« %s » est verrouillé.'):format(e.name or id) end
                work[id] = nil
                counts.total = counts.total - (counts.per[id] or 0)
                counts.per[id] = nil
                out.ids[#out.ids + 1] = id
            end
        end
    else
        return 'type d\'opération inconnu'
    end
    return nil
end

function Projects.apply(src, id, op)
    local p = Projects.get(id)
    if not p then return nil, 'Projet introuvable.' end
    if not Perm.has(src, 'access') then return nil, 'Permission refusée.' end
    local list = (type(op) == 'table' and op.kind == 'batch') and op.ops or { op }
    if type(list) ~= 'table' or #list == 0 then return nil, 'opération vide' end
    local size = 0
    for _, o in ipairs(list) do
        if type(o) ~= 'table' then return nil, 'opération invalide' end
        size = size + #(o.elements or o.ids or {})
    end
    if size > L.maxElementsPerOp then return nil, ('Trop d\'éléments en une fois (%d, max %d).'):format(size, L.maxElementsPerOp) end

    -- état de travail : on n'applique que si TOUT est valide
    local work = {}
    for k, v in pairs(p.elements) do work[k] = v end
    local pc = Projects.pieceCount[p.id] or { per = {}, total = 0 }
    local counts = { total = pc.total, per = {} }
    for k, v in pairs(pc.per) do counts.per[k] = v end
    local results = {}
    for _, o in ipairs(list) do
        local out = { kind = o.kind, elements = {}, ids = {} }
        local err = check(src, p, work, o, out, counts)
        if err then return nil, err end
        results[#results + 1] = out
    end
    local n = 0
    for _ in pairs(work) do n = n + 1 end
    if n > L.maxElementsPerProject then return nil, ('Limite d\'éléments du projet atteinte (%d).'):format(L.maxElementsPerProject) end
    if counts.total > L.maxPiecesPerProject then
        return nil, ('Limite de modules du projet atteinte (%d / %d).'):format(counts.total, L.maxPiecesPerProject)
    end
    p.elements = work
    Projects.pieceCount[p.id] = counts
    Projects.markDirty(p)
    local labels = { add = 'Ajout', update = 'Modification', remove = 'Suppression' }
    for _, r in ipairs(results) do
        local cnt = #r.elements + #r.ids
        local first = r.elements[1]
        Projects.log(p, src, (labels[r.kind] or r.kind) .. (first and (' : ' .. (first.name or first.type)) or ''), cnt)
    end
    return { kind = 'batch', ops = results }
end

-- Dimensions mesurées envoyées par un client (kit vanilla)
function Projects.reportDims(src, list)
    if not Perm.has(src, 'access') or type(list) ~= 'table' then return end
    local changed = false
    local n = 0
    for model, d in pairs(list) do
        n = n + 1
        if n > 200 then break end
        if BSchema.model(model) and type(d) == 'table' and type(d.min) == 'table' and type(d.max) == 'table' and not Projects.dims[model] then
            local ok = true
            for _, ax in ipairs({ 'x', 'y', 'z' }) do
                local a, b = tonumber(d.min[ax]), tonumber(d.max[ax])
                if not a or not b or b - a <= 0 or b - a > 300 or a ~= a or b ~= b then ok = false end
            end
            if ok then
                Projects.dims[model] = {
                    min = { x = d.min.x, y = d.min.y, z = d.min.z },
                    max = { x = d.max.x, y = d.max.y, z = d.max.z },
                }
                changed = true
            end
        end
    end
    if changed then Store.saveDims(Projects.dims) end
    return changed
end

-- Objets personnalisés du catalogue
function Projects.addCustom(src, item)
    if not Perm.has(src, 'import') then return nil, 'Permission refusée (importation).' end
    if type(item) ~= 'table' or not BSchema.model(item.model) then return nil, 'Nom de modèle invalide.' end
    for _, it in ipairs(Projects.custom) do if it.model == item.model then return nil, 'Déjà dans le catalogue.' end end
    if #Projects.custom >= 2000 then return nil, 'Catalogue personnalisé plein.' end
    local entry = {
        model = item.model, label = BSchema.text(item.label, 48) or item.model, cat = 'custom',
        type = item.type == 'vehicle' and 'vehicle' or 'prop', by = nameOf(src), t = os.time(),
    }
    Projects.custom[#Projects.custom + 1] = entry
    Store.saveCustom(Projects.custom)
    return entry
end

function Projects.removeCustom(src, model)
    if not Perm.has(src, 'import') then return nil, 'Permission refusée (importation).' end
    for i, it in ipairs(Projects.custom) do
        if it.model == model then
            table.remove(Projects.custom, i)
            Store.saveCustom(Projects.custom)
            return true
        end
    end
    return nil, 'Introuvable.'
end

-- Remplacement de textures (vraie fonction du moteur : AddReplaceTexture)
-- entry = { txd, txn, file }   file = image dans textures/custom/ (déclarée dans fxmanifest)
function Projects.setTextures(src, id, list)
    local p = Projects.get(id)
    if not p then return nil, 'Projet introuvable.' end
    if not Perm.has(src, 'import') then return nil, 'Permission refusée (importation).' end
    if type(list) ~= 'table' or #list > 64 then return nil, 'Liste invalide.' end
    local clean = {}
    local seen = {}
    for _, t in ipairs(list) do
        if type(t) == 'table' and BSchema.model(t.txd) and BSchema.model(t.txn) then
            local key = t.txd .. '|' .. t.txn
            if seen[key] then return nil, ('Texture visée deux fois : %s / %s'):format(t.txd, t.txn) end
            seen[key] = true
            if type(t.tex) == 'string' and t.tex ~= '' then
                -- Texture de la bibliothèque (importée en jeu : image du PC ou lien)
                local e = Textures and Textures.get(t.tex)
                if not e then return nil, 'Texture introuvable dans la bibliothèque.' end
                clean[#clean + 1] = { txd = t.txd, txn = t.txn, tex = e.id, url = e.url, w = e.w, h = e.h, name = e.name }
            elseif type(t.file) == 'string' and t.file:match('^[%w_%-]+%.png$') then
                -- Ancienne méthode : PNG posé dans textures/custom/ (déclaré dans fxmanifest)
                local raw = LoadResourceFile(GetCurrentResourceName(), 'textures/custom/' .. t.file)
                if not raw then return nil, ('Image introuvable : textures/custom/%s'):format(t.file) end
                clean[#clean + 1] = { txd = t.txd, txn = t.txn, file = t.file }
            end
        end
    end
    p.textures = clean
    Projects.markDirty(p)
    Projects.log(p, src, ('Textures personnalisées : %d remplacement(s)'):format(#clean), #clean)
    return p
end

return Projects
