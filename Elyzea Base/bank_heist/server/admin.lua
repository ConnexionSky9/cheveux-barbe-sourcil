-- =====================================================================
--  BANK HEIST - serveur : administration (onglet « Braquage de banque » d'admin_menu)
--  admin_menu appelle exports.bank_heist:AdminData() et AdminAction(src, nom, données).
--  La permission « bankheist_manage » est vérifiée par admin_menu ET revérifiée ici.
-- =====================================================================
local P = BHS

exports('AdminData', function()
    local banks = {}
    for _, b in ipairs(P.S.banks) do
        local s = P.sessions[b.id]
        local robbers = {}
        if s then for id in pairs(s.participants) do robbers[#robbers + 1] = Adapters.Perms.Name(id) end end
        banks[b.id] = { phase = P.Phase(b.id), cooldown = math.max(0, math.ceil(((P.cooldown[b.id] or 0) - os.time()) / 60)),
            session = s and { id = s.id, state = s.state, robbers = robbers, threatened = s.threatened, pool = s.pool, initial = s.initialPool or 0, distributed = s.distributed,
                hacker = s.hackBy and Adapters.Perms.Name(s.hackBy) or nil, startedAt = s.startedAt, openLeft = s.openUntil and math.max(0, s.openUntil - os.time()) or nil } or nil }
    end
    local items = {}
    for k, it in pairs(P.S.items) do items[k] = Adapters.Inv.Exists(it.name) end
    return {
        available = true, settings = P.S, defaults = P.Sanitize(nil), banks = banks, items = items, globalCooldown = math.max(0, math.ceil((P.globalUntil - os.time()) / 60)),
        police = Adapters.Police.Count(), policeRes = GetResourceState('elyzea_police') == 'started', bagRes = Adapters.Bag.Ready(),
        inventoryRes = GetResourceState('elyzea_inventory') == 'started', imagePath = Config.ImagePath, pedModels = Config.PedModels,
        gameList = Config.GameList, gameLabels = Config.GameLabels,
        logs = MySQL.query.await('SELECT `kind`, `ref`, `name`, `details`, UNIX_TIMESTAMP(`created_at`) AS t FROM `bh_logs` ORDER BY `id` DESC LIMIT 120') or {},
    }
end)

local A = {}
A.save = function(src, d) P.SaveSettings(d) P.Log('admin', 'save', src, 'Réglages enregistrés') return true, 'Réglages du braquage de banque enregistrés.' end
A.reset = function(src) P.ResetSettings() P.Log('admin', 'reset', src, 'Valeurs par défaut') return true, 'Valeurs par défaut restaurées (config.lua).' end

-- Placer un point à la position du staff (le brouillon complet est envoyé pour ne rien perdre)
A.place = function(src, d)
    local draft = type(d.draft) == 'table' and d.draft or P.S
    local pos, h = P.PedPos(src)
    if not pos then return false, 'Position introuvable.' end
    local p = { x = pos.x, y = pos.y, z = pos.z, h = h }
    local list = ({ bank = draft.banks, merchant = draft.merchants, deposit = draft.deposits })[d.target]
    local e = type(list) == 'table' and list[tonumber(d.index) or 0]
    if not e then return false, 'Élément introuvable.' end
    local what = tostring(d.what or '')
    if d.target == 'merchant' then e.ped = e.ped or {} e.ped.x, e.ped.y, e.ped.z, e.ped.h = p.x, p.y, p.z, p.h
    elseif d.target == 'deposit' then e.x, e.y, e.z = p.x, p.y, p.z
    elseif what == 'start' then e.start = { x = p.x, y = p.y, z = p.z }
    elseif what == 'clerk' then e.clerk = e.clerk or {} e.clerk.x, e.clerk.y, e.clerk.z, e.clerk.h = p.x, p.y, p.z, p.h
    elseif what == 'vault' then e.vault = p
    elseif what == 'cash' then e.cash = type(e.cash) == 'table' and e.cash or {} e.cash[#e.cash + 1] = p
    elseif what == 'door' then
        -- la porte est cherchée par chaque joueur autour de ce point (objet de la carte, non synchronisé)
        e.door = e.door or {}
        e.door.x, e.door.y, e.door.z = p.x, p.y, p.z
    else return false, 'Point inconnu.' end
    P.SaveSettings(draft)
    P.Log('admin', 'place', src, ('%s %s : %s placé à %.2f, %.2f, %.2f'):format(d.target, tostring(e.id), what ~= '' and what or 'point', p.x, p.y, p.z))
    return true, 'Position enregistrée.'
end

A.teleport = function(src, d)
    local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
    if not x or not y or not z then return false, 'Position invalide.' end
    SetEntityCoords(GetPlayerPed(src), x + 0.0, y + 0.0, z + 0.0, false, false, false, false)
    return true, 'Téléporté.'
end

A.cancel = function(src, d)
    local id = tostring(d.bank or '')
    if not P.sessions[id] then return false, 'Aucun braquage en cours dans cette banque.' end
    P.EndSession(id, 'annulé par le staff ' .. Adapters.Perms.Name(src), src)
    return true, 'Braquage annulé (aucun butin redistribué ; les sacs déjà remplis restent à leurs porteurs).'
end

A.resetBank = function(src, d)
    local id = tostring(d.bank or '')
    if P.sessions[id] then return false, 'Annulez d\'abord le braquage en cours.' end
    P.cooldown[id] = 0
    MySQL.query('UPDATE `bh_state` SET `cooldown_until` = 0 WHERE `bank_id` = ?', { id })
    P.PublishBanks()
    P.Log('admin', id, src, 'Délai de la banque remis à zéro')
    return true, 'Banque disponible.'
end

A.resetGlobal = function(src)
    P.globalUntil = 0
    MySQL.query('UPDATE `bh_state` SET `cooldown_until` = 0 WHERE `bank_id` = ?', { '_global' })
    P.PublishBanks()
    P.Log('admin', '_global', src, 'Délai global remis à zéro')
    return true, 'Délai global remis à zéro.'
end

exports('AdminAction', function(src, name, data)
    if not Adapters.Perms.IsAdmin(src) then return false, 'Permission refusée.' end
    local fn = A[tostring(name or '')]
    if not fn then return false, 'Action inconnue.' end
    return fn(src, type(data) == 'table' and data or {})
end)
