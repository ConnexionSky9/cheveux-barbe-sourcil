-- =====================================================================
--  elyzea_papiers - serveur
--  · Guichet du gouvernement (PNJ de l'éditeur de map) : carte d'identité, changement d'identité
--  · PPA : test proposé par un EMS (payé à l'acceptation), puis remise du permis si le test est réussi
--  · Montrer ses papiers à la personne la plus proche
--  Les papiers sont des objets d'inventaire : leurs informations sont dans la metadata.
-- =====================================================================
local core = exports.elyzea_core
local inv = exports.elyzea_inventory
local G, PPA = Config.Government, Config.PPA

local function Notify(src, msg, kind) core:Notify(src, msg, kind or 'inform') end
local function Coords(src) return GetEntityCoords(GetPlayerPed(src)) end
local function Dist(a, b) return #(Coords(a) - Coords(b)) end
local function Log(src, action, details)
    if GetResourceState('admin_menu') ~= 'started' then return end
    pcall(function() exports.admin_menu:AddLog(src, '[Papiers] ' .. action, details) end)
end
local function Number(prefix) return ('%s-%06d'):format(prefix, math.random(0, 999999)) end
local function Trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

-- Paiement : renvoie true si payé (montant 0 = gratuit)
local function Pay(src, amount, method, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    if Config.PayWith ~= 'choice' then method = Config.PayWith end
    method = method == 'cash' and 'cash' or 'bank'
    return core:RemoveMoney(src, method, amount, reason) == true
end
local function Deposit(society, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if society and society ~= '' and amount > 0 then core:AddSocietyMoney(society, amount, reason) end
end

local function Holder(p)
    local ci = p.PlayerData.charinfo or {}
    return {
        firstname = ci.firstname, lastname = ci.lastname, birthdate = ci.birthdate,
        gender = tonumber(ci.gender) or 0, nationality = ci.nationality or Config.IdCard.nationality,
        citizenid = p.PlayerData.citizenid,
    }
end

-- Donne un objet ; réessaie quelques secondes si l'inventaire n'est pas encore chargé
local function GiveItem(src, item, meta)
    for _ = 1, 15 do
        if not GetPlayerName(src) then return false end
        local ok, res, err = pcall(function() return inv:AddItem(src, item, 1, meta) end)
        if ok and res == true then return true end
        if ok and err ~= 'no_inventory' then return false, err end
        Wait(2000)
    end
    return false, 'no_inventory'
end

-- =====================================================================
--  CARTE D'IDENTITÉ
-- =====================================================================
local function GiveIdCard(src)
    local p = core:GetPlayer(src)
    if not p then return false end
    local meta = Holder(p)
    meta.number = Number('ID')
    meta.issued = os.date('%d/%m/%Y')
    meta.label = "Carte d'identité"
    meta.description = ('%s %s · n° %s'):format(meta.firstname or '', meta.lastname or '', meta.number)
    local ok, err = GiveItem(src, Config.Items.id, meta)
    if not ok then return false, err end
    core:SetMetadata(src, 'idcard', meta.number)
    return true, meta.number
end
exports('GiveIdCard', GiveIdCard)

-- Carte d'identité valide (à son nom) dans l'inventaire ?
local function HasOwnCard(src, cid)
    local ok, n = pcall(function() return inv:Search(src, 'count', Config.Items.id, { citizenid = cid }) end)
    return ok and (tonumber(n) or 0) > 0
end

AddEventHandler('elyzea:server:playerLoaded', function(src)
    if not Config.IdCard.giveOnFirstSpawn then return end
    src = tonumber(src)
    CreateThread(function()
        Wait(3000)
        local p = core:GetPlayer(src)
        if not p or p.PlayerData.metadata.idcard then return end
        if GiveIdCard(src) then Notify(src, 'Vous avez reçu votre carte d\'identité.', 'success') end
    end)
end)

-- Staff : carte gratuite (perdue, bug…)
RegisterCommand(Config.IdCard.command, function(src, args)
    local target = tonumber(args[1]) or src
    local function reply(msg, kind) if src == 0 then print(msg) else Notify(src, msg, kind) end end
    if target == 0 or not core:GetPlayer(target) then return reply('Joueur introuvable.', 'error') end
    local ok, number = GiveIdCard(target)
    if not ok then return reply('Impossible de donner la carte (inventaire plein ?).', 'error') end
    Notify(target, 'Vous avez reçu une nouvelle carte d\'identité.', 'success')
    reply(('Carte d\'identité %s donnée à %d.'):format(number, target), 'success')
    Log(src, 'Carte d\'identité refaite', ('%s [%d] · %s'):format(GetPlayerName(target) or '?', target, number))
end, true)

-- =====================================================================
--  GUICHET DU GOUVERNEMENT
-- =====================================================================
local Gov = {}   -- [src] = { name, npc = vector3 }

local function NearGov(src)
    local s = Gov[src]
    if not s then return nil end
    if #(Coords(src) - s.npc) > G.maxDistance then Gov[src] = nil return nil end
    return s
end

local function GovData(src)
    local s = Gov[src]
    local p = core:GetPlayer(src)
    if not s or not p then return nil end
    local md = p.PlayerData.metadata or {}
    local ic, ch = G.idCard, G.identityChange
    local cardPrice = (ic.firstFree and not md.idcard) and 0 or ic.price
    local left = 0
    if ch.cooldownDays > 0 and md.identityChangedAt then
        left = math.max(0, md.identityChangedAt + ch.cooldownDays * 86400 - os.time())
    end
    return {
        name = s.name, payWith = Config.PayWith,
        money = { bank = core:GetMoney(src, 'bank'), cash = core:GetMoney(src, 'cash') },
        identity = Holder(p),
        idCard = { enabled = ic.enabled, price = cardPrice, free = cardPrice == 0, hasCard = HasOwnCard(src, p.PlayerData.citizenid), onlyOne = ic.onlyOne },
        change = { enabled = ch.enabled, price = ch.price, fields = ch.fields, nationalities = ch.nationalities,
            nameMin = ch.nameMin, nameMax = ch.nameMax, minAge = ch.minAge, maxAge = ch.maxAge,
            cooldownDays = math.ceil(left / 86400), newCard = ch.giveNewCard },
    }
end

exports('OpenGovernment', function(src, opts)
    src = tonumber(src)
    opts = type(opts) == 'table' and opts or {}
    if not src or type(opts.npc) ~= 'table' then return end
    Gov[src] = { name = (opts.name and opts.name ~= '') and opts.name or 'Gouvernement d\'Elyzea',
        npc = vector3(opts.npc.x + 0.0, opts.npc.y + 0.0, opts.npc.z + 0.0) }
    TriggerClientEvent('elyzea_papiers:gov', src, GovData(src))
end)

local function Refresh(src) TriggerClientEvent('elyzea_papiers:govData', src, GovData(src)) end

RegisterNetEvent('elyzea_papiers:gov:close', function() Gov[source] = nil end)

RegisterNetEvent('elyzea_papiers:gov:buyId', function(method)
    local src = source
    if not NearGov(src) or not G.idCard.enabled then return end
    local p = core:GetPlayer(src)
    if not p then return end
    if G.idCard.onlyOne and HasOwnCard(src, p.PlayerData.citizenid) then
        return Notify(src, 'Vous avez déjà une carte d\'identité sur vous.', 'error')
    end
    local price = (G.idCard.firstFree and not p.PlayerData.metadata.idcard) and 0 or G.idCard.price
    if not Pay(src, price, method, 'carte-identite') then return Notify(src, 'Vous n\'avez pas assez d\'argent.', 'error') end
    local ok = GiveIdCard(src)
    if not ok then
        if price > 0 then core:AddMoney(src, (Config.PayWith == 'cash' or (Config.PayWith == 'choice' and method == 'cash')) and 'cash' or 'bank', price, 'carte-identite-rembourse') end
        return Notify(src, 'Inventaire plein : impossible de vous remettre la carte.', 'error')
    end
    Deposit(G.society, price, 'Carte d\'identité')
    Notify(src, price > 0 and ('Carte d\'identité délivrée (%d $).'):format(price) or 'Carte d\'identité délivrée gratuitement.', 'success')
    Log(src, 'Carte d\'identité achetée', ('%d $'):format(price))
    Refresh(src)
end)

-- Vérification des champs du changement d'identité
local BAD = '[%c%d<>"{}%[%]\\/@#%$%%%^&%*=%+_|~!%?;:,%.]'
local function CleanName(v)
    v = Trim(v):gsub('%s+', ' ')
    local n = utf8.len(v)
    local ch = G.identityChange
    if not n or n < ch.nameMin or n > ch.nameMax or v:find(BAD) then return nil end
    return v
end

local function CleanBirth(v)
    local y, m, d = tostring(v or ''):match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not y or m < 1 or m > 12 or d < 1 or d > 31 then return nil end
    local now = os.date('*t')
    local age = now.year - y - ((now.month < m or (now.month == m and now.day < d)) and 1 or 0)
    local ch = G.identityChange
    if age < ch.minAge or age > ch.maxAge then return nil, ('Âge refusé : entre %d et %d ans.'):format(ch.minAge, ch.maxAge) end
    return ('%04d-%02d-%02d'):format(y, m, d)
end

RegisterNetEvent('elyzea_papiers:gov:change', function(data, method)
    local src = source
    local ch = G.identityChange
    if not NearGov(src) or not ch.enabled or type(data) ~= 'table' then return end
    local p = core:GetPlayer(src)
    if not p then return end
    local md = p.PlayerData.metadata or {}
    if ch.cooldownDays > 0 and md.identityChangedAt and os.time() < md.identityChangedAt + ch.cooldownDays * 86400 then
        return Notify(src, 'Vous avez déjà changé d\'identité récemment.', 'error')
    end

    local ci, new = p.PlayerData.charinfo or {}, {}
    if ch.fields.firstname and data.firstname ~= nil and Trim(data.firstname) ~= (ci.firstname or '') then
        new.firstname = CleanName(data.firstname)
        if not new.firstname then return Notify(src, ('Prénom invalide (%d à %d lettres).'):format(ch.nameMin, ch.nameMax), 'error') end
    end
    if ch.fields.lastname and data.lastname ~= nil and Trim(data.lastname) ~= (ci.lastname or '') then
        new.lastname = CleanName(data.lastname)
        if not new.lastname then return Notify(src, ('Nom invalide (%d à %d lettres).'):format(ch.nameMin, ch.nameMax), 'error') end
    end
    if ch.fields.birthdate and data.birthdate ~= nil and data.birthdate ~= ci.birthdate then
        local b, why = CleanBirth(data.birthdate)
        if not b then return Notify(src, why or 'Date de naissance invalide.', 'error') end
        new.birthdate = b
    end
    if ch.fields.nationality and data.nationality ~= nil and data.nationality ~= ci.nationality then
        local okNat = false
        for _, n in ipairs(ch.nationalities or {}) do if n == data.nationality then okNat = true end end
        if not okNat then return Notify(src, 'Nationalité invalide.', 'error') end
        new.nationality = data.nationality
    end
    if ch.fields.gender and data.gender ~= nil and tonumber(data.gender) ~= tonumber(ci.gender) then
        local g = tonumber(data.gender)
        if g ~= 0 and g ~= 1 then return Notify(src, 'Sexe invalide.', 'error') end
        new.gender = g
    end
    if not next(new) then return Notify(src, 'Aucun changement à enregistrer.', 'error') end

    if not Pay(src, ch.price, method, 'changement-identite') then return Notify(src, 'Vous n\'avez pas assez d\'argent.', 'error') end
    Deposit(G.society, ch.price, 'Changement d\'identité')

    local before = ('%s %s'):format(ci.firstname or '', ci.lastname or '')
    for k, v in pairs(new) do core:SetCharInfo(src, k, v) end
    core:SetMetadata(src, 'identityChangedAt', os.time())

    -- Anciennes cartes retirées, nouvelle carte remise
    if ch.removeOldCards then
        local ok, slots = pcall(function() return inv:Search(src, 'slots', Config.Items.id) end)
        for _, sl in ipairs(ok and slots or {}) do pcall(function() inv:RemoveItem(src, Config.Items.id, 1, nil, sl.slot) end) end
    end
    local newCard = ch.giveNewCard and GiveIdCard(src)
    Notify(src, newCard and 'Identité modifiée : voici votre nouvelle carte d\'identité.' or 'Identité modifiée.', 'success')
    local p2 = core:GetPlayer(src)
    local after = p2 and ('%s %s'):format(p2.PlayerData.charinfo.firstname or '', p2.PlayerData.charinfo.lastname or '') or '?'
    Log(src, 'Changement d\'identité', ('%s → %s (%d $)'):format(before, after, ch.price))
    Refresh(src)
end)

-- =====================================================================
--  PPA : test et remise
-- =====================================================================
local Requests = {}   -- [joueur] = { ems, kind, expires }
local Tests = {}      -- [joueur] = { kind, correct = {}, ems, started }
local Results = {}    -- [citizenid] = { kind, passed, score, total, at }

local function CanEms(src)
    local p = core:GetPlayer(src)
    local job = p and p.PlayerData.job
    if not job or job.name ~= PPA.job then return false, 'Réservé au personnel médical.' end
    if (job.grade and job.grade.level or 0) < PPA.minGrade then return false, 'Votre grade ne permet pas de faire passer le PPA.' end
    if PPA.requireDuty and Player(src).state.emsDuty ~= true and job.onduty ~= true then return false, 'Vous devez être en service.' end
    return true
end

local function ValidPatient(src, target)
    target = tonumber(target)
    if not target or target == src or not core:GetPlayer(target) then return nil, 'Patient introuvable.' end
    if Dist(src, target) > Config.ShowDistance + 2.0 then return nil, 'Le patient est trop loin.' end
    return target
end

local function Shuffle(t)
    for i = #t, 2, -1 do local j = math.random(i) t[i], t[j] = t[j], t[i] end
    return t
end

-- 1. L'EMS propose le test
RegisterNetEvent('elyzea_papiers:ppaRequest', function(target, kind)
    local src = source
    local ok, why = CanEms(src)
    if not ok then return Notify(src, why, 'error') end
    local t = PPA.types[kind]
    if not t then return end
    target, why = ValidPatient(src, target)
    if not target then return Notify(src, why, 'error') end
    if t.jobs then
        local pj = core:GetPlayer(target).PlayerData.job
        local allowed = false
        for _, j in ipairs(t.jobs) do if pj and pj.name == j then allowed = true end end
        if not allowed then return Notify(src, ('Le %s est réservé aux forces de l\'ordre.'):format(t.label), 'error') end
    end
    if Tests[target] then return Notify(src, 'Ce patient passe déjà un test.', 'error') end
    if Requests[target] and Requests[target].expires > os.time() then return Notify(src, 'Une demande est déjà en attente pour ce patient.', 'error') end
    Requests[target] = { ems = src, kind = kind, expires = os.time() + PPA.requestTimeout }
    TriggerClientEvent('elyzea_papiers:ppaOffer', target, {
        label = t.label, price = t.price, ems = core:GetCharName(src), payWith = Config.PayWith, timeout = PPA.requestTimeout,
        questions = math.min(t.questions, #(Config.Questions[kind] or {})), passScore = t.passScore, categories = t.categories,
    })
    Notify(src, ('Demande de %s envoyée (%d $).'):format(t.label, t.price), 'inform')
end)

-- 2. Le joueur accepte (paiement immédiat) ou refuse
RegisterNetEvent('elyzea_papiers:ppaAnswer', function(accept, method)
    local src = source
    local r = Requests[src]
    Requests[src] = nil
    if not r then return end
    local t = PPA.types[r.kind]
    local emsOnline = GetPlayerName(r.ems) ~= nil
    if os.time() > r.expires then return Notify(src, 'La demande a expiré.', 'error') end
    if accept ~= true then
        if emsOnline then Notify(r.ems, 'Le patient a refusé le test PPA.', 'error') end
        return
    end
    if not emsOnline or Dist(src, r.ems) > Config.ShowDistance + 8.0 then return Notify(src, 'L\'EMS n\'est plus là.', 'error') end
    if not Pay(src, t.price, method, 'test-ppa') then
        Notify(r.ems, 'Le patient n\'a pas assez d\'argent pour le test.', 'error')
        return Notify(src, ('Vous n\'avez pas assez d\'argent (%d $).'):format(t.price), 'error')
    end
    Deposit(PPA.society, t.price, t.label)

    -- Tirage des questions, réponses mélangées ; seul le serveur connaît les bonnes réponses
    local pool = {}
    for i, q in ipairs(Config.Questions[r.kind] or {}) do pool[#pool + 1] = i end
    Shuffle(pool)
    local list, correct = {}, {}
    for n = 1, math.min(t.questions, #pool) do
        local q = Config.Questions[r.kind][pool[n]]
        local order = {}
        for i = 1, #q.answers do order[i] = i end
        Shuffle(order)
        local answers = {}
        for pos, idx in ipairs(order) do
            answers[pos] = q.answers[idx]
            if idx == q.correct then correct[n] = pos end
        end
        list[n] = { kind = q.kind, text = q.text, answers = answers }
    end
    Tests[src] = { kind = r.kind, correct = correct, ems = r.ems, started = os.time() }
    TriggerClientEvent('elyzea_papiers:ppaTest', src, { label = t.label, passScore = t.passScore, questions = list })
    Notify(r.ems, ('Le patient a payé (%d $) et commence le %s.'):format(t.price, t.label), 'success')
end)

-- 3. Fin du test : correction par le serveur
RegisterNetEvent('elyzea_papiers:ppaSubmit', function(answers)
    local src = source
    local test = Tests[src]
    Tests[src] = nil
    if not test or type(answers) ~= 'table' then return end
    local t = PPA.types[test.kind]
    local score, total = 0, #test.correct
    for i = 1, total do if tonumber(answers[i]) == test.correct[i] then score = score + 1 end end
    local passed = score >= t.passScore
    local cid = core:GetCitizenId(src)
    if cid then Results[cid] = { kind = test.kind, passed = passed, score = score, total = total, at = os.time() } end
    TriggerClientEvent('elyzea_papiers:ppaResult', src, { label = t.label, score = score, total = total, passScore = t.passScore, passed = passed })
    if GetPlayerName(test.ems) then
        Notify(test.ems, ('%s : %s (%d/%d).'):format(t.label, passed and 'test RÉUSSI, vous pouvez donner le PPA' or 'test ÉCHOUÉ', score, total), passed and 'success' or 'error')
    end
    Log(src, 'Test PPA', ('%s · %d/%d · %s'):format(t.label, score, total, passed and 'réussi' or 'échoué'))
end)

-- 4. L'EMS donne le PPA (seulement si le test est réussi et récent)
RegisterNetEvent('elyzea_papiers:issuePpa', function(target)
    local src = source
    local ok, why = CanEms(src)
    if not ok then return Notify(src, why, 'error') end
    target, why = ValidPatient(src, target)
    if not target then return Notify(src, why, 'error') end
    local p = core:GetPlayer(target)
    local cid = p.PlayerData.citizenid
    local res = Results[cid]
    if not res or not res.passed then return Notify(src, 'Ce patient n\'a pas réussi le test PPA : impossible de le donner.', 'error') end
    if os.time() - res.at > PPA.resultMinutes * 60 then
        Results[cid] = nil
        return Notify(src, 'Le résultat du test a expiré : le patient doit repasser le test.', 'error')
    end
    local t = PPA.types[res.kind]

    local meta = Holder(p)
    meta.kind = res.kind
    meta.categories = t.categories
    meta.number = Number(res.kind == 'fdo' and 'FDO' or 'PPA')
    meta.issued = os.date('%d/%m/%Y')
    meta.doctor = core:GetCharName(src)
    meta.score = ('%d/%d'):format(res.score, res.total)
    if (t.validDays or 0) > 0 then
        meta.expiresAt = os.time() + t.validDays * 86400
        meta.expires = os.date('%d/%m/%Y', meta.expiresAt)
    end
    meta.label = res.kind == 'fdo' and 'PPA · Forces de l\'ordre' or 'PPA · Civil'
    meta.description = ('%s %s · %s · n° %s%s'):format(meta.firstname or '', meta.lastname or '', table.concat(t.categories, ', '),
        meta.number, meta.expires and (' · valide jusqu\'au ' .. meta.expires) or '')

    local given, err = GiveItem(target, t.item, meta)
    if not given then
        return Notify(src, ('Impossible de remettre le PPA (%s).'):format(err == 'no_inventory' and 'inventaire indisponible' or 'inventaire plein'), 'error')
    end
    Results[cid] = nil
    local lic = p.PlayerData.metadata.licences or {}
    lic[PPA.licence] = true
    if res.kind == 'fdo' then lic.weapon_fdo = true end
    core:SetMetadata(target, 'licences', lic)

    Notify(src, ('%s %s délivré.'):format(t.label, meta.number), 'success')
    Notify(target, ('Vous avez reçu votre %s.'):format(t.label), 'success')
    Log(src, 'PPA délivré', ('%s %s [%d] · %s · %s'):format(meta.firstname or '', meta.lastname or '', target, t.label, meta.number))
end)

AddEventHandler('playerDropped', function()
    local src = source
    Gov[src], Requests[src], Tests[src] = nil, nil, nil
end)

-- =====================================================================
--  MONTRER UN PAPIER À LA PERSONNE LA PLUS PROCHE
-- =====================================================================
local Allowed = {}
for _, name in pairs(Config.Items) do Allowed[name] = true end

RegisterNetEvent('elyzea_papiers:show', function(slot)
    local src = source
    local item = inv:GetSlot(src, tonumber(slot) or 0)
    if not item or not Allowed[item.name] or type(item.metadata) ~= 'table' then return end
    local me, target, best = Coords(src), nil, nil
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if id ~= src then
            local d = #(me - Coords(id))
            if d <= Config.ShowDistance and (not best or d < best) then target, best = id, d end
        end
    end
    if not target then return Notify(src, ('Personne à moins de %d m.'):format(math.floor(Config.ShowDistance)), 'error') end
    TriggerClientEvent('elyzea_papiers:card', target, item.name, item.metadata, src)
    Notify(src, 'Vous montrez vos papiers.', 'success')
end)
