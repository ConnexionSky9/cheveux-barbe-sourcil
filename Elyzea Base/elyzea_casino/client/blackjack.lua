-- =========================================================
--  ELYZEA CASINO - blackjack côté client : cartes 3D sur la table, gestes du croupier
--  Tout est dessiné à partir de l'état envoyé par le serveur : une carte qui apparaît dans
--  l'état est distribuée (elle glisse du sabot à sa place), la carte cachée est retournée
--  quand le serveur la dévoile. Rien ici ne décide d'un résultat.
-- =========================================================
local A = Config.Anims
local cards = {}     -- [tableId] = { round, ents = { [clé] = { ent, hidden } } }

local function vec(t) return vector3(t.x, t.y, t.z) end
local function flat(v) return vector3(v.x, v.y, 0.0) end
local function norm(v) local l = #v return l > 0.0001 and v / l or vector3(0.0, 1.0, 0.0) end

function CS.ClearCards(id)
    local c = cards[id]
    if not c then return end
    for _, e in pairs(c.ents) do if DoesEntityExist(e.ent) then DeleteEntity(e.ent) end end
    cards[id] = nil
end

-- Geste d'un joueur assis (bras seulement) ; s'il s'est relevé à cause du geste, il se rassoit
function CS.Gesture(spec)
    local ped = PlayerPedId()
    if not CS.seated then return end
    CS.PlayAnim(ped, spec, 48, 1600)
    local s = CS.seated
    SetTimeout(1800, function()
        if CS.seated == s and s.sit and not IsPedUsingScenario(ped, A.sitScenario) then
            TaskStartScenarioAtPosition(ped, A.sitScenario, s.sit.x, s.sit.y, s.sit.z, s.sit.h, 0, true, true)
        end
    end)
end

-- Repères de la table : centre du tapis, côté croupier, places
local function frame(id)
    local p, e = CS.points[id], CS.ents[id]
    if not p or not p.table or not e or not e.table then return nil end
    local center = vec(p.table)
    local top = center.z + Config.Table.top
    local dealer = CS.DealerPed(id)
    local dpos = dealer and GetEntityCoords(dealer) or (p.ped and vector3(p.ped.x, p.ped.y, p.ped.z))
    local seats = CS.Seats(id)
    local dirD
    if dpos then dirD = norm(flat(dpos - center)) else
        local m = vector3(0.0, 0.0, 0.0)
        for _, s in ipairs(seats) do m = m + flat(s.pos - center) end
        dirD = norm(-m)
    end
    return { center = vector3(center.x, center.y, top), dirD = dirD, seats = seats, dealer = dealer }
end

local function headingOf(dir) return (math.deg(math.atan(dir.y, dir.x)) - 90.0) % 360.0 end

-- Place d'une carte : main h de la place i, carte n° j
local function slot(F, i, h, j, nHands)
    local s = F.seats[i]
    if not s then return nil end
    local out = norm(flat(s.pos - F.center))
    local tan = vector3(-out.y, out.x, 0.0)
    local base = F.center + out * 0.42
    local hOff = ((h - 1) - (nHands - 1) / 2) * 0.24
    local pos = base + tan * (hOff + (j - 1) * 0.045) + out * ((j - 1) * 0.012)
    return vector3(pos.x, pos.y, F.center.z + 0.002 * j), headingOf(-out)
end

local function dealerSlot(F, j)
    local tan = vector3(-F.dirD.y, F.dirD.x, 0.0)
    local pos = F.center + F.dirD * 0.32 + tan * ((j - 1) * 0.075 - 0.08)
    return vector3(pos.x, pos.y, F.center.z + 0.002 * j), headingOf(F.dirD)
end

local function shoePos(F)
    local tan = vector3(-F.dirD.y, F.dirD.x, 0.0)
    local p = F.center + F.dirD * 0.42 - tan * 0.45
    return vector3(p.x, p.y, F.center.z + 0.08)
end

-- Fait glisser une carte du sabot à sa place (0,45 s), face cachée si besoin
local function dealCard(F, card, target, heading, hidden)
    local model = card.hidden and 'vw_prop_cas_card_spd_ace' or Config.CardModel(card)
    local hash = CS.LoadModel(model)
    if not hash then return nil end
    local from = shoePos(F)
    local ent = CreateObjectNoOffset(hash, from.x, from.y, from.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityCollision(ent, false, false)
    FreezeEntityPosition(ent, true)
    local rx = hidden and 180.0 or 0.0
    SetEntityRotation(ent, rx, 0.0, heading, 2, true)
    CreateThread(function()
        local t0, dur = GetGameTimer(), 450
        while DoesEntityExist(ent) do
            local k = math.min(1.0, (GetGameTimer() - t0) / dur)
            local e = 1 - (1 - k) * (1 - k)
            local p = from + (target - from) * e
            SetEntityCoordsNoOffset(ent, p.x, p.y, p.z + math.sin(k * math.pi) * 0.05, false, false, false)
            if k >= 1.0 then break end
            Wait(0)
        end
    end)
    return ent
end

-- Retourne la carte cachée du croupier : on remplace l'objet par la vraie carte en la faisant pivoter
local function flipCard(entry, card, F, j)
    local pos, heading = dealerSlot(F, j)
    if DoesEntityExist(entry.ent) then DeleteEntity(entry.ent) end
    local hash = CS.LoadModel(Config.CardModel(card))
    if not hash then return end
    local ent = CreateObjectNoOffset(hash, pos.x, pos.y, pos.z + 0.03, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityCollision(ent, false, false)
    FreezeEntityPosition(ent, true)
    entry.ent, entry.hidden = ent, false
    CreateThread(function()
        local t0 = GetGameTimer()
        while DoesEntityExist(ent) do
            local k = math.min(1.0, (GetGameTimer() - t0) / 350)
            SetEntityRotation(ent, 180.0 * (1 - k), 0.0, heading, 2, true)
            if k >= 1.0 then SetEntityCoordsNoOffset(ent, pos.x, pos.y, pos.z, false, false, false) break end
            Wait(0)
        end
    end)
end

local lastAnim = 0
local function dealerGesture(F, spec)
    if not F.dealer or GetGameTimer() - lastAnim < 600 then return end
    lastAnim = GetGameTimer()
    CS.PlayAnim(F.dealer, spec, 0, -1, A.fallbackHand)
end

function CS.BJState(id, st)
    if not CS.ents[id] then return end
    local F = frame(id)
    if not F then return end
    local c = cards[id]
    if st.phase == 'betting' or st.phase == 'idle' or not c or c.round ~= st.round then
        CS.ClearCards(id)
        if st.phase == 'betting' or st.phase == 'idle' then return end
        c = { round = st.round, ents = {} }
        cards[id] = c
    end
    local keep = {}
    -- Joueurs
    for si, seat in pairs(st.seats or {}) do
        local i = tonumber(si)
        local hands = seat.hands or {}
        for h, hand in ipairs(hands) do
            for j, card in ipairs(hand.cards or {}) do
                local k = ('p%d:%d:%d:%s%s'):format(i, h, j, card.r, card.s)
                keep[k] = true
                if not c.ents[k] then
                    local pos, heading = slot(F, i, h, j, #hands)
                    if pos then
                        dealerGesture(F, A.dealerDeal)
                        c.ents[k] = { ent = dealCard(F, card, pos, heading, false) }
                        PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                    end
                end
            end
        end
    end
    -- Croupier
    for j, card in ipairs((st.dealer or {}).cards or {}) do
        local k = ('d%d'):format(j)
        keep[k] = true
        local entry = c.ents[k]
        if not entry then
            local pos, heading = dealerSlot(F, j)
            dealerGesture(F, A.dealerDealSelf)
            c.ents[k] = { ent = dealCard(F, card, pos, heading, card.hidden == true), hidden = card.hidden == true }
        elseif entry.hidden and not card.hidden then
            dealerGesture(F, A.dealerReveal)
            flipCard(entry, card, F, j)
        end
    end
    -- Cartes qui ne sont plus dans l'état (séparation : une main a changé) : retirées
    for k, e in pairs(c.ents) do
        if not keep[k] then if DoesEntityExist(e.ent) then DeleteEntity(e.ent) end c.ents[k] = nil end
    end
end

-- ---------------------------------------------------------------- actions (interface)
RegisterNUICallback('bjAction', function(d, cb)
    if not CS.seated or CS.seated.game ~= 'blackjack' then return cb({ ok = false, msg = 'Tu n\'es pas assis.' }) end
    d.pedId = CS.seated.id
    local ok, msg = Ely.callback.await('elyzea_casino:bj:action', false, d)
    cb({ ok = ok == true, msg = msg })
    if ok then
        if d.action == 'hit' or d.action == 'double' or d.action == 'split' then CS.Gesture(A.playerHit)
        elseif d.action == 'stand' then CS.Gesture(A.playerStand)
        elseif d.action == 'bet' then CS.Gesture(A.playerBet) PlaySoundFrontend(-1, 'CHIPS', 'DLC_VW_TABLE_GAMES_SOUNDS', true) end
    end
end)
