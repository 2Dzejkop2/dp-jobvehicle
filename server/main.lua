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

-- Check if the current player owns a vehicle with given plate
lib.callback.register('jobvehicle:isOwnerOfPlate', function(source, plate)
    if type(plate) ~= 'string' then return false end
    if not Config.RequireOwnership then return true end

    local safePlate = plate:gsub('%s+', '')

    local tableName, plateCol, ownerCol, ownerId

    if Config.Framework == 'ESX' and ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        ownerId = xPlayer.identifier
        tableName = Config.ESX.table
        plateCol = Config.ESX.plateColumn
        ownerCol = Config.ESX.ownerColumn or 'owner'

    elseif Config.Framework == 'QB' and QBCore then
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return false end
        ownerId = Player.PlayerData.citizenid
        tableName = Config.QB.table
        plateCol = Config.QB.plateColumn
        ownerCol = Config.QB.ownerColumn or 'citizenid'

    elseif Config.Framework == 'CUSTOM' then
        -- Implement your own ownership check here
        return false
    else
        return false
    end

    local query = ('SELECT 1 FROM `%s` WHERE `%s` = ? AND `%s` = ? LIMIT 1')
        :format(tableName, plateCol, ownerCol)

    local exists
    local ok, err = pcall(function()
        exists = MySQL.scalar.await(query, { safePlate, ownerId }) ~= nil
    end)
    if not ok then
        print(('[jobvehicle] SQL error (ownership check): %s'):format(err))
        return false
    end

    return exists
end)

RegisterNetEvent('jobvehicle:setVehicleJob', function(plate)
    local src = source

    if type(plate) ~= 'string' then
        TriggerClientEvent('jobvehicle:result', src, false, 'Chybná SPZ (plate).')
        return
    end

    -- enforce ownership server-side as well
    local isOwner = lib.callback.await('jobvehicle:isOwnerOfPlate', src, plate)
    if not isOwner then
        TriggerClientEvent('jobvehicle:result', src, false, 'Toto vozidlo nevlastníš.')
        return
    end

    local job = getPlayerJob(src)
    if not job or job == '' then
        TriggerClientEvent('jobvehicle:result', src, false, 'Nepodařilo se zjistit tvoji práci.')
        return
    end

    local safePlate = plate:gsub('%s+', '')

    if not Config.EnableDatabaseUpdate then
        print(('[jobvehicle] Simulace: nastavuji job=%s pro SPZ=%s'):format(job, safePlate))
        TriggerClientEvent('jobvehicle:result', src, true, ('Simulace: SPZ %s přiřazena práci %s.'):format(safePlate, job), job)
        return
    end

    local tableName, plateCol, jobCol
    if Config.Framework == 'ESX' then
        tableName = Config.ESX.table
        plateCol = Config.ESX.plateColumn
        jobCol = Config.ESX.jobColumn
    elseif Config.Framework == 'QB' then
        tableName = Config.QB.table
        plateCol = Config.QB.plateColumn
        jobCol = Config.QB.jobColumn
    elseif Config.Framework == 'CUSTOM' then
        -- Do your own SQL here if using custom framework
        -- Example:
        -- local affected = MySQL.update.await('UPDATE my_table SET job = ? WHERE plate = ?', { job, safePlate })
        -- TriggerClientEvent('jobvehicle:result', src, affected and affected > 0, affected and 'OK' or 'SPZ nenalezena', job)
        TriggerClientEvent('jobvehicle:result', src, false, 'CUSTOM mód není nastaven.')
        return
    else
        TriggerClientEvent('jobvehicle:result', src, false, 'Neznámý framework v configu.')
        return
    end

    local query = ('UPDATE `%s` SET `%s` = ? WHERE `%s` = ?'):format(tableName, jobCol, plateCol)
    local affected
    local ok, err = pcall(function()
        affected = MySQL.update.await(query, { job, safePlate })
    end)

    if not ok then
        print(('[jobvehicle] SQL error: %s'):format(err))
        TriggerClientEvent('jobvehicle:result', src, false, 'Chyba databáze, zkontroluj server konzoli.')
        return
    end

    if affected and affected > 0 then
        TriggerClientEvent('jobvehicle:result', src, true, ('Vozidlo %s bylo přepsáno na práci %s.'):format(safePlate, job), job)
    else
        TriggerClientEvent('jobvehicle:result', src, false, ('Vozidlo se SPZ %s nebylo nalezeno v databázi.'):format(safePlate))
    end
end)
