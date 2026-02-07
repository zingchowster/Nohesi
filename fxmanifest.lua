fx_version 'cerulean'
game 'gta5'

author 'Leaf'
description 'Nohesi HUD for FiveM'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

ui_page 'fivem-hud.html'

files {
    'fivem-hud.html',
    'index.css'
}

dependency 'oxmysql'
