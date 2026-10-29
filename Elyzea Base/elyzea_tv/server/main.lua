-- =====================================================================
--  ELYZEA TV - serveur
--  · État de chaque écran (vidéo, départ, pause, volume) gardé ici et envoyé à tous : chaque joueur
--    affiche la même vidéo au même moment (heure commune GetCloudTimeAsInt côté joueur, os.time ici).
--  · Télés à écran plat du jeu : identifiées par « modèle | x | y | z » (objets de la carte).
--  · Écrans posés par le staff : base de données (table tv_screens, créée toute seule).
--  · Tout est revérifié : lien YouTube, distance, délai entre deux changements, permissions.
-- =====================================================================
TV = { screens = {}, states = {}, ready = false }
local C = Config
local core = exports.elyzea_core

local function dbg(...) if C.Debug then print('[elyzea_tv]', ...) end end
local function now() return os.time() end
local function round(v, d) local m = 10 ^ (d or 0) return math.floor(v * m + 0.5) / m end
local function num(v, lo, hi) v = tonumber(v) if not v or v ~= v or v == math.huge or v == -math.huge then return nil end if (lo and v < lo) or (hi and v > hi) then return nil end return v end
local function trim(s, n) s = tostring(s or ''):gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '') return s:sub(1, n or 40) end

local function nameOf(src)
    local ok, p = pcall(function() return core:GetPlayer(src) end)
    if ok and p and p.PlayerData and p.PlayerData.charinfo then
        local ci = p.PlayerData.charinfo
        local n = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
        if n ~= '' then return n end
    end
    return GetPlayerName(src) or ('#' .. tostring(src))
end
local function pos(src) local ped = GetPlayerPed(src) if not ped or ped == 0 then return nil end return GetEntityCoords(ped) end
local function isStaff(src)
    local ok, r = pcall(function() return exports.admin_menu:HasPermission(src, 'tv_manage') end)
    return ok and r == true
end
local function notify(src, msg, kind) TriggerClientEvent('elyzea:client:notify', src, msg, kind or 'inform') end

-- ---------------------------------------------------------------- télés à écran plat
-- entiers 32 bits signés : même écriture des modèles que chez les joueurs
local function s32(h) h = math.floor(h) % 4294967296 if h >= 2147483648 then h = h - 4294967296 end return h end
local flatModels = {}
for _, t in ipairs(C.FlatTVs) do flatModels[s32(GetHashKey(t.model))] = t.model end
-- clé d'une télé : « m<hash>|x|y|z » (coordonnées arrondies au décimètre, identiques chez tous les joueurs)
function TV.ParseFlatKey(key)
    if type(key) ~= 'string' or #key > 60 then return nil end
    local h, x, y, z = key:match('^m(%-?%d+)|(%-?[%d%.]+)|(%-?[%d%.]+)|(%-?[%d%.]+)$')
    h, x, y, z = tonumber(h), tonumber(x), tonumber(y), tonumber(z)
    if not h or not x or not y or not z then return nil end
    h = s32(h)
    if not flatModels[h] then return nil end
    return { model = h, x = x, y = y, z = z }
end

-- ---------------------------------------------------------------- écrans du staff (base de données)
local function loadScreens()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `tv_screens` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(60) NOT NULL DEFAULT '',
        `data` LONGTEXT NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ) DEFAULT CHARSET=utf8mb4]])
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `tv_screens`') or {}) do
        local ok, d = pcall(json.decode, r.data or '')
        if ok and type(d) == 'table' then TV.screens[r.id] = { id = r.id, name = r.name, data = d } end
    end
    TV.ready = true
end
function TV.PublicScreens()
    local out = {}
    for id, s in pairs(TV.screens) do out[#out + 1] = { id = id, name = s.name, data = s.data } end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end
local function pushScreens() TriggerClientEvent('elyzea_tv:client:screens', -1, TV.PublicScreens()) end
local function saveScreen(s)
    local data = json.encode(s.data)
    if s.id then MySQL.update.await('UPDATE `tv_screens` SET `name` = ?, `data` = ? WHERE `id` = ?', { s.name, data, s.id })
    else s.id = MySQL.insert.await('INSERT INTO `tv_screens` (`name`, `data`) VALUES (?, ?)', { s.name, data }) end
    TV.screens[s.id] = s
    pushScreens()
    return s.id
end

-- ---------------------------------------------------------------- état des écrans
local function setState(key, st)
    TV.states[key] = st
    TriggerClientEvent('elyzea_tv:client:state', -1, key, st)
end
-- position de la vidéo (s) à l'instant présent
function TV.Position(st)
    if not st then return 0 end
    if st.paused then return st.pausedAt or 0 end
    return (st.offset or 0) + math.max(0, now() - (st.startAt or now()))
end

-- Le joueur peut-il commander cet écran ? (renvoie la description de l'écran ou nil, raison)
function TV.Access(src, key, staffAction)
    if type(key) ~= 'string' then return nil, 'Écran inconnu.' end
    if staffAction then
        if not isStaff(src) then return nil, 'Permission refusée.' end
    end
    local sid = key:match('^s(%d+)$')
    if sid then
        local s = TV.screens[tonumber(sid)]
        if not s then return nil, 'Écran introuvable.' end
        if staffAction then return { kind = 'custom', screen = s } end
        if not s.data.public and not isStaff(src) then return nil, 'Écran réservé au staff.' end
        local p, r = pos(src), s.data.remote
        if not p or not r or #(p - vector3(r.x, r.y, r.z)) > C.Custom.remoteDistance + 0.5 then return nil, 'Approche-toi de la télécommande de l\'écran.' end
        return { kind = 'custom', screen = s }
    end
    local f = TV.ParseFlatKey(key)
    if not f then return nil, 'Ce n\'est pas une télé à écran plat.' end
    if staffAction then return { kind = 'flat', flat = f } end
    if not C.Flat.everyone and not isStaff(src) then return nil, 'Télés réservées au staff.' end
    local p = pos(src)
    if not p or #(p - vector3(f.x, f.y, f.z)) > C.Flat.controlDistance + 0.6 then return nil, 'Approche-toi de la télé.' end
    return { kind = 'flat', flat = f }
end

local lastChange = {}
function TV.Play(src, key, url, staffAction)
    local a, why = TV.Access(src, key, staffAction)
    if not a then return nil, why end
    local id, start = YT.Parse(url)
    if not id then return nil, 'Lien YouTube invalide (ex. https://www.youtube.com/watch?v=… ou https://youtu.be/…).' end
    local t = now()
    if not staffAction and lastChange[src] and t - lastChange[src] < C.Player.changeCooldown then return nil, 'Doucement : attends un peu avant de changer.' end
    lastChange[src] = t
    local old = TV.states[key]
    local vol = old and old.volume or (a.kind == 'custom' and a.screen.data.volume) or C.Player.defaultVolume
    setState(key, { id = id, offset = start or 0, startAt = t, paused = false, volume = vol, by = nameOf(src), at = t })
    dbg('lecture', key, id, src)
    return true, id
end

function TV.Control(src, key, action, value, staffAction)
    local a, why = TV.Access(src, key, staffAction)
    if not a then return nil, why end
    local st = TV.states[key]
    if action == 'stop' then
        if not st then return true end
        setState(key, nil)
        return true
    end
    if not st then return nil, 'Aucune vidéo sur cet écran.' end
    st = { id = st.id, offset = st.offset, startAt = st.startAt, paused = st.paused, pausedAt = st.pausedAt, volume = st.volume, by = st.by, at = now() }
    if action == 'pause' then
        if st.paused then return true end
        st.pausedAt, st.paused = TV.Position(st), true
    elseif action == 'resume' then
        if not st.paused then return true end
        st.offset, st.startAt, st.paused, st.pausedAt = st.pausedAt or 0, now(), false, nil
    elseif action == 'volume' then
        local v = num(value, 0, 100)
        if not v then return nil, 'Volume invalide.' end
        st.volume = math.floor(v)
    elseif action == 'seek' then
        local v = num(value, -3600, 3600)
        if not v then return nil, 'Position invalide.' end
        local p = math.max(0, TV.Position(st) + v)
        if st.paused then st.pausedAt = p else st.offset, st.startAt = p, now() end
    else
        return nil, 'Action inconnue.'
    end
    setState(key, st)
    return true
end

-- ---------------------------------------------------------------- rappels (joueurs)
local function wrap(fn) return function(src, ...) local ok, a, b = pcall(fn, src, ...) if not ok then print('^1[elyzea_tv] ' .. tostring(a) .. '^0') return { error = 'Erreur serveur.' } end return a, b end end
local rate = {}
local function limited(src) local t = GetGameTimer() local r = rate[src] if r and t - r < 250 then return true end rate[src] = t return false end
Ely.callback.register('elyzea_tv:state', wrap(function()
    return { screens = TV.PublicScreens(), states = TV.states, now = now() }
end))
Ely.callback.register('elyzea_tv:play', wrap(function(src, key, url)
    if limited(src) then return { error = 'Trop rapide.' } end
    local ok, r = TV.Play(src, key, url)
    return ok and { ok = true, id = r } or { error = r }
end))
Ely.callback.register('elyzea_tv:control', wrap(function(src, key, action, value)
    if limited(src) then return { error = 'Trop rapide.' } end
    local ok, r = TV.Control(src, key, tostring(action or ''), value)
    return ok and { ok = true } or { error = r }
end))
AddEventHandler('playerDropped', function() local src = source rate[src], lastChange[src] = nil, nil TV.editTokens[src] = nil end)

-- ---------------------------------------------------------------- éditeur d'écran (staff) : jeton donné par l'action admin
TV.editTokens = {}
local function newToken(src, id)
    local token = ('%d-%d'):format(math.random(100000, 999999), GetGameTimer())
    TV.editTokens[src] = { token = token, id = id, exp = now() + 900 }
    return token
end
function TV.CleanScreenData(v, old)
    if type(v) ~= 'table' then return nil end
    local X = C.Custom
    local d = {
        x = num(v.x), y = num(v.y), z = num(v.z, -500, 3000), h = num(v.h, -720, 720),
        w = num(v.w, X.minW, X.maxW), hgt = num(v.hgt, X.minH, X.maxH),
    }
    if not d.x or not d.y or not d.z or not d.h or not d.w or not d.hgt then return nil end
    d.x, d.y, d.z, d.h, d.w, d.hgt = round(d.x, 3), round(d.y, 3), round(d.z, 3), round(d.h % 360, 2), round(d.w, 3), round(d.hgt, 3)
    local r = type(v.remote) == 'table' and v.remote or {}
    d.remote = { x = round(num(r.x) or d.x, 3), y = round(num(r.y) or d.y, 3), z = round(num(r.z) or d.z, 3) }
    old = old or {}
    d.public = old.public ~= false
    d.range = old.range or X.defaultRange
    d.volume = old.volume or C.Player.defaultVolume
    return d
end
RegisterNetEvent('elyzea_tv:server:editorSave', function(token, v, name)
    local src = source
    local t = TV.editTokens[src]
    if not t or t.token ~= token or now() > t.exp then return notify(src, 'Écran refusé : relance « Placer / modifier » depuis le menu admin.', 'error') end
    if not isStaff(src) then return notify(src, 'Permission refusée.', 'error') end
    local old = t.id and TV.screens[t.id]
    if t.id and not old then return notify(src, 'Écran introuvable.', 'error') end
    local p = pos(src)
    if not p then return end
    local d = TV.CleanScreenData(v, old and old.data)
    if not d then return notify(src, 'Dimensions ou position invalides.', 'error') end
    if #(vector3(d.x, d.y, d.z) - p) > 150.0 or #(vector3(d.remote.x, d.remote.y, d.remote.z) - p) > 10.0 then return notify(src, 'Écran trop loin de toi.', 'error') end
    if not old then
        local n = 0 for _ in pairs(TV.screens) do n = n + 1 end
        if n >= C.Custom.maxScreens then return notify(src, ('Maximum %d écrans.'):format(C.Custom.maxScreens), 'error') end
    end
    TV.editTokens[src] = nil
    local nm = trim(name, 40)
    local s = old or { name = nm ~= '' and nm or 'Écran' }
    if old and nm ~= '' then s.name = nm end
    s.data = d
    local id = saveScreen(s)
    pcall(function() exports.admin_menu:AddLog(src, 'Écrans / TV', ('Écran #%d « %s » %s (%.1f × %.1f m)'):format(id, s.name, old and 'modifié' or 'créé', d.w, d.hgt)) end)
    notify(src, ('Écran « %s » enregistré (%.1f × %.1f m). Sa télécommande est là où tu te tiens.'):format(s.name, d.w, d.hgt), 'success')
end)

-- ---------------------------------------------------------------- menu admin (admin_menu/server/tv.lua)
local ACTIONS = {}
ACTIONS.screen_new = function(src, d)
    local token = newToken(src, nil)
    local w = num(d.w, C.Custom.minW, C.Custom.maxW) or C.Custom.defaultW
    local h = num(d.h, C.Custom.minH, C.Custom.maxH) or C.Custom.defaultH
    TriggerClientEvent('elyzea_tv:client:editor', src, token, nil, { w = w, hgt = h }, trim(d.name, 40))
    return true, 'Placement : vise l\'endroit, molette = taille, Q / E = tourner, Page préc. / suiv. = hauteur, ENTRÉE = enregistrer.'
end
ACTIONS.screen_edit = function(src, d)
    local s = TV.screens[tonumber(d.id) or -1]
    if not s then return false, 'Écran introuvable.' end
    local token = newToken(src, s.id)
    TriggerClientEvent('elyzea_tv:client:editor', src, token, s.id, s.data, s.name)
    return true, 'Modification en jeu : ENTRÉE pour enregistrer, RETOUR pour annuler.'
end
ACTIONS.screen_size = function(src, d)
    local s = TV.screens[tonumber(d.id) or -1]
    if not s then return false, 'Écran introuvable.' end
    local w, h = num(d.w, C.Custom.minW, C.Custom.maxW), num(d.h, C.Custom.minH, C.Custom.maxH)
    if not w or not h then return false, ('Taille invalide (%.1f à %.0f m de large, %.2f à %.0f m de haut).'):format(C.Custom.minW, C.Custom.maxW, C.Custom.minH, C.Custom.maxH) end
    s.data.w, s.data.hgt = round(w, 3), round(h, 3)
    saveScreen(s)
    return true, ('Taille : %.2f × %.2f m.'):format(w, h)
end
-- l'image passe de l'autre côté de l'écran (écran posé à l'envers)
ACTIONS.screen_flip = function(src, d)
    local s = TV.screens[tonumber(d.id) or -1]
    if not s then return false, 'Écran introuvable.' end
    s.data.h = round(((s.data.h or 0) + 180) % 360, 2)
    saveScreen(s)
    return true, 'Écran retourné : l\'image est maintenant de l\'autre côté.'
end
ACTIONS.screen_set = function(src, d)
    local s = TV.screens[tonumber(d.id) or -1]
    if not s then return false, 'Écran introuvable.' end
    if d.name ~= nil then local n = trim(d.name, 40) if n ~= '' then s.name = n end end
    if d.public ~= nil then s.data.public = d.public == true end
    local r = num(d.range, 5, 300) if r then s.data.range = math.floor(r) end
    local v = num(d.volume, 0, 100) if v then s.data.volume = math.floor(v) end
    saveScreen(s)
    return true, 'Écran enregistré.'
end
ACTIONS.screen_delete = function(src, d)
    local id = tonumber(d.id) or -1
    if not TV.screens[id] then return false, 'Écran introuvable.' end
    MySQL.update.await('DELETE FROM `tv_screens` WHERE `id` = ?', { id })
    TV.screens[id] = nil
    setState('s' .. id, nil)
    pushScreens()
    return true, 'Écran supprimé.'
end
ACTIONS.play = function(src, d)
    local key = d.key or (d.id and ('s' .. tostring(d.id)))
    local ok, r = TV.Play(src, key, d.url, true)
    if not ok then return false, r end
    return true, 'Vidéo lancée.'
end
ACTIONS.control = function(src, d)
    local key = d.key or (d.id and ('s' .. tostring(d.id)))
    local ok, r = TV.Control(src, key, tostring(d.action or ''), d.value, true)
    if not ok then return false, r end
    return true, 'C\'est fait.'
end
ACTIONS.stop_all = function()
    local n = 0
    for key in pairs(TV.states) do setState(key, nil) n = n + 1 end
    return true, ('%d écran(s) coupé(s).'):format(n)
end
ACTIONS.tp = function(src, d)
    local s = TV.screens[tonumber(d.id) or -1]
    local p = s and s.data.remote
    if not p then return false, 'Écran introuvable.' end
    SetEntityCoords(GetPlayerPed(src), p.x, p.y, p.z + 1.0, false, false, false, false)
    return true, 'Téléporté à la télécommande.'
end

exports('AdminAction', function(src, name, data)
    local fn = ACTIONS[tostring(name or '')]
    if not fn then return false, 'Action inconnue.' end
    local ok, success, msg = pcall(fn, src, type(data) == 'table' and data or {})
    if not ok then print('^1[elyzea_tv] ' .. tostring(success) .. '^0') return false, 'Erreur serveur.' end
    return success, msg
end)
exports('AdminData', function()
    local list = TV.PublicScreens()
    for _, s in ipairs(list) do s.state = TV.states['s' .. s.id] end
    local flats = {}
    for key, st in pairs(TV.states) do
        local f = TV.ParseFlatKey(key)
        if f then flats[#flats + 1] = { key = key, model = flatModels[f.model], x = f.x, y = f.y, z = f.z, state = st } end
    end
    return { ready = TV.ready, screens = list, flats = flats, limits = C.Custom, now = now() }
end)

CreateThread(function()
    local ok, err = pcall(loadScreens)
    if not ok then print('^1[elyzea_tv] base de données : ' .. tostring(err) .. '^0') TV.ready = true end
    pushScreens()
end)
