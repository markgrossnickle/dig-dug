--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Knit = require(ReplicatedStorage.Packages.Knit)
local DigDugConfig = require(ReplicatedStorage.Shared.DigDugConfig)

local LocalPlayer = Players.LocalPlayer

local GameController = Knit.CreateController({
	Name = "GameController",
})

GameController._score = 0
GameController._lives = 0
GameController._stage = 1
GameController._state = "Waiting"
GameController._hudGui = nil :: ScreenGui?

function GameController:KnitInit()
	-- Disable default Roblox UI elements
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

	-- Hide the character
	if LocalPlayer.Character then
		self:_hideCharacter(LocalPlayer.Character)
	end
	LocalPlayer.CharacterAdded:Connect(function(char)
		self:_hideCharacter(char)
	end)
end

function GameController:_hideCharacter(character: Model)
	-- Make the default character invisible — we use our own sprite
	task.defer(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			humanoid.JumpHeight = 0
		end
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = 1
				part.CanCollide = false
			elseif part:IsA("Decal") or part:IsA("Texture") then
				part.Transparency = 1
			end
		end
	end)
end

function GameController:KnitStart()
	local GameService = Knit.GetService("GameService")

	GameService.ScoreChanged:Connect(function(score: number)
		self._score = score
		self:_updateHUD()
	end)

	GameService.LivesChanged:Connect(function(lives: number)
		self._lives = lives
		self:_updateHUD()
	end)

	GameService.StageChanged:Connect(function(stage: number)
		self._stage = stage
		self:_updateHUD()
	end)

	GameService.GameStateChanged:Connect(function(state: string)
		self._state = state
		self:_updateHUD()

		if state == "Waiting" or state == "GameOver" then
			self:_showStartScreen()
		end
	end)

	GameService.PlayerDied:Connect(function()
		self:_showMessage("YOU DIED!", DigDugConfig.DEATH_DELAY)
	end)

	GameService.StageClear:Connect(function()
		self:_showMessage("STAGE CLEAR!", DigDugConfig.STAGE_CLEAR_DELAY)
	end)

	GameService.GameOver:Connect(function(finalScore: number)
		self:_showMessage(`GAME OVER\nScore: {finalScore}`, 5)
	end)

	-- Create HUD
	self:_createHUD()
	self:_showStartScreen()
end

function GameController:_createHUD()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DigDugHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = LocalPlayer.PlayerGui
	self._hudGui = gui

	-- Score display (top left)
	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "ScoreLabel"
	scoreLabel.Size = UDim2.new(0, 200, 0, 40)
	scoreLabel.Position = UDim2.new(0, 10, 0, 10)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.TextColor3 = Color3.new(1, 1, 1)
	scoreLabel.TextSize = 28
	scoreLabel.Font = Enum.Font.Arcade
	scoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	scoreLabel.Text = "SCORE: 0"
	scoreLabel.Parent = gui

	-- Lives display (top center)
	local livesLabel = Instance.new("TextLabel")
	livesLabel.Name = "LivesLabel"
	livesLabel.Size = UDim2.new(0, 200, 0, 40)
	livesLabel.Position = UDim2.new(0.5, -100, 0, 10)
	livesLabel.BackgroundTransparency = 1
	livesLabel.TextColor3 = Color3.new(1, 1, 1)
	livesLabel.TextSize = 28
	livesLabel.Font = Enum.Font.Arcade
	livesLabel.Text = "LIVES: 3"
	livesLabel.Parent = gui

	-- Stage display (top right)
	local stageLabel = Instance.new("TextLabel")
	stageLabel.Name = "StageLabel"
	stageLabel.Size = UDim2.new(0, 200, 0, 40)
	stageLabel.Position = UDim2.new(1, -210, 0, 10)
	stageLabel.BackgroundTransparency = 1
	stageLabel.TextColor3 = Color3.new(1, 1, 1)
	stageLabel.TextSize = 28
	stageLabel.Font = Enum.Font.Arcade
	stageLabel.TextXAlignment = Enum.TextXAlignment.Right
	stageLabel.Text = "STAGE: 1"
	stageLabel.Parent = gui

	-- Center message label (for notifications)
	local msgLabel = Instance.new("TextLabel")
	msgLabel.Name = "MessageLabel"
	msgLabel.Size = UDim2.new(0, 400, 0, 100)
	msgLabel.Position = UDim2.new(0.5, -200, 0.4, -50)
	msgLabel.BackgroundTransparency = 0.3
	msgLabel.BackgroundColor3 = Color3.new(0, 0, 0)
	msgLabel.TextColor3 = Color3.new(1, 1, 0)
	msgLabel.TextSize = 36
	msgLabel.Font = Enum.Font.Arcade
	msgLabel.Text = ""
	msgLabel.Visible = false
	msgLabel.Parent = gui
end

function GameController:_updateHUD()
	if not self._hudGui then
		return
	end
	local scoreLabel = self._hudGui:FindFirstChild("ScoreLabel") :: TextLabel?
	if scoreLabel then
		scoreLabel.Text = `SCORE: {self._score}`
	end
	local livesLabel = self._hudGui:FindFirstChild("LivesLabel") :: TextLabel?
	if livesLabel then
		livesLabel.Text = `LIVES: {self._lives}`
	end
	local stageLabel = self._hudGui:FindFirstChild("StageLabel") :: TextLabel?
	if stageLabel then
		stageLabel.Text = `STAGE: {self._stage}`
	end
end

function GameController:_showMessage(text: string, duration: number?)
	if not self._hudGui then
		return
	end
	local msgLabel = self._hudGui:FindFirstChild("MessageLabel") :: TextLabel?
	if not msgLabel then
		return
	end
	msgLabel.Text = text
	msgLabel.Visible = true

	if duration then
		task.delay(duration, function()
			if msgLabel then
				msgLabel.Visible = false
			end
		end)
	end
end

function GameController:_hideMessage()
	if not self._hudGui then
		return
	end
	local msgLabel = self._hudGui:FindFirstChild("MessageLabel") :: TextLabel?
	if msgLabel then
		msgLabel.Visible = false
	end
end

function GameController:_showStartScreen()
	if not self._hudGui then
		return
	end

	-- Create start screen
	local existing = self._hudGui:FindFirstChild("StartScreen")
	if existing then
		existing:Destroy()
	end

	local frame = Instance.new("Frame")
	frame.Name = "StartScreen"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 0.3
	frame.Parent = self._hudGui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0, 500, 0, 80)
	title.Position = UDim2.new(0.5, -250, 0.3, 0)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 200, 0)
	title.TextSize = 60
	title.Font = Enum.Font.Arcade
	title.Text = "DIG DUG"
	title.Parent = frame

	local startBtn = Instance.new("TextButton")
	startBtn.Name = "StartButton"
	startBtn.Size = UDim2.new(0, 300, 0, 60)
	startBtn.Position = UDim2.new(0.5, -150, 0.55, 0)
	startBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
	startBtn.TextColor3 = Color3.new(1, 1, 1)
	startBtn.TextSize = 32
	startBtn.Font = Enum.Font.Arcade
	startBtn.Text = "START GAME"
	startBtn.Parent = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = startBtn

	startBtn.MouseButton1Click:Connect(function()
		frame:Destroy()
		local GameService = Knit.GetService("GameService")
		GameService:RequestStartGame()
	end)
end

return GameController
