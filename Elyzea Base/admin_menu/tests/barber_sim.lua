-- =====================================================================
--  Simulation HORS JEU du salon de coiffure (client/barber.lua)
--  Les natives FiveM sont imitées : personnage freemode, coupes du jeu,
--  un DLC et un pack addon de coupes (collection), chargement des modèles.
--  Ne remplace PAS un test en jeu : vérifie la logique du salon.
--  Lancement : python3 tests/run_barber_sim.py  (depuis admin_menu/)
-- =====================================================================
local ROOT = ...   -- dossier admin_menu, passé par le lanceur

local fails, passes = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1 print('  ok   ' .. msg)
    else fails = fails + 1 print('  ÉCHEC ' .. msg) end
end

-- ---------------------------------------------------------------- monde imité
local W = {}
local MALE_H, FEMALE_H = 'mp_m_freemode_01', 'mp_f_freemode_01'

-- collections : { name, count, tex, missing = { [li] = true } (modèle .ydd absent), notex = {li} }
local function makePed(model, cols)
    local ped = { model = model, cols = cols, hair = 0, hairTex = 0, color = 3, highlight = 4, eye = 2,
        overlays = {}, props = { [0] = -1, [1] = -1 }, comp1 = { 0, 0 }, preload = nil }
    -- n° globaux à la suite
    local g = 0
    ped.global = {}
    for _, c in ipairs(cols) do
        c.first = g
        for li = 0, c.count - 1 do ped.global[g] = { col = c, li = li } g = g + 1 end
    end
    ped.count = g
    return ped
end

local function femaleCols(withPack)
    local t = {
        { name = '', count = 24, tex = 3, notex = { [23] = true } },        -- jeu de base (n°23 sans texture)
        { name = 'mp_f_bikerdlc_01', count = 102, tex = 2 },               -- mises à jour du jeu → n° 24 à 125
    }
    if withPack then
        t[#t + 1] = { name = 'mp_f_vm_female_hair', count = 26, tex = 2, missing = { [14] = true } } -- n° 126 à 151
    end
    return t
end

local ped
local NUI, SERVER, TIME = {}, {}, 0
local threads = {}

local function reset(model, cols)
    ped = makePed(model, cols)
    NUI, SERVER = {}, {}
end

-- ---------------------------------------------------------------- planificateur
function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), wake = TIME } end
function Wait(ms) coroutine.yield(ms or 0) end
function SetTimeout(ms, fn) threads[#threads + 1] = { co = coroutine.create(function() Wait(ms) fn() end), wake = TIME } end
local function tick(n)
    for _ = 1, n or 1 do
        TIME = TIME + 16
        local list = threads
        threads = {}
        for _, t in ipairs(list) do
            if coroutine.status(t.co) ~= 'dead' then
                if t.wake <= TIME then
                    local ok, ms = coroutine.resume(t.co)
                    if not ok then error(ms) end
                    t.wake = TIME + (ms or 0)
                end
                if coroutine.status(t.co) ~= 'dead' then threads[#threads + 1] = t end
            end
        end
        -- préchargement : 3 images pour un modèle présent, jamais pour un modèle absent
        if ped.preload and not ped.preload.done then
            ped.preload.ticks = ped.preload.ticks + 1
            local e = ped.global[ped.preload.d]
            if e and not (e.col.missing and e.col.missing[e.li]) and ped.preload.ticks >= 3 then ped.preload.done = true end
        end
    end
end

-- ---------------------------------------------------------------- natives imitées
local events, nui = {}, {}
function RegisterNetEvent(name, fn) if fn then events[name] = fn end end
function AddEventHandler(name, fn) events[name] = fn end
function RegisterNUICallback(name, fn) nui[name] = fn end
function TriggerServerEvent(name, ...) SERVER[#SERVER + 1] = { name = name, args = { ... } } end
function TriggerEvent() end
function SendNUIMessage(m) NUI[#NUI + 1] = m end
function GetGameTimer() return TIME end
function PlayerPedId() return ped end
function GetEntityModel(p) return p.model end
function IsDuplicityVersion() return false end
function GetCurrentResourceName() return 'admin_menu' end
function NetworkIsPlayerActive() return true end
function PlayerId() return 1 end
CID = 'char1'
exports = setmetatable({ elyzea_core = { GetCitizenId = function() return CID end } }, { __call = function() end })
function Notify() end
function IsStaffMenuOpen() return false end

function GetNumberOfPedDrawableVariations(p, c) return c == 2 and p.count or 0 end
function GetNumberOfPedTextureVariations(p, c, d)
    local e = p.global[d]
    if c ~= 2 or not e then return 0 end
    if e.col.notex and e.col.notex[e.li] then return 0 end
    return e.col.tex
end
function GetPedDrawableVariation(p, c) if c == 2 then return p.hair end return p.comp1[1] end
function GetPedTextureVariation(p, c) if c == 2 then return p.hairTex end return p.comp1[2] end
function SetPedComponentVariation(p, c, d, t)
    if c == 2 then
        -- comme le jeu : un modèle absent → tête chauve
        p.hair, p.hairTex = d, t
        local e = p.global[d]
        p.bald = (not e) or (e.col.missing and e.col.missing[e.li]) or false
    elseif c == 1 then p.comp1 = { d, t } end
end
function SetPedPreloadVariationData(p, c, d, t) p.preload = { d = d, t = t, ticks = 0, done = false } end
function HasPedPreloadVariationDataFinished(p) return p.preload and p.preload.done end
function ReleasePedPreloadVariationData(p) p.preload = nil end
function GetPedHairColor(p) return p.color end
function GetPedHairHighlightColor(p) return p.highlight end
function SetPedHairColor(p, c, h) p.color, p.highlight = c, h end
function GetPedEyeColor(p) return p.eye end
function SetPedEyeColor(p, e) p.eye = e end
function GetPedHeadOverlayData(p, i) local o = p.overlays[i] return true, o and o.s or 255, 0, 0, 0, o and o.o or 1.0 end
function SetPedHeadOverlay(p, i, s, o) p.overlays[i] = { s = s, o = o } end
function SetPedHeadOverlayColor() end
function GetPedHeadOverlayNum() return 10 end
function GetPedPropIndex(p, i) return p.props[i] end
function GetPedPropTextureIndex() return 0 end
function ClearPedProp(p, i) p.props[i] = -1 end
function SetPedPropIndex(p, i, d) p.props[i] = d end
function GetNumHairColors() return 64 end
function GetPedHairRgbColor() return 10, 20, 30 end
function GetNumMakeupColors() return 64 end
function GetPedMakeupRgbColor() return 10, 20, 30 end
function GetPedBoneCoords() return { x = 0.0, y = 0.0, z = 0.0 } end
function GetEntityHeading() return 0.0 end
function IsRadarHidden() return false end
function IsEntityDead() return false end
function IsPedInAnyVehicle() return false end
function GetFrameTime() return 0.016 end
function CreateCamWithParams() return 1 end

-- natives de collection (build récent)
local function colByName(p, name) for _, c in ipairs(p.cols) do if c.name == name then return c end end end
function GetPedCollectionsCount(p) return #p.cols end
function GetPedCollectionName(p, i) return p.cols[i + 1].name end
function GetPedCollectionNameFromDrawable(p, c, d) local e = p.global[d] return e and e.col.name or '' end
function GetPedCollectionLocalIndexFromDrawable(p, c, d) local e = p.global[d] return e and e.li or -1 end
function GetPedDrawableGlobalIndexFromCollection(p, c, name, li)
    local col = colByName(p, name)
    if not col or li >= col.count then return -1 end
    return col.first + li
end
function GetNumberOfPedCollectionDrawableVariations(p, c, name) local col = colByName(p, name) return col and col.count or 0 end
function GetPedCollectionNameFromProp() return '' end
function GetPedCollectionLocalIndexFromProp() return -1 end
function GetPedPropGlobalIndexFromCollection() return -1 end
function GetNumberOfPedCollectionPropDrawableVariations() return 0 end

-- toute autre native (caméra, radar, blips…) : sans effet
local NOT_NATIVE = { ElyCloth = true, Editor = true, SavedLook = true, BarberOpen = true, Config = true, BarberData = true }
setmetatable(_G, { __index = function(_, k)
    if type(k) == 'string' and k:match('^%u') and not NOT_NATIVE[k] then return function() end end
end })

-- ---------------------------------------------------------------- chargement du code réel
local function loadFile(rel)
    local f = assert(io.open(ROOT .. '/' .. rel, 'r'))
    local src = f:read('a') f:close()
    src = src:gsub('`([^`]*)`', '"%1"')     -- hachage de modèle FiveM → chaîne
    assert(load(src, '@' .. rel))()
end
reset(FEMALE_H, femaleCols(true))
loadFile('config.lua')
Config.Barber.debug = false
loadFile('barber_data.lua')
loadFile('../elyzea_core/lib/clothing.lua')
loadFile('client/barber.lua')

local function lastNui(pred) for i = #NUI, 1, -1 do if pred(NUI[i]) then return NUI[i] end end end
local function open() events['adminmenu:barber:show']({ id = 1, name = 'Salon Prestige', prices = { hair = 150, eyes = 200, hair_color = 80 } }) tick(1) end
local function cb(name, data) nui[name](data or {}, function() end) end

-- ---------------------------------------------------------------- scénarios
print('\n[1] Femme : ouverture, liste des coupes réellement disponibles')
reset(FEMALE_H, femaleCols(true))
ped.hair, ped.hairTex = 4, 1
open()
local msg = lastNui(function(m) return m.open end)
check(msg and #msg.hairList == 151, ('151 coupes utilisables sur 152 (n°23 sans texture exclu) : %d'):format(msg and #msg.hairList or -1))
local byV = {} for _, e in ipairs(msg.hairList) do byV[e.v] = e end
check(byV[23] == nil, 'n°23 (0 texture) absent de la liste')
check(byV[130] and byV[130].c == 'mp_f_vm_female_hair' and byV[130].l == 4, 'n°130 = pack mp_f_vm_female_hair, n° local 4')
check(byV[5] and byV[5].c == nil, 'n°5 = coupe du jeu (pas de collection)')

print('\n[2] Coupe du jeu sur une femme : appliquée après chargement, jamais chauve')
cb('barber_preview', { key = 'hair', value = 10 })
check(ped.hair == 4, 'pendant le chargement, la coupe actuelle reste visible')
tick(5)
check(ped.hair == 10 and not ped.bald, 'coupe n°10 appliquée')

print('\n[3] Coupe ADDON sur une femme (n°130)')
cb('barber_preview', { key = 'hair', value = 130 })
tick(5)
check(ped.hair == 130 and ped.hairTex == 0 and not ped.bald, 'coupe addon n°130 appliquée, texture 0')

print('\n[4] Coupe addon dont le modèle manque dans le pack (n°140) : pas de tête chauve')
cb('barber_preview', { key = 'hair', value = 140 })
tick(400)  -- > 4 s
check(ped.hair == 130 and not ped.bald, 'la coupe précédente reste (n°130)')
check(lastNui(function(m) return m.event == 'hairfail' end) and lastNui(function(m) return m.event == 'hairfail' end).v == 140, 'l\'interface est prévenue (hairfail n°140)')

print('\n[5] Index invalides')
local before = ped.hair
cb('barber_set', { key = 'hair', value = 999 })
tick(5)
check(ped.hair == before and not ped.bald, 'n°999 hors limites refusé')
cb('barber_set', { key = 'hair', value = 23 })
tick(5)
check(ped.hair == before, 'n°23 (sans texture) refusé')

print('\n[6] Choix de la variante de texture, survols rapides : la dernière coupe gagne')
cb('barber_preview', { key = 'hair', value = 12 })
tick(1)
cb('barber_preview', { key = 'hair', value = 131, tex = 1 })
tick(6)
check(ped.hair == 131 and ped.hairTex == 1, 'n°131 variante 2 affichée (n°12 abandonnée)')
cb('barber_set', { key = 'hair', value = 131, tex = 1 })
tick(6)
check(ped.hair == 131 and ped.hairTex == 1, 'n°131 variante 2 ajoutée au panier, toujours visible')
cb('barber_preview', {})   -- la souris quitte la liste
tick(6)
check(ped.hair == 131 and ped.hairTex == 1, 'la coupe du panier reste après le survol')
cb('barber_set', { key = 'eyes', value = 5 })
check(ped.eye == 5, 'autre catégorie (yeux) toujours fonctionnelle')
check(ped.hair == 131, 'changer les yeux ne touche pas à la coupe')

print('\n[7] Annulation : retour à la tête d\'origine')
cb('barber_close')
tick(6)
check(ped.hair == 4 and ped.hairTex == 1 and ped.eye == 2, 'coupe n°4 texture 1 et yeux d\'origine restaurés')

print('\n[8] Validation : la coupe achetée est conservée et enregistrée avec son pack')
reset(FEMALE_H, femaleCols(true))
open()
cb('barber_set', { key = 'hair', value = 131, tex = 1 })
tick(6)
cb('barber_pay', { method = 'cash' })
local pay = SERVER[#SERVER]
check(pay and pay.name == 'adminmenu:barber:pay', 'paiement envoyé au serveur')
local look = pay.args[3]
check(look.hair == 131 and look.hairTex == 1 and look.hairCol == 'mp_f_vm_female_hair' and look.hairLi == 5, 'tête enregistrée : n°131, texture 1, pack + n° local 5')
events['adminmenu:barber:result'](true, 'Payé')
tick(80)
check(ped.hair == 131 and ped.hairTex == 1 and not ped.bald, 'après paiement et fermeture, la coupe reste')

print('\n[9] Reconnexion après ajout d\'un autre pack AVANT le pack de coupes (les n° globaux changent)')
local cols = femaleCols(false)
table.insert(cols, { name = 'autre_pack', count = 7, tex = 1 })
table.insert(cols, { name = 'mp_f_vm_female_hair', count = 26, tex = 2, missing = { [14] = true } })
reset(FEMALE_H, cols)
ped.hair = 2
events['adminmenu:barber:look'](look, 'char1')
tick(5)
check(ped.hair == 138 and ped.hairTex == 1, ('coupe retrouvée par son pack : n°138 au lieu de 131 (obtenu %d)'):format(ped.hair))

print('\n[10] Pack de coupes absent : pas de plantage, coupe actuelle conservée')
reset(FEMALE_H, femaleCols(false))
ped.hair = 6
events['adminmenu:barber:look'](look, 'char1')
tick(5)
check(ped.hair == 6 and not ped.bald, 'coupe n°6 conservée (pack absent)')
open()
local m10 = lastNui(function(m) return m.open end)
check(#m10.hairList == 125, 'salon ouvert sans le pack : 125 coupes du jeu')
cb('barber_close')
tick(6)

print('\n[11] Homme : coupe du jeu, puis coupe addon d\'un pack homme')
reset(MALE_H, { { name = '', count = 24, tex = 3 }, { name = 'mp_m_some_hair', count = 5, tex = 1 } })
ped.hair = 1
open()
cb('barber_preview', { key = 'hair', value = 7 })
tick(5)
check(ped.hair == 7, 'homme : coupe du jeu n°7')
cb('barber_preview', { key = 'hair', value = 26 })
tick(5)
check(ped.hair == 26 and not ped.bald, 'homme : coupe addon n°26 (pack mp_m_some_hair)')
cb('barber_close')
tick(6)
check(ped.hair == 1, 'homme : annulation')

print('\n[12] Tête enregistrée pour une femme non appliquée sur un homme')
events['adminmenu:barber:look'](look, 'char1')
tick(5)
check(ped.hair == 1, 'modèle différent : rien n\'est changé')

print('\n[13] Audit multipersonnage : la tête du personnage A n\'est jamais remise sur le personnage B')
reset(MALE_H, { { name = '', count = 24, tex = 3 } })
CID = 'A'
ped.hair = 2
events['adminmenu:barber:look']({ model = 'male', hair = 7, hairTex = 0 }, 'A')
tick(200)
check(ped.hair == 7, 'personnage A : sa coupe (n°7) est appliquée')
events['elyzea:client:playerUnloaded']()
CID = 'B'
ped.hair = 3                                    -- apparence de B remise par ely_creator
events['ely_creator:loaded']()
tick(200)
check(ped.hair == 3, ('personnage B : la coupe de A n\'est pas réappliquée (coupe %d)'):format(ped.hair))
local asked = false
for _, e in ipairs(SERVER) do if e.name == 'adminmenu:barber:getLook' then asked = true end end
check(asked, 'personnage B : sa propre tête est demandée au serveur')
events['adminmenu:barber:look']({ model = 'male', hair = 7, hairTex = 0 }, 'A')   -- réponse en retard pour A
tick(200)
check(ped.hair == 3, 'réponse en retard pour A : ignorée sur B')
events['adminmenu:barber:look'](false, 'B')
tick(200)
check(ped.hair == 3, 'B sans tête enregistrée : son apparence reste intacte')
events['adminmenu:barber:look']({ model = 'male', hair = 11, hairTex = 0 }, 'B')
tick(200)
check(ped.hair == 11, 'B : sa propre coupe (n°11) est appliquée')
events['elyzea:client:playerUnloaded']()
CID = 'A'
ped.hair = 2
events['ely_creator:loaded']()
tick(200)
check(ped.hair == 2, 'retour sur A : la coupe de B n\'est pas réappliquée')
events['adminmenu:barber:look']({ model = 'male', hair = 7, hairTex = 0 }, 'A')
tick(200)
check(ped.hair == 7, 'retour sur A : sa coupe revient')

print(('\nRésultat : %d réussis, %d échecs'):format(passes, fails))
return fails
