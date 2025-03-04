--================================--
--       FIRE SCRIPT v2.0.0       --
--  by GIMI (+ foregz, Albo1125)  --
--      License: GNU GPL 3.0      --
--================================--

--================================--
--         VERSION CHECK          --
--================================--

Version = GetResourceMetadata(GetCurrentResourceName(), "version")
LatestVersionFeed = "https://api.github.com/repos/gimicze/firescript/releases/latest"
local QBCore = exports['qb-core']:GetCoreObject()
Citizen.CreateThread(
	checkVersion
)

--================================--
--          INITIALIZE            --
--================================--

function onResourceStart(resourceName)
	if (GetCurrentResourceName() == resourceName) then
		Whitelist:load()
		Fire:loadScenarios()
		if Config.Fire.spawner.enableOnStartup and Config.Fire.spawner.interval then
			if not Fire:startSpawner() then
				sendMessage(0, "Couldn't start fire spawner.")
			end
		end
	end
end

RegisterNetEvent('onResourceStart')
AddEventHandler(
	'onResourceStart',
	onResourceStart
)

--================================--
--           CLEAN-UP             --
--================================--

function onPlayerDropped()
	Whitelist:removePlayer(source)
	Dispatch:unsubscribe(source)
end

RegisterNetEvent('playerDropped')
AddEventHandler(
	'playerDropped',
	onPlayerDropped
)

--================================--
--           COMMANDS             --
--================================--

RegisterNetEvent('fireManager:command:startfire')
AddEventHandler(
	'fireManager:command:startfire',
	function(coords, maxSpread, chance, triggerDispatch, dispatchMessage)
		if not Whitelist:isWhitelisted(source, "firescript.start") then
			sendMessage(source, "Insufficient permissions.")
			return
		end

		local _source = source

		local maxSpread = (maxSpread ~= nil and tonumber(maxSpread) ~= nil) and tonumber(maxSpread) or Config.Fire.maximumSpreads
		local chance = (chance ~= nil and tonumber(chance) ~= nil) and tonumber(chance) or Config.Fire.fireSpreadChance

		local fireIndex = Fire:create(coords, maxSpread, chance)

		sendMessage(source, "Spawned fire #" .. fireIndex)
		TriggerClientEvent('firescript:addBlip', -1, coords.x, coords.y, coords.z)

		if triggerDispatch then
			if Config.Dispatch.toneSources and type(Config.Dispatch.toneSources) == "table" then
				TriggerClientEvent('fireClient:playTone', -1)
			end
			
			Citizen.SetTimeout(
				Config.Dispatch.timeout,
				function()
					if Config.Dispatch.enabled and not Config.Dispatch.disableCalls then
						if dispatchMessage then
							Dispatch:create(dispatchMessage, coords)
							TriggerClientEvent('firescript:addBlip', -1, coords.x, coords.y, coords.z)

						else
							Dispatch.expectingInfo[_source] = true
							TriggerClientEvent('fd:dispatch', _source, coords)
							TriggerClientEvent('firescript:addBlip', -1, coords.x, coords.y, coords.z)

						end
					end
				end
			)
		end
	end
)

RegisterNetEvent('fireManager:command:registerscenario')
AddEventHandler(
	'fireManager:command:registerscenario',
	function(coords)
		if not Whitelist:isWhitelisted(source, "firescript.manage") then
			sendMessage(source, "Insufficient permissions.")
			return
		end

		local scenarioID = Fire:register(coords)

		sendMessage(source, "Created scenario #" .. scenarioID)
	end
)

RegisterNetEvent('fireManager:command:addflame')
AddEventHandler(
	'fireManager:command:addflame',
	function(scenarioID, coords, spread, chance)
		if not Whitelist:isWhitelisted(source, "firescript.manage") then
			sendMessage(source, "Insufficient permissions.")
			return
		end

		local scenarioID = tonumber(scenarioID)
		local spread = tonumber(spread)
		local chance = tonumber(chance)

		if not (coords and scenarioID and spread and chance) then
			return
		end

		local flameID = Fire:addFlame(scenarioID, coords, spread, chance)

		if not flameID then
			sendMessage(source, "No such scenario.")
			return
		end

		sendMessage(source, "Added flame #" .. flameID)
	end
)

RegisterCommand(
	'stopfire',
	function(source, args, rawCommand)
		if not Whitelist:isWhitelisted(source, "firescript.stop") then
			sendMessage(source, "Insufficient permissions.")
			return
		end

		local fireIndex = tonumber(args[1])

		if not fireIndex then
			return
		end

		if Fire:remove(fireIndex) then
			sendMessage(source, "Stopping fire #" .. fireIndex)
			TriggerClientEvent("pNotify:SendNotification", source, {
				text = "Fire " .. fireIndex .. " going out...",
				type = "info",
				timeout = 5000,
				layout = "centerRight",
				queue = "fire"
			})
		end
	end,
	false
)

RegisterCommand(
	'stopallfires',
	function(source, args, rawCommand)
		if not Whitelist:isWhitelisted(source, "firescript.stop") then
			sendMessage(source, "Insufficient permissions.")
			return
		end

		Fire:removeAll()

		sendMessage(source, "Stopping fires")
		TriggerClientEvent("pNotify:SendNotification", source, {
			text = "Fires going out...",
			type = "info",
			timeout = 5000,
			layout = "centerRight",
			queue = "fire"
		})
	end,
	false
)

RegisterCommand(
	'removeflame',
	function(source, args, rawCommand)
		if not Whitelist:isWhitelisted(source, "firescript.manage") then
			sendMessage(source, "Insufficient permissions.")
			return
		end

		local scenarioID = tonumber(args[1])
		local flameID = tonumber(args[2])

		if not (scenarioID and flameID) then
			return
		end

		local success = Fire:deleteFlame(scenarioID, flameID)

		if not success then
			sendMessage(source, "No such fire or flame registered.")
			return
		end

		sendMessage(source, "Removed flame #" .. flameID)
	end,
	false
)

RegisterCommand(
	'removescenario',
	function(source, args, rawCommand)
		if not Whitelist:isWhitelisted(source, "firescript.manage") then
			sendMessage(source, "Insufficient permissions.")
			return
		end
		local scenarioID = tonumber(args[1])
		if not scenarioID then
			return
		end

		local success = Fire:deleteScenario(scenarioID)

		if not success then
			sendMessage(source, "No such scenario.")
			return
		end

		sendMessage(source, "Removed scenario #" .. scenarioID)
	end,
	false
)

RegisterCommand(
	'startscenario',
	function(source, args, rawCommand)
		if not Whitelist:isWhitelisted(source, "firescript.start") then
			sendMessage(source, "Insufficient permissions.")
			return
		end
		
		local scenarioID = tonumber(args[1])
		local triggerDispatch = args[2] == "true"

		if not scenarioID then
			return
		end

		local success = Fire:startScenario(scenarioID, triggerDispatch, source)

		if not success then
			sendMessage(source, "No such scenario.")
			return
		end

		sendMessage(source, "Started scenario #" .. scenarioID)
	end,
	false
)

RegisterCommand(
	'stopscenario',
	function(source, args, rawCommand)
		if not Whitelist:isWhitelisted(source, "firescript.stop") then
			sendMessage(source, "Insufficient permissions.")
			return
		end
		local _source = source
		local scenarioID = tonumber(args[1])

		if not scenarioID then
			return
		end

		local success = Fire:stopScenario(scenarioID)

		if not success then
			sendMessage(source, "No such scenario active.")
			return
		end

		sendMessage(source, "Stopping scenario #" .. scenarioID)

		TriggerClientEvent("pNotify:SendNotification", source, {
			text = "Fire going out...",
			type = "info",
			timeout = 5000,
			layout = "centerRight",
			queue = "fire"
		})
	end,
	false
)

RegisterCommand(
	'firewl',
	function(source, args, rawCommand)
		local action = args[1]
		local serverId = tonumber(args[2])

		if not (action and serverId) or serverId < 1 then
			return
		end

		local identifier = GetPlayerIdentifier(serverId, 0)

		if not identifier then
			sendMessage(source, "Player not online.")
			return
		end

		if action == "add" then
			Whitelist:addPlayer(serverId, identifier)
			sendMessage(source, ("Added %s to the whitelist."):format(GetPlayerName(serverId)))
		elseif action == "remove" then
			Whitelist:removePlayer(serverId, identifier)
			sendMessage(source, ("Removed %s from the whitelist."):format(GetPlayerName(serverId)))
		else
			sendMessage(source, "Invalid action.")
		end
	end,
	true
)

RegisterCommand(
	'firewlreload',
	function(source, args, rawCommand)
		Whitelist:load()
		sendMessage(source, "Reloaded whitelist from config.")
	end,
	true
)

RegisterCommand(
	'firewlsave',
	function(source, args, rawCommand)
		Whitelist:save()
		sendMessage(source, "Saved whitelist.")
	end,
	true
)

RegisterCommand(
	'firedispatch',
	function(source, args, rawCommand)
		local action = args[1]
		local serverId = tonumber(args[2])

		if not (action and serverId) or serverId < 1 then
			return
		end

		if action == "scenario" then
			if not Fire.scenario[serverId] then
				sendMessage(source, "The specified scenario hasn't been found.")
				return
			end

			table.remove(args, 1)
			table.remove(args, 1)

			Fire.scenario[serverId].message = next(args) and table.concat(args, " ") or nil
			Fire:saveScenarios()
			sendMessage(source, ("Changed scenario's (#%s) dispatch message."):format(serverId))
		else
			local identifier = GetPlayerIdentifier(serverId, 0)

			if not identifier then
				sendMessage(source, "Player not online.")
				return
			end

			if action == "add" then
				Dispatch:subscribe(serverId, (not args[3] or args[3] ~= "false"))
				sendMessage(source, ("Subscribed %s to dispatch."):format(GetPlayerName(serverId)))
			elseif action == "remove" then
				Dispatch:unsubscribe(serverId, identifier)
				sendMessage(source, ("Unsubscribed %s from the dispatch."):format(GetPlayerName(serverId)))
			else
				sendMessage(source, "Invalid action.")
			end
		end
	end,
	true
)


local function randomfire3()
    -- Define the fixed list of fire locations
    local fireLocations = {
		{x = -365.425, y = -131.809, z = 37.873},
        {x = -2023.661, y = -1038.038, z = 5.577},
        {x = 3069.330, y = -4704.220, z = 15.043},
        {x = 2052.000, y = 3237.000, z = 1456.973},
        {x = -129.964, y = 8130.873, z = 6705.307},
        {x = 134.085, y = -637.859, z = 262.851},
        {x = 150.126, y = -754.591, z = 262.865},
        {x = -75.015, y = -818.215, z = 326.176},
        {x = 450.718, y = 5566.614, z = 806.183},
        {x = 24.775, y = 7644.102, z = 19.055},
        {x = 686.245, y = 577.950, z = 130.461},
        {x = 205.316, y = 1167.378, z = 227.005},
        {x = -20.004, y = -10.889, z = 500.602},
        {x = -438.804, y = 1076.097, z = 352.411},
        {x = -2243.810, y = 264.048, z = 174.615},
        {x = -3426.683, y = 967.738, z = 8.347},
        {x = -275.522, y = 6635.835, z = 7.425},
        {x = -1006.402, y = 6272.383, z = 1.503},
        {x = -517.869, y = 4425.284, z = 89.795},
        {x = -1170.841, y = 4926.646, z = 224.295},
        {x = -324.300, y = -1968.545, z = 67.002},
        {x = -1868.971, y = 2095.674, z = 139.115},
        {x = 2476.712, y = 3789.645, z = 41.226},
        {x = -2639.872, y = 1866.812, z = 160.135},
        {x = -595.342, y = 2086.008, z = 131.412},
        {x = 2208.777, y = 5578.235, z = 53.735},
        {x = 126.975, y = 3714.419, z = 46.827},
        {x = 2395.096, y = 3049.616, z = 60.053},
        {x = 2034.988, y = 2953.105, z = 74.602},
        {x = 2062.123, y = 2942.055, z = 47.431},
        {x = 2026.677, y = 1842.684, z = 133.313},
        {x = 1051.209, y = 2280.452, z = 89.727},
        {x = 736.153, y = 2583.143, z = 79.634},
        {x = 2954.196, y = 2783.410, z = 41.004},
        {x = 2732.931, y = 1577.540, z = 83.671},
        {x = 486.417, y = -3339.692, z = 6.070},
        {x = 899.678, y = -2882.191, z = 19.013},
        {x = -1850.127, y = -1231.751, z = 13.017},
        {x = -1475.234, y = 167.088, z = 55.841},
        {x = 3059.620, y = 5564.246, z = 197.091},
        {x = 2535.243, y = -383.799, z = 92.993},
        {x = 971.245, y = -1620.993, z = 30.111},
        {x = 293.089, y = 180.466, z = 104.301},
        {x = -1374.881, y = -1398.835, z = 6.141},
        {x = 718.341, y = -1218.714, z = 26.014},
        {x = 925.329, y = 46.152, z = 80.908},
        {x = -1696.866, y = 142.747, z = 64.372},
        {x = -543.932, y = -2225.543, z = 122.366},
        {x = 1660.369, y = -12.013, z = 170.020},
        {x = 2877.633, y = 5911.078, z = 369.624},
        {x = -889.655, y = -853.499, z = 20.566},
        {x = -695.025, y = 82.955, z = 55.855},
        {x = -1330.911, y = 340.871, z = 64.078},
        {x = 711.362, y = 1198.134, z = 348.526},
        {x = -1336.715, y = 59.051, z = 55.246},
        {x = -31.010, y = 6316.830, z = 40.083},
        {x = -635.463, y = -242.402, z = 38.175},
        {x = -3022.222, y = 39.968, z = 13.611},
        {x = -1659993, y = -128.399, z = 59.954},
        {x = -549.467, y = 5308.221, z = 114.146},
        {x = 1070.206, y = -711.958, z = 58.483},
        {x = 1608.698, y = 6438.096, z = 37.637},
        {x = 3430.155, y = 5174.196, z = 41.280}
    }

    -- Pick a random location from the array
    local location = fireLocations[math.random(#fireLocations)]

    -- Generate random spread and chance for fire (mimicking the random fire system)
    local maxSpread = math.random(10, 50)  -- Random spread between 10 and 50
    local spreadChance = math.random(1, 100)  -- Random chance between 1% and 100%

    -- Trigger the client event to start the fire at the selected location
    TriggerClientEvent('firescript:startRandomFire', -1, location.x, location.y, location.z, maxSpread, spreadChance)

    -- Create the blip at the fire location
    TriggerClientEvent('firescript:addBlip', -1, location.x, location.y, location.z)
	for _, playerId in ipairs(QBCore.Functions.GetPlayers()) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            local job = Player.PlayerData.job.name
            if job == "police" or job == "ambulance" or job == "fire" then
                TriggerClientEvent('QBCore:Notify', playerId, 
                    "🔥 Fire reported at [" .. location.x .. ", " .. location.y .. "]! Respond immediately!", 
                    "error", 
                    10000)
            end
        end
    end
    -- Set a timer to remove the blip after 5 minutes (300000 ms)
    Citizen.SetTimeout(300000, function()
        -- Trigger the event to remove the blip after 5 minutes
        TriggerClientEvent('firescript:removeBlip', -1, location.x, location.y, location.z)
    end)
end

-- Server-side: Automatically trigger the fire event every 20 minutes
Citizen.CreateThread(function()
    -- Initial fire trigger when the server starts
    randomfire3()

    -- Now run every 20 minutes (1200000 milliseconds)
    while true do
        Citizen.Wait(1200000)  -- Wait for 20 minutes (1200000 milliseconds)

        -- Trigger the random fire event by calling the function
        randomfire3()  -- This will start a fire at a random location
    end
end)

-- Optionally, if you still want the command, you can use it as a fallback trigger
RegisterCommand("randomfire3", function(source, args, rawCommand)
    randomfire3()  -- Trigger the random fire event manually
end)

-- Server-side: Automatically trigger the fire event every 20 minutes
Citizen.CreateThread(function()
    -- Initial fire trigger when the server starts
    randomfire3()

    -- Now run every 20 minutes (1200000 milliseconds)
    while true do
        Citizen.Wait(1200000)  -- Wait for 20 minutes (1200000 milliseconds)

        -- Trigger the random fire event by calling the function
        randomfire3()  -- This will start a fire at a random location
    end
end)

RegisterCommand("randomfire2", function(source, args, rawCommand)
    -- Define the fixed list of fire locations
    local fireLocations = {
        {x = -365.425, y = -131.809, z = 37.873},
        {x = -2023.661, y = -1038.038, z = 5.577},
        {x = 3069.330, y = -4704.220, z = 15.043},
        {x = 2052.000, y = 3237.000, z = 1456.973},
        {x = -129.964, y = 8130.873, z = 6705.307},
        {x = 134.085, y = -637.859, z = 262.851},
        {x = 150.126, y = -754.591, z = 262.865},
        {x = -75.015, y = -818.215, z = 326.176},
        {x = 450.718, y = 5566.614, z = 806.183},
        {x = 24.775, y = 7644.102, z = 19.055},
        {x = 686.245, y = 577.950, z = 130.461},
        {x = 205.316, y = 1167.378, z = 227.005},
        {x = -20.004, y = -10.889, z = 500.602},
        {x = -438.804, y = 1076.097, z = 352.411},
        {x = -2243.810, y = 264.048, z = 174.615},
        {x = -3426.683, y = 967.738, z = 8.347},
        {x = -275.522, y = 6635.835, z = 7.425},
        {x = -1006.402, y = 6272.383, z = 1.503},
        {x = -517.869, y = 4425.284, z = 89.795},
        {x = -1170.841, y = 4926.646, z = 224.295},
        {x = -324.300, y = -1968.545, z = 67.002},
        {x = -1868.971, y = 2095.674, z = 139.115},
        {x = 2476.712, y = 3789.645, z = 41.226},
        {x = -2639.872, y = 1866.812, z = 160.135},
        {x = -595.342, y = 2086.008, z = 131.412},
        {x = 2208.777, y = 5578.235, z = 53.735},
        {x = 126.975, y = 3714.419, z = 46.827},
        {x = 2395.096, y = 3049.616, z = 60.053},
        {x = 2034.988, y = 2953.105, z = 74.602},
        {x = 2062.123, y = 2942.055, z = 47.431},
        {x = 2026.677, y = 1842.684, z = 133.313},
        {x = 1051.209, y = 2280.452, z = 89.727},
        {x = 736.153, y = 2583.143, z = 79.634},
        {x = 2954.196, y = 2783.410, z = 41.004},
        {x = 2732.931, y = 1577.540, z = 83.671},
        {x = 486.417, y = -3339.692, z = 6.070},
        {x = 899.678, y = -2882.191, z = 19.013},
        {x = -1850.127, y = -1231.751, z = 13.017},
        {x = -1475.234, y = 167.088, z = 55.841},
        {x = 3059.620, y = 5564.246, z = 197.091},
        {x = 2535.243, y = -383.799, z = 92.993},
        {x = 971.245, y = -1620.993, z = 30.111},
        {x = 293.089, y = 180.466, z = 104.301},
        {x = -1374.881, y = -1398.835, z = 6.141},
        {x = 718.341, y = -1218.714, z = 26.014},
        {x = 925.329, y = 46.152, z = 80.908},
        {x = -1696.866, y = 142.747, z = 64.372},
        {x = -543.932, y = -2225.543, z = 122.366},
        {x = 1660.369, y = -12.013, z = 170.020},
        {x = 2877.633, y = 5911.078, z = 369.624},
        {x = -889.655, y = -853.499, z = 20.566},
        {x = -695.025, y = 82.955, z = 55.855},
        {x = -1330.911, y = 340.871, z = 64.078},
        {x = 711.362, y = 1198.134, z = 348.526},
        {x = -1336.715, y = 59.051, z = 55.246},
        {x = -31.010, y = 6316.830, z = 40.083},
        {x = -635.463, y = -242.402, z = 38.175},
        {x = -3022.222, y = 39.968, z = 13.611},
        {x = -1659993, y = -128.399, z = 59.954},
        {x = -549.467, y = 5308.221, z = 114.146},
        {x = 1070.206, y = -711.958, z = 58.483},
        {x = 1608.698, y = 6438.096, z = 37.637},
        {x = 3430.155, y = 5174.196, z = 41.280}
    }

    -- Pick a random fire location
    local fireLocation = fireLocations[math.random(1, #fireLocations)]

    -- Random spread and chance for the fire
    local spread = math.random(1, 100)  -- Adjust to your desired spread range
    local chance = math.random(1, 100)  -- Adjust to your desired chance range

    -- Trigger the fire event at the selected location with spread and chance
    TriggerClientEvent('firescript:startRandomFire', -1, fireLocation.x, fireLocation.y, fireLocation.z, spread, chance)
    TriggerClientEvent('firescript:addBlip', -1, fireLocation.x, fireLocation.y, fireLocation.z)

    print("🔥 Fire started at:", fireLocation.x, fireLocation.y, fireLocation.z, "Spread:", spread, "Chance:", chance)

    -- Notify all emergency services
    for _, playerId in ipairs(QBCore.Functions.GetPlayers()) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            local job = Player.PlayerData.job.name
            if job == "police" or job == "ambulance" or job == "fire" then
                TriggerClientEvent('QBCore:Notify', playerId, 
                    "🔥 Fire reported at [" .. fireLocation.x .. ", " .. fireLocation.y .. "]! Respond immediately!", 
                    "error", 
                    10000)
            end
        end
    end
end)

RegisterCommand(
	'randomfires',
	function(source, args, rawCommand)
		if not Whitelist:isWhitelisted(source, "firescript.manage") then
			sendMessage(source, "Insufficient permissions.")
			return
		end

		local _source = source
		local action = args[1]
		local scenarioID = tonumber(args[2])

		if not action then
			return
		end

		if action == "add" then
			if not scenarioID then
				sendMessage(source, "Invalid argument (2).")
				return
			end
			Fire:setRandom(scenarioID, true)
			sendMessage(source, ("Set scenario #%s to start randomly."):format(scenarioID))
		elseif action == "remove" then
			if not scenarioID then
				sendMessage(source, "Invalid argument (2).")
				return
			end
			Fire:setRandom(scenarioID, false)
			sendMessage(source, ("Set scenario #%s not to start randomly."):format(scenarioID))
		elseif action == "disable" then
			Fire:stopSpawner()
			sendMessage(source, "Disabled random fire spawn.")
		elseif action == "enable" then
			Fire:startSpawner()
			sendMessage(source, "Enabled random fire spawn.")
		else
			sendMessage(source, "Invalid action.")
		end
	end,
	false
)

RegisterCommand(
	'setscenariodifficulty',
	function(source, args, rawCommand)
		if not Whitelist:isWhitelisted(source, "firescript.manage") then
			sendMessage(source, "Insufficient permissions.")
			return
		end

		local scenarioID = tonumber(args[1])
		local difficulty = tonumber(args[2])

		if not scenarioID or not difficulty or difficulty < 0 then
			sendMessage(source, "Invalid argument")
			return
		end

		local message = Fire:setScenarioDifficulty(scenarioID, difficulty) and ("Scenario #%s set to difficulty %s"):format(scenarioID, difficulty) or ("Scenario #%s doesn't exist"):format(scenarioID)

		sendMessage(source, message)
	end
)

--================================--
--           FIRE SYNC            --
--================================--

RegisterNetEvent('fireManager:requestSync')
AddEventHandler(
	'fireManager:requestSync',
	function()
		if source > 0 then
			TriggerClientEvent('fireClient:synchronizeFlames', source, Fire.active)
		end
	end
)

RegisterNetEvent('fireManager:createFlame')
AddEventHandler(
	'fireManager:createFlame',
	function(fireIndex, coords)
		Fire:createFlame(fireIndex, coords)
	end
)

RegisterNetEvent('fireManager:createFire')
AddEventHandler('fireManager:createFire', function(coords, maxSpread, spreadChance, triggerDispatch, dispatchMessage)
    -- Debugging: Check the received coords and spread
    print(("Received fire at coords: x=%s, y=%s, z=%s"):format(coords.x, coords.y, coords.z))
    print(("Spread: %d, Chance: %d"):format(maxSpread, spreadChance))

    -- Ensure the coordinates are valid
    if coords == nil or coords.x == nil or coords.y == nil or coords.z == nil then
        print("Error: Invalid coordinates!")
        return
    end

    -- Ensure maxSpread and spreadChance are valid numbers
    maxSpread = (maxSpread ~= nil and tonumber(maxSpread) ~= nil) and tonumber(maxSpread) or Config.Fire.maximumSpreads
    spreadChance = (spreadChance ~= nil and tonumber(spreadChance) ~= nil) and tonumber(spreadChance) or Config.Fire.fireSpreadChance

    -- Debugging: Check if the fire creation method is valid
    if not Fire.create then
        print("Error: Fire.create method is missing or invalid.")
        return
    end

    -- Create the fire at the location
    local fireIndex = Fire:create(coords, maxSpread, spreadChance)

    -- If fire creation failed, log the error and stop
    if not fireIndex then
        print("Error: Fire was not created. Check the Fire:create() method.")
        return
    end

    -- Send a success message and create a blip
    sendMessage(source, "Spawned fire #" .. fireIndex)
    TriggerClientEvent('firescript:addBlip', -1, coords.x, coords.y, coords.z)

    -- Handle dispatch (if enabled)
    if triggerDispatch then
        if Config.Dispatch.toneSources and type(Config.Dispatch.toneSources) == "table" then
            TriggerClientEvent('fireClient:playTone', -1)
        end
        
        Citizen.SetTimeout(Config.Dispatch.timeout, function()
            if Config.Dispatch.enabled and not Config.Dispatch.disableCalls then
                if dispatchMessage then
                    Dispatch:create(dispatchMessage, coords)
                    TriggerClientEvent('firescript:addBlip', -1, coords.x, coords.y, coords.z)
                else
                    Dispatch.expectingInfo[source] = true
                    TriggerClientEvent('fd:dispatch', source, coords)
                    TriggerClientEvent('firescript:addBlip', -1, coords.x, coords.y, coords.z)
                end
            end
        end)
    end
end)


RegisterNetEvent('fireManager:removeFire')
AddEventHandler(
	'fireManager:removeFire',
	function(fireIndex)
		Fire:remove(fireIndex)
	end
)

RegisterNetEvent('fireManager:removeAllFires')
AddEventHandler(
	'fireManager:removeAllFires',
	function()
		Fire:removeAll()
	end
)

RegisterNetEvent('fireManager:removeFlame')
AddEventHandler(
	'fireManager:removeFlame',
	function(fireIndex, flameIndex)
		Fire:removeFlame(fireIndex, flameIndex)
	end
)

--================================--
--           DISPATCH             --
--================================--

RegisterNetEvent('fireDispatch:registerPlayer')
AddEventHandler(
	'fireDispatch:registerPlayer',
	function(playerSource, isFirefighter)
		source = tonumber(source)
		playerSource = tonumber(playerSource)
		if (source and source > 0) or not playerSource or playerSource < 0 then
			return
		end

		Dispatch:subscribe(playerSource, not (isFirefighter))
	end
)

RegisterNetEvent('fireDispatch:removePlayer')
AddEventHandler(
	'fireDispatch:removePlayer',
	function(playerSource)
		source = tonumber(source)
		playerSource = tonumber(playerSource)
		if (source and source > 0) or not playerSource or playerSource < 0 then
			return
		end

		Dispatch:subscribe(playerSource)
	end
)

RegisterNetEvent('fireDispatch:create')
AddEventHandler(
	'fireDispatch:create',
	function(text, coords)
		if not Config.Dispatch.disableCalls and (source < 1 or Dispatch.expectingInfo[source]) then
			Dispatch:create(text, coords)
			if source > 0 then
				Dispatch.expectingInfo[source] = nil
			end
		end
	end
)

--================================--
--          WHITELIST             --
--================================--

RegisterNetEvent('fireManager:checkWhitelist')
AddEventHandler(
	'fireManager:checkWhitelist',
	function(serverId)
		if serverId then
			source = tonumber(serverId) or source
		end

		Whitelist:check(source)
	end
)

--================================--
--         AUTO-SUBSCRIBE         --
--================================--

if Config.Dispatch.enabled then
	local allowedJobs = {}
	local firefighterJobs = {}

	if Config.Dispatch.enableFramework then
		if type(Config.Dispatch.jobs) == "table" then
			for k, v in pairs(Config.Dispatch.jobs) do
				allowedJobs[v] = true
			end
		else
			allowedJobs[Config.Dispatch.jobs] = true
		end

		firefighterJobs = Config.Fire.spawner.firefighterJobs or allowedJobs
	end

	if Config.Dispatch.enableFramework == 1 then
		ESX = exports["es_extended"]:getSharedObject()
	
		AddEventHandler(
			"esx:setJob",
			function(source)
				local xPlayer = ESX.GetPlayerFromId(source)
		
				if allowedJobs[xPlayer.job.name] then
					Dispatch:subscribe(source, firefighterJobs[xPlayer.job.name])
				else
					Dispatch:unsubscribe(source)
				end
			end
		)
		
		AddEventHandler(
			"esx:playerLoaded",
			function(source, xPlayer)
				if allowedJobs[xPlayer.job.name] then
					Dispatch:subscribe(source, firefighterJobs[xPlayer.job.name])
				else
					Dispatch:unsubscribe(source)
				end
			end
		)
	elseif Config.Dispatch.enableFramework == 2 then
		AddEventHandler(
			'QBCore:Server:PlayerLoaded',
			function(Player)
				if Player.PlayerData.job.onduty and allowedJobs[Player.PlayerData.job.name] then
					Dispatch:subscribe(Player.PlayerData.source, firefighterJobs[Player.PlayerData.job.name])
				end
			end
		)

		AddEventHandler(
			'QBCore:Server:OnJobUpdate',
			function(source, job)
				if allowedJobs[job.name] and job.onduty then
					Dispatch:subscribe(source, firefighterJobs[job.name])
				else
					Dispatch:unsubscribe(source)
				end
			end
		)

		AddEventHandler(
			'QBCore:Server:OnPlayerUnload',
			function(source)
				Dispatch:unsubscribe(source)
			end
		)
	end
end
