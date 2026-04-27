fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'clp_realtuner'
author 'Contentlos (clp)'
description 'Hardcore Tuning & Mechaniker-Simulation fuer ESX Legacy (ox_target, ox_inventory, oxmysql, ox_lib)'
version '1.0.0'

dependencies {
    'es_extended',
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/modtypes.lua',
    'shared/utils.lua',
    'config/config.lua',
    'config/parts.lua',
    'config/locations.lua',
}

client_scripts {
    'client/main.lua',
    'client/diagnostics.lua',
    'client/scan.lua',
    'client/target.lua',
    'client/install.lua',
    'client/paint.lua',
    'client/ecu.lua',
    'client/damage.lua',
    'client/handling.lua',
    'client/tablet.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/vin.lua',
    'server/main.lua',
    'server/logging.lua',
    'server/admin.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

provide 'clp_realtuner'
