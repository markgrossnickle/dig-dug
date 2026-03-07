--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local DigDugConfig = require(ReplicatedStorage.Shared.DigDugConfig)

local CELL_SIZE = DigDugConfig.CELL_SIZE

local EnemyController = Knit.CreateController({
	Name = "EnemyController",
})

EnemyController._enemyParts = {} :: { [number]: Part }
EnemyController._enemyFolder = nil :: Folder?

function EnemyController:KnitInit()
	self._enemyParts = {}
end

function EnemyController:KnitStart()
	local EnemyService = Knit.GetService("EnemyService")

	EnemyService.EnemySpawned:Connect(function(id: number, enemyType: string, col: number, row: number)
		self:_onEnemySpawned(id, enemyType, col, row)
	end)

	EnemyService.EnemyMoved:Connect(function(id: number, col: number, row: number)
		self:_onEnemyMoved(id, col, row)
	end)

	EnemyService.EnemyInflated:Connect(function(id: number, inflateLevel: number)
		self:_onEnemyInflated(id, inflateLevel)
	end)

	EnemyService.EnemyPopped:Connect(function(id: number)
		self:_onEnemyDefeated(id)
	end)

	EnemyService.EnemyCrushed:Connect(function(id: number)
		self:_onEnemyDefeated(id)
	end)

	EnemyService.FygarFire:Connect(function(enemyId: number, col: number, row: number, dirX: number, range: number)
		self:_onFygarFire(enemyId, col, row, dirX, range)
	end)

	-- Clean up enemies on grid reset
	local GridService = Knit.GetService("GridService")
	GridService.GridReset:Connect(function()
		self:_clearAll()
	end)
end

function EnemyController:_clearAll()
	for _, part in self._enemyParts do
		part:Destroy()
	end
	self._enemyParts = {}
	if self._enemyFolder then
		self._enemyFolder:Destroy()
	end
	self._enemyFolder = Instance.new("Folder")
	self._enemyFolder.Name = "DigDugEnemies"
	self._enemyFolder.Parent = workspace
end

function EnemyController:_onEnemySpawned(id: number, enemyType: string, col: number, row: number)
	if not self._enemyFolder then
		self._enemyFolder = Instance.new("Folder")
		self._enemyFolder.Name = "DigDugEnemies"
		self._enemyFolder.Parent = workspace
	end

	local GridController = Knit.GetController("GridController")
	local worldPos = GridController:GridToWorld(col, row)

	local part = Instance.new("Part")
	part.Name = `Enemy_{id}`
	part.Anchored = true
	part.CanCollide = false
	part.Size = Vector3.new(CELL_SIZE * 0.8, CELL_SIZE * 0.8, CELL_SIZE * 0.8)
	part.Position = worldPos
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon

	if enemyType == DigDugConfig.EnemyType.POOKA then
		part.Color = Color3.fromRGB(255, 50, 50) -- red for Pooka
	else
		part.Color = Color3.fromRGB(50, 200, 50) -- green for Fygar
	end

	part.Parent = self._enemyFolder
	self._enemyParts[id] = part
end

function EnemyController:_onEnemyMoved(id: number, col: number, row: number)
	local part = self._enemyParts[id]
	if not part then
		return
	end

	local GridController = Knit.GetController("GridController")
	local worldPos = GridController:GridToWorld(col, row)
	part.Position = worldPos
end

function EnemyController:_onEnemyInflated(id: number, inflateLevel: number)
	local part = self._enemyParts[id]
	if not part then
		return
	end

	-- Scale up the enemy as it inflates
	local scale = 1 + (inflateLevel * 0.2)
	part.Size = Vector3.new(CELL_SIZE * 0.8 * scale, CELL_SIZE * 0.8 * scale, CELL_SIZE * 0.8 * scale)

	-- Change color to indicate inflation
	local baseColor = part.Color
	local whiteBlend = inflateLevel / DigDugConfig.PUMP_POPS_REQUIRED
	part.Color = baseColor:Lerp(Color3.new(1, 1, 1), whiteBlend * 0.5)
end

function EnemyController:_onEnemyDefeated(id: number)
	local part = self._enemyParts[id]
	if not part then
		return
	end

	local deathPos = part.Position

	-- Quick pop animation
	task.spawn(function()
		for i = 1, 5 do
			if not part or not part.Parent then
				break
			end
			part.Size = part.Size * 1.1
			part.Transparency = i / 5
			task.wait(0.05)
		end
		if part and part.Parent then
			part:Destroy()
		end

		-- Show score popup at death position
		self:_showScorePopup(deathPos)
	end)

	self._enemyParts[id] = nil
end

function EnemyController:_showScorePopup(worldPos: Vector3)
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Size = UDim2.new(0, 80, 0, 40)
	billboardGui.StudsOffset = Vector3.new(0, 2, 0)
	billboardGui.AlwaysOnTop = true

	local anchor = Instance.new("Part")
	anchor.Name = "ScorePopup"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = worldPos
	anchor.Parent = workspace

	billboardGui.Parent = anchor
	billboardGui.Adornee = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 0)
	label.TextSize = 18
	label.Font = Enum.Font.Arcade
	label.Text = "POP!"
	label.Parent = billboardGui

	-- Float up and fade
	task.spawn(function()
		for i = 1, 20 do
			anchor.Position = anchor.Position + Vector3.new(0, 0.1, 0)
			label.TextTransparency = i / 20
			task.wait(0.03)
		end
		anchor:Destroy()
	end)
end

function EnemyController:_onFygarFire(_enemyId: number, col: number, row: number, dirX: number, range: number)
	local GridController = Knit.GetController("GridController")

	-- Create fire effect parts
	task.spawn(function()
		local fireParts = {}
		for i = 1, range do
			local fireCol = col + dirX * i
			local worldPos = GridController:GridToWorld(fireCol, row)

			local fire = Instance.new("Part")
			fire.Name = "FygarFire"
			fire.Anchored = true
			fire.CanCollide = false
			fire.Size = Vector3.new(CELL_SIZE * 0.7, CELL_SIZE * 0.5, CELL_SIZE * 0.5)
			fire.Position = worldPos
			fire.Color = Color3.fromRGB(255, 150, 0)
			fire.Material = Enum.Material.Neon
			fire.Transparency = 0.2
			fire.Parent = workspace
			table.insert(fireParts, fire)
			task.wait(0.05)
		end

		-- Hold fire for a moment then fade
		task.wait(0.3)
		for _, fire in fireParts do
			if fire and fire.Parent then
				fire:Destroy()
			end
		end
	end)
end

return EnemyController
