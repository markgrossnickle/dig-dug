--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local DigDugConfig = require(ReplicatedStorage.Shared.DigDugConfig)
local PlatformUtil = require(ReplicatedStorage.Shared.PlatformUtil)

local CELL_SIZE = DigDugConfig.CELL_SIZE

local EnemyController = Knit.CreateController({
	Name = "EnemyController",
})

EnemyController._enemyModels = {} :: { [number]: Model }
EnemyController._enemyTypes = {} :: { [number]: string }
EnemyController._enemyFolder = nil :: Folder?

function EnemyController:KnitInit()
	self._enemyModels = {}
	self._enemyTypes = {}
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
		self:_onEnemyDefeated(id, false)
	end)

	EnemyService.EnemyChunkKilled:Connect(function(id: number)
		self:_onEnemyDefeated(id, true)
	end)

	EnemyService.EnemyDefeated:Connect(function(id: number)
		self:_onEnemyDefeated(id, false)
	end)

	EnemyService.FygarFire:Connect(function(enemyId: number, col: number, row: number, dirX: number, range: number)
		self:_onFygarFire(enemyId, col, row, dirX, range)
	end)

	EnemyService.EnemyFleeing:Connect(function(id: number)
		self:_onEnemyFleeing(id)
	end)

	local GridService = Knit.GetService("GridService")
	GridService.GridReset:Connect(function()
		self:_clearAll()
	end)
end

function EnemyController:_clearAll()
	for _, model in self._enemyModels do
		model:Destroy()
	end
	self._enemyModels = {}
	self._enemyTypes = {}
	if self._enemyFolder then
		self._enemyFolder:Destroy()
	end
	self._enemyFolder = Instance.new("Folder")
	self._enemyFolder.Name = "DigDugEnemies"
	self._enemyFolder.Parent = workspace
end

function EnemyController:_ensureFolder()
	if not self._enemyFolder then
		self._enemyFolder = Instance.new("Folder")
		self._enemyFolder.Name = "DigDugEnemies"
		self._enemyFolder.Parent = workspace
	end
end

function EnemyController:_onEnemySpawned(id: number, enemyType: string, col: number, row: number)
	self:_ensureFolder()

	local GridController = Knit.GetController("GridController")
	local worldPos = GridController:GridToWorld(col, row)

	local model: Model
	if enemyType == DigDugConfig.EnemyType.POOKA then
		model = self:_buildPookaModel(id, worldPos)
	else
		model = self:_buildFygarModel(id, worldPos)
	end

	model.Parent = self._enemyFolder
	self._enemyModels[id] = model
	self._enemyTypes[id] = enemyType
end

function EnemyController:_buildPookaModel(id: number, worldPos: Vector3): Model
	local model = Instance.new("Model")
	model.Name = `Enemy_{id}`
	local s = CELL_SIZE * 0.35

	-- Body (red sphere)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(s * 2.2, s * 2.2, s * 2.2)
	body.Position = worldPos + Vector3.new(0, s * 1.1, 0)
	body.Color = DigDugConfig.POOKA_COLOR
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = model

	-- Left goggle
	local leftGoggle = Instance.new("Part")
	leftGoggle.Name = "LeftGoggle"
	leftGoggle.Anchored = true
	leftGoggle.CanCollide = false
	leftGoggle.Shape = Enum.PartType.Ball
	leftGoggle.Size = Vector3.new(s * 0.65, s * 0.65, s * 0.3)
	leftGoggle.Position = worldPos + Vector3.new(-s * 0.4, s * 1.4, -s * 0.9)
	leftGoggle.Color = DigDugConfig.POOKA_GOGGLE_COLOR
	leftGoggle.Material = Enum.Material.Neon
	leftGoggle.Parent = model

	-- Right goggle
	local rightGoggle = Instance.new("Part")
	rightGoggle.Name = "RightGoggle"
	rightGoggle.Anchored = true
	rightGoggle.CanCollide = false
	rightGoggle.Shape = Enum.PartType.Ball
	rightGoggle.Size = Vector3.new(s * 0.65, s * 0.65, s * 0.3)
	rightGoggle.Position = worldPos + Vector3.new(s * 0.4, s * 1.4, -s * 0.9)
	rightGoggle.Color = DigDugConfig.POOKA_GOGGLE_COLOR
	rightGoggle.Material = Enum.Material.Neon
	rightGoggle.Parent = model

	-- Goggle strap (thin bar across head)
	local strap = Instance.new("Part")
	strap.Name = "Strap"
	strap.Anchored = true
	strap.CanCollide = false
	strap.Size = Vector3.new(s * 2.0, s * 0.15, s * 0.1)
	strap.Position = worldPos + Vector3.new(0, s * 1.5, -s * 0.5)
	strap.Color = DigDugConfig.POOKA_GOGGLE_COLOR
	strap.Material = Enum.Material.SmoothPlastic
	strap.Parent = model

	-- Feet (two small parts at bottom)
	for _, side in { -1, 1 } do
		local foot = Instance.new("Part")
		foot.Name = if side == -1 then "LeftFoot" else "RightFoot"
		foot.Anchored = true
		foot.CanCollide = false
		foot.Shape = Enum.PartType.Ball
		foot.Size = Vector3.new(s * 0.5, s * 0.35, s * 0.5)
		foot.Position = worldPos + Vector3.new(side * s * 0.45, s * -0.1, 0)
		foot.Color = Color3.fromRGB(180, 30, 30)
		foot.Material = Enum.Material.SmoothPlastic
		foot.Parent = model
	end

	model.PrimaryPart = body
	return model
end

function EnemyController:_buildFygarModel(id: number, worldPos: Vector3): Model
	local model = Instance.new("Model")
	model.Name = `Enemy_{id}`
	local s = CELL_SIZE * 0.35

	-- Body (green oblong)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.Size = Vector3.new(s * 2.4, s * 1.6, s * 1.8)
	body.Position = worldPos + Vector3.new(0, s * 0.8, 0)
	body.Color = DigDugConfig.FYGAR_COLOR
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = model

	-- Belly (lighter green/yellow underside)
	local belly = Instance.new("Part")
	belly.Name = "Belly"
	belly.Anchored = true
	belly.CanCollide = false
	belly.Size = Vector3.new(s * 1.8, s * 0.6, s * 1.2)
	belly.Position = worldPos + Vector3.new(0, s * 0.3, 0)
	belly.Color = DigDugConfig.FYGAR_BELLY_COLOR
	belly.Material = Enum.Material.SmoothPlastic
	belly.Parent = model

	-- Head/snout (sphere at front)
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Anchored = true
	head.CanCollide = false
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(s * 1.2, s * 1.2, s * 1.0)
	head.Position = worldPos + Vector3.new(0, s * 1.3, -s * 1.0)
	head.Color = DigDugConfig.FYGAR_COLOR
	head.Material = Enum.Material.SmoothPlastic
	head.Parent = model

	-- Eyes (red/orange, menacing)
	for _, side in { -1, 1 } do
		local eye = Instance.new("Part")
		eye.Name = if side == -1 then "LeftEye" else "RightEye"
		eye.Anchored = true
		eye.CanCollide = false
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(s * 0.35, s * 0.35, s * 0.2)
		eye.Position = worldPos + Vector3.new(side * s * 0.35, s * 1.5, -s * 1.3)
		eye.Color = Color3.fromRGB(255, 100, 0)
		eye.Material = Enum.Material.Neon
		eye.Parent = model
	end

	-- Wings (small flaps on sides)
	for _, side in { -1, 1 } do
		local wing = Instance.new("Part")
		wing.Name = if side == -1 then "LeftWing" else "RightWing"
		wing.Anchored = true
		wing.CanCollide = false
		wing.Size = Vector3.new(s * 0.15, s * 0.8, s * 1.0)
		wing.Position = worldPos + Vector3.new(side * s * 1.3, s * 1.0, s * 0.1)
		wing.Color = Color3.fromRGB(30, 130, 30)
		wing.Material = Enum.Material.SmoothPlastic
		wing.Parent = model
	end

	-- Tail
	local tail = Instance.new("Part")
	tail.Name = "Tail"
	tail.Anchored = true
	tail.CanCollide = false
	tail.Size = Vector3.new(s * 0.5, s * 0.4, s * 0.8)
	tail.Position = worldPos + Vector3.new(0, s * 0.9, s * 1.1)
	tail.Color = DigDugConfig.FYGAR_COLOR
	tail.Material = Enum.Material.SmoothPlastic
	tail.Parent = model

	model.PrimaryPart = body
	return model
end

function EnemyController:_moveModelTo(model: Model, worldPos: Vector3)
	if not model.PrimaryPart then
		return
	end
	local body = model.PrimaryPart
	local s = CELL_SIZE * 0.35
	-- Expected body center offset depends on enemy type
	local expectedY = if body.Shape == Enum.PartType.Ball then s * 1.1 else s * 0.8
	local targetBodyPos = worldPos + Vector3.new(0, expectedY, 0)
	local offset = targetBodyPos - body.Position

	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			part.Position = part.Position + offset
		end
	end
end

function EnemyController:_onEnemyMoved(id: number, col: number, row: number)
	local model = self._enemyModels[id]
	if not model then
		return
	end

	local GridController = Knit.GetController("GridController")
	local worldPos = GridController:GridToWorld(col, row)
	self:_moveModelTo(model, worldPos)
end

function EnemyController:_onEnemyInflated(id: number, inflateLevel: number)
	local model = self._enemyModels[id]
	if not model or not model.PrimaryPart then
		return
	end

	local scale = 1 + (inflateLevel * 0.25)
	local whiteBlend = inflateLevel / DigDugConfig.PUMP_POPS_REQUIRED

	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			-- Scale up from current size
			local baseSize = part:GetAttribute("OrigSize") :: Vector3?
			if not baseSize then
				part:SetAttribute("OrigSize", part.Size)
				baseSize = part.Size
			end
			part.Size = baseSize * scale

			-- Blend toward white
			local origColor = part:GetAttribute("OrigColor") :: Color3?
			if not origColor then
				part:SetAttribute("OrigColor", part.Color)
				origColor = part.Color
			end
			part.Color = origColor:Lerp(Color3.new(1, 1, 1), whiteBlend * 0.6)
		end
	end
end

function EnemyController:_onEnemyFleeing(id: number)
	local model = self._enemyModels[id]
	if not model then
		return
	end

	task.spawn(function()
		local toggle = false
		while model and model.Parent do
			toggle = not toggle
			for _, part in model:GetChildren() do
				if part:IsA("BasePart") then
					if toggle then
						part.Color = Color3.fromRGB(255, 180, 255)
					else
						local origColor = part:GetAttribute("OrigColor") :: Color3?
						if origColor then
							part.Color = origColor
						end
					end
				end
			end
			task.wait(0.2)
		end
	end)
end

function EnemyController:_onEnemyDefeated(id: number, chunkKill: boolean)
	local model = self._enemyModels[id]
	if not model or not model.PrimaryPart then
		self._enemyModels[id] = nil
		self._enemyTypes[id] = nil
		return
	end

	local deathPos = model.PrimaryPart.Position
	local deathColor = model.PrimaryPart.Color

	if chunkKill then
		-- Sink with chunk
		task.spawn(function()
			for i = 1, 15 do
				for _, part in model:GetChildren() do
					if part:IsA("BasePart") then
						part.Position = part.Position - Vector3.new(0, 0.2, 0)
						part.Transparency = i / 15
					end
				end
				task.wait(0.06)
			end
			if model and model.Parent then
				model:Destroy()
			end
		end)
	else
		-- Pop animation: expand all parts, then burst
		task.spawn(function()
			for i = 1, 5 do
				for _, part in model:GetChildren() do
					if part:IsA("BasePart") then
						part.Size = part.Size * 1.15
						part.Transparency = i / 5
					end
				end
				task.wait(0.05)
			end
			if model and model.Parent then
				model:Destroy()
			end

			self:_spawnPopParticles(deathPos, deathColor)
			self:_showScorePopup(deathPos)
		end)
	end

	self._enemyModels[id] = nil
	self._enemyTypes[id] = nil
end

function EnemyController:_spawnPopParticles(pos: Vector3, color: Color3)
	local count = math.floor(8 * PlatformUtil.getParticleMultiplier())
	for i = 1, count do
		local particle = Instance.new("Part")
		particle.Name = "PopParticle"
		particle.Anchored = true
		particle.CanCollide = false
		particle.Size = Vector3.new(0.5, 0.5, 0.5)
		particle.Position = pos
		particle.Color = color
		particle.Material = Enum.Material.Neon
		particle.Shape = Enum.PartType.Ball
		particle.Parent = workspace

		local angle = (i / count) * math.pi * 2
		local velX = math.cos(angle) * 6
		local velZ = math.sin(angle) * 6

		task.spawn(function()
			for step = 1, 12 do
				if not particle or not particle.Parent then
					break
				end
				particle.Position = particle.Position + Vector3.new(velX * 0.02, 0.1, velZ * 0.02)
				particle.Transparency = step / 12
				particle.Size = particle.Size * 0.9
				task.wait(0.03)
			end
			if particle and particle.Parent then
				particle:Destroy()
			end
		end)
	end
end

function EnemyController:_showScorePopup(worldPos: Vector3)
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Size = UDim2.new(0, 80, 0, 40)
	billboardGui.StudsOffset = Vector3.new(0, 4, 0)
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
	label.TextSize = 22
	label.Font = Enum.Font.Arcade
	label.Text = "POP!"
	label.TextStrokeTransparency = 0.5
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Parent = billboardGui

	task.spawn(function()
		for i = 1, 20 do
			anchor.Position = anchor.Position + Vector3.new(0, 0.15, 0)
			label.TextTransparency = i / 20
			label.TextStrokeTransparency = 0.5 + (i / 20) * 0.5
			task.wait(0.03)
		end
		anchor:Destroy()
	end)
end

function EnemyController:_onFygarFire(_enemyId: number, col: number, row: number, dirX: number, range: number)
	local GridController = Knit.GetController("GridController")

	local fireColors = {
		Color3.fromRGB(255, 220, 50),
		Color3.fromRGB(255, 140, 0),
		Color3.fromRGB(220, 50, 0),
	}

	task.spawn(function()
		local fireParts = {}
		for i = 1, range do
			local fireCol = col + dirX * i
			local worldPos = GridController:GridToWorld(fireCol, row)

			local fireLayers = if PlatformUtil.isMobile() then 1 else 3
			for j = 1, fireLayers do
				local fire = Instance.new("Part")
				fire.Name = "FygarFire"
				fire.Anchored = true
				fire.CanCollide = false
				local scale = 1.1 - (j * 0.2)
				fire.Size = Vector3.new(CELL_SIZE * 0.7 * scale, CELL_SIZE * 0.5 * scale, CELL_SIZE * 0.5 * scale)
				fire.Position = worldPos + Vector3.new(0, (j - 1) * 0.3 + 0.5, 0)
				fire.Color = fireColors[j]
				fire.Material = Enum.Material.Neon
				fire.Transparency = 0.1 + (j * 0.1)
				fire.Parent = workspace
				table.insert(fireParts, fire)
			end
			task.wait(0.05)
		end

		task.wait(0.3)
		for step = 1, 5 do
			for _, fire in fireParts do
				if fire and fire.Parent then
					fire.Transparency = step / 5
				end
			end
			task.wait(0.04)
		end
		for _, fire in fireParts do
			if fire and fire.Parent then
				fire:Destroy()
			end
		end
	end)
end

return EnemyController
