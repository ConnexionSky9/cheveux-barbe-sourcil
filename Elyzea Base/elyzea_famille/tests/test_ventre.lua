-- Test hors du jeu du ventre de grossesse (shared/ventre.lua + client/ventre.lua + elyzea_core/lib/clothing.lua).
-- Les fonctions du jeu (composants, collections de vêtements) sont simulées. Ce test ne remplace pas l'essai en jeu.
-- Lancement depuis le dossier de la ressource : lua5.4 tests/test_ventre.lua
local OK, KO = 0, 0
local function check(nom, cond, detail)
    if cond then OK = OK + 1 print('OK     ' .. nom) else KO = KO + 1 print('ÉCHEC  ' .. nom .. '  ' .. tostring(detail or '')) end
end

-- ── simulation : collections (jeu de base 0..199, pack « veloxfv1 » 200..209) et personnage
local COLS = { { name = '', first = 0, count = 200 }, { name = 'veloxfv1', first = 200, count = 10 } }
local PED = 7
local comps = {}
local function reset() for c = 0, 11 do comps[c] = { 0, 0 } end comps[3] = { 15, 0 } comps[11] = { 15, 0 } end
reset()
local shopOuverte = false
function IsDuplicityVersion() return false end
function PlayerPedId() return PED end
function DoesEntityExist(p) return p == PED end
function GetHashKey(s) return s == 'mp_f_freemode_01' and 1 or 0 end
function GetEntityModel() return 1 end
function GetPedDrawableVariation(_, c) return comps[c][1] end
function GetPedTextureVariation(_, c) return comps[c][2] end
function GetNumberOfPedTextureVariations() return 4 end
function SetPedComponentVariation(_, c, d, t) comps[c] = { d, t } end
function GetPedCollectionsCount() return #COLS end
function GetPedCollectionName(_, i) return COLS[i + 1].name end
local function colDe(d) for _, k in ipairs(COLS) do if d >= k.first and d < k.first + k.count then return k end end end
function GetPedCollectionNameFromDrawable(_, _, d) local k = colDe(d) return k and k.name end
function GetPedCollectionLocalIndexFromDrawable(_, _, d) local k = colDe(d) return k and d - k.first or -1 end
function GetPedDrawableGlobalIndexFromCollection(_, _, col, li)
    for _, k in ipairs(COLS) do if k.name == col and li < k.count then return k.first + li end end
    return -1
end
function GetNumberOfPedCollectionDrawableVariations(_, _, col) for _, k in ipairs(COLS) do if k.name == col then return k.count end end return 0 end
function GetPedCollectionNameFromProp() return '' end
function GetPedCollectionLocalIndexFromProp() return -1 end
function GetPedPropGlobalIndexFromCollection() return -1 end
function GetNumberOfPedCollectionPropDrawableVariations() return 0 end
function GetResourceState(r) return r == 'elyzea_clothing' and 'started' or 'missing' end
exports = { elyzea_clothing = { IsOpen = function() return shopOuverte end } }
local STATE = {}
LocalPlayer = { state = setmetatable({ set = function(self, k, v) STATE[k] = v end }, { __index = function(_, k) return STATE[k] end }) }
GlobalState = {}
local HANDLERS, THREADS = {}, {}
function AddEventHandler(n, fn) HANDLERS[n] = fn end
function TriggerEvent(n, ...) if HANDLERS[n] then HANDLERS[n](...) end end
function RegisterCommand() end
function SetTimeout() end
function CreateThread(fn) THREADS[#THREADS + 1] = coroutine.create(fn) end
function Wait() coroutine.yield() end
function GetCurrentResourceName() return 'elyzea_famille' end

dofile('../elyzea_core/lib/clothing.lua')
dofile('config/config.lua')
dofile('grossesse/shared/ventre.lua')
dofile('grossesse/client/ventre.lua')
local function tick() for _, co in ipairs(THREADS) do assert(coroutine.resume(co)) end end
local function enregistree(c) local p = ElyCloth.readReal(PED, 'component', c) return p.drawable, p.col, p.li end
local function etape(n) TriggerEvent('elyzea_famille:client:etapeGrossesse', n) tick() end

-- réglages publiés (comme server/reglages.lua) : ventre = pack veloxfv1, n° 2 (étape 2) et 5 (étapes 3-5)
local function publier(actif, compat)
    local V = Config.Ventre
    GlobalState.famVentre = { actif = actif, composant = 3, collection = 'veloxfv1', compatibilite = compat or 'toujours', hautsCompatibles = {},
        hautNu = { h = 15, f = 15 }, etapes = { e2 = { li = 2, texture = 1 }, e3 = { li = 5, texture = 0 }, e4 = { li = 5, texture = 0 }, e5 = { li = -1, texture = 0 } } }
end

-- 1. désactivé par défaut (numéros pas encore relevés)
GlobalState.famVentre = nil
comps[3] = { 120, 2 }       -- gants du jeu de base portés
etape(2)
check('1. ventre désactivé (défaut) : la tenue ne change pas', comps[3][1] == 120 and comps[3][2] == 2)

-- 2. activé, étape 1 : rien ; étape 2 : ventre du pack, par la collection
publier(true)
etape(1)
check('2. étape 1 : pas de ventre', comps[3][1] == 120)
etape(2)
check('2. étape 2 : ventre posé (collection veloxfv1 n° 2 = n° global 202, texture 1)', comps[3][1] == 202 and comps[3][2] == 1, comps[3][1])
local d = enregistree(3)
check('2. tenue enregistrée / objets vêtements : la pièce d\'origine (120), jamais le ventre', d == 120, d)

-- 3. étape 3 : autre ventre ; la pièce d'origine reste la même
etape(3)
check('3. étape 3 : ventre plus gros (n° 205)', comps[3][1] == 205)
check('3. pièce d\'origine toujours 120', (enregistree(3)) == 120)

-- 4. changement de tenue (objet vêtement, uniforme) : nouvelle pièce d'origine, ventre remis
comps[3] = { 130, 0 }
check('4. juste après le changement : la tenue enregistrée lit la nouvelle pièce (130)', (enregistree(3)) == 130)
tick()
check('4. ventre remis par-dessus, la nouvelle pièce (130) devient l\'origine', comps[3][1] == 205 and (enregistree(3)) == 130)

-- 5. boutique ouverte : on ne touche à rien
shopOuverte = true
comps[3] = { 140, 0 }   -- essayage
tick()
check('5. boutique ouverte : essayage non recouvert', comps[3][1] == 140)
shopOuverte = false
tick()
check('5. boutique fermée : ventre remis, l\'achat (140) devient l\'origine', comps[3][1] == 205 and (enregistree(3)) == 140)

-- 6. compatibilité « sans haut »
publier(true, 'sansHaut')
comps[11] = { 33, 0 }
tick()
check('6. mode « sans haut » avec un haut porté : ventre retiré, pièce d\'origine remise', comps[3][1] == 140)
comps[11] = { 15, 0 }
tick()
check('6. haut retiré : ventre remis', comps[3][1] == 205)
publier(true)

-- 7. personnage recréé (rechargement de l'apparence) : nouveau ped, ventre reposé sans perdre l'origine
PED = 8
reset() comps[3] = { 140, 0 }
tick()
check('7. nouveau personnage : ventre reposé, origine = tenue rechargée (140)', comps[3][1] == 205 and (enregistree(3)) == 140)

-- 8. pack absent : rien n'est posé (et pas d'erreur)
GlobalState.famVentre.collection = 'pack_absent'
tick()
check('8. collection introuvable : ventre retiré, tenue d\'origine', comps[3][1] == 140)
publier(true)
tick()

-- 9. fin de grossesse : pièce d'origine remise, plus rien de masqué
etape(nil)
check('9. fin de grossesse : pièce d\'origine remise (140), masque effacé', comps[3][1] == 140 and STATE.elyTenueMasquee == nil)

-- 10. règles pures
local R = VentreRegles
check('10. étape sans n° (-1) : pas de ventre', R.cible(GlobalState.famVentre, 5, { drawable = 15 }, true) == nil)
check('10. mode « liste » : seulement avec un haut listé', R.cible({ actif = true, composant = 3, collection = '', compatibilite = 'liste',
    hautsCompatibles = { { col = 'veloxfv1', li = 1 } }, etapes = { e2 = { li = 3 } } }, 2, { drawable = 201, col = 'veloxfv1', li = 1 }, true) ~= nil
    and R.cible({ actif = true, composant = 3, collection = '', compatibilite = 'liste', hautsCompatibles = { { col = 'veloxfv1', li = 1 } },
    etapes = { e2 = { li = 3 } } }, 2, { drawable = 50, col = '', li = 50 }, true) == nil)

print(('\n%d contrôles réussis, %d échec(s)'):format(OK, KO))
os.exit(KO == 0 and 0 or 1)
