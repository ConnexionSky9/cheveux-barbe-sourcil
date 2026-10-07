-- =========================================================
--  ARRIVÉE EN VILLE : cinématique de bienvenue, une fois par personnage
--  Lancée à la validation d'un nouveau personnage dans ely_creator
--  (ou, sans ely_creator, à la première arrivée en ville).
--  Permission « manage_welcome » : textes, voir sur soi, rejouer.
-- =========================================================
local AM = AdminMenu
local W = Storage.load('welcome', {})
W.enabled = W.enabled ~= false
W.title = W.title or 'Bienvenue sur'
W.name = W.name or 'Elyzea FA'
W.message = W.message or 'Bon courage. Nous avons hâte de voir ce que vous allez accomplir.'
W.signature = W.signature or "L'équipe Elyzea FA"
W.seen = W.seen or {}

local function save() Storage.save('welcome', W) end
local function texts() return { title = W.title, name = W.name, message = W.message, signature = W.signature } end
local function str(v, max) return (tostring(v or ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, max or 120) end

-- force : ely_creator demande la cinématique même pour un personnage déjà vu (modification staff)
RegisterNetEvent('adminmenu:welcome:check', function(force)
    local src = source
    local cid = Bridge.GetCharId(src)
    if W.enabled and cid and (force == true or not W.seen[cid]) then
        TriggerClientEvent('adminmenu:welcome:play', src, texts())
    else
        -- Pas de cinématique : le joueur récupère l'image tout de suite
        TriggerClientEvent('adminmenu:welcome:skip', src)
    end
end)

-- Marqué « vu » seulement une fois la cinématique allée jusqu'au bout
RegisterNetEvent('adminmenu:welcome:done', function()
    local cid = Bridge.GetCharId(source)
    if cid and not W.seen[cid] then W.seen[cid] = os.time() save() end
end)

local A = AM.Actions
A.welcome_save = { perm = 'manage_welcome', fn = function(src, d)
    W.enabled = d.enabled == true
    if str(d.title) ~= '' then W.title = str(d.title, 60) end
    if str(d.name) ~= '' then W.name = str(d.name, 40) end
    if str(d.message) ~= '' then W.message = str(d.message, 240) end
    W.signature = str(d.signature, 60)
    save()
    AM.notify(src, 'Arrivée en ville enregistrée.', 'success')
    AM.addLog(src, 'Arrivée en ville : réglages', W.enabled and 'activée' or 'désactivée')
end }

A.welcome_test = { perm = 'manage_welcome', noRefresh = true, fn = function(src)
    TriggerClientEvent('adminmenu:welcome:play', src, texts(), true)
end }

A.welcome_replay = { perm = 'manage_welcome', fn = function(src, d)
    local t = tonumber(d.target)
    if not t or not GetPlayerName(t) then return AM.notify(src, 'Joueur introuvable (ID).', 'error') end
    local cid = Bridge.GetCharId(t)
    if cid then W.seen[cid] = nil save() end
    TriggerClientEvent('adminmenu:welcome:play', t, texts())
    AM.notify(src, ('La cinématique de bienvenue est rejouée pour %s.'):format(GetPlayerName(t)), 'success')
    AM.addLog(src, 'Arrivée en ville : rejouée', ('%s [%d]'):format(GetPlayerName(t), t))
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'manage_welcome') then return end
    local n = 0
    for _ in pairs(W.seen) do n = n + 1 end
    data.welcome = { enabled = W.enabled, title = W.title, name = W.name, message = W.message, signature = W.signature,
        seen = n, creator = GetResourceState('ely_creator') == 'started' }
end)
