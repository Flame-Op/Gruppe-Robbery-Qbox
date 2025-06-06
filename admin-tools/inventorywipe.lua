QBCore = exports['qb-core']:GetCoreObject()
if not Config or not Config.Webhooks then
    print("[ERROR] Config file not loaded properly!")
    return
end

-- Config = Config or {}

RegisterCommand("wipeinventory", function(source, args)
    local targetCID = args[1]
    if not targetCID then return Notify(source, "Usage: /wipeinventory [CitizenID]", "error") end
    if source > 0 and not QBCore.Functions.HasPermission(source, "admin") then return Notify(source, "No permission!", "error") end

    exports.oxmysql:execute("SELECT citizenid, charinfo FROM players WHERE citizenid = ?", {targetCID}, function(result)
        if not result[1] then return Notify(source, "CitizenID not found!", "error") end

        local charinfo = json.decode(result[1].charinfo or "{}")
        local playerName = (charinfo.firstname or "Unknown") .. " " .. (charinfo.lastname or "Unknown")

        exports.oxmysql:execute("SELECT license FROM players WHERE citizenid = ? LIMIT 1", {targetCID}, function(licenseResult)
            local license = licenseResult[1] and licenseResult[1].license or "Unknown"

            exports.oxmysql:execute("UPDATE players SET inventory = '[]' WHERE citizenid = ?", {targetCID}, function(updateResult)
                if updateResult.affectedRows > 0 then
                    Notify(source, "Inventory wiped for: " .. playerName .. " (" .. targetCID .. ")", "success")
                    local adminName = GetAdminName(source)
                    SendInventoryWipeLog(adminName, playerName, targetCID, license) -- ✅ Fixed function call
                else
                    Notify(source, "Failed to wipe inventory!", "error")
                end
            end)
            
        end)
    end)
end, false)

-- ✅ Fix: Added missing Notify function
function Notify(src, msg, type)
    if src > 0 then
        TriggerClientEvent('QBCore:Notify', src, msg, type)
    else
        print(msg)
    end
end

function GetAdminName(src)
    return src > 0 and GetPlayerName(src) or "Console"
end

function SendInventoryWipeLog(adminName, playerName, citizenid, license)
    local embedData = {
        {
            ["color"] = 16711680, -- 🔴 Red color
            ["title"] = "**🧹 Inventory Wipe Log**",
            ["description"] = "An admin wiped a player's inventory.",
            ["fields"] = {
                {["name"] = "**Admin**", ["value"] = adminName, ["inline"] = true},
                {["name"] = "**Wiped Player**", ["value"] = playerName, ["inline"] = true},
                {["name"] = "**CitizenID**", ["value"] = citizenid, ["inline"] = true},
                {["name"] = "**License**", ["value"] = license, ["inline"] = true},
            },
            ["footer"] = {["text"] = "🔥Flame Inventory Wipe Logs"},
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }
    }

    -- 🚀 Send log to Discord
    PerformHttpRequest(Config.Webhooks.InventoryWipe, function(err, text, headers) end, "POST", json.encode({
        username = "🔥Flame Inventory Wipe",
        avatar_url = Config.BotAvatarURL,
        embeds = embedData
    }), {["Content-Type"] = "application/json"})
end

