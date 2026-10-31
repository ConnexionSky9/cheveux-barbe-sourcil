-- Petites assertions communes aux tests
local T = { fails = 0, count = 0 }
function T.ok(cond, msg)
    T.count = T.count + 1
    if cond then print('  ok   ' .. msg) else T.fails = T.fails + 1 print('  ÉCHEC ' .. msg) end
end
function T.near(a, b, msg, eps) T.ok(math.abs((a or 1e9) - b) < (eps or 1e-3), msg .. (' (%s ~ %s)'):format(tostring(a), tostring(b))) end
function T.load(root, rel)
    local f = assert(loadfile(root .. '/' .. rel))
    return f()
end
function T.shared(root)
    for _, f in ipairs({ 'shared/mathx.lua', 'shared/kits.lua', 'shared/geometry.lua', 'shared/catalog.lua', 'shared/schema.lua', 'shared/compose.lua' }) do T.load(root, f) end
end
return T
