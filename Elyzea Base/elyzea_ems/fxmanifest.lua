fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_ems'
author 'Elyzea FA'
description 'Métier EMS / SAMS Elyzea : coma, soins, réanimation, appels, soutien, facturation, PPA, dossiers médicaux, comptes rendus, garage, tablette (direction, finance, paie au taux horaire)'
version '1.0.0'

shared_scripts {
    '@elyzea_core/lib/ely.lua',
    'config.lua',
    'config_procedures.lua',
    'shared/perms.lua',
    'shared/lab_rules.lua',
    'shared/health_rules.lua',
    'shared/procedure_rules.lua',
}

server_scripts {
    '@elyzea_core/lib/MySQL.lua',
    'server/main.lua',
    'server/agencies.lua',
    'server/service.lua',
    'server/finance.lua',
    'server/commission.lua',
    'server/death.lua',
    'server/calls.lua',
    'server/medical.lua',
    'server/billing.lua',
    'server/ppa.lua',
    'server/records.lua',
    'server/records_points.lua',
    'server/appointments.lua',
    'server/health.lua',
    'server/lab.lua',
    'server/injuries.lua',
    'server/procedures.lua',
    'server/direction.lua',
    'server/garage.lua',
    'server/phone.lua',
    'server/api.lua',
}

client_scripts {
    'client/main.lua',
    'client/death.lua',
    'client/calls.lua',
    'client/medical.lua',
    'client/f6.lua',
    'client/tablet.lua',
    'client/phone.lua',
    'client/garage.lua',
    'client/health.lua',
    'client/procedures.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/tablet.js',
    'html/map.js',
    'html/proc.js',
    'html/proc.css',
    'html/img/*',
}

dependencies { 'elyzea_core' }
