-- Environnement minimal pour charger les fichiers partagés hors FiveM
local root = ...
vector3 = function(x, y, z) return { x = x, y = y, z = z } end
vec3 = vector3
local function load_(rel) local f = assert(io.open(root .. '/' .. rel, 'r')) local s = f:read('a') f:close() assert(load(s, '@' .. rel))() end
LOAD = load_
load_('config.lua')
load_('shared/utils.lua')
load_('shared/bowling.lua')
if io.open(root .. '/shared/billiards.lua') then load_('shared/billiards.lua') end
if io.open(root .. '/shared/golf.lua') then load_('shared/golf.lua') end
