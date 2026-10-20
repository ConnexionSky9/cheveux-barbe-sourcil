-- =====================================================================
--  ELYZEA PRESSE - serveur : requêtes publiques (tous les joueurs)
--  · Lire le journal (articles publiés de toutes les rédactions, annonces en cours).
--  · Staff (permission admin_menu « presse_manage ») : retirer un article ou une annonce.
--  · Même règle que « presse:req » : limite de fréquence, erreurs rattrapées,
--    le client ne décide jamais d'un droit.
-- =====================================================================
local P = Presse

P.PubActions = {}

-- Texte libre (articles, notes) : retours à la ligne gardés, balises et caractères de contrôle retirés
function P.CleanText(s, max)
    s = tostring(s or ''):gsub('\r\n', '\n'):gsub('[\0-\9\11-\31<>]', '')
    s = s:gsub('\n\n\n+', '\n\n'):gsub('^%s+', ''):gsub('%s+$', '')
    if max and #s > max then
        s = s:sub(1, max)
        while #s > 0 and not utf8.len(s) do s = s:sub(1, -2) end   -- pas de caractère coupé en deux
    end
    return s
end

-- Staff du serveur (admin_menu) ou ACE
function P.IsStaff(src)
    if IsPlayerAceAllowed(src, Config.StaffAce) then return true end
    if GetResourceState('admin_menu') == 'started' then
        local ok, v = pcall(function() return exports.admin_menu:HasPermission(src, Config.StaffPermission) end)
        return ok and v == true
    end
    return false
end

-- Présentoir du journal à proximité (si le journal n'est pas lisible partout)
function P.NearKiosk(src)
    if Config.Reader.anywhere then return true end
    local c = P.Coords(src)
    if not c then return false end
    for _, k in ipairs(P.KioskList and P.KioskList() or {}) do
        if #(c - vector3(k.x, k.y, k.z)) <= 3.0 then return true end
    end
    return false
end

local rate = {}
local function Allowed(src)
    local now = GetGameTimer()
    local r = rate[src]
    if not r or now - r.t > 1000 then rate[src] = { t = now, n = 1 } return true end
    r.n = r.n + 1
    return r.n <= 8
end

Ely.callback.register('presse:pub', function(src, action, data)
    if not P.ready then return { error = 'Le journal démarre, réessayez dans un instant.' } end
    if not Allowed(src) then return { error = 'Trop de demandes, patientez une seconde.' } end
    local a = P.PubActions[tostring(action)]
    if not a then return { error = 'Action inconnue.' } end
    if a.staff and not P.IsStaff(src) then return { error = 'Réservé au staff.' } end
    local ok, res = pcall(a.fn, src, type(data) == 'table' and data or {})
    if not ok then
        print(('^1[PRESSE] Erreur publique « %s » : %s^0'):format(tostring(action), tostring(res)))
        return { error = 'Erreur serveur.' }
    end
    return res or {}
end)

AddEventHandler('playerDropped', function() rate[source] = nil end)
