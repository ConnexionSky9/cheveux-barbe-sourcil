-- =====================================================================
--  ELYZEA LABS · serveur : entrée, code, sortie, instance
--  · Chaque laboratoire a sa propre instance (routing bucket 52000 + id) : plusieurs
--    laboratoires utilisent le même intérieur sans se voir.
--  · Autorisé (droit « entrer ») : E sans code. Sinon : code (vérifié sur l'empreinte salée).
--  · Le code n'est jamais envoyé aux clients.
-- =====================================================================
local L = Labs
local Fails = {}   -- ['src:lab'] = { n, untilT }

local function kvpKey(cid) return 'labs:last:' .. tostring(cid) end

-- Données envoyées au joueur qui entre (intérieur, équipements posés, ses droits)
function L.InsideData(src, lab)
    local role, rights = L.Rights(src, lab)
    local it = L.Interior(lab.interior)
    return { id = lab.id, name = lab.name, interior = it, role = role, rights = rights, level = lab.level,
        equipment = L.PlacedList and L.PlacedList(lab) or {}, staff = L.inside[src] and L.inside[src].via == 'admin' }
end

function L.PutInside(src, lab, via)
    local cid = L.Cid(src)
    L.inside[src] = { lab = lab.id, via = via, t = os.time() }
    SetPlayerRoutingBucket(src, L.Bucket(lab))
    if cid then SetResourceKvp(kvpKey(cid), tostring(lab.id)) end
    TriggerClientEvent('elyzea_labs:enter', src, L.InsideData(src, lab))
    L.Log(lab.id, 'entree', L.Name(src), via == 'code' and 'entrée avec le code' or via == 'admin' and 'entrée (staff)' or 'entrée')
end

function L.PutOutside(src, reason)
    local i = L.inside[src]
    if not i then return end
    local lab = L.list[i.lab]
    L.inside[src] = nil
    if L.CancelCraftOf then L.CancelCraftOf(src) end
    SetPlayerRoutingBucket(src, 0)
    local cid = L.Cid(src)
    if cid then DeleteResourceKvp(kvpKey(cid)) end
    local p = lab and { x = lab.x, y = lab.y, z = lab.z, h = lab.h } or nil
    TriggerClientEvent('elyzea_labs:exit', src, p, reason)
end

-- Rafraîchit les droits des joueurs présents (changement de grade, de droits, de propriétaire)
function L.RefreshInside(lab, kickRevoked, reason)
    for src, i in pairs(L.inside) do
        if i.lab == lab.id then
            local role = L.Rights(src, lab)
            if kickRevoked and role == nil and i.via ~= 'admin' then
                L.PutOutside(src, reason or 'Tu n\'as plus accès à ce laboratoire.')
            else
                TriggerClientEvent('elyzea_labs:rights', src, L.InsideData(src, lab))
            end
        end
    end
end

function L.Present(lab)
    local n = 0
    for _, i in pairs(L.inside) do if i.lab == lab.id then n = n + 1 end end
    return n
end

local function nearEntrance(src, lab) return L.Dist(src, lab) <= Config.InteractDistance + 1.5 and GetPlayerRoutingBucket(src) == 0 end

-- Infos de l'entrée (ce que le joueur peut faire ici)
L.pub.entrance = function(src, d)
    local lab = L.list[tonumber(d.lab) or -1]
    if not lab then return { error = 'Laboratoire introuvable.' } end
    if not nearEntrance(src, lab) then return { error = 'Rapproche-toi de l\'entrée.' } end
    local role, rights, g = L.Rights(src, lab)
    local raid = L.raidOf and L.raidOf(lab.id)
    local out = { id = lab.id, name = lab.name, owned = lab.owner ~= nil, disabled = lab.disabled,
        canEnter = rights.enter == true, member = role ~= nil, raid = raid and { status = raid.status } or nil }
    if not lab.owner then
        out.price = lab.price
        out.canBuy = g ~= nil and g.boss == true
        out.buyHint = not g and 'Il faut faire partie d\'un groupe illégal.' or not g.boss and 'Seul le chef du groupe peut l\'acheter.' or nil
    else
        out.ownerLabel = L.GroupLabel(lab.owner)
        if L.RaidCheck and g and g.id ~= lab.owner then
            local ok, why = L.RaidCheck(src, lab, g, true)
            out.canRaid, out.raidHint = ok, why
        end
    end
    return out
end

L.pub.enter = function(src, d)
    local lab = L.list[tonumber(d.lab) or -1]
    if not lab then return { error = 'Laboratoire introuvable.' } end
    if lab.disabled then return { error = 'Ce laboratoire est fermé.' } end
    if not lab.owner then return { error = 'Ce laboratoire n\'a pas de propriétaire.' } end
    if L.inside[src] then return { error = 'Tu es déjà dans un laboratoire.' } end
    if not nearEntrance(src, lab) then return { error = 'Rapproche-toi de l\'entrée.' } end
    local ped = L.Ped(src)
    if ped and GetVehiclePedIsIn(ped, false) ~= 0 then return { error = 'Descends du véhicule.' } end
    local raid = L.raidOf and L.raidOf(lab.id)
    if raid and L.Raids().lockDuringRaid then return { error = 'Le laboratoire est verrouillé pendant l\'attaque.' } end
    local _, rights = L.Rights(src, lab)
    if rights.enter then L.PutInside(src, lab, 'member') return { ok = true } end
    -- Code
    local key = src .. ':' .. lab.id
    local f = Fails[key]
    if f and f.untilT and os.time() < f.untilT then return { error = ('Trop d\'essais. Réessaie dans %d s.'):format(f.untilT - os.time()), locked = true } end
    if d.code == nil then return { needCode = true } end
    local code = tostring(d.code)
    if lab.codeHash and L.ValidCode(code) and L.HashCode(lab.codeSalt, code) == lab.codeHash then
        Fails[key] = nil
        L.PutInside(src, lab, 'code')
        return { ok = true }
    end
    f = f or { n = 0 }
    f.n, f.untilT = f.n + 1, nil
    if f.n >= Config.Code.maxFails then f.n, f.untilT = 0, os.time() + Config.Code.lockSeconds end
    Fails[key] = f
    L.Log(lab.id, 'code', L.Name(src), 'code incorrect')
    if Config.Code.notifyOwnersOnFail then L.NotifyGroup(lab.owner, ('🔒 Quelqu\'un a essayé un mauvais code à « %s ».'):format(lab.name), 'error', true) end
    return { error = f.untilT and ('Code incorrect. Bloqué %d s.'):format(Config.Code.lockSeconds) or 'Code incorrect.', needCode = true }
end

L.pub.exit = function(src)
    local i = L.inside[src]
    if not i then return { error = 'Tu n\'es pas dans un laboratoire.' } end
    local lab = L.list[i.lab]
    local it = lab and L.Interior(lab.interior)
    if it and L.Dist(src, it.spawn) > Config.InteractDistance + 2.0 and i.via ~= 'admin' then return { error = 'Va jusqu\'à la sortie.' } end
    L.PutOutside(src)
    return { ok = true }
end

-- Déconnexion : on oublie la présence (la position de reconnexion est corrigée au chargement)
function L.OnDrop(src)
    L.inside[src] = nil
    for k in pairs(Fails) do if k:match('^' .. src .. ':') then Fails[k] = nil end end
    if L.CancelCraftOf then L.CancelCraftOf(src) end
end

-- Reconnexion d'un joueur déconnecté dans un laboratoire : remis devant l'entrée
AddEventHandler('elyzea:server:playerLoaded', function(src)
    src = tonumber(src)
    if not src then return end
    SetTimeout(3500, function()
        local cid = L.Cid(src)
        if not cid or L.inside[src] then return end
        local id = tonumber(GetResourceKvpString(kvpKey(cid)) or '')
        if not id then return end
        DeleteResourceKvp(kvpKey(cid))
        local lab = L.list[id]
        if not lab then return end
        local it = L.Interior(lab.interior)
        if it and L.Dist(src, it.bounds) < (it.bounds.r or 40) + 30 then
            SetPlayerRoutingBucket(src, 0)
            TriggerClientEvent('elyzea_labs:exit', src, { x = lab.x, y = lab.y, z = lab.z, h = lab.h }, 'Tu as été replacé devant le laboratoire.')
        end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src, i in pairs(L.inside) do
        local lab = L.list[i.lab]
        SetPlayerRoutingBucket(src, 0)
        if lab then TriggerClientEvent('elyzea_labs:exit', src, { x = lab.x, y = lab.y, z = lab.z, h = lab.h }, 'Laboratoires redémarrés.') end
    end
end)
