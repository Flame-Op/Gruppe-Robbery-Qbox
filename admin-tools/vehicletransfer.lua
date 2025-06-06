QBCore = exports['qb-core']:GetCoreObject()
if not Config or not Config.Webhooks then
    print("[ERROR] Config file not loaded properly!")
    return
end

RegisterCommand("transfercar", function(source, args)
    local plate = args[1]
    local toCID = args[2]

    if not plate or not toCID then
        return Notify(source, "Usage: /transfercar [Plate] [ToCitizenID]", "error")
    end

    if source > 0 and not QBCore.Functions.HasPermission(source, "admin") then
        return Notify(source, "You do not have permission!", "error")
    end

    -- 🔍 Fetch old owner details
    exports.oxmysql:execute("SELECT citizenid FROM player_vehicles WHERE plate = ?", {plate}, function(result)
        if not result[1] then
            return Notify(source, "Vehicle not found!", "error")
        end

        local fromCID = result[1].citizenid

        -- 🔍 Get old owner's name
        exports.oxmysql:execute("SELECT charinfo FROM players WHERE citizenid = ?", {fromCID}, function(fromResult)
            local oldOwnerName = "Unknown"
            if fromResult[1] then
                local charinfo = json.decode(fromResult[1].charinfo or "{}")
                oldOwnerName = (charinfo.firstname or "Unknown") .. " " .. (charinfo.lastname or "Unknown")
            end

            -- 🔍 Get new owner's name
            exports.oxmysql:execute("SELECT charinfo FROM players WHERE citizenid = ?", {toCID}, function(toResult)
                local newOwnerName = "Unknown"
                if toResult[1] then
                    local charinfo = json.decode(toResult[1].charinfo or "{}")
                    newOwnerName = (charinfo.firstname or "Unknown") .. " " .. (charinfo.lastname or "Unknown")
                end

                -- 🔄 Update ownership in database
                exports.oxmysql:execute("UPDATE player_vehicles SET citizenid = ? WHERE plate = ?", {toCID, plate}, function(updateResult)
                    if updateResult.affectedRows > 0 then
                        Notify(source, "Vehicle transferred successfully!", "success")
                        local adminName = GetAdminName(source)

                        -- ✅ Send proper log with both old and new owner names
                        SendVehicleTransferLog(adminName, fromCID, toCID, oldOwnerName, newOwnerName, plate)
                    else
                        Notify(source, "Failed to transfer vehicle!", "error")
                    end
                end)
            end)
        end)
    end)
end, false)


function SendVehicleTransferLog(adminName, fromCID, toCID, oldOwnerName, newOwnerName, plate)
    -- 🔍 Debugging to check if values are correct
    print("[DEBUG] Sending vehicle transfer log...")
    print("Admin:", adminName)
    print("From CID:", fromCID, "To CID:", toCID)
    print("Old Owner:", oldOwnerName, "New Owner:", newOwnerName)
    print("Plate:", plate)

    if not plate or not fromCID or not toCID or not oldOwnerName or not newOwnerName then
        print("[ERROR] Missing data! Vehicle transfer log not sent.")
        return
    end

    local embedData = {
        {
            ["color"] = 16776960, -- Yellow color
            ["title"] = "**🚗 Vehicle Transferred**",
            ["fields"] = {
                {["name"] = "**Admin**", ["value"] = adminName, ["inline"] = true},
                {["name"] = "**From CitizenID**", ["value"] = fromCID, ["inline"] = true},
                {["name"] = "**To CitizenID**", ["value"] = toCID, ["inline"] = true},
                {["name"] = "**Old Owner**", ["value"] = oldOwnerName, ["inline"] = true},
                {["name"] = "**New Owner**", ["value"] = newOwnerName, ["inline"] = true},
                {["name"] = "**Vehicle Plate**", ["value"] = plate, ["inline"] = false},
            },
            ["footer"] = {["text"] = "🔥Flame Vehicle Transfer Logs"},
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }
    }

    PerformHttpRequest(Config.Webhooks.VehicleTransfer, function(err, text, headers)
        print("[DEBUG] HTTP Response:", err, text)
    end, "POST", json.encode({
        username = "🔥Flame Vehicle Transfer ",
        avatar_url = Config.BotAvatarURL,
        embeds = embedData
    }), {["Content-Type"] = "application/json"})
end
