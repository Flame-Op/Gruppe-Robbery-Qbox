QBCore = exports['qb-core']:GetCoreObject()
if not Config or not Config.Webhooks then
    print("[ERROR] Config file not loaded properly!")
    return
end

RegisterCommand("deletecar", function(source, args)
    local plate = args[1]
    if not plate then
        return Notify(source, "Usage: /deletecar [Plate]", "error")
    end

    if source > 0 and not QBCore.Functions.HasPermission(source, "admin") then
        return Notify(source, "You do not have permission!", "error")
    end

    exports.oxmysql:execute("SELECT citizenid FROM player_vehicles WHERE plate = ?", {plate}, function(result)
        if not result[1] then
            return Notify(source, "Vehicle not found!", "error")
        end

        local ownerCID = result[1].citizenid

        exports.oxmysql:execute("SELECT charinfo FROM players WHERE citizenid = ?", {ownerCID}, function(ownerResult)
            local ownerName = "Unknown"
            if ownerResult[1] then
                local charinfo = json.decode(ownerResult[1].charinfo or "{}")
                ownerName = (charinfo.firstname or "Unknown") .. " " .. (charinfo.lastname or "Unknown")
            end

            exports.oxmysql:execute("DELETE FROM player_vehicles WHERE plate = ?", {plate}, function(deleteResult)
                if deleteResult.affectedRows > 0 then
                    Notify(source, "Vehicle with plate [" .. plate .. "] deleted successfully!", "success")
                    local adminName = GetAdminName(source)
                    print("[SUCCESS] " .. adminName .. " deleted vehicle with plate [" .. plate .. "] owned by [" .. ownerName .. " | " .. ownerCID .. "]")

                    -- ✅ Make sure it calls `SendVehicleDeleteLog()` and NOT a transfer function
                    SendVehicleDeleteLog(adminName, plate, ownerName, ownerCID)
                else
                    Notify(source, "Failed to delete vehicle!", "error")
                end
            end)
        end)
    end)
end, false)

function Notify(src, msg, type)
    if src > 0 then
        TriggerClientEvent('QBCore:Notify', src, msg, type)
    else
        print(msg)
    end
end


function SendVehicleDeleteLog(adminName, plate, ownerName, citizenid)
    exports.oxmysql:execute("SELECT license FROM players WHERE citizenid = ? LIMIT 1", {citizenid}, function(result)
        local license = result and #result > 0 and result[1].license or "Unknown"

        local embedData = {
            {
                ["color"] = 16711680, 
                ["title"] = "**🚗💀 Vehicle Deleted**",
                ["fields"] = {
                    {["name"] = "**Admin**", ["value"] = adminName, ["inline"] = true},
                    {["name"] = "**Vehicle Plate**", ["value"] = plate, ["inline"] = true},
                    {["name"] = "**Owner Name**", ["value"] = ownerName, ["inline"] = true},
                    {["name"] = "**Owner CitizenID**", ["value"] = citizenid, ["inline"] = true},
                    {["name"] = "**License**", ["value"] = license, ["inline"] = true},
                },
                ["footer"] = {["text"] = "🔥Flame Vehicle Delete Logs"},
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }
        }

        PerformHttpRequest(Config.Webhooks.VehicleDelete, function() end, "POST", json.encode({
            username = "🔥Flame Vehicle Delete",
            avatar_url = Config.BotAvatarURL,
            embeds = embedData
        }), {["Content-Type"] = "application/json"})
    end)
end
