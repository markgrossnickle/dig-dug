--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local DigDugConfig = require(ReplicatedStorage.Shared.DigDugConfig)

local COLS = DigDugConfig.GRID_COLUMNS
local ROWS = DigDugConfig.GRID_ROWS

local PlayerService = Knit.CreateService({
	Name = "PlayerService",
	Client = {
		PlayerMoved = Knit.CreateSignal(),
		PlayerDirectionChanged = Knit.CreateSignal(),
		PlayerSpawned = Knit.CreateSignal(),
		PumpStarted = Knit.CreateSignal(),
		PumpStopped = Knit.CreateSignal(),
	},
})

PlayerService._playerPositions = {} :: { [Player]: Vector2 }
PlayerService._playerDirections = {} :: { [Player]: Vector2 }
PlayerService._playerPumping = {} :: { [Player]: boolean }
PlayerService.PlayerMoved = Signal.new()
PlayerService.PumpFired = Signal.new()

function PlayerService:KnitInit() end

function PlayerService:KnitStart()
	Players.PlayerRemoving:Connect(function(player)
		self._playerPositions[player] = nil
		self._playerDirections[player] = nil
		self._playerPumping[player] = nil
	end)
end

function PlayerService:SpawnPlayer(player: Player, spawnPos: Vector2?)
	local spawn = spawnPos or DigDugConfig.PLAYER_SPAWN
	self._playerPositions[player] = Vector2.new(spawn.X, spawn.Y)
	self._playerDirections[player] = DigDugConfig.Direction.RIGHT
	self._playerPumping[player] = false
	self.Client.PlayerSpawned:FireAll(player, spawn.X, spawn.Y)
end

function PlayerService:GetPosition(player: Player): Vector2?
	return self._playerPositions[player]
end

function PlayerService:GetDirection(player: Player): Vector2?
	return self._playerDirections[player]
end

function PlayerService.Client:Move(player: Player, dirX: number, dirY: number)
	local GameService = Knit.GetService("GameService")
	if GameService:GetState(player) ~= GameService.State.PLAYING then
		return
	end

	local GridService = Knit.GetService("GridService")
	local pos = self.Server._playerPositions[player]
	if not pos then
		return
	end

	-- Normalize direction to cardinal
	local dir = Vector2.new(0, 0)
	if math.abs(dirX) > math.abs(dirY) then
		dir = Vector2.new(if dirX > 0 then 1 else -1, 0)
	elseif math.abs(dirY) > 0 then
		dir = Vector2.new(0, if dirY > 0 then 1 else -1)
	else
		return
	end

	self.Server._playerDirections[player] = dir

	local newCol = pos.X + dir.X
	local newRow = pos.Y + dir.Y

	-- Bounds check
	if newCol < 1 or newCol > COLS or newRow < 1 or newRow > ROWS then
		return
	end

	-- Can only walk on island cells
	if not GridService:IsIsland(newCol, newRow) then
		return
	end

	-- Check for fault between current cell and target cell — drill it if intact
	local faultState = GridService:GetFaultBetween(pos.X, pos.Y, newCol, newRow)
	if faultState == DigDugConfig.FaultState.INTACT then
		local drilled = GridService:DrillFault(pos.X, pos.Y, newCol, newRow)
		if drilled then
			GameService:AddScore(player, DigDugConfig.Scoring.DRILL_FAULT)
			-- Check for chunk breaks after drilling
			local sinkingCells = GridService:CheckChunks(player)
			if #sinkingCells > 0 then
				-- Check if player is on a sinking cell (they're still at old pos)
				-- Player hasn't moved yet, check destination too
				local playerOnSinking = false
				for _, cell in sinkingCells do
					if cell[1] == newCol and cell[2] == newRow then
						playerOnSinking = true
						break
					end
					if cell[1] == pos.X and cell[2] == pos.Y then
						playerOnSinking = true
						break
					end
				end

				-- Kill enemies on sinking cells
				local EnemyService = Knit.GetService("EnemyService")
				local killed = EnemyService:KillEnemiesInCells(sinkingCells, player)
				if killed > 0 then
					local scoreKey = "CHUNK_KILL_" .. tostring(math.min(killed, 5))
					local points = DigDugConfig.Scoring[scoreKey] or 1000
					GameService:AddScore(player, points)
				end

				if playerOnSinking then
					GameService:OnPlayerDied(player)
					return
				end
			end
		end
	end

	-- Move player
	self.Server._playerPositions[player] = Vector2.new(newCol, newRow)
	self.Server.Client.PlayerMoved:FireAll(player, newCol, newRow)
	self.Server.PlayerMoved:Fire(player, newCol, newRow)
end

function PlayerService.Client:StartPump(player: Player)
	local GameService = Knit.GetService("GameService")
	if GameService:GetState(player) ~= GameService.State.PLAYING then
		return
	end

	self.Server._playerPumping[player] = true
	self.Server.Client.PumpStarted:FireAll(player)
	self.Server.PumpFired:Fire(player)
end

function PlayerService.Client:StopPump(player: Player)
	self.Server._playerPumping[player] = false
	self.Server.Client.PumpStopped:FireAll(player)
end

function PlayerService:IsPumping(player: Player): boolean
	return self._playerPumping[player] == true
end

return PlayerService
