-- =====================================================================
--  Appli Identité : vrais fichiers serveur (elyzea_papiers + elyzea_aura)
-- =====================================================================
--@@MOCKS@@
-- Fonctions FiveM inconnues : sans effet (le gros fichier du téléphone en appelle beaucoup au chargement)
local function permissive(env)
    return setmetatable(env, { __index = function(_, k)
        local v = rawget(_G, k)
        if v ~= nil then return v end
        if type(k) == 'string' and k:match('^%u') then return function() end end
    end })
end
MySQL.ready = function(fn) fn() end
-- Threads : exécutés jusqu'à leur premier Wait (les boucles infinies s'arrêtent là)
function CreateThread(fn) local co = coroutine.create(fn) local ok, err = coroutine.resume(co) if not ok then error(err) end end
Citizen = { CreateThread = CreateThread, Wait = function() end }
function Wait() if coroutine.isyieldable() then coroutine.yield() end end
function SetTimeout() end
function LoadResourceFile(res, path) local ok, s = pcall(py_read, res .. '/' .. path) return ok and s or nil end
MySQL.prepare = MySQL.query
function GetPlayerPing() return 30 end
function GetPlayerIdentifiers() return {} end
function GetEntityHeading() return 0.0 end
function RegisterCommand() end
Notified = {}
-- Joueurs : A (citoyen, a ses papiers), P (policier en service), C (civil)
local PLAYERS = {
    [1] = { cid = 'CID_A', ci = { firstname = 'Léna', lastname = 'Duval', birthdate = '1998-04-12', gender = 1 }, md = { idcard = 'ID-482913', licences = { driver = true, moto = true, weapon = true } }, job = { name = 'unemployed' } },
    [2] = { cid = 'CID_P', ci = { firstname = 'Marc', lastname = 'Vidal', birthdate = '1990-01-01', gender = 0 }, md = {}, job = { name = 'police', onduty = true } },
    [3] = { cid = 'CID_C', ci = { firstname = 'Inès', lastname = 'Morel', birthdate = '1995-05-05', gender = 1 }, md = {}, job = { name = 'unemployed' } },
}
Pos = { [1] = vector3(0, 0, 0), [2] = vector3(1.5, 0, 0), [3] = vector3(2.0, 1, 0) }
function GetPlayerPed(s) return PLAYERS[tonumber(s)] and ('ped' .. s) or 0 end
function GetEntityCoords(e) return Pos[tonumber(tostring(e):sub(4))] end
function GetPlayerName(s) return PLAYERS[tonumber(s)] and ('J' .. s) or nil end
function GetPlayers() return { '1', '2', '3' } end
local function pobj(s)
    local p = PLAYERS[tonumber(s)]; if not p then return nil end
    return { PlayerData = { source = s, citizenid = p.cid, charinfo = p.ci, metadata = p.md, job = p.job },
        Functions = { GetMoney = function() return 0 end, SetMetaData = function(k, v) p.md[k] = v end } }
end
INV = { [1] = { carte_identite = { { slot = 1, metadata = { number = 'ID-482913', issued = '02/11/2026', citizenid = 'CID_A' } } },
               ppa = { { slot = 2, metadata = { number = 'PPA-551204', kind = 'civil', issued = '01/11/2026', citizenid = 'CID_A', categories = { 'Pistolet' } } } } } }
Registry.elyzea_core = {
    GetPlayer = pobj,
    GetPlayerByCitizenId = function(cid) for s, p in pairs(PLAYERS) do if p.cid == cid then return pobj(s) end end end,
    GetSourceByCitizenId = function(cid) for s, p in pairs(PLAYERS) do if p.cid == cid then return s end end end,
    Notify = function(s, msg, kind) Notified[#Notified + 1] = { s = s, msg = msg, kind = kind } end,
    SetMetadata = function(s, k, v) PLAYERS[s].md[k] = v return true end,
    GetCharName = function(s) local c = PLAYERS[s].ci return c.firstname .. ' ' .. c.lastname end,
    GetCitizenId = function(s) return PLAYERS[s].cid end,
}
Registry.elyzea_inventory = { Search = function(s, kind, item) return (INV[s] or {})[item] or {} end }
Registry.elyzea_permis = { GetLicenses = function(cid)
    local r = py_single('SELECT licenses, number FROM elyzea_permis WHERE citizenid = ?', { cid })
    if not r then return { licenses = {} } end
    return { number = r.number, licenses = json.decode(r.licenses) }
end }
Registry.elyzea_police = { IsPolice = function(s) return PLAYERS[s].job.name == 'police' end, IsOnDuty = function(s) return PLAYERS[s].job.onduty == true end }
Registry.elyzea_papiers = {}; Registry.elyzea_aura = {}
Started = { elyzea_papiers = true, elyzea_permis = true, elyzea_police = true, elyzea_core = true, elyzea_inventory = true }

-- Chargement dans l'ordre de FiveM, chaque ressource dans son environnement
local function load2(res, files)
    local env = permissive({ exports = nil })
    local e = loadResource(res, {})          -- crée l'objet exports de la ressource
    env.exports = e.exports
    env.GetCurrentResourceName = function() return res end
    for _, f in ipairs(files) do assert(load(py_read(f), '@' .. f, 't', env))() end
    Envs[res] = env
    return env
end
local PA = load2('elyzea_papiers', { 'elyzea_papiers/config.lua', 'elyzea_papiers/server_identity.lua' })
local AU = load2('elyzea_aura', { 'elyzea_aura/config.lua', 'elyzea_aura/server/main.lua' })
local function call(name, src, args)
    local reply
    TriggerClientEvent = function(n, s, ...) local a = { ... } Sent[#Sent + 1] = { name = n, src = s, args = a } if n == 'elyzea_aura:client:cb' then reply = a[2] end end
    fire('elyzea_aura:server:cb', src, name, 1, args or {})
    return reply
end
local function out(s, on) fire('elyzea_aura:server:phoneOut', s, on) end
py_query('SELECT 1')

print('— Documents')
local r = call('idDocs', 1)
check(r and r.ok and r.docs.id and r.docs.id.data.number == 'ID-482913', 'carte d\'identité trouvée (objet au nom du joueur)')
check(r.docs.licence and #r.docs.licence.data.categories == 2 and r.docs.licence.data.number == 'EL-104223', 'permis : catégories B et A (elyzea_permis)')
check(r.docs.ppa and r.docs.ppa.sub == 'civil' and not r.docs.ppa.suspended, 'PPA civil, non suspendu')
check(r.police == false, 'citoyen : pas de droit de suspension')
check(call('idDocs', 2).police == true, 'policier en service : droit de suspension')
local rc = call('idDocs', 3)
check(rc.ok and next(rc.docs) == nil, 'joueur sans papiers : aucune carte')

print('— Téléphone sorti obligatoire')
out(1, false) out(2, false) out(3, false)
local nb = call('idNearby', 1)
check(nb.ok and #nb.devices == 0, 'téléphone rangé : personne n\'apparaît')
out(1, true)
check(#call('idNearby', 1).devices == 0, 'autres téléphones rangés : invisibles')
out(2, true)
local nb2 = call('idNearby', 1)
check(#nb2.devices == 1 and nb2.devices[1].id == 2, 'seul le téléphone sorti (policier) est visible')
local sR = call('idShow', 1, { id = 3, kind = 'id' })
check(not sR.ok and sR.error:find('rangé'), 'montrer à un téléphone rangé : refusé')
-- AuraDrop : même règle
check(#call('getNearby', 1).devices == 1, 'AuraDrop : seul le téléphone sorti apparaît')
local dR = call('auraDropSend', 1, { id = 3 })
check(not dR.ok and dR.error:find('rangé'), 'AuraDrop vers un téléphone rangé : refusé')
out(1, false)
check(#call('getNearby', 1).devices == 0, 'AuraDrop : mon téléphone rangé → je ne vois personne')
out(1, true)

print('— Montrer, enregistrer')
Sent = {}
local show = call('idShow', 1, { id = 2, kind = 'licence' })
check(show.ok, 'permis montré au policier')
local ev = lastSent('elyzea_aura:client:idCard', 2)
check(ev and ev.args[1].doc.type == 'licence' and ev.args[1].police == true, 'le policier reçoit la carte (et peut la suspendre)')
local shareId = ev.args[1].shareId
check(not call('idSave', 3, { shareId = shareId }).ok, 'un autre joueur ne peut pas enregistrer cette carte')
local sv = call('idSave', 2, { shareId = shareId })
check(sv.ok, 'carte enregistrée dans la galerie du policier')
local n = lastSent('elyzea_aura:client:notify', 1)
check(n and n.args[1].key == 'idSaved', 'le propriétaire est prévenu : « … a enregistré votre permis »')
check(not call('idSave', 2, { shareId = shareId }).ok, 'pas de double enregistrement')
local g = call('getGallery', 2)
check(g.ok and g.photos[1].type == 'card' and g.photos[1].card.type == 'licence', 'galerie : la carte est relue avec ses données')
check(call('idSaveOwn', 1, { kind = 'ppa' }).ok, 'enregistrer sa propre carte dans sa galerie')
check(not call('idSaveOwn', 3, { kind = 'ppa' }).ok, 'impossible d\'enregistrer une carte qu\'on n\'a pas')

print('— Suspensions (police)')
local s1 = call('idSuspend', 2, { shareId = shareId, what = 'moto', on = true, reason = 'Grand excès de vitesse' })
check(s1.ok, 'permis moto suspendu')
local cats = {}
for _, c in ipairs(s1.doc.data.categories) do cats[c.key] = c.suspended end
check(cats.moto == true and cats.car == false, 'seule la catégorie moto est « SUSPENDU »')
check(PLAYERS[1].md.licences.moto == false and PLAYERS[1].md.licences.driver == true, 'personnage : permis moto retiré, voiture gardé')
check(py_scalar("SELECT COUNT(*) FROM elyzea_doc_suspensions WHERE citizenid='CID_A' AND kind='moto'") == 1, 'suspension enregistrée en base')
local nt = Notified[#Notified - 1]
check(nt and nt.s == 1 and nt.msg:find('suspendu') and nt.msg:find('Grand excès'), 'la personne est prévenue (avec le motif)')
local s2 = call('idSuspend', 2, { shareId = shareId, what = 'licence', on = true })
check(s2.ok, 'tout le permis suspendu')
local all = true for _, c in ipairs(s2.doc.data.categories) do all = all and c.suspended end
check(all and PLAYERS[1].md.licences.driver == false, 'toutes les catégories « SUSPENDU », permis voiture retiré')
check(call('idDocs', 1).docs.licence ~= nil, 'la carte ne disparaît pas')
check(not call('idSuspend', 3, { shareId = shareId, what = 'car', on = false }).ok, 'un autre joueur ne peut pas rétablir')
Pos[2] = vector3(30, 0, 0)
check(not call('idSuspend', 2, { shareId = shareId, what = 'car', on = false }).ok, 'policier trop loin : refusé')
Pos[2] = vector3(1.5, 0, 0)
PLAYERS[2].job.onduty = false
check(not call('idSuspend', 2, { shareId = shareId, what = 'car', on = false }).ok, 'policier hors service : refusé')
PLAYERS[2].job.onduty = true
local s3 = call('idSuspend', 2, { shareId = shareId, what = 'car', on = false })
check(s3.ok and PLAYERS[1].md.licences.driver == true, 'permis voiture rétabli')
-- PPA
Sent = {}
call('idShow', 1, { id = 2, kind = 'ppa' })
local sid2 = lastSent('elyzea_aura:client:idCard', 2).args[1].shareId
local s4 = call('idSuspend', 2, { shareId = sid2, what = 'ppa', on = true, reason = 'Arme en état d\'ivresse' })
check(s4.ok and s4.doc.suspended == true and PLAYERS[1].md.licences.weapon == false, 'PPA suspendu : « SUSPENDU », port d\'arme retiré')
-- La carte montrée ensuite porte la suspension
Sent = {}
out(3, true)
call('idShow', 1, { id = 3, kind = 'ppa' })
local ev3 = lastSent('elyzea_aura:client:idCard', 3)
check(ev3 and ev3.args[1].doc.suspended == true and ev3.args[1].police == false, 'montrée à un autre joueur : le PPA s\'affiche SUSPENDU (et il ne peut rien modifier)')
check(not call('idSuspend', 3, { shareId = ev3.args[1].shareId, what = 'ppa', on = false }).ok, 'un civil ne peut pas rétablir le PPA')
-- État « en main » (objet de l'inventaire) : par citizenid ou numéro de permis
TriggerClientEvent = function(nm, s, ...) Sent[#Sent + 1] = { name = nm, src = s, args = { ... } } end
fire('elyzea_papiers:docState', 3, 'permis:1', nil, 'EL-104223')
local st = lastSent('elyzea_papiers:docStateReply', 3)
check(st and st.args[2].moto == true and st.args[2].car == false and st.args[2].ppa == true, 'permis montré en main (ancien objet sans citizenid) : moto et PPA suspendus')
print(('\nidentité : %d ok, %d échec(s)'):format(Oks, Fails))
