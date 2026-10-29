-- =====================================================================
--  ELYZEA BOÎTE DE NUIT - serveur : administration (staff)
--  Accès : admin_menu, permission « club_manage » (vérifiée à chaque requête).
--  · Créer plusieurs boîtes (chacune : métier, compte de société, grades, matricules).
--  · Points : entrée, intérieur (facultatif), bar, coffre, bureau (tablette).
--  · Nommer le patron, ouvrir / fermer, supprimer (désactivation : finances et
--    historiques gardés), retirer une enceinte, couper la musique.
-- =====================================================================
local P = Club
local core = exports.elyzea_core

local function Log(src, action, details)
    if GetResourceState('admin_menu') == 'started' and type(src) == 'number' then
        pcall(function() exports.admin_menu:AddLog(src, '[Boîte de nuit] ' .. action, details or '') end)
    else
        print(('^5[CLUB]^7 %s | %s'):format(action, details or ''))
    end
end

local function StaffPos(src)
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    local r2 = function(v) return math.floor(v * 100 + 0.5) / 100 end
    return { x = r2(c.x), y = r2(c.y), z = r2(c.z), h = r2(GetEntityHeading(ped)) }
end

local function ShopView(D)
    local emp = 0
    for _ in pairs(P.ShopEmployees(D.id)) do emp = emp + 1 end
    local m = GlobalState.clubMusic and GlobalState.clubMusic[tostring(D.id)]
    return { id = D.id, name = D.name, address = D.address, job = D.job, jobLabel = D.jobLabel, society = D.society, matPrefix = D.matPrefix,
        enabled = D.enabled, deleted = D.deleted, options = D.options, points = D.points, employees = emp, balance = P.Balance(D),
        publicOpen = P.PublicOpen(D), fee = P.EntryFee(D), speakers = P.SpeakerList(D.id), tracks = #(P.tracks[D.id] or {}),
        music = m and { title = m.title, paused = m.paused } or nil }
end

P.Admin.data = { fn = function()
    local shops = {}
    for _, D in pairs(P.shops) do if not D.deleted then shops[#shops + 1] = ShopView(D) end end
    table.sort(shops, function(a, c) return a.id < c.id end)
    local grades = {}
    for _, D in pairs(P.shops) do
        local list = {}
        for _, g in ipairs(P.SortedGrades(D.id)) do list[#list + 1] = { id = g.id, name = g.name, level = g.level } end
        grades[tostring(D.id)] = list
    end
    return { shops = shops, grades = grades }
end }

-- ---------------------------------------------------------------------
-- Boîtes
-- ---------------------------------------------------------------------
local function ValidJob(job, exceptId)
    job = tostring(job or ''):lower():gsub('[^%w_]', ''):sub(1, 40)
    if #job < 3 then return nil, 'Nom de métier invalide (3 à 40 caractères : lettres, chiffres, _).' end
    for _, D in pairs(P.shops) do if D.id ~= exceptId and D.job == job and not D.deleted then return nil, ('Le métier « %s » est déjà utilisé par « %s ».'):format(job, D.name) end end
    if job == 'unemployed' then return nil, 'Nom de métier réservé.' end
    local existing = core:GetJob(job)
    if existing and not exceptId and not P.GetSetting('ownJobs', {})[job] then
        return nil, ('Le métier « %s » existe déjà dans elyzea_core (autre script) : choisissez un autre nom.'):format(job)
    end
    return job
end

P.Admin.shopSave = { fn = function(src, d)
    local id = tonumber(d.id)
    local D = id and P.shops[id]
    if id and (not D or D.deleted) then return { error = 'Boîte introuvable.' } end
    local name = P.Clean(d.name, 80)
    if #name < 2 then return { error = 'Nom trop court.' } end
    local job, why = ValidJob(d.job ~= nil and d.job ~= '' and d.job or (D and D.job) or ('club_' .. name:lower():gsub('[^%w]', ''):sub(1, 20)), id)
    if not job then return { error = why } end
    if D and D.job ~= job then
        for _ in pairs(P.ShopEmployees(D.id)) do return { error = 'Des employés ont le métier actuel : retirez-les avant de changer le nom du métier.' } end
    end
    local society = tostring(d.society or ''):lower():gsub('[^%w_]', ''):sub(1, 40)
    if society == '' then society = job end
    local prefix = P.Clean(d.matPrefix, 8):upper()
    if prefix == '' then prefix = 'BN-' end
    local opts = D and D.options or { publicOpen = false, entryFee = Config.Entry.defaultFee }
    opts.requireDuty = d.requireDuty ~= false
    opts.blip = d.blip ~= false
    opts.blipSprite = P.Int(d.blipSprite, 1, 900, opts.blipSprite or 614)
    opts.blipColor = P.Int(d.blipColor, 0, 85, opts.blipColor or 27)
    local address, jobLabel = P.Clean(d.address, 120), P.Clean(d.jobLabel, 60)
    if jobLabel == '' then jobLabel = name end
    if D then
        D.name, D.address, D.job, D.jobLabel, D.society, D.matPrefix, D.options = name, address, job, jobLabel, society, prefix, opts
        P.SaveShop(D)
        Log(src, 'Boîte modifiée', ('%s · métier %s · compte %s'):format(name, job, society))
    else
        id = MySQL.insert.await([[INSERT INTO `cl_shops` (`name`, `address`, `job`, `job_label`, `society`, `mat_prefix`, `enabled`, `points`, `options`, `created_by`)
            VALUES (?, ?, ?, ?, ?, ?, 0, '{}', ?, ?)]], { name, address, job, jobLabel, society, prefix, json.encode(opts), P.Name(src) })
        if not id then return { error = 'Création impossible.' } end
        D = { id = id, name = name, address = address, job = job, jobLabel = jobLabel, society = society, matPrefix = prefix, enabled = false, deleted = false, points = {}, options = opts }
        P.shops[id] = D
        local own = P.GetSetting('ownJobs', {})
        own[job] = true
        P.SetSetting('ownJobs', own)
        P.SeedGrades(id)
        P.SeedMenu(D)
        Log(src, 'Boîte créée', ('%s · métier %s · compte %s'):format(name, job, society))
    end
    pcall(function() core:GetSocietyMoney(society) end)
    P.SyncCoreJob(D)
    P.RegisterStash(D)
    P.Touch()
    P.PushShop(D.id)
    return { ok = true, id = D.id, message = tonumber(d.id) and 'Boîte enregistrée.' or 'Boîte créée (fermée tant que vous ne l\'activez pas). Placez ses points puis nommez le patron.' }
end }

P.Admin.shopEnable = { fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D or D.deleted then return { error = 'Boîte introuvable.' } end
    local on = d.enabled == true
    if on and not D.points.door then return { error = 'Placez d\'abord le point Entrée.' } end
    if on and not D.points.bar then return { error = 'Placez d\'abord le point Bar.' } end
    D.enabled = on
    P.SaveShop(D)
    if not on then P.MusicShopClosed(D.id) end
    Log(src, on and 'Boîte activée' or 'Boîte désactivée', D.name)
    P.Touch()
    P.PushShop(D.id)
    P.PublishMusic()
    return { ok = true, message = on and 'Boîte activée : le patron peut l\'ouvrir au public.' or 'Boîte désactivée par le staff : entrée, bar et musique suspendus (rien n\'est supprimé).' }
end }

P.Admin.shopDelete = { fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D or D.deleted then return { error = 'Boîte introuvable.' } end
    if d.confirm ~= D.name then return { error = 'Confirmation incorrecte : tapez exactement le nom de la boîte.' } end
    local n = 0
    for cid in pairs(P.ShopEmployees(D.id)) do P.Remove(cid) n = n + 1 end
    P.MusicShopClosed(D.id)
    D.enabled, D.deleted = false, true
    P.SaveShop(D)
    -- Les enceintes disparaissent de la ville (gardées en base, avec l'historique)
    P.speakers[D.id] = {}
    pcall(function() core:RemoveJob(D.job) end)
    local own = P.GetSetting('ownJobs', {})
    own[D.job] = nil
    P.SetSetting('ownJobs', own)
    Log(src, 'Boîte supprimée', ('%s · %d employé(s) retiré(s) du métier'):format(D.name, n))
    P.Touch()
    P.PublishMusic()
    return { ok = true, message = ('« %s » supprimée : %d employé(s) retiré(s). Les ventes et les finances sont conservées.'):format(D.name, n) }
end }

P.Admin.setBoss = { fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D or D.deleted then return { error = 'Boîte introuvable.' } end
    local t = tonumber(d.target)
    local cid = t and P.Cid(t)
    if not cid then return { error = 'Joueur introuvable (ID serveur).' } end
    local top = P.TopGrade(D.id)
    if not top then return { error = 'Aucun grade dans cette boîte.' } end
    local cur = P.employees[cid]
    if cur and cur.shop_id ~= D.id then return { error = 'Ce joueur travaille dans une autre boîte : il doit d\'abord la quitter.' } end
    if cur then P.ApplyGrade(cid, top) else
        local ok, why = P.Hire(D, cid, P.Name(t), top)
        if not ok then return { error = why } end
    end
    P.AddLog(D.id, src, cid, P.Name(t), 'Nommé par le staff', nil, top.name, nil)
    Log(src, 'Patron nommé', ('%s · %s (%s)'):format(D.name, P.Name(t), top.name))
    P.Notify(t, ('Vous êtes %s de %s.'):format(top.name, D.name), 'success')
    return { ok = true, message = ('%s est maintenant %s de %s.'):format(P.Name(t), top.name, D.name) }
end }

-- ---------------------------------------------------------------------
-- Points
-- ---------------------------------------------------------------------
local KEYS = { door = 'Entrée', inside = 'Intérieur (après l\'entrée)', bar = 'Bar', stash = 'Coffre', manage = 'Bureau (tablette)' }
P.Admin.point = { fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D or D.deleted then return { error = 'Boîte introuvable.' } end
    local key = tostring(d.key or '')
    if not KEYS[key] then return { error = 'Point inconnu.' } end
    D.points = D.points or {}
    if d.remove then
        if key == 'door' and D.enabled then return { error = 'Désactivez la boîte avant de retirer son entrée.' } end
        if key == 'bar' and D.enabled then return { error = 'Désactivez la boîte avant de retirer son bar.' } end
        D.points[key] = nil
    else
        local p = StaffPos(src)
        p.r = math.max(0.6, math.min(10.0, tonumber(d.r) or (D.points[key] and D.points[key].r) or Config.Points.defaultRadius))
        p.on = true
        D.points[key] = p
    end
    P.SaveShop(D)
    Log(src, d.remove and 'Point retiré' or 'Point placé', ('%s · %s'):format(D.name, KEYS[key]))
    P.Touch()
    return { ok = true, message = d.remove and 'Point retiré.' or ('%s placé à votre position (orientation comprise).'):format(KEYS[key]) }
end }

P.Admin.teleport = { fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D then return { error = 'Boîte introuvable.' } end
    local pt
    if d.key == 'speaker' then pt = (P.speakers[D.id] or {})[tonumber(d.speaker) or -1]
    else pt = D.points[tostring(d.key or '')] end
    if not pt then return { error = 'Point non placé.' } end
    SetEntityCoords(GetPlayerPed(src), pt.x + 0.0, pt.y + 0.0, pt.z + (d.key == 'speaker' and 1.0 or 0.0), false, false, false, false)
    return { ok = true, message = 'Téléporté.' }
end }

P.Admin.speakerRemove = { fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    local id = tonumber(d.speaker) or -1
    local s = D and (P.speakers[D.id] or {})[id]
    if not s then return { error = 'Enceinte introuvable.' } end
    P.speakers[D.id][id] = nil
    MySQL.update.await('DELETE FROM `cl_speakers` WHERE `id` = ?', { id })
    if P.SpeakerCount(D.id) == 0 then P.MusicStop(D.id) end
    Log(src, 'Enceinte retirée', D.name)
    P.Touch()
    P.PublishMusic()
    return { ok = true, message = 'Enceinte retirée.' }
end }

P.Admin.musicStop = { fn = function(src, d)
    local D = P.shops[tonumber(d.id) or 0]
    if not D then return { error = 'Boîte introuvable.' } end
    P.MusicStop(D.id)
    Log(src, 'Musique coupée', D.name)
    return { ok = true, message = ('Musique de %s coupée.'):format(D.name) }
end }
