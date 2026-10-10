-- ─────────────────────────────────────────────────────────────
-- Taille du personnage : petit (nain) ou grand, visible par tous
-- Réglée par le staff (/taille), partagée par le serveur (state bag « elyHeight ») ;
-- chaque joueur redimensionne les personnages autour de lui.
-- GTA n'a pas de réglage de taille : on agrandit / rétrécit le modèle à chaque image.
-- La taille reste appliquée tout le temps : à pied, en véhicule, porté, à terre, mort…
-- Les collisions (portes, tirs) restent celles d'un personnage normal.
-- ─────────────────────────────────────────────────────────────
local H = Config.Height
if not H or not H.enabled then return end

local FEMALE = `mp_f_freemode_01`

-- Taille en cm -> échelle (1.0 = taille de référence du modèle homme / femme)
local function scaleOf(ped, cm)
    cm = tonumber(cm)
    if not cm then return 1.0 end
    local base = GetEntityModel(ped) == FEMALE and H.baseFemale or H.baseMale
    return math.max(H.minScale, math.min(H.maxScale, cm / base))
end

local function unit(x, y, z)
    local l = math.sqrt(x * x + y * y + z * z)
    if l < 0.0001 then return 0.0, 0.0, 0.0 end
    return x / l, y / l, z / l
end

local placed = {}   -- [ped] = { z écrit, z d'origine } : évite de décaler deux fois un personnage immobile (figé)

local function apply(ped, s, onFoot)
    local f, r, u, p = GetEntityMatrix(ped)
    local fx, fy, fz = unit(f.x, f.y, f.z)
    local rx, ry, rz = unit(r.x, r.y, r.z)
    local ux, uy, uz = unit(u.x, u.y, u.z)
    -- Le centre du personnage est à ~1 m du sol : on le descend / monte pour garder les pieds au sol.
    -- Si le jeu n'a pas replacé le personnage depuis l'image précédente, on repart de sa hauteur d'origine.
    -- Assis (véhicule), porté, au sol (ragdoll) : on garde la position, seule la taille change.
    local z = p.z
    if onFoot then
        local last = placed[ped]
        local base = (last and math.abs(p.z - last[1]) < 0.0005) and last[2] or p.z
        z = base + (s - 1.0) * H.groundOffset
        placed[ped] = { z, base }
    else
        placed[ped] = nil
    end
    SetEntityMatrix(ped, fx * s, fy * s, fz * s, rx * s, ry * s, rz * s, ux * s, uy * s, uz * s, p.x, p.y, z)
end

-- À pied : on recale les pieds au sol. Sinon (véhicule, porté, ragdoll) : taille seulement.
local function onFoot(ped)
    return not IsPedInAnyVehicle(ped, true) and not IsPedRagdoll(ped) and not IsEntityAttached(ped)
end

CreateThread(function()
    while true do
        local list = {}
        for _, id in ipairs(GetActivePlayers()) do
            local cm = Player(GetPlayerServerId(id)).state.elyHeight
            if cm then
                local ped = GetPlayerPed(id)
                local s = scaleOf(ped, cm)
                if math.abs(s - 1.0) > 0.01 then list[#list + 1] = { ped, s } end
            end
        end
        for ped in pairs(placed) do if not DoesEntityExist(ped) then placed[ped] = nil end end
        if #list == 0 then
            Wait(500)
        else
            -- environ 1 seconde de redimensionnement, puis on refait la liste des joueurs
            for _ = 1, 60 do
                for i = 1, #list do
                    local ped, s = list[i][1], list[i][2]
                    if DoesEntityExist(ped) then apply(ped, s, onFoot(ped)) end
                end
                Wait(0)
            end
        end
    end
end)
