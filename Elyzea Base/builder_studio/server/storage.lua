-- =========================================================
--  BUILDER STUDIO - STOCKAGE (fichiers JSON, aucune base de données)
--  data/index.json            liste des projets + points de restauration
--  data/projects/<id>.json    un fichier par projet
--  data/versions/<id>_<n>.json  points de restauration
--  data/custom_models.json    objets personnalisés ajoutés au catalogue
--  data/dims.json             dimensions des modèles vanilla mesurées en jeu
--  Écriture sécurisée : on écrit, on relit, et on garde la copie .bak
--  précédente du projet pour ne jamais perdre une sauvegarde.
-- =========================================================
Store = {}
local RES = GetCurrentResourceName()

local function read(path)
    local raw = LoadResourceFile(RES, path)
    if not raw or raw == '' then return nil end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then return data end
    print(('^1[Builder] Fichier %s illisible.^7'):format(path))
    return nil
end

local function write(path, data, pretty)
    local ok, raw = pcall(json.encode, data, pretty and { indent = true } or nil)
    if not ok or not raw then
        print(('^1[Builder] Encodage JSON impossible pour %s : %s^7'):format(path, tostring(raw)))
        return false
    end
    if not SaveResourceFile(RES, path, raw, -1) then
        print(('^1[Builder] Écriture impossible : %s (le dossier existe-t-il ?)^7'):format(path))
        return false
    end
    return true
end
Store.read, Store.write = read, write

function Store.loadIndex()
    local idx = read('data/index.json') or {}
    idx.projects = idx.projects or {}
    return idx
end

function Store.saveIndex(idx) return write('data/index.json', idx, true) end

function Store.loadProject(id)
    local p = read(('data/projects/%s.json'):format(id))
    if not p then
        p = read(('data/projects/%s.bak.json'):format(id))
        if p then print(('^3[Builder] Projet %s restauré depuis la copie de secours.^7'):format(id)) end
    end
    return BSchema.upgrade(p)
end

function Store.saveProject(p)
    local path = ('data/projects/%s.json'):format(p.id)
    local prev = LoadResourceFile(RES, path)
    if prev and prev ~= '' then SaveResourceFile(RES, ('data/projects/%s.bak.json'):format(p.id), prev, -1) end
    if not write(path, p) then return false end
    -- relecture de contrôle
    local back = LoadResourceFile(RES, path)
    if not back or #back < 10 then
        print(('^1[Builder] Sauvegarde du projet %s incomplète, copie de secours conservée.^7'):format(p.id))
        return false
    end
    return true
end

function Store.deleteProject(id)
    SaveResourceFile(RES, ('data/projects/%s.json'):format(id), '', -1)
    SaveResourceFile(RES, ('data/projects/%s.bak.json'):format(id), '', -1)
end

function Store.saveVersion(id, n, p) return write(('data/versions/%s_%d.json'):format(id, n), p) end
function Store.loadVersion(id, n) return BSchema.upgrade(read(('data/versions/%s_%d.json'):format(id, n))) end
function Store.deleteVersion(id, n) SaveResourceFile(RES, ('data/versions/%s_%d.json'):format(id, n), '', -1) end

function Store.loadCustom() return read('data/custom_models.json') or {} end
function Store.saveCustom(list) return write('data/custom_models.json', list, true) end
function Store.loadDims() return read('data/dims.json') or {} end
function Store.saveDims(d) return write('data/dims.json', d, true) end

return Store
