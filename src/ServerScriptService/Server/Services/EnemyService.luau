--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local DigDugConfig = require(ReplicatedStorage.Shared.DigDugConfig)

local COLS = DigDugConfig.GRID_COLUMNS
local ROWS = DigDugConfig.GRID_ROWS

type Enemy = {
	id: number,
	enemyType: string,
	col: number,
	row: number,
	direction: Vector2,
	inflateLevel: number, -- 0 = normal, 1-3 = inflating, 4 = popped
	isGhosting: boolean,
	ghostTarget: Vector2?,
	alive: boolean,
	moveTimer: number,
	deflateTimer: number,
	ghostTimer: number,
}

local EnemyService = Knit.CreateService({
	Name = "EnemyService",
	Client = {
		EnemySpawned = Knit.CreateSignal(),
		EnemyMoved = Knit.CreateSignal(),
		EnemyInflated = Knit.CreateSignal(),
		EnemyPopped = Knit.CreateSignal(),
		EnemyDefeated = Knit.CreateSignal(),
		EnemyCrushed = Knit.CreateSignal(),
		AllEnemiesDefeated = Knit.CreateSignal(),
	},
})

EnemyService._enemies = {} :: { Enemy }
EnemyService._nextId = 1
EnemyService._heartbeatConn = nil :: RBXScriptConnection?
EnemyService._active = false
EnemyService.EnemyKilled = Signal.new()
EnemyService.AllDefeated = Signal.new()

function EnemyService:KnitInit() end

function EnemyService:KnitStart() end

function EnemyService:SpawnEnemies(stage: number, player: Player)
	self._enemies = {}
	self._active = true

	local config = DigDugConfig.StageEnemies[math.min(stage, #DigDugConfig.StageEnemies)]
	local pookaCount = config[1]
	local fygarCount = config[2]

	-- Spawn Pookas in tunnels
	local spawnPositions = self:_getEnemySpawnPositions(pookaCount + fygarCount)

	for i = 1, pookaCount do
		local pos = spawnPositions[i]
		if pos then
			self:_spawnEnemy(DigDugConfig.EnemyType.POOKA, pos.X, pos.Y, player)
		end
	end

	for i = 1, fygarCount do
		local pos = spawnPositions[pookaCount + i]
		if pos then
			self:_spawnEnemy(DigDugConfig.EnemyType.FYGAR, pos.X, pos.Y, player)
		end
	end

	-- Start AI loop
	self:_startAILoop(player)
end

function EnemyService:_getEnemySpawnPositions(count: number): { Vector2 }
	local GridService = Knit.GetService("GridService")
	local positions = {} :: { Vector2 }

	-- Find tunnel cells away from player spawn
	local tunnelCells = {} :: { Vector2 }
	for row = 3, ROWS do
		for col = 1, COLS do
			if GridService:IsWalkable(col, row) then
				-- Not too close to player spawn
				local dist = math.abs(col - DigDugConfig.PLAYER_SPAWN.X) + math.abs(row - DigDugConfig.PLAYER_SPAWN.Y)
				if dist > 5 then
					table.insert(tunnelCells, Vector2.new(col, row))
				end
			end
		end
	end

	-- Pick random positions from available tunnel cells
	for _ = 1, count do
		if #tunnelCells > 0 then
			local idx = math.random(1, #tunnelCells)
			table.insert(positions, tunnelCells[idx])
			table.remove(tunnelCells, idx)
		else
			-- Fallback: place in lower area
			table.insert(positions, Vector2.new(math.random(2, COLS - 1), math.random(8, ROWS - 1)))
		end
	end

	return positions
end

function EnemyService:_spawnEnemy(enemyType: string, col: number, row: number, player: Player): Enemy
	local enemy: Enemy = {
		id = self._nextId,
		enemyType = enemyType,
		col = col,
		row = row,
		direction = DigDugConfig.Direction.LEFT,
		inflateLevel = 0,
		isGhosting = false,
		ghostTarget = nil,
		alive = true,
		moveTimer = 0,
		deflateTimer = 0,
		ghostTimer = DigDugConfig.GHOST_MODE_TIME + math.random() * 5,
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
		if not enemy.alive then
			continue
		end

		-- Handle inflation deflation
		if enemy.inflateLevel > 0 then
			enemy.deflateTimer += dt
			if enemy.deflateTimer >= DigDugConfig.PUMP_DEFLATE_TIME then
				enemy.deflateTimer = 0
				enemy.inflateLevel -= 1
				self.Client.EnemyInflated:Fire(player, enemy.id, enemy.inflateLevel)
			end
			aliveCount += 1
			continue -- don't move while inflated
		end

		aliveCount += 1

		-- Ghost timer
		enemy.ghostTimer -= dt
		if enemy.ghostTimer <= 0 and not enemy.isGhosting then
			enemy.isGhosting = true
			enemy.ghostTarget = playerPos
		end

		-- Movement
		enemy.moveTimer += dt
		local speed = if enemy.isGhosting then DigDugConfig.ENEMY_GHOST_SPEED else DigDugConfig.ENEMY_SPEED
		local moveInterval = 1 / speed

		if enemy.moveTimer >= moveInterval then
			enemy.moveTimer = 0

			if enemy.isGhosting then
				self:_moveGhost(enemy, playerPos, GridService, player)
			else
				self:_moveNormal(enemy, playerPos, GridService, player)
			end

			-- Check collision with player
			if enemy.col == math.floor(playerPos.X + 0.5) and enemy.row == math.floor(playerPos.Y + 0.5) then
				local GameService = Knit.GetService("GameService")
				GameService:OnPlayerDied(player)
				self:StopAI()
				return
			end
		end
	end

	if aliveCount == 0 then
		self:StopAI()
		self.AllDefeated:Fire(player)
		self.Client.AllEnemiesDefeated:Fire(player)
		local GameService = Knit.GetService("GameService")
		GameService:OnStageClear(player)
	end
end

function EnemyService:_moveNormal(enemy: Enemy, playerPos: Vector2, GridService: any, player: Player)
	-- Simple chase AI: try to move toward player through tunnels
	local possibleDirs = {
		DigDugConfig.Direction.UP,
		DigDugConfig.Direction.DOWN,
		DigDugConfig.Direction.LEFT,
		DigDugConfig.Direction.RIGHT,
	}

	-- Sort by distance to player
	table.sort(possibleDirs, function(a, b)
		local posA = Vector2.new(enemy.col + a.X, enemy.row + a.Y)
		local posB = Vector2.new(enemy.col + b.X, enemy.row + b.Y)
		local distA = (posA - playerPos).Magnitude
		local distB = (posB - playerPos).Magnitude
		return distA < distB
	end)

	-- Try each direction, prefer moving toward player
	for _, dir in possibleDirs do
		local newCol = enemy.col + dir.X
		local newRow = enemy.row + dir.Y

		-- Don't reverse direction unless no other option
		if dir.X == -enemy.direction.X and dir.Y == -enemy.direction.Y then
			continue
		end

		if GridService:IsWalkable(newCol, newRow) then
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
	if GridService:IsWalkable(newCol, newRow) then
		enemy.col = newCol
		enemy.row = newRow
		enemy.direction = reverseDir
		self.Client.EnemyMoved:Fire(player, enemy.id, newCol, newRow)
	end
end

function EnemyService:_moveGhost(enemy: Enemy, playerPos: Vector2, GridService: any, player: Player)
	-- Ghost mode: move directly toward player through walls
	local dx = playerPos.X - enemy.col
	local dy = playerPos.Y - enemy.row

	local dir
	if math.abs(dx) > math.abs(dy) then
		dir = Vector2.new(if dx > 0 then 1 else -1, 0)
	else
		dir = Vector2.new(0, if dy > 0 then 1 else -1)
	end

	local newCol = enemy.col + dir.X
	local newRow = enemy.row + dir.Y

	if newCol >= 1 and newCol <= COLS and newRow >= 1 and newRow <= ROWS then
		-- If we arrived at a walkable cell, stop ghosting
		if GridService:IsWalkable(newCol, newRow) then
			local distToPlayer = math.abs(newCol - playerPos.X) + math.abs(newRow - playerPos.Y)
			if distToPlayer <= 3 then
				enemy.isGhosting = false
				enemy.ghostTimer = DigDugConfig.GHOST_MODE_TIME + math.random() * 10
			end
		end

		enemy.col = newCol
		enemy.row = newRow
		enemy.direction = dir
		self.Client.EnemyMoved:Fire(player, enemy.id, newCol, newRow)
	end
end

function EnemyService:InflateEnemy(enemyId: number, player: Player): boolean
	for _, enemy in self._enemies do
		if enemy.id == enemyId and enemy.alive then
			enemy.inflateLevel += 1
			enemy.deflateTimer = 0
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

function EnemyService:_killEnemy(enemy: Enemy, player: Player, crushed: boolean)
	enemy.alive = false
	if crushed then
		self.Client.EnemyCrushed:Fire(player, enemy.id)
	else
		self.Client.EnemyPopped:Fire(player, enemy.id)
	end

	-- Score based on depth layer and enemy type
	local GridService = Knit.GetService("GridService")
	local layer = GridService:GetDepthLayer(enemy.row)
	local GameService = Knit.GetService("GameService")

	if not crushed then
		local scoreKey
		if enemy.enemyType == DigDugConfig.EnemyType.POOKA then
			scoreKey = "POOKA_LAYER_" .. tostring(layer)
		else
			scoreKey = "FYGAR_LAYER_" .. tostring(layer)
		end
		local points = DigDugConfig.Scoring[scoreKey] or 200
		GameService:AddScore(player, points)
	end

	self.EnemyKilled:Fire(enemy, player, crushed)
end

function EnemyService:CrushEnemiesAt(col: number, row: number, player: Player): number
	local crushed = 0
	for _, enemy in self._enemies do
		if enemy.alive and enemy.col == col and enemy.row == row then
			self:_killEnemy(enemy, player, true)
			crushed += 1
		end
	end
	return crushed
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
	for i = 1, range do
		local checkCol = fromCol + dir.X * i
		local checkRow = fromRow + dir.Y * i
		local enemy = self:GetEnemyAt(checkCol, checkRow)
		if enemy then
			return enemy
		end
		-- Stop at walls (unless enemy is in the way)
		local GridService = Knit.GetService("GridService")
		if not GridService:IsWalkable(checkCol, checkRow) and not GridService:IsDirt(checkCol, checkRow) then
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
