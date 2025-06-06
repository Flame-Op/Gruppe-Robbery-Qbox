local steamBlockWebhook = "https://discord.com/api/webhooks/1345622352716632087/v4Mw2XMOk-jMsr8rT0ke4SfAHujSARdDfrjQxRSp9fXWsaBZHBaawj_KVsQR8d7_lffY"

local checkInterval = 10000
local botName = "🔥Flame Steam Blocker"
local botAvatar = "https://r2.fivemanage.com/2YrPflDTgGWHfrkYg1rhi/images/Iconv1(500x500).png"
local icons = { Connecting = "🔍", Joined = "⚡", Blocked = "💀", Kicked = "⚠️" }

-- Function to send logs to Discord
function sendToDiscord(icon, title, description, color)
    local embedData = {
        {
            ["title"] = icon .. " " .. title,
            ["description"] = description,
            ["color"] = color,
            ["footer"] = { ["text"] = botName .. " • Made bY Flame🔥" },
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
    }

    PerformHttpRequest(steamBlockWebhook, function(err, text, headers) end, "POST", json.encode({
        username = botName,
        avatar_url = botAvatar,
        embeds = embedData
    }), { ["Content-Type"] = "application/json" })
end


-- Function to get detailed player info
function getPlayerDetails(src)
    local identifiers = GetPlayerIdentifiers(src)
    local details = {
        ["License"] = "N/A",
        ["Discord"] = "N/A",
        ["FiveM"] = "N/A",
        ["IP"] = "N/A",
        ["Xbox"] = "N/A",
        ["Live"] = "N/A"
    }

    for _, id in ipairs(identifiers) do
        if id:match("^license:") then details["License"] = id
        elseif id:match("^discord:") then details["Discord"] = "<@" .. id:gsub("discord:", "") .. ">"
        elseif id:match("^fivem:") then details["FiveM"] = id
        elseif id:match("^ip:") then details["IP"] = id:gsub("ip:", "")
        elseif id:match("^xbl:") then details["Xbox"] = id
        elseif id:match("^live:") then details["Live"] = id
        end
    end

    return details
end

-- Function to check if a player has Steam
function hasSteamIdentifier(src)
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:match("^steam:") then
            return true
        end
    end
    return false
end

-- Prevent Steam users from joining
AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(100)

    local playerDetails = getPlayerDetails(src)

    if hasSteamIdentifier(src) then
        -- print(icons.Blocked, "Blocking connection for:", name, "because Steam is open.")
        deferrals.done("🚫 You cannot join this server while using Steam. Please close Steam and try again.")

        sendToDiscord(
            icons.Blocked,
            "Connection Blocked",
            "**Player:** " .. name ..
            "\n**License:** " .. playerDetails["License"] ..
            "\n**Discord:** " .. playerDetails["Discord"] ..
            "\n**FiveM ID:** " .. playerDetails["FiveM"] ..
            "\n**IP Address:** ||" .. playerDetails["IP"] .. "||" ..
            "\n**Xbox ID:** " .. playerDetails["Xbox"] ..
            "\n**Live ID:** " .. playerDetails["Live"] ..
            "\n**Reason:** Tried to join with Steam open.",
            15158332
        )
    else
        -- print(icons.Joined, name, "is allowed to join (No Steam detected).")
        deferrals.done()

        sendToDiscord(
            icons.Joined,
            "Player Joined",
            "**Player:** " .. name ..
            "\n**License:** " .. playerDetails["License"] ..
            "\n**Discord:** " .. playerDetails["Discord"] ..
            "\n**FiveM ID:** " .. playerDetails["FiveM"] ..
            "\n**IP Address:** ||" .. playerDetails["IP"] .. "||" ..
            "\n**Xbox ID:** " .. playerDetails["Xbox"] ..
            "\n**Live ID:** " .. playerDetails["Live"] ..
            "\n**Status:** No Steam detected.",
            3066993
        )
    end
end)

-- Kick players if they open Steam after joining
CreateThread(function()
    while true do
        Wait(checkInterval)
        -- print(" Checking all players for Steam usage...")

        for _, playerId in ipairs(GetPlayers()) do
            local playerName = GetPlayerName(playerId)
            local playerDetails = getPlayerDetails(playerId)

            if hasSteamIdentifier(playerId) then
                print(icons.Kicked, "Kicking player:", playerName, "for opening Steam.")
                DropPlayer(playerId, "🚫 You cannot use Steam on this server. Please close Steam and try again.")

                sendToDiscord(
                    icons.Kicked,
                    "Player Kicked",
                    "**Player:** " .. playerName ..
                    "\n**License:** " .. playerDetails["License"] ..
                    "\n**Discord:** " .. playerDetails["Discord"] ..
                    "\n**FiveM ID:** " .. playerDetails["FiveM"] ..
                    "\n**IP Address:** ||" .. playerDetails["IP"] .. "||" ..
                    "\n**Xbox ID:** " .. playerDetails["Xbox"] ..
                    "\n**Live ID:** " .. playerDetails["Live"] ..
                    "\n**Reason:** Opened Steam after joining.",
                    15158332
                )
            else
                -- print("Player", playerName, "is not using Steam.")
            end
        end
    end
end)
