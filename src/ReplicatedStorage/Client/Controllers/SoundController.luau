--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local DigDugConfig = require(ReplicatedStorage.Shared.DigDugConfig)
local PlatformUtil = require(ReplicatedStorage.Shared.PlatformUtil)

local SoundController = Knit.CreateController({
	Name = "SoundController",
})

SoundController._sounds = {} :: { [string]: Sound }
SoundController._sfxGroup = nil :: SoundGroup?
SoundController._musicGroup = nil :: SoundGroup?
SoundController._bgMusic = nil :: Sound?
SoundController._musicPlaying = false

-- Roblox asset IDs for retro/arcade-style sounds
local SoundAssets = {
	-- SFX
	Dig = "rbxassetid://9113869830", -- short crunch
	Pump = "rbxassetid://9113622901", -- air whoosh
	EnemyPop = "rbxassetid://5801617096", -- cartoon pop
	RockFall = "rbxassetid://5801617096", -- rumble thud (reuse pop for base)
	RockCrush = "rbxassetid://4918728884", -- heavy impact
	PlayerDeath = "rbxassetid://4918728884", -- retro death
	StageClear = "rbxassetid://5801617096", -- victory
	GameOver = "rbxassetid://4918728884", -- game over
	FygarFire = "rbxassetid://9113622901", -- fire breath
	ScorePopup = "rbxassetid://9113869830", -- coin ding
	HighScore = "rbxassetid://5801617096", -- achievement
	-- Music
	BGMusic = "rbxassetid://9043887091", -- chiptune loop
}

-- Volume and pitch overrides per sound
local SoundConfig: { [string]: { volume: number?, pitch: number?, looped: boolean? } } = {
	Dig = { volume = 0.4, pitch = 1.5 },
	Pump = { volume = 0.5, pitch = 1.2 },
	EnemyPop = { volume = 0.7, pitch = 1.3 },
	RockFall = { volume = 0.6, pitch = 0.6 },
	RockCrush = { volume = 0.8, pitch = 0.7 },
	PlayerDeath = { volume = 0.8, pitch = 0.8 },
	StageClear = { volume = 0.7, pitch = 1.5 },
	GameOver = { volume = 0.7, pitch = 0.5 },
	FygarFire = { volume = 0.6, pitch = 0.7 },
	ScorePopup = { volume = 0.3, pitch = 2.0 },
	HighScore = { volume = 0.8, pitch = 1.0 },
	BGMusic = { volume = 0.3, looped = true },
}

function SoundController:KnitInit()
	-- Create sound groups
	self._sfxGroup = Instance.new("SoundGroup")
	self._sfxGroup.Name = "DigDugSFX"
	self._sfxGroup.Volume = if PlatformUtil.isMobile() then 0.8 else 1.0
	self._sfxGroup.Parent = SoundService

	self._musicGroup = Instance.new("SoundGroup")
	self._musicGroup.Name = "DigDugMusic"
	self._musicGroup.Volume = 1.0
	self._musicGroup.Parent = SoundService

	-- Pre-create all sounds
	for name, assetId in SoundAssets do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = assetId

		local config = SoundConfig[name]
		if config then
			if config.volume then
				sound.Volume = config.volume
			end
			if config.pitch then
				sound.PlaybackSpeed = config.pitch
			end
			if config.looped then
				sound.Looped = true
			end
		end

		if name == "BGMusic" then
			sound.SoundGroup = self._musicGroup
			self._bgMusic = sound
		else
			sound.SoundGroup = self._sfxGroup
		end

		sound.Parent = SoundService
		self._sounds[name] = sound
	end
end

function SoundController:KnitStart()
	local GameService = Knit.GetService("GameService")
	local PlayerService = Knit.GetService("PlayerService")
	local EnemyService = Knit.GetService("EnemyService")
	local RockService = Knit.GetService("RockService")
	local GridService = Knit.GetService("GridService")

	local GridController = Knit.GetController("GridController")

	-- Dig sound: CellChanged fires when player digs dirt
	GridService.CellChanged:Connect(function(_col: number, _row: number, cellType: number)
		if cellType == DigDugConfig.CellType.EMPTY then
			self:PlaySound("Dig")
		end
	end)

	-- Pump sounds
	PlayerService.PumpStarted:Connect(function(_player)
		self:PlaySound("Pump")
	end)

	-- Enemy pop
	EnemyService.EnemyPopped:Connect(function(id: number)
		local EnemyController = Knit.GetController("EnemyController")
		local part = EnemyController._enemyParts[id]
		if part then
			self:PlaySoundAt("EnemyPop", part.Position)
		else
			self:PlaySound("EnemyPop")
		end
		self:PlaySound("ScorePopup")
	end)

	-- Enemy crushed
	EnemyService.EnemyCrushed:Connect(function(_id: number)
		self:PlaySound("RockCrush")
		self:PlaySound("ScorePopup")
	end)

	-- Fygar fire
	EnemyService.FygarFire:Connect(function(_enemyId: number, col: number, row: number, _dirX: number, _range: number)
		local worldPos = GridController:GridToWorld(col, row)
		self:PlaySoundAt("FygarFire", worldPos)
	end)

	-- Rock start falling
	RockService.RockStartFalling:Connect(function(_rockId: number, col: number, row: number)
		local worldPos = GridController:GridToWorld(col, row)
		self:PlaySoundAt("RockFall", worldPos)
	end)

	-- Player death
	GameService.PlayerDied:Connect(function()
		self:PlaySound("PlayerDeath")
		self:PauseMusic()
	end)

	-- Stage clear
	GameService.StageClear:Connect(function()
		self:PlaySound("StageClear")
		self:PauseMusic()
	end)

	-- Game over
	GameService.GameOver:Connect(function(_finalScore: number, _highScore: number)
		self:PlaySound("GameOver")
		self:StopMusic()
	end)

	-- Stage start: resume music
	GameService.StageChanged:Connect(function(_stage: number)
		task.delay(DigDugConfig.ROUND_START_DELAY, function()
			self:StartMusic()
		end)
	end)

	-- High score: check when score changes
	local prevHighScore = 0
	GameService.ScoreChanged:Connect(function(score: number)
		local GameController = Knit.GetController("GameController")
		if score > prevHighScore and score > 0 and score == GameController._highScore and prevHighScore > 0 then
			self:PlaySound("HighScore")
		end
		prevHighScore = GameController._highScore
	end)
end

function SoundController:PlaySound(name: string)
	local sound = self._sounds[name]
	if sound then
		-- Clone for overlapping plays
		local clone = sound:Clone()
		clone.Parent = SoundService
		clone.Ended:Once(function()
			clone:Destroy()
		end)
		clone:Play()
	end
end

function SoundController:PlaySoundAt(name: string, position: Vector3)
	local sound = self._sounds[name]
	if not sound then
		return
	end

	-- Create a temporary part for spatial audio
	local anchor = Instance.new("Part")
	anchor.Name = "SoundAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = position
	anchor.Parent = workspace

	local spatialSound = sound:Clone()
	spatialSound.Parent = anchor
	spatialSound.Ended:Once(function()
		anchor:Destroy()
	end)
	spatialSound:Play()
end

function SoundController:StartMusic()
	if self._bgMusic and not self._musicPlaying then
		self._bgMusic:Play()
		self._musicPlaying = true
	elseif self._bgMusic and self._bgMusic.IsPaused then
		self._bgMusic:Resume()
		self._musicPlaying = true
	end
end

function SoundController:PauseMusic()
	if self._bgMusic and self._musicPlaying then
		self._bgMusic:Pause()
		self._musicPlaying = false
	end
end

function SoundController:StopMusic()
	if self._bgMusic then
		self._bgMusic:Stop()
		self._musicPlaying = false
	end
end

function SoundController:SetSFXVolume(vol: number)
	if self._sfxGroup then
		self._sfxGroup.Volume = math.clamp(vol, 0, 1)
	end
end

function SoundController:SetMusicVolume(vol: number)
	if self._musicGroup then
		self._musicGroup.Volume = math.clamp(vol, 0, 1)
	end
end

return SoundController
