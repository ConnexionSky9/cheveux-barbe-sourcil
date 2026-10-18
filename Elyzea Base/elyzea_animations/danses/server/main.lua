-- =====================================================================
--  Danses : événements réseau (serveur)
--  Tout ce qui vient d'un client est vérifié : types, limites d'appels, droits.
-- =====================================================================
local Sec, S, I, L = Danse.Sec, Danse.Sessions, Danse.Invites, Danse.Lobbies
local notify = Danse.Notify

-- ── Réglages du staff en jeu : positions calibrées et danses validées (stockage de la ressource) ──
local Tuning = json.decode(GetResourceKvpString('danse_tuning') or 'null') or {}
Tuning.offsets = Tuning.offsets or {}
Tuning.validated = Tuning.validated or {}
DanseCatalog.Validated = Tuning.validated

local function saveTuning()
    SetResourceKvp('danse_tuning', json.encode(Tuning))
    TriggerClientEvent('elyzea_danse:cl:tuning', -1, Tuning)
end

-- Positions à appliquer pour une danse : { ['étape'] = offset } (vide = valeurs du catalogue)
function Danse.Offsets(animId) return Tuning.offsets[animId] or {} end

-- ── Événements ─────────────────────────────────────────────────────────────
RegisterNetEvent('elyzea_danse:sv:hello', function()
    local src = source
    if not Sec.Allow(src, 'hello', 3, 10000) then return end
    TriggerClientEvent('elyzea_danse:cl:tuning', src, Tuning)
end)

RegisterNetEvent('elyzea_danse:sv:invite', function(target, animId, role)
    I.SendDuo(source, target, animId, role == 'B' and 'B' or 'A')
end)

RegisterNetEvent('elyzea_danse:sv:group', function(animId, formation, targets)
    L.Create(source, animId, type(formation) == 'string' and formation or nil, targets)
end)

RegisterNetEvent('elyzea_danse:sv:groupStart', function()
    local src = source
    if not Sec.Allow(src, 'groupStart', 5, 10000) then return end
    L.StartNow(src)
end)

RegisterNetEvent('elyzea_danse:sv:respond', function(id, accept)
    I.Respond(source, id, accept == true)
end)

RegisterNetEvent('elyzea_danse:sv:ready', function(sid, ok, reason)
    local src = source
    if not Sec.Allow(src, 'ready', 10, 10000) then return end
    S.Ready(src, tonumber(sid), ok == true, type(reason) == 'string' and reason or nil)
end)

-- Arrêter / quitter : jamais refusé (limite large anti-spam seulement). Quitte aussi un groupe en attente.
RegisterNetEvent('elyzea_danse:sv:stop', function(reason)
    local src = source
    if not Sec.Allow(src, 'stop', 30, 10000) then return end
    if not L.Leave(src, 'stop') then S.Stop(src, reason) end
end)

-- Calibrage : enregistre la position d'une étape (staff uniquement)
RegisterNetEvent('elyzea_danse:sv:saveOffset', function(animId, step, off)
    local src = source
    if not Sec.Allow(src, 'calib', 20, 10000) then return end
    if not Sec.IsAdmin(src) then
        print(('[Elyzea danses] %s (%d) : calibrage refusé (permission %s manquante)'):format(GetPlayerName(src) or '?', src, DanseConfig.AdminAce))
        return
    end
    local entry = DanseCatalog.Get(animId)
    step = tonumber(step)
    local st = entry and step and entry.steps[step]
    off = st and Sec.CleanOffset(off, st.off and st.off.bone)
    if not entry or entry.type ~= 'duo' or not off then return end
    Tuning.offsets[entry.id] = Tuning.offsets[entry.id] or {}
    Tuning.offsets[entry.id][tostring(step)] = off
    saveTuning()
    notify(src, ('Position enregistrée : %s, étape %d'):format(entry.label, step), 'ok')
    print(('[Elyzea danses] position %s étape %d = { x = %.3f, y = %.3f, z = %.3f, h = %.1f } (par %s)'):format(
        entry.id, step, off.x, off.y, off.z, off.h, GetPlayerName(src) or src))
end)

local function reply(src, text) if src == 0 then print(text) else notify(src, text, 'info') end end

-- /danse_valider <id> [non] : marque une danse comme validée après un essai en jeu
RegisterCommand('danse_valider', function(src, args)
    if src ~= 0 and not Sec.IsAdmin(src) then return end
    local entry = DanseCatalog.Get(args[1])
    if not entry then return reply(src, 'Usage : /danse_valider <id> [non]') end
    Tuning.validated[entry.id] = (args[2] ~= 'non') or nil
    saveTuning()
    reply(src, ('%s : %s'):format(entry.label, Tuning.validated[entry.id] and 'validée' or 'à valider'))
end, false)

-- /danse_reset <id> : revient aux positions du catalogue
RegisterCommand('danse_reset', function(src, args)
    if src ~= 0 and not Sec.IsAdmin(src) then return end
    local entry = DanseCatalog.Get(args[1])
    if not entry then return reply(src, 'Usage : /danse_reset <id>') end
    Tuning.offsets[entry.id] = nil
    saveTuning()
    reply(src, 'Positions remises par défaut : ' .. entry.label)
end, false)

AddEventHandler('playerDropped', function()
    local src = source
    I.Dropped(src)
    S.Dropped(src)
    Sec.Forget(src)
end)

-- Arrêt de la ressource : chaque client se nettoie aussi lui-même (onResourceStop côté client)
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for sid in pairs(S.list) do S.End(sid, 'redemarrage') end
end)

-- Vérification du catalogue au démarrage
CreateThread(function()
    local seen, problems = {}, 0
    for _, e in ipairs(DanseCatalog.List) do
        if seen[e.id] then print('[Elyzea danses] identifiant en double : ' .. e.id) problems = problems + 1 end
        seen[e.id] = true
        for i, st in ipairs(e.steps) do
            if not st.A or (e.type == 'duo' and (not st.B or not st.off)) then
                print(('[Elyzea danses] fiche incomplète : %s étape %d'):format(e.id, i)) problems = problems + 1
            end
        end
    end
    print(('[Elyzea danses] %d danses à plusieurs au catalogue, %d problème(s)'):format(#DanseCatalog.List, problems))
    if GetConvar('onesync', 'off') == 'off' then
        print('[Elyzea danses] ATTENTION : OneSync semble désactivé, les danses à plusieurs seront refusées')
    end
end)
