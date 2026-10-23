-- =====================================================================
--  ELYZEA FAMILLE - client : ventre de grossesse (sur son propre personnage, visible par tous)
--  · Pose la pièce du pack réglée pour l'étape (GlobalState.famVentre, menu admin › Ventre de grossesse).
--  · Garde la pièce d'origine et la remet à la fin de la grossesse ou si le ventre est désactivé.
--  · Si la tenue change (boutique, objet vêtement, uniforme, rechargement de l'apparence), la nouvelle pièce
--    devient la pièce d'origine et le ventre est remis par-dessus.
--  · Déclare la pièce posée dans LocalPlayer.state.elyTenueMasquee : ely_creator (tenue enregistrée) et
--    elyzea_clothing (objets vêtements, « Ma tenue ») lisent la pièce d'origine (ElyCloth.readReal).
--  Outils : /ventre_info (ce que l'on porte, composant par composant), /ventre_scan [composant] (collections),
--           /ventre_essai composant n° [texture] [collection] (aperçu de 20 s, puis retour à la tenue).
-- =====================================================================
local etape = nil
local pose = nil        -- { ped, piece = cible, drawable, texture, origine = { drawable, texture, col, li } }
local essai = false

AddEventHandler('elyzea_famille:client:etapeGrossesse', function(n) etape = n end)

local function masquer(p)
    LocalPlayer.state:set('elyTenueMasquee', p and { [tostring(p.piece.composant)] = {
        ventre = { drawable = p.drawable, texture = p.texture }, origine = p.origine } } or nil, false)
end

local function globalDe(ped, piece)
    if piece.collection ~= '' then
        return ElyCloth.resolve(ped, 'component', piece.composant, { drawable = 0, col = piece.collection, li = piece.li })
    end
    return piece.li
end

local function remettre()
    if not pose then return end
    local ped = PlayerPedId()
    if pose.ped == ped and DoesEntityExist(ped) then
        local cur = ElyCloth.read(ped, 'component', pose.piece.composant)
        -- seulement si l'emplacement montre encore le ventre (sinon un autre script y a mis un vrai vêtement)
        if not VentreRegles.change(cur, pose) then ElyCloth.apply(ped, 'component', pose.piece.composant, pose.origine) end
    end
    pose = nil
    masquer(nil)
end

local avertiPack = false
local function poser(ped, piece, origine)
    local g = globalDe(ped, piece)
    if not g or g < 0 then
        if not avertiPack then
            avertiPack = true
            print(('[elyzea_famille] ventre : collection « %s » n° %d introuvable pour ce personnage (pack absent ?)'):format(piece.collection, piece.li))
        end
        return
    end
    local t = piece.texture
    if t >= GetNumberOfPedTextureVariations(ped, piece.composant, g) then t = 0 end
    SetPedComponentVariation(ped, piece.composant, g, t, 0)
    pose = { ped = ped, piece = piece, drawable = g, texture = t, origine = origine }
    masquer(pose)
end

local function boutiqueOuverte()
    if GetResourceState('elyzea_clothing') ~= 'started' then return false end
    local ok, r = pcall(function() return exports.elyzea_clothing:IsOpen() end)
    return ok and r == true
end

local function maj()
    if essai then return end
    if not etape and not pose then return end   -- pas enceinte et rien de posé : rien à faire (résultat identique)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or boutiqueOuverte() then return end   -- boutique : on ne touche à rien
    local femme = GetEntityModel(ped) == GetHashKey('mp_f_freemode_01')
    local voulu = VentreRegles.cible(GlobalState.famVentre, etape, ElyCloth.read(ped, 'component', 11), femme)
    if pose and (pose.ped ~= ped or not VentreRegles.meme(pose.piece, voulu)) then
        if pose.ped ~= ped then pose = nil masquer(nil) else remettre() end
    end
    if not voulu then return end
    if pose then
        local cur = ElyCloth.read(ped, 'component', voulu.composant)
        if VentreRegles.change(cur, pose) then poser(ped, voulu, cur) end   -- nouvelle tenue : nouvelle pièce d'origine
    else
        poser(ped, voulu, ElyCloth.readReal(ped, 'component', voulu.composant))
    end
end

CreateThread(function()
    while true do
        local ok, err = pcall(maj)
        if not ok then print('[elyzea_famille] ventre : ' .. tostring(err)) Wait(5000) end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then remettre() end end)

-- ─────────── Outils d'identification (le pack n'est pas fourni : numéros à relever en jeu) ───────────

local NOMS = { [0] = 'tête', 'masque', 'cheveux', 'torse / bras', 'jambes', 'sac', 'chaussures', 'accessoire cou', 'sous-haut', 'gilet', 'logo', 'haut' }

local function dire(t) print(t) TriggerEvent('chat:addMessage', { args = { 'Ventre', t } }) end

RegisterCommand('ventre_info', function()
    local ped = PlayerPedId()
    dire('Composants portés (n° global · collection · n° local · texture) — à recopier dans le menu admin › Ventre :')
    for c = 0, 11 do
        local p = ElyCloth.read(ped, 'component', c)
        dire(('%2d %-15s : global %d · col %s · li %s · texture %d'):format(c, NOMS[c], p.drawable, p.col or '—', p.li and tostring(p.li) or '—', p.texture))
    end
    if pose then dire(('Ventre posé : composant %d, collection %s, n° %d (pièce d\'origine gardée : %d)'):format(pose.piece.composant, pose.piece.collection, pose.piece.li, pose.origine.drawable)) end
end, false)

RegisterCommand('ventre_scan', function(_, args)
    local c = tonumber(args[1]) or 3
    local ped = PlayerPedId()
    dire(('Collections du composant %d (%s) :'):format(c, NOMS[c] or '?'))
    for _, r in ipairs(ElyCloth.ranges(ped, 'component', c)) do
        dire(('  %s : %d pièce(s), n° global %d à %d'):format(r.col ~= '' and r.col or '(jeu de base)', r.count, r.first, r.first + r.count - 1))
    end
end, false)

RegisterCommand('ventre_essai', function(_, args)
    local c, n = tonumber(args[1]), tonumber(args[2])
    if not c or not n or essai then return dire('Usage : /ventre_essai composant n° [texture] [collection]  (n° local si une collection est donnée, sinon n° global)') end
    local ped = PlayerPedId()
    local piece = { composant = c, li = n, texture = tonumber(args[3]) or 0, collection = args[4] or '' }
    local g = globalDe(ped, piece)
    if not g or g < 0 then return dire('Pièce introuvable pour ce personnage.') end
    essai = true
    local avant = ElyCloth.read(ped, 'component', c)
    SetPedComponentVariation(ped, c, g, piece.texture, 0)
    dire(('Essai : composant %d, n° global %d. Retour à la tenue dans 20 s (rien n\'est enregistré).'):format(c, g))
    SetTimeout(20000, function()
        if DoesEntityExist(ped) then ElyCloth.apply(ped, 'component', c, avant) end
        essai = false
    end)
end, false)
