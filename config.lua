Config = {}

-- Framework selection: 'ESX' | 'QB' | 'CUSTOM'
Config.Framework = 'ESX'

-- Whether to actually update DB. If false, server just logs.
Config.EnableDatabaseUpdate = true

-- If true, players can set job only for vehicles they own
Config.RequireOwnership = true

-- Vehicles table info per framework
Config.ESX = {
    table = 'owned_vehicles',
    plateColumn = 'plate',
    jobColumn = 'job', -- ensure this column exists in your DB
    ownerColumn = 'owner', -- identifier/license/steam depending on your ESX setup
}

Config.QB = {
    table = 'player_vehicles',
    plateColumn = 'plate',
    jobColumn = 'job', -- ensure this column exists in your DB
    ownerColumn = 'citizenid',
}

-- If you need custom SQL, implement in server/main.lua where marked.
