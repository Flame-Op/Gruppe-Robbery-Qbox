return {
    numRequiredPolice = 0, -- Minimum required police to activate mission
    activationCost = 500, -- How much is the activation of the mission (clean from the bank)
    missionCooldown = 2700 * 1000, -- Timer between missions in milliseconds

    -- Rewards Configuration
    minRewards = 2, -- Minimum number of different items to give
    maxRewards = 3, -- Maximum number of different items to give

    ---@class Reward
    ---@field item string
    ---@field minAmount? integer default 1
    ---@field maxAmount? integer default 1
    ---@field probability? number 0.0 to 1.0

    ---@type Reward[]
    rewards = {
        {
            item = 'black_money',
            minAmount = 250,
            maxAmount = 450,
            probability = 1.0
        },
        {
            item = 'security_card_01',
            minAmount = 1,
            maxAmount = 1,
            probability = 1.0
        },
        {
            item = 'goldbar',
            minAmount = 1,
            maxAmount = 3,
            probability = 1.0
        },
        {
            item = 'diamond',
            minAmount = 1,
            maxAmount = 5,
            probability = 1.0
        }

    },


    timeToDetonation = 5, -- Time in seconds until the bomb explodes after planting

    driverWeapon = `WEAPON_COMBATPISTOL`, -- Weapon of the driver
    passengerWeapon = `WEAPON_COMBATSHOTGUN`, -- Weapon of the front passenger
    backPassengerWeapon = `WEAPON_TACTICALRIFLE`, -- Weapon of the rear guards

    truckModel = `Stockade`, -- Model of the armored truck
    guardModel = `s_m_m_security_01`, -- Model of the guards

    -- Truck spawn locations (vector4)
    truckSpawns = {
        vec4(-281.05, -617.55, 33.35, 276.51),
        vec4(2.55, -671.9, 32.34, 181.81),
        vec4(-19.54, -672.65, 32.34, 183.36),
        vec4(-34.64, -674.35, 32.34, 177.9),
        vec4(147.24, -1081.15, 29.19, 1.6),
        vec4(-1187.67, -321.86, 37.61, 22.79),
        vec4(276.2, -172.81, 60.54, 70.45),
        vec4(255.49, 278.25, 105.59, 67.0)
    },

    -- Police alert logic
    alertPolice = function(src, coords)
        local msg = locale("info.alert_desc")
        local alertData = {
            title = locale('info.alert_title'),
            coords = {
                x = coords.x,
                y = coords.y,
                z = coords.z
            },
            description = msg
        }
        local numCops, copSrcs = exports.qbx_core:GetDutyCountType('leo')
        for i = 1, numCops do
            local copSrc = copSrcs[i]
            TriggerClientEvent('police:client:policeAlert', copSrc, coords, msg)
            TriggerClientEvent('qb-phone:client:addPoliceAlert', copSrc, alertData)
        end
    end,


}
