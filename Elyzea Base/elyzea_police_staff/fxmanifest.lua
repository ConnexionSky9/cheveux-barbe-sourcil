fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'elyzea_police_staff'
description 'Tablette staff Police : configuration complète du métier Police (accès géré par admin_menu)'
version '1.0.0'

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'elyzea_police',
}
