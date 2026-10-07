--[[
    ELYZEA CORE — métiers et groupes de base.
    Les métiers Elyzea (police, ambulance, concession, LsCustom…) sont déclarés
    automatiquement par leur ressource au démarrage (exports.elyzea_core:CreateJobs).
    Les métiers créés dans admin_menu › Métiers le sont aussi.
    Ne mettez ici que les métiers « fixes » du serveur.

    Format :
    ['nom'] = { label = 'Nom affiché', type = 'leo' | 'ems' | ..., defaultDuty = true, offDutyPay = false,
                grades = { [0] = { name = 'Grade', payment = 50, isboss = true } } }
]]

ElyJobs = {
    ['unemployed'] = {
        label = 'Sans emploi',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Citoyen', payment = 10 },
        },
    },
}

-- Les organisations illégales sont gérées par elyzea_illegal ; « none » doit toujours exister.
ElyGangs = {
    ['none'] = {
        label = 'Aucun',
        grades = {
            [0] = { name = 'Aucun' },
        },
    },
}
