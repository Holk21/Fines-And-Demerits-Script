fx_version 'cerulean'
game 'gta5'

name 'qb-fines-demerits'
author 'ChatGPT'
description 'QBCore Fines & Demerits with NZ-inspired fines, NPC payments, 24-month rolling demerits, engine block, okokNotify, and Tablet UI'
version '1.3.0'

lua54 'yes'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    'qb-core',
    'qb-menu',
    'qb-target'
}
