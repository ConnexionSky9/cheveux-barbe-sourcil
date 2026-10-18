-- =====================================================================
--  ELYZEA VÊTEMENTS CORRECTIFS · diagnostic en jeu (client)
--  /vet_diag  : chaque emplacement porté, son pack et les fichiers à chercher (console F8)
--  /vet_essai : change UN emplacement pour un essai, SANS rien enregistrer
--               /vet_essai 4 15   ·   /vet_essai 11 + (suivant)   ·   /vet_essai 11 - 2 (coloris 3)
--               /vet_essai annuler : remet la tenue d'avant le premier essai
-- =====================================================================
local SLOTS = {
    [0] = { 'head', 'Tête' }, [1] = { 'berd', 'Masque' }, [2] = { 'hair', 'Cheveux' },
    [3] = { 'uppr', 'Bras / torse (corps)' }, [4] = { 'lowr', 'Jambes / pantalon' }, [5] = { 'hand', 'Sac' },
    [6] = { 'feet', 'Chaussures' }, [7] = { 'teef', 'Collier' }, [8] = { 'accs', 'Sous-haut / T-shirt' },
    [9] = { 'task', 'Gilet' }, [10] = { 'decl', 'Logo' }, [11] = { 'jbib', 'Haut / robe' },
}
local hasCollections = type(GetPedCollectionNameFromDrawable) == 'function' and type(GetPedCollectionLocalIndexFromDrawable) == 'function'

local function say(msg)
    TriggerEvent('chat:addMessage', { args = { 'Vêtements', msg } })
end

local function modelPrefix(ped)
    local m = GetEntityModel(ped)
    if m == `mp_f_freemode_01` then return 'mp_f_freemode_01' end
    if m == `mp_m_freemode_01` then return 'mp_m_freemode_01' end
end

-- Collection (pack) et n° dans le pack ; collection vide = vêtement d'origine de GTA
local function collectionOf(ped, slot, d)
    if not hasCollections or d < 0 then return nil, nil end
    return GetPedCollectionNameFromDrawable(ped, slot, d) or '', GetPedCollectionLocalIndexFromDrawable(ped, slot, d)
end

local function describe(ped, slot, prefix)
    local d, t, pal = GetPedDrawableVariation(ped, slot), GetPedTextureVariation(ped, slot), GetPedPaletteVariation(ped, slot)
    local col, li = collectionOf(ped, slot, d)
    local code = SLOTS[slot][1]
    local info = {
        slot = slot, code = code, label = SLOTS[slot][2], drawable = d, texture = t, palette = pal,
        textures = d >= 0 and GetNumberOfPedTextureVariations(ped, slot, d) or 0,
        valid = d >= 0 and IsPedComponentVariationValid(ped, slot, d, t) or false,
        col = col, li = li,
    }
    if col and col ~= '' and li and li >= 0 then
        local n = ('%03d'):format(li)
        local letter = string.char(97 + math.max(0, t))
        -- Fichiers d'un pack : <modèle>_<pack>^<emplacement>_<n°>…
        local base = (prefix and col:sub(1, #prefix) ~= prefix) and (prefix .. '_' .. col) or col
        info.files = {
            model = ('%s^%s_%s_u.ydd (ou _r.ydd)'):format(base, code, n),
            texture = ('%s^%s_diff_%s_%s_uni.ytd (ou _whi / _bla…)'):format(base, code, n, letter),
            search = ('*%s_%s*'):format(code, n),
        }
    end
    return info
end

RegisterNetEvent('elyzea_vetfix:diag', function()
    local ped = PlayerPedId()
    local prefix = modelPrefix(ped)
    print('^3========== DIAGNOSTIC VÊTEMENTS ==========^0')
    print(('Modèle : %s'):format(prefix or ('NON freemode (0x%X) : les vêtements de packs ne sont pas faits pour ce modèle'):format(GetEntityModel(ped))))
    if not hasCollections then print('^1Natives de collection absentes : mets à jour le serveur (artefacts récents) pour connaître les packs.^0') end
    for slot = 0, 11 do
        local i = describe(ped, slot, prefix)
        local pack = i.col == nil and '?' or (i.col == '' and 'GTA d\'origine' or ('pack « %s », n° %d dans le pack'):format(i.col, i.li))
        print(('[%2d] %-22s n° %4d · coloris %d/%d · %s%s'):format(slot, i.label, i.drawable, i.texture + 1, i.textures, pack,
            i.valid and '' or ' ^1(combinaison NON valide)^0'))
        if i.files then
            print(('      modèle 3D : %s'):format(i.files.model))
            print(('      texture   : %s'):format(i.files.texture))
            print(('      chercher  : %s dans le dossier du pack'):format(i.files.search))
        end
    end
    -- Ce qui se trouve SOUS une robe et peut apparaître au travers
    local top, legs, under, arms = describe(ped, 11, prefix), describe(ped, 4, prefix), describe(ped, 8, prefix), describe(ped, 3, prefix)
    print('^3--- Sous le haut / la robe ---^0')
    print(('Jambes n° %d, sous-haut n° %d, bras/torse n° %d. Si la zone abîmée de la robe CHANGE quand on change l\'un d\'eux (/vet_essai), c\'est lui qu\'on voit au travers.'):format(legs.drawable, under.drawable, arms.drawable))
    print('^3==========================================^0')
    say(('Haut n° %d (coloris %d) %s — détails et noms des fichiers dans la console F8.'):format(top.drawable, top.texture + 1,
        top.col and top.col ~= '' and ('pack « ' .. top.col .. ' »') or 'GTA d\'origine'))
end)

-- ---------------------------------------------------------------------
-- Essais sans enregistrement
-- ---------------------------------------------------------------------
local before = nil   -- tenue avant le premier essai

local function snapshot(ped)
    local s = {}
    for i = 0, 11 do s[i] = { GetPedDrawableVariation(ped, i), GetPedTextureVariation(ped, i), GetPedPaletteVariation(ped, i) } end
    return s
end

RegisterNetEvent('elyzea_vetfix:essai', function(args)
    local ped = PlayerPedId()
    args = type(args) == 'table' and args or {}
    if args[1] == 'annuler' then
        if not before then return say('Aucun essai en cours.') end
        for i = 0, 11 do SetPedComponentVariation(ped, i, before[i][1], before[i][2], before[i][3]) end
        before = nil
        return say('Tenue d\'avant les essais remise.')
    end
    local slot = tonumber(args[1])
    if not slot or not SLOTS[slot] then return say('Usage : /vet_essai <emplacement 0-11> <n°|+|-> [coloris] · /vet_essai annuler') end
    local cur = GetPedDrawableVariation(ped, slot)
    local count = GetNumberOfPedDrawableVariations(ped, slot)
    local d = args[2] == '+' and cur + 1 or args[2] == '-' and cur - 1 or tonumber(args[2])
    if not d then return say('Indique un n° de modèle, + ou -.') end
    d = math.floor(d) % math.max(1, count)
    local t = math.max(0, math.floor((tonumber(args[3]) or 1) - 1))
    if t >= GetNumberOfPedTextureVariations(ped, slot, d) then t = 0 end
    before = before or snapshot(ped)
    SetPedComponentVariation(ped, slot, d, t, 0)
    local col, li = collectionOf(ped, slot, d)
    say(('Essai %s : n° %d coloris %d%s. Rien n\'est enregistré — /vet_essai annuler pour revenir.'):format(SLOTS[slot][2], d, t + 1,
        col and col ~= '' and (' (pack « %s », n° %d)'):format(col, li) or ''))
end)

-- Ressource arrêtée pendant un essai : on remet la tenue
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not before then return end
    local ped = PlayerPedId()
    for i = 0, 11 do SetPedComponentVariation(ped, i, before[i][1], before[i][2], before[i][3]) end
end)
