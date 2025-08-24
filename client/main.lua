---@diagnostic disable: undefined-global

local ox_lib = lib

local function showConfirmDialog(header, content)
    local result = lib.alertDialog({
        header = header or 'Potvrzení',
        content = content or 'Jste si jistý?',
        centered = true,
        cancel = true,
        size = 'sm',
        labels = {
            cancel = 'Zrušit',
            confirm = 'Potvrdit'
        }
    })
    return result == 'confirm'
end

local function getVehiclePlayerIsIn()
    local ped = cache and cache.ped or PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    -- try last vehicle
    veh = GetPlayersLastVehicle()
    if veh ~= 0 and #(GetEntityCoords(ped) - GetEntityCoords(veh)) < 5.0 then
        return veh
    end
    return 0
end

RegisterCommand('jobvehicle', function()
    local ped = cache and cache.ped or PlayerPedId()
    local veh = getVehiclePlayerIsIn()

    if veh == 0 then
        lib.notify({
            title = 'Job Vehicle',
            description = 'Nejsi ve vozidle (nebo poblíž posledního).',
            type = 'error'
        })
        return
    end

    if GetPedInVehicleSeat(veh, -1) ~= ped then
        lib.notify({
            title = 'Job Vehicle',
            description = 'Musíš sedět na místě řidiče.',
            type = 'error'
        })
        return
    end

    local plate = GetVehicleNumberPlateText(veh)
    plate = plate and plate:gsub('%s+', '') or 'N/A'

    -- ownership pre-check
    local isOwner = lib.callback.await('jobvehicle:isOwnerOfPlate', false, plate)
    if not isOwner then
        lib.notify({ title = 'Job Vehicle', description = 'Toto vozidlo nevlastníš.', type = 'error' })
        return
    end

    -- get player's job name from server to show in dialog
    local jobName = lib.callback.await('jobvehicle:getJobName', false)
    if not jobName or jobName == '' then
        lib.notify({ title = 'Job Vehicle', description = 'Nepodařilo se zjistit tvoji práci.', type = 'error' })
        return
    end
    local jobUpper = string.upper(jobName)

    local ok = showConfirmDialog('Přepsat vozidlo na práci?', (
        'SPZ: %s\n\nJsi si jistý, že chceš vozidlo přepsat na práci %s?'
    ):format(plate, jobUpper):gsub('\\n', '\n'))
    if not ok then
        lib.notify({ title = 'Job Vehicle', description = 'Akce zrušena.', type = 'inform' })
        return
    end

    -- freeze briefly to avoid drive-away
    FreezeEntityPosition(veh, true)
    SetTimeout(1500, function()
        FreezeEntityPosition(veh, false)
    end)

    TriggerServerEvent('jobvehicle:setVehicleJob', plate)
end, false)

RegisterKeyMapping('jobvehicle', 'Přepsat vozidlo na práci', 'keyboard', 'F9')

-- Server response handling
RegisterNetEvent('jobvehicle:result', function(success, message)
    lib.notify({
        title = 'Job Vehicle',
        description = message or (success and 'Hotovo.' or 'Chyba.'),
        type = success and 'success' or 'error'
    })
end)
