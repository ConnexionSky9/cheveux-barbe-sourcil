-- Simulation HORS JEU du serveur du salon (server/barber.lua) :
-- enregistrement de la tête (coupe de pack) et diagnostic des fichiers d'un pack addon.
-- Lancement : python3 tests/run_barber_sim.py server
local ROOT, TMP = ...
local fails, passes = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1 print('  ok   ' .. msg) else fails = fails + 1 print('  ÉCHEC ' .. msg) end
end

-- ---------------------------------------------------------------- faux pack sur le disque
local function sh(cmd) assert(os.execute(cmd)) end
local written = {}
local function write(path, content) local f = assert(io.open(path, 'w')) f:write(content or 'x') f:close() written[#written + 1] = path end
-- io.popen imité (l'interpréteur de test ne sait pas lancer de commande) : liste des fichiers écrits
local realPopen = io.popen
local function fakePopen()
    local i = 0
    return { lines = function() return function() i = i + 1 return written[i] end end, close = function() end }
end
local PACK = TMP .. '/vm_hair'
local FULL = 'mp_f_freemode_01_mp_f_vm_female_hair'
local function makePack(prefix, ymt, missing)
    sh(('rm -rf "%s" && mkdir -p "%s/stream/coupes"'):format(PACK, PACK))
    written = {}
    write(PACK .. '/' .. FULL .. '.meta', ([[<?xml version="1.0" encoding="UTF-8"?>
<ShopPedApparel>
  <pedName>mp_f_freemode_01</pedName>
  <dlcName>mp_f_vm_female_hair</dlcName>
  <fullDlcName>%s</fullDlcName>
  <eCharacter>SCR_CHAR_MULTIPLAYER_F</eCharacter>
</ShopPedApparel>]]):format(FULL))
    if ymt then write(PACK .. '/stream/' .. FULL .. '.ymt') end
    for li = 0, 25 do
        if not (missing and missing[li]) then
            write(('%s/stream/coupes/%s^hair_%03d_u.ydd'):format(PACK, prefix, li))
            write(('%s/stream/coupes/%s^hair_diff_%03d_a_uni.ytd'):format(PACK, prefix, li))
        end
    end
end

-- ---------------------------------------------------------------- natives imitées
local client = {}
local events = {}
function RegisterNetEvent(name, fn) if fn then events[name] = fn end end
function AddEventHandler(name, fn) events[name] = fn end
function TriggerClientEvent(name, src, ...) client[#client + 1] = { name = name, args = { ... } } end
function TriggerEvent() end
function exports() end
exports = setmetatable({}, { __call = function() end })
local RES = { 'admin_menu', 'vm_female_hair' }
function GetNumResources() return #RES end
function GetResourceByFindIndex(i) return RES[i + 1] end
function GetResourceState() return 'started' end
local META = {
    vm_female_hair = {
        data_file = { 'SHOP_PED_APPAREL_META_FILE' }, data_file_extra = { '"' .. FULL .. '.meta"' },
        file = { FULL .. '.meta' },
    },
}
function GetNumResourceMetadata(res, key) return META[res] and META[res][key] and #META[res][key] or 0 end
function GetResourceMetadata(res, key, i) return META[res] and META[res][key] and META[res][key][i + 1] end
function GetResourcePath(res) return res == 'vm_female_hair' and PACK or '' end
function LoadResourceFile(res, file)
    if res ~= 'vm_female_hair' then return nil end
    local f = io.open(PACK .. '/' .. file, 'r')
    if not f then return nil end
    local s = f:read('a') f:close() return s
end
local saved
Storage = { load = function() return {} end, saveLater = function(_, t) saved = t end }
Bridge = { GetCharId = function() return 'char1' end, GetMoney = function() return 1000 end, RemoveMoney = function() return true end, GetLabel = function() end }
AdminMenu = { rateLimit = function() return true end, getLicense = function() return 'lic' end,
    EditorPeds = { check = function() return { id = 1, npc = { payment = 'cash', barber = { prices = { hair = 150 }, services = {}, payChoice = true } } } end } }

local function loadFile(rel)
    local f = assert(io.open(ROOT .. '/' .. rel, 'r'))
    local src = f:read('a') f:close()
    src = src:gsub('`([^`]*)`', '"%1"')
    assert(load(src, '@' .. rel))()
end
loadFile('config.lua')
loadFile('barber_data.lua')
Config.Barber.debug = true
loadFile('server/barber.lua')

-- ---------------------------------------------------------------- scénarios
print('\n[S1] Paiement : la tête enregistrée garde le pack, le n° local et la texture')
source = 7
events['adminmenu:barber:pay'](1, { hair = 131 }, { model = 'female', hair = 131, hairTex = 1, hairCol = 'mp_f_vm_female_hair', hairLi = 5, hair_color = 3, hair_highlight = 4 }, 'cash')
check(saved and saved.char1 and saved.char1.hairCol == 'mp_f_vm_female_hair' and saved.char1.hairLi == 5 and saved.char1.hairTex == 1, 'tête enregistrée avec hairCol / hairLi / hairTex')
events['adminmenu:barber:pay'](1, { hair = 131 }, { model = 'female', hair = 131, hairCol = 'x"; DROP', hairLi = 5 }, 'cash')
check(saved.char1.hairCol == nil, 'nom de collection invalide ignoré')

local function run(noList)
    client = {}
    io.popen = (not noList) and fakePopen or nil
    events['adminmenu:barber:checkPacks']('mp_f_freemode_01', { { col = 'mp_f_vm_female_hair', first = 126, count = 26 } })
    local all = {}
    for _, c in ipairs(client) do all[#all + 1] = c.args[1] end
    return table.concat(all, '\n')
end

print('\n[S2] Pack correct (fichiers dans un sous-dossier de stream/)')
makePack(FULL, true)
local out = run()
check(out:find('ressource « vm_female_hair »', 1, true) ~= nil, 'ressource du pack retrouvée par le .meta')
check(out:find('.ymt', 1, true) and out:find('trouvé', 1, true), '.ymt trouvé')
check(out:find('.ydd manquants : 0', 1, true) ~= nil, 'aucun .ydd manquant')

print('\n[S3] Pack mal nommé (préfixe « mp_f_freemode_01^ » au lieu de la collection) et .ymt absent')
makePack('mp_f_freemode_01', false)
out = run()
check(out:find('MANQUANT', 1, true) ~= nil, '.ymt signalé manquant')
check(out:find('.ydd manquants : 26', 1, true) ~= nil, '26 .ydd au mauvais nom détectés')
check(out:find('CHAUVES', 1, true) ~= nil, 'explication : coupes chauves')
check(out:find('« mp_f_freemode_01^hair_… »', 1, true) ~= nil, 'mauvais préfixe trouvé et nommé')

print('\n[S4] Pack avec 2 coupes sans modèle')
makePack(FULL, true, { [3] = true, [14] = true })
out = run()
check(out:find('.ydd manquants : 2', 1, true) and out:find('3, 14', 1, true), 'n° locaux 3 et 14 signalés')

print('\n[S5] Serveur sans liste des dossiers : recherche aux emplacements habituels')
makePack(FULL, true)
sh(('mv "%s/stream/coupes/"* "%s/stream/"'):format(PACK, PACK))
out = run(true)
check(out:find('recherche limitée', 1, true) and out:find('.ydd manquants : 0', 1, true), 'fichiers trouvés à la racine de stream/ sans liste')

print(('\nRésultat : %d réussis, %d échecs'):format(passes, fails))
sh(('rm -rf "%s"'):format(PACK))
return fails
