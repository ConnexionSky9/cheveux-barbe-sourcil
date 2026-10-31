-- Simulation hors jeu : scripts serveur RÉELS de builder_studio (copie temporaire),
-- natives FiveM et admin_menu imités. Lancé par tests/run_admin_textures.py.
local ROOT = ...
local fails, passes = 0, 0
local function check(ok, label) if ok then passes = passes + 1 print('  ok   ' .. label) else fails = fails + 1 print('  ÉCHEC ' .. label) end end

-- JSON minimal (encodeur / décodeur) suffisant pour les fichiers du studio
local json = {}
do
    local function esc(s) return (s:gsub('[%c"\\]', function(c) return ({ ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' })[c] or ('\\u%04x'):format(c:byte()) end)) end
    local function isArr(t) local n = 0 for k in pairs(t) do if type(k) ~= 'number' then return false end n = n + 1 end return n == #t end
    function json.encode(v)
        local t = type(v)
        if t == 'nil' then return 'null' elseif t == 'boolean' then return tostring(v)
        elseif t == 'number' then if math.type(v) == 'integer' then return tostring(v) end return ('%.14g'):format(v)
        elseif t == 'string' then return '"' .. esc(v) .. '"'
        elseif t == 'table' then
            if next(v) == nil then return '[]' end
            local o = {}
            if isArr(v) then for _, x in ipairs(v) do o[#o + 1] = json.encode(x) end return '[' .. table.concat(o, ',') .. ']' end
            for k, x in pairs(v) do o[#o + 1] = json.encode(tostring(k)) .. ':' .. json.encode(x) end
            return '{' .. table.concat(o, ',') .. '}'
        end
        return 'null'
    end
    function json.decode(s)
        local i = 1
        local function ws() i = s:find('%S', i) or #s + 1 end
        local val
        local function str()
            local out = {} i = i + 1
            while true do
                local c = s:sub(i, i)
                if c == '"' then i = i + 1 break end
                if c == '\\' then local n = s:sub(i + 1, i + 1)
                    if n == 'u' then out[#out + 1] = utf8.char(tonumber(s:sub(i + 2, i + 5), 16)) i = i + 6
                    else out[#out + 1] = ({ n = '\n', r = '\r', t = '\t' })[n] or n i = i + 2 end
                else out[#out + 1] = c i = i + 1 end
            end
            return table.concat(out)
        end
        function val()
            ws()
            local c = s:sub(i, i)
            if c == '{' then local t = {} i = i + 1 ws() if s:sub(i, i) == '}' then i = i + 1 return t end
                while true do ws() local k = str() ws() i = i + 1 t[k] = val() ws() local d = s:sub(i, i) i = i + 1 if d == '}' then break end end return t
            elseif c == '[' then local t = {} i = i + 1 ws() if s:sub(i, i) == ']' then i = i + 1 return t end
                while true do t[#t + 1] = val() ws() local d = s:sub(i, i) i = i + 1 if d == ']' then break end end return t
            elseif c == '"' then return str()
            elseif s:sub(i, i + 3) == 'true' then i = i + 4 return true
            elseif s:sub(i, i + 4) == 'false' then i = i + 5 return false
            elseif s:sub(i, i + 3) == 'null' then i = i + 4 return nil
            else local n = s:match('^-?%d+%.?%d*[eE]?[-+]?%d*', i) i = i + #n return tonumber(n) end
        end
        return val()
    end
end

-- ---------------------------------------------------------------------
-- Environnement serveur imité
-- ---------------------------------------------------------------------
local handlers, clientEvents, latent = {}, {}, {}
local staffPerms = {}            -- [src] = { perm = true }
local aces = {}                  -- [src] = { ace = true }
local adminState = 'started'
local names = { [1] = 'Staff Tout', [2] = 'Staff Ouvrir', [3] = 'Joueur', [4] = 'Staff ACE', [5] = 'Staff Import' }
local env = setmetatable({}, { __index = _G })
env.json = json
env.vector3 = function(x, y, z) return { x = x, y = y, z = z } end
env.CreateThread = function(fn) local co = coroutine.create(fn) coroutine.resume(co) end
env.Wait = function() coroutine.yield() end
env.GetGameTimer = function() return os.clock() * 1000 end
env.GetCurrentResourceName = function() return 'builder_studio' end
env.GetResourcePath = function() return ROOT end
env.GetResourceState = function(r) if r == 'admin_menu' then return adminState end return 'missing' end
env.LoadResourceFile = function(_, path) local f = io.open(ROOT .. '/' .. path, 'rb') if not f then return nil end local s = f:read('a') f:close() return s end
env.SaveResourceFile = function(_, path, data) local f = io.open(ROOT .. '/' .. path, 'wb') if not f then return false end f:write(data) f:close() return true end
env.IsPlayerAceAllowed = function(src, ace) return aces[src] ~= nil and aces[src][ace] == true end
env.GetPlayerIdentifiers = function(src) return { 'license:' .. src } end
env.GetPlayerName = function(src) return names[src] end
env.exports = setmetatable({ admin_menu = { HasPermission = function(_, src, perm) return (staffPerms[src] or {})[perm] == true end } }, { __call = function() end })
env.RegisterNetEvent = function(name, fn) if fn then handlers[name] = fn end end
env.AddEventHandler = function(name, fn) handlers[name] = fn end
env.TriggerClientEvent = function(name, target, ...) clientEvents[#clientEvents + 1] = { name = name, target = target, args = { ... } } end
env.TriggerLatentClientEvent = function(name, target, bps, ...) latent[#latent + 1] = { name = name, target = target, args = { ... } } end
env.RegisterCommand = function() end
env.print = function(...) local s = table.concat({ ... }, ' ') if s:find('%^1') then print('  [erreur] ' .. s) end end
local function fire(name, src, ...) env.source = src return handlers[name](...) end
local function last(name) for i = #clientEvents, 1, -1 do if clientEvents[i].name == name then return clientEvents[i] end end end
local function lastNotify(src) for i = #clientEvents, 1, -1 do local e = clientEvents[i] if e.name == 'builder:notify' and e.target == src then return e.args[1], e.args[2] end end return '' end

local function loadFile(path)
    local f = assert(io.open(ROOT .. '/' .. path, 'r')) local s = f:read('a') f:close()
    assert(load(s, '@' .. path, 't', env))()
end
for _, f in ipairs({ 'config.lua', 'shared/mathx.lua', 'shared/kits.lua', 'shared/geometry.lua', 'shared/catalog.lua', 'shared/schema.lua', 'shared/compose.lua',
    'server/storage.lua', 'server/textures.lua', 'server/projects.lua', 'server/export.lua', 'server/main.lua' }) do loadFile(f) end
local Perm, Textures, Projects, Export = env.Perm, env.Textures, env.Projects, env.Export

print('\n[Permissions staff admin_menu]')
staffPerms[1] = { builder_manage = true }
staffPerms[2] = { builder_access = true }
staffPerms[5] = { builder_access = true, builder_import = true }
aces[4] = { ['builder.access'] = true, ['builder.build'] = true }
local all = true
for k in pairs(env.Config.Ace) do if not Perm.has(1, k) then all = false end end
check(all, '« builder_manage » (Builder Studio : TOUT) donne tous les droits')
check(Perm.has(2, 'access') and not Perm.has(2, 'build') and not Perm.has(2, 'import'), 'case « ouvrir » seule : ouvrir oui, construire / importer non')
check(Perm.has(5, 'import') and not Perm.has(5, 'export'), 'case « importer » : importer oui, exporter non')
check(not Perm.has(3, 'access'), 'joueur sans permission : refusé')
check(Perm.has(4, 'build') and not Perm.has(4, 'delete'), 'ACE builder.* toujours valables (sans admin_menu)')
check(Perm.has(0, 'admin'), 'console : tous les droits')
adminState = 'stopped'
check(not Perm.has(1, 'access') and Perm.has(4, 'access'), 'admin_menu arrêté : pas d\'erreur, seules les ACE comptent')
adminState = 'started'
fire('builder:open', 3)
check(lastNotify(3):find('admin_menu', 1, true) ~= nil, 'ouverture refusée avec un message qui cite admin_menu')
fire('builder:open', 1)
local op = last('builder:opened')
check(op and op.target == 1 and op.args[1].perms.import == true and type(op.args[1].textures) == 'table', 'staff : studio ouvert (droits + bibliothèque envoyés)')

print('\n[Bibliothèque de textures]')
fire('builder:tex:upload', 2, { name = 'Brique', kind = 'image', data = SAMPLE_B64, w = 512, h = 512 })
check(#Textures.list == 0 and lastNotify(2):find('importation', 1, true), 'sans « importer » : refusé')
fire('builder:tex:upload', 5, { name = 'Brique rouge', kind = 'image', data = SAMPLE_B64, w = 512, h = 512 })
check(#Textures.list == 1 and Textures.list[1].kind == 'image', 'image du PC ajoutée : ' .. tostring(lastNotify(5)))
local img = Textures.list[1]
check(env.LoadResourceFile(nil, 'data/textures/' .. img.id .. '.txt') == SAMPLE_B64, 'image gardée dans data/textures/<id>.txt')
check(last('builder:tex:list') and last('builder:tex:list').target == -1, 'bibliothèque renvoyée à tous les éditeurs')
check(select(2, Textures.add(5, { name = 'X', kind = 'image', data = 'data:image/jpeg;base64,AAAA', w = 512, h = 512 })) ~= nil, 'image non PNG refusée')
check(select(2, Textures.add(5, { name = 'X', kind = 'image', data = SAMPLE_B64, w = 500, h = 512 })) ~= nil, 'résolution non puissance de 2 refusée')
check(select(2, Textures.add(5, { name = 'X', kind = 'image', data = 'data:image/png;base64,' .. string.rep('A', env.Config.Textures.maxBytes), w = 512, h = 512 })) ~= nil, 'image trop lourde refusée')
check(select(2, Textures.add(5, { name = '', kind = 'image', data = SAMPLE_B64, w = 512, h = 512 })) ~= nil, 'texture sans nom refusée')
local u = Textures.add(5, { name = 'Logo', kind = 'url', url = 'https://exemple.fr/logo.png', w = 256, h = 256 })
check(u and u.kind == 'url', 'lien https ajouté')
check(select(2, Textures.add(5, { name = 'X', kind = 'url', url = 'http://exemple.fr/a.png', w = 256, h = 256 })) ~= nil, 'lien non https refusé')
check(select(2, Textures.add(5, { name = 'X', kind = 'url', url = 'https://a.fr/"><script>', w = 256, h = 256 })) ~= nil, 'lien avec caractères dangereux refusé')
latent = {}
fire('builder:tex:get', 3, img.id)
check(latent[1] and latent[1].target == 3 and latent[1].args[2] == SAMPLE_B64, 'image envoyée à un joueur qui en a besoin (envoi progressif)')
fire('builder:tex:get', 3, img.id)
check(#latent == 1, 'redemande immédiate ignorée (anti-abus)')
local bytes = Textures.png(img.id)
check(bytes and #bytes == SAMPLE_LEN and bytes:sub(2, 4) == 'PNG', 'décodage base64 → PNG exact')

print('\n[Remplacements de textures d\'un projet]')
fire('builder:project:create', 1, { name = 'Test tex', origin = { x = 0, y = 0, z = 70 } })
local pid
for id in pairs(Projects.index.projects) do pid = id end
check(pid ~= nil, 'projet créé par le staff')
fire('builder:textures', 5, pid, { { txd = 'ubk_textures', txn = 'ubk_brique', tex = img.id }, { txd = 'prop_x', txn = 'tex_logo', tex = u.id } })
local p = Projects.get(pid)
check(#p.textures == 2 and p.textures[1].tex == img.id and p.textures[2].url == u.url and p.textures[2].w == 256, 'remplacements enregistrés (image + lien, résolution)')
check(last('builder:textures') and last('builder:textures').args[2][1].txn == 'ubk_brique', 'remplacements envoyés aux éditeurs')
fire('builder:textures', 5, pid, { { txd = 'a', txn = 'b', tex = 'inexistant' } })
check(#Projects.get(pid).textures == 2 and lastNotify(5):find('introuvable', 1, true), 'texture inconnue refusée (projet inchangé)')
fire('builder:textures', 5, pid, { { txd = 'a', txn = 'b', tex = img.id }, { txd = 'a', txn = 'b', tex = u.id } })
check(lastNotify(5):find('deux fois', 1, true) ~= nil, 'même texture visée deux fois refusée')
fire('builder:textures', 2, pid, {})
check(#Projects.get(pid).textures == 2, 'sans « importer » : remplacements inchangés')

print('\n[Export]')
local built = Export.build(Projects.get(pid), { name = 'map_test_tex' })
local data = json.decode(built.files['data.json'])
check(data.textures[1].file == img.id .. '.png' and data.textures[1].tex == nil, 'export : image de la bibliothèque → fichier PNG')
check(data.textures[2].url == u.url, 'export : lien gardé')
check(built.files['tex.html'] ~= nil and built.files['fxmanifest.lua']:find("'tex.html'", 1, true) and built.files['fxmanifest.lua']:find("'textures/" .. img.id .. ".png'", 1, true),
    'export : tex.html et le PNG déclarés dans le fxmanifest')
local res = Export.run(1, pid, { name = 'map_test_tex' })
check(res and #res.warnings == 0, 'export écrit sur le disque sans avertissement')
check(Export.run(2, pid, { name = 'x' }) == nil, 'export refusé sans la case « exporter »')

print('\n[Suppression]')
fire('builder:tex:remove', 2, u.id)
check(Textures.get(u.id) ~= nil, 'sans « importer » : suppression refusée')
fire('builder:tex:remove', 5, u.id)
check(Textures.get(u.id) == nil and #Textures.list == 1, 'texture supprimée')
Textures.load()
check(#Textures.list == 1 and Textures.list[1].id == img.id, 'bibliothèque relue depuis le disque (redémarrage)')
return fails
