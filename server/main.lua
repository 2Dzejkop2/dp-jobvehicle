---@diagnostic disable: undefined-global
local Config = Config

-- Try to grab framework objects based on config
local ESX, QBCore
if Config.Framework == 'ESX' then
    local ok, obj = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)
    if ok then ESX = obj end
elseif Config.Framework == 'QB' then
    local ok, obj = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    if ok then QBCore = obj end
end

local function getPlayerJob(src)
    if Config.Framework == 'ESX' and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer and xPlayer.job and xPlayer.job.name then
            return xPlayer.job.name
        end
    elseif Config.Framework == 'QB' and QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData and Player.PlayerData.job and Player.PlayerData.job.name then
            return Player.PlayerData.job.name
        end
    elseif Config.Framework == 'CUSTOM' then
        -- Implement your custom framework job fetch here
        -- return 'police'
    end
    return nil
end

-- ox_lib callback to get current player's job name on the client
lib.callback.register('jobvehicle:getJobName', function(source)
    return getPlayerJob(source)
end)

-- Helpers: plate variants and DB map
local function plateVariants(raw)
    local withSpaces = tostring(raw or '')
    local trimmed = withSpaces:gsub('%s+', '')
    local mixed = trimmed
    if #trimmed > 3 and not withSpaces:match('%s') then
        mixed = trimmed:sub(1, 3) .. ' ' .. trimmed:sub(4)
    elseif withSpaces:match('%s') then
        mixed = trimmed
    end
    return trimmed, withSpaces, mixed
end

local function getDBMap()
    if Config.Framework == 'ESX' then
        return Config.ESX.table, Config.ESX.plateColumn, Config.ESX.jobColumn, Config.ESX.jobPersonalColumn, (Config.ESX.ownerColumn or 'owner')
    elseif Config.Framework == 'QB' then
        return Config.QB.table, Config.QB.plateColumn, Config.QB.jobColumn, Config.QB.jobPersonalColumn, (Config.QB.ownerColumn or 'citizenid')
    else
        return nil
    end
end

local function getOwnerId(src)
    if Config.Framework == 'ESX' and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        return xPlayer and xPlayer.identifier or nil
    elseif Config.Framework == 'QB' and QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        return Player and Player.PlayerData and Player.PlayerData.citizenid or nil
    end
    return nil
end

-- Local function to check ownership using plate variants
local function isOwnerOfPlate(src, rawPlate)
    if type(rawPlate) ~= 'string' then return false end
    if not Config.RequireOwnership then return true end

    local tableName, plateCol, _, _, ownerCol = getDBMap()
    if not tableName then return false end

    local ownerId = getOwnerId(src)
    if not ownerId then return false end

    local t, r, m = plateVariants(rawPlate)
    local query = ('SELECT 1 FROM `%s` WHERE `%s` = ? AND `%s` IN (?, ?, ?) LIMIT 1')
        :format(tableName, ownerCol, plateCol)
    local exists
    local ok, err = pcall(function()
        exists = MySQL.scalar.await(query, { ownerId, t, r, m }) ~= nil
    end)
    if not ok then
        print(('[jobvehicle] SQL error (ownership check): %s'):format(err))
        return false
    end
    return exists
end

-- Server callback for client-side ownership check
lib.callback.register('jobvehicle:isOwnerOfPlate', function(source, plate)
    return isOwnerOfPlate(source, plate)
end)

RegisterNetEvent('jobvehicle:setVehicleJob', function(rawPlate, action)
    local src = source

    if type(rawPlate) ~= 'string' or rawPlate == '' then
        TriggerClientEvent('jobvehicle:result', src, false, 'Chybná SPZ (plate).')
        return
    end

    -- enforce ownership server-side as well (direct check)
    if not isOwnerOfPlate(src, rawPlate) then
        TriggerClientEvent('jobvehicle:result', src, false, 'Toto vozidlo nevlastníš.')
        return
    end

    local job = getPlayerJob(src)
    if not job or job == '' then
        TriggerClientEvent('jobvehicle:result', src, false, 'Nepodařilo se zjistit tvoji práci.')
        return
    end

    local t, r, m = plateVariants(rawPlate)

    if not Config.EnableDatabaseUpdate then
        print(('[jobvehicle] Simulace: nastavuji job=%s pro SPZ varianty: %s | %s | %s'):format(job, t, r, m))
        TriggerClientEvent('jobvehicle:result', src, true, ('Simulace: SPZ přiřazena práci %s.'):format(job), job)
        return
    end

    local tableName, plateCol, jobCol, jobPersonalCol, ownerCol = getDBMap()
    if not tableName then
        TriggerClientEvent('jobvehicle:result', src, false, 'Neznámý framework v configu.')
        return
    end

    if Config.Framework == 'CUSTOM' then
        -- Do your own SQL here if using custom framework
        -- Example:
        -- local affected = MySQL.update.await('UPDATE my_table SET job = ? WHERE plate = ?', { job, safePlate })
        -- TriggerClientEvent('jobvehicle:result', src, affected and affected > 0, affected and 'OK' or 'SPZ nenalezena', job)
        TriggerClientEvent('jobvehicle:result', src, false, 'CUSTOM mód není nastaven.')
        return
    end

    local mode = type(action) == 'string' and action:lower() or 'society'
    if mode ~= 'personal' then mode = 'society' end

    local query, params
    if mode == 'society' then
        if not jobCol or jobCol == '' or not ownerCol or ownerCol == '' then
            TriggerClientEvent('jobvehicle:result', src, false, 'DB sloupce (job/owner) nejsou správně nastavené.')
            return
        end
        query = ('UPDATE `%s` SET `%s` = ?, `%s` = ? WHERE `%s` IN (?, ?, ?)')
            :format(tableName, jobCol, ownerCol, plateCol)
        params = { job, job, t, r, m }
    else -- personal
        if not jobPersonalCol or jobPersonalCol == '' then
            TriggerClientEvent('jobvehicle:result', src, false, 'DB sloupec pro osobní vlastnictví není nastaven.')
            return
        end
        query = ('UPDATE `%s` SET `%s` = ? WHERE `%s` IN (?, ?, ?)')
            :format(tableName, jobPersonalCol, plateCol)
        params = { job, t, r, m }
    end

    local affected
    local ok, err = pcall(function()
        affected = MySQL.update.await(query, params)
    end)

    if not ok then
        print(('[jobvehicle] SQL error: %s'):format(err))
        TriggerClientEvent('jobvehicle:result', src, false, 'Chyba databáze, zkontroluj server konzoli.')
        return
    end

    if affected and affected > 0 then
        TriggerClientEvent('jobvehicle:result', src, true, ('Vozidlo bylo přepsáno na práci %s (%s).'):format(job, mode), job)
    else
        TriggerClientEvent('jobvehicle:result', src, false, 'Vozidlo se zadanou SPZ nebylo nalezeno v databázi.')
    end
end)
