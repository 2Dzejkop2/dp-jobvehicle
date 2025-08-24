fx_version 'cerulean'

game 'gta5'

name 'jobvehicle'
author 'you'
version '1.0.0'
description 'Command /jobvehicle to set vehicle job after confirmation using ox_lib'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'ox_lib',
    'oxmysql'
}
