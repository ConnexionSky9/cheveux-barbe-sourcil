-- Simulation hors jeu du moteur de textures (client/runtime.lua RÉEL, natives imitées).
-- Lancé par tests/run_admin_textures.py (après le serveur).
local ROOT = ...
local fails = 0
local function check(ok, label) if ok then print('  ok   ' .. label) else fails = fails + 1 print('  ÉCHEC ' .. label) end end
local calls = {}
local function log(...) calls[#calls + 1] = table.concat({ ... }, ' ') end
local function has(pat) for _, c in ipairs(calls) do if c:find(pat, 1, true) then return true end end return false end
local function count(pat) local n = 0 for _, c in ipairs(calls) do if c:find(pat, 1, true) then n = n + 1 end end return n end
local threads = {}
local duiN, duiReady = 0, {}
local env = setmetatable({}, { __index = _G })
env.CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
env.Wait = function() coroutine.yield() end
local function tick(n) for _ = 1, n or 5 do for i = #threads, 1, -1 do local co = threads[i] if coroutine.status(co) ~= 'dead' then local ok, e = coroutine.resume(co) if not ok then print('  [erreur] ' .. tostring(e)) end end end end end
env.GetGameTimer = function() return 0 end
env.GetCurrentResourceName = function() return 'builder_studio' end
env.GetHashKey = function(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) & 0xffffffff end return h end
env.json = { encode = function(t) return '{"src":"' .. tostring(t.src) .. '"}' end }
env.CreateDui = function(url, w, h) duiN = duiN + 1 log('CreateDui', url, w, h) return duiN end
env.IsDuiAvailable = function(d) return duiReady[d] == true end
env.SendDuiMessage = function(d, m) log('SendDuiMessage', d, m) end
env.GetDuiHandle = function(d) return 'H' .. d end
env.DestroyDui = function(d) log('DestroyDui', d) end
env.CreateRuntimeTxd = function(n) log('CreateRuntimeTxd', n) return 'TXD:' .. n end
env.CreateRuntimeTextureFromDuiHandle = function(txd, n, h) log('FromDui', txd, n, h) end
env.CreateRuntimeTextureFromImage = function(txd, n, path) log('FromImage', txd, n, path) end
env.AddReplaceTexture = function(a, b, c, d) log('Add', a, b, c, d) end
env.RemoveReplaceTexture = function(a, b) log('Remove', a, b) end
env.AddEventHandler = function() end
env.RegisterNetEvent = function() end
env.TriggerServerEvent = function() end
-- runtime.lua : uniquement la partie textures et projets nous intéresse ; le reste est défini sans s'exécuter
local f = assert(io.open(ROOT .. '/client/runtime.lua', 'r')) local src = f:read('a') f:close()
local chunk = assert(load(src, '@client/runtime.lua', 't', env))
local okLoad, err = pcall(chunk)
check(okLoad, 'client/runtime.lua se charge' .. (okLoad and '' or ' : ' .. tostring(err)))
threads = {}   -- boucles de chargement et de lumières du moteur : hors sujet ici
local R = env.BRuntime
R.unloadProject = function() end
local asked = {}
R.texRequest = function(id) asked[#asked + 1] = id end

print('\n[Texture importée (image du PC)]')
R.projects.p1 = { data = { id = 'p1', textures = { { txd = 'ubk_textures', txn = 'ubk_brique', tex = 'tx1', w = 512, h = 512 } } } }
R.refreshTextures()
check(asked[1] == 'tx1' and not has('Add '), 'image absente : demandée au serveur, rien de remplacé')
R.texData.tx1 = 'data:image/png;base64,AAA'
R.refreshTextures()
check(has('CreateDui nui://builder_studio/html/tex.html 512 512'), 'page DUI créée à la bonne résolution')
duiReady[1] = true tick(3)
check(has('SendDuiMessage 1 {"src":"data:image/png;base64,AAA"}') and has('FromDui') and has('Add ubk_textures ubk_brique'), 'image envoyée à la page, texture créée et remplacement appliqué')
check(count('Add ubk_textures ubk_brique') == 1, 'un seul remplacement (pas de doublon)')
R.refreshTextures()
check(count('Add ubk_textures ubk_brique') == 1, 'rafraîchir sans changement : rien de refait')

print('\n[Lien https et ancien fichier]')
R.projects.p1.data.textures[2] = { txd = 'prop_a', txn = 'logo', url = 'https://exemple.fr/l.png', w = 256, h = 256 }
R.projects.p1.data.textures[3] = { txd = 'prop_b', txn = 'mur', file = 'mur.png' }
R.refreshTextures()
check(has('CreateDui nui://builder_studio/html/tex.html 256 256') and has('FromImage') and has('Add prop_b mur'), 'lien : page DUI ; fichier : texture depuis l\'image (comme avant)')
duiReady[2] = true tick(3)
check(has('Add prop_a logo'), 'lien appliqué quand la page est prête')

print('\n[Retrait]')
table.remove(R.projects.p1.data.textures, 2)
R.refreshTextures()
check(has('Remove prop_a logo') and has('DestroyDui 2'), 'remplacement retiré : texture d\'origine rendue, page libérée')
R.projects.p1.data.textures[1].tex = 'tx2'
R.texData.tx2 = 'data:image/png;base64,BBB'
R.refreshTextures()
check(has('Remove ubk_textures ubk_brique'), 'texture changée : l\'ancienne est retirée avant la nouvelle')
duiReady[3] = true tick(3)
check(count('Add ubk_textures ubk_brique') == 2, 'nouvelle texture appliquée')
R.removeProject('p1')
check(has('Remove prop_b mur') and count('Remove ubk_textures ubk_brique') == 2, 'projet retiré : tous ses remplacements sont retirés')
R.projects.p2 = { data = { id = 'p2', textures = { { txd = 'x', txn = 'y', url = 'https://a.fr/b.png' } } } }
R.refreshTextures()
R.clearTextures()
check(has('Remove x y') or not has('Add x y'), 'arrêt de la ressource : nettoyage complet')
return fails
