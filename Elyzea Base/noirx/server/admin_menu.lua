--[[
    NOIR X — Pont admin_menu (onglet « NOIR X »)
    Même contrat que les autres modules du menu (elyzea_illegal › ILLEGAL, Concession, LsCustom) :
        exports.noirx:AdminData(src)               → données de l'onglet
        exports.noirx:AdminAction(src, name, data) → ok, message
    La permission staff (Config.Admin.permission) est REVÉRIFIÉE ici à chaque appel,
    et chaque valeur reçue est validée par les modules (Ratline, Launder, Settings…).

    L'onglet HTML d'admin_menu (html/noirx.js) sera écrit quand j'aurai admin_menu :
    je réutiliserai ses composants (formModal, confirmBox…) au lieu d'en inventer.

    Actions disponibles (data = table) :
      createInformant { name, tagline, greeting }          updateInformant { id, …champs }
      deleteInformant { id }
      createIntel { informant_id, category, title, answer, keywords, price, currency,
                    reliability (0-100), here = true (position du staff) | coords = {x,y,z} | coords = false,
                    expires_in (secondes, facultatif) }
      updateIntel { id, …champs }   deleteIntel { id }   toggleIntel { id, enabled }
      cancelLaunder { id, refund = true|false }
      setSetting { path, value }    resetSetting { path }
      resolvePayout { id, status = 'paid'|'pending' }
      revokeIdentity { handle }
]]

local function staffName(src)
    return ('%s (staff)'):format(GetPlayerName(src) or ('#' .. tostring(src)))
end

local function staffCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

-- Messages lisibles pour les codes d'erreur des validateurs.
local ERRORS = {
    bad_data = 'Données invalides.', name_required = 'Le nom est obligatoire.',
    informant_not_found = 'Informateur introuvable.', bad_category = 'Catégorie inconnue.',
    title_required = 'La question est obligatoire.', answer_required = 'La réponse est obligatoire.',
    bad_price = 'Prix invalide.', bad_currency = 'Devise invalide (sale ou propre).',
    bad_reliability = 'Fiabilité invalide (0 à 100).', bad_coords = 'Position invalide.',
    bad_expiry = 'Expiration invalide.', nothing_to_update = 'Rien à modifier.',
    not_running = 'Ce blanchiment n\'est plus en cours.', locked = 'Ce réglage ne se modifie pas en jeu.',
    unknown_path = 'Réglage inconnu.', type_mismatch = 'Type de valeur incorrect.',
    table_not_allowed = 'Valeur non modifiable.', invalid_number = 'Nombre invalide.',
    no_database = 'Base de données indisponible.',
}
local function err(code) return ERRORS[code] or tostring(code or 'Refusé.') end

-- Réglages exposés dans l'onglet (chemin, libellé, catégorie). Tout autre chemin
-- existant reste modifiable via setSetting / la commande /nx_set.
local SETTINGS = {
    { 'Laundering.minAmount', 'Montant minimum', 'Blanchiment' },
    { 'Laundering.maxAmount', 'Montant maximum', 'Blanchiment' },
    { 'Laundering.feePercent', 'Commission (%)', 'Blanchiment' },
    { 'Laundering.baseSeconds', 'Durée de base (s)', 'Blanchiment' },
    { 'Laundering.secondsPer1000', 'Durée par tranche de 1 000 (s)', 'Blanchiment' },
    { 'Laundering.maxSeconds', 'Durée maximum (s)', 'Blanchiment' },
    { 'Laundering.cooldownSeconds', 'Délai entre deux blanchiments (s)', 'Blanchiment' },
    { 'Laundering.hack.npcChance', 'Chance d\'attaque d\'un pirate PNJ (%)', 'Piratage' },
    { 'Laundering.hack.windowSeconds', 'Durée du duel (s)', 'Piratage' },
    { 'Laundering.hack.lossPercentMin', 'Perte minimum si piraté (%)', 'Piratage' },
    { 'Laundering.hack.lossPercentMax', 'Perte maximum si piraté (%)', 'Piratage' },
    { 'Laundering.hack.maxAttacksPerJob', 'Attaques max par blanchiment', 'Piratage' },
    { 'Ratline.askCooldownSeconds', 'Délai entre deux questions (s)', 'Informateurs' },
    { 'Burner.price', 'Prix d\'un burner', 'Burner' },
    { 'Burner.maxActive', 'Burners actifs max', 'Burner' },
}

local function settingsView()
    local out = {}
    for _, s in ipairs(SETTINGS) do
        out[#out + 1] = { path = s[1], label = s[2], category = s[3], value = Settings.Get(s[1]) }
    end
    local apps = {}
    for i, a in ipairs(Config.Apps) do apps[#apps + 1] = { path = ('Apps.%d.enabled'):format(i), id = a.id, label = a.label, enabled = a.enabled } end
    return out, apps
end

local function intelRow(r)
    return {
        id = tonumber(r.id), informant_id = tonumber(r.informant_id), category = r.category,
        categoryLabel = Config.Ratline.categories[r.category] or r.category,
        title = r.title, answer = r.answer, keywords = r.keywords,
        price = tonumber(r.price) or 0, currency = r.currency, reliability = tonumber(r.reliability) or 100,
        enabled = tonumber(r.enabled) == 1, expires_at = tonumber(r.expires_at),
        coords = r.x and { x = tonumber(r.x), y = tonumber(r.y), z = tonumber(r.z) } or nil,
    }
end

local function adminData(src)
    src = tonumber(src)
    if not src or not Admin.IsStaff(src) then return { available = false, reason = 'Permission refusée.' } end
    if DB.driver == 'none' then return { available = true, noDatabase = true } end
    if not Boot.done then return { available = true, loading = true } end

    local informants = {}
    for _, r in ipairs(Ratline.AdminListInformants()) do
        informants[#informants + 1] = { id = tonumber(r.id), name = r.name, tagline = r.tagline, greeting = r.greeting,
            enabled = tonumber(r.enabled) == 1, sort_order = tonumber(r.sort_order) or 0 }
    end
    local intel = {}
    for _, r in ipairs(Ratline.AdminListIntel()) do intel[#intel + 1] = intelRow(r) end

    local launders = Launder.AdminList()
    local settings, apps = settingsView()
    local stuck = DB.Query('SELECT id, owner, currency, amount, reason, created_at FROM noirx_payouts WHERE status = ? ORDER BY id', { 'processing' })
    local totals = DB.Single([[SELECT COUNT(*) AS n, COALESCE(SUM(amount), 0) AS laundered, COALESCE(SUM(stolen), 0) AS stolen
        FROM noirx_launder_jobs WHERE status = 'done']], {}) or {}

    local categories = {}
    for k, v in pairs(Config.Ratline.categories) do categories[#categories + 1] = { id = k, label = v } end
    table.sort(categories, function(a, b) return a.label < b.label end)

    return {
        available = true,
        stats = {
            informants = #informants, intel = #intel, launders = #launders, stuckPayouts = #stuck,
            launderedTotal = math.floor(tonumber(totals.laundered) or 0), stolenTotal = math.floor(tonumber(totals.stolen) or 0),
            launderedCount = math.floor(tonumber(totals.n) or 0),
        },
        informants = informants,
        intel = intel,
        categories = categories,
        launders = launders,
        stuckPayouts = stuck,
        settings = settings,
        apps = apps,
        symbol = Config.Money.symbol,
        audit = DB.Query('SELECT id, actor, action, details, created_at FROM noirx_audit ORDER BY id DESC LIMIT 40', {}),
    }
end
exports('AdminData', adminData)

local A = {}

A.createInformant = function(src, d)
    local ok, id = Ratline.AdminCreateInformant(d)
    if not ok then return false, err(id) end
    return true, ('Informateur « %s » créé.'):format(tostring(d.name))
end
A.updateInformant = function(src, d)
    local ok, e = Ratline.AdminUpdateInformant(d.id, d)
    return ok == true, ok and 'Informateur mis à jour.' or err(e or 'Informateur introuvable.')
end
A.deleteInformant = function(src, d)
    return Ratline.AdminDeleteInformant(d.id) == true, 'Informateur et ses informations supprimés.'
end

local function intelInput(src, d)
    local data = {}
    for k, v in pairs(d) do data[k] = v end
    if d.here then data.coords = staffCoords(src) end
    data.here, data.id = nil, nil
    if d.expires_in ~= nil then
        local s = math.tointeger(tonumber(d.expires_in))
        data.expires_at = (s and s > 0) and (os.time() + s) or false
        data.expires_in = nil
    end
    return data
end

A.createIntel = function(src, d)
    local ok, id = Ratline.AdminCreateIntel(intelInput(src, d))
    if not ok then return false, err(id) end
    return true, ('Information #%s créée.'):format(tostring(id))
end
A.updateIntel = function(src, d)
    local ok, e = Ratline.AdminUpdateIntel(d.id, intelInput(src, d))
    return ok == true, ok and 'Information mise à jour.' or err(e or 'Information introuvable.')
end
A.toggleIntel = function(src, d)
    local ok = Ratline.AdminUpdateIntel(d.id, { enabled = d.enabled == true })
    return ok == true, ok and (d.enabled and 'Information activée.' or 'Information désactivée.') or 'Information introuvable.'
end
A.deleteIntel = function(src, d)
    return Ratline.AdminDeleteIntel(d.id) == true, 'Information supprimée.'
end

A.cancelLaunder = function(src, d)
    local ok, info = Launder.AdminCancel(d.id, d.refund == true, staffName(src))
    if not ok then return false, err(info) end
    return true, d.refund and ('Blanchiment annulé, %s%d d\'argent sale rendus.'):format(Config.Money.symbol, info) or 'Blanchiment annulé sans remboursement.'
end

A.setSetting = function(src, d)
    local ok, e = Settings.Set(tostring(d.path or ''), d.value, staffName(src))
    return ok == true, ok and 'Réglage enregistré.' or err(e)
end
A.resetSetting = function(src, d)
    local ok, e = Settings.Reset(tostring(d.path or ''), staffName(src))
    return ok == true, ok and 'Réglage remis par défaut (appliqué au prochain redémarrage).' or err(e)
end

A.resolvePayout = function(src, d)
    if d.status ~= 'paid' and d.status ~= 'pending' then return false, 'Statut invalide.' end
    local n = DB.Execute('UPDATE noirx_payouts SET status = ? WHERE id = ? AND status = ?', { d.status, tonumber(d.id), 'processing' })
    Audit.Log(src, 'admin.payout_resolve', { id = d.id, status = d.status })
    return n == 1, n == 1 and 'Paiement mis à jour.' or 'Paiement introuvable.'
end

A.revokeIdentity = function(src, d)
    local row = Ghost.AdminFind(tostring(d.handle or ''))
    if not row then return false, 'Pseudo introuvable.' end
    Ghost.AdminRevoke(row.id, staffName(src))
    return true, ('Identité %s révoquée.'):format(row.handle)
end

local function adminAction(src, name, data)
    src = tonumber(src)
    if not src or not Admin.IsStaff(src) then return false, 'Permission refusée.' end
    local fn = A[name]
    if not fn then return false, 'Action inconnue.' end
    if DB.driver == 'none' then return false, 'Base de données indisponible.' end
    data = type(data) == 'table' and data or {}
    local ok, res, msg = pcall(fn, src, data)
    if not ok then
        NoirX.Error(('Action staff « %s » : %s'):format(tostring(name), tostring(res)))
        return false, 'Erreur interne (voir la console serveur).'
    end
    Audit.Log(src, 'admin.' .. tostring(name), { ok = res == true })
    return res == true, msg
end
exports('AdminAction', adminAction)

-- ─── Versions asynchrones (utilisées par admin_menu/server/noirx.lua) ─────────
-- AdminData / AdminAction lisent la base (Citizen.Await) : appelées depuis une autre
-- ressource, l'attente traverserait l'appel d'export. Ici le travail se fait dans un
-- thread de NOIR X et le résultat repart par un événement serveur LOCAL (jamais réseau,
-- un client ne peut ni l'envoyer ni le recevoir).
exports('AdminDataAsync', function(src)
    src = tonumber(src)
    CreateThread(function()
        local ok, d = pcall(adminData, src)
        if not ok then NoirX.Error('AdminData : ' .. tostring(d)) end
        TriggerEvent('noirx:server:adminData', src, ok and d or { available = false, error = true })
    end)
    return true
end)

exports('AdminActionAsync', function(src, name, data)
    src = tonumber(src)
    CreateThread(function()
        local ok, res, msg = pcall(adminAction, src, name, data)
        if not ok then NoirX.Error('AdminAction : ' .. tostring(res)) end
        TriggerEvent('noirx:server:adminActionDone', src, tostring(name), ok and res == true, ok and msg or 'Erreur interne.')
    end)
    return true
end)
