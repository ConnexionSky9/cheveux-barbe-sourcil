-- Simulation hors jeu du moteur d'affichage (client/runtime.lua + shared/ RÉELS, natives imitées) :
-- limite d'objets (cause des plantages), ordre de chargement, réutilisation des objets.
local ROOT = ...
local fails = 0
local function check(ok, label) if ok then print('  ok   ' .. label) else fails = fails + 1 print('  ÉCHEC ' .. label) end end
local T = 0
local threads = {}
local ents, nextEnt, created, deleted = {}, 1000, 0, 0
local worldBase = 0      -- objets du jeu lui-même (hors studio)
local cam = { x = 0, y = 0, z = 75 }
local env = setmetatable({}, { __index = _G })
env.CreateThread = function(fn) threads[#threads + 1] = { co = coroutine.create(fn), at = T } end
env.Wait = function(ms) coroutine.yield(ms or 0) end
local function run(ms)
    local stop = T + ms
    while T <= stop do
        for _, t in ipairs(threads) do
            if coroutine.status(t.co) ~= 'dead' and t.at <= T then
                local ok, w = coroutine.resume(t.co)
                if not ok then print('  [erreur] ' .. tostring(w)) fails = fails + 1 end
                t.at = T + math.max(1, w or 0)
            end
        end
        T = T + 16
    end
end
env.GetGameTimer = function() return T end
env.GetHashKey = function(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) & 0x7fffffff end return h end
local DIMS = { [env.GetHashKey('stt_prop_stunt_bblock_sml1')] = 1, [env.GetHashKey('stt_prop_stunt_bblock_sml2')] = 1, [env.GetHashKey('stt_prop_stunt_bblock_sml3')] = 1,
    [env.GetHashKey('stt_prop_stunt_bblock_mdm1')] = 2, [env.GetHashKey('prop_com_ls_door_01')] = 1 }
env.IsModelInCdimage = function(h) return DIMS[h] ~= nil end
env.IsModelValid = env.IsModelInCdimage
env.HasModelLoaded = function() return true end
env.RequestModel = function() end
env.SetModelAsNoLongerNeeded = function() end
env.GetModelDimensions = function(h) local s = DIMS[h] or 1 return { x = -s / 2, y = -s / 2, z = 0 }, { x = s / 2, y = s / 2, z = s } end
env.CreateObjectNoOffset = function(h, x, y, z) nextEnt = nextEnt + 1 ents[nextEnt] = { model = h, x = x, y = y, z = z } created = created + 1 return nextEnt end
env.DoesEntityExist = function(e) return ents[e] ~= nil end
env.DeleteObject = function(e) if ents[e] then ents[e] = nil deleted = deleted + 1 end end
env.SetEntityAsMissionEntity = function() end
env.IsEntityAVehicle = function() return false end
env.SetEntityMatrix = function(e, ax, ay, az, bx, by, bz, cx, cy, cz, x, y, z) if ents[e] then ents[e].x, ents[e].y, ents[e].z = x, y, z end end
for _, n in ipairs({ 'FreezeEntityPosition', 'SetObjectTextureVariation', 'SetEntityAlpha', 'ResetEntityAlpha', 'SetEntityLodDist', 'AddEventHandler', 'RegisterNetEvent',
    'TriggerServerEvent', 'DrawLightWithRange', 'DrawSpotLight', 'DrawLightWithRangeAndShadow', 'DrawSpotLightWithShadow', 'RemoveReplaceTexture', 'AddReplaceTexture' }) do env[n] = function() end end
env.GetFinalRenderedCamCoord = function() return cam end
env.PlayerPedId = function() return 1 end
env.GetEntityCoords = function() return cam end
env.IsControlJustPressed = function() return false end
env.GetGamePool = function(kind) local t = {} local n = worldBase for _ in pairs(ents) do n = n + 1 end for i = 1, n do t[i] = i end return t end
env.GetCurrentResourceName = function() return 'builder_studio' end
env.json = { encode = function() return '{}' end }
local function loadFile(path)
    local f = assert(io.open(ROOT .. '/' .. path, 'r')) local s = f:read('a') f:close()
    assert(load(s, '@' .. path, 't', env))()
end
for _, f in ipairs({ 'config.lua', 'shared/mathx.lua', 'shared/kits.lua', 'shared/geometry.lua', 'shared/catalog.lua', 'shared/compose.lua', 'client/runtime.lua' }) do loadFile(f) end
local R, BGeo = env.BRuntime, env.BGeo
for k, v in pairs({ MaxEntities = env.Config.Stream.maxEntities, MaxWorldObjects = env.Config.Stream.maxWorldObjects, SpawnPerFrame = env.Config.Stream.spawnPerFrame }) do R.cfg[k] = v end
R.matrixOrder = 'xyz'
for h, s in pairs(DIMS) do end
-- dimensions mesurées comme en jeu
for _, m in ipairs(env.BKits.allModels('blocs')) do local s = DIMS[env.GetHashKey(m)] if s then R.dims[m] = { min = { x = -s / 2, y = -s / 2, z = 0 }, max = { x = s / 2, y = s / 2, z = s } } end end
local function count() local n = 0 for _ in pairs(ents) do n = n + 1 end return n end
local function terrain(id, kind, n, amp, x)
    return { id = id, type = 'terrain', name = id, kit = 'blocs', mat = 't0', pos = { x = x or 0, y = 0, z = 70 }, rot = { x = 0, y = 0, z = 0 },
        params = { cols = n, rows = n, cell = 4, base = 0, heights = BGeo.terrainPreset(kind, n, n, { amplitude = amp, seed = 7 }) } }
end

print('\n[Limite d\'objets : plus jamais de réserve GTA pleine]')
worldBase = 1200   -- une zone de la carte déjà chargée d'objets
local p = { id = 'p1', elements = {} }
for i = 1, 6 do local e = terrain('t' .. i, 'ile', 12, 10, (i - 1) * 60) p.elements[e.id] = e end
R.setProject(p)
run(20000)
local total = count()
check(worldBase + total <= R.cfg.MaxWorldObjects, ('6 îles (≈ 6 000 objets) : %d créés, monde %d / %d (jamais dépassé)'):format(total, worldBase + total, R.cfg.MaxWorldObjects))
check(R.isCapped(), 'limite atteinte signalée (barre d\'état du studio)')
local mine, others = 0, 0
for eid, st in pairs(R.projects.p1.els) do for _ in pairs(st.ents) do if eid == 't1' then mine = mine + 1 else others = others + 1 end end end
check(mine == total and others == 0, ('les places libres vont à l\'île la plus proche de la caméra (%d objets), pas aux plus lointaines (%d)'):format(mine, others))
worldBase = 0
run(20000)
check(count() <= R.cfg.MaxEntities, ('place libérée : le studio reprend, sans dépasser ses %d objets (%d)'):format(R.cfg.MaxEntities, count()))

print('\n[Modification fluide : objets réutilisés]')
for k in pairs(R.projects.p1.els) do R.despawn('p1', k) end
R.removeProject('p1')
local p2 = { id = 'p2', elements = {} }
local t = terrain('ter', 'ile', 12, 10, 0)
p2.elements.ter = t
R.setProject(p2)
run(10000)
local st = R.projects.p2.els.ter
check(st and st.done, ('terrain affiché (%d objets)'):format(count()))
local before, c0, d0 = count(), created, deleted
local t2 = env.BCompose and env.BCompose.deepcopy(t) or t
t2 = { id = t.id, type = t.type, name = t.name, kit = t.kit, mat = t.mat, pos = t.pos, rot = t.rot, params = { cols = 12, rows = 12, cell = 4, base = 0, heights = {} } }
for i, h in ipairs(t.params.heights) do t2.params.heights[i] = h end
for i = 60, 66 do t2.params.heights[i] = (t2.params.heights[i] or 0) + 2 end   -- coup de sculpture
R.updateElement('p2', t2)
run(3000)
local newCount = #BGeo.pieces(t2, { measured = R.measured })
check(created - c0 < before / 4 and count() == newCount, ('sculpture : %d objets créés et %d supprimés au lieu de tout refaire (%d)'):format(created - c0, deleted - d0, before))
check(R.projects.p2.els.ter.done, 'terrain à jour, complet')
local moved = { id = t.id, type = t.type, name = t.name, kit = t.kit, mat = t.mat, pos = { x = 10, y = 0, z = 70 }, rot = t.rot, params = t2.params }
local c1 = created
R.updateElement('p2', moved)
run(500)
check(created == c1, 'déplacement : aucun objet recréé')
return fails
