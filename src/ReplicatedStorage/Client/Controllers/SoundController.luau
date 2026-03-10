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
	Drill = "rbxassetid://9114083260", -- crack/drill sound (repurposed dig)
	Pump = "rbxassetid://17759294420", -- pump air whoosh
	EnemyPop = "rbxassetid://7948526859", -- balloon pop
	ChunkBreak = "rbxassetid://3923230963", -- ground smash/crack for chunk breaking
	Splash = "rbxassetid://1276167793", -- splash/water for chunk sinking
	PlayerDeath = "rbxassetid://297237983", -- 8-bit death
	StageClear = "rbxassetid://1837507072", -- victory fanfare
	GameOver = "rbxassetid://4858952348", -- game over 8-bit
	FygarFire = "rbxassetid://221456870", -- fireball whoosh
	ScorePopup = "rbxassetid://7128958209", -- bell ding
	HighScore = "rbxassetid://4342630136", -- achievement jingle
	-- Music
	BGMusic = "rbxassetid://9048375773", -- 8-bit chiptune loop
}

-- Volume and pitch overrides per sound
local SoundConfig: { [string]: { volume: number?, pitch: number?, looped: boolean? } } = {
	Drill = { volume = 0.4, pitch = 1.4 },
	Pump = { volume = 0.5, pitch = 1.0 },
	EnemyPop = { volume = 0.7, pitch = 1.0 },
	ChunkBreak = { volume = 0.8, pitch = 0.8 },
	Splash = { volume = 0.6, pitch = 1.0 },
	PlayerDeath = { volume = 0.8, pitch = 1.0 },
	StageClear = { volume = 0.7, pitch = 1.0 },
	GameOver = { volume = 0.7, pitch = 1.0 },
	FygarFire = { volume = 0.6, pitch = 1.0 },
	ScorePopup = { volume = 0.3, pitch = 1.2 },
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
	local GridService = Knit.GetService("GridService")

	local GridController = Knit.GetController("GridController")

	-- Drill sound when fault is drilled
	GridService.FaultDrilled:Connect(function(_faultType: string, row: number, col: number)
		local worldPos = GridController:GridToWorld(col, row)
		self:PlaySoundAt("Drill", worldPos)
	end)

	-- Chunk break + splash
	GridService.ChunkSinking:Connect(function(sinkingCells: { { number } })
		self:PlaySound("ChunkBreak")
		task.delay(0.3, function()
			if #sinkingCells > 0 then
				local cell = sinkingCells[1]
				local worldPos = GridController:GridToWorld(cell[1], cell[2])
				self:PlaySoundAt("Splash", worldPos)
			end
		end)
	end)

	-- Pump sounds
	PlayerService.PumpStarted:Connect(function(_player)
		self:PlaySound("Pump")
	end)

	-- Enemy pop
	EnemyService.EnemyPopped:Connect(function(id: number)
		local EnemyController = Knit.GetController("EnemyController")
		local model = EnemyController._enemyModels[id]
		if model and model.PrimaryPart then
			self:PlaySoundAt("EnemyPop", model.PrimaryPart.Position)
		else
			self:PlaySound("EnemyPop")
		end
		self:PlaySound("ScorePopup")
	end)

	-- Enemy chunk killed
	EnemyService.EnemyChunkKilled:Connect(function(_id: number)
		self:PlaySound("ScorePopup")
	end)

	-- Fygar fire
	EnemyService.FygarFire:Connect(function(_enemyId: number, col: number, row: number, _dirX: number, _range: number)
		local worldPos = GridController:GridToWorld(col, row)
		self:PlaySoundAt("FygarFire", worldPos)
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

	-- High score
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
