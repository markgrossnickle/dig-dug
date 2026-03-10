--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local DigDugConfig = require(ReplicatedStorage.Shared.DigDugConfig)
local StageLayouts = require(ReplicatedStorage.Shared.StageLayouts)

local COLS = DigDugConfig.GRID_COLUMNS
local ROWS = DigDugConfig.GRID_ROWS

type Enemy = {
	id: number,
	enemyType: string,
	col: number,
	row: number,
	direction: Vector2,
	inflateLevel: number,
	alive: boolean,
	moveTimer: number,
	deflateTimer: number,
	fireTimer: number,
	fireActive: boolean,
	isFleeing: boolean,
}

local EnemyService = Knit.CreateService({
	Name = "EnemyService",
	Client = {
		EnemySpawned = Knit.CreateSignal(),
		EnemyMoved = Knit.CreateSignal(),
		EnemyInflated = Knit.CreateSignal(),
		EnemyPopped = Knit.CreateSignal(),
		EnemyDefeated = Knit.CreateSignal(),
		EnemyChunkKilled = Knit.CreateSignal(),
		FygarFire = Knit.CreateSignal(),
		EnemyFleeing = Knit.CreateSignal(),
		AllEnemiesDefeated = Knit.CreateSignal(),
	},
})

EnemyService._enemies = {} :: { Enemy }
EnemyService._nextId = 1
EnemyService._heartbeatConn = nil :: RBXScriptConnection?
EnemyService._active = false
EnemyService._currentStage = 1
EnemyService._fleeTriggered = false
EnemyService.EnemyKilled = Signal.new()
EnemyService.AllDefeated = Signal.new()

function EnemyService:KnitInit() end

function EnemyService:KnitStart() end

-- Difficulty scaling
function EnemyService:_getEnemySpeed(): number
	local base = DigDugConfig.ENEMY_SPEED
	local bonus = math.floor((self._currentStage - 1) / 3) * 0.5
	return base + bonus
end

function EnemyService:_getFireCooldown(): number
	local base = 4
	local reduction = math.min(self._currentStage * 0.2, 2.5)
	return (base - reduction) + math.random() * 3
end

function EnemyService:SpawnEnemies(stage: number, player: Player)
	self._enemies = {}
	self._active = true
	self._currentStage = stage
	self._fleeTriggered = false

	local layout = StageLayouts.GetLayout(stage)
	if not layout then
		layout = StageLayouts.GenerateProceduralLayout(stage)
	end

	for _, spawn in layout.enemies do
		self:_spawnEnemy(spawn.enemyType, spawn.col, spawn.row, player)
	end

	self:_startAILoop(player)
end

function EnemyService:_spawnEnemy(enemyType: string, col: number, row: number, player: Player): Enemy
	local enemy: Enemy = {
		id = self._nextId,
		enemyType = enemyType,
		col = col,
		row = row,
		direction = DigDugConfig.Direction.LEFT,
		inflateLevel = 0,
		alive = true,
		moveTimer = 0,
		deflateTimer = 0,
		fireTimer = self:_getFireCooldown(),
		fireActive = false,
		isFleeing = false,
	}
	self._nextId += 1
	table.insert(self._enemies, enemy)
	self.Client.EnemySpawned:Fire(player, enemy.id, enemyType, col, row)
	return enemy
end

function EnemyService:_startAILoop(player: Player)
	if self._heartbeatConn then
		self._heartbeatConn:Disconnect()
	end

	self._heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		if not self._active then
			return
		end
		self:_updateEnemies(dt, player)
	end)
end

function EnemyService:StopAI()
	self._active = false
	if self._heartbeatConn then
		self._heartbeatConn:Disconnect()
		self._heartbeatConn = nil
	end
end

function EnemyService:_updateEnemies(dt: number, player: Player)
	local GridService = Knit.GetService("GridService")
	local PlayerService = Knit.GetService("PlayerService")
	local playerPos = PlayerService:GetPosition(player)
	if not playerPos then
		return
	end

	local aliveCount = 0
	for _, enemy in self._enemies do
		if enemy.alive then
			aliveCount += 1
		end
	end

	-- Trigger flee mode when 1 enemy remains
	if aliveCount == 1 and not self._fleeTriggered then
		self._fleeTriggered = true
		for _, enemy in self._enemies do
			if enemy.alive then
				enemy.isFleeing = true
				self.Client.EnemyFleeing:Fire(player, enemy.id)
				break
			end
		end
	end

	if aliveCount == 0 then
		self:StopAI()
		self.AllDefeated:Fire(player)
		self.Client.AllEnemiesDefeated:Fire(player)
		local GameService = Knit.GetService("GameService")
		GameService:OnStageClear(player)
		return
	end

	for _, enemy in self._enemies do
		if not enemy.alive then
			continue
		end

		-- Handle inflation/deflation
		if enemy.inflateLevel > 0 then
			enemy.deflateTimer += dt
			if enemy.deflateTimer >= DigDugConfig.PUMP_DEFLATE_TIME then
				enemy.deflateTimer = 0
				enemy.inflateLevel -= 1
				self.Client.EnemyInflated:Fire(player, enemy.id, enemy.inflateLevel)
			end
			continue -- don't move while inflated
		end

		-- Movement
		enemy.moveTimer += dt
		local speed = self:_getEnemySpeed()
		if enemy.isFleeing then
			speed = speed * 1.2
		end
		local moveInterval = 1 / speed

		if enemy.moveTimer >= moveInterval then
			enemy.moveTimer = 0

			if enemy.isFleeing then
				self:_moveFlee(enemy, GridService, player)
			else
				self:_moveChase(enemy, playerPos, GridService, player)
			end

			-- Fygar fire breathing (not while fleeing)
			if enemy.enemyType == DigDugConfig.EnemyType.FYGAR and not enemy.isFleeing then
				enemy.fireTimer -= moveInterval
				if enemy.fireTimer <= 0 then
					enemy.fireTimer = self:_getFireCooldown()
					if math.abs(enemy.direction.X) > 0 then
						local fireRange = 3
						local fireDir = enemy.direction.X
						self.Client.FygarFire:Fire(player, enemy.id, enemy.col, enemy.row, fireDir, fireRange)
						for fi = 1, fireRange do
							local fireCol = enemy.col + fireDir * fi
							-- Fire stops at water/sunk
							if not GridService:IsIsland(fireCol, enemy.row) then
								break
							end
							if fireCol == playerPos.X and enemy.row == playerPos.Y then
								local GameService = Knit.GetService("GameService")
								GameService:OnPlayerDied(player)
								self:StopAI()
								return
							end
						end
					end
				end
			end

			-- Check collision with player
			if not enemy.isFleeing then
				if enemy.col == playerPos.X and enemy.row == playerPos.Y then
					local GameService = Knit.GetService("GameService")
					GameService:OnPlayerDied(player)
					self:StopAI()
					return
				end
			end

			-- Fleeing enemy escapes at island edge (adjacent to water)
			if enemy.isFleeing and self:_isAtIslandEdge(enemy.col, enemy.row, GridService) then
				enemy.alive = false
				self.Client.EnemyDefeated:Fire(player, enemy.id)
				local remaining = 0
				for _, e in self._enemies do
					if e.alive then
						remaining += 1
					end
				end
				if remaining == 0 then
					self:StopAI()
					self.AllDefeated:Fire(player)
					self.Client.AllEnemiesDefeated:Fire(player)
					local GameService = Knit.GetService("GameService")
					GameService:OnStageClear(player)
					return
				end
			end
		end
	end
end

-- Free roaming: chase player on island surface
function EnemyService:_moveChase(enemy: Enemy, playerPos: Vector2, GridService: any, player: Player)
	local possibleDirs = {
		DigDugConfig.Direction.UP,
		DigDugConfig.Direction.DOWN,
		DigDugConfig.Direction.LEFT,
		DigDugConfig.Direction.RIGHT,
	}

	-- Sort by distance to player (closest first)
	table.sort(possibleDirs, function(a, b)
		local posA = Vector2.new(enemy.col + a.X, enemy.row + a.Y)
		local posB = Vector2.new(enemy.col + b.X, enemy.row + b.Y)
		local distA = (posA - playerPos).Magnitude
		local distB = (posB - playerPos).Magnitude
		return distA < distB
	end)

	for _, dir in possibleDirs do
		local newCol = enemy.col + dir.X
		local newRow = enemy.row + dir.Y

		-- Avoid reversing unless no other option
		if dir.X == -enemy.direction.X and dir.Y == -enemy.direction.Y then
			continue
		end

		-- Can only walk on island cells
		if GridService:IsIsland(newCol, newRow) then
			enemy.col = newCol
			enemy.row = newRow
			enemy.direction = dir
			self.Client.EnemyMoved:Fire(player, enemy.id, newCol, newRow)
			return
		end
	end

	-- If stuck, allow reversal
	local reverseDir = Vector2.new(-enemy.direction.X, -enemy.direction.Y)
	local newCol = enemy.col + reverseDir.X
	local newRow = enemy.row + reverseDir.Y
	if GridService:IsIsland(newCol, newRow) then
		enemy.col = newCol
		enemy.row = newRow
		enemy.direction = reverseDir
		self.Client.EnemyMoved:Fire(player, enemy.id, newCol, newRow)
	end
end

-- Flee toward nearest island edge
function EnemyService:_moveFlee(enemy: Enemy, GridService: any, player: Player)
	-- Find the nearest water-adjacent island cell
	local bestDir = nil
	local bestDist = math.huge

	local possibleDirs = {
		DigDugConfig.Direction.UP,
		DigDugConfig.Direction.DOWN,
		DigDugConfig.Direction.LEFT,
		DigDugConfig.Direction.RIGHT,
	}

	for _, dir in possibleDirs do
		local newCol = enemy.col + dir.X
		local newRow = enemy.row + dir.Y

		if not GridService:IsIsland(newCol, newRow) then
			continue
		end

		-- Prefer directions that bring us closer to water
		local distToEdge = self:_distanceToWater(newCol, newRow, GridService)
		if distToEdge < bestDist then
			bestDist = distToEdge
			bestDir = dir
		end
	end

	if bestDir then
		enemy.col = enemy.col + bestDir.X
		enemy.row = enemy.row + bestDir.Y
		enemy.direction = bestDir
		self.Client.EnemyMoved:Fire(player, enemy.id, enemy.col, enemy.row)
	end
end

function EnemyService:_distanceToWater(col: number, row: number, GridService: any): number
	-- Simple manhattan distance to nearest water cell
	local minDist = math.huge
	for dr = -5, 5 do
		for dc = -5, 5 do
			local c = col + dc
			local r = row + dr
			if GridService:IsWater(c, r) then
				local dist = math.abs(dc) + math.abs(dr)
				if dist < minDist then
					minDist = dist
				end
			end
		end
	end
	return minDist
end

function EnemyService:_isAtIslandEdge(col: number, row: number, GridService: any): boolean
	-- True if any adjacent cell is water
	return GridService:IsWater(col - 1, row)
		or GridService:IsWater(col + 1, row)
		or GridService:IsWater(col, row - 1)
		or GridService:IsWater(col, row + 1)
end

function EnemyService:InflateEnemy(enemyId: number, player: Player): boolean
	for _, enemy in self._enemies do
		if enemy.id == enemyId and enemy.alive then
			enemy.inflateLevel += 1
			enemy.deflateTimer = 0
			enemy.isFleeing = false
			self.Client.EnemyInflated:Fire(player, enemy.id, enemy.inflateLevel)

			if enemy.inflateLevel >= DigDugConfig.PUMP_POPS_REQUIRED then
				self:_killEnemy(enemy, player, false)
				return true
			end
			return false
		end
	end
	return false
end

function EnemyService:_killEnemy(enemy: Enemy, player: Player, chunkKill: boolean)
	enemy.alive = false
	if chunkKill then
		self.Client.EnemyChunkKilled:Fire(player, enemy.id)
	else
		self.Client.EnemyPopped:Fire(player, enemy.id)
	end

	if not chunkKill then
		local GameService = Knit.GetService("GameService")
		local points
		if enemy.enemyType == DigDugConfig.EnemyType.POOKA then
			points = DigDugConfig.Scoring.POOKA_PUMP
		else
			points = DigDugConfig.Scoring.FYGAR_PUMP
		end
		if enemy.isFleeing then
			points = points * 2
		end
		GameService:AddScore(player, points)
	end

	self.EnemyKilled:Fire(enemy, player, chunkKill)
end

-- Kill all enemies on the given sinking cells. Returns count killed.
function EnemyService:KillEnemiesInCells(cells: { { number } }, player: Player): number
	local killed = 0
	local cellSet: { [string]: boolean } = {}
	for _, cell in cells do
		cellSet[`{cell[1]}_{cell[2]}`] = true
	end

	for _, enemy in self._enemies do
		if enemy.alive then
			local key = `{enemy.col}_{enemy.row}`
			if cellSet[key] then
				self:_killEnemy(enemy, player, true)
				killed += 1
			end
		end
	end
	return killed
end

function EnemyService:GetEnemyAt(col: number, row: number): Enemy?
	for _, enemy in self._enemies do
		if enemy.alive and enemy.col == col and enemy.row == row then
			return enemy
		end
	end
	return nil
end

function EnemyService:GetEnemyInDirection(fromCol: number, fromRow: number, dir: Vector2, range: number): Enemy?
	local GridService = Knit.GetService("GridService")
	for i = 1, range do
		local checkCol = fromCol + dir.X * i
		local checkRow = fromRow + dir.Y * i
		local enemy = self:GetEnemyAt(checkCol, checkRow)
		if enemy then
			return enemy
		end
		-- LOS stops at water/sunk
		if not GridService:IsIsland(checkCol, checkRow) then
			break
		end
	end
	return nil
end

function EnemyService:GetAliveCount(): number
	local count = 0
	for _, enemy in self._enemies do
		if enemy.alive then
			count += 1
		end
	end
	return count
end

return EnemyService
