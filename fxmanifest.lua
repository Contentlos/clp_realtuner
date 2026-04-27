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
    'client/runtime.lua',
    'client/diagnostics.lua',
    'client/scan.lua',
    'client/target.lua',
    'client/install.lua',
    'client/paint.lua',
    'client/ecu.lua',
    'client/damage.lua',
    'client/handling.lua',
    'client/tablet.lua',
    'client/adminui.lua',
    'client/wartung.lua',
    'client/physics.lua',
    'client/audio.lua',
    'client/hud.lua',
    'client/diag_tools.lua',
    'client/dyno.lua',
    'client/visuals.lua',
    'client/tune_advanced.lua',
    'client/progression.lua',
    'client/workshop.lua',
    'client/customer_jobs.lua',
    'client/trip.lua',
    'client/police.lua',
    'client/insurance.lua',
    'bridges/fuel.lua',
    'bridges/lbphone.lua',
    'client/admin_liveview.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/migrations.lua',
    'server/vin.lua',
    'server/runtime.lua',
    'server/main.lua',
    'server/logging.lua',
    'server/wartung.lua',
    'server/admin.lua',
    'server/adminapi.lua',
    'server/diagnostics.lua',
    'server/dyno.lua',
    'server/progression.lua',
    'server/workshop.lua',
    'server/customer_jobs.lua',
    'server/police.lua',
    'server/insurance.lua',
    'server/admin_liveview.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/admin.css',
    'html/hud.css',
    'html/diag.css',
    'html/app.js',
    'html/admin.js',
    'html/hud.js',
    'html/diag.js',
    'html/phone_app.html',
    'migrations/INDEX.txt',
    'migrations/000_base_schema_fix.sql',
    'migrations/001_fluids_and_wear.sql',
    'migrations/002_workshops.sql',
    'migrations/003_progression_racing_police.sql',
    'migrations/004_portfolio.sql',
    'migrations/005_police.sql',
}

provide 'clp_realtuner'
