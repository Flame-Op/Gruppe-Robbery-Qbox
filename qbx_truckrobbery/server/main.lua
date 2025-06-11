lib.locale()
local config = require 'config.server'
local sharedConfig = require 'config.shared'
local isMissionAvailable = true
local truck

RegisterNetEvent('qbx_truckrobbery:server:startMission', function()
    local src = source
    local player = exports.qbx_core:GetPlayer(src)

    if not isMissionAvailable then
        exports.qbx_core:Notify(src, locale('error.already_active'), 'error')
        return
    end

    if player.PlayerData.money.bank < config.activationCost then
        exports.qbx_core:Notify(src, locale('error.activation_cost', config.activationCost), 'error')
        return
    end

    local numCops = exports.qbx_core:GetDutyCountType('leo')
    if numCops < config.numRequiredPolice then
        exports.qbx_core:Notify(src, locale('error.active_police', config.numRequiredPolice), 'error')
        return
    end

    player.Functions.RemoveMoney('bank', config.activationCost, 'armored-truck')
    isMissionAvailable = false

    local coords = config.truckSpawns[math.random(#config.truckSpawns)]
    TriggerClientEvent('qbx_truckrobbery:client:missionStarted', src, coords)

    CreateThread(function()
        Wait(config.missionCooldown)
        isMissionAvailable = true
        truck = nil
        TriggerClientEvent('qbx_truckrobbery:client:missionEnded', -1)
    end)
end)

local function spawnGuardInSeat(seat, weapon)
    local coords = GetEntityCoords(truck)
    local guard = CreatePed(26, config.guardModel, coords.x, coords.y, coords.z, 0.0, true, false)

    lib.waitFor(function()
        return DoesEntityExist(guard)
    end, "guard does not exist")

    GiveWeaponToPed(guard, weapon, 250, false, true)
    for _ = 1, 50 do
        Wait(0)
        SetPedIntoVehicle(guard, truck, seat)
        if GetVehiclePedIsIn(guard, false) == truck then break end
    end

    Entity(guard).state:set('qbx_truckrobbery:initGuard', true, true)
end

lib.callback.register('qbx_truckrobbery:server:spawnVehicle', function(source, coords)
    local netId, veh = qbx.spawnVehicle({spawnSource = coords, model = config.truckModel})
    truck = veh

    SetVehicleDoorsLocked(truck, 2)
    local state = Entity(truck).state
    state:set('truckstate', TruckState.PLANTABLE, true)

    Wait(0)
    spawnGuardInSeat(-1, config.driverWeapon)
    spawnGuardInSeat(0, config.passengerWeapon)
    spawnGuardInSeat(1, config.backPassengerWeapon)
    spawnGuardInSeat(2, config.backPassengerWeapon)

    CreateThread(function()
        while true do
            if isMissionAvailable or state.truckstate == TruckState.LOOTED then return end
            if NetworkGetEntityOwner(truck) == -1 then
                DeleteEntity(truck)
                exports.qbx_core:Notify(source, locale('error.truck_escaped'), 'error')
                return
            end
            Wait(10000)
        end
    end)

    CreateThread(function()
        local closestPlayer
        while not closestPlayer do
            closestPlayer = lib.getClosestPlayer(GetEntityCoords(truck), 5)
            if isMissionAvailable or state.truckstate == TruckState.PLANTED then return end
            Wait(10000)
        end
        config.alertPolice(closestPlayer, coords)
    end)

    return netId
end)

RegisterNetEvent('qbx_truckrobbery:server:plantedBomb', function()
    local source = source
    if Entity(truck).state.truckstate ~= TruckState.PLANTABLE then return end

    if not exports.ox_inventory:RemoveItem(source, sharedConfig.bombItem, 1) then return end

    exports.qbx_core:Notify(source, locale('info.bomb_timer', config.timeToDetonation))
    Entity(truck).state:set('truckstate', TruckState.PLANTED, true)

    SetTimeout(config.timeToDetonation * 1000, function()
        SetVehicleDoorBroken(truck, 2, false)
        SetVehicleDoorBroken(truck, 3, false)
        ApplyForceToEntity(truck, 0, 20.0, 500.0, 0.0, 0.0, 0.0, 0.0, 1, false, true, true, false, true)
        Entity(truck).state:set('truckstate', TruckState.LOOTABLE, true)
    end)
end)

local function GetDiscord(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in ipairs(identifiers) do
        if string.find(id, "discord:") then
            local discordId = string.sub(id, 9)
            return "<@" .. discordId .. ">"  -- for tag link in Discord
        end
    end
    return "Not Linked"
end

-- ✅ Discord Logger
local webhookURL = 'https://discord.com/api/webhooks/1382041726058758225/T-7VnsO6nbnZKB_23X9KYxnVGviyQrMhRkmQ_Z4xLAg_iTTO2wA3oHO3sbMoE1-Z4qAu'

local function sendDiscordLog(title, description, color)
    PerformHttpRequest(webhookURL, function() end, 'POST', json.encode({
        username = "Flame's Truck Robbery 🔥",
        embeds = {{
            title = title,
            description = description,
            color = color or 16753920,
            footer = { text = os.date("📅 %Y-%m-%d 🕒 %H:%M:%S") }
        }},
        avatar_url = "https://media.discordapp.net/attachments/1326528694386298900/1326528929489752134/Icon_v1_1000x1000.png?ex=68438896&is=68423716&hm=584de18ab8b25852675357462a19de058e1688f302367489b3e10033a9ebf064&=&format=webp&quality=lossless&width=855&height=855"
    }), { ['Content-Type'] = 'application/json' })
end

local function logFlameTruckRobbery(message)
    print("[Flame's Truck Robbery] " .. message)
    sendDiscordLog("🚛 Truck Robbery Reward Log", message)
end

lib.callback.register('qbx_truckrobbery:server:giveReward', function(source)
    if Entity(truck).state.truckstate ~= TruckState.LOOTABLE then return end
    Entity(truck).state:set('truckstate', TruckState.LOOTED, true)

    local cantCarryRewards = {}
    local cantCarryRewardsSize = 0
    local givenCount, attempts = 0, 0
    local player = exports.qbx_core:GetPlayer(source)

    local charName = player and player.PlayerData.charinfo and (
        player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname
    ) or "Unknown"

    local playerName = GetPlayerName(source) or "Unknown"
    local discord = GetDiscord(source)

    local rewardLog = {}

    -- local rewardLog = {}

    while givenCount < 2 and attempts < 100 do
        attempts = attempts + 1
        local reward = config.rewards[math.random(#config.rewards)]
        if not reward.probability or math.random() <= reward.probability then
            local amount = math.random(reward.minAmount or 1, reward.maxAmount or 1)
            if exports.ox_inventory:CanCarryItem(source, reward.item, amount) then
                exports.ox_inventory:AddItem(source, reward.item, amount)
                givenCount = givenCount + 1
                table.insert(rewardLog, ("+%dx %s"):format(amount, reward.item))
            else
                cantCarryRewardsSize = cantCarryRewardsSize + 1
                cantCarryRewards[cantCarryRewardsSize] = {reward.item, amount}
                givenCount = givenCount + 1
                table.insert(rewardLog, ("(Dropped) %dx %s"):format(amount, reward.item))
            end
        end
    end

    for i = 1, #config.rewards do
        local reward = config.rewards[i]
        if not reward.probability or math.random() <= reward.probability then
            local amount = math.random(reward.minAmount or 1, reward.maxAmount or 1)
            if exports.ox_inventory:CanCarryItem(source, reward.item, amount) then
                exports.ox_inventory:AddItem(source, reward.item, amount)
                table.insert(rewardLog, ("+%dx %s"):format(amount, reward.item))
            else
                cantCarryRewardsSize = cantCarryRewardsSize + 1
                cantCarryRewards[cantCarryRewardsSize] = {reward.item, amount}
                table.insert(rewardLog, ("(Dropped) %dx %s"):format(amount, reward.item))
            end
        end
    end

    if cantCarryRewardsSize > 0 then
        exports.ox_inventory:CustomDrop('Loot', cantCarryRewards, GetEntityCoords(GetPlayerPed(source)))
    end

    exports.qbx_core:Notify(source, locale('success.looted'), 'success')
logFlameTruckRobbery((
    "**Player:** %s (%s)\n**Character:** %s\n**Discord:** %s\n**Looted:** %s"
):format(playerName, source, charName, discord, table.concat(rewardLog, ", ")))
    return true
end)
