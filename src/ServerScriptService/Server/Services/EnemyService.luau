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
	isGhosting: boolean,
	ghostTarget: Vector2?,
	alive: boolean,
	moveTimer: number,
	deflateTimer: number,
	ghostTimer: number,
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
		EnemyCrushed = Knit.CreateSignal(),
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

-- Difficulty scaling helpers
function EnemyService:_getEnemySpeed(): number
	local base = DigDugConfig.ENEMY_SPEED
	local bonus = math.floor((self._currentStage - 1) / 3) * 0.5
	return base + bonus
end

function EnemyService:_getGhostSpeed(): number
	local base = DigDugConfig.ENEMY_GHOST_SPEED
	local bonus = math.floor((self._currentStage - 1) / 3) * 0.3
	return base + bonus
end

function EnemyService:_getGhostCooldown(): number
	local base = DigDugConfig.GHOST_MODE_TIME
	local reduction = math.min(self._currentStage * 0.3, base * 0.6)
	return base - reduction + math.random() * 3
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
		isGhosting = false,
		ghostTarget = nil,
		alive = true,
		moveTimer = 0,
		deflateTimer = 0,
		ghostTimer = self:_getGhostCooldown(),
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
				enemy.isGhosting = false
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

		-- Ghost timer (not while fleeing)
		if not enemy.isFleeing then
			enemy.ghostTimer -= dt
			if enemy.ghostTimer <= 0 and not enemy.isGhosting then
				enemy.isGhosting = true
				enemy.ghostTarget = playerPos
			end
		end

		-- Movement
		enemy.moveTimer += dt
		local speed: number
		if enemy.isFleeing then
			speed = self:_getEnemySpeed() * 1.2
		elseif enemy.isGhosting then
			speed = self:_getGhostSpeed()
		else
			speed = self:_getEnemySpeed()
		end
		local moveInterval = 1 / speed

		if enemy.moveTimer >= moveInterval then
			enemy.moveTimer = 0

			if enemy.isFleeing then
				self:_moveFlee(enemy, GridService, player)
			elseif enemy.isGhosting then
				self:_moveGhost(enemy, playerPos, GridService, player)
			else
				self:_moveNormal(enemy, playerPos, GridService, player)
			end

			-- Fygar fire breathing (not while fleeing or ghosting)
			if enemy.enemyType == DigDugConfig.EnemyType.FYGAR and not enemy.isGhosting and not enemy.isFleeing then
				enemy.fireTimer -= moveInterval
				if enemy.fireTimer <= 0 then
					enemy.fireTimer = self:_getFireCooldown()
					if math.abs(enemy.direction.X) > 0 then
						local fireRange = 3
						local fireDir = enemy.direction.X
						self.Client.FygarFire:Fire(player, enemy.id, enemy.col, enemy.row, fireDir, fireRange)
						for fi = 1, fireRange do
							local fireCol = enemy.col + fireDir * fi
							if not GridService:IsWalkable(fireCol, enemy.row) then
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

			-- Check collision with player (not while fleeing)
			if not enemy.isFleeing then
				if enemy.col == playerPos.X and enemy.row == playerPos.Y then
					local GameService = Knit.GetService("GameService")
					GameService:OnPlayerDied(player)
					self:StopAI()
					return
				end
			end

			-- Fleeing enemy escapes at row 1
			if enemy.isFleeing and enemy.row <= 1 then
				enemy.alive = false
				self.Client.EnemyDefeated:Fire(player, enemy.id)
				-- Check if all defeated now
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

function EnemyService:_moveNormal(enemy: Enemy, playerPos: Vector2, GridService: any, player: Player)
	local possibleDirs = {
		DigDugConfig.Direction.UP,
		DigDugConfig.Direction.DOWN,
		DigDugConfig.Direction.LEFT,
		DigDugConfig.Direction.RIGHT,
	}

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
		if GridService:IsWalkable(newCol, newRow) then
			local distToPlayer = math.abs(newCol - playerPos.X) + math.abs(newRow - playerPos.Y)
			if distToPlayer <= 3 then
				enemy.isGhosting = false
				enemy.ghostTimer = self:_getGhostCooldown()
			end
		end

		enemy.col = newCol
		enemy.row = newRow
		enemy.direction = dir
		self.Client.EnemyMoved:Fire(player, enemy.id, newCol, newRow)
	end
end

function EnemyService:_moveFlee(enemy: Enemy, GridService: any, player: Player)
	-- Try to move upward through tunnels toward row 1
	-- Prefer up, then sideways toward nearest tunnel going up
	local fleeTarget = Vector2.new(enemy.col, 1) -- head toward surface

	local possibleDirs = {
		DigDugConfig.Direction.UP,
		DigDugConfig.Direction.LEFT,
		DigDugConfig.Direction.RIGHT,
		DigDugConfig.Direction.DOWN,
	}

	-- Sort by distance to surface (prefer upward)
	table.sort(possibleDirs, function(a, b)
		local posA = Vector2.new(enemy.col + a.X, enemy.row + a.Y)
		local posB = Vector2.new(enemy.col + b.X, enemy.row + b.Y)
		local distA = (posA - fleeTarget).Magnitude
		local distB = (posB - fleeTarget).Magnitude
		return distA < distB
	end)

	-- Try walkable path first
	for _, dir in possibleDirs do
		local newCol = enemy.col + dir.X
		local newRow = enemy.row + dir.Y

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

	-- If stuck in tunnels, ghost upward through dirt
	local upCol = enemy.col
	local upRow = enemy.row - 1
	if upRow >= 1 and upRow <= ROWS then
		enemy.col = upCol
		enemy.row = upRow
		enemy.direction = DigDugConfig.Direction.UP
		self.Client.EnemyMoved:Fire(player, enemy.id, upCol, upRow)
		return
	end

	-- Allow reversal as last resort
	local reverseDir = Vector2.new(-enemy.direction.X, -enemy.direction.Y)
	local newCol = enemy.col + reverseDir.X
	local newRow = enemy.row + reverseDir.Y
	if newCol >= 1 and newCol <= COLS and newRow >= 1 and newRow <= ROWS then
		enemy.col = newCol
		enemy.row = newRow
		enemy.direction = reverseDir
		self.Client.EnemyMoved:Fire(player, enemy.id, newCol, newRow)
	end
end

function EnemyService:InflateEnemy(enemyId: number, player: Player): boolean
	for _, enemy in self._enemies do
		if enemy.id == enemyId and enemy.alive then
			enemy.inflateLevel += 1
			enemy.deflateTimer = 0
			-- Stop fleeing if pumped
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

function EnemyService:_killEnemy(enemy: Enemy, player: Player, crushed: boolean)
	enemy.alive = false
	if crushed then
		self.Client.EnemyCrushed:Fire(player, enemy.id)
	else
		self.Client.EnemyPopped:Fire(player, enemy.id)
	end

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
		-- Bonus for killing fleeing enemy
		if enemy.isFleeing then
			points = points * 2
		end
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
	local GridService = Knit.GetService("GridService")
	for i = 1, range do
		local checkCol = fromCol + dir.X * i
		local checkRow = fromRow + dir.Y * i
		local enemy = self:GetEnemyAt(checkCol, checkRow)
		if enemy then
			return enemy
		end
		if not GridService:IsWalkable(checkCol, checkRow) then
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
