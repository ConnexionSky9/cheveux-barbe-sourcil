-- =========================================================
--  VÉHICULES › PERSONNALISATION (staff, gratuit, en direct)
--  Le staff est au volant : chaque choix s'applique aussitôt.
--  « Annuler mes changements » remet le véhicule comme à l'ouverture,
--  « Enregistrer » le garde sur la carte grise (player_vehicles).
-- =========================================================
local Snapshot = nil   -- { veh, props } à l'ouverture de l'onglet

-- Propriétés complètes du véhicule : fournies par la base Elyzea (elyzea_core)
local VP = {
    getVehicleProperties = function(veh) return exports.elyzea_core:GetVehicleProperties(veh) end,
    setVehicleProperties = function(veh, props) return exports.elyzea_core:SetVehicleProperties(veh, props) end,
}
local function ox()
    if GetResourceState('elyzea_core') ~= 'started' then return nil end
    return VP
end

local CATS = {
    -- Performance
    { key = 'engine', label = 'Moteur', group = 'perf', kind = 'mod', mod = 11, level = true },
    { key = 'brakes', label = 'Freins', group = 'perf', kind = 'mod', mod = 12, level = true },
    { key = 'transmission', label = 'Transmission', group = 'perf', kind = 'mod', mod = 13, level = true },
    { key = 'suspension', label = 'Suspension', group = 'perf', kind = 'mod', mod = 15, level = true },
    { key = 'armor', label = 'Blindage', group = 'perf', kind = 'mod', mod = 16, level = true },
    { key = 'turbo', label = 'Turbo', group = 'perf', kind = 'toggle', mod = 18 },
    -- Carrosserie
    { key = 'fbumper', label = 'Pare-choc avant', group = 'body', kind = 'mod', mod = 1 },
    { key = 'rbumper', label = 'Pare-choc arrière', group = 'body', kind = 'mod', mod = 2 },
    { key = 'skirts', label = 'Bas de caisse', group = 'body', kind = 'mod', mod = 3 },
    { key = 'spoiler', label = 'Aileron', group = 'body', kind = 'mod', mod = 0 },
    { key = 'hood', label = 'Capot', group = 'body', kind = 'mod', mod = 7 },
    { key = 'grille', label = 'Calandre', group = 'body', kind = 'mod', mod = 6 },
    { key = 'exhaust', label = 'Échappement', group = 'body', kind = 'mod', mod = 4 },
    { key = 'frame', label = 'Arceau', group = 'body', kind = 'mod', mod = 5 },
    { key = 'lfender', label = 'Aile gauche', group = 'body', kind = 'mod', mod = 8 },
    { key = 'rfender', label = 'Aile droite', group = 'body', kind = 'mod', mod = 9 },
    { key = 'roof', label = 'Toit', group = 'body', kind = 'mod', mod = 10 },
    { key = 'archcover', label = 'Passages de roue', group = 'body', kind = 'mod', mod = 42 },
    { key = 'aerials', label = 'Antennes', group = 'body', kind = 'mod', mod = 43 },
    { key = 'trim2', label = 'Garnitures extérieures', group = 'body', kind = 'mod', mod = 44 },
    { key = 'tank', label = 'Réservoir', group = 'body', kind = 'mod', mod = 45 },
    { key = 'windows', label = 'Fenêtres', group = 'body', kind = 'mod', mod = 46 },
    { key = 'trunk', label = 'Coffre', group = 'body', kind = 'mod', mod = 37 },
    { key = 'hydraulics', label = 'Hydraulique', group = 'body', kind = 'mod', mod = 38 },
    { key = 'engineblock', label = 'Bloc moteur', group = 'body', kind = 'mod', mod = 39 },
    { key = 'airfilter', label = 'Filtre à air', group = 'body', kind = 'mod', mod = 40 },
    { key = 'struts', label = 'Barres de renfort', group = 'body', kind = 'mod', mod = 41 },
    { key = 'horn', label = 'Klaxon', group = 'body', kind = 'mod', mod = 14 },
    { key = 'doors', label = 'Portes', group = 'body', kind = 'mod', mod = 47 },
    { key = 'lightbar', label = 'Rampe lumineuse', group = 'body', kind = 'mod', mod = 49 },
    { key = 'extras', label = 'Éléments optionnels', group = 'body', kind = 'extras' },
    -- Roues
    { key = 'wheels', label = 'Jantes', group = 'wheels', kind = 'wheels' },
    { key = 'wheelcolor', label = 'Couleur des jantes', group = 'wheels', kind = 'wheelcolor' },
    { key = 'smoke', label = 'Fumée des pneus', group = 'wheels', kind = 'smoke' },
    { key = 'tyres', label = 'Pneus (flancs, pare-balles)', group = 'wheels', kind = 'tyres' },
    -- Peinture
    { key = 'paint1', label = 'Peinture principale', group = 'paint', kind = 'paint' },
    { key = 'paint2', label = 'Peinture secondaire', group = 'paint', kind = 'paint' },
    { key = 'pearl', label = 'Nacrage', group = 'paint', kind = 'pearl' },
    { key = 'livery', label = 'Livrées', group = 'paint', kind = 'livery' },
    { key = 'tint', label = 'Vitres teintées', group = 'paint', kind = 'tint' },
    { key = 'plate', label = 'Style de plaque', group = 'paint', kind = 'plate' },
    { key = 'platefx', label = 'Plaque animée multicolore', group = 'paint', kind = 'platefx' },
    { key = 'roofliv', label = 'Livrée de toit', group = 'paint', kind = 'roofliv' },
    { key = 'intcolor', label = 'Couleur de l\'intérieur', group = 'interior', kind = 'intcolor' },
    { key = 'dashcolor', label = 'Couleur du tableau de bord', group = 'interior', kind = 'dashcolor' },
    -- Lumières
    { key = 'neon', label = 'Néons', group = 'lights', kind = 'neon' },
    { key = 'xenon', label = 'Phares xénon', group = 'lights', kind = 'xenon' },
    -- Intérieur
    { key = 'plateholder', label = 'Support de plaque', group = 'interior', kind = 'mod', mod = 25 },
    { key = 'vanity', label = 'Plaque personnalisée', group = 'interior', kind = 'mod', mod = 26 },
    { key = 'trim', label = 'Garnitures', group = 'interior', kind = 'mod', mod = 27 },
    { key = 'ornaments', label = 'Ornements', group = 'interior', kind = 'mod', mod = 28 },
    { key = 'dashboard', label = 'Tableau de bord', group = 'interior', kind = 'mod', mod = 29 },
    { key = 'dials', label = 'Compteurs', group = 'interior', kind = 'mod', mod = 30 },
    { key = 'doorspeakers', label = 'Haut-parleurs de portes', group = 'interior', kind = 'mod', mod = 31 },
    { key = 'seats', label = 'Sièges', group = 'interior', kind = 'mod', mod = 32 },
    { key = 'steering', label = 'Volant', group = 'interior', kind = 'mod', mod = 33 },
    { key = 'shifter', label = 'Levier de vitesse', group = 'interior', kind = 'mod', mod = 34 },
    { key = 'plaques', label = 'Plaques décoratives', group = 'interior', kind = 'mod', mod = 35 },
    { key = 'speakers', label = 'Sono', group = 'interior', kind = 'mod', mod = 36 },
}
local BY = {}
for _, c in ipairs(CATS) do BY[c.key] = c end

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
local FIN = { [0] = 'normal', [1] = 'métallisé', [3] = 'mat', [4] = 'métal', [5] = 'chrome' }
local LIGHTS = {
    { 1, 'Blanc', 255, 255, 255 }, { 2, 'Bleu', 2, 21, 255 }, { 3, 'Bleu électrique', 3, 83, 255 }, { 4, 'Vert menthe', 0, 255, 140 },
    { 5, 'Vert lime', 94, 255, 1 }, { 6, 'Jaune', 255, 255, 0 }, { 7, 'Or', 255, 150, 5 }, { 8, 'Orange', 255, 62, 0 },
    { 9, 'Rouge', 255, 1, 1 }, { 10, 'Rose', 255, 50, 100 }, { 11, 'Rose vif', 255, 5, 190 }, { 12, 'Violet', 35, 1, 255 },
    { 13, 'Lumière noire', 15, 3, 255 }, { 14, 'Cyan', 0, 255, 255 }, { 15, 'Magenta', 255, 0, 255 }, { 16, 'Turquoise', 0, 200, 150 },
    { 17, 'Ambre', 255, 191, 0 }, { 18, 'Lavande', 180, 140, 255 },
}
local XENON = { 'Blanc', 'Bleu', 'Bleu électrique', 'Vert menthe', 'Vert lime', 'Jaune', 'Or', 'Orange', 'Rouge', 'Rose', 'Rose vif', 'Violet', 'Lumière noire' }
local TINTS = { { 0, 'Aucune' }, { 4, 'Origine' }, { 3, 'Fumé clair' }, { 2, 'Fumé foncé' }, { 5, 'Limousine' }, { 1, 'Noir pur' }, { 6, 'Vert' } }
local PLATES = { { 0, 'Bleu sur blanc' }, { 3, 'Bleu sur blanc (2)' }, { 4, 'Bleu sur blanc (3)' }, { 1, 'Jaune sur noir' }, { 2, 'Jaune sur bleu' }, { 5, 'North Yankton' } }
local WHEELTYPES = { { 0, 'Sport' }, { 1, 'Muscle' }, { 2, 'Lowrider' }, { 3, 'SUV' }, { 4, 'Tout-terrain' }, { 5, 'Tuner' }, { 7, 'Haut de gamme' },
    { 8, "Benny's Original" }, { 9, "Benny's Bespoke" }, { 11, 'Street' }, { 12, 'Track' }, { 10, 'Roues F1' }, { 6, 'Moto' } }

-- Véhicule dans lequel le staff est monté (n'importe quelle place) ; on prend la main réseau pour le modifier
local function myVehicle()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then return nil end
    return veh
end
local function control(veh)
    if NetworkHasControlOfEntity(veh) then return true end
    local t = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < t do NetworkRequestControlOfEntity(veh) Wait(0) end
    return NetworkHasControlOfEntity(veh)
end
local function netOf(veh) return NetworkGetNetworkIdFromEntity(veh) end
local function fxOf(veh) return Entity(veh).state.elyFx or {} end
local function setFx(veh, kind, on) TriggerServerEvent('adminmenu:action', 'vehcustom_fx', { netId = netOf(veh), kind = kind, fx = on and 'rainbow' or false }) end

local function plateOf(veh) local p = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '') return p end
local function useMod48(veh) return GetNumVehicleMods(veh, 48) > 0 end
local function lightById(id) for _, l in ipairs(LIGHTS) do if l[1] == id then return l end end end
local function rgbMatch(r, g, b)
    for _, l in ipairs(LIGHTS) do if math.abs(l[3] - r) < 6 and math.abs(l[4] - g) < 6 and math.abs(l[5] - b) < 6 then return l[1] end end
    return ('rgb:%d,%d,%d'):format(r, g, b)
end
local function parseRgb(v)
    local r, g, b, f = tostring(v or ''):match('^rgb:(%d+),(%d+),(%d+):?(%d*)$')
    if not r then return nil end
    local c = function(x) return math.max(0, math.min(255, tonumber(x))) end
    return c(r), c(g), c(b), tonumber(f)
end

-- ---------------------------------------------------------
--  Lecture / application
-- ---------------------------------------------------------
local function current(veh, c)
    local k = c.kind
    if k == 'mod' then return GetVehicleMod(veh, c.mod)
    elseif k == 'toggle' then return IsToggleModOn(veh, c.mod) and 1 or 0
    elseif k == 'wheels' then return ('%d:%d'):format(GetVehicleWheelType(veh), GetVehicleMod(veh, 23))
    elseif k == 'paint' then
        if c.key == 'paint1' and GetIsVehiclePrimaryColourCustom(veh) then
            local r, g, b = GetVehicleCustomPrimaryColour(veh)
            return ('rgb:%d,%d,%d:%d'):format(r, g, b, (GetVehicleModColor_1(veh)))
        elseif c.key == 'paint2' and GetIsVehicleSecondaryColourCustom(veh) then
            local r, g, b = GetVehicleCustomSecondaryColour(veh)
            return ('rgb:%d,%d,%d:%d'):format(r, g, b, (GetVehicleModColor_2(veh)))
        end
        local p, s = GetVehicleColours(veh)
        return c.key == 'paint1' and p or s
    elseif k == 'pearl' then return (GetVehicleExtraColours(veh))
    elseif k == 'wheelcolor' then return select(2, GetVehicleExtraColours(veh))
    elseif k == 'neon' then
        if fxOf(veh).neon then return 'fx:rainbow' end
        local any = false
        for i = 0, 3 do if IsVehicleNeonLightEnabled(veh, i) then any = true end end
        if not any then return -1 end
        return rgbMatch(GetVehicleNeonLightsColour(veh))
    elseif k == 'xenon' then
        if fxOf(veh).xenon then return 'fx:rainbow' end
        if not IsToggleModOn(veh, 22) then return -1 end
        local has, r, g, b = GetVehicleXenonLightsCustomColor(veh)
        if has then return ('rgb:%d,%d,%d'):format(r, g, b) end
        local x = GetVehicleXenonLightsColor(veh)
        return (x and x >= 0 and x <= 12) and x or 0
    elseif k == 'platefx' then return fxOf(veh).plate and 1 or 0
    elseif k == 'intcolor' then return GetVehicleInteriorColor(veh)
    elseif k == 'dashcolor' then return GetVehicleDashboardColor(veh)
    elseif k == 'roofliv' then return GetVehicleRoofLivery(veh)
    elseif k == 'tyres' then return (GetVehicleModVariation(veh, 23) and 1 or 0) + (GetVehicleTyresCanBurst(veh) == false and 2 or 0)
    elseif k == 'extras' then return nil
    elseif k == 'tint' then return GetVehicleWindowTint(veh)
    elseif k == 'plate' then return GetVehicleNumberPlateTextIndex(veh)
    elseif k == 'livery' then return useMod48(veh) and GetVehicleMod(veh, 48) or GetVehicleLivery(veh)
    elseif k == 'smoke' then
        if not IsToggleModOn(veh, 20) then return -1 end
        return rgbMatch(GetVehicleTyreSmokeColor(veh))
    end
end

local function apply(veh, c, v)
    control(veh)
    SetVehicleModKit(veh, 0)
    local k = c.kind
    if k == 'mod' then SetVehicleMod(veh, c.mod, tonumber(v), false)
    elseif k == 'toggle' then ToggleVehicleMod(veh, c.mod, tonumber(v) == 1)
    elseif k == 'wheels' then
        local t, i = tostring(v):match('^(%-?%d+):(%-?%d+)$')
        if not t then return end
        SetVehicleWheelType(veh, tonumber(t))
        SetVehicleMod(veh, 23, tonumber(i), false)
        if IsThisModelABike(GetEntityModel(veh)) then SetVehicleMod(veh, 24, tonumber(i), false) end
    elseif k == 'paint' then
        local r, g, b, finish = parseRgb(v)
        local pearl, wheel = GetVehicleExtraColours(veh)
        if r then
            finish = math.max(0, math.min(5, finish or 1))
            if c.key == 'paint1' then SetVehicleModColor_1(veh, finish, 0, 0) SetVehicleCustomPrimaryColour(veh, r, g, b)
            else SetVehicleModColor_2(veh, finish, 0) SetVehicleCustomSecondaryColour(veh, r, g, b) end
        else
            local p, s = GetVehicleColours(veh)
            if c.key == 'paint1' then ClearVehicleCustomPrimaryColour(veh) p = tonumber(v) else ClearVehicleCustomSecondaryColour(veh) s = tonumber(v) end
            SetVehicleColours(veh, p, s)
        end
        SetVehicleExtraColours(veh, pearl, wheel)
    elseif k == 'pearl' then local _, w = GetVehicleExtraColours(veh) SetVehicleExtraColours(veh, tonumber(v), w)
    elseif k == 'wheelcolor' then local pe = GetVehicleExtraColours(veh) SetVehicleExtraColours(veh, pe, tonumber(v))
    elseif k == 'neon' then
        local fx = tostring(v):match('^fx:(%w+)$')
        local r, g, b = parseRgb(v)
        local on = fx ~= nil or r ~= nil or tonumber(v) ~= -1
        for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, on) end
        -- Arc-en-ciel animé : état du véhicule posé par le serveur, animé chez tous les joueurs
        setFx(veh, 'neon', fx ~= nil)
        if r then SetVehicleNeonLightsColour(veh, r, g, b)
        elseif not fx and on then local l = lightById(tonumber(v)) if l then SetVehicleNeonLightsColour(veh, l[3], l[4], l[5]) end end
    elseif k == 'xenon' then
        local fx = tostring(v):match('^fx:(%w+)$')
        local r, g, b = parseRgb(v)
        local on = fx ~= nil or r ~= nil or tonumber(v) ~= -1
        ToggleVehicleMod(veh, 22, on)
        setFx(veh, 'xenon', fx ~= nil)
        if r then SetVehicleXenonLightsCustomColor(veh, r, g, b)
        elseif on and not fx then ClearVehicleXenonLightsCustomColor(veh) SetVehicleXenonLightsColor(veh, tonumber(v)) end
    elseif k == 'platefx' then setFx(veh, 'plate', tonumber(v) == 1)
    elseif k == 'intcolor' then SetVehicleInteriorColor(veh, tonumber(v))
    elseif k == 'dashcolor' then SetVehicleDashboardColor(veh, tonumber(v))
    elseif k == 'roofliv' then SetVehicleRoofLivery(veh, tonumber(v))
    elseif k == 'tyres' then
        local n = tonumber(v) or 0
        SetVehicleMod(veh, 23, GetVehicleMod(veh, 23), n % 2 == 1)
        if IsThisModelABike(GetEntityModel(veh)) then SetVehicleMod(veh, 24, GetVehicleMod(veh, 24), n % 2 == 1) end
        SetVehicleTyresCanBurst(veh, n < 2)
    elseif k == 'extras' then
        local id = tonumber(v)
        if id and DoesExtraExist(veh, id) then SetVehicleExtra(veh, id, IsVehicleExtraTurnedOn(veh, id)) end
    elseif k == 'tint' then SetVehicleWindowTint(veh, tonumber(v))
    elseif k == 'plate' then SetVehicleNumberPlateTextIndex(veh, tonumber(v))
    elseif k == 'livery' then if useMod48(veh) then SetVehicleMod(veh, 48, tonumber(v), false) else SetVehicleLivery(veh, tonumber(v)) end
    elseif k == 'smoke' then
        local r, g, b = parseRgb(v)
        local on = r ~= nil or tonumber(v) ~= -1
        ToggleVehicleMod(veh, 20, on)
        if r then SetVehicleTyreSmokeColor(veh, r, g, b)
        elseif on then local l = lightById(tonumber(v)) if l then SetVehicleTyreSmokeColor(veh, l[3], l[4], l[5]) end end
    end
end

local function modLabel(veh, c, i)
    if c.level then return ('Niveau %d'):format(i + 1) end
    local txt = GetModTextLabel(veh, c.mod, i)
    local label = txt and GetLabelText(txt)
    if not label or label == 'NULL' or label == '' then label = ('%s n°%d'):format(c.label, i + 1) end
    return label
end

local function options(veh, c, wheelType)
    local k, out = c.kind, {}
    if k == 'mod' then
        out[1] = { value = -1, label = 'Origine' }
        for i = 0, GetNumVehicleMods(veh, c.mod) - 1 do out[#out + 1] = { value = i, label = modLabel(veh, c, i) } end
    elseif k == 'toggle' then out = { { value = 0, label = 'Sans' }, { value = 1, label = 'Avec' } }
    elseif k == 'wheels' then
        local curT, curM = GetVehicleWheelType(veh), GetVehicleMod(veh, 23)
        local t = tonumber(wheelType) or curT
        SetVehicleModKit(veh, 0)
        SetVehicleWheelType(veh, t)
        out[1] = { value = ('%d:-1'):format(t), label = 'Origine' }
        for i = 0, GetNumVehicleMods(veh, 23) - 1 do
            local txt = GetModTextLabel(veh, 23, i)
            local label = txt and GetLabelText(txt)
            if not label or label == 'NULL' then label = ('Jante n°%d'):format(i + 1) end
            out[#out + 1] = { value = ('%d:%d'):format(t, i), label = label }
        end
        SetVehicleWheelType(veh, curT)
        SetVehicleMod(veh, 23, curM, false)
        return out, t
    elseif k == 'paint' or k == 'pearl' or k == 'wheelcolor' or k == 'intcolor' or k == 'dashcolor' then
        for _, x in ipairs(COLORS) do out[#out + 1] = { value = x[1], label = ('%s · %s'):format(x[2], FIN[x[3]] or '') } end
    elseif k == 'platefx' then out = { { value = 0, label = 'Fixe' }, { value = 1, label = '🌈 Animée multicolore' } }
    elseif k == 'roofliv' then for i = 0, GetVehicleRoofLiveryCount(veh) - 1 do out[#out + 1] = { value = i, label = ('Livrée de toit n°%d'):format(i + 1) } end
    elseif k == 'tyres' then out = { { value = 0, label = 'Pneus d\'origine' }, { value = 1, label = 'Pneus personnalisés' }, { value = 2, label = 'Pare-balles' }, { value = 3, label = 'Personnalisés + pare-balles' } }
    elseif k == 'extras' then
        for i = 0, 20 do
            if DoesExtraExist(veh, i) then out[#out + 1] = { value = i, label = ('Élément n°%d : %s'):format(i, IsVehicleExtraTurnedOn(veh, i) and 'présent (retirer)' or 'absent (ajouter)') } end
        end
    elseif k == 'neon' or k == 'smoke' then
        out[1] = { value = -1, label = k == 'neon' and 'Éteints' or 'Aucune' }
        if k == 'neon' then out[#out + 1] = { value = 'fx:rainbow', label = '🌈 Arc-en-ciel animé' } end
        for _, l in ipairs(LIGHTS) do out[#out + 1] = { value = l[1], label = l[2] } end
    elseif k == 'xenon' then
        out[1] = { value = -1, label = 'Phares normaux' }
        out[#out + 1] = { value = 'fx:rainbow', label = '🌈 Multicolore animé' }
        for i, l in ipairs(XENON) do out[#out + 1] = { value = i - 1, label = l } end
    elseif k == 'tint' then for _, x in ipairs(TINTS) do out[#out + 1] = { value = x[1], label = x[2] } end
    elseif k == 'plate' then for _, x in ipairs(PLATES) do out[#out + 1] = { value = x[1], label = x[2] } end
    elseif k == 'livery' then
        if useMod48(veh) then
            out[1] = { value = -1, label = 'Origine' }
            for i = 0, GetNumVehicleMods(veh, 48) - 1 do out[#out + 1] = { value = i, label = modLabel(veh, { mod = 48, label = 'Livrée' }, i) } end
        else
            for i = 0, GetVehicleLiveryCount(veh) - 1 do out[#out + 1] = { value = i, label = ('Livrée n°%d'):format(i + 1) } end
        end
    end
    return out
end

local function available(veh, c)
    if c.kind == 'mod' then return GetNumVehicleMods(veh, c.mod) > 0 end
    if c.kind == 'neon' then return IsThisModelACar(GetEntityModel(veh)) end
    if c.kind == 'livery' then return useMod48(veh) or GetVehicleLiveryCount(veh) > 0 end
    if c.kind == 'roofliv' then return GetVehicleRoofLiveryCount(veh) > 0 end
    if c.kind == 'extras' then for i = 0, 20 do if DoesExtraExist(veh, i) then return true end end return false end
    return true
end

-- ---------------------------------------------------------
--  Interface
-- ---------------------------------------------------------
RegisterNUICallback('vc_info', function(_, cb)
    local veh = myVehicle()
    if not veh then return cb({ inVehicle = false }) end
    local L = ox()
    if not Snapshot or Snapshot.veh ~= veh then Snapshot = { veh = veh, props = L and L.getVehicleProperties(veh) or nil } end
    SetVehicleModKit(veh, 0)
    local cats = {}
    for _, c in ipairs(CATS) do
        if available(veh, c) then cats[#cats + 1] = { key = c.key, label = c.label, group = c.group } end
    end
    cb({
        inVehicle = true, plate = plateOf(veh), cats = cats, canRevert = Snapshot.props ~= nil, canSave = L ~= nil,
        driver = GetPedInVehicleSeat(veh, -1) == PlayerPedId(), control = control(veh),
        label = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh))),
        wheelTypes = (function() local o = {} for _, w in ipairs(WHEELTYPES) do o[#o + 1] = { id = w[1], label = w[2] } end return o end)(),
    })
end)

RegisterNUICallback('vc_options', function(body, cb)
    local veh, c = myVehicle(), BY[tostring(body.key)]
    if not veh or not c then return cb({ options = {} }) end
    local opts, wt = options(veh, c, body.wheelType)
    cb({ options = opts, current = current(veh, c), wheelType = wt })
end)

RegisterNUICallback('vc_apply', function(body, cb)
    local veh, c = myVehicle(), BY[tostring(body.key)]
    if veh and c then apply(veh, c, body.value) end
    cb({ current = veh and c and current(veh, c) or nil })
end)

-- Tout au maximum (performances)
RegisterNUICallback('vc_max', function(_, cb)
    local veh = myVehicle()
    if veh then
        SetVehicleModKit(veh, 0)
        for _, m in ipairs({ 11, 12, 13, 15, 16 }) do SetVehicleMod(veh, m, GetNumVehicleMods(veh, m) - 1, false) end
        ToggleVehicleMod(veh, 18, true)
    end
    cb('ok')
end)

RegisterNUICallback('vc_revert', function(_, cb)
    local veh = myVehicle()
    local L = ox()
    if veh and Snapshot and Snapshot.veh == veh and Snapshot.props and L then
        control(veh)
        L.setVehicleProperties(veh, Snapshot.props)
        TriggerServerEvent('adminmenu:action', 'vehcustom_fx', { netId = netOf(veh), clear = true })
    end
    cb('ok')
end)

-- Enregistrer sur la carte grise (si le véhicule appartient à un joueur)
RegisterNUICallback('vc_save', function(_, cb)
    local veh = myVehicle()
    local L = ox()
    if veh and L then
        local props = L.getVehicleProperties(veh)
        TriggerServerEvent('adminmenu:action', 'vehcustom_save', { netId = netOf(veh), props = props })
        Snapshot = { veh = veh, props = props }
    end
    cb('ok')
end)

-- Texte de la plaque : appliqué par le serveur (véhicule de joueur : carte grise, clés et coffre suivent)
RegisterNUICallback('vc_plate', function(body, cb)
    local veh = myVehicle()
    if veh then
        TriggerServerEvent('adminmenu:action', 'vehcustom_plate', { netId = NetworkGetNetworkIdFromEntity(veh), text = tostring(body and body.text or '') })
    end
    cb('ok')
end)

-- ---------------------------------------------------------
--  Effets animés visibles par tous (état « elyFx » posé par le serveur)
--  Néons et xénon : arc-en-ciel RVB. Plaque : GTA ne permet pas une couleur libre
--  pour l'écriture des plaques ; l'animation passe par les styles de plaque du jeu.
-- ---------------------------------------------------------
local PLATE_CYCLE = { 0, 2, 1, 5, 3, 4 }
local function hue(t)
    local h = (t % 6000) / 6000 * 6
    local x = math.floor((1 - math.abs(h % 2 - 1)) * 255)
    if h < 1 then return 255, x, 0 elseif h < 2 then return x, 255, 0 elseif h < 3 then return 0, 255, x
    elseif h < 4 then return 0, x, 255 elseif h < 5 then return x, 0, 255 end
    return 255, 0, x
end
CreateThread(function()
    local list, scanAt = {}, 0
    while true do
        local now = GetGameTimer()
        if now > scanAt then
            scanAt = now + 1500
            list = {}
            local me = GetEntityCoords(PlayerPedId())
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                local fx = Entity(veh).state.elyFx
                if fx and #(GetEntityCoords(veh) - me) < 200.0 then list[#list + 1] = { veh = veh, fx = fx } end
            end
        end
        if #list == 0 then Wait(500) else
            local r, g, b = hue(now)
            for _, e in ipairs(list) do
                local veh, fx = e.veh, e.fx
                if DoesEntityExist(veh) then
                    if fx.neon then SetVehicleNeonLightsColour(veh, r, g, b) end
                    if fx.xenon then
                        if not IsToggleModOn(veh, 22) then ToggleVehicleMod(veh, 22, true) end
                        SetVehicleXenonLightsCustomColor(veh, r, g, b)
                    end
                    if fx.plate then SetVehicleNumberPlateTextIndex(veh, PLATE_CYCLE[math.floor(now / 350) % #PLATE_CYCLE + 1]) end
                end
            end
            Wait(40)
        end
    end
end)
