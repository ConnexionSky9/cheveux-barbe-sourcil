-- =====================================================================
--  BARRE DE POLE DANCE - serveur
--  Une seule danseuse par barre. Le serveur vérifie : barre existante, joueur chargé, proche, debout,
--  pas dans une partie. Il arrête la danse si le joueur s'éloigne, tombe ou se déconnecte.
--  Pourboires : argent liquide du spectateur → danseuse, validé et limité ici.
-- =====================================================================
local P = { dancers = {}, byPlayer = {}, lastTip = {} }
LS.Pole = P
local C = Config.Pole

local function poleOf(id)
    local inst = LS.inst[tonumber(id) or -1]
    if inst and inst.kind == 'pole' then return inst end
end
-- distance au pied de la barre (à plat) + écart de hauteur raisonnable
local function distTo(src, inst)
    local p = LS.Pos(src)
    if not p then return math.huge end
    local d = inst.data
    if math.abs(p.z - d.z) > 4.0 then return math.huge end
    return math.sqrt((p.x - d.x) ^ 2 + (p.y - d.y) ^ 2)
end
P.DistTo = distTo

local function push(id)
    local d = P.dancers[id]
    TriggerClientEvent('elyzea_loisirs:client:pole', -1, id, d and { sid = d.sid, name = d.name } or nil)
end

function P.IsDancing(src) return P.byPlayer[src] ~= nil end
function P.DancerOf(id) local d = P.dancers[id] return d and { sid = d.sid, name = d.name } or nil end
function P.Release(src)
    local id = P.byPlayer[src]
    if not id then return false end
    P.byPlayer[src] = nil
    P.dancers[id] = nil
    push(id)
    return true
end
-- barre supprimée ou arrêt par le staff : la danseuse redescend
function P.OnDelete(id)
    local d = P.dancers[id]
    if not d then return end
    TriggerClientEvent('elyzea_loisirs:client:poleStop', d.sid, id)
    P.Release(d.sid)
end

function P.Claim(src, id)
    if not C.enabled then return nil, 'La pole dance est désactivée.' end
    local inst = poleOf(id)
    if not inst then return nil, 'Barre introuvable.' end
    if not LS.Online(src) then return nil, 'Personnage non chargé.' end
    if LS.Down(src) then return nil, 'Impossible dans ton état.' end
    if LS.Sessions and LS.Sessions.byPlayer[src] then return nil, 'Quitte d\'abord ta partie en cours.' end
    if distTo(src, inst) > C.maxDistance then return nil, 'Approche-toi de la barre.' end
    local cur = P.dancers[inst.id]
    if cur and cur.sid ~= src then return nil, ('%s danse déjà sur cette barre.'):format(cur.name) end
    local other = P.byPlayer[src]
    if other and other ~= inst.id then P.Release(src) end
    P.dancers[inst.id] = { sid = src, name = LS.Name(src), since = os.time() }
    P.byPlayer[src] = inst.id
    push(inst.id)
    return true
end

function P.Tip(src, id)
    local T = C.tips
    if not T or not T.enabled then return nil, 'Les pourboires sont désactivés.' end
    local inst = poleOf(id)
    if not inst then return nil, 'Barre introuvable.' end
    local d = P.dancers[inst.id]
    if not d then return nil, 'Personne ne danse ici.' end
    if d.sid == src then return nil, 'Tu ne peux pas te donner un pourboire.' end
    if not LS.Online(src) or LS.Down(src) then return nil, 'Impossible dans ton état.' end
    local now = GetGameTimer()
    if P.lastTip[src] and now - P.lastTip[src] < (T.cooldown or 3) * 1000 then return nil, 'Doucement…' end
    if distTo(src, inst) > (T.maxDistance or 5.0) then return nil, 'Approche-toi de la scène.' end
    if distTo(d.sid, inst) > C.maxDistance + 1.0 then return nil, 'La danseuse n\'est plus à la barre.' end
    local amount = math.floor(tonumber(T.amount) or 0)
    if amount <= 0 then return nil, 'Montant invalide.' end
    if not LS.Charge(src, amount, 'Pourboire pole dance') then return nil, ('Il te faut %d $ en liquide.'):format(amount) end
    P.lastTip[src] = now
    LS.Refund(d.sid, amount, 'Pourboire pole dance')
    LS.Notify(d.sid, ('💵 %s t\'a lancé %d $.'):format(LS.Name(src), amount), 'success')
    TriggerClientEvent('elyzea_loisirs:client:poleTip', -1, inst.id, src, d.sid)
    return true, amount
end

-- surveillance : la danse s'arrête si la danseuse part, tombe ou n'est plus chargée
CreateThread(function()
    while true do
        Wait(2000)
        for id, d in pairs(P.dancers) do
            local inst = poleOf(id)
            local gone = not inst or not LS.Online(d.sid)
            if not gone and (LS.Down(d.sid) or distTo(d.sid, inst) > C.maxDistance + 1.5) then
                TriggerClientEvent('elyzea_loisirs:client:poleStop', d.sid, id)
                gone = true
            end
            if gone then P.Release(d.sid) end
        end
    end
end)

AddEventHandler('playerDropped', function() local src = source P.Release(src) P.lastTip[src] = nil end)
AddEventHandler('elyzea:server:playerUnloaded', function(src) P.Release(src) end)

local function wrap(fn) return function(src, ...) local ok, a, b = pcall(fn, src, ...) if not ok then print('^1[elyzea_loisirs] ' .. tostring(a) .. '^0') return { error = 'Erreur serveur.' } end return a, b end end
Ely.callback.register('loisirs:pole_claim', wrap(function(src, id)
    if not LS.Rate(src, 'pole', 6, 5000) then return { error = 'Trop rapide.' } end
    local ok, err = P.Claim(src, id)
    return ok and { ok = true } or { error = err }
end))
Ely.callback.register('loisirs:pole_release', wrap(function(src)
    P.Release(src)
    return { ok = true }
end))
Ely.callback.register('loisirs:pole_tip', wrap(function(src, id)
    if not LS.Rate(src, 'tip', 4, 5000) then return { error = 'Trop rapide.' } end
    local ok, res = P.Tip(src, id)
    return ok and { ok = true, amount = res } or { error = res }
end))
Ely.callback.register('loisirs:pole_state', wrap(function()
    local out = {}
    for id, d in pairs(P.dancers) do out[tostring(id)] = { sid = d.sid, name = d.name } end
    return out
end))
