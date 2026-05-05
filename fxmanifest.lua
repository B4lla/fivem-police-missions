fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Balla'
description 'Misiones de servicio anti-AFK para police y ambulance (QB-Core)'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'shared/locales/es.lua',
    'shared/config.lua',
    'shared/missions.lua'
}

client_scripts {
    'client/npc.lua',
    'client/ui.lua',
    'client/mission_core.lua',
    'client/missions_police.lua',
    'client/missions_ems.lua'
}

server_scripts {
    'server/main.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'qb-core',
    'qb-target'
}
