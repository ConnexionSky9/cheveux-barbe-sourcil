-- =========================================================
--  ELYZEA ANIMAUX - SERVEUR : administration
--  Appelé par admin_menu (onglet « Gestion des animaux ») :
--    exports.elyzea_animaux:AdminData(src)
--    exports.elyzea_animaux:AdminAction(src, nom, données) -> succès, message
--  Les permissions sont revérifiées ici (animaux_manage / animaux_owned).
-- =========================================================
A.AdminSearch = {}   -- [staff] = { q, rows }

local function canManage(src) return A.IsStaff(src, Config.AdminPerms.manage) end
local function canOwned(src) return A.IsStaff(src, Config.AdminPerms.owned) end

-- ---------------------------------------------------------
--  Diagnostic
-- ---------------------------------------------------------
local function worldPets()
    local byId, orphans = {}, {}
    local ok, peds = pcall(GetAllPeds)
    if not ok or type(peds) ~= 'table' then return byId, orphans end
    for _, ped in ipairs(peds) do
        local okS, st = pcall(function() return Entity(ped).state.elyPet end)
        if okS and type(st) == 'table' and st.id then
            local id = tonumber(st.id)
            byId[id] = (byId[id] or 0) + 1
            local o = A.Out[id]
            if not o or A.EntityOf(o.netId) ~= ped then orphans[#orphans + 1] = { netId = NetworkGetNetworkIdFromEntity(ped), id = id, name = st.name } end
        end
    end
    return byId, orphans
end

function A.DiagData()
    local d = { out = 0, vendorsOn = 0, farmActive = 0, issues = 0, missingModels = {}, scanned = 0 }
    for _ in pairs(A.Out) do d.out = d.out + 1 end
    for _, v in ipairs(A.Vendors) do if v.enabled then d.vendorsOn = d.vendorsOn + 1 end end
    for _ in pairs(A.FarmLive) do d.farmActive = d.farmActive + 1 end
    for _ in pairs(A.Diag.clientIssues) do d.issues = d.issues + 1 end
    for model, s in pairs(A.Scan) do
        d.scanned = d.scanned + 1
        if not s.exists then d.missingModels[#d.missingModels + 1] = model end
    end
    table.sort(d.missingModels)
    return d
end

local function configErrors()
    local errs = {}
    for _, v in ipairs(A.Vendors) do
        if #v.catalog == 0 then errs[#errs + 1] = ('Vendeur « %s » : catalogue vide.'):format(v.label) end
        for _, sid in ipairs(v.catalog) do
            local sp = A.SpeciesEff(sid)
            local usable = 0
            for _, va in ipairs(sp.variants) do if va.enabled and A.VariantUsable(va) then usable = usable + 1 end end
            if usable == 0 then errs[#errs + 1] = ('Vendeur « %s » : %s n\'a aucun pelage utilisable (il n\'apparaît pas).'):format(v.label, sp.label) end
            if not sp.enabled then errs[#errs + 1] = ('Vendeur « %s » : %s est désactivé (il n\'apparaît pas).'):format(v.label, sp.label) end
        end
        local s = A.Scan[v.model]
        if s and not s.exists then errs[#errs + 1] = ('Vendeur « %s » : modèle %s introuvable.'):format(v.label, v.model) end
    end
    for k, name in pairs(Config.Items) do
        if not A.ItemExists(name) then errs[#errs + 1] = ('Objet « %s » (%s) absent de elyzea_inventory : la fonction correspondante est inutilisable.'):format(name, k) end
    end
    if A.S.exotic.requireItem ~= '' and not A.ItemExists(A.S.exotic.requireItem) then
        errs[#errs + 1] = ('Objet obligatoire des exotiques « %s » inconnu : personne ne pourra en acheter.'):format(A.S.exotic.requireItem)
    end
    if GetResourceState('elyzea_police') ~= 'started' then errs[#errs + 1] = 'elyzea_police n\'est pas démarré : pas de menu ALT (utilise F7 › Mes animaux pour les ordres).' end
    for _, e in ipairs(A.Diag.loadErrors) do errs[#errs + 1] = e end
    return errs
end

local function speciesList()
    local out = {}
    local ids = {}
    for sid in pairs(Config.Species) do ids[#ids + 1] = sid end
    table.sort(ids, function(a, b) return Config.Species[a].label < Config.Species[b].label end)
    for _, sid in ipairs(ids) do
        local sp = A.SpeciesEff(sid)
        local base = Config.Species[sid]
        local vs = {}
        for _, v in ipairs(sp.variants) do
            local scan = A.Scan[v.model]
            vs[#vs + 1] = { id = v.id, label = v.label, model = v.model, c = v.c, d = v.d, t = v.t, extra = v.extra, enabled = v.enabled,
                addon = v.addon, custom = v.custom, usable = A.VariantUsable(v), scanned = scan ~= nil }
        end
        -- Textures trouvées par le scan mais pas encore proposées
        local found = {}
        local known = {}
        for _, v in ipairs(sp.variants) do known[('%s|%d|%d|%d'):format(v.model, v.c, v.d, v.t)] = true end
        local models = {}
        for _, v in ipairs(sp.variants) do models[v.model] = true end
        for model in pairs(models) do
            local s = A.Scan[model]
            if s and s.exists then
                local comp = s.comps['0']
                for dI = 0, (comp and comp.drawables or 0) - 1 do
                    for t = 0, (tonumber(comp.textures[tostring(dI)]) or 0) - 1 do
                        if not known[('%s|0|%d|%d'):format(model, dI, t)] and #found < 30 then found[#found + 1] = { model = model, c = 0, d = dI, t = t } end
                    end
                end
            end
        end
        out[#out + 1] = { id = sid, label = sp.label, cat = sp.cat, exotic = sp.exotic, farm = sp.farm, model = sp.model, profile = sp.profile,
            profileLabel = Config.Profiles[sp.profile] and Config.Profiles[sp.profile].label or sp.profile,
            price = sp.price, basePrice = base.price, fees = sp.fees, baseFees = base.fees or 0, enabled = sp.enabled, variants = vs, found = found }
    end
    return out
end

local function livePets()
    local list = {}
    local byId = worldPets()
    for id, o in pairs(A.Out) do
        local ent = A.EntityOf(o.netId)
        local pos = A.PedPos(o.src)
        list[#list + 1] = { id = id, name = o.name, species = o.species, owner = A.CharName(o.src), src = o.src, cid = o.cid, netId = o.netId,
            exists = ent ~= 0, dist = (ent ~= 0 and pos) and math.floor(#(GetEntityCoords(ent) - pos)) or nil, leash = o.leash,
            harness = o.gear.harness and A.HarnessLabel(o.gear.harness) or nil, copies = byId[id] or 0 }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function A.AdminPetRows(q)
    q = Ani.Text(q, 40, '') or ''
    local rows
    if q == '' then
        rows = MySQL.query.await('SELECT *, UNIX_TIMESTAMP(`acquired_at`) AS acquired FROM `elyzea_animaux` ORDER BY `id` DESC LIMIT 100') or {}
    else
        local like = '%' .. q:gsub('[%%_]', '') .. '%'
        rows = MySQL.query.await([[SELECT a.*, UNIX_TIMESTAMP(a.`acquired_at`) AS acquired FROM `elyzea_animaux` a
            LEFT JOIN `players` p ON p.`citizenid` = a.`citizenid`
            WHERE a.`chip` LIKE ? OR a.`name` LIKE ? OR a.`citizenid` LIKE ? OR CAST(a.`id` AS CHAR) = ?
               OR JSON_UNQUOTE(JSON_EXTRACT(p.`charinfo`, '$.firstname')) LIKE ? OR JSON_UNQUOTE(JSON_EXTRACT(p.`charinfo`, '$.lastname')) LIKE ?
            ORDER BY a.`id` DESC LIMIT 100]], { like, like, like, q, like, like }) or {}
    end
    local out = {}
    for _, r in ipairs(rows) do
        local p = A.RowPublic(r)
        p.cid = r.citizenid
        p.vendor = r.vendor
        p.incoherent = (r.status == 'out' and not A.Out[r.id]) or (r.status ~= 'out' and A.Out[r.id] ~= nil)
        local online = exports.elyzea_core:GetSourceByCitizenId(r.citizenid)
        p.ownerOnline = online ~= nil
        p.owner = online and A.CharName(online) or nil
        out[#out + 1] = p
    end
    return out
end

exports('AdminData', function(src)
    local m, o = canManage(src), canOwned(src)
    if not m and not o then return { available = true, denied = true } end
    local data = { available = true, ready = A.Ready, canManage = m, canOwned = o, keyMenu = Config.Keys.menu }
    if o then
        local s = A.AdminSearch[src]
        data.pets = s and s.rows or nil
        data.search = s and s.q or ''
        data.live = livePets()
        local _, orphans = worldPets()
        data.orphans = orphans
    end
    if m then
        data.settings = A.S
        data.defaults = A.SanitizeSettings({}, Config.Defaults)
        data.schema = A.Schema
        data.sections = A.Sections
        data.accessoryKinds = A.AccessoryKinds
        data.species = speciesList()
        data.categories = Config.Categories
        data.vendors = A.Vendors
        data.models = Config.VendorModels
        data.scenarios = Config.VendorScenarios
        data.styles = Config.HarnessStyles
        data.colors = Config.HarnessColors
        data.profiles = {}
        for id, p in pairs(Config.Profiles) do
            local cmds = {}
            for cid, c in pairs(p.commands or {}) do cmds[#cmds + 1] = c.label end
            table.sort(cmds)
            data.profiles[id] = { label = p.label, harness = p.harness == true, leash = p.leash == true, vehicle = p.vehicle == true, commands = cmds }
        end
        data.farm = { settings = A.Farm, live = {}, rows = {} }
        for encId, live in pairs(A.FarmLive) do local n = 0 for _ in pairs(live.ents) do n = n + 1 end data.farm.live[encId] = n end
        for encId, rows in pairs(A.FarmRows) do
            local list = {}
            for slot, r in pairs(rows) do list[#list + 1] = { slot = slot, species = r.species, variant = r.variant, hunger = math.floor(r.hunger), health = math.floor(r.health) } end
            table.sort(list, function(a, b) return a.slot < b.slot end)
            data.farm.rows[encId] = list
        end
        data.farmProduce = Config.FarmProduce
        local issues = {}
        for _, e in pairs(A.Diag.clientIssues) do issues[#issues + 1] = e end
        table.sort(issues, function(a, b) return (a.last or 0) > (b.last or 0) end)
        local scan = {}
        for model, s in pairs(A.Scan) do
            local c0 = s.comps['0']
            scan[#scan + 1] = { model = model, exists = s.exists, by = s.by, at = s.at, drawables = c0 and c0.drawables or 0, textures = c0 and c0.textures['0'] or 0 }
        end
        table.sort(scan, function(a, b) return a.model < b.model end)
        data.diag = { info = A.DiagData(), errors = configErrors(), saveErrors = A.Diag.saveErrors, issues = issues, scan = scan,
            missingSpecies = Config.MissingSpecies, total = MySQL.scalar.await('SELECT COUNT(*) FROM `elyzea_animaux`') or 0 }
    end
    return data
end)

-- ---------------------------------------------------------
--  Actions
-- ---------------------------------------------------------
local function staffPos(src)
    local pos, ped = A.PedPos(src)
    if not pos then return nil end
    return pos, GetEntityHeading(ped)
end

local function vendorsChanged()
    A.SaveSection('vendors', A.Vendors)
    A.PushWorld()
end

local function farmChanged()
    A.SaveSection('farm', A.Farm)
    A.FarmSyncRows()
    -- enclos modifiés : animaux recréés à leur nouvelle place
    A.FarmDespawnAll()
    A.PushWorld()
end

local function newId(prefix, list)
    for i = 1, 999 do
        local id = ('%s_%d'):format(prefix, i)
        local used = false
        for _, x in ipairs(list) do if x.id == id then used = true end end
        if not used then return id end
    end
end

local Manage, Owned = {}, {}

function Manage.saveSettings(src, d)
    A.S = A.SanitizeSettings(d.values, A.S)
    A.SaveSection('settings', A.S)
    A.PushWorld()
    return true, 'Réglages des animaux enregistrés (appliqués tout de suite).'
end
function Manage.resetSettings()
    A.S = A.SanitizeSettings({}, Config.Defaults)
    A.DeleteSection('settings')
    A.PushWorld()
    return true, 'Réglages généraux remis par défaut (vendeurs, espèces, ferme et animaux possédés inchangés).'
end

function Manage.saveSpecies(src, d)
    local sid = type(d.species) == 'string' and Config.Species[d.species] and d.species
    if not sid then return false, 'Espèce inconnue.' end
    local all = Ani.Copy(A.Species)
    local cur = all[sid] or { variants = {}, custom = {} }
    local v = type(d.values) == 'table' and d.values or {}
    cur.enabled = v.enabled ~= false
    cur.price = Ani.Num(v.price) and v.price or nil
    cur.fees = Ani.Num(v.fees) and v.fees or nil
    cur.variants = type(v.variants) == 'table' and v.variants or cur.variants
    if type(v.custom) == 'table' then cur.custom = v.custom end
    all[sid] = cur
    A.Species = A.SanitizeSpecies(all)
    A.SaveSection('species', A.Species)
    return true, ('%s enregistré.'):format(Config.Species[sid].label)
end
function Manage.addVariant(src, d)
    local sid = type(d.species) == 'string' and Config.Species[d.species] and d.species
    if not sid then return false, 'Espèce inconnue.' end
    local s = A.Scan[d.model]
    if not s or not s.exists then return false, 'Fais d\'abord un scan : ce modèle n\'est pas vérifié.' end
    local comp = s.comps[tostring(d.c or 0)]
    local dI, t = Ani.Int(d.d, 0, 50, 0), Ani.Int(d.t, 0, 50, 0)
    if not comp or dI >= comp.drawables or t >= (tonumber(comp.textures[tostring(dI)]) or 0) then return false, 'Cette texture n\'existe pas sur ce modèle.' end
    local all = Ani.Copy(A.Species)
    local cur = all[sid] or { variants = {}, custom = {} }
    cur.custom = cur.custom or {}
    local id = ('x%d_%d_%d'):format(#cur.custom + 1, dI, t)
    cur.custom[#cur.custom + 1] = { id = id, label = Ani.Text(d.label, 40, ('Robe %d'):format(t + 1)), model = d.model, c = Ani.Int(d.c, 0, 11, 0), d = dI, t = t, extra = 0 }
    all[sid] = cur
    A.Species = A.SanitizeSpecies(all)
    A.SaveSection('species', A.Species)
    return true, 'Pelage ajouté au catalogue : vérifie-le avec l\'aperçu puis renomme-le.'
end
function Manage.removeVariant(src, d)
    local sid = type(d.species) == 'string' and Config.Species[d.species] and d.species
    if not sid then return false, 'Espèce inconnue.' end
    local all = Ani.Copy(A.Species)
    local cur = all[sid]
    if not cur or not cur.custom then return false, 'Pelage introuvable.' end
    local used = MySQL.scalar.await('SELECT COUNT(*) FROM `elyzea_animaux` WHERE `species` = ? AND `variant` = ?', { sid, tostring(d.variant) }) or 0
    if tonumber(used) > 0 then return false, ('%d animal(aux) possédé(s) ont ce pelage : désactive-le plutôt.'):format(used) end
    for i, v in ipairs(cur.custom) do if v.id == d.variant then table.remove(cur.custom, i) break end end
    A.Species = A.SanitizeSpecies(all)
    A.SaveSection('species', A.Species)
    return true, 'Pelage retiré.'
end
function Manage.resetSpecies()
    A.Species = A.SanitizeSpecies({})
    A.DeleteSection('species')
    return true, 'Prix, espèces et pelages remis par défaut (animaux possédés inchangés).'
end

function Manage.vendorSave(src, d)
    local v = type(d.vendor) == 'table' and d.vendor or nil
    if not v then return false end
    if not v.id or v.id == '' then
        local pos, h = staffPos(src)
        if not pos then return false, 'Position introuvable.' end
        v.id = newId('vendeur', A.Vendors)
        v.x, v.y, v.z, v.h = v.x or pos.x, v.y or pos.y, v.z or (pos.z - 1.0), v.h or h
    end
    local old = A.Vendor(v.id)
    local clean = A.SanitizeVendor(v, old)
    if not clean then return false, 'Vendeur invalide (position ?).' end
    if old then
        for i, x in ipairs(A.Vendors) do if x.id == clean.id then A.Vendors[i] = clean end end
    else
        if #A.Vendors >= 40 then return false, '40 vendeurs maximum.' end
        A.Vendors[#A.Vendors + 1] = clean
    end
    vendorsChanged()
    return true, ('Vendeur « %s » enregistré.'):format(clean.label)
end
function Manage.vendorHere(src, d)
    local v = A.Vendor(d.id)
    if not v then return false, 'Vendeur introuvable.' end
    local pos, h = staffPos(src)
    if not pos then return false, 'Position introuvable.' end
    local c = Ani.Copy(v)
    c.x, c.y, c.z, c.h = pos.x, pos.y, pos.z - 1.0, h
    for i, x in ipairs(A.Vendors) do if x.id == v.id then A.Vendors[i] = A.SanitizeVendor(c, v) end end
    vendorsChanged()
    return true, ('« %s » placé à ta position (regarde dans la direction voulue avant de cliquer).'):format(v.label)
end
function Manage.vendorDelete(src, d)
    for i, x in ipairs(A.Vendors) do
        if x.id == d.id then
            table.remove(A.Vendors, i)
            vendorsChanged()
            return true, ('Vendeur « %s » supprimé (animaux déjà vendus conservés).'):format(x.label)
        end
    end
    return false, 'Vendeur introuvable.'
end
function Manage.resetVendors()
    A.Vendors = A.SanitizeVendors(Config.Vendors)
    A.DeleteSection('vendors')
    vendorsChanged()
    return true, 'Vendeurs remis par défaut (animaux possédés inchangés).'
end
function Manage.gotoPoint(src, d)
    local x, y, z = Ani.Num(d.x), Ani.Num(d.y), Ani.Num(d.z)
    if not (x and y and z) then return false end
    SetEntityCoords(GetPlayerPed(src), x + 1.5, y + 1.5, z + 0.2, false, false, false, false)
    return true, 'Téléporté.'
end

function Manage.saveFarm(src, d)
    local v = type(d.values) == 'table' and d.values or {}
    v.enclosures = A.Farm.enclosures
    A.Farm = A.SanitizeFarm(v, A.Farm)
    farmChanged()
    return true, 'Réglages de la ferme enregistrés.'
end
function Manage.enclosureSave(src, d)
    local e = type(d.enclosure) == 'table' and d.enclosure or nil
    if not e then return false end
    if not e.id or e.id == '' then
        local pos = staffPos(src)
        if not pos then return false, 'Position introuvable.' end
        e.id = newId('enclos', A.Farm.enclosures)
        e.x, e.y, e.z = e.x or pos.x, e.y or pos.y, e.z or (pos.z - 1.0)
    end
    local old = A.Enclosure(e.id)
    local clean = A.SanitizeEnclosure(e, old)
    if not clean then return false, 'Enclos invalide.' end
    local list = Ani.Copy(A.Farm.enclosures)
    local found = false
    for i, x in ipairs(list) do if x.id == clean.id then list[i] = clean found = true end end
    if not found then
        if #list >= 30 then return false, '30 enclos maximum.' end
        list[#list + 1] = clean
    end
    A.Farm.enclosures = list
    farmChanged()
    return true, ('Enclos « %s » enregistré.'):format(clean.label)
end
function Manage.enclosureHere(src, d)
    local e = A.Enclosure(d.id)
    if not e then return false, 'Enclos introuvable.' end
    local pos = staffPos(src)
    if not pos then return false end
    local c = Ani.Copy(e)
    c.x, c.y, c.z = pos.x, pos.y, pos.z - 1.0
    return Manage.enclosureSave(src, { enclosure = c })
end
function Manage.enclosureDelete(src, d)
    for i, x in ipairs(A.Farm.enclosures) do
        if x.id == d.id then
            table.remove(A.Farm.enclosures, i)
            farmChanged()
            return true, ('Enclos « %s » supprimé.'):format(x.label)
        end
    end
    return false, 'Enclos introuvable.'
end
function Manage.resetFarm()
    A.Farm = A.SanitizeFarm({}, Config.Farm)
    A.DeleteSection('farm')
    farmChanged()
    return true, 'Ferme remise par défaut.'
end

function Manage.scan(src) A.RequestScan(src) return true, nil end
function Manage.clearIssues() A.Diag.clientIssues = {} A.Diag.saveErrors = {} return true, 'Diagnostic vidé.' end
function Manage.preview(src, d)
    local v, sp = A.Variant(d.species, d.variant)
    if not v then return false, 'Pelage introuvable.' end
    TriggerClientEvent('elyzea_animaux:client:adminPreview', src, { model = v.model, c = v.c, d = v.d, t = v.t, label = ('%s · %s'):format(sp.label, v.label) })
    return true, nil
end

-- Animaux possédés
function Owned.searchPets(src, d)
    A.AdminSearch[src] = { q = Ani.Text(d.q, 40, '') or '', rows = A.AdminPetRows(d.q) }
    return true, nil
end
local function refreshSearch(src)
    local s = A.AdminSearch[src]
    if s then s.rows = A.AdminPetRows(s.q) end
end
function Owned.petStore(src, d)
    local id = tonumber(d.id)
    local r = id and A.GetPet(id)
    if not r then return false, 'Animal introuvable.' end
    if A.Out[id] then
        local o = A.Out[id]
        A.StorePet(id, 'admin')
        A.Notify(o.src, ('%s a été rangé par le staff.'):format(o.name), 'inform')
    else
        MySQL.update.await("UPDATE `elyzea_animaux` SET `status` = 'stored' WHERE `id` = ? AND `status` = 'out'", { id })
    end
    refreshSearch(src)
    A.Log(src, 'Staff : animal rangé', ('%s (#%d, %s)'):format(r.name, id, r.citizenid))
    return true, ('%s renvoyé dans son stockage.'):format(r.name)
end
function Owned.petFix(src, d)
    local id = tonumber(d.id)
    local r = id and A.GetPet(id)
    if not r then return false, 'Animal introuvable.' end
    local status = (d.status == 'stored' or d.status == 'injured') and d.status or 'stored'
    if A.Out[id] then A.StorePet(id, 'admin') end
    local h = Ani.Int(d.health, 0, 100, r.health)
    local hu = Ani.Int(d.hunger, 0, 100, r.hunger)
    local th = Ani.Int(d.thirst, 0, 100, r.thirst)
    if status == 'stored' and h <= 0 then h = 50 end
    MySQL.update.await('UPDATE `elyzea_animaux` SET `status` = ?, `health` = ?, `hunger` = ?, `thirst` = ?, `injured_at` = ? WHERE `id` = ?',
        { status, h, hu, th, status == 'injured' and os.time() or nil, id })
    refreshSearch(src)
    A.Log(src, 'Staff : état d\'animal corrigé', ('%s (#%d) : %s, santé %d, faim %d, soif %d'):format(r.name, id, status, h, hu, th))
    return true, ('État de %s corrigé.'):format(r.name)
end
function Owned.petRemove(src, d)
    local id = tonumber(d.id)
    local r = id and A.GetPet(id)
    if not r then return false, 'Animal introuvable.' end
    if tostring(d.confirm or '') ~= r.chip then return false, 'Confirmation incorrecte (numéro de puce).' end
    if A.Out[id] then A.StorePet(id, 'admin') end
    MySQL.query.await('DELETE FROM `elyzea_animaux` WHERE `id` = ?', { id })
    local online = exports.elyzea_core:GetSourceByCitizenId(r.citizenid)
    if online then A.Notify(online, ('%s ne fait plus partie de tes animaux (décision du staff).'):format(r.name), 'warning') end
    refreshSearch(src)
    A.Log(src, 'Staff : animal retiré', ('%s (#%d, puce %s) retiré à %s'):format(r.name, id, r.chip, r.citizenid))
    return true, ('%s retiré de la possession de son propriétaire.'):format(r.name)
end
function Owned.deleteOrphan(src, d)
    local ent = A.EntityOf(tonumber(d.netId))
    if ent == 0 then return false, 'Entité déjà disparue.' end
    local ok, st = pcall(function() return Entity(ent).state.elyPet end)
    if not ok or type(st) ~= 'table' then return false, 'Ce n\'est pas un animal du système.' end
    local o = A.Out[tonumber(st.id)]
    if o and A.EntityOf(o.netId) == ent then return false, 'Cet animal est légitime (sorti par son propriétaire).' end
    DeleteEntity(ent)
    A.Log(src, 'Staff : entité animale orpheline supprimée', ('animal #%s'):format(tostring(st.id)))
    return true, 'Entité supprimée.'
end
function Owned.gotoPet(src, d)
    local o = A.Out[tonumber(d.id) or -1]
    local ent = o and A.EntityOf(o.netId) or 0
    if ent == 0 then return false, 'Animal introuvable dans le monde.' end
    local c = GetEntityCoords(ent)
    SetEntityCoords(GetPlayerPed(src), c.x + 1.0, c.y + 1.0, c.z, false, false, false, false)
    return true, 'Téléporté.'
end

exports('AdminAction', function(src, name, d)
    d = type(d) == 'table' and d or {}
    if not A.Ready then return false, 'elyzea_animaux démarre encore.' end
    local fn
    if Manage[name] then
        if not canManage(src) then return false, 'Permission « animaux_manage » requise.' end
        fn = Manage[name]
    elseif Owned[name] then
        if not canOwned(src) then return false, 'Permission « animaux_owned » requise.' end
        fn = Owned[name]
    else
        return false, 'Action inconnue.'
    end
    local ok, success, msg = pcall(fn, src, d)
    if not ok then
        print(('^1[ANIMAUX] Action admin « %s » : %s^7'):format(name, tostring(success)))
        return false, 'Erreur du serveur (voir la console).'
    end
    if success and msg and name ~= 'searchPets' then A.Log(src, 'Admin : ' .. name, msg) end
    return success, msg
end)

AddEventHandler('playerDropped', function() A.AdminSearch[source] = nil end)
