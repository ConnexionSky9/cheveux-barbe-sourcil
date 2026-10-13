-- =====================================================================
--  ELYZEA CONCESSION - client : administration automobile (staff)
--  Ouverte depuis admin_menu (« Administration automobile ») ou /concessadmin.
--  Le serveur revérifie la permission « dealer_manage » à chaque action.
--  · Recherche de modèles : liste RÉELLE des modèles chargés dans le jeu
--    (GetAllVehicleModels, véhicules ajoutés par des ressources compris).
--  · Vérification : le modèle doit exister (IsModelInCdimage) ET être un véhicule.
--  · Aperçu en jeu : points, places de sortie et emplacements de la concession choisie.
-- =====================================================================
local C = CDC
local isOpen, preview = false, nil

local function Close()
    if not isOpen then return end
    isOpen = false
    C.Focus('admin', false)
    SendNUIMessage({ action = 'admin', show = false })
end
C.ui.admin = { close = Close }

-- Import de tous les véhicules chargés par le jeu (base + ressources) vers le catalogue global.
-- Le jeu fournit classe, nom, marque, places et performances ; le serveur choisit la catégorie
-- (classe GTA) et le prix (classe + rang de performance dans la classe : score de 0 à 1).
local importing = false
local function ImportGame()
    if importing then return { error = 'Import déjà en cours.' } end
    importing = true
    local ok, list = pcall(GetAllVehicleModels)
    local items, byClass = {}, {}
    for _, name in ipairs(ok and list or {}) do
        name = tostring(name):lower()
        local hash = joaat(name)
        if IsModelInCdimage(hash) and IsModelAVehicle(hash) then
            local make = GetMakeNameFromVehicleModel(hash)
            local brand = make and make ~= '' and GetLabelText(make) or ''
            if brand == 'NULL' then brand = make or '' end
            local it = { model = name, label = C.LabelOf(hash), brand = brand, class = GetVehicleClassFromName(hash), seats = GetVehicleModelNumberOfSeats(hash),
                perf = (GetVehicleModelEstimatedMaxSpeed(hash) or 0.0) + (GetVehicleModelAcceleration(hash) or 0.0) * 100.0 }
            items[#items + 1] = it
            byClass[it.class] = byClass[it.class] or {}
            table.insert(byClass[it.class], it)
        end
    end
    for _, l in pairs(byClass) do
        table.sort(l, function(a, c) return a.perf < c.perf end)
        for i, it in ipairs(l) do it.score = #l > 1 and (i - 1) / (#l - 1) or 0.5 it.perf = nil end
    end
    if #items == 0 then importing = false return { error = 'Aucun véhicule trouvé dans le jeu.' } end
    local res
    for i = 1, #items, 50 do
        local chunk = {}
        for j = i, math.min(i + 49, #items) do chunk[#chunk + 1] = items[j] end
        res = C.Adm('importGame', { list = chunk, first = i == 1, last = i + 50 > #items })
        if res.error then break end
    end
    importing = false
    return res
end

local function Open()
    if isOpen then return Close() end
    local r = C.Adm('data')
    if r.error then return C.Notify(r.error, 'error') end
    if r.needImport then
        C.Notify('Premier lancement : import automatique de tous les véhicules du jeu…', 'inform')
        local ir = ImportGame()
        C.Show(ir)
        r = C.Adm('data')
        if r.error then return C.Notify(r.error, 'error') end
    end
    isOpen = true
    C.Focus('admin', true)
    SendNUIMessage({ action = 'admin', show = true, data = r, preview = preview ~= nil })
end
RegisterNetEvent('concess:client:openAdmin', Open)
RegisterCommand('concessadmin', Open, false)
RegisterNUICallback('adminHide', function(_, cb) cb({}) Close() end)

-- Informations d'un modèle lues dans le jeu
local function Info(name)
    local hash = joaat(name)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return nil end
    local make = GetMakeNameFromVehicleModel(hash)
    local brand = make and make ~= '' and GetLabelText(make) or ''
    if brand == 'NULL' then brand = make or '' end
    return { model = name:lower(), label = C.LabelOf(hash), brand = brand, class = GetVehicleClassFromName(hash), seats = GetVehicleModelNumberOfSeats(hash) }
end

RegisterNUICallback('admImport', function(_, cb) cb(ImportGame()) end)

local allModels = nil
RegisterNUICallback('admVehSearch', function(body, cb)
    if not allModels then
        allModels = {}
        local ok, list = pcall(GetAllVehicleModels)
        for _, m in ipairs(ok and list or {}) do allModels[#allModels + 1] = tostring(m):lower() end
        table.sort(allModels)
    end
    local q = tostring(body.q or ''):lower()
    local out = {}
    if #q >= 2 then
        for _, m in ipairs(allModels) do
            local label = C.LabelOf(m)
            if m:find(q, 1, true) or label:lower():find(q, 1, true) then
                local i = Info(m)
                if i then out[#out + 1] = i end
                if #out >= 60 then break end
            end
        end
    end
    cb({ list = out, total = #allModels })
end)

RegisterNUICallback('admVehCheck', function(body, cb)
    local name = tostring(body.model or ''):lower():gsub('[^%w_%-]', '')
    local i = name ~= '' and Info(name)
    if not i then return cb({ ok = false, model = name, error = ('« %s » n\'existe pas dans le jeu ou n\'est pas un véhicule.'):format(name) }) end
    i.ok = true
    cb(i)
end)

-- ---------------------------------------------------------------------
-- Aperçu en jeu des points de la concession choisie
-- ---------------------------------------------------------------------
RegisterNUICallback('admPreview', function(body, cb)
    preview = type(body.shop) == 'table' and body.shop or nil
    cb({ on = preview ~= nil })
end)

local function Label3D(p, text, col)
    SetDrawOrigin(p.x + 0.0, p.y + 0.0, p.z + 0.6, 0)
    SetTextScale(0.3, 0.3) SetTextFont(4) SetTextCentre(true) SetTextOutline()
    SetTextColour(col[1], col[2], col[3], 255)
    BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName(text) EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end
local function Arrow(p, col)
    local h = math.rad(p.h or 0.0)
    DrawMarker(2, p.x - math.sin(h) * 1.2, p.y + math.cos(h) * 1.2, p.z + 0.2, 0, 0, 0, 90.0, 0.0, -(p.h or 0.0), 0.6, 0.6, 0.6, col[1], col[2], col[3], 200, false, false, 2, false, nil, nil, false)
end
CreateThread(function()
    local COL = { manage = { 245, 158, 11 }, catalog = { 59, 130, 246 }, preview = { 168, 85, 247 }, exit = { 34, 197, 94 }, slot = { 236, 72, 153 } }
    local NAMES = { manage = 'Gestion', catalog = 'Catalogue', preview = 'Aperçu' }
    while true do
        if not preview then Wait(500) else
            local pc = GetEntityCoords(PlayerPedId())
            local pts = preview.points or {}
            for k, name in pairs(NAMES) do
                local p = pts[k]
                if p and #(pc - C.Vec(p)) < 80.0 then C.Circle(p, COL[k], p.r) Label3D(p, ('%s · %s%s'):format(preview.name or '', name, p.on == false and ' (désactivé)' or ''), COL[k]) Arrow(p, COL[k]) end
            end
            for i, p in ipairs(pts.exits or {}) do
                if #(pc - C.Vec(p)) < 80.0 then C.Circle(p, COL.exit, 2.5) Label3D(p, ('Sortie %d%s'):format(i, p.on == false and ' (désactivée)' or ''), COL.exit) Arrow(p, COL.exit) end
            end
            for _, s in ipairs(preview.slots or {}) do
                if #(pc - C.Vec(s)) < 80.0 then C.Circle(s, COL.slot, 2.5) Label3D(s, ('Exposition · %s%s'):format(s.label or ('#' .. s.id), s.model and (' · ' .. s.model) or ' · libre'), COL.slot) Arrow(s, COL.slot) end
            end
            Wait(0)
        end
    end
end)
