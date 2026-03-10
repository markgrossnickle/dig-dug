--!strict
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Knit = require(ReplicatedStorage.Packages.Knit)
local DigDugConfig = require(ReplicatedStorage.Shared.DigDugConfig)
local PlatformUtil = require(ReplicatedStorage.Shared.PlatformUtil)

local LocalPlayer = Players.LocalPlayer

local GameController = Knit.CreateController({
	Name = "GameController",
})

GameController._score = 0
GameController._lives = 0
GameController._stage = 1
GameController._state = "Waiting"
GameController._highScore = 0
GameController._hudGui = nil :: ScreenGui?

local function scaled(baseSize: number): number
	return math.floor(baseSize * PlatformUtil.getUIScale())
end

function GameController:KnitInit()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

	if LocalPlayer.Character then
		self:_hideCharacter(LocalPlayer.Character)
	end
	LocalPlayer.CharacterAdded:Connect(function(char)
		self:_hideCharacter(char)
	end)
end

function GameController:_hideCharacter(character: Model)
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
		if score > self._highScore then
			self._highScore = score
		end
		self:_updateHUD()
	end)

	GameService.LivesChanged:Connect(function(lives: number)
		self._lives = lives
		self:_updateHUD()
	end)

	GameService.StageChanged:Connect(function(stage: number)
		self._stage = stage
		self:_updateHUD()
		self:_hideMessage()
		self:_showRoundSplash(stage)
	end)

	GameService.GameStateChanged:Connect(function(state: string)
		self._state = state
		self:_updateHUD()
	end)

	GameService.PlayerDied:Connect(function()
		self:_showMessage("YOU DIED!", DigDugConfig.DEATH_DELAY, Color3.fromRGB(255, 80, 80))
	end)

	GameService.StageClear:Connect(function()
		self:_showMessage("STAGE CLEAR!", DigDugConfig.STAGE_CLEAR_DELAY, Color3.fromRGB(100, 255, 100))
		self:_flashCelebration()
	end)

	GameService.GameOver:Connect(function(finalScore: number, highScore: number)
		self._highScore = highScore
		self:_updateHUD()
		self:_showGameOverScreen(finalScore, highScore)
	end)

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

	local isMobile = PlatformUtil.isMobile()

	-- Top bar background for readability
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, scaled(56))
	topBar.Position = UDim2.new(0, 0, 0, 0)
	topBar.BackgroundColor3 = Color3.new(0, 0, 0)
	topBar.BackgroundTransparency = 0.5
	topBar.BorderSizePixel = 0
	topBar.Parent = gui

	-- Score display (top left)
	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "ScoreLabel"
	scoreLabel.Size = UDim2.new(0.3, 0, 0, scaled(28))
	scoreLabel.Position = UDim2.new(0, scaled(12), 0, scaled(4))
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.TextColor3 = Color3.new(1, 1, 1)
	scoreLabel.TextSize = scaled(if isMobile then 18 else 24)
	scoreLabel.Font = Enum.Font.Arcade
	scoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	scoreLabel.TextStrokeTransparency = 0.5
	scoreLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	scoreLabel.Text = "SCORE: 0"
	scoreLabel.Parent = gui

	-- High score (below score, smaller and gold)
	local highScoreLabel = Instance.new("TextLabel")
	highScoreLabel.Name = "HighScoreLabel"
	highScoreLabel.Size = UDim2.new(0.3, 0, 0, scaled(20))
	highScoreLabel.Position = UDim2.new(0, scaled(12), 0, scaled(30))
	highScoreLabel.BackgroundTransparency = 1
	highScoreLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
	highScoreLabel.TextSize = scaled(if isMobile then 12 else 14)
	highScoreLabel.Font = Enum.Font.Arcade
	highScoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	highScoreLabel.TextStrokeTransparency = 0.5
	highScoreLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	highScoreLabel.Text = "HI: 0"
	highScoreLabel.Parent = gui

	-- Lives display (top center) — icons as colored circles
	local livesFrame = Instance.new("Frame")
	livesFrame.Name = "LivesFrame"
	livesFrame.Size = UDim2.new(0.3, 0, 0, scaled(32))
	livesFrame.Position = UDim2.new(0.35, 0, 0, scaled(8))
	livesFrame.BackgroundTransparency = 1
	livesFrame.Parent = gui

	local livesLayout = Instance.new("UIListLayout")
	livesLayout.FillDirection = Enum.FillDirection.Horizontal
	livesLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	livesLayout.Padding = UDim.new(0, scaled(6))
	livesLayout.Parent = livesFrame

	-- "LIVES" text label above icons
	local livesLabel = Instance.new("TextLabel")
	livesLabel.Name = "LivesLabel"
	livesLabel.Size = UDim2.new(0.3, 0, 0, scaled(16))
	livesLabel.Position = UDim2.new(0.35, 0, 0, scaled(-2))
	livesLabel.BackgroundTransparency = 1
	livesLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	livesLabel.TextSize = scaled(if isMobile then 10 else 12)
	livesLabel.Font = Enum.Font.Arcade
	livesLabel.TextStrokeTransparency = 0.5
	livesLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	livesLabel.Text = "LIVES"
	livesLabel.Parent = gui

	-- Stage display (top right)
	local stageLabel = Instance.new("TextLabel")
	stageLabel.Name = "StageLabel"
	stageLabel.Size = UDim2.new(0.3, 0, 0, scaled(28))
	stageLabel.Position = UDim2.new(0.68, 0, 0, scaled(10))
	stageLabel.BackgroundTransparency = 1
	stageLabel.TextColor3 = Color3.new(1, 1, 1)
	stageLabel.TextSize = scaled(if isMobile then 18 else 24)
	stageLabel.Font = Enum.Font.Arcade
	stageLabel.TextXAlignment = Enum.TextXAlignment.Right
	stageLabel.TextStrokeTransparency = 0.5
	stageLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	stageLabel.Text = "STAGE: 1"
	stageLabel.Parent = gui

	-- Center message label
	local msgLabel = Instance.new("TextLabel")
	msgLabel.Name = "MessageLabel"
	msgLabel.Size = if isMobile then UDim2.new(0.85, 0, 0, scaled(100)) else UDim2.new(0, scaled(420), 0, scaled(130))
	msgLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	msgLabel.Position = UDim2.new(0.5, 0, 0.4, 0)
	msgLabel.BackgroundTransparency = 0.15
	msgLabel.BackgroundColor3 = Color3.new(0, 0, 0)
	msgLabel.TextColor3 = Color3.new(1, 1, 0)
	msgLabel.TextSize = scaled(if isMobile then 26 else 38)
	msgLabel.Font = Enum.Font.Arcade
	msgLabel.Text = ""
	msgLabel.Visible = false
	msgLabel.TextWrapped = true
	msgLabel.TextStrokeTransparency = 0.3
	msgLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	msgLabel.Parent = gui

	local msgCorner = Instance.new("UICorner")
	msgCorner.CornerRadius = UDim.new(0, 12)
	msgCorner.Parent = msgLabel

	local msgStroke = Instance.new("UIStroke")
	msgStroke.Color = Color3.fromRGB(255, 200, 0)
	msgStroke.Thickness = 2
	msgStroke.Parent = msgLabel
end

function GameController:_updateHUD()
	if not self._hudGui then
		return
	end
	local scoreLabel = self._hudGui:FindFirstChild("ScoreLabel") :: TextLabel?
	if scoreLabel then
		scoreLabel.Text = `SCORE: {self._score}`
	end
	local highScoreLabel = self._hudGui:FindFirstChild("HighScoreLabel") :: TextLabel?
	if highScoreLabel then
		highScoreLabel.Text = `HI: {self._highScore}`
	end
	local stageLabel = self._hudGui:FindFirstChild("StageLabel") :: TextLabel?
	if stageLabel then
		stageLabel.Text = `STAGE: {self._stage}`
	end

	-- Update lives icons
	self:_updateLivesIcons()
end

function GameController:_updateLivesIcons()
	if not self._hudGui then
		return
	end
	local livesFrame = self._hudGui:FindFirstChild("LivesFrame") :: Frame?
	if not livesFrame then
		return
	end

	-- Clear existing icons (but keep UIListLayout)
	for _, child in livesFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local iconSize = scaled(22)
	for i = 1, self._lives do
		local icon = Instance.new("Frame")
		icon.Name = `Life_{i}`
		icon.Size = UDim2.new(0, iconSize, 0, iconSize)
		icon.BackgroundColor3 = DigDugConfig.PLAYER_HELMET_COLOR
		icon.Parent = livesFrame

		local iconCorner = Instance.new("UICorner")
		iconCorner.CornerRadius = UDim.new(0.5, 0)
		iconCorner.Parent = icon

		-- Small white inner circle (body)
		local inner = Instance.new("Frame")
		inner.Name = "Inner"
		inner.Size = UDim2.new(0.6, 0, 0.6, 0)
		inner.Position = UDim2.new(0.2, 0, 0.15, 0)
		inner.BackgroundColor3 = Color3.new(1, 1, 1)
		inner.Parent = icon

		local innerCorner = Instance.new("UICorner")
		innerCorner.CornerRadius = UDim.new(0.5, 0)
		innerCorner.Parent = inner
	end
end

function GameController:_showRoundSplash(stage: number)
	if not self._hudGui then
		return
	end

	-- Full-screen round splash
	local splash = Instance.new("Frame")
	splash.Name = "RoundSplash"
	splash.Size = UDim2.fromScale(1, 1)
	splash.BackgroundColor3 = Color3.new(0, 0, 0)
	splash.BackgroundTransparency = 0.3
	splash.Parent = self._hudGui

	local roundLabel = Instance.new("TextLabel")
	roundLabel.Name = "RoundText"
	roundLabel.Size = UDim2.new(0.8, 0, 0, scaled(80))
	roundLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	roundLabel.Position = UDim2.new(0.5, 0, 0.4, 0)
	roundLabel.BackgroundTransparency = 1
	roundLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
	roundLabel.TextSize = scaled(if PlatformUtil.isMobile() then 40 else 56)
	roundLabel.Font = Enum.Font.Arcade
	roundLabel.Text = `ROUND {stage}`
	roundLabel.TextStrokeTransparency = 0.2
	roundLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	roundLabel.Parent = splash

	-- Animate: scale in, hold, fade out
	task.spawn(function()
		roundLabel.TextTransparency = 1
		for i = 1, 5 do
			roundLabel.TextTransparency = 1 - (i / 5)
			task.wait(0.06)
		end
		task.wait(DigDugConfig.ROUND_START_DELAY - 0.8)
		for i = 1, 5 do
			splash.BackgroundTransparency = 0.3 + (i / 5) * 0.7
			roundLabel.TextTransparency = i / 5
			task.wait(0.08)
		end
		splash:Destroy()
	end)
end

function GameController:_showMessage(text: string, duration: number?, color: Color3?)
	if not self._hudGui then
		return
	end
	local msgLabel = self._hudGui:FindFirstChild("MessageLabel") :: TextLabel?
	if not msgLabel then
		return
	end
	msgLabel.Text = text
	msgLabel.TextColor3 = color or Color3.new(1, 1, 0)
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

function GameController:_flashCelebration()
	if not self._hudGui then
		return
	end
	local flash = Instance.new("Frame")
	flash.Name = "CelebrationFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 200)
	flash.BackgroundTransparency = 0.7
	flash.Parent = self._hudGui

	task.spawn(function()
		for i = 1, 6 do
			flash.BackgroundTransparency = if i % 2 == 0 then 1 else 0.7
			task.wait(0.15)
		end
		flash:Destroy()
	end)
end

function GameController:_startGame()
	local startScreen = if self._hudGui then self._hudGui:FindFirstChild("StartScreen") else nil
	if startScreen then
		startScreen:Destroy()
	end
	local GameService = Knit.GetService("GameService")
	GameService:RequestStartGame():catch(function(err)
		warn("Failed to start game:", err)
	end)
end

function GameController:_showGameOverScreen(finalScore: number, highScore: number)
	if not self._hudGui then
		return
	end

	local existing = self._hudGui:FindFirstChild("GameOverScreen")
	if existing then
		existing:Destroy()
	end

	local isMobile = PlatformUtil.isMobile()

	local frame = Instance.new("Frame")
	frame.Name = "GameOverScreen"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 0.15
	frame.Parent = self._hudGui

	local gameOverLabel = Instance.new("TextLabel")
	gameOverLabel.Name = "GameOverText"
	gameOverLabel.Size = UDim2.new(0.8, 0, 0, scaled(70))
	gameOverLabel.AnchorPoint = Vector2.new(0.5, 0)
	gameOverLabel.Position = UDim2.new(0.5, 0, 0.15, 0)
	gameOverLabel.BackgroundTransparency = 1
	gameOverLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
	gameOverLabel.TextSize = scaled(if isMobile then 44 else 60)
	gameOverLabel.Font = Enum.Font.Arcade
	gameOverLabel.Text = "GAME OVER"
	gameOverLabel.TextStrokeTransparency = 0.2
	gameOverLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	gameOverLabel.Parent = frame

	local scoreText = Instance.new("TextLabel")
	scoreText.Name = "FinalScore"
	scoreText.Size = UDim2.new(0.8, 0, 0, scaled(40))
	scoreText.AnchorPoint = Vector2.new(0.5, 0)
	scoreText.Position = UDim2.new(0.5, 0, 0.35, 0)
	scoreText.BackgroundTransparency = 1
	scoreText.TextColor3 = Color3.new(1, 1, 1)
	scoreText.TextSize = scaled(if isMobile then 22 else 30)
	scoreText.Font = Enum.Font.Arcade
	scoreText.Text = `SCORE: {finalScore}`
	scoreText.TextStrokeTransparency = 0.5
	scoreText.TextStrokeColor3 = Color3.new(0, 0, 0)
	scoreText.Parent = frame

	local hiText = Instance.new("TextLabel")
	hiText.Name = "HighScoreText"
	hiText.Size = UDim2.new(0.8, 0, 0, scaled(36))
	hiText.AnchorPoint = Vector2.new(0.5, 0)
	hiText.Position = UDim2.new(0.5, 0, 0.45, 0)
	hiText.BackgroundTransparency = 1
	hiText.TextColor3 = Color3.fromRGB(255, 200, 0)
	hiText.TextSize = scaled(if isMobile then 20 else 26)
	hiText.Font = Enum.Font.Arcade
	hiText.Text = `HIGH SCORE: {highScore}`
	hiText.TextStrokeTransparency = 0.5
	hiText.TextStrokeColor3 = Color3.new(0, 0, 0)
	hiText.Parent = frame

	-- Flashing "insert coin" style text
	local continueLabel = Instance.new("TextLabel")
	continueLabel.Name = "ContinueText"
	continueLabel.Size = UDim2.new(0.8, 0, 0, scaled(30))
	continueLabel.AnchorPoint = Vector2.new(0.5, 0)
	continueLabel.Position = UDim2.new(0.5, 0, 0.65, 0)
	continueLabel.BackgroundTransparency = 1
	continueLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	continueLabel.TextSize = scaled(if isMobile then 14 else 18)
	continueLabel.Font = Enum.Font.Arcade
	continueLabel.Text = "RETURNING TO TITLE..."
	continueLabel.Parent = frame

	task.spawn(function()
		for i = 1, 16 do
			if not continueLabel or not continueLabel.Parent then
				break
			end
			continueLabel.TextTransparency = if i % 2 == 0 then 0.6 else 0
			task.wait(0.3)
		end
	end)

	task.delay(5, function()
		if frame and frame.Parent then
			frame:Destroy()
		end
		self:_showStartScreen()
	end)
end

function GameController:_showStartScreen()
	if not self._hudGui then
		return
	end

	local existing = self._hudGui:FindFirstChild("StartScreen")
	if existing then
		existing:Destroy()
	end

	local isMobile = PlatformUtil.isMobile()
	local isGamepad = PlatformUtil.isGamepad()

	local frame = Instance.new("Frame")
	frame.Name = "StartScreen"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(10, 20, 40)
	frame.BackgroundTransparency = 0.15
	frame.Parent = self._hudGui

	-- Title with retro arcade styling
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0.8, 0, 0, scaled(80))
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0.12, 0)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 220, 50)
	title.TextSize = scaled(if isMobile then 48 else 68)
	title.Font = Enum.Font.Arcade
	title.Text = "DIG DUG II"
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = Color3.fromRGB(180, 80, 0)
	title.Parent = frame

	-- Subtitle
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(0.8, 0, 0, scaled(24))
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.Position = UDim2.new(0.5, 0, 0.25, 0)
	subtitle.BackgroundTransparency = 1
	subtitle.TextColor3 = Color3.fromRGB(100, 180, 255)
	subtitle.TextSize = scaled(if isMobile then 14 else 18)
	subtitle.Font = Enum.Font.Arcade
	subtitle.Text = "TROUBLE IN PARADISE"
	subtitle.Parent = frame

	-- High score on start screen
	if self._highScore > 0 then
		local hiLabel = Instance.new("TextLabel")
		hiLabel.Name = "HighScore"
		hiLabel.Size = UDim2.new(0.8, 0, 0, scaled(30))
		hiLabel.AnchorPoint = Vector2.new(0.5, 0)
		hiLabel.Position = UDim2.new(0.5, 0, 0.33, 0)
		hiLabel.BackgroundTransparency = 1
		hiLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
		hiLabel.TextSize = scaled(if isMobile then 18 else 22)
		hiLabel.Font = Enum.Font.Arcade
		hiLabel.Text = `HIGH SCORE: {self._highScore}`
		hiLabel.TextStrokeTransparency = 0.5
		hiLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		hiLabel.Parent = frame
	end

	-- Controls info
	local controlsText: string
	if isGamepad then
		controlsText = "D-PAD: MOVE  |  A: PUMP  |  X: DRILL\nDRILL FAULT LINES TO SINK ISLAND CHUNKS!"
	elseif isMobile then
		controlsText = "D-PAD: MOVE  |  PUMP: INFLATE  |  DRILL: CRACK\nDRILL FAULT LINES TO SINK ISLAND CHUNKS!"
	else
		controlsText = "WASD/ARROWS: MOVE  |  SPACE: PUMP  |  E: DRILL\nDRILL FAULT LINES TO SINK ISLAND CHUNKS!"
	end

	local controls = Instance.new("TextLabel")
	controls.Name = "Controls"
	controls.Size = UDim2.new(0.85, 0, 0, scaled(50))
	controls.AnchorPoint = Vector2.new(0.5, 0)
	controls.Position = UDim2.new(0.5, 0, 0.68, 0)
	controls.BackgroundTransparency = 1
	controls.TextColor3 = Color3.fromRGB(160, 160, 160)
	controls.TextSize = scaled(if isMobile then 12 else 14)
	controls.Font = Enum.Font.Arcade
	controls.Text = controlsText
	controls.TextWrapped = true
	controls.Parent = frame

	-- Start button with pulsing glow
	local startBtn = Instance.new("TextButton")
	startBtn.Name = "StartButton"
	startBtn.Size = if isMobile then UDim2.new(0.65, 0, 0, scaled(56)) else UDim2.new(0, scaled(280), 0, scaled(56))
	startBtn.AnchorPoint = Vector2.new(0.5, 0)
	startBtn.Position = UDim2.new(0.5, 0, 0.5, 0)
	startBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 50)
	startBtn.TextColor3 = Color3.new(1, 1, 1)
	startBtn.TextSize = scaled(if isMobile then 22 else 28)
	startBtn.Font = Enum.Font.Arcade
	startBtn.Text = if isGamepad then "PRESS A TO START" else "START GAME"
	startBtn.TextStrokeTransparency = 0.3
	startBtn.TextStrokeColor3 = Color3.new(0, 0, 0)
	startBtn.Parent = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = startBtn

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = Color3.fromRGB(100, 255, 100)
	btnStroke.Thickness = 2
	btnStroke.Parent = startBtn

	-- Pulse the button
	task.spawn(function()
		while startBtn and startBtn.Parent do
			for i = 1, 10 do
				if not startBtn or not startBtn.Parent then
					return
				end
				btnStroke.Transparency = i / 10
				task.wait(0.05)
			end
			for i = 10, 1, -1 do
				if not startBtn or not startBtn.Parent then
					return
				end
				btnStroke.Transparency = i / 10
				task.wait(0.05)
			end
		end
	end)

	startBtn.Activated:Connect(function()
		self:_startGame()
	end)

	if isGamepad then
		GuiService.SelectedObject = startBtn
	end
end

return GameController
