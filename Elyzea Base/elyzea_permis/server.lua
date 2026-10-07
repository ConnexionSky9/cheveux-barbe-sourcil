-- =====================================================================
--  elyzea_permis - serveur
--  Les bonnes réponses du code restent ici : le joueur ne reçoit que
--  les questions, et la correction est faite par le serveur.
-- =====================================================================
local Sessions = {}   -- [src] = { opts, quiz = {...}, exam = {...} }

local function GetPlayer(src) return exports.elyzea_core:GetPlayer(src) end
local function Cid(src) local p = GetPlayer(src) return p and p.PlayerData.citizenid end
local function Notify(src, msg, kind) TriggerClientEvent('permis:client:notify', src, msg, kind or 'inform') end
local function Coords(src) return GetEntityCoords(GetPlayerPed(src)) end
local function Log(src, action, details)
    if GetResourceState('admin_menu') == 'started' then pcall(function() exports.admin_menu:AddLog(src, '[Auto-école] ' .. action, details) end) end
end

-- ---------------------------------------------------------------------
-- Réglages modifiables dans le menu admin : questions du code et prix
-- ---------------------------------------------------------------------
local Settings = { questions = {}, prices = {} }
local function Copy(t) return json.decode(json.encode(t)) end

local function SaveSettings()
    MySQL.query.await('INSERT INTO elyzea_permis_settings (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)',
        { 'config', json.encode(Settings) })
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_permis` (
        `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
        `theory` LONGTEXT NULL, `licenses` LONGTEXT NULL, `number` VARCHAR(20) NULL)]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `elyzea_permis_settings` (
        `key` VARCHAR(64) NOT NULL PRIMARY KEY, `value` LONGTEXT NOT NULL)]])
    local raw = MySQL.scalar.await('SELECT `value` FROM elyzea_permis_settings WHERE `key` = ?', { 'config' })
    local saved = raw and json.decode(raw) or {}
    Settings.questions = type(saved.questions) == 'table' and saved.questions or Copy(Config.Questions)
    Settings.prices = type(saved.prices) == 'table' and saved.prices or Copy(Config.Prices)
    for key in pairs(Config.Categories) do
        Settings.questions[key] = Settings.questions[key] or {}
        Settings.prices[key] = Settings.prices[key] or Copy(Config.Prices[key] or { code = 250, drive = 500 })
    end
    Settings.questions.common = Settings.questions.common or {}
    if not raw then SaveSettings() end
end)

local function PriceOf(cat, kind) return math.max(0, math.floor(tonumber(((Settings.prices or {})[cat] or {})[kind]) or 0)) end

local function Load(cid)
    local r = MySQL.single.await('SELECT theory, licenses, number FROM elyzea_permis WHERE citizenid = ?', { cid })
    return {
        theory = r and json.decode(r.theory or '{}') or {},
        licenses = r and json.decode(r.licenses or '{}') or {},
        number = r and r.number or nil,
    }
end

local function Save(cid, d)
    MySQL.query.await('INSERT INTO elyzea_permis (citizenid, theory, licenses, number) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE theory = VALUES(theory), licenses = VALUES(licenses), number = VALUES(number)',
        { cid, json.encode(d.theory), json.encode(d.licenses), d.number })
end

local function Pay(src, amount, reason)
    if amount <= 0 then return true end
    local p = GetPlayer(src)
    if not p then return false end
    if p.Functions.RemoveMoney('cash', amount, reason) or p.Functions.RemoveMoney('bank', amount, reason) then return true end
    Notify(src, ("Tu n'as pas assez d'argent (%d $)."):format(amount), 'error')
    return false
end

local function NearNpc(src)
    local s = Sessions[src]
    return s and #(Coords(src) - vector3(s.opts.npc.x, s.opts.npc.y, s.opts.npc.z)) <= 8.0 and s or nil
end

-- État envoyé à l'interface : ce que le joueur a déjà
local function Status(src)
    local s = Sessions[src]
    local d = Load(Cid(src))
    local cats = {}
    for _, key in ipairs(Config.Order) do
        local c = Config.Categories[key]
        if s.opts.categories[key] then
            cats[#cats + 1] = { key = key, short = c.short, label = c.label, icon = c.icon,
                theory = d.theory[key] == true, license = d.licenses[key] ~= nil,
                codePrice = PriceOf(key, 'code'), drivePrice = PriceOf(key, 'drive') }
        end
    end
    local route = s.opts.route
    return {
        name = s.opts.name,
        questions = s.opts.questions, passScore = s.opts.passScore, maxFaults = s.opts.maxFaults,
        routeReady = route ~= nil and #(route.points or {}) >= 3 and s.opts.spot ~= nil,
        routeMinutes = route and route.duration and math.max(1, math.floor(route.duration / 60 + 0.5)) or nil,
        categories = cats,
    }
end

-- Appelé par admin_menu quand un joueur parle à un PNJ « Auto-école »
exports('OpenFor', function(src, opts)
    if type(opts) ~= 'table' or type(opts.npc) ~= 'table' then return end
    local D = Config.Defaults
    Sessions[src] = { opts = {
        name = opts.name or 'Auto-école Elyzea', npc = opts.npc, spot = opts.spot, route = opts.route,
        questions = math.max(3, math.min(30, tonumber(opts.questions) or D.questions)),
        passScore = math.max(1, tonumber(opts.passScore) or D.passScore),
        maxFaults = math.max(0, tonumber(opts.maxFaults) or D.maxFaults),
        speedTolerance = math.max(0, tonumber(opts.speedTolerance) or D.speedTolerance),
        categories = type(opts.categories) == 'table' and opts.categories or { car = true, moto = true, truck = true },
        models = type(opts.models) == 'table' and opts.models or {},
    } }
    if Sessions[src].opts.passScore > Sessions[src].opts.questions then Sessions[src].opts.passScore = Sessions[src].opts.questions end
    TriggerClientEvent('permis:client:open', src, Status(src))
end)

RegisterNetEvent('permis:server:close', function()
    local s = Sessions[source]
    if s and not s.exam then Sessions[source] = nil end
end)

-- ---------------------------------------------------------------------
-- Code de la route
-- ---------------------------------------------------------------------
local function Shuffle(t)
    for i = #t, 2, -1 do local j = math.random(i) t[i], t[j] = t[j], t[i] end
    return t
end

RegisterNetEvent('permis:server:startQuiz', function(cat)
    local src = source
    local s = NearNpc(src)
    if not s or not s.opts.categories[cat] or not Config.Categories[cat] then return end
    local d = Load(Cid(src))
    if d.licenses[cat] then return Notify(src, 'Tu as déjà ce permis.', 'error') end
    if d.theory[cat] then return Notify(src, 'Tu as déjà réussi le code de ce permis : passe à la conduite.', 'inform') end
    local pool = {}
    for _, q in ipairs(Settings.questions.common or {}) do pool[#pool + 1] = q end
    for _, q in ipairs(Settings.questions[cat] or {}) do pool[#pool + 1] = q end
    if #pool < 3 then return Notify(src, 'Le code de ce permis n\'a pas encore de questions : préviens le staff.', 'error') end
    if not Pay(src, PriceOf(cat, 'code'), 'permis-code') then return end

    Shuffle(pool)
    local list, answers = {}, {}
    for i = 1, math.min(s.opts.questions, #pool) do
        -- Les réponses sont mélangées : on garde la position de la bonne
        local q = pool[i]
        local order = Shuffle({ 1, 2, 3, 4 })
        local shown, good = {}, nil
        for pos, orig in ipairs(order) do
            if q.a[orig] then shown[#shown + 1] = q.a[orig] if orig == q.answer then good = #shown end end
        end
        list[#list + 1] = { q = q.q, a = shown }
        answers[#answers + 1] = good
    end
    s.quiz = { cat = cat, answers = answers, list = list, started = os.time() }
    Log(src, 'Code commencé', Config.Categories[cat].label)
    TriggerClientEvent('permis:client:quiz', src, { cat = cat, label = Config.Categories[cat].label, questions = list, passScore = math.min(s.opts.passScore, #list) })
end)

RegisterNetEvent('permis:server:submitQuiz', function(given)
    local src = source
    local s = Sessions[src]
    if not s or not s.quiz then return end
    local quiz = s.quiz
    s.quiz = nil
    if os.time() - quiz.started < 10 then return Notify(src, 'Réponses trop rapides : examen annulé.', 'error') end
    given = type(given) == 'table' and given or {}
    local score, corrections = 0, {}
    for i, good in ipairs(quiz.answers) do
        local g = tonumber(given[i])
        if g == good then score = score + 1 end
        corrections[i] = { given = g, good = good }
    end
    local need = math.min(s.opts.passScore, #quiz.answers)
    local passed = score >= need
    if passed then
        local cid = Cid(src)
        local d = Load(cid)
        d.theory[quiz.cat] = true
        Save(cid, d)
    end
    Log(src, passed and 'Code réussi' or 'Code échoué', ('%s · %d/%d'):format(Config.Categories[quiz.cat].label, score, #quiz.answers))
    TriggerClientEvent('permis:client:quizResult', src, {
        cat = quiz.cat, score = score, total = #quiz.answers, need = need, passed = passed,
        corrections = corrections, codePrice = PriceOf(quiz.cat, 'code'), status = Status(src),
    })
end)

-- ---------------------------------------------------------------------
-- Examen de conduite
-- ---------------------------------------------------------------------
local function EndExam(src, passed, reason)
    local s = Sessions[src]
    local e = s and s.exam
    if not e then return end
    s.exam = nil
    if DoesEntityExist(e.veh) then DeleteEntity(e.veh) end
    TriggerClientEvent('permis:client:examEnd', src, { passed = passed, reason = reason, cat = e.cat, label = Config.Categories[e.cat].label })
end

local function GiveLicense(src, cat)
    local p = GetPlayer(src)
    local cid = p.PlayerData.citizenid
    local d = Load(cid)
    d.licenses[cat] = os.date('%d/%m/%Y')
    d.theory[cat] = nil
    if not d.number then d.number = ('EL-%06d'):format(math.random(0, 999999)) end
    Save(cid, d)

    -- Permis reconnus par la base Elyzea (et la tablette de police)
    local lic = p.PlayerData.metadata.licences or {}
    lic[Config.Categories[cat].license] = true
    p.Functions.SetMetaData('licences', lic)

    -- Un seul objet « permis de conduire » qui regroupe toutes les catégories
    if GetResourceState('elyzea_inventory') == 'started' then
        local ci = p.PlayerData.charinfo or {}
        local cats = {}
        for _, key in ipairs(Config.Order) do if d.licenses[key] then cats[#cats + 1] = { short = Config.Categories[key].short, label = Config.Categories[key].label, date = d.licenses[key] } end end
        local shorts = {}
        for _, c in ipairs(cats) do shorts[#shorts + 1] = c.short end
        local meta = {
            label = 'Permis de conduire', number = d.number, firstname = ci.firstname, lastname = ci.lastname,
            birthdate = ci.birthdate, gender = ci.gender, categories = cats,
            description = ('%s %s · catégories %s · n° %s'):format(ci.firstname or '', ci.lastname or '', table.concat(shorts, ', '), d.number),
        }
        local slots = exports.elyzea_inventory:Search(src, 'slots', Config.Item) or {}
        local own
        for _, sl in ipairs(slots) do if sl.metadata and sl.metadata.number == d.number then own = sl end end
        if own then
            exports.elyzea_inventory:SetMetadata(src, own.slot, meta)
        elseif not exports.elyzea_inventory:AddItem(src, Config.Item, 1, meta) then
            print(('^1[Auto-école] Impossible de donner « %s » : inventaire plein ?^0'):format(Config.Item))
        end
    end
    Log(src, 'Permis obtenu', Config.Categories[cat].label)
end

RegisterNetEvent('permis:server:startExam', function(cat)
    local src = source
    local s = NearNpc(src)
    if not s or s.exam or not s.opts.categories[cat] then return end
    local d = Load(Cid(src))
    if d.licenses[cat] then return Notify(src, 'Tu as déjà ce permis.', 'error') end
    if not d.theory[cat] then return Notify(src, 'Réussis d\'abord le code.', 'error') end
    local route, spot = s.opts.route, s.opts.spot
    if not route or #(route.points or {}) < 3 or not spot then return Notify(src, 'Le parcours de conduite n\'est pas encore prêt : préviens le staff.', 'error') end
    if not Pay(src, PriceOf(cat, 'drive'), 'permis-conduite') then return end

    local model = s.opts.models[cat] or Config.Categories[cat].model
    local vtype = cat == 'moto' and 'bike' or 'automobile'
    local veh = CreateVehicleServerSetter(joaat(model), vtype, spot.x + 0.0, spot.y + 0.0, spot.z + 0.0, (spot.h or 0.0) + 0.0)
    local t = GetGameTimer()
    while not DoesEntityExist(veh) and GetGameTimer() - t < 4000 do Wait(10) end
    if not DoesEntityExist(veh) then return Notify(src, ('Le véhicule d\'examen « %s » n\'existe pas sur ce serveur.'):format(model), 'error') end
    SetVehicleNumberPlateText(veh, 'PERMIS')
    pcall(function() exports.elyzea_core:GiveKeys(src, veh) end)

    s.exam = { cat = cat, veh = veh, started = os.time() }
    Log(src, 'Conduite commencée', Config.Categories[cat].label)
    TriggerClientEvent('permis:client:exam', src, {
        cat = cat, label = Config.Categories[cat].label, netId = NetworkGetNetworkIdFromEntity(veh),
        points = route.points, duration = route.duration, maxFaults = s.opts.maxFaults, tolerance = s.opts.speedTolerance,
    })
end)

RegisterNetEvent('permis:server:finishExam', function(faults, aborted, reason)
    local src = source
    local s = Sessions[src]
    local e = s and s.exam
    if not e then return end
    if aborted then return EndExam(src, false, reason or 'Examen abandonné.') end
    faults = math.max(0, math.floor(tonumber(faults) or 0))
    local route = s.opts.route
    local start = route.points[1]
    local minTime = math.floor((route.duration or 120) * 0.4)
    if os.time() - e.started < minTime then return EndExam(src, false, 'Parcours terminé trop vite : examen annulé.') end
    if #(Coords(src) - vector3(start.x, start.y, start.z)) > 40.0 then return EndExam(src, false, 'Tu n\'es pas revenu au point de départ.') end
    if faults > s.opts.maxFaults then return EndExam(src, false, ('Trop de fautes (%d, maximum %d).'):format(faults, s.opts.maxFaults)) end
    local cat = e.cat
    EndExam(src, true, ('Examen réussi avec %d faute%s.'):format(faults, faults > 1 and 's' or ''))
    GiveLicense(src, cat)
end)

-- ---------------------------------------------------------------------
-- Montrer son permis
-- ---------------------------------------------------------------------
RegisterNetEvent('permis:server:show', function(slot)
    local src = source
    if GetResourceState('elyzea_inventory') ~= 'started' then return end
    local item = exports.elyzea_inventory:GetSlot(src, tonumber(slot) or 0)
    if not item or item.name ~= Config.Item or not item.metadata then return end
    local me = Coords(src)
    local target, best
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if id ~= src then
            local dist = #(me - Coords(id))
            if dist <= 3.0 and (not best or dist < best) then target, best = id, dist end
        end
    end
    if not target then return Notify(src, 'Personne à moins de 3 m pour voir ton permis.', 'error') end
    TriggerClientEvent('permis:client:card', target, item.metadata, src)
    Notify(src, 'Tu montres ton permis de conduire.', 'success')
end)

AddEventHandler('playerDropped', function()
    local s = Sessions[source]
    if s and s.exam and DoesEntityExist(s.exam.veh) then DeleteEntity(s.exam.veh) end
    Sessions[source] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, s in pairs(Sessions) do if s.exam and DoesEntityExist(s.exam.veh) then DeleteEntity(s.exam.veh) end end
end)

-- ---------------------------------------------------------------------
-- Menu admin › Métiers › Auto-école (permission vérifiée par admin_menu)
-- ---------------------------------------------------------------------
local function Str(v, max) return (tostring(v or ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, max or 200) end
local VALID = { common = true }
for key in pairs(Config.Categories) do VALID[key] = true end

exports('AdminData', function()
    local counts = MySQL.single.await('SELECT COUNT(*) AS n FROM elyzea_permis WHERE licenses IS NOT NULL AND licenses <> "{}"') or {}
    local cats = {}
    for _, key in ipairs(Config.Order) do
        local c = Config.Categories[key]
        cats[#cats + 1] = { key = key, short = c.short, label = c.label, icon = c.icon }
    end
    return { available = true, questions = Settings.questions, prices = Settings.prices, categories = cats, holders = counts.n or 0 }
end)

local A = {}
function A.saveQuestion(_, d)
    local cat = tostring(d.cat or '')
    if not VALID[cat] then error('Catégorie inconnue.') end
    local q = Str(d.q, 220)
    local answers = {}
    for i = 1, 4 do
        local a = Str((d.a or {})[i], 140)
        if a ~= '' then answers[#answers + 1] = a end
    end
    local good = math.floor(tonumber(d.answer) or 0)
    if q == '' then error('Écris la question.') end
    if #answers < 2 then error('Il faut au moins 2 réponses.') end
    if good < 1 or good > #answers then error('Choisis la bonne réponse.') end
    local list = Settings.questions[cat]
    local idx = tonumber(d.index)
    local entry = { q = q, a = answers, answer = good }
    if idx and list[idx] then list[idx] = entry else list[#list + 1] = entry end
    SaveSettings()
    return idx and 'Question modifiée.' or 'Question ajoutée.'
end

function A.deleteQuestion(_, d)
    local list = Settings.questions[tostring(d.cat or '')]
    local idx = tonumber(d.index)
    if not list or not idx or not list[idx] then error('Question introuvable.') end
    table.remove(list, idx)
    SaveSettings()
    return 'Question supprimée.'
end

function A.resetQuestions(_, d)
    local cat = tostring(d.cat or '')
    if not VALID[cat] then error('Catégorie inconnue.') end
    Settings.questions[cat] = Copy(Config.Questions[cat] or {})
    SaveSettings()
    return 'Questions d\'origine remises.'
end

function A.savePrices(_, d)
    for key in pairs(Config.Categories) do
        local p = (d.prices or {})[key]
        if type(p) == 'table' then
            Settings.prices[key] = { code = math.max(0, math.floor(tonumber(p.code) or 0)), drive = math.max(0, math.floor(tonumber(p.drive) or 0)) }
        end
    end
    SaveSettings()
    return 'Prix enregistrés.'
end

exports('AdminAction', function(src, name, data)
    local fn = A[tostring(name)]
    if not fn then return false, 'Action inconnue.' end
    local ok, res = pcall(fn, src, type(data) == 'table' and data or {})
    if not ok then return false, (tostring(res):gsub('^.-:%d+: ', '')) end
    return true, res
end)
