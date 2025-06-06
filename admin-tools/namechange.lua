QBCore = exports['qb-core']:GetCoreObject()
if not Config or not Config.Webhooks then
    print("[ERROR] Config file not loaded properly!")
    return
end

RegisterCommand("changename", function(source, args, rawCommand)
    if source == 0 then
        if #args < 3 then
            print("[ERROR] Usage: changename [CitizenID] [First Name] [Last Name]")
            return
        end

        local citizenid = args[1]
        local firstName = args[2]
        local lastName = table.concat(args, " ", 3)

        ChangePlayerName(citizenid, firstName, lastName, "Console")
    else
        local src = source
        if #args < 3 then
            TriggerClientEvent('QBCore:Notify', src, "Usage: /changename [CitizenID] [First Name] [Last Name]", "error")
            return
        end

        local citizenid = args[1]
        local firstName = args[2]
        local lastName = table.concat(args, " ", 3)

        if not QBCore.Functions.HasPermission(src, "admin") then
            TriggerClientEvent('QBCore:Notify', src, "You do not have permission!", "error")
            return
        end

        ChangePlayerName(citizenid, firstName, lastName, src)
    end
end, false)

function ChangePlayerName(citizenid, firstName, lastName, adminSrc)
    local adminName = adminSrc == "Console" and "Server Console" or GetPlayerName(adminSrc)

    exports.oxmysql:execute("SELECT charinfo FROM players WHERE citizenid = ?", {citizenid}, function(charinfoResult)
        if not charinfoResult or #charinfoResult == 0 then
            if adminSrc == "Console" then
                print("[ERROR] CitizenID not found:", citizenid)
            else
                TriggerClientEvent('QBCore:Notify', adminSrc, "CitizenID not found!", "error")
            end
            return
        end

        local charinfo = json.decode(charinfoResult[1].charinfo)
        if not charinfo then
            if adminSrc == "Console" then
                print("[ERROR] Invalid charinfo for CitizenID:", citizenid)
            else
                TriggerClientEvent('QBCore:Notify', adminSrc, "Invalid charinfo data!", "error")
            end
            return
        end

        local oldFirstName = charinfo.firstname or "Unknown"
        local oldLastName = charinfo.lastname or "Unknown"

        charinfo.firstname = firstName
        charinfo.lastname = lastName
        local updatedCharinfo = json.encode(charinfo)

        exports.oxmysql:execute("UPDATE players SET charinfo = ? WHERE citizenid = ?", {updatedCharinfo, citizenid}, function(result)
            if result and result.affectedRows and result.affectedRows > 0 then
                if adminSrc == "Console" then
                    print("[SUCCESS] Name changed: " .. oldFirstName .. " " .. oldLastName .. " → " .. firstName .. " " .. lastName)
                else
                    TriggerClientEvent('QBCore:Notify', adminSrc, "Successfully changed name for " .. citizenid .. " to " .. firstName .. " " .. lastName, "success")
                end

                print("[QBCore] Admin " .. adminName .. " changed name of CitizenID " .. citizenid .. " from " .. oldFirstName .. " " .. oldLastName .. " to " .. firstName .. " " .. lastName)

                SendLogToDiscord(adminName, citizenid, oldFirstName, oldLastName, firstName, lastName, Config.Webhooks.NameChange)
            else
                if adminSrc == "Console" then
                    print("[ERROR] Failed to update database for CitizenID:", citizenid)
                else
                    TriggerClientEvent('QBCore:Notify', adminSrc, "Failed to update name in database!", "error")
                end
            end
        end)
    end)
end

function SendLogToDiscord(adminName, citizenid, oldFirstName, oldLastName, newFirstName, newLastName, webhook)
    local embedData = {
        {
            ["color"] = 16711680, -- 🔴 Red color
            ["title"] = "**✍️ Name Change Log**",
            ["description"] = "An admin changed a player's name.",
            ["fields"] = {
                {["name"] = "**Admin**", ["value"] = adminName, ["inline"] = true},
                {["name"] = "**CitizenID**", ["value"] = citizenid, ["inline"] = true},
                {["name"] = "**Old Name**", ["value"] = oldFirstName .. " " .. oldLastName, ["inline"] = true},
                {["name"] = "**New Name**", ["value"] = newFirstName .. " " .. newLastName, ["inline"] = true},
            },
            ["footer"] = {["text"] = "🔥Flame Name Change Logs"},
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }
    }

    PerformHttpRequest(webhook, function(err, text, headers) end, "POST", json.encode({
        username = "🔥Flame Name Change",
        avatar_url = Config.BotAvatarURL,
        embeds = embedData
    }), {["Content-Type"] = "application/json"})
end
