-- =====================================================================
--  BANK HEIST - serveur : indics
--  Contre un billet (prix réglé par le staff), l'indic donne la position d'un marchand de matériel :
--  point GPS + repère temporaire sur la carte. Un délai par personnage évite de le spammer.
-- =====================================================================
local P = BHS
local talked = {}   -- [cid .. ':' .. indic] = os.time() de fin de délai

local function usable(src, n)
    if not P.S.general.enabled then return 'Il n\'a rien à te dire.' end
    if not n or not n.enabled then return 'Il n\'a rien à te dire.' end
    if not P.Near(src, n.ped, n.interactDistance + 1.0) then return 'Vous êtes trop loin.' end
    if not P.HoursOk(n.hours) then return 'Il n\'est pas d\'humeur à parler maintenant.' end
    if n.forbidPolice and Adapters.Police.IsOnDuty(src) then return 'Il te regarde de travers : « J\'parle pas aux flics. »' end
end

local function key(src, n) return ('%s:%s'):format(Adapters.Perms.CitizenId(src) or src, n.id) end

-- Marchand indiqué : celui réglé, sinon le plus proche de l'indic
local function target(n)
    if n.merchant ~= '' then
        local m = P.MerchantById(n.merchant)
        if m and m.enabled then return m end
    end
    local best, bd
    for _, m in ipairs(P.S.merchants) do
        if m.enabled then
            local d = #(vector3(m.ped.x, m.ped.y, m.ped.z) - vector3(n.ped.x, n.ped.y, n.ped.z))
            if not bd or d < bd then best, bd = m, d end
        end
    end
    return best
end

P.Req.infoTalk = function(src, d)
    local n = P.InformantById(tostring(d.id or ''))
    local why = usable(src, n)
    if why then return { error = why } end
    local cd = talked[key(src, n)]
    return { ok = true, id = n.id, name = n.name, price = n.price, payment = Adapters.Money.Labels[n.payment], greeting = n.greeting,
        waitMin = cd and cd > os.time() and math.ceil((cd - os.time()) / 60) or nil, hasMerchant = target(n) ~= nil }
end

P.Req.infoPay = function(src, d)
    local n = P.InformantById(tostring(d.id or ''))
    local why = usable(src, n)
    if why then return { error = why } end
    local k = key(src, n)
    if (talked[k] or 0) > os.time() then return { error = ('« Je t\'ai déjà tout dit. Reviens dans %d min. »'):format(math.ceil((talked[k] - os.time()) / 60)) } end
    local m = target(n)
    if not m then return { error = '« Y\'a plus personne qui vend, en ce moment. »' } end
    if not P.Lock('tx:' .. src) then return { error = 'Patientez un instant.' } end
    local paid = n.price <= 0 or Adapters.Money.Remove(src, n.payment, n.price, 'Indic ' .. n.name)
    P.Unlock('tx:' .. src)
    if not paid then return { error = '« Reviens quand t\'auras de quoi payer. »' } end
    talked[k] = os.time() + n.cooldown * 60
    P.Log('shop', n.id, src, ('Indic payé %s : position du marchand « %s »'):format(BH.Money(n.price), m.name))
    return { ok = true, answer = n.answer, merchant = { name = m.name, x = m.ped.x, y = m.ped.y, z = m.ped.z }, minutes = n.blipMinutes }
end
