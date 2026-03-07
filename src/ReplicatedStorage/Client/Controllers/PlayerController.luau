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
PlayerController._currentDir = Vector2.new(0, 0)
PlayerController._isPumping = false
PlayerController._heartbeatConn = nil :: RBXScriptConnection?
PlayerController._pumpPart = nil :: Part?

function PlayerController:KnitInit() end

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

	-- Start input loop
	self:_startInputLoop()
end

function PlayerController:_onPlayerSpawned(player: Player, col: number, row: number)
	-- Remove old part
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
		part.Color = Color3.fromRGB(255, 255, 255) -- white player
	else
		part.Color = Color3.fromRGB(200, 200, 255) -- other players slightly different
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

	-- Update pump position if active
	if player == LocalPlayer and self._pumpPart and self._pumpPart.Visible ~= false then
		self:_updatePumpPosition()
	end
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

	-- Check directional input
	local dirX = 0
	local dirY = 0

	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		dirY = -1
	elseif UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		dirY = 1
	elseif UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		dirX = -1
	elseif UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		dirX = 1
	end

	-- Pump input (Space)
	local wantsPump = UserInputService:IsKeyDown(Enum.KeyCode.Space)
	if wantsPump and not self._isPumping then
		self._isPumping = true
		local PlayerService = Knit.GetService("PlayerService")
		PlayerService:StartPump()
	elseif not wantsPump and self._isPumping then
		self._isPumping = false
		local PlayerService = Knit.GetService("PlayerService")
		PlayerService:StopPump()
	end

	-- Don't move while pumping
	if self._isPumping then
		return
	end

	-- Movement with rate limiting
	if dirX ~= 0 or dirY ~= 0 then
		self._moveTimer += dt
		if self._moveTimer >= MOVE_INTERVAL then
			self._moveTimer = 0
			local PlayerService = Knit.GetService("PlayerService")
			PlayerService:Move(dirX, dirY)
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
			part.Size = Vector3.new(CELL_SIZE * 0.2, CELL_SIZE * 0.2, CELL_SIZE * 2)
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

	-- For now, just extend in the last move direction
	-- The pump extends from the player in their facing direction
	local pumpPos = myPart.Position + Vector3.new(0, 0, 0) -- centered on player for now
	self._pumpPart.Position = pumpPos
end

return PlayerController
