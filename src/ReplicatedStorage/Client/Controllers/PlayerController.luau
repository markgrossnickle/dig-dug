--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local DigDugConfig = require(ReplicatedStorage.Shared.DigDugConfig)

local LocalPlayer = Players.LocalPlayer
local CELL_SIZE = DigDugConfig.CELL_SIZE
local MOVE_INTERVAL = 1 / DigDugConfig.PLAYER_SPEED

local PlayerController = Knit.CreateController({
	Name = "PlayerController",
})

PlayerController._playerParts = {} :: { [Player]: Part }
PlayerController._moveTimer = 0
PlayerController._facingDir = Vector2.new(1, 0) -- default facing right
PlayerController._isPumping = false
PlayerController._heartbeatConn = nil :: RBXScriptConnection?
PlayerController._pumpPart = nil :: Part?
PlayerController._touchDirX = 0
PlayerController._touchDirY = 0
PlayerController._touchPump = false

function PlayerController:KnitInit()
	-- Create mobile controls if on touch device
	if UserInputService.TouchEnabled then
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

	-- Start input loop
	self:_startInputLoop()
end

function PlayerController:_onDeath()
	local myPart = self._playerParts[LocalPlayer]
	if not myPart then
		return
	end

	-- Flash and shrink animation
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

	-- Hide pump
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
	-- Remove old part for this player
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

function PlayerController:_handleInput(dt: number)
	local GameController = Knit.GetController("GameController")
	if GameController._state ~= "Playing" then
		return
	end

	-- Check directional input (keyboard + mobile)
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

	-- Pump input (Space or mobile button)
	local wantsPump = UserInputService:IsKeyDown(Enum.KeyCode.Space) or self._touchPump
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
		-- Track facing direction
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
		self._moveTimer = MOVE_INTERVAL -- allow immediate move on next press
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

	-- Extend pump hose in facing direction
	local dir3 = Vector3.new(self._facingDir.X, -self._facingDir.Y, 0)
	local hoseLength = CELL_SIZE * DigDugConfig.PUMP_RANGE * 0.5

	-- Orient the hose in the facing direction
	if math.abs(self._facingDir.X) > 0 then
		-- Horizontal
		self._pumpPart.Size = Vector3.new(hoseLength, CELL_SIZE * 0.15, CELL_SIZE * 0.15)
	else
		-- Vertical
		self._pumpPart.Size = Vector3.new(CELL_SIZE * 0.15, hoseLength, CELL_SIZE * 0.15)
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
	dpad.Size = UDim2.new(0, 180, 0, 180)
	dpad.Position = UDim2.new(0, 20, 1, -200)
	dpad.BackgroundTransparency = 1
	dpad.Parent = gui

	local directions = {
		{ name = "Up", pos = UDim2.new(0.5, -30, 0, 0), size = UDim2.new(0, 60, 0, 60), dx = 0, dy = -1 },
		{ name = "Down", pos = UDim2.new(0.5, -30, 1, -60), size = UDim2.new(0, 60, 0, 60), dx = 0, dy = 1 },
		{ name = "Left", pos = UDim2.new(0, 0, 0.5, -30), size = UDim2.new(0, 60, 0, 60), dx = -1, dy = 0 },
		{ name = "Right", pos = UDim2.new(1, -60, 0.5, -30), size = UDim2.new(0, 60, 0, 60), dx = 1, dy = 0 },
	}

	for _, dir in directions do
		local btn = Instance.new("TextButton")
		btn.Name = dir.name
		btn.Size = dir.size
		btn.Position = dir.pos
		btn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		btn.BackgroundTransparency = 0.5
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.TextSize = 24
		btn.Font = Enum.Font.Arcade
		btn.Text = dir.name:sub(1, 1)
		btn.Parent = dpad

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = btn

		btn.MouseButton1Down:Connect(function()
			self._touchDirX = dir.dx
			self._touchDirY = dir.dy
		end)
		btn.MouseButton1Up:Connect(function()
			if self._touchDirX == dir.dx and self._touchDirY == dir.dy then
				self._touchDirX = 0
				self._touchDirY = 0
			end
		end)
	end

	-- Pump button (bottom right)
	local pumpBtn = Instance.new("TextButton")
	pumpBtn.Name = "PumpButton"
	pumpBtn.Size = UDim2.new(0, 80, 0, 80)
	pumpBtn.Position = UDim2.new(1, -100, 1, -150)
	pumpBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	pumpBtn.BackgroundTransparency = 0.3
	pumpBtn.TextColor3 = Color3.new(1, 1, 1)
	pumpBtn.TextSize = 20
	pumpBtn.Font = Enum.Font.Arcade
	pumpBtn.Text = "PUMP"
	pumpBtn.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 40)
	corner.Parent = pumpBtn

	pumpBtn.MouseButton1Down:Connect(function()
		self._touchPump = true
	end)
	pumpBtn.MouseButton1Up:Connect(function()
		self._touchPump = false
	end)
end

return PlayerController
