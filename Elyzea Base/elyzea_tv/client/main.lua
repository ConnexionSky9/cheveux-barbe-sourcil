-- =====================================================================
--  ELYZEA TV - client : état des écrans, télés à écran plat (ALT), télécommande des écrans du staff (E)
-- =====================================================================
TVC = {
    states = {},        -- [clé] = { id, offset, startAt, paused, pausedAt, volume, by }
    screens = {},       -- [id] = { id, name, data = { x, y, z, h, w, hgt, remote, public, range, volume } }
    clock = 0,          -- décalage entre l'heure du serveur et GetCloudTimeAsInt()
}
local C = Config
function TVC.Dbg(...) if C.Debug then print('[elyzea_tv]', ...) end end
function TVC.Notify(msg, kind) pcall(function() exports.elyzea_core:Notify(msg, kind or 'inform') end) end

-- entiers 32 bits signés (les hash du jeu peuvent arriver signés ou non selon la fonction)
local function s32(h) h = math.floor(h) % 4294967296 if h >= 2147483648 then h = h - 4294967296 end return h end
TVC.s32 = s32
TVC.flat = {}       -- [hash] = { model, rt }
for _, t in ipairs(C.FlatTVs) do TVC.flat[s32(GetHashKey(t.model))] = { model = t.model, rt = t.rt } end
function TVC.IsFlat(ent)
    return ent and ent ~= 0 and DoesEntityExist(ent) and TVC.flat[s32(GetEntityModel(ent))] ~= nil
end
-- clé d'une télé du jeu : la même chez tous les joueurs (modèle + position au décimètre)
function TVC.FlatKey(ent)
    local c = GetEntityCoords(ent)
    return ('m%d|%.1f|%.1f|%.1f'):format(s32(GetEntityModel(ent)), c.x, c.y, c.z)
end
function TVC.ParseKey(key)
    local h, x, y, z = tostring(key):match('^m(%-?%d+)|(%-?[%d%.]+)|(%-?[%d%.]+)|(%-?[%d%.]+)$')
    if not h then return nil end
    return { model = tonumber(h), x = tonumber(x), y = tonumber(y), z = tonumber(z) }
end
-- retrouve l'objet télé d'une clé (objet de la carte, présent quand on est assez près)
function TVC.FlatEntity(key)
    local f = TVC.ParseKey(key)
    if not f then return nil end
    local o = GetClosestObjectOfType(f.x, f.y, f.z, 0.6, f.model, false, false, false)
    if o and o ~= 0 and DoesEntityExist(o) then return o end
end

-- ---------------------------------------------------------------- heure commune et position des vidéos
function TVC.Now() return (GetCloudTimeAsInt() or 0) + TVC.clock end
function TVC.Position(st)
    if not st then return 0 end
    if st.paused then return st.pausedAt or 0 end
    return (st.offset or 0) + math.max(0, TVC.Now() - (st.startAt or TVC.Now()))
end

-- ---------------------------------------------------------------- synchronisation avec le serveur
local function setScreens(list)
    local fresh = {}
    for _, s in ipairs(list or {}) do fresh[s.id] = s end
    TVC.screens = fresh
    if TVC.OnScreens then TVC.OnScreens() end
end
RegisterNetEvent('elyzea_tv:client:screens', setScreens)
RegisterNetEvent('elyzea_tv:client:state', function(key, st)
    TVC.states[key] = st
    if TVC.OnState then TVC.OnState(key, st) end
end)
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    Wait(2000)
    local r = Ely.callback.await('elyzea_tv:state', false)
    if type(r) == 'table' then
        if r.now then TVC.clock = r.now - (GetCloudTimeAsInt() or r.now) end
        setScreens(r.screens)
        for k, st in pairs(r.states or {}) do TVC.states[k] = st if TVC.OnState then TVC.OnState(k, st) end end
    end
end)

-- actions (le serveur revérifie distance, lien, délai)
function TVC.Play(key, url)
    local r = Ely.callback.await('elyzea_tv:play', false, key, url)
    if not r or r.error then TVC.Notify(r and r.error or 'Le serveur ne répond pas.', 'error') return false end
    return true
end
function TVC.Control(key, action, value)
    local r = Ely.callback.await('elyzea_tv:control', false, key, action, value)
    if not r or r.error then TVC.Notify(r and r.error or 'Le serveur ne répond pas.', 'error') return false end
    return true
end

-- ---------------------------------------------------------------- ALT : télés à écran plat (fournisseur du menu ALT d'elyzea_police, préfixe « tv: »)
-- liste des télés proches, rafraîchie chaque seconde (pas de parcours des objets à chaque image)
local nearFlat = {}
CreateThread(function()
    while true do
        local me = GetEntityCoords(PlayerPedId())
        local list = {}
        for _, o in ipairs(GetGamePool('CObject')) do
            if TVC.flat[s32(GetEntityModel(o))] then
                local d = #(GetEntityCoords(o) - me)
                if d < 30.0 then list[#list + 1] = o end
            end
        end
        nearFlat = list
        TVC.nearFlat = list
        Wait(1000)
    end
end)

local function titleOf(ent)
    local st = TVC.states[TVC.FlatKey(ent)]
    if st then return st.paused and '📺 Télévision · en pause' or '📺 Télévision · en lecture' end
    return '📺 Télévision'
end
exports('AltTarget', function(ent)
    if TVC.IsFlat(ent) then return titleOf(ent) end
    return nil
end)
exports('AltNearby', function()
    local me = GetEntityCoords(PlayerPedId())
    local best, bd
    for _, o in ipairs(nearFlat) do
        if DoesEntityExist(o) then
            local d = #(GetEntityCoords(o) - me)
            if d < 2.5 and (not bd or d < bd) then best, bd = o, d end
        end
    end
    if not best then return nil end
    return best, titleOf(best)
end)
exports('AltOptions', function(ctx)
    local ent = ctx and ctx.entity
    if not TVC.IsFlat(ent) then return {} end
    local st = TVC.states[TVC.FlatKey(ent)]
    local out = { { id = 'remote', label = 'Télécommande : mettre une vidéo YouTube', icon = 'search', desc = 'Colle un lien YouTube' } }
    if st then
        out[#out + 1] = st.paused and { id = 'resume', label = 'Reprendre la lecture', icon = 'in' } or { id = 'pause', label = 'Mettre en pause', icon = 'out' }
        out[#out + 1] = { id = 'volup', label = ('Volume + (%d %%)'):format(st.volume or 0), icon = 'in' }
        out[#out + 1] = { id = 'voldown', label = 'Volume −', icon = 'out' }
        out[#out + 1] = { id = 'stop', label = 'Éteindre la télé', icon = 'out' }
    end
    return out
end)
exports('AltSelect', function(id, ctx)
    local ent = ctx and ctx.entity
    if not TVC.IsFlat(ent) then return false end
    local key = TVC.FlatKey(ent)
    local st = TVC.states[key]
    CreateThread(function()
        if id == 'remote' then TVC.OpenRemote(key, 'Télévision', GetEntityCoords(ent))
        elseif id == 'pause' then TVC.Control(key, 'pause')
        elseif id == 'resume' then TVC.Control(key, 'resume')
        elseif id == 'stop' then TVC.Control(key, 'stop')
        elseif id == 'volup' and st then TVC.Control(key, 'volume', math.min(100, (st.volume or 0) + 10))
        elseif id == 'voldown' and st then TVC.Control(key, 'volume', math.max(0, (st.volume or 0) - 10)) end
    end)
    return true
end)

-- ---------------------------------------------------------------- écrans du staff : [E] Télécommande au point de commande
local prompt
local function showPrompt(t) if prompt ~= t then prompt = t pcall(function() exports.elyzea_core:ShowTextUI(t) end) end end
local function hidePrompt() if prompt then prompt = nil pcall(function() exports.elyzea_core:HideTextUI() end) end end
TVC.HidePrompt = hidePrompt
CreateThread(function()
    while true do
        local sleep = 800
        local ped = PlayerPedId()
        local p = GetEntityCoords(ped)
        local best, bd
        if not TVC.uiOpen and not TVC.editing and not IsPedInAnyVehicle(ped, false) then
            for _, s in pairs(TVC.screens) do
                local r = s.data.remote
                if r and s.data.public ~= false then
                    local d = #(p - vector3(r.x, r.y, r.z + 1.0))
                    if d < 10.0 then sleep = 0 end
                    if d < C.Custom.remoteDistance and (not bd or d < bd) then best, bd = s, d end
                end
            end
        end
        if best then
            showPrompt(('[E] 📺 Télécommande · %s'):format(best.name))
            if IsControlJustPressed(0, C.Keys.interact) then
                hidePrompt()
                TVC.OpenRemote('s' .. best.id, best.name, vector3(best.data.x, best.data.y, best.data.z))
            end
        else
            hidePrompt()
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then hidePrompt() end end)
