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
    local Site
    if foundAnything == "" then
        Site = S_H:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. placeId .. '/servers/Public?sortOrder=Asc&limit=100'))
    else
        Site = S_H:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. placeId .. '/servers/Public?sortOrder=Asc&limit=100&cursor=' .. foundAnything))
    end
    
    local bestServer = nil
    local minPlayers = math.huge
    
    for _, server in pairs(Site.data) do
        local id = tostring(server.id)
        local playing = #server.playerTokens
        local maxPlayers = tonumber(server.maxPlayers)
        if playing < maxPlayers and id ~= CurrentID then
            local visited = false
            for _, existingID in pairs(AllIDs) do
                if id == tostring(existingID) then
                    visited = true
                    break
                end
            end
            
            if not visited and playing < minPlayers then
                bestServer = server
                minPlayers = playing
				print(playing)
            end
        end
    end
    
    if bestServer then
        local id = tostring(bestServer.id)
        table.insert(AllIDs, id)
        
        pcall(function()
            writefile("server-hop-temp.json", S_H:JSONEncode(AllIDs))
        end)
        
        task.wait()
        
        if teleportSetting then
            S_T:TeleportToPlaceInstance(placeId, id, game.Players.LocalPlayer, "", teleportSetting)
        else
            S_T:TeleportToPlaceInstance(placeId, id, game.Players.LocalPlayer)
        end
        
        task.wait()
    end
    
    if Site.nextPageCursor and Site.nextPageCursor ~= "null" and Site.nextPageCursor ~= nil then
        foundAnything = Site.nextPageCursor
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
