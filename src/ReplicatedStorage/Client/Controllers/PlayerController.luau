--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local DigDugConfig = require(ReplicatedStorage.Shared.DigDugConfig)
local PlatformUtil = require(ReplicatedStorage.Shared.PlatformUtil)

local LocalPlayer = Players.LocalPlayer
local CELL_SIZE = DigDugConfig.CELL_SIZE
local MOVE_INTERVAL = 1 / DigDugConfig.PLAYER_SPEED

local PlayerController = Knit.CreateController({
	Name = "PlayerController",
})

PlayerController._playerModels = {} :: { [Player]: Model }
PlayerController._moveTimer = 0
PlayerController._facingDir = Vector2.new(1, 0)
PlayerController._isPumping = false
PlayerController._heartbeatConn = nil :: RBXScriptConnection?
PlayerController._pumpModel = nil :: Model?
PlayerController._touchDirX = 0
PlayerController._touchDirY = 0
PlayerController._touchPump = false
PlayerController._gamepadConn = nil :: RBXScriptConnection?
PlayerController._walkBob = 0

function PlayerController:KnitInit()
	if PlatformUtil.isMobile() then
		self:_createMobileControls()
	end
end

function PlayerController:KnitStart()
	local PlayerService = Knit.GetService("PlayerService")

	PlayerService.PlayerSpawned:Connect(function(player: Player, col: number, row: number)
		self:_onPlayerSpawned(player, col, row)
	end)

	PlayerService.PlayerMoved:Connect(function(player: Player, col: number, row: number)
		self:_onPlayerMoved(player, col, row)
	end)

	PlayerService.PlayerDirectionChanged:Connect(function(player: Player, dirX: number, dirY: number)
		if player == LocalPlayer then
			self._facingDir = Vector2.new(dirX, dirY)
			self:_updateFacing()
		end
	end)

	PlayerService.PumpStarted:Connect(function(player: Player)
		if player == LocalPlayer then
			self:_showPump(true)
		end
	end)

	PlayerService.PumpStopped:Connect(function(player: Player)
		if player == LocalPlayer then
			self:_showPump(false)
		end
	end)

	local GameService = Knit.GetService("GameService")
	GameService.PlayerDied:Connect(function()
		self:_onDeath()
	end)

	local GridService = Knit.GetService("GridService")
	GridService.GridReset:Connect(function()
		self:_clearAllParts()
	end)

	self:_startInputLoop()
	self:_setupGamepad()
end

function PlayerController:_buildPlayerModel(player: Player, worldPos: Vector3): Model
	local model = Instance.new("Model")
	model.Name = `Player_{player.Name}`

	local isLocal = player == LocalPlayer
	local bodyColor = if isLocal then DigDugConfig.PLAYER_BODY_COLOR else Color3.fromRGB(200, 200, 255)
	local helmetColor = if isLocal then DigDugConfig.PLAYER_HELMET_COLOR else Color3.fromRGB(120, 120, 200)
	local s = CELL_SIZE * 0.35 -- base scale

	-- Body (torso) — white block
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.Size = Vector3.new(s * 1.2, s * 1.4, s * 1.0)
	body.Position = worldPos + Vector3.new(0, s * 0.7, 0)
	body.Color = bodyColor
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = model

	-- Head (sphere) — blue helmet
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Anchored = true
	head.CanCollide = false
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(s * 1.3, s * 1.3, s * 1.3)
	head.Position = worldPos + Vector3.new(0, s * 1.8, 0)
	head.Color = helmetColor
	head.Material = Enum.Material.SmoothPlastic
	head.Parent = model

	-- Visor (small sphere on front of head)
	local visor = Instance.new("Part")
	visor.Name = "Visor"
	visor.Anchored = true
	visor.CanCollide = false
	visor.Shape = Enum.PartType.Ball
	visor.Size = Vector3.new(s * 0.6, s * 0.5, s * 0.3)
	visor.Position = worldPos + Vector3.new(0, s * 1.8, -s * 0.55)
	visor.Color = DigDugConfig.PLAYER_VISOR_COLOR
	visor.Material = Enum.Material.Neon
	visor.Transparency = 0.2
	visor.Parent = model

	-- Left arm
	local leftArm = Instance.new("Part")
	leftArm.Name = "LeftArm"
	leftArm.Anchored = true
	leftArm.CanCollide = false
	leftArm.Size = Vector3.new(s * 0.35, s * 1.0, s * 0.35)
	leftArm.Position = worldPos + Vector3.new(-s * 0.8, s * 0.7, 0)
	leftArm.Color = bodyColor
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.Parent = model

	-- Right arm
	local rightArm = Instance.new("Part")
	rightArm.Name = "RightArm"
	rightArm.Anchored = true
	rightArm.CanCollide = false
	rightArm.Size = Vector3.new(s * 0.35, s * 1.0, s * 0.35)
	rightArm.Position = worldPos + Vector3.new(s * 0.8, s * 0.7, 0)
	rightArm.Color = bodyColor
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.Parent = model

	-- Left leg
	local leftLeg = Instance.new("Part")
	leftLeg.Name = "LeftLeg"
	leftLeg.Anchored = true
	leftLeg.CanCollide = false
	leftLeg.Size = Vector3.new(s * 0.4, s * 0.6, s * 0.4)
	leftLeg.Position = worldPos + Vector3.new(-s * 0.35, s * -0.1, 0)
	leftLeg.Color = Color3.fromRGB(60, 60, 180) -- blue pants
	leftLeg.Material = Enum.Material.SmoothPlastic
	leftLeg.Parent = model

	-- Right leg
	local rightLeg = Instance.new("Part")
	rightLeg.Name = "RightLeg"
	rightLeg.Anchored = true
	rightLeg.CanCollide = false
	rightLeg.Size = Vector3.new(s * 0.4, s * 0.6, s * 0.4)
	rightLeg.Position = worldPos + Vector3.new(s * 0.35, s * -0.1, 0)
	rightLeg.Color = Color3.fromRGB(60, 60, 180)
	rightLeg.Material = Enum.Material.SmoothPlastic
	rightLeg.Parent = model

	model.PrimaryPart = body
	model.Parent = workspace

	return model
end

function PlayerController:_moveModelTo(model: Model, worldPos: Vector3)
	if not model.PrimaryPart then
		return
	end
	local offset = worldPos - model.PrimaryPart.Position
	-- Add walk bobbing for position
	offset += Vector3.new(0, offset.Magnitude > 0.01 and 0 or 0, 0)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			part.Position = part.Position + offset
		end
	end
end

function PlayerController:_updateFacing()
	local model = self._playerModels[LocalPlayer]
	if not model or not model.PrimaryPart then
		return
	end

	-- Rotate model to face direction on XZ plane
	local dir = self._facingDir
	local lookDir = Vector3.new(dir.X, 0, dir.Y)
	if lookDir.Magnitude < 0.01 then
		return
	end

	-- Reposition visor to front of head
	local visor = model:FindFirstChild("Visor") :: BasePart?
	local head = model:FindFirstChild("Head") :: BasePart?
	if visor and head then
		local s = CELL_SIZE * 0.35
		visor.Position = head.Position + lookDir.Unit * (s * 0.55)
	end

	-- Update pump position
	self:_updatePumpPosition()
end

function PlayerController:_onDeath()
	local model = self._playerModels[LocalPlayer]
	if not model then
		return
	end

	task.spawn(function()
		-- Flatten/squish death animation
		for i = 1, 10 do
			for _, part in model:GetChildren() do
				if part:IsA("BasePart") then
					-- Squish vertically
					part.Size = Vector3.new(part.Size.X * 1.05, part.Size.Y * 0.8, part.Size.Z * 1.05)
					part.Position = part.Position - Vector3.new(0, 0.05, 0)
					part.Transparency = if i % 2 == 0 then 0 else 0.4
				end
			end
			task.wait(0.1)
		end
		-- Final fade
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") then
				part.Transparency = 1
			end
		end
	end)

	self:_showPump(false)
end

function PlayerController:_clearAllParts()
	for _, model in self._playerModels do
		model:Destroy()
	end
	self._playerModels = {}
	if self._pumpModel then
		self._pumpModel:Destroy()
		self._pumpModel = nil
	end
end

function PlayerController:_onPlayerSpawned(player: Player, col: number, row: number)
	if self._playerModels[player] then
		self._playerModels[player]:Destroy()
	end

	local GridController = Knit.GetController("GridController")
	local worldPos = GridController:GridToWorld(col, row)

	local model = self:_buildPlayerModel(player, worldPos)
	self._playerModels[player] = model
end

function PlayerController:_onPlayerMoved(player: Player, col: number, row: number)
	local model = self._playerModels[player]
	if not model then
		return
	end

	local GridController = Knit.GetController("GridController")
	local worldPos = GridController:GridToWorld(col, row)
	self:_moveModelTo(model, worldPos)

	-- Walk bob animation for local player
	if player == LocalPlayer then
		self._walkBob += 1
		local bob = math.sin(self._walkBob * 0.8) * 0.15
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") then
				part.Position = part.Position + Vector3.new(0, bob, 0)
			end
		end
		self:_updatePumpPosition()
	end
end

function PlayerController:_startInputLoop()
	self._heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		self:_handleInput(dt)
	end)
end

function PlayerController:_setupGamepad()
	if not PlatformUtil.isGamepad() then
		return
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonStart then
			local GameController = Knit.GetController("GameController")
			if GameController._state == "Waiting" or GameController._state == "GameOver" then
				GameController:_startGame()
			end
		end
	end)
end

function PlayerController:_handleInput(dt: number)
	local GameController = Knit.GetController("GameController")
	if GameController._state ~= "Playing" then
		return
	end

	local dirX = self._touchDirX
	local dirY = self._touchDirY

	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		dirY = -1
	elseif UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		dirY = 1
	elseif UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		dirX = -1
	elseif UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		dirX = 1
	end

	if PlatformUtil.isGamepad() then
		if UserInputService:IsKeyDown(Enum.KeyCode.DPadUp) then
			dirY = -1
		elseif UserInputService:IsKeyDown(Enum.KeyCode.DPadDown) then
			dirY = 1
		elseif UserInputService:IsKeyDown(Enum.KeyCode.DPadLeft) then
			dirX = -1
		elseif UserInputService:IsKeyDown(Enum.KeyCode.DPadRight) then
			dirX = 1
		else
			local states = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
			for _, state in states do
				if state.KeyCode == Enum.KeyCode.Thumbstick1 then
					if math.abs(state.Position.X) > 0.5 or math.abs(state.Position.Y) > 0.5 then
						if math.abs(state.Position.X) > math.abs(state.Position.Y) then
							dirX = if state.Position.X > 0 then 1 else -1
						else
							dirY = if state.Position.Y > 0 then -1 else 1
						end
					end
					break
				end
			end
		end
	end

	local wantsPump = UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or UserInputService:IsKeyDown(Enum.KeyCode.Z)
		or self._touchPump
	if PlatformUtil.isGamepad() then
		wantsPump = wantsPump or UserInputService:IsKeyDown(Enum.KeyCode.ButtonA)
	end

	if wantsPump and not self._isPumping then
		self._isPumping = true
		local PlayerService = Knit.GetService("PlayerService")
		PlayerService:StartPump():catch(function() end)
	elseif not wantsPump and self._isPumping then
		self._isPumping = false
		local PlayerService = Knit.GetService("PlayerService")
		PlayerService:StopPump():catch(function() end)
	end

	if self._isPumping then
		return
	end

	if dirX ~= 0 or dirY ~= 0 then
		if math.abs(dirX) > math.abs(dirY) then
			self._facingDir = Vector2.new(if dirX > 0 then 1 else -1, 0)
		else
			self._facingDir = Vector2.new(0, if dirY > 0 then 1 else -1)
		end

		self._moveTimer += dt
		if self._moveTimer >= MOVE_INTERVAL then
			self._moveTimer = 0
			local PlayerService = Knit.GetService("PlayerService")
			PlayerService:Move(dirX, dirY):catch(function() end)
		end
	else
		self._moveTimer = MOVE_INTERVAL
	end
end

function PlayerController:_showPump(active: boolean)
	if active then
		if not self._pumpModel then
			self._pumpModel = self:_buildPumpModel()
		end
		for _, part in self._pumpModel:GetChildren() do
			if part:IsA("BasePart") then
				part.Transparency = 0
			end
		end
		self:_updatePumpPosition()
	else
		if self._pumpModel then
			for _, part in self._pumpModel:GetChildren() do
				if part:IsA("BasePart") then
					part.Transparency = 1
				end
			end
		end
	end
end

function PlayerController:_buildPumpModel(): Model
	local model = Instance.new("Model")
	model.Name = "PumpHose"

	-- Hose line (series of small parts for segmented look)
	local segments = 6
	for i = 1, segments do
		local seg = Instance.new("Part")
		seg.Name = `Segment_{i}`
		seg.Anchored = true
		seg.CanCollide = false
		seg.Size = Vector3.new(CELL_SIZE * 0.12, CELL_SIZE * 0.12, CELL_SIZE * 0.12)
		seg.Shape = Enum.PartType.Ball
		seg.Color = Color3.fromRGB(255, 80, 80)
		seg.Material = Enum.Material.Neon
		seg.Transparency = 1
		seg.Parent = model
	end

	-- Pump end (nozzle)
	local nozzle = Instance.new("Part")
	nozzle.Name = "Nozzle"
	nozzle.Anchored = true
	nozzle.CanCollide = false
	nozzle.Size = Vector3.new(CELL_SIZE * 0.25, CELL_SIZE * 0.25, CELL_SIZE * 0.25)
	nozzle.Shape = Enum.PartType.Ball
	nozzle.Color = Color3.fromRGB(255, 50, 50)
	nozzle.Material = Enum.Material.Neon
	nozzle.Transparency = 1
	nozzle.Parent = model

	model.Parent = workspace
	return model
end

function PlayerController:_updatePumpPosition()
	local model = self._playerModels[LocalPlayer]
	if not model or not model.PrimaryPart or not self._pumpModel then
		return
	end

	local bodyPos = model.PrimaryPart.Position
	local dir3 = Vector3.new(self._facingDir.X, 0, self._facingDir.Y)
	local range = CELL_SIZE * DigDugConfig.PUMP_RANGE * 0.5

	-- Position segments along the hose line
	local segments = {}
	for _, part in self._pumpModel:GetChildren() do
		if part:IsA("BasePart") and part.Name:sub(1, 7) == "Segment" then
			table.insert(segments, part)
		end
	end

	for i, seg in segments do
		local t = i / (#segments + 1)
		seg.Position = bodyPos + dir3 * (t * range)
	end

	-- Position nozzle at end
	local nozzle = self._pumpModel:FindFirstChild("Nozzle") :: BasePart?
	if nozzle then
		nozzle.Position = bodyPos + dir3 * range
	end
end

function PlayerController:_createMobileControls()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MobileControls"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = LocalPlayer.PlayerGui

	local dpad = Instance.new("Frame")
	dpad.Name = "DPad"
	dpad.Size = UDim2.new(0, 200, 0, 200)
	dpad.Position = UDim2.new(0, 16, 1, -216)
	dpad.BackgroundTransparency = 1
	dpad.Parent = gui

	local btnSize = 64
	local directions = {
		{ name = "U", pos = UDim2.new(0.5, -btnSize / 2, 0, 0), dx = 0, dy = -1 },
		{ name = "D", pos = UDim2.new(0.5, -btnSize / 2, 1, -btnSize), dx = 0, dy = 1 },
		{ name = "L", pos = UDim2.new(0, 0, 0.5, -btnSize / 2), dx = -1, dy = 0 },
		{ name = "R", pos = UDim2.new(1, -btnSize, 0.5, -btnSize / 2), dx = 1, dy = 0 },
	}

	for _, dir in directions do
		local btn = Instance.new("TextButton")
		btn.Name = dir.name
		btn.Size = UDim2.new(0, btnSize, 0, btnSize)
		btn.Position = dir.pos
		btn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		btn.BackgroundTransparency = 0.4
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.TextSize = 28
		btn.Font = Enum.Font.Arcade
		btn.Text = dir.name
		btn.Parent = dpad

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = btn

		btn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				self._touchDirX = dir.dx
				self._touchDirY = dir.dy
			end
		end)
		btn.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				if self._touchDirX == dir.dx and self._touchDirY == dir.dy then
					self._touchDirX = 0
					self._touchDirY = 0
				end
			end
		end)
	end

	local pumpSize = 72
	local pumpBtn = Instance.new("TextButton")
	pumpBtn.Name = "PumpButton"
	pumpBtn.Size = UDim2.new(0, pumpSize, 0, pumpSize)
	pumpBtn.Position = UDim2.new(1, -pumpSize - 24, 1, -pumpSize - 60)
	pumpBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	pumpBtn.BackgroundTransparency = 0.2
	pumpBtn.TextColor3 = Color3.new(1, 1, 1)
	pumpBtn.TextSize = 18
	pumpBtn.Font = Enum.Font.Arcade
	pumpBtn.Text = "PUMP"
	pumpBtn.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = pumpBtn

	pumpBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			self._touchPump = true
		end
	end)
	pumpBtn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			self._touchPump = false
		end
	end)
end

return PlayerController
