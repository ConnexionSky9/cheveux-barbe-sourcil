-- =====================================================================
--  rp_animations : événements réseau (serveur)
--  Tout ce qui vient d'un client est vérifié : types, limites d'appels, droits.
-- =====================================================================
local Sec, S, I = RPA.Sec, RPA.Sessions, RPA.Invites
local notify = RPA.Notify

-- ── Réglages en jeu du staff : offsets calibrés et animations validées ────
-- Sauvegardés dans le stockage de la ressource (KVP), sans toucher au catalogue.
local Tuning = json.decode(GetResourceKvpString('tuning') or 'null') or {}
Tuning.offsets = Tuning.offsets or {}
Tuning.validated = Tuning.validated or {}
Catalog.Validated = Tuning.validated

local function saveTuning()
    SetResourceKvp('tuning', json.encode(Tuning))
    TriggerClientEvent('rp_animations:cl:tuning', -1, Tuning)
end

-- Offsets à appliquer pour une animation : { [étape] = offset } (vide = valeurs du catalogue)
function RPA.Offsets(animId) return Tuning.offsets[animId] or {} end

-- ── Événements ─────────────────────────────────────────────────────────────
RegisterNetEvent('rp_animations:sv:hello', function()
    local src = source
    if not Sec.Allow(src, 'hello', 3, 10000) then return end
    TriggerClientEvent('rp_animations:cl:tuning', src, Tuning)
end)

RegisterNetEvent('rp_animations:sv:prefs', function(prefs)
    local src = source
    if not Sec.Allow(src, 'prefs', 10, 10000) or type(prefs) ~= 'table' then return end
    I.prefs[src] = { adult = prefs.adult == true and Config.Adult.Enabled, dnd = prefs.dnd == true }
    -- Désactiver le contenu adulte met fin tout de suite à une session adulte en cours
    local s = S.Of(src)
    if s and s.entry.adult and not I.prefs[src].adult then S.End(s.id, 'stop', src) end
end)

RegisterNetEvent('rp_animations:sv:invite', function(target, animId, role)
    I.Send(source, target, animId, role)
end)

RegisterNetEvent('rp_animations:sv:cancelInvite', function()
    local src = source
    if not Sec.Allow(src, 'cancel', 10, 10000) then return end
    I.Cancel(src)
end)

RegisterNetEvent('rp_animations:sv:respond', function(id, accept, confirmAdult)
    I.Respond(source, id, accept == true, confirmAdult == true)
end)

RegisterNetEvent('rp_animations:sv:ready', function(sid, ok, reason)
    local src = source
    if not Sec.Allow(src, 'ready', 10, 10000) then return end
    S.Ready(src, tonumber(sid), ok == true, type(reason) == 'string' and reason or nil)
end)

-- L'arrêt n'est jamais limité au point d'être refusé : on garde juste une limite large anti-spam
RegisterNetEvent('rp_animations:sv:stop', function(reason)
    local src = source
    if not Sec.Allow(src, 'stop', 30, 10000) then return end
    S.Stop(src, reason)
end)

-- Calibrage : enregistre l'offset d'une étape (staff uniquement)
RegisterNetEvent('rp_animations:sv:saveOffset', function(animId, step, off)
    local src = source
    if not Sec.Allow(src, 'calib', 20, 10000) then return end
    if not Sec.IsAdmin(src) then
        print(('[rp_animations] %s (%d) : calibrage refusé (permission %s manquante)'):format(GetPlayerName(src) or '?', src, Config.AdminAce))
        return
    end
    local entry = Catalog.Get(animId)
    step = tonumber(step)
    off = Sec.CleanOffset(off)
    if not entry or entry.type ~= 'duo' or not step or not entry.steps[step] or not off then return end
    Tuning.offsets[entry.id] = Tuning.offsets[entry.id] or {}
    Tuning.offsets[entry.id][tostring(step)] = off
    saveTuning()
    notify(src, ('Position enregistrée : %s, étape %d'):format(entry.label, step), 'ok')
    print(('[rp_animations] offset %s étape %d = { x = %.3f, y = %.3f, z = %.3f, h = %.1f } (par %s)'):format(
        entry.id, step, off.x, off.y, off.z, off.h, GetPlayerName(src) or src))
end)

-- /rpanim_valider <id> [non] : marque une animation comme validée après test en jeu
RegisterCommand('rpanim_valider', function(src, args)
    if src ~= 0 and not Sec.IsAdmin(src) then return end
    local entry = Catalog.Get(args[1])
    local reply = function(t) if src == 0 then print(t) else notify(src, t, 'info') end end
    if not entry then return reply('Usage : /rpanim_valider <id> [non]') end
    if args[2] == 'non' then Tuning.validated[entry.id] = nil else Tuning.validated[entry.id] = true end
    saveTuning()
    reply(('%s : %s'):format(entry.label, Tuning.validated[entry.id] and 'validée' or 'à valider'))
end, false)

-- /rpanim_reset <id> : revient aux offsets du catalogue
RegisterCommand('rpanim_reset', function(src, args)
    if src ~= 0 and not Sec.IsAdmin(src) then return end
    local entry = Catalog.Get(args[1])
    if not entry then return end
    Tuning.offsets[entry.id] = nil
    saveTuning()
    if src ~= 0 then notify(src, 'Positions remises par défaut : ' .. entry.label, 'ok') else print('ok') end
end, false)

AddEventHandler('playerDropped', function()
    local src = source
    I.Dropped(src)
    S.Dropped(src)
    Sec.Forget(src)
end)

-- Arrêt de la ressource : chaque client se nettoie lui-même (onResourceStop côté client)
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for sid in pairs(S.list) do S.End(sid, 'redemarrage') end
end)

-- Vérification du catalogue au démarrage (identifiants uniques, fiches complètes)
CreateThread(function()
    local seen, problems, playable = {}, 0, 0
    for _, e in ipairs(Catalog.List) do
        if seen[e.id] then print('[rp_animations] identifiant en double : ' .. e.id) problems = problems + 1 end
        seen[e.id] = true
        if Catalog.IsPlayable(e) then
            playable = playable + 1
            for i, st in ipairs(e.steps) do
                if not st.A or (e.type == 'duo' and (not st.B or not st.off)) then
                    print(('[rp_animations] fiche incomplète : %s étape %d'):format(e.id, i)) problems = problems + 1
                end
            end
        end
    end
    print(('[rp_animations] %d animations au catalogue, %d jouables, %d problème(s)'):format(#Catalog.List, playable, problems))
    if GetConvar('onesync', 'off') == 'off' then
        print('[rp_animations] ATTENTION : OneSync semble désactivé, les animations en duo seront refusées')
    end
end)
