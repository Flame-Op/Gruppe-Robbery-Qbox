local config = require 'config.client'
local sharedConfig = require 'config.shared'
local truckBlip
local truck
local area
local dealer
local c4Prop
local correctWire = nil
local isBombPlanted = false

Config = Config or {}
Config.Debug = true -- or false, depending on what you want


AddEventHandler('onResourceStop', function(resource)
	if resource ~= cache.resource then return end
	if dealer then
        exports.ox_target:removeLocalEntity(dealer)
        DeletePed(dealer)
    end
end)

local function resetMission()
    RemoveBlip(truckBlip)
    RemoveBlip(area)
end

RegisterNetEvent('qbx_truckrobbery:client:missionEnded', resetMission)

local function wireCutPuzzle()
    local wires = {
        { label = "Red Wire", value = "red" },
        { label = "Blue Wire", value = "blue" },
        { label = "Green Wire", value = "green" },
    }

    if not correctWire then
        lib.notify({ title = "Error", description = "Wire info missing!", type = "error" })
        return false
    end

    local choice = lib.inputDialog("Wire Cut Puzzle", {
        {
            type = "select",
            label = "Choose a wire to cut:",
            options = wires,
            required = true
        }
    })

    if not choice or not choice[1] then
        lib.notify({ title = "Cancelled", description = "You backed out!", type = "error" })
        return false
    end

    if choice[1] == correctWire then
        lib.notify({ title = "Success", description = "Correct wire cut!", type = "success" })
        return true
    else
        lib.notify({ title = "BOOM!", description = "Wrong wire! Truck exploded!", type = "error" })
        local coords = GetEntityCoords(truck)
        AddExplosion(coords.x, coords.y, coords.z, 'EXPLOSION_GRENADE', 1.5, true, false, 2.0)
        resetMission()
        return false
    end
end


local function lootTruck()
    if not wireCutPuzzle() then return end

    local looting = true
	CreateThread(function()
        if lib.progressBar({
            duration = config.lootDuration,
            label = locale('info.looting_truck'),
            useWhileDead = false,
            canCancel = true,
            disable = {
                move = true,
                car = true,
                combat = true,
                mouse = false,
            },
            anim = {
                dict = 'anim@heists@ornate_bank@grab_cash_heels',
                clip = 'grab',
                flag = 1,
            },
            prop = {
                model = `prop_cs_heist_bag_02`,
                bone = 57005,
                pos = vec3(0.0, 0.0, -0.16),
                rot = vec3(250.0, -30.0, 0.0),
            }
        }) then
            local success = lib.callback.await('qbx_truckrobbery:server:giveReward')
            if not success then return end

            -- 🧼 Remove loot interaction after successful looting
            exports.ox_target:removeLocalEntity(truck, 'transportTake')
            Entity(truck).state:set('truckstate', TruckState.LOOTED, true)

            SetPedComponentVariation(cache.ped, 5, 45, 0, 2)
            resetMission()

        end
        looting = false
    end)

    while looting do
        if #(GetEntityCoords(cache.ped) - GetEntityCoords(truck)) > 6 and lib.progressActive() then
            lib.cancelProgress()
        end
        Wait(1000)
    end
end


local function plantBomb()
	if not IsVehicleStopped(truck) then
		exports.qbx_core:Notify(locale('error.truck_moving'), 'error')
		return
	end
	if IsEntityInWater(cache.ped) then
		exports.qbx_core:Notify(locale('error.get_out_water'), 'error')
		return
	end
	local hasBomb = exports.ox_inventory:Search('count', sharedConfig.bombItem) > 0
	if not hasBomb then
		exports.qbx_core:Notify(locale('error.missing_bomb'), 'error')
		return
	end

	-- 🧩 Lights Out Mini-game
	local result = exports['lightsout']:StartLightsOut(4, 12)
	if not result then
		lib.notify({ title = "Failed", description = "You failed the Lights Out puzzle!", type = 'error' })
		if Config.Debug then print("Lights Out failed.") end
		return
	else
        if Config and Config.Debug then
            print("Debug message")
        end
    end

	TriggerEvent('ox_inventory:disarm', cache.playerId)
	Wait(500)

	if lib.progressBar({
		duration = 4000,
		label = locale('info.planting_bomb'),
		useWhileDead = false,
		canCancel = true,
		disable = { move = true, car = true, combat = true },
		anim = {
			dict = 'anim@heists@ornate_bank@thermal_charge_heels',
			clip = 'thermal_charge',
			flag = 16,
		},
		prop = {
			model = `prop_c4_final_green`,
			pos = vec3(0.06, 0.0, 0.06),
			rot = vec3(90.0, 0.0, 0.0),
		}
	}) then
		if Entity(truck).state.truckstate ~= TruckState.PLANTABLE then return end
        isBombPlanted = true

        lib.showTextUI("[G] Detonate Bomb", {
            position = "right-center",
            icon = "bomb",
            style = {
                borderRadius = 8,
                backgroundColor = '#990000',
                color = 'white'
            }
        })
        exports.qbx_core:Notify("The bomb is planted. Press [G] to detonate.", "inform")
            end
end

CreateThread(function()
    while true do
        Wait(0)
        if isBombPlanted and IsControlJustReleased(0, 47) then -- G key
            isBombPlanted = false
            lib.hideTextUI()

            local coords = GetEntityCoords(truck)
            AddExplosion(coords.x, coords.y, coords.z, 'EXPLOSION_TANKER', 2.0, true, false, 2.0)

            TriggerServerEvent('qbx_truckrobbery:server:detonated')
            -- Set truck state to LOOTABLE manually if needed:
            Entity(truck).state:set('truckstate', TruckState.LOOTABLE, true)
        end
    end
end)


RegisterNetEvent('qbx_truckrobbery:client:missionStarted', function(vehicleSpawnCoords)
	exports.qbx_core:Notify('Go to the designated location to find the bank truck')
	config.emailNotification()

	area = AddBlipForRadius(vehicleSpawnCoords.x, vehicleSpawnCoords.y, vehicleSpawnCoords.z, 250.0)
	SetBlipHighDetail(area, true)
	SetBlipAlpha(area, 90)
	SetBlipRoute(area, true)
	SetBlipRouteColour(area, config.routeColor)
	SetBlipColour(area, 1)

	local point = lib.points.new({
		coords = vehicleSpawnCoords,
		distance = 250,
	})

	function point:onEnter()
		local netId = lib.callback.await('qbx_truckrobbery:server:spawnVehicle', false, vehicleSpawnCoords)
		lib.waitFor(function()
			if NetworkDoesEntityExistWithNetworkId(netId) then
				truck = NetToVeh(netId)
				return truck
			end
		end, locale('error.no_truck_spawned'))

		exports.qbx_core:Notify(locale('info.truck_spotted'), 'inform')
		RemoveBlip(area)

		truckBlip = AddBlipForEntity(truck)
		SetBlipSprite(truckBlip, 67)
		SetBlipColour(truckBlip, 1)
		SetBlipFlashes(truckBlip, true)
		SetBlipRoute(truckBlip, true)
		SetBlipRouteColour(truckBlip, config.routeColor)
		BeginTextCommandSetBlipName('STRING')
		AddTextComponentString('Armored Truck')
		EndTextCommandSetBlipName(truckBlip)
		PlaySoundFrontend(-1, 'Mission_Pass_Notify', 'DLC_HEISTS_GENERAL_FRONTEND_SOUNDS', false)
		point:remove()
	end
end)

qbx.entityStateHandler('truckstate', function(entity, _, value)
	if entity == 0 then return end
    truck = entity
    if value == TruckState.PLANTABLE then
        exports.ox_target:addLocalEntity(truck, {
            name = 'transportPlant',
            label = locale('info.plant_bomb'),
            icon = 'fas fa-bomb',
            canInteract = function()
                return QBX.PlayerData.job.type ~= 'leo'
            end,
			bones = {
				'seat_dside_r',
				'seat_pside_r',
			},
            onSelect = plantBomb,
            distance = 3.0,
        })
    elseif value == TruckState.PLANTED then
        exports.ox_target:removeLocalEntity(truck, 'transportPlant')
		local coords = GetEntityCoords(cache.ped)
		c4Prop = CreateObject(`prop_c4_final_green`, coords.x, coords.y, coords.z + 0.2,  false, false, true)
		AttachEntityToEntity(c4Prop, truck, GetEntityBoneIndexByName(truck, 'door_pside_r'), -0.7, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
		while DoesEntityExist(c4Prop) do
			if not DoesEntityExist(truck) then
				DeleteObject(c4Prop)
				return
			end

			qbx.playAudio({
				audioName = 'IDLE_BEEP',
				audioRef = 'EPSILONISM_04_SOUNDSET',
				audioSource = c4Prop
			})
			Wait(1000)
		end
    elseif value == TruckState.LOOTABLE then
        -- 🔧 Clean up any bomb-related props or target entries
        exports.ox_target:removeLocalEntity(truck, 'transportPlant')

        if c4Prop and DoesEntityExist(c4Prop) then
            DeleteObject(c4Prop)
        end
        if Entity(truck).state.truckstate == TruckState.PLANTED then
            local transCoords = GetEntityCoords(truck)
            AddExplosion(transCoords.x, transCoords.y, transCoords.z, 'EXPLOSION_TANKER', 2.0, true, false, 2.0)
        end

        -- 🔓 Add loot interaction
        exports.ox_target:addLocalEntity(truck, {
            name = 'transportTake',
            label = locale('info.loot_truck'),
            icon = 'fas fa-sack-dollar',
            canInteract = function()
                return QBX.PlayerData.job.type ~= 'leo'
            end,
            bones = {
                'seat_dside_r',
                'seat_pside_r',
            },
            onSelect = lootTruck,
            distance = 3.0,
        })

    -- elseif value == TruckState.LOOTED then
	-- 	exports.ox_target:removeLocalEntity(truck, 'transportTake')
    end
end)

qbx.entityStateHandler('qbx_truckrobbery:initGuard', function(entity, _, value)
	if not value then return end
	while GetVehiclePedIsIn(entity, false) == 0 do
		Wait(100)
	end
    if NetworkGetEntityOwner(entity) ~= cache.playerId then return end

	SetPedFleeAttributes(entity, 0, false)
	SetPedCombatAttributes(entity, 46, true)
	SetPedCombatAbility(entity, 100)
	SetPedCombatMovement(entity, 2)
	SetPedCombatRange(entity, 2)
	SetPedKeepTask(entity, true)
	SetPedAsCop(entity, true)
	SetPedCanSwitchWeapon(entity, true)
    SetPedDropsWeaponsWhenDead(entity, false)
	SetPedAccuracy(entity, config.guardAccuracy)
	TaskVehicleDriveWander(entity, truck, 60.0, 524860)
	Entity(entity).state:set('qbx_truckrobbery:initGuard', false, true)
end)

local dealerPos = lib.points.new({
    coords = config.dealerCoords.xyz,
    distance = 400,
})

function dealerPos:onEnter()
    lib.requestModel(config.dealerModel, 10000)
    dealer = CreatePed(26, config.dealerModel, config.dealerCoords.x, config.dealerCoords.y, config.dealerCoords.z, config.dealerCoords.w, false, false)
    SetModelAsNoLongerNeeded(config.dealerModel)
    TaskStartScenarioInPlace(dealer, 'WORLD_HUMAN_AA_SMOKE', 0, false)
    SetEntityInvincible(dealer, true)
    SetBlockingOfNonTemporaryEvents(dealer, true)
    FreezeEntityPosition(dealer, true)

    exports.ox_target:addLocalEntity(dealer, {
        name = 'dealer',
        label = locale('mission.ask_for_mission'),
        icon = 'fas fa-truck-fast',
        canInteract = function()
            return QBX.PlayerData.job.type ~= 'leo'
        end,
        onSelect = function()
            local wires = { "red", "blue", "green" }
            correctWire = wires[math.random(1, #wires)]
            exports.qbx_core:Notify("Dealer whispers: Cut the " .. correctWire:upper() .. " wire when the time comes.", "inform", 10000)
            TriggerServerEvent('qbx_truckrobbery:server:startMission')
        end,
        distance = 3.0,
    })
end

function dealerPos:onExit()
    exports.ox_target:removeLocalEntity(dealer)
    DeletePed(dealer)
    dealer = nil
end
