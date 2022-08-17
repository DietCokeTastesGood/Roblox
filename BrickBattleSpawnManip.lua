-- Optimized Doomspire Brickbattle Spawning System || https://www.roblox.com/games/10553011683/brickbattle-spawn-manipulation

-- Priority :

-- 1 : Spawn closest to an enemy in your base. (Multiple = Pick lowest.)
-- 2 : If one of our spawns is at an enemy base, spawn there.
-- 3 : Spawn closest to the bridge.

-- The reason the code is in a module script is because there was base game code with :LoadCharacter() in it, so that code now relies on this module.

-- MODULE SCRIPT:
local rngSpawn = {}

local respawnTime = 1
local players = game:GetService("Players")
local doomspires = workspace:WaitForChild("Doomspires")

local function getChrFloor(chr : Model, tower : Model) -- Returns the floor a character is on.
	for _, floorHb in ipairs(tower.FloorHitboxes:GetChildren()) do
		for _, part in ipairs(workspace:GetPartsInPart(floorHb)) do
			if part.Parent == chr then
				return floorHb
			end
		end
	end
end

local function spawnAtChr(player : Player, target : Player): SpawnLocation -- Get the spawn closest to a player.
	local teamDoomspire = workspace.Doomspires[player.Team.Name]
	local teamSpawns = teamDoomspire.Spawns

	local targetFloor = getChrFloor(target.Character, teamDoomspire)
	local floorSpwns = {}

	for _, part in ipairs(workspace:GetPartsInPart(targetFloor)) do -- Gather all spawns on the floor that the target is on.
		if part.Parent.Name == "Spawns" then
			table.insert(floorSpwns, part)
		end
	end

	local chosenChrPos = target.Character.HumanoidRootPart.Position -- Targets position (used for magnitude checks later)

	if #floorSpwns == 0 then -- If there aren't any spawns on the selected floor, make an array of all of them. (Otherwise, this array will just be spawns on the floor our target is on.)
		floorSpwns = {unpack(teamSpawns:GetChildren())}
	end

	table.sort(floorSpwns, function(a, b) -- Sort our spawn table based on distance from the spawn and target position.
		return ((a.Position - chosenChrPos).Magnitude) < ((b.Position - chosenChrPos).Magnitude)
	end)

	return floorSpwns[1] -- Return the closest spawn!
end

local function getSpawn(player : Player): SpawnLocation -- Get the best spawn for our player!
	local teamDoomspire = workspace.Doomspires[player.Team.Name]
	local teamSpawns = teamDoomspire.Spawns
	local tbl = {}
	local chosenChr = nil

	for _, enemy : Player in ipairs(players:GetPlayers()) do -- If theres an enemy in our base that isn't dead, insert them into an array.
		if player ~= enemy and enemy.Character ~= nil and enemy.Character:FindFirstChild("Humanoid") ~= nil and enemy.Character.Humanoid.Health > 0 and enemy.Team ~= player.Team then
			for _, floorHb in ipairs(teamDoomspire.FloorHitboxes:GetChildren()) do
				for _, part in ipairs(workspace:GetPartsInPart(floorHb)) do
					if not table.find(tbl, enemy) and part.Parent == enemy.Character then
						table.insert(tbl, enemy)
					end
				end
			end
		end
	end

	if #tbl ~= 0 then -- If the table of enemies in our base isn't empty then:
		if #tbl == 1 then
			return spawnAtChr(player, tbl[1]) -- ... only one enemy was found, get the closest spawn.
		else
			local lowestFloor, lowestEnemy = 1, nil -- ... there are multiple enemies in our base, get the lowest one.
			for _, enemy in ipairs(tbl) do
				local res = tonumber(getChrFloor(enemy.Character, teamDoomspire).Name)
				if res > lowestFloor then
					lowestFloor = res
					lowestEnemy = enemy
				end
			end
			return spawnAtChr(player, lowestEnemy)
		end
	end

	for _, enemyDs in ipairs(workspace.Doomspires:GetChildren()) do -- If there were no enemies in our base, check if any of our teams spawns are in someone elses base.
		if game:GetService("Teams"):FindFirstChild(enemyDs.Name) ~= nil and enemyDs.Name ~= player.Team.Name then
			for _, floorHb in ipairs(enemyDs.FloorHitboxes:GetChildren()) do
				for _, part in ipairs(workspace:GetPartsInPart(floorHb)) do
					if part.Parent == teamSpawns then
						return part
					end
				end
			end
		end
	end

	local floor1Spawns = {} -- No enemies were in our base & none of our spawns were at an enemies base.
	if teamDoomspire:WaitForChild("FloorHitboxes"):FindFirstChild("1") ~= nil then
		for _, possibleSpwn in ipairs(workspace:GetPartsInPart(teamDoomspire.FloorHitboxes["1"])) do -- Gather all spawns on the top floor.
			if possibleSpwn:IsA("SpawnLocation") then
				table.insert(floor1Spawns, possibleSpwn)
			end
		end
	end

	-- If there are no spawns on the top floor, then gather all spawns into an array, otherwise just use the top floor spawns.
	tbl = #floor1Spawns == 0 and {unpack(teamSpawns:GetChildren())} or floor1Spawns

	if doomspires:FindFirstChild("Holder") ~= nil then
		table.sort(tbl, function(a, b) -- Sort the array of spawns based on distance to the bridge.
			return ((a.Position - doomspires.Holder.Position).Magnitude) < ((b.Position - doomspires.Holder.Position).Magnitude)
		end)
	end

	return tbl[1] ~= nil and tbl[1] or workspace:WaitForChild("Lobby"):FindFirstChildOfClass("SpawnLocation") -- Return the spawn cloest to the bridge!
end

local function setupSpawn(player)
	if player.Team.Name ~= "Spectators" and doomspires:FindFirstChild(player.Team.Name) ~= nil and doomspires[player.Team.Name]:FindFirstChild("Spawns") ~= nil then -- No spectators allowed to spawn in a base >:(
		local strt = os.clock()
		player.RespawnLocation = getSpawn(player)
		warn(player.Name .. " -- " .. os.clock() - strt)
	else 
		player.RespawnLocation = workspace:WaitForChild("Lobby"):FindFirstChildOfClass("SpawnLocation")
	end	
	task.wait(respawnTime)
end

function rngSpawn.loadChr(player)
	setupSpawn(player)
	if player ~= nil then 
		player:LoadCharacter()
	end
end

return rngSpawn


--SERVER SCRIPT:
local rngMod = require(script:WaitForChild("SpawnPlayer"))
local players = game:GetService("Players")

players.PlayerAdded:Connect(function(player) -- Handles actually setting the spawnpoint of players.
	player.CharacterAdded:Connect(function(chr)
		chr:WaitForChild("Humanoid").Died:Connect(function()
			rngMod.loadChr(player)
		end)
	end)
	rngMod.loadChr(player)
end)
