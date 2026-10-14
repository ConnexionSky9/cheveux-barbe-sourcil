--[[
    NOIR X — Démarrage ordonné
    Les modules s'enregistrent avec Boot.Register(nom, fn). Une fois la base détectée,
    les réglages persistants sont appliqués puis chaque module est initialisé
    (restauration des opérations en cours après un redémarrage, etc.).
]]

Boot = { tasks = {}, done = false }

function Boot.Register(name, fn)
    Boot.tasks[#Boot.tasks + 1] = { name = name, fn = fn }
end

function Boot.Run()
    if Boot.done then return end
    Boot.done = true
    Settings.LoadOverrides()
    for _, t in ipairs(Boot.tasks) do
        local ok, err = pcall(t.fn)
        if not ok then NoirX.Error(('Initialisation %s : %s'):format(t.name, tostring(err))) end
    end
    NoirX.Debug('NOIR X prêt.')
end

CreateThread(function()
    while not DB.ready do Wait(100) end
    Boot.Run()
end)
