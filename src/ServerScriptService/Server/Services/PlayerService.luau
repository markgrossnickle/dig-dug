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
PlayerService.PlayerDigged = Signal.new()
PlayerService.PumpFired = Signal.new()

function PlayerService:KnitInit() end

function PlayerService:KnitStart()
	Players.PlayerRemoving:Connect(function(player)
		self._playerPositions[player] = nil
		self._playerDirections[player] = nil
		self._playerPumping[player] = nil
	end)
end

function PlayerService:SpawnPlayer(player: Player)
	local spawn = DigDugConfig.PLAYER_SPAWN
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

	-- Check for rocks
	if GridService:IsRock(newCol, newRow) then
		return
	end

	-- Dig if dirt
	if GridService:IsDirt(newCol, newRow) then
		GridService:DigCell(newCol, newRow)
		GameService:AddScore(player, DigDugConfig.Scoring.DIG_CELL)
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
