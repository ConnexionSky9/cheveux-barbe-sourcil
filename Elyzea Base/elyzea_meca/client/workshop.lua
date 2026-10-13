-- =====================================================================
--  ELYZEA MÉCANO - client : points d'atelier (E), aperçu, devis, installation
--  · E au point (au volant OU à pied à côté du véhicule garé dessus), ou F6 :
--    le serveur vérifie la position, le grade et le véhicule.
--  · Chaque option s'affiche tout de suite sur le véhicule (aperçu en direct).
--    En quittant l'atelier, tout ce qui n'a pas été payé ET installé est retiré.
--  · Pendant l'atelier : moteur, phares et néons allumés pour voir le rendu.
--  · À l'installation, le serveur envoie les propriétés exactes de chaque ligne :
--    elles sont appliquées puis relues sur le véhicule ; seule une ligne réellement
--    posée est déclarée réussie (et donc facturée).
-- =====================================================================
local C = MecaC
local core = exports.elyzea_core
local WS = { open = false, ws = nil, veh = nil, snapshot = nil, data = nil }

-- Pièces de carrosserie et d'intérieur (type de modification GTA)
local BODY = {
    { id = 0, label = 'Aileron' }, { id = 1, label = 'Pare-chocs avant' }, { id = 2, label = 'Pare-chocs arrière' }, { id = 3, label = 'Bas de caisse' },
    { id = 4, label = 'Échappement' }, { id = 5, label = 'Arceau' }, { id = 6, label = 'Calandre' }, { id = 7, label = 'Capot' },
    { id = 8, label = 'Aile gauche' }, { id = 9, label = 'Aile droite' }, { id = 10, label = 'Toit' }, { id = 14, label = 'Klaxon' },
    { id = 37, label = 'Coffre' }, { id = 38, label = 'Hydraulique' }, { id = 39, label = 'Bloc moteur' }, { id = 40, label = 'Filtre à air' },
    { id = 41, label = 'Barres de renfort' }, { id = 42, label = 'Passages de roue' }, { id = 43, label = 'Antennes' }, { id = 44, label = 'Garnitures extérieures' },
    { id = 45, label = 'Réservoir' }, { id = 46, label = 'Fenêtres' }, { id = 47, label = 'Portes' }, { id = 49, label = 'Rampe lumineuse' },
}
local INTERIOR = {
    { id = 25, label = 'Support de plaque' }, { id = 26, label = 'Plaque personnalisée' }, { id = 27, label = 'Garnitures' }, { id = 28, label = 'Ornements' },
    { id = 29, label = 'Tableau de bord' }, { id = 30, label = 'Compteurs' }, { id = 31, label = 'Haut-parleurs de portes' }, { id = 32, label = 'Sièges' },
    { id = 33, label = 'Volant' }, { id = 34, label = 'Levier de vitesse' }, { id = 35, label = 'Plaques décoratives' }, { id = 36, label = 'Sono' },
}
local PERF = { engine = 11, brakes = 12, transmission = 13, suspension = 15, armor = 16 }
-- Palette complète de GTA (0-160) : { index, nom, finition (0 normal, 1 métallisé, 3 mat, 4 métal, 5 chrome) }
local COLORS = {
    { 0, 'Noir', 1 }, { 1, 'Noir graphite', 1 }, { 2, 'Noir acier', 1 }, { 3, 'Argent foncé', 1 }, { 4, 'Argent', 1 }, { 5, 'Argent bleuté', 1 },
    { 6, 'Gris acier', 1 }, { 7, 'Argent ombré', 1 }, { 8, 'Argent pierre', 1 }, { 9, 'Argent minuit', 1 }, { 10, 'Gris canon', 1 }, { 11, 'Gris anthracite', 1 },
    { 12, 'Noir mat', 3 }, { 13, 'Gris mat', 3 }, { 14, 'Gris clair mat', 3 }, { 15, 'Noir utilitaire', 0 }, { 16, 'Noir utilitaire (poly)', 0 },
    { 17, 'Argent foncé utilitaire', 0 }, { 18, 'Argent utilitaire', 0 }, { 19, 'Gris canon utilitaire', 0 }, { 20, 'Argent ombré utilitaire', 0 },
    { 21, 'Noir usé', 0 }, { 22, 'Graphite usé', 0 }, { 23, 'Gris argent usé', 0 }, { 24, 'Argent usé', 0 }, { 25, 'Argent bleuté usé', 0 }, { 26, 'Argent ombré usé', 0 },
    { 27, 'Rouge', 1 }, { 28, 'Rouge Torino', 1 }, { 29, 'Rouge Formule', 1 }, { 30, 'Rouge flamme', 1 }, { 31, 'Rouge élégant', 1 }, { 32, 'Rouge grenat', 1 },
    { 33, 'Rouge désert', 1 }, { 34, 'Rouge cabernet', 1 }, { 35, 'Rouge bonbon', 1 }, { 36, 'Orange soleil levant', 1 }, { 37, 'Or classique', 1 }, { 38, 'Orange', 1 },
    { 39, 'Rouge mat', 3 }, { 40, 'Rouge foncé mat', 3 }, { 41, 'Orange mat', 3 }, { 42, 'Jaune mat', 3 }, { 43, 'Rouge utilitaire', 0 }, { 44, 'Rouge vif utilitaire', 0 },
    { 45, 'Grenat utilitaire', 0 }, { 46, 'Rouge usé', 0 }, { 47, 'Rouge doré usé', 0 }, { 48, 'Rouge foncé usé', 0 }, { 49, 'Vert foncé', 1 }, { 50, 'Vert course', 1 },
    { 51, 'Vert océan', 1 }, { 52, 'Vert olive', 1 }, { 53, 'Vert', 1 }, { 54, 'Bleu-vert essence', 1 }, { 55, 'Vert citron mat', 3 }, { 56, 'Vert foncé utilitaire', 0 },
    { 57, 'Vert utilitaire', 0 }, { 58, 'Vert foncé usé', 0 }, { 59, 'Vert usé', 0 }, { 60, 'Vert d\'eau usé', 0 }, { 61, 'Bleu nuit', 1 }, { 62, 'Bleu foncé', 1 },
    { 63, 'Bleu Saxe', 1 }, { 64, 'Bleu', 1 }, { 65, 'Bleu marin', 1 }, { 66, 'Bleu port', 1 }, { 67, 'Bleu diamant', 1 }, { 68, 'Bleu surf', 1 },
    { 69, 'Bleu nautique', 1 }, { 70, 'Bleu vif', 1 }, { 71, 'Bleu violet', 1 }, { 72, 'Bleu spinnaker', 1 }, { 73, 'Bleu ultra', 1 }, { 74, 'Bleu clair', 1 },
    { 75, 'Bleu foncé utilitaire', 0 }, { 76, 'Bleu nuit utilitaire', 0 }, { 77, 'Bleu utilitaire', 0 }, { 78, 'Bleu écume utilitaire', 0 }, { 79, 'Bleu éclair utilitaire', 0 },
    { 80, 'Bleu Maui utilitaire', 0 }, { 81, 'Bleu vif utilitaire', 0 }, { 82, 'Bleu foncé mat', 3 }, { 83, 'Bleu mat', 3 }, { 84, 'Bleu nuit mat', 3 },
    { 85, 'Bleu foncé usé', 0 }, { 86, 'Bleu usé', 0 }, { 87, 'Bleu clair usé', 0 }, { 88, 'Jaune taxi', 1 }, { 89, 'Jaune course', 1 }, { 90, 'Bronze', 1 },
    { 91, 'Jaune canari', 1 }, { 92, 'Vert lime', 1 }, { 93, 'Champagne', 1 }, { 94, 'Beige pueblo', 1 }, { 95, 'Ivoire foncé', 1 }, { 96, 'Brun chocolat', 1 },
    { 97, 'Brun doré', 1 }, { 98, 'Brun clair', 1 }, { 99, 'Beige paille', 1 }, { 100, 'Brun mousse', 1 }, { 101, 'Brun bistre', 1 }, { 102, 'Hêtre', 1 },
    { 103, 'Hêtre foncé', 1 }, { 104, 'Orange chocolat', 1 }, { 105, 'Sable', 1 }, { 106, 'Sable délavé', 1 }, { 107, 'Crème', 1 }, { 108, 'Brun utilitaire', 0 },
    { 109, 'Brun moyen utilitaire', 0 }, { 110, 'Brun clair utilitaire', 0 }, { 111, 'Blanc', 1 }, { 112, 'Blanc givré', 1 }, { 113, 'Beige miel usé', 0 },
    { 114, 'Brun usé', 0 }, { 115, 'Brun foncé usé', 0 }, { 116, 'Beige paille usé', 0 }, { 117, 'Acier brossé', 4 }, { 118, 'Acier noir brossé', 4 },
    { 119, 'Aluminium brossé', 4 }, { 120, 'Chrome', 5 }, { 121, 'Blanc cassé usé', 0 }, { 122, 'Blanc cassé utilitaire', 0 }, { 123, 'Orange usé', 0 },
    { 124, 'Orange clair usé', 0 }, { 125, 'Vert Securicor', 1 }, { 126, 'Jaune taxi usé', 0 }, { 127, 'Bleu police', 1 }, { 128, 'Vert mat', 3 }, { 129, 'Brun mat', 3 },
    { 130, 'Orange usé (2)', 0 }, { 131, 'Blanc mat', 3 }, { 132, 'Blanc usé', 0 }, { 133, 'Vert armée usé', 0 }, { 134, 'Blanc pur', 0 }, { 135, 'Rose vif', 1 },
    { 136, 'Rose saumon', 1 }, { 137, 'Rose vermillon', 1 }, { 138, 'Orange vif', 1 }, { 139, 'Vert vif', 1 }, { 140, 'Bleu vif (2)', 1 }, { 141, 'Noir bleuté', 1 },
    { 142, 'Noir violacé', 1 }, { 143, 'Noir rougeâtre', 1 }, { 144, 'Vert chasseur', 1 }, { 145, 'Violet', 1 }, { 146, 'Bleu très foncé', 1 }, { 147, 'Noir carbone', 1 },
    { 148, 'Violet mat', 3 }, { 149, 'Violet foncé mat', 3 }, { 150, 'Rouge lave', 1 }, { 151, 'Vert forêt mat', 3 }, { 152, 'Vert olive mat', 3 },
    { 153, 'Brun désert mat', 3 }, { 154, 'Beige désert mat', 3 }, { 155, 'Vert feuillage mat', 3 }, { 156, 'Alliage par défaut', 1 }, { 157, 'Bleu Epsilon', 1 },
    { 158, 'Or pur', 4 }, { 159, 'Or brossé', 4 }, { 160, 'Or secret', 4 },
}
local LIGHTS = {
    { 'Blanc', 255, 255, 255 }, { 'Bleu', 2, 21, 255 }, { 'Bleu électrique', 3, 83, 255 }, { 'Vert menthe', 0, 255, 140 }, { 'Vert lime', 94, 255, 1 },
    { 'Jaune', 255, 255, 0 }, { 'Or', 255, 150, 5 }, { 'Orange', 255, 62, 0 }, { 'Rouge', 255, 1, 1 }, { 'Rose', 255, 50, 100 }, { 'Rose vif', 255, 5, 190 }, { 'Violet', 35, 1, 255 },
    { 'Lumière noire', 15, 3, 255 }, { 'Cyan', 0, 255, 255 }, { 'Turquoise', 0, 200, 150 }, { 'Magenta', 255, 0, 255 }, { 'Corail', 255, 110, 70 }, { 'Ambre', 255, 191, 0 },
    { 'Bleu ciel', 120, 200, 255 }, { 'Lavande', 180, 140, 255 }, { 'Noir (fumée)', 1, 1, 1 },
}
local NEON_LAYOUT = { { '1111', 'Tout le tour' }, { '0011', 'Avant et arrière' }, { '1100', 'Côtés' }, { '0010', 'Avant' }, { '0001', 'Arrière' } }
local XENON = { 'Blanc', 'Bleu', 'Bleu électrique', 'Vert menthe', 'Vert lime', 'Jaune', 'Or', 'Orange', 'Rouge', 'Rose', 'Rose vif', 'Violet', 'Lumière noire' }
local TINTS = { { 0, 'Aucune' }, { 4, 'Origine' }, { 3, 'Fumé clair' }, { 2, 'Fumé foncé' }, { 5, 'Limousine' }, { 1, 'Noir pur' }, { 6, 'Vert' } }
local PLATES = { { 0, 'Bleu sur blanc' }, { 3, 'Bleu sur blanc (2)' }, { 4, 'Bleu sur blanc (3)' }, { 1, 'Jaune sur noir' }, { 2, 'Jaune sur bleu' }, { 5, 'North Yankton' } }
local WHEELTYPES = { { 0, 'Sport' }, { 1, 'Muscle' }, { 2, 'Lowrider' }, { 3, 'SUV' }, { 4, 'Tout-terrain' }, { 5, 'Tuner' }, { 7, 'Haut de gamme' },
    { 8, "Benny's Original" }, { 9, "Benny's Bespoke" }, { 11, 'Street' }, { 12, 'Track' }, { 10, 'Roues F1' }, { 6, 'Moto' } }
local FINISH = { { 0, 'Normal' }, { 1, 'Métallisé' }, { 2, 'Nacré' }, { 3, 'Mat' }, { 4, 'Métal' }, { 5, 'Chrome' } }

local function ModLabel(veh, mod, i, fallback)
    local txt = GetModTextLabel(veh, mod, i)
    local l = txt and GetLabelText(txt)
    if not l or l == 'NULL' or l == '' then l = ('%s n°%d'):format(fallback, i + 1) end
    return l
end

-- ---------------------------------------------------------------------
-- Options compatibles avec CE véhicule (groupe = mod du catalogue esthétique)
-- Chaque option : { value, label, spec } ; spec = ce que le serveur valide et facture
-- ---------------------------------------------------------------------
local function Subs(veh, group)
    if group == 'body' or group == 'interior' then
        local out = {}
        for _, m in ipairs(group == 'body' and BODY or INTERIOR) do
            if GetNumVehicleMods(veh, m.id) > 0 then out[#out + 1] = { id = tostring(m.id), label = m.label } end
        end
        return out
    elseif group == 'paint' then return { { id = '1', label = 'Peinture principale' }, { id = '2', label = 'Peinture secondaire' } }
    elseif group == 'neon' then
        if not IsThisModelACar(GetEntityModel(veh)) then return {} end
        local out = {}
        for _, l in ipairs(NEON_LAYOUT) do out[#out + 1] = { id = l[1], label = l[2] } end
        return out
    elseif group == 'wheels' then
        local out = {}
        local bike, f1 = IsThisModelABike(GetEntityModel(veh)), GetVehicleClass(veh) == 22
        for _, w in ipairs(WHEELTYPES) do
            if w[1] == 6 then if bike then out[#out + 1] = { id = '6', label = w[2] } end
            elseif w[1] == 10 then if f1 then out[#out + 1] = { id = '10', label = w[2] } end
            elseif not bike and not f1 then out[#out + 1] = { id = tostring(w[1]), label = w[2] } end
        end
        return out
    end
    return nil
end

local function Options(veh, group, sub)
    local out = {}
    SetVehicleModKit(veh, 0)
    if group == 'body' or group == 'interior' then
        local id = tonumber(sub)
        if not id then return out end
        local cur = GetVehicleMod(veh, id)
        out[#out + 1] = { value = -1, label = 'Origine', spec = { t = 'mod', id = id, v = -1 } }
        for i = 0, GetNumVehicleMods(veh, id) - 1 do out[#out + 1] = { value = i, label = ModLabel(veh, id, i, 'Pièce'), spec = { t = 'mod', id = id, v = i } } end
        return out, cur
    elseif group == 'paint' then
        local slot = tonumber(sub) or 1
        for _, c in ipairs(COLORS) do
            out[#out + 1] = { value = c[1], label = c[2], spec = { t = 'paint', slot = slot, color = c[1], finish = c[3] } }
            -- Les teintes métallisées existent aussi en nacré (finition GTA « perle »)
            if c[3] == 1 then out[#out + 1] = { value = ('%d:2'):format(c[1]), label = c[2] .. ' · nacré', spec = { t = 'paint', slot = slot, color = c[1], finish = 2 } } end
        end
        local p, s = GetVehicleColours(veh)
        return out, slot == 1 and p or s
    elseif group == 'pearl' or group == 'wheelcolor' or group == 'intcolor' or group == 'dashcolor' then
        for _, c in ipairs(COLORS) do out[#out + 1] = { value = c[1], label = c[2], spec = { t = group, v = c[1] } } end
        local pe, wc = GetVehicleExtraColours(veh)
        local cur = ({ pearl = pe, wheelcolor = wc, intcolor = GetVehicleInteriorColor(veh), dashcolor = GetVehicleDashboardColor(veh) })[group]
        return out, cur
    elseif group == 'tyres' then
        local ct, bp = GetVehicleModVariation(veh, 23), GetVehicleTyresCanBurst(veh) == false
        local cur = (ct and 1 or 0) + (bp and 2 or 0)
        for _, o in ipairs({ { 0, 'Pneus d\'origine' }, { 1, 'Pneus personnalisés (flancs)' }, { 2, 'Pneus pare-balles' }, { 3, 'Personnalisés + pare-balles' } }) do
            out[#out + 1] = { value = o[1], label = o[2], spec = { t = 'tyres', custom = o[1] % 2 == 1, bp = o[1] >= 2 } }
        end
        return out, cur
    elseif group == 'extras' then
        for i = 0, 20 do
            if DoesExtraExist(veh, i) then
                local on = IsVehicleExtraTurnedOn(veh, i)
                out[#out + 1] = { value = i, label = ('Élément n°%d : %s'):format(i, on and 'retirer' or 'ajouter'), spec = { t = 'extra', id = i, on = not on } }
            end
        end
        return out
    elseif group == 'roofliv' then
        local n = GetVehicleRoofLiveryCount(veh)
        for i = 0, n - 1 do out[#out + 1] = { value = i, label = ('Livrée de toit n°%d'):format(i + 1), spec = { t = 'roofliv', v = i } } end
        return out, GetVehicleRoofLivery(veh)
    elseif group == 'platetext' then
        return out, C.Plate(veh)
    elseif group == 'wheels' then
        local t = tonumber(sub) or GetVehicleWheelType(veh)
        local curT, curM = GetVehicleWheelType(veh), GetVehicleMod(veh, 23)
        SetVehicleWheelType(veh, t)
        out[#out + 1] = { value = -1, label = 'Origine', spec = { t = 'wheels', wt = t, v = -1 } }
        for i = 0, GetNumVehicleMods(veh, 23) - 1 do out[#out + 1] = { value = i, label = ModLabel(veh, 23, i, 'Jante'), spec = { t = 'wheels', wt = t, v = i } } end
        SetVehicleWheelType(veh, curT)
        SetVehicleMod(veh, 23, curM, false)
        return out, curT == t and curM or nil
    elseif group == 'smoke' then
        for i, l in ipairs(LIGHTS) do out[#out + 1] = { value = i, label = l[1], spec = { t = 'smoke', rgb = { l[2], l[3], l[4] } } } end
        return out
    elseif group == 'neon' then
        if not IsThisModelACar(GetEntityModel(veh)) then return out end
        local sides = tostring(sub or '1111')
        out[#out + 1] = { value = 0, label = 'Éteints', spec = { t = 'neon', on = false } }
        for i, l in ipairs(LIGHTS) do out[#out + 1] = { value = i, label = l[1], spec = { t = 'neon', on = true, sides = sides, rgb = { l[2], l[3], l[4] } } } end
        return out
    elseif group == 'xenon' then
        out[#out + 1] = { value = -2, label = 'Phares normaux', spec = { t = 'xenon', on = false } }
        for i, l in ipairs(XENON) do out[#out + 1] = { value = i - 1, label = l, spec = { t = 'xenon', on = true, v = i - 1 } } end
        return out, IsToggleModOn(veh, 22) and GetVehicleXenonLightsColor(veh) or -2
    elseif group == 'tint' then
        for _, x in ipairs(TINTS) do out[#out + 1] = { value = x[1], label = x[2], spec = { t = 'tint', v = x[1] } } end
        return out, GetVehicleWindowTint(veh)
    elseif group == 'plate' then
        for _, x in ipairs(PLATES) do out[#out + 1] = { value = x[1], label = x[2], spec = { t = 'plate', v = x[1] } } end
        return out, GetVehicleNumberPlateTextIndex(veh)
    elseif group == 'livery' then
        if GetNumVehicleMods(veh, 48) > 0 then
            out[#out + 1] = { value = -1, label = 'Origine', spec = { t = 'livery', v = -1 } }
            for i = 0, GetNumVehicleMods(veh, 48) - 1 do out[#out + 1] = { value = i, label = ModLabel(veh, 48, i, 'Livrée'), spec = { t = 'livery', v = i } } end
            return out, GetVehicleMod(veh, 48)
        end
        for i = 0, GetVehicleLiveryCount(veh) - 1 do out[#out + 1] = { value = i, label = ('Livrée n°%d'):format(i + 1), spec = { t = 'livery', v = i } } end
        return out, GetVehicleLivery(veh)
    end
    return out
end

-- Spécification → propriétés elyzea_core (même conversion que le serveur, pour l'aperçu)
local MODKEY = {}
for _, m in ipairs(BODY) do MODKEY[m.id] = true end
for _, m in ipairs(INTERIOR) do MODKEY[m.id] = true end
MODKEY[47], MODKEY[49] = true, true
local function Preview(veh, spec)
    SetVehicleModKit(veh, 0)
    local t = spec.t
    if t == 'mod' and MODKEY[spec.id] then SetVehicleMod(veh, spec.id, spec.v, false)
    elseif t == 'wheels' then SetVehicleWheelType(veh, spec.wt) SetVehicleMod(veh, 23, spec.v, false) if IsThisModelABike(GetEntityModel(veh)) then SetVehicleMod(veh, 24, spec.v, false) end
    elseif t == 'paint' then
        local p, s = GetVehicleColours(veh)
        local pe, wc = GetVehicleExtraColours(veh)
        if type(spec.color) == 'table' then   -- couleur personnalisée (RVB)
            local c = spec.color
            if spec.slot == 1 then SetVehicleModColor_1(veh, spec.finish or 1, 0, 0) SetVehicleCustomPrimaryColour(veh, c[1], c[2], c[3])
            else SetVehicleModColor_2(veh, spec.finish or 1, 0) SetVehicleCustomSecondaryColour(veh, c[1], c[2], c[3]) end
        elseif spec.slot == 1 then ClearVehicleCustomPrimaryColour(veh) SetVehicleModColor_1(veh, spec.finish, 0, 0) SetVehicleColours(veh, spec.color, s)
        else ClearVehicleCustomSecondaryColour(veh) SetVehicleModColor_2(veh, spec.finish, 0) SetVehicleColours(veh, p, spec.color) end
        SetVehicleExtraColours(veh, pe, wc)
    elseif t == 'pearl' then local _, wc = GetVehicleExtraColours(veh) SetVehicleExtraColours(veh, spec.v, wc)
    elseif t == 'intcolor' then SetVehicleInteriorColor(veh, spec.v)
    elseif t == 'dashcolor' then SetVehicleDashboardColor(veh, spec.v)
    elseif t == 'tyres' then
        SetVehicleMod(veh, 23, GetVehicleMod(veh, 23), spec.custom == true)
        if IsThisModelABike(GetEntityModel(veh)) then SetVehicleMod(veh, 24, GetVehicleMod(veh, 24), spec.custom == true) end
        SetVehicleTyresCanBurst(veh, spec.bp ~= true)
    elseif t == 'extra' then SetVehicleExtra(veh, spec.id, spec.on ~= true)
    elseif t == 'roofliv' then SetVehicleRoofLivery(veh, spec.v)
    elseif t == 'platetext' then SetVehicleNumberPlateText(veh, spec.v)
    elseif t == 'wheelcolor' then local pe = GetVehicleExtraColours(veh) SetVehicleExtraColours(veh, pe, spec.v)
    elseif t == 'smoke' then ToggleVehicleMod(veh, 20, true) SetVehicleTyreSmokeColor(veh, spec.rgb[1], spec.rgb[2], spec.rgb[3])
    elseif t == 'neon' then
        local sides = tostring(spec.sides or '1111')
        for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, spec.on == true and sides:sub(i + 1, i + 1) == '1') end
        if spec.rgb then SetVehicleNeonLightsColour(veh, spec.rgb[1], spec.rgb[2], spec.rgb[3]) end
    elseif t == 'xenon' then
        ToggleVehicleMod(veh, 22, spec.on == true)
        if spec.on and type(spec.rgb) == 'table' then SetVehicleXenonLightsCustomColor(veh, spec.rgb[1], spec.rgb[2], spec.rgb[3])
        elseif spec.on then ClearVehicleXenonLightsCustomColor(veh) SetVehicleXenonLightsColor(veh, spec.v or -1) end
    elseif t == 'tint' then SetVehicleWindowTint(veh, spec.v)
    elseif t == 'plate' then SetVehicleNumberPlateTextIndex(veh, spec.v)
    elseif t == 'livery' then if GetNumVehicleMods(veh, 48) > 0 then SetVehicleMod(veh, 48, spec.v, false) else SetVehicleLivery(veh, spec.v) end
    elseif t == 'perf' then
        if spec.mod == 'turbo' then ToggleVehicleMod(veh, 18, true) elseif PERF[spec.mod] then SetVehicleMod(veh, PERF[spec.mod], spec.level - 1, false) end
    end
end

-- La ligne est-elle réellement posée ? (relecture des propriétés du véhicule)
local IGNORE = { modBackWheels = true, paintType1 = true, paintType2 = true, xenonColor = true }
local function Same(a, b)
    if type(a) == 'table' and type(b) == 'table' then
        for i = 1, math.max(#a, 3) do
            local x, y = a[i], b[i]
            if type(x) == 'boolean' or type(y) == 'boolean' then if (x == true) ~= (y == true) then return false end
            elseif x ~= nil and y ~= nil and math.abs((tonumber(x) or 0) - (tonumber(y) or 0)) > 3 then return false end
        end
        return true
    end
    if type(a) == 'boolean' or type(b) == 'boolean' then return (a == true) == (b == true) end
    if tonumber(a) and tonumber(b) then
        local x, y = tonumber(a), tonumber(b)
        if x == y then return true end
        return (x <= 0 and y <= 0)   -- -1 / 0 : « origine » ou « aucune » selon le natif
    end
    return a == b
end
local function Verify(veh, patch)
    local props = core:GetVehicleProperties(veh) or {}
    for k, v in pairs(patch) do
        if not IGNORE[k] then
            local got = props[k]
            if k == 'modXenon' or k == 'modTurbo' or k == 'modSmokeEnabled' or k == 'bulletProofTyres' or k == 'modCustomTiresF' or k == 'modCustomTiresR' then
                got = props[k] == true or props[k] == 1
                v = v == true or v == 1
            end
            if k == 'extras' then
                for id, val in pairs(v) do if (tonumber((got or {})[tostring(id)]) or -1) ~= tonumber(val) then return false end end
            elseif k == 'plate' then
                if C.Plate(veh):upper() ~= tostring(v):upper() then return false end
            elseif not Same(got, v) then return false end
        end
    end
    return true
end

local function Control(veh)
    if NetworkHasControlOfEntity(veh) then return true end
    local t = GetGameTimer() + 2500
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < t do NetworkRequestControlOfEntity(veh) Wait(0) end
    return NetworkHasControlOfEntity(veh)
end

-- ---------------------------------------------------------------------
-- Caméra : clic droit maintenu + glisser pour tourner autour du véhicule, molette pour zoomer
-- ---------------------------------------------------------------------
local CAM = { cam = nil, h = 0.0, p = 12.0, d = 6.0 }
local function CamUpdate()
    if not CAM.cam or not WS.veh or not DoesEntityExist(WS.veh) then return end
    local c = GetEntityCoords(WS.veh) + vector3(0.0, 0.0, 0.4)
    local h, p = math.rad(CAM.h), math.rad(CAM.p)
    local pos = c + vector3(-math.sin(h) * math.cos(p) * CAM.d, math.cos(h) * math.cos(p) * CAM.d, math.sin(p) * CAM.d)
    SetCamCoord(CAM.cam, pos.x, pos.y, pos.z)
    PointCamAtCoord(CAM.cam, c.x, c.y, c.z)
end
local function CamStart(veh)
    local min, max = GetModelDimensions(GetEntityModel(veh))
    CAM.d = math.max(4.0, math.min(14.0, #(max - min) * 1.25))
    CAM.h, CAM.p = GetEntityHeading(veh) + 220.0, 12.0
    CAM.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(CAM.cam, 50.0)
    WS.veh = veh
    CamUpdate()
    RenderScriptCams(true, true, 600, true, true)
end
local function CamStop()
    if not CAM.cam then return end
    RenderScriptCams(false, true, 600, true, true)
    DestroyCam(CAM.cam, false)
    CAM.cam = nil
end
RegisterNUICallback('wsCam', function(body, cb)
    cb({})
    if not WS.open or not CAM.cam then return end
    CAM.h = (CAM.h - (tonumber(body.dx) or 0) * 0.35) % 360
    CAM.p = math.max(-10.0, math.min(70.0, CAM.p + (tonumber(body.dy) or 0) * 0.25))
    if tonumber(body.zoom) then CAM.d = math.max(2.5, math.min(16.0, CAM.d + tonumber(body.zoom))) end
    if body.reset then CAM.h, CAM.p = GetEntityHeading(WS.veh) + 220.0, 12.0 end
    CamUpdate()
end)

-- ---------------------------------------------------------------------
-- Ouverture / fermeture
-- ---------------------------------------------------------------------
-- Phares et néons allumés pendant l'atelier (moteur en marche, véhicule figé)
local function LightsOn(veh)
    if not veh or not DoesEntityExist(veh) then return end
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleLights(veh, 2)                 -- phares forcés
    DisableVehicleNeonLights(veh, false)     -- néons (LED) affichés s'ils sont posés / en aperçu
end
local function LightsOff(veh)
    if not veh or not DoesEntityExist(veh) then return end
    SetVehicleLights(veh, 0)                 -- retour au comportement normal
    if not WS.engineWas then SetVehicleEngineOn(veh, false, true, true) end
end

local function Restore()
    if WS.veh and DoesEntityExist(WS.veh) and WS.snapshot then
        Control(WS.veh)
        core:SetVehicleProperties(WS.veh, WS.snapshot)
        if WS.open then LightsOn(WS.veh) end
    end
end

-- Fermeture : le véhicule revient TOUJOURS à son dernier état payé et installé
-- (WS.snapshot : état à l'ouverture, remplacé après chaque installation réussie).
local function Close(silent)
    if not WS.open then return end
    WS.open = false
    Restore()
    if WS.veh and DoesEntityExist(WS.veh) then
        LightsOff(WS.veh)
        FreezeEntityPosition(WS.veh, false)
    end
    CamStop()
    C.Focus('workshop', false)
    SendNUIMessage({ action = 'workshop', show = false })
    if not silent then C.Notify('Atelier fermé : les modifications non payées et non installées ont été retirées.', 'inform') end
end
C.ui.workshop = { close = function() Close(false) end }

-- Véhicule de l'atelier : celui que le mécanicien conduit sur le point, sinon le véhicule
-- garé sur le point le plus proche de lui (il peut être à pied à côté)
local function PointVehicle(w)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        if GetPedInVehicleSeat(veh, -1) ~= ped then return nil end
        return #(GetEntityCoords(veh) - w.coords) <= (w.radius or 3.5) + 1.0 and veh or nil
    end
    local best, bestD = nil, (w.radius or 3.5) + 1.0
    for _, v in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(v) - w.coords)
        if d <= bestD and GetEntitySpeed(v) < 1.0 then best, bestD = v, d end
    end
    return best
end

local function Open(w)
    local ped = PlayerPedId()
    local veh = PointVehicle(w)
    if not veh then return C.Notify('Garez le véhicule du client sur le cercle de l\'atelier.', 'error') end
    if #(GetEntityCoords(ped) - GetEntityCoords(veh)) > 6.0 then return C.Notify('Approchez-vous du véhicule.', 'error') end
    if GetEntitySpeed(veh) > 1.0 then return C.Notify('Arrêtez le véhicule.', 'error') end
    local r = C.Req('wsOpen', { ws = w.id, net = VehToNet(veh) })
    if r.error then return C.Notify(r.error, 'error') end
    if not Control(veh) then return C.Notify('Impossible de prendre la main sur le véhicule, réessayez.', 'error') end
    WS.open, WS.ws, WS.veh, WS.data = true, w, veh, r
    WS.engineWas = GetIsVehicleEngineRunning(veh)
    FreezeEntityPosition(veh, true)              -- le véhicule reste sur le point pendant l'intervention
    WS.snapshot = core:GetVehicleProperties(veh)
    LightsOn(veh)
    -- Niveaux actuels (véhicule) et pièces disponibles par rubrique
    local live = {}
    for k, id in pairs(PERF) do live[k] = GetVehicleMod(veh, id) + 1 end
    live.turbo = IsToggleModOn(veh, 18) and 1 or 0
    local maxLv = {}
    for k, id in pairs(PERF) do maxLv[k] = GetNumVehicleMods(veh, id) end
    maxLv.turbo = 1
    local groups = {}
    for _, it in ipairs(r.items) do
        if it.kind == 'cosmetic' and not groups[it.mod] then
            local subs = Subs(veh, it.mod)
            local opts = subs and {} or select(1, Options(veh, it.mod))
            if it.mod == 'platetext' then groups[it.mod] = { text = true, empty = not r.owned }
            else groups[it.mod] = { subs = subs, empty = (subs and #subs == 0) or (not subs and #opts == 0) } end
        end
    end
    C.Focus('workshop', true)
    CamStart(veh)
    SendNUIMessage({ action = 'workshop', show = true, data = r, live = live, maxLv = maxLv, groups = groups,
        model = C.ModelLabel(veh), health = { engine = math.floor(GetVehicleEngineHealth(veh) / 10), body = math.floor(GetVehicleBodyHealth(veh) / 10) },
        state = C.VehicleState(veh) })
    -- Fermeture automatique si le mécanicien s'éloigne ou si le véhicule bouge de l'emplacement
    CreateThread(function()
        while WS.open do
            Wait(500)
            if DoesEntityExist(veh) then LightsOn(veh) end   -- garde phares, néons et moteur allumés
            if not DoesEntityExist(veh) or #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(veh)) > 6.0 or #(GetEntityCoords(veh) - w.coords) > (w.radius or 3.5) + 2.0
                or C.IsDown() or not C.OnDuty() then
                Close(false)
            end
        end
    end)
end

-- Ouverture depuis le F6 (point le plus proche)
function C.OpenWorkshopNear()
    local pos = GetEntityCoords(PlayerPedId())
    local best, bestD = nil, 12.0
    for _, w in ipairs(C.Workshops()) do
        local d = #(pos - w.coords)
        if d < bestD then best, bestD = w, d end
    end
    if not best then return C.Notify('Aucun point d\'atelier à proximité.', 'error') end
    if not C.OnDuty() then return C.Notify('Prenez votre service (F6) pour utiliser l\'atelier.', 'error') end
    Open(best)
end

RegisterNUICallback('wsOptions', function(body, cb)
    if not WS.open then return cb({ options = {} }) end
    local opts, cur = Options(WS.veh, tostring(body.group or ''), body.sub)
    cb({ options = opts, current = cur })
end)
RegisterNUICallback('wsPreview', function(body, cb)
    cb({})
    if not WS.open or type(body.spec) ~= 'table' then return end
    Control(WS.veh)
    Preview(WS.veh, body.spec)
end)
RegisterNUICallback('wsRevert', function(_, cb)
    cb({})
    if WS.open then Restore() end
end)
-- Retire l'aperçu d'une seule ligne : on repart de l'état d'origine puis on remet les autres lignes
RegisterNUICallback('wsReapply', function(body, cb)
    cb({})
    if not WS.open then return end
    Restore()
    for _, spec in ipairs(type(body.specs) == 'table' and body.specs or {}) do if type(spec) == 'table' then Preview(WS.veh, spec) end end
end)

RegisterNUICallback('wsSend', function(body, cb)
    if not WS.open then return cb({ error = 'Atelier fermé.' }) end
    local r = C.Req('quoteCreate', { ws = WS.ws.id, net = VehToNet(WS.veh), customer = body.customer, items = body.items, model = C.ModelLabel(WS.veh) })
    if r.ok then C.Notify(r.message, 'success') end
    cb(r)
end)

RegisterNUICallback('wsCancelQuote', function(body, cb)
    local r = C.Req('quoteCancel', { uid = body.uid })
    if r.error then C.Notify(r.error, 'error') elseif r.message then C.Notify(r.message, 'inform') end
    cb(r)
end)

-- Installation : propriétés exactes envoyées par le serveur, appliquées puis vérifiées
RegisterNUICallback('wsInstall', function(body, cb)
    if not WS.open then return cb({ error = 'Atelier fermé.' }) end
    local veh = WS.veh
    local r = C.Req('quoteInstallStart', { uid = body.uid, net = VehToNet(veh) })
    if r.error then return cb(r) end
    Restore()                         -- on enlève les aperçus : seul le devis est posé
    Control(veh)
    local results = {}
    -- Pneus en dernier (la variante « pneus personnalisés » se pose sur la jante finale)
    local order = {}
    for i, line in ipairs(r.lines) do if not (line.patch and line.patch.modCustomTiresF ~= nil) then order[#order + 1] = i end end
    for i, line in ipairs(r.lines) do if line.patch and line.patch.modCustomTiresF ~= nil then order[#order + 1] = i end end
    for _, i in ipairs(order) do
        local line = r.lines[i]
        if line.patch then
            core:SetVehicleProperties(veh, line.patch)
            if line.patch.modXenon == true and not line.patch.customXenon then ClearVehicleXenonLightsCustomColor(veh) SetVehicleXenonLightsColor(veh, line.patch.xenonColor or -1) end
            if line.patch.modCustomTiresF ~= nil then
                SetVehicleMod(veh, 23, GetVehicleMod(veh, 23), line.patch.modCustomTiresF == true)
                if IsThisModelABike(GetEntityModel(veh)) then SetVehicleMod(veh, 24, GetVehicleMod(veh, 24), line.patch.modCustomTiresR == true) end
            end
            -- Finition d'une couleur d'origine (le core n'applique la finition qu'aux couleurs libres)
            local pt = line.patch
            if pt.paintType1 and type(pt.color1) == 'number' then
                local _, s2 = GetVehicleColours(veh)
                SetVehicleModColor_1(veh, pt.paintType1, pt.color1, 0) SetVehicleColours(veh, pt.color1, s2)
            end
            if pt.paintType2 and type(pt.color2) == 'number' then
                local p1 = GetVehicleColours(veh)
                SetVehicleModColor_2(veh, pt.paintType2, pt.color2) SetVehicleColours(veh, p1, pt.color2)
            end
            Wait(80)
            results[i] = Verify(veh, line.patch)
        else
            results[i] = true
        end
    end
    local done = C.Req('quoteInstallDone', { uid = body.uid, results = results })
    if done.ok then
        WS.snapshot = core:GetVehicleProperties(veh)   -- l'état payé et installé devient la référence
        LightsOn(veh)
        C.Notify(done.message, done.failed > 0 and 'inform' or 'success')
    end
    cb(done)
end)

RegisterNetEvent('meca:client:quoteUpdate', function(q)
    if WS.open then SendNUIMessage({ action = 'wsQuote', quote = q }) end
end)

-- ---------------------------------------------------------------------
-- Points d'atelier : marqueur et touche E
-- ---------------------------------------------------------------------
local function Help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

-- Texte 3D au-dessus d'un point
local function Text3D(p, text)
    SetDrawOrigin(p.x, p.y, p.z, 0)
    SetTextScale(0.35, 0.35) SetTextFont(4) SetTextCentre(true) SetTextOutline()
    SetTextColour(255, 255, 255, 235)
    BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName(text) EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

-- Blips des ateliers sur la carte (mécaniciens seulement)
local blips, blipSrc = {}, nil
local function ClearBlips() for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end blips = {} end
CreateThread(function()
    while true do
        local list = (C.IsMeca() and C.Can('workshop')) and C.Workshops() or nil
        if list ~= blipSrc then
            blipSrc = list
            ClearBlips()
            for _, w in ipairs(list or {}) do
                local b = AddBlipForCoord(w.coords.x, w.coords.y, w.coords.z)
                SetBlipSprite(b, 446) SetBlipColour(b, 47) SetBlipScale(b, 0.65) SetBlipAsShortRange(b, true)
                BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(('Atelier · %s'):format(w.label)) EndTextCommandSetBlipName(b)
                blips[#blips + 1] = b
            end
        end
        Wait(3000)
    end
end)

local scan = {}   -- [id du point] = { t, veh }
-- Seuls les mécaniciens voient les points. Cercle orange = libre, vert = véhicule en place.
-- E au volant sur le cercle, ou E à pied à côté d'un véhicule garé dessus.
CreateThread(function()
    while true do
        local sleep = 1000
        if C.IsMeca() and C.Can('workshop') and not WS.open then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            for _, w in ipairs(C.Workshops()) do
                local d = #(pos - w.coords)
                if d < 40.0 then
                    sleep = 0
                    local r = w.radius or 3.5
                    -- Recherche du véhicule sur le point : 4 fois par seconde au plus
                    local sc = scan[w.id]
                    if not sc or GetGameTimer() - sc.t > 250 then sc = { t = GetGameTimer(), veh = d < 15.0 and PointVehicle(w) or nil } scan[w.id] = sc end
                    local veh = sc.veh
                    if veh and not DoesEntityExist(veh) then veh = nil end
                    local cr, cg, cb = 245, 158, 11
                    if veh then cr, cg, cb = 34, 197, 94 end
                    if Config.WorkshopMarker then
                        DrawMarker(1, w.coords.x, w.coords.y, w.coords.z - 1.0, 0, 0, 0, 0, 0, 0, r * 2, r * 2, 0.25, cr, cg, cb, 70, false, false, 2, false, nil, nil, false)
                        DrawMarker(36, w.coords.x, w.coords.y, w.coords.z + 1.2, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, cr, cg, cb, 180, true, true, 2, false, nil, nil, false)
                    end
                    if d < 15.0 then
                        Text3D(w.coords + vector3(0.0, 0.0, 2.1), veh and ('~g~%s~s~\nVéhicule en place'):format(w.label) or ('~o~%s~s~\nGarez le véhicule du client ici'):format(w.label))
                    end
                    local inVeh = GetVehiclePedIsIn(ped, false)
                    local near = veh and ((inVeh == veh and GetPedInVehicleSeat(veh, -1) == ped) or (inVeh == 0 and #(pos - GetEntityCoords(veh)) < 4.0))
                    if near and not C.AnyOpen() then
                        if inVeh ~= 0 then DisableControlAction(0, 86, true) end     -- E = klaxon en véhicule
                        Help(('~INPUT_CONTEXT~ Ouvrir l\'atelier · %s'):format(w.label))
                        if IsDisabledControlJustPressed(0, 86) or IsControlJustPressed(0, Config.Keys.workshop) then
                            if not C.OnDuty() then C.Notify('Prenez votre service (F6) pour utiliser l\'atelier.', 'error') else Open(w) end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    ClearBlips()
    if WS.open then
        Restore()
        if WS.veh and DoesEntityExist(WS.veh) then LightsOff(WS.veh) FreezeEntityPosition(WS.veh, false) end
    end
end)
