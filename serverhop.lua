--edited from this: https://github.com/AlternateYT/Roblox-Scripts/blob/main/Serverhop%20Module.lua
--chatgpt is the pog
--makes it so it actively searches for lowest playercount
local AllIDs = {}
local foundAnything = ""
local actualHour = os.date("!*t").hour
local Deleted = false
local S_T = game:GetService("TeleportService")
local S_H = game:GetService("HttpService")
local CurrentID = tostring(game.JobId)

local File = pcall(function()
	AllIDs = S_H:JSONDecode(readfile("server-hop-temp.json"))
end)

if not File then
	table.insert(AllIDs, actualHour)
	pcall(function()
		writefile("server-hop-temp.json", S_H:JSONEncode(AllIDs))
	end)
end

local function TPReturner(placeId, teleportSetting)
    local Site;
    if foundAnything == "" then
        Site = S_H:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. placeId .. '/servers/Public?sortOrder=Asc&limit=100'))
    else
        Site = S_H:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. placeId .. '/servers/Public?sortOrder=Asc&limit=100&cursor=' .. foundAnything))
    end
    local ID = ""
    local bestServer = nil
    local bestPlayerCount = math.huge
    local bestPing = math.huge
    if Site.nextPageCursor and Site.nextPageCursor ~= "null" and Site.nextPageCursor ~= nil then
        foundAnything = Site.nextPageCursor
    end
    for _, v in pairs(Site.data) do
        local Possible = true
        ID = tostring(v.id)
        if tonumber(v.maxPlayers) > #v.playerTokens and ID ~= CurrentID then
            for _, Existing in pairs(AllIDs) do
                if ID == tostring(Existing) then
                    Possible = false
                    break
                end
            end
            if Possible == true then
                local ping = v.ping
                if #v.playerTokens < bestPlayerCount or (#v.playerTokens == bestPlayerCount and ping < bestPing) then
                    bestServer = v.id
                    bestPlayerCount = #v.playerTokens
                    bestPing = ping
					print(bestPing)
                end
            end
        end
    end
    if bestServer then
        table.insert(AllIDs, bestServer)
        task.wait()
        pcall(function()
            writefile("server-hop-temp.json", S_H:JSONEncode(AllIDs))
            task.wait()
            if teleportSetting then
                S_T:TeleportToPlaceInstance(placeId, bestServer, game.Players.LocalPlayer, "", teleportSetting)
            else
                S_T:TeleportToPlaceInstance(placeId, bestServer, game.Players.LocalPlayer)
            end
        end)
        task.wait(4)
    end
end


local module = {}
function module:Hop(placeId, teleportSetting)
	while task.wait() do
		pcall(function()
            if not placeId then
                placeId = game.PlaceId
            end
            if teleportSetting then
				TPReturner(placeId, teleportSetting)
            else
                TPReturner(placeId)
            end
		end)
	end
end

return module
