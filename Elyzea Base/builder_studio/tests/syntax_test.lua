-- Compile chaque fichier Lua de la ressource (erreurs de syntaxe) et vérifie le fxmanifest
local root = ...
local T = dofile(root .. '/tests/helpers.lua')
local files = {
    'fxmanifest.lua', 'config.lua',
    'shared/mathx.lua', 'shared/kits.lua', 'shared/geometry.lua', 'shared/catalog.lua', 'shared/schema.lua', 'shared/compose.lua',
    'server/storage.lua', 'server/projects.lua', 'server/export.lua', 'server/main.lua',
    'client/runtime.lua', 'client/editor.lua', 'client/main.lua',
    'export_template/client.lua', 'export_template/server.lua',
}
for _, f in ipairs(files) do
    local h = io.open(root .. '/' .. f, 'rb')
    T.ok(h ~= nil, f .. ' existe')
    if h then
        local src = h:read('a') h:close()
        -- FiveM accepte les littéraux `modele` (hash) : aucun n'est utilisé ici
        local fn, err = load(src, '@' .. f)
        T.ok(fn ~= nil, f .. ' compile' .. (err and (' : ' .. err) or ''))
    end
end
-- chaque fichier cité par le manifeste existe
local man = io.open(root .. '/fxmanifest.lua'):read('a')
for path in man:gmatch("'([%w_/%.%*]+%.[%a]+)'") do
    if not path:find('%*') then
        local h = io.open(root .. '/' .. path, 'rb')
        T.ok(h ~= nil, 'manifeste : ' .. path)
        if h then h:close() end
    end
end
return T.fails
