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

PlayerController._playerParts = {} :: { [Player]: Part }
PlayerController._moveTimer = 0
PlayerController._facingDir = Vector2.new(1, 0)
PlayerController._isPumping = false
PlayerController._heartbeatConn = nil :: RBXScriptConnection?
PlayerController._pumpPart = nil :: Part?
PlayerController._touchDirX = 0
PlayerController._touchDirY = 0
PlayerController._touchPump = false
PlayerController._gamepadConn = nil :: RBXScriptConnection?

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

	-- Death animation
	local GameService = Knit.GetService("GameService")
	GameService.PlayerDied:Connect(function()
		self:_onDeath()
	end)

	-- Clean up on grid reset (new stage)
	local GridService = Knit.GetService("GridService")
	GridService.GridReset:Connect(function()
		self:_clearAllParts()
	end)

	self:_startInputLoop()
	self:_setupGamepad()
end

function PlayerController:_onDeath()
	local myPart = self._playerParts[LocalPlayer]
	if not myPart then
		return
	end

	task.spawn(function()
		for i = 1, 10 do
			if not myPart or not myPart.Parent then
				break
			end
			myPart.Transparency = if i % 2 == 0 then 0 else 0.5
			myPart.Size = myPart.Size * 0.9
			task.wait(0.1)
		end
		if myPart and myPart.Parent then
			myPart.Transparency = 1
		end
	end)

	self:_showPump(false)
end

function PlayerController:_clearAllParts()
	for _, part in self._playerParts do
		part:Destroy()
	end
	self._playerParts = {}
	if self._pumpPart then
		self._pumpPart:Destroy()
		self._pumpPart = nil
	end
end

function PlayerController:_onPlayerSpawned(player: Player, col: number, row: number)
	if self._playerParts[player] then
		self._playerParts[player]:Destroy()
	end

	local GridController = Knit.GetController("GridController")
	local worldPos = GridController:GridToWorld(col, row)

	local part = Instance.new("Part")
	part.Name = `Player_{player.Name}`
	part.Anchored = true
	part.CanCollide = false
	part.Size = Vector3.new(CELL_SIZE * 0.8, CELL_SIZE * 0.8, CELL_SIZE * 0.8)
	part.Position = worldPos
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Parent = workspace

	if player == LocalPlayer then
		part.Color = Color3.fromRGB(255, 255, 255)
	else
		part.Color = Color3.fromRGB(200, 200, 255)
	end

	self._playerParts[player] = part
end

function PlayerController:_onPlayerMoved(player: Player, col: number, row: number)
	local part = self._playerParts[player]
	if not part then
		return
	end

	local GridController = Knit.GetController("GridController")
	local worldPos = GridController:GridToWorld(col, row)
	part.Position = worldPos
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

	-- Check directional input (keyboard + mobile + gamepad)
	local dirX = self._touchDirX
	local dirY = self._touchDirY

	-- Keyboard
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		dirY = -1
	elseif UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		dirY = 1
	elseif UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		dirX = -1
	elseif UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		dirX = 1
	end

	-- Gamepad D-pad and thumbstick
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

	-- Pump input (Space, Z, or gamepad A, or mobile button)
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

	-- Don't move while pumping
	if self._isPumping then
		return
	end

	-- Movement with rate limiting
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
		if not self._pumpPart then
			local part = Instance.new("Part")
			part.Name = "PumpHose"
			part.Anchored = true
			part.CanCollide = false
			part.Color = Color3.fromRGB(255, 100, 100)
			part.Material = Enum.Material.Neon
			part.Transparency = 0
			part.Parent = workspace
			self._pumpPart = part
		end
		self._pumpPart.Transparency = 0
		self:_updatePumpPosition()
	else
		if self._pumpPart then
			self._pumpPart.Transparency = 1
		end
	end
end

function PlayerController:_updatePumpPosition()
	local myPart = self._playerParts[LocalPlayer]
	if not myPart or not self._pumpPart then
		return
	end

	-- Top-down: pump extends on XZ plane
	local dir3 = Vector3.new(self._facingDir.X, 0, self._facingDir.Y)
	local hoseLength = CELL_SIZE * DigDugConfig.PUMP_RANGE * 0.5

	if math.abs(self._facingDir.X) > 0 then
		-- Horizontal pump hose
		self._pumpPart.Size = Vector3.new(hoseLength, CELL_SIZE * 0.15, CELL_SIZE * 0.15)
	else
		-- Vertical pump hose (along Z axis)
		self._pumpPart.Size = Vector3.new(CELL_SIZE * 0.15, CELL_SIZE * 0.15, hoseLength)
	end

	self._pumpPart.Position = myPart.Position + dir3 * (hoseLength / 2)
end

function PlayerController:_createMobileControls()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MobileControls"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = LocalPlayer.PlayerGui

	-- D-Pad container (bottom left)
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

	-- Pump button (bottom right)
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
