-- =====================================================================
--  ELYZEA LOISIRS - serveur : installations (pistes, tables, parcours), utilitaires, admin
--  Les installations sont posées en jeu depuis le menu admin (onglet « Loisirs ») et enregistrées
--  en base (table loisirs_installations, créée toute seule).
-- =====================================================================
LS = {
    ready = false,
    inst = {},          -- [id] = { id, kind = 'bowling'|'billiards'|'golf', name, data }
    Games = {},         -- modules de jeu (server/bowling.lua …)
}
local core = exports.elyzea_core

local function dbg(...) if Config.Debug then print('[elyzea_loisirs]', ...) end end
LS.dbg = dbg

-- ---------------------------------------------------------------- joueurs
function LS.Name(src)
    local ok, p = pcall(function() return core:GetPlayer(src) end)
    if ok and p and p.PlayerData and p.PlayerData.charinfo then
        local ci = p.PlayerData.charinfo
        local n = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
        if n ~= '' then return n end
    end
    return GetPlayerName(src) or ('#' .. tostring(src))
end
function LS.Cid(src)
    local ok, cid = pcall(function() return core:GetCitizenId(src) end)
    return ok and cid or nil
end
function LS.Online(src) return src and GetPlayerName(src) ~= nil and LS.Cid(src) ~= nil end
function LS.Pos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end
function LS.Down(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return true end
    if Player(src).state.emsDown then return true end
    return GetEntityHealth(ped) <= 0
end
function LS.Notify(src, msg, kind) TriggerClientEvent('elyzea:client:notify', src, msg, kind or 'inform') end

-- Limite de fréquence par joueur et par clé
local rate = {}
function LS.Rate(src, key, count, window)
    local now = GetGameTimer()
    rate[src] = rate[src] or {}
    local r = rate[src][key]
    if not r or now - r.t > window then r = { t = now, n = 0 } rate[src][key] = r end
    r.n = r.n + 1
    return r.n <= count
end
AddEventHandler('playerDropped', function() rate[source] = nil end)

-- Argent (droits d'entrée) : retire / rend sur le compte configuré
function LS.Charge(src, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    local ok, p = pcall(function() return core:GetPlayer(src) end)
    if not ok or not p or not p.Functions then return false end
    return p.Functions.RemoveMoney(Config.Account, amount, reason) == true
end
function LS.Refund(src, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or not GetPlayerName(src) then return end
    local ok, p = pcall(function() return core:GetPlayer(src) end)
    if ok and p and p.Functions then p.Functions.AddMoney(Config.Account, amount, reason) end
end

-- ---------------------------------------------------------------- installations
local function decode(s) local ok, v = pcall(json.decode, s or '') return ok and type(v) == 'table' and v or nil end

-- Position de référence d'une installation (pour les distances)
function LS.InstPos(inst)
    local d = inst.data
    if inst.kind == 'golf' then
        local h = d.holes and d.holes[1]
        return h and h.tee and vector3(h.tee.x, h.tee.y, h.tee.z) or nil
    end
    return vector3(d.x, d.y, d.z)
end

-- Liste envoyée aux clients (données publiques uniquement)
function LS.PublicInstallations()
    local out = {}
    for id, i in pairs(LS.inst) do out[#out + 1] = { id = id, kind = i.kind, name = i.name, data = i.data } end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end
function LS.PushInstallations(target)
    TriggerLatentClientEvent('elyzea_loisirs:client:installations', target or -1, 100000, LS.PublicInstallations())
end

local function validKind(k) return k == 'bowling' or k == 'billiards' or k == 'golf' or k == 'pole' end

function LS.SaveInstallation(inst)
    local data = json.encode(inst.data)
    if inst.id then
        MySQL.update.await('UPDATE `loisirs_installations` SET `name` = ?, `data` = ? WHERE `id` = ?', { inst.name, data, inst.id })
    else
        inst.id = MySQL.insert.await('INSERT INTO `loisirs_installations` (`kind`, `name`, `data`) VALUES (?, ?, ?)', { inst.kind, inst.name, data })
    end
    LS.inst[inst.id] = inst
    LS.PushInstallations()
    return inst.id
end

function LS.DeleteInstallation(id)
    if not LS.inst[id] then return false end
    if LS.Sessions and LS.Sessions.CancelForInstallation then LS.Sessions.CancelForInstallation(id, 'Installation retirée par le staff.') end
    if LS.Pole and LS.Pole.OnDelete then LS.Pole.OnDelete(id) end
    MySQL.update.await('DELETE FROM `loisirs_installations` WHERE `id` = ?', { id })
    LS.inst[id] = nil
    LS.PushInstallations()
    return true
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `loisirs_installations` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `kind` VARCHAR(16) NOT NULL,
        `name` VARCHAR(60) NOT NULL DEFAULT '',
        `data` LONGTEXT NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ) DEFAULT CHARSET=utf8mb4]])
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `loisirs_installations`') or {}) do
        local data = decode(r.data)
        if data and validKind(r.kind) then
            LS.inst[tonumber(r.id)] = { id = tonumber(r.id), kind = r.kind, name = r.name, data = data }
        else
            print(('^3[elyzea_loisirs] Installation #%s illisible : ignorée.^0'):format(tostring(r.id)))
        end
    end
    LS.ready = true
    local n = 0 for _ in pairs(LS.inst) do n = n + 1 end
    print(('^2[elyzea_loisirs] Prêt : %d installation(s) (bowling, billard, golf).^0'):format(n))
    LS.PushInstallations()
end)

Ely.callback.register('loisirs:installations', function(src)
    while not LS.ready do Wait(200) end
    return LS.PublicInstallations()
end)

-- ---------------------------------------------------------------- menu admin (admin_menu › Loisirs)
-- La permission est vérifiée par admin_menu (« loisirs_manage ») avant tout appel ; tout est revalidé ici.
local function here(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    -- GetEntityCoords d'un joueur = bassin (≈ 1 m au-dessus du sol) : on garde la hauteur du sol
    return { x = LU.round(c.x, 3), y = LU.round(c.y, 3), z = LU.round(c.z - 1.0, 3), h = LU.round(GetEntityHeading(ped), 2) }
end

local pendingScan = {}
RegisterNetEvent('elyzea_loisirs:server:scanResult', function(token, res)
    local src = source
    local p = pendingScan[src]
    if not p or p.token ~= token then return end
    pendingScan[src] = nil
    p.cb(type(res) == 'table' and res or nil)
end)
-- Demande au client du staff un objet du décor : table de billard la plus proche, ou quille n°1 d'une piste du MLO
local function scanTable(src, event)
    local pr = promise.new()
    local token = math.random(1, 1e9)
    pendingScan[src] = { token = token, cb = function(r) pr:resolve(r) end }
    TriggerClientEvent(event or 'elyzea_loisirs:client:scanTable', src, token)
    SetTimeout(4000, function() if pendingScan[src] and pendingScan[src].token == token then pendingScan[src] = nil pr:resolve(nil) end end)
    return Citizen.Await(pr)
end

local function holeDefaults(pos)
    return { tee = { x = pos.x, y = pos.y, z = pos.z, h = pos.h }, flag = nil, par = Config.Golf.defaultPar,
        greenR = Config.Golf.defaultGreenRadius, fairwayW = Config.Golf.defaultFairwayWidth, hazards = {} }
end

local ACTIONS = {}
ACTIONS.add_bowling = function(src, d)
    local p = here(src)
    if not p then return false, 'Position introuvable.' end
    local name = LU.trim(d.name, 40)
    if d.align then
        -- la quille n°1 du décor fixe l'axe et la distance : ligne de faute 18,29 m avant elle, dans l'axe staff → quille
        local q = scanTable(src, 'elyzea_loisirs:client:scanPins')
        if not q or not tonumber(q.x) or not tonumber(q.y) then return false, 'Aucune quille du décor trouvée devant toi (8 à 30 m). Regarde vers les quilles, ou vérifie hideModels.' end
        local dx, dy = q.x - p.x, q.y - p.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < 8.0 or dist > 30.0 then return false, 'Quille trop près ou trop loin.' end
        local h = math.deg(math.atan(-dx, dy)) % 360
        local L = Config.Bowling.laneLength
        local fx, fy = q.x - dx / dist * L, q.y - dy / dist * L
        LS.SaveInstallation({ kind = 'bowling', name = name ~= '' and name or 'Piste de bowling',
            data = { x = LU.round(fx, 3), y = LU.round(fy, 3), z = p.z, h = LU.round(h, 2) } })
        return true, ('Piste alignée sur les quilles du décor (ligne de faute à %.1f m devant la quille de tête).'):format(L)
    end
    LS.SaveInstallation({ kind = 'bowling', name = name ~= '' and name or 'Piste de bowling', data = { x = p.x, y = p.y, z = p.z, h = p.h } })
    return true, 'Piste posée : la ligne de faute est à tes pieds, la piste part devant toi.'
end
ACTIONS.add_billiards = function(src, d)
    local p = here(src)
    if not p then return false, 'Position introuvable.' end
    local name = LU.trim(d.name, 40)
    local data
    if d.existing then
        local t = scanTable(src)
        if not t or not t.x then return false, 'Aucune table de billard du jeu à moins de 4 m.' end
        local pos = LS.Pos(src)
        if not pos or #(pos - vector3(t.x, t.y, t.z)) > 6.0 then return false, 'Table trop loin.' end
        data = { x = LU.round(t.x, 3), y = LU.round(t.y, 3), z = LU.round(t.z, 3), h = LU.round(tonumber(t.h) or 0, 2), model = t.model, spawn = false }
    else
        local model = Config.Billiards.tables[d.model or ''] and d.model or Config.Billiards.defaultModel
        -- la table est posée devant le staff, dans l'axe de son regard
        local fx, fy = LU.toWorld(p.x, p.y, p.h, 0.0, 1.6)
        data = { x = LU.round(fx, 3), y = LU.round(fy, 3), z = p.z, h = p.h, model = model, spawn = true }
    end
    LS.SaveInstallation({ kind = 'billiards', name = name ~= '' and name or 'Table de billard', data = data })
    return true, data.spawn and 'Table posée devant toi.' or 'Table du jeu enregistrée.'
end
ACTIONS.billiards_calib = function(src, d)
    local inst = LS.inst[tonumber(d.id) or -1]
    if not inst or inst.kind ~= 'billiards' then return false, 'Table introuvable.' end
    local c = inst.data.calib or {}
    c.length = LU.num(d.length, 1.5, 3.2) or c.length
    c.width = LU.num(d.width, 0.7, 1.7) or c.width
    c.height = LU.num(d.height, 0.3, 1.5) or c.height
    inst.data.calib = c
    LS.SaveInstallation(inst)
    return true, 'Dimensions de la table enregistrées.'
end
-- Barre de pole dance : neuve (posée à tes pieds) ou barre du décor la plus proche (club de strip-tease…)
ACTIONS.add_pole = function(src, d)
    local p = here(src)
    if not p then return false, 'Position introuvable.' end
    local name = LU.trim(d.name, 40)
    local data
    if d.existing then
        local t = scanTable(src, 'elyzea_loisirs:client:scanPole')
        if not t or not tonumber(t.x) then return false, ('Aucune barre du décor (%s) à moins de 4 m.'):format(Config.Pole.model) end
        local pos = LS.Pos(src)
        if not pos or #(pos - vector3(t.x, t.y, t.z)) > 6.0 then return false, 'Barre trop loin.' end
        data = { x = LU.round(t.x, 3), y = LU.round(t.y, 3), z = LU.round(tonumber(t.z) or p.z, 3), h = p.h, spawn = false }
    else
        data = { x = p.x, y = p.y, z = p.z, h = p.h, spawn = true }
    end
    LS.SaveInstallation({ kind = 'pole', name = name ~= '' and name or 'Barre de pole dance', data = data })
    return true, data.spawn and 'Barre posée à tes pieds : écarte-toi pour la voir. La danse se fait face à la direction où tu regardais.'
        or 'Barre du décor enregistrée : la danse se fait face à la direction où tu regardes.'
end
ACTIONS.pole_calib = function(src, d)
    local inst = LS.inst[tonumber(d.id) or -1]
    if not inst or inst.kind ~= 'pole' then return false, 'Barre introuvable.' end
    local c = inst.data
    if d.here then
        local p = here(src)
        if p then c.h = p.h end
    end
    local h = LU.num(d.h, 0, 360) if h then c.h = h end
    local z = LU.num(d.oz, -1.5, 1.5) if z then c.oz = z end
    local ox = LU.num(d.ox, -1.0, 1.0) if ox then c.ox = ox end
    local oy = LU.num(d.oy, -1.0, 1.0) if oy then c.oy = oy end
    LS.SaveInstallation(inst)
    return true, 'Réglage de la barre enregistré.'
end
-- Réglage en direct : le staff danse sur la barre et la cale aux flèches ; ENTRÉE enregistre (jeton valable 15 min)
ACTIONS.pole_calib_live = function(src, d)
    local inst = LS.inst[tonumber(d.id) or -1]
    if not inst or inst.kind ~= 'pole' then return false, 'Barre introuvable.' end
    local token = LS.Pole.NewCalib(src, inst.id)
    TriggerClientEvent('elyzea_loisirs:client:poleCalibrate', src, inst.id, token)
    return true, 'Réglage en direct : va à la barre, appuie sur E, puis flèches / Page préc. / Page suiv. (MAJ = pas de 5 cm), ENTRÉE pour enregistrer.'
end
ACTIONS.pole_stop = function(src, d)
    if not LS.Pole or not LS.Pole.OnDelete then return false, 'Indisponible.' end
    LS.Pole.OnDelete(tonumber(d.id) or -1)
    return true, 'Danse arrêtée.'
end
ACTIONS.add_course = function(src, d)
    local name = LU.trim(d.name, 40)
    LS.SaveInstallation({ kind = 'golf', name = name ~= '' and name or 'Parcours de golf', data = { holes = {} } })
    return true, 'Parcours créé : ajoute maintenant ses trous (départ puis drapeau).'
end
local function course(d)
    local inst = LS.inst[tonumber(d.id) or -1]
    if not inst or inst.kind ~= 'golf' then return nil end
    return inst
end
ACTIONS.hole_tee = function(src, d)
    local inst = course(d)
    if not inst then return false, 'Parcours introuvable.' end
    local p = here(src)
    local holes = inst.data.holes
    local idx = tonumber(d.hole)
    if idx and holes[idx] then holes[idx].tee = { x = p.x, y = p.y, z = p.z, h = p.h }
    else
        if #holes >= 18 then return false, '18 trous maximum.' end
        holes[#holes + 1] = holeDefaults(p)
        idx = #holes
    end
    LS.SaveInstallation(inst)
    return true, ('Trou %d : départ posé. Va au drapeau et clique « Drapeau ici ».'):format(idx)
end
ACTIONS.hole_flag = function(src, d)
    local inst = course(d)
    local h = inst and inst.data.holes[tonumber(d.hole) or -1]
    if not h then return false, 'Trou introuvable.' end
    local p = here(src)
    if LU.dist2(p.x, p.y, h.tee.x, h.tee.y) < 20 then return false, 'Le drapeau doit être à plus de 20 m du départ.' end
    h.flag = { x = p.x, y = p.y, z = p.z }
    LS.SaveInstallation(inst)
    return true, ('Drapeau posé (%.0f m du départ).'):format(LU.dist2(p.x, p.y, h.tee.x, h.tee.y))
end
ACTIONS.hole_set = function(src, d)
    local inst = course(d)
    local h = inst and inst.data.holes[tonumber(d.hole) or -1]
    if not h then return false, 'Trou introuvable.' end
    h.par = math.floor(LU.num(d.par, 3, 6) or h.par)
    h.greenR = LU.num(d.greenR, 5, 40) or h.greenR
    h.fairwayW = LU.num(d.fairwayW, 10, 120) or h.fairwayW
    LS.SaveInstallation(inst)
    return true, 'Trou enregistré.'
end
ACTIONS.hole_hazard = function(src, d)
    local inst = course(d)
    local h = inst and inst.data.holes[tonumber(d.hole) or -1]
    if not h then return false, 'Trou introuvable.' end
    local t = tostring(d.type or '')
    if t ~= 'water' and t ~= 'bunker' and t ~= 'ob' and t ~= 'lost' then return false, 'Type de zone inconnu.' end
    local r = LU.num(d.radius, 2, 150)
    if not r then return false, 'Rayon invalide (2 à 150 m).' end
    if #h.hazards >= 30 then return false, '30 zones maximum par trou.' end
    local p = here(src)
    h.hazards[#h.hazards + 1] = { type = t, x = p.x, y = p.y, r = r }
    LS.SaveInstallation(inst)
    return true, 'Zone ajoutée autour de toi.'
end
ACTIONS.hazard_del = function(src, d)
    local inst = course(d)
    local h = inst and inst.data.holes[tonumber(d.hole) or -1]
    if not h or not h.hazards[tonumber(d.index) or -1] then return false, 'Zone introuvable.' end
    table.remove(h.hazards, tonumber(d.index))
    LS.SaveInstallation(inst)
    return true, 'Zone supprimée.'
end
ACTIONS.hole_del = function(src, d)
    local inst = course(d)
    if not inst or not inst.data.holes[tonumber(d.hole) or -1] then return false, 'Trou introuvable.' end
    if LS.Sessions.ActiveFor(inst.id) then return false, 'Une partie est en cours sur ce parcours.' end
    table.remove(inst.data.holes, tonumber(d.hole))
    LS.SaveInstallation(inst)
    return true, 'Trou supprimé.'
end
ACTIONS.rename = function(src, d)
    local inst = LS.inst[tonumber(d.id) or -1]
    if not inst then return false, 'Installation introuvable.' end
    local name = LU.trim(d.name, 40)
    if name == '' then return false, 'Nom vide.' end
    inst.name = name
    LS.SaveInstallation(inst)
    return true, 'Renommé.'
end
ACTIONS.delete = function(src, d)
    if not LS.DeleteInstallation(tonumber(d.id) or -1) then return false, 'Installation introuvable.' end
    return true, 'Installation supprimée (partie en cours annulée et remboursée si besoin).'
end
ACTIONS.tp = function(src, d)
    local inst = LS.inst[tonumber(d.id) or -1]
    local p = inst and LS.InstPos(inst)
    if not p then return false, 'Installation introuvable.' end
    SetEntityCoords(GetPlayerPed(src), p.x, p.y, p.z + 1.0, false, false, false, false)
    return true, 'Téléporté.'
end
ACTIONS.cancel_session = function(src, d)
    if not LS.Sessions.Cancel(tonumber(d.session) or -1, 'Partie annulée par le staff.') then return false, 'Partie introuvable.' end
    return true, 'Partie annulée (droits d\'entrée remboursés si elle n\'avait pas commencé).'
end

-- Appelé par admin_menu (server/loisirs.lua) après vérification de la permission
exports('AdminAction', function(src, name, data)
    local fn = ACTIONS[tostring(name or '')]
    if not fn then return false, 'Action inconnue.' end
    if not LS.Rate(src, 'admin', 8, 4000) then return false, 'Trop rapide.' end
    local ok, success, msg = pcall(fn, src, type(data) == 'table' and data or {})
    if not ok then print('^1[elyzea_loisirs] ' .. tostring(success) .. '^0') return false, 'Erreur serveur.' end
    return success, msg
end)

exports('AdminData', function()
    local list = {}
    for _, i in pairs(LS.inst) do
        local item = { id = i.id, kind = i.kind, name = i.name, data = i.data }
        item.session = LS.Sessions and LS.Sessions.ActiveFor(i.id) or nil
        if i.kind == 'pole' and LS.Pole then item.dancer = LS.Pole.DancerOf(i.id) end
        list[#list + 1] = item
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    local sessions = {}
    for _, s in pairs(LS.Sessions and LS.Sessions.all or {}) do
        sessions[#sessions + 1] = { id = s.id, game = s.game, name = s.name, state = s.state, inst = s.inst, players = #s.order, host = LS.Name(s.host) }
    end
    return { installations = list, sessions = sessions, games = Config.Games, ready = LS.ready }
end)
