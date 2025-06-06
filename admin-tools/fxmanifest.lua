fx_version 'cerulean'
game 'gta5'
lua54 'on'

author '_flame_op_'
description 'Admin Tools: Vehicle Delete, Vehicle Transfer, Inventory Wipe, Steam Blocker'
version '1.0.0'



shared_scripts {
    'config.lua'
}

server_scripts {
    'vehicledelete.lua',
    'vehicletransfer.lua',
    'inventorywipe.lua',
    'namechange.lua',
    'steamblock.lua'
}

dependencies {
    'qb-core',
    'oxmysql'
}

escrow_ignore {
    'config.lua'
}