-- Optimized Doomspire Brickbattle Spawning System

-- Priority :

-- 1 : Spawn closest to an enemy in your base. (Multiple = Pick lowest.)
-- 2 : If one of our spawns is at an enemy base, spawn there.
-- 3 : Spawn closest to the bridge.

local respawnTime = 1
local players = game:GetService("Players")
local doomspires = workspace:WaitForChild("Doomspires")

local function getChrFloor(chr, tower : Model) -- Returns the floor a character is on.
	for _, floorHb in ipairs(tower.FloorHitboxes:GetChildren()) do
		for _, part in ipairs(workspace:GetPartsInPart(floorHb)) do
			if part.Parent == chr then
				return floorHb
			end
		end
	end
end

local function spawnAtChr(player : Player, target : Target) -- Get the spawn closest to a player.
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

local function getSpawn(player : Player) -- Get the best spawn for our player!
	local teamDoomspire = workspace.Doomspires[player.Team.Name]
	local teamSpawns = teamDoomspire.Spawns
	local tbl = {}
	local chosenChr = nil
	
	for _, enemy : Player in ipairs(players:GetPlayers()) do -- If theres an enemy in our base that isn't dead, insert them into an array.
		if player ~= enemy and enemy.Character ~= nil and enemy.Character:FindFirstChild("Humanoid") ~= nil and enemy.Character.Humanoid.Health > 0 and enemy.Team ~= player.Team then
			for _, part in ipairs(workspace:GetPartsInPart(teamDoomspire.Hitbox)) do
				if not table.find(tbl, enemy) and part.Parent == enemy.Character then
					table.insert(tbl, enemy)
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
			for _, spwn in ipairs(teamSpawns:GetChildren()) do
				if table.find(workspace:GetPartsInPart(enemyDs.Hitbox), spwn) then
					return spwn
				end
			end
		end
	end

	local floor1Spawns = {} -- No enemies were in our base & none of our spawns were at an enemies base.
	for _, possibleSpwn in ipairs(workspace:GetPartsInPart(teamDoomspire:WaitForChild("FloorHitboxes")["1"])) do -- Gather all spawns on the top floor.
		if possibleSpwn:IsA("SpawnLocation") then
			table.insert(floor1Spawns, possibleSpwn)
		end
	end

	if #floor1Spawns == 0 then -- If there are no spawns on the top floor, then gather all spawns into an array, otherwise just use the top floor spawns.
		tbl = {unpack(teamSpawns:GetChildren())}
	else 
		tbl = floor1Spawns
	end

	table.sort(tbl, function(a, b) -- Sort the array of spawns based on distance to the bridge.
		return ((a.Position - doomspires.Holder.Position).Magnitude) < ((b.Position - doomspires.Holder.Position).Magnitude)
	end)

	return tbl[1] -- Return the spawn cloest to the bridge!
end

local function setupSpawn(player)
	if player.Team.Name ~= "Spectators" then -- No spectators allowed to spawn in a base >:(
		player.RespawnLocation = getSpawn(player)
	else 
		player.RespawnLocation = workspace:WaitForChild("Lobby"):FindFirstChildOfClass("SpawnLocation")
	end	
end

players.PlayerAdded:Connect(function(player) -- Handles actually setting the spawnpoint of players.
	setupSpawn(player)
	
	player.CharacterAdded:Connect(function(chr)
		chr:WaitForChild("Humanoid").Died:Connect(function()
			setupSpawn(player)
			task.wait(respawnTime)
			player:LoadCharacter()
		end)
	end)
	
	task.wait(respawnTime)
	player:LoadCharacter()
end)
