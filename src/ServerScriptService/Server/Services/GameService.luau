--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local DigDugConfig = require(ReplicatedStorage.Shared.DigDugConfig)

local GameService = Knit.CreateService({
	Name = "GameService",
	Client = {
		StageChanged = Knit.CreateSignal(),
		ScoreChanged = Knit.CreateSignal(),
		LivesChanged = Knit.CreateSignal(),
		GameStateChanged = Knit.CreateSignal(),
		PlayerDied = Knit.CreateSignal(),
		StageClear = Knit.CreateSignal(),
		GameOver = Knit.CreateSignal(),
	},
})

-- Game states
GameService.State = {
	WAITING = "Waiting",
	PLAYING = "Playing",
	DYING = "Dying",
	STAGE_CLEAR = "StageClear",
	GAME_OVER = "GameOver",
}

-- Per-player game data
GameService._playerData = {} :: {
	[Player]: {
		score: number,
		lives: number,
		stage: number,
		state: string,
		extraLifeAwarded: boolean,
		highScore: number,
	},
}

-- Signals
GameService.PlayerStateChanged = Signal.new()
GameService.StageStarted = Signal.new()

function GameService:KnitInit() end

function GameService:KnitStart()
	Players.PlayerAdded:Connect(function(player)
		self:_initPlayer(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._playerData[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		self:_initPlayer(player)
	end
end

function GameService:_initPlayer(player: Player)
	self._playerData[player] = {
		score = 0,
		lives = DigDugConfig.STARTING_LIVES,
		stage = 1,
		state = self.State.WAITING,
		extraLifeAwarded = false,
		highScore = 0,
	}
end

function GameService:StartGame(player: Player)
	local data = self._playerData[player]
	if not data then
		return
	end
	data.score = 0
	data.lives = DigDugConfig.STARTING_LIVES
	data.stage = 1
	data.state = self.State.PLAYING
	data.extraLifeAwarded = false

	self.Client.ScoreChanged:Fire(player, data.score)
	self.Client.LivesChanged:Fire(player, data.lives)
	self.Client.GameStateChanged:Fire(player, data.state)

	self:StartStage(player)
end

function GameService:StartStage(player: Player)
	local data = self._playerData[player]
	if not data then
		return
	end

	data.state = self.State.PLAYING

	-- Initialize grid for this stage
	local GridService = Knit.GetService("GridService")
	GridService:ResetGrid(data.stage)

	-- Spawn player
	local PlayerService = Knit.GetService("PlayerService")
	PlayerService:SpawnPlayer(player)

	-- Spawn enemies
	local EnemyService = Knit.GetService("EnemyService")
	EnemyService:SpawnEnemies(data.stage, player)

	-- Init rocks
	local RockService = Knit.GetService("RockService")
	RockService:InitRocks(player)

	self.Client.StageChanged:Fire(player, data.stage)
	self.Client.GameStateChanged:Fire(player, data.state)
	self.StageStarted:Fire(player, data.stage)
end

function GameService:AddScore(player: Player, points: number)
	local data = self._playerData[player]
	if not data then
		return
	end
	data.score += points
	self.Client.ScoreChanged:Fire(player, data.score)

	-- Check for extra life
	if not data.extraLifeAwarded and data.score >= DigDugConfig.EXTRA_LIFE_SCORE then
		data.extraLifeAwarded = true
		data.lives += 1
		self.Client.LivesChanged:Fire(player, data.lives)
	end
end

function GameService:OnPlayerDied(player: Player)
	local data = self._playerData[player]
	if not data or data.state ~= self.State.PLAYING then
		return
	end

	data.state = self.State.DYING
	data.lives -= 1

	local EnemyService = Knit.GetService("EnemyService")
	EnemyService:StopAI()
	local RockService = Knit.GetService("RockService")
	RockService:Stop()
	local PumpService = Knit.GetService("PumpService")
	PumpService:ClearAll()

	self.Client.LivesChanged:Fire(player, data.lives)
	self.Client.PlayerDied:Fire(player)
	self.Client.GameStateChanged:Fire(player, data.state)

	task.delay(DigDugConfig.DEATH_DELAY, function()
		if not self._playerData[player] then
			return
		end
		if data.lives <= 0 then
			self:OnGameOver(player)
		else
			self:StartStage(player)
		end
	end)
end

function GameService:OnStageClear(player: Player)
	local data = self._playerData[player]
	if not data then
		return
	end

	data.state = self.State.STAGE_CLEAR

	local RockService = Knit.GetService("RockService")
	RockService:Stop()
	local PumpService = Knit.GetService("PumpService")
	PumpService:ClearAll()

	self.Client.StageClear:Fire(player)
	self.Client.GameStateChanged:Fire(player, data.state)

	task.delay(DigDugConfig.STAGE_CLEAR_DELAY, function()
		if not self._playerData[player] then
			return
		end
		data.stage += 1
		self:StartStage(player)
	end)
end

function GameService:OnGameOver(player: Player)
	local data = self._playerData[player]
	if not data then
		return
	end

	data.state = self.State.GAME_OVER
	if data.score > data.highScore then
		data.highScore = data.score
	end
	self.Client.GameOver:Fire(player, data.score, data.highScore)
	self.Client.GameStateChanged:Fire(player, data.state)
end

function GameService:GetPlayerData(player: Player): { score: number, lives: number, stage: number, state: string }?
	return self._playerData[player]
end

function GameService:GetState(player: Player): string
	local data = self._playerData[player]
	return if data then data.state else self.State.WAITING
end

-- Client methods
function GameService.Client:GetScore(player: Player): number
	local data = self.Server._playerData[player]
	return if data then data.score else 0
end

function GameService.Client:GetLives(player: Player): number
	local data = self.Server._playerData[player]
	return if data then data.lives else 0
end

function GameService.Client:GetStage(player: Player): number
	local data = self.Server._playerData[player]
	return if data then data.stage else 1
end

function GameService.Client:GetState(player: Player): string
	return self.Server:GetState(player)
end

function GameService.Client:GetHighScore(player: Player): number
	local data = self.Server._playerData[player]
	return if data then data.highScore else 0
end

function GameService.Client:RequestStartGame(player: Player)
	self.Server:StartGame(player)
end

return GameService
