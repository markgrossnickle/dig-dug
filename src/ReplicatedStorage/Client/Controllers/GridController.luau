--!strict
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local DigDugConfig = require(ReplicatedStorage.Shared.DigDugConfig)
local PlatformUtil = require(ReplicatedStorage.Shared.PlatformUtil)

local COLS = DigDugConfig.GRID_COLUMNS
local ROWS = DigDugConfig.GRID_ROWS
local CELL_SIZE = DigDugConfig.CELL_SIZE
local ORIGIN = DigDugConfig.GRID_ORIGIN
local CellType = DigDugConfig.CellType

local GridController = Knit.CreateController({
	Name = "GridController",
})

GridController._gridFolder = nil :: Folder?
GridController._cells = {} :: { { Part? } }
GridController._gridData = {} :: { { number } }
GridController._faultParts = {} :: { [string]: Part }
GridController._decorFolder = nil :: Folder?
GridController._waterBase = nil :: Part?
GridController._currentStage = 1

function GridController:KnitInit()
	self._gridData = {}
	self._cells = {}
	self._faultParts = {}
end

function GridController:KnitStart()
	local GridService = Knit.GetService("GridService")

	GridService.CellChanged:Connect(function(col: number, row: number, cellType: number)
		self:_updateCell(col, row, cellType)
	end)

	GridService.GridReset:Connect(function(gridData: { { number } }, faultData: { { any } }, stage: number)
		self._currentStage = stage
		self:_buildGrid(gridData, faultData)
	end)

	GridService.FaultDrilled:Connect(function(faultType: string, row: number, col: number)
		self:_onFaultDrilled(faultType, row, col)
	end)

	GridService.ChunkSinking:Connect(function(sinkingCells: { { number } })
		self:_onChunkSinking(sinkingCells)
	end)

	-- Clean up default workspace objects
	self:_cleanWorkspace()

	-- Set up camera immediately so the start screen looks right
	self:_setupCamera()
end

function GridController:_cleanWorkspace()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	local spawn = workspace:FindFirstChild("SpawnLocation")
	if spawn then
		spawn:Destroy()
	end

	self:_applyStageTheme(1)
end

function GridController:_applyStageTheme(stage: number)
	local themeIndex = math.ceil(stage / 2)
	themeIndex = ((themeIndex - 1) % #DigDugConfig.StageThemes) + 1
	local theme = DigDugConfig.StageThemes[themeIndex]

	Lighting.Ambient = theme.ambientColor
	Lighting.Brightness = theme.brightness
	Lighting.ClockTime = theme.clockTime
	Lighting.FogEnd = 1000
	Lighting.FogStart = 500
	Lighting.FogColor = theme.skyColor

	-- Update water base color if it exists
	if self._waterBase then
		TweenService:Create(self._waterBase, TweenInfo.new(1), {
			Color = theme.waterTint,
		}):Play()
	end
end

function GridController:GridToWorld(col: number, row: number): Vector3
	return Vector3.new(ORIGIN.X + (col - 0.5) * CELL_SIZE, 0.5, ORIGIN.Z + (row - 0.5) * CELL_SIZE)
end

function GridController:_buildGrid(gridData: { { number } }, faultData: { { any } })
	-- Clean up old grid
	if self._gridFolder then
		self._gridFolder:Destroy()
	end
	if self._decorFolder then
		self._decorFolder:Destroy()
	end

	self._gridFolder = Instance.new("Folder")
	self._gridFolder.Name = "DigDugGrid"
	self._gridFolder.Parent = workspace

	self._decorFolder = Instance.new("Folder")
	self._decorFolder.Name = "DigDugDecor"
	self._decorFolder.Parent = workspace

	self._cells = {}
	self._faultParts = {}
	self._gridData = gridData

	-- Create ocean base (large water plane beneath everything)
	self:_createOceanBase()

	-- Create grid cells on XZ plane
	for row = 1, ROWS do
		self._cells[row] = {}
		for col = 1, COLS do
			local cellType = gridData[row][col]
			self:_createCell(col, row, cellType)
		end
	end

	-- Add grass edges to island cells bordering water
	self:_createGrassEdges()

	-- Create fault line visuals
	for _, fault in faultData do
		local fType = fault[1] :: string
		local fRow = fault[2] :: number
		local fCol = fault[3] :: number
		local fState = fault[4] :: number
		self:_createFaultPart(fType, fRow, fCol, fState)
	end

	-- Scatter decorations on island
	self:_createDecorations()

	-- Apply stage theme
	self:_applyStageTheme(self._currentStage)

	-- Set up camera
	self:_setupCamera()
end

function GridController:_createOceanBase()
	local water = Instance.new("Part")
	water.Name = "OceanBase"
	water.Anchored = true
	water.CanCollide = false
	water.Size = Vector3.new((COLS + 4) * CELL_SIZE, 0.2, (ROWS + 4) * CELL_SIZE)
	water.Position = Vector3.new(ORIGIN.X + (COLS * CELL_SIZE) / 2, -0.5, ORIGIN.Z + (ROWS * CELL_SIZE) / 2)
	water.Color = DigDugConfig.WATER_COLOR
	water.Material = Enum.Material.Foil
	water.Transparency = 0.2
	water.Reflectance = 0.3
	water.Parent = self._gridFolder
	self._waterBase = water
end

function GridController:_isIslandAt(col: number, row: number): boolean
	if row < 1 or row > ROWS or col < 1 or col > COLS then
		return false
	end
	return self._gridData[row] ~= nil and self._gridData[row][col] == CellType.ISLAND
end

function GridController:_createCell(col: number, row: number, cellType: number)
	if cellType == CellType.ISLAND then
		local part = Instance.new("Part")
		part.Name = `Cell_{col}_{row}`
		part.Anchored = true
		part.Size = Vector3.new(CELL_SIZE, CELL_SIZE * 0.5, CELL_SIZE)
		part.Position = Vector3.new(ORIGIN.X + (col - 0.5) * CELL_SIZE, 0, ORIGIN.Z + (row - 0.5) * CELL_SIZE)
		part.Color = DigDugConfig.ISLAND_COLOR
		part.Material = Enum.Material.Sand
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = self._gridFolder
		self._cells[row][col] = part
	else
		-- Water cells: no part needed, ocean base shows through
		self._cells[row][col] = nil
	end
end

function GridController:_createGrassEdges()
	local isMobile = PlatformUtil.isMobile()
	for row = 1, ROWS do
		for col = 1, COLS do
			if not self:_isIslandAt(col, row) then
				continue
			end
			-- Check if this island cell borders water on any side
			local bordersWater = not self:_isIslandAt(col - 1, row)
				or not self:_isIslandAt(col + 1, row)
				or not self:_isIslandAt(col, row - 1)
				or not self:_isIslandAt(col, row + 1)

			if bordersWater then
				-- Add a grass/vegetation strip on top of this cell
				local grass = Instance.new("Part")
				grass.Name = `Grass_{col}_{row}`
				grass.Anchored = true
				grass.CanCollide = false
				grass.Size = Vector3.new(CELL_SIZE * 0.95, 0.15, CELL_SIZE * 0.95)
				grass.Position =
					Vector3.new(ORIGIN.X + (col - 0.5) * CELL_SIZE, 0.32, ORIGIN.Z + (row - 0.5) * CELL_SIZE)
				grass.Color = DigDugConfig.ISLAND_GRASS_COLOR
				grass.Material = Enum.Material.LeafyGrass
				if isMobile then
					grass.Material = Enum.Material.Grass
				end
				grass.Parent = self._gridFolder
			end
		end
	end
end

function GridController:_createDecorations()
	local isMobile = PlatformUtil.isMobile()
	local density = DigDugConfig.DECORATION_DENSITY
	if isMobile then
		density = density * 0.5
	end

	for row = 1, ROWS do
		for col = 1, COLS do
			if not self:_isIslandAt(col, row) then
				continue
			end
			-- Only decorate interior cells (not near edges, to avoid clipping)
			if
				not self:_isIslandAt(col - 1, row)
				or not self:_isIslandAt(col + 1, row)
				or not self:_isIslandAt(col, row - 1)
				or not self:_isIslandAt(col, row + 1)
			then
				continue
			end

			if math.random() < density then
				local decorType = math.random(1, 3)
				if decorType == 1 then
					self:_createFlower(col, row)
				elseif decorType == 2 then
					self:_createRock(col, row)
				else
					self:_createPalmTree(col, row)
				end
			end
		end
	end
end

function GridController:_createFlower(col: number, row: number)
	local worldPos = self:GridToWorld(col, row)
	-- Random offset within cell
	local ox = (math.random() - 0.5) * CELL_SIZE * 0.6
	local oz = (math.random() - 0.5) * CELL_SIZE * 0.6

	-- Stem
	local stem = Instance.new("Part")
	stem.Name = "FlowerStem"
	stem.Anchored = true
	stem.CanCollide = false
	stem.Size = Vector3.new(0.1, 0.6, 0.1)
	stem.Position = worldPos + Vector3.new(ox, 0.3, oz)
	stem.Color = Color3.fromRGB(40, 140, 30)
	stem.Material = Enum.Material.SmoothPlastic
	stem.Parent = self._decorFolder

	-- Petals (small sphere on top)
	local petal = Instance.new("Part")
	petal.Name = "FlowerPetal"
	petal.Anchored = true
	petal.CanCollide = false
	petal.Shape = Enum.PartType.Ball
	petal.Size = Vector3.new(0.5, 0.5, 0.5)
	petal.Position = worldPos + Vector3.new(ox, 0.65, oz)
	local flowerColors = {
		Color3.fromRGB(255, 80, 80),
		Color3.fromRGB(255, 200, 50),
		Color3.fromRGB(255, 100, 200),
		Color3.fromRGB(255, 255, 100),
	}
	petal.Color = flowerColors[math.random(1, #flowerColors)]
	petal.Material = Enum.Material.SmoothPlastic
	petal.Parent = self._decorFolder
end

function GridController:_createRock(col: number, row: number)
	local worldPos = self:GridToWorld(col, row)
	local ox = (math.random() - 0.5) * CELL_SIZE * 0.5
	local oz = (math.random() - 0.5) * CELL_SIZE * 0.5
	local size = 0.3 + math.random() * 0.4

	local rock = Instance.new("Part")
	rock.Name = "DecorRock"
	rock.Anchored = true
	rock.CanCollide = false
	rock.Size = Vector3.new(size * 1.2, size * 0.7, size)
	rock.Position = worldPos + Vector3.new(ox, 0.1, oz)
	rock.Color = Color3.fromRGB(140 + math.random(0, 30), 130 + math.random(0, 30), 120 + math.random(0, 30))
	rock.Material = Enum.Material.Slate
	rock.Parent = self._decorFolder
end

function GridController:_createPalmTree(col: number, row: number)
	local worldPos = self:GridToWorld(col, row)
	local ox = (math.random() - 0.5) * CELL_SIZE * 0.3
	local oz = (math.random() - 0.5) * CELL_SIZE * 0.3
	local basePos = worldPos + Vector3.new(ox, 0, oz)

	-- Trunk (brown cylinder)
	local trunk = Instance.new("Part")
	trunk.Name = "PalmTrunk"
	trunk.Anchored = true
	trunk.CanCollide = false
	trunk.Shape = Enum.PartType.Cylinder
	-- Cylinder: Size.Y = length (along axis), rotated to be vertical
	trunk.Size = Vector3.new(0.4, 2.5, 0.4)
	trunk.CFrame = CFrame.new(basePos + Vector3.new(0, 1.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	trunk.Color = Color3.fromRGB(120, 80, 40)
	trunk.Material = Enum.Material.WoodPlanks
	trunk.Parent = self._decorFolder

	-- Fronds (green ellipsoids radiating from top)
	for i = 1, 4 do
		local frond = Instance.new("Part")
		frond.Name = "PalmFrond"
		frond.Anchored = true
		frond.CanCollide = false
		frond.Size = Vector3.new(1.8, 0.15, 0.6)
		local angle = (i / 4) * math.pi * 2 + math.random() * 0.3
		local frondX = math.cos(angle) * 0.7
		local frondZ = math.sin(angle) * 0.7
		frond.CFrame = CFrame.new(basePos + Vector3.new(frondX, 2.3, frondZ)) * CFrame.Angles(0, angle, math.rad(-20))
		frond.Color = Color3.fromRGB(40, 150 + math.random(0, 30), 30)
		frond.Material = Enum.Material.Grass
		frond.Parent = self._decorFolder
	end
end

function GridController:_updateCell(col: number, row: number, cellType: number)
	local part = self._cells[row] and self._cells[row][col]

	if cellType == CellType.ISLAND then
		if part then
			part.Color = DigDugConfig.ISLAND_COLOR
			part.Material = Enum.Material.Sand
			part.Position = Vector3.new(ORIGIN.X + (col - 0.5) * CELL_SIZE, 0, ORIGIN.Z + (row - 0.5) * CELL_SIZE)
			part.Transparency = 0
		end
	elseif cellType == CellType.SUNK then
		if part then
			part.Color = DigDugConfig.SUNK_COLOR
			part.Material = Enum.Material.Sand
			part.Transparency = 0.3
		end
	else -- WATER
		if part then
			part.Transparency = 1
		end
	end
end

function GridController:_createFaultPart(fType: string, row: number, col: number, state: number)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false

	local faultThickness = CELL_SIZE * 0.12

	if fType == "h" then
		part.Name = `Fault_h_{row}_{col}`
		part.Size = Vector3.new(CELL_SIZE * 0.85, faultThickness, faultThickness)
		part.Position = Vector3.new(ORIGIN.X + (col - 0.5) * CELL_SIZE, 0.35, ORIGIN.Z + row * CELL_SIZE)
	else
		part.Name = `Fault_v_{row}_{col}`
		part.Size = Vector3.new(faultThickness, faultThickness, CELL_SIZE * 0.85)
		part.Position = Vector3.new(ORIGIN.X + col * CELL_SIZE, 0.35, ORIGIN.Z + (row - 0.5) * CELL_SIZE)
	end

	if state == DigDugConfig.FaultState.DRILLED then
		part.Color = DigDugConfig.FAULT_DRILLED_COLOR
		part.Material = Enum.Material.Neon
	else
		part.Color = DigDugConfig.FAULT_INTACT_COLOR
		part.Material = Enum.Material.Slate
	end

	part.Parent = self._gridFolder

	local key = `{fType}_{row}_{col}`
	self._faultParts[key] = part
end

function GridController:_onFaultDrilled(faultType: string, row: number, col: number)
	local typeKey = if faultType == "horizontal" then "h" else "v"
	local key = `{typeKey}_{row}_{col}`
	local part = self._faultParts[key]
	if part then
		part.Color = DigDugConfig.FAULT_DRILLED_COLOR
		part.Material = Enum.Material.Neon

		-- Flash effect on drill
		task.spawn(function()
			local origSize = part.Size
			part.Size = origSize * 1.5
			task.wait(0.1)
			if part and part.Parent then
				part.Size = origSize
			end
		end)
	end
end

function GridController:_onChunkSinking(sinkingCells: { { number } })
	-- Spawn splash particles at chunk edges
	self:_spawnSplashParticles(sinkingCells)

	for _, cell in sinkingCells do
		local col, row = cell[1], cell[2]
		local part = self._cells[row] and self._cells[row][col]
		if part then
			local targetPos = part.Position - Vector3.new(0, 3, 0)
			local tweenInfo =
				TweenInfo.new(DigDugConfig.CHUNK_SINK_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local tween = TweenService:Create(part, tweenInfo, {
				Position = targetPos,
				Transparency = 0.9,
			})
			tween:Play()

			-- After sink, hide the cell (ocean base shows through)
			task.delay(DigDugConfig.CHUNK_SINK_TIME + 0.1, function()
				if part and part.Parent then
					part.Transparency = 1
				end
			end)
		end

		-- Remove fault parts near sinking cells
		for _key, faultPart in self._faultParts do
			local faultPos = faultPart.Position
			local cellWorldX = ORIGIN.X + (col - 0.5) * CELL_SIZE
			local cellWorldZ = ORIGIN.Z + (row - 0.5) * CELL_SIZE
			local dist = math.abs(faultPos.X - cellWorldX) + math.abs(faultPos.Z - cellWorldZ)
			if dist < CELL_SIZE * 1.1 then
				task.delay(DigDugConfig.CHUNK_SINK_TIME * 0.5, function()
					if faultPart and faultPart.Parent then
						faultPart:Destroy()
					end
				end)
			end
		end
	end

	-- Destroy decorations near sinking cells
	if self._decorFolder then
		for _, cell in sinkingCells do
			local col, row = cell[1], cell[2]
			local cellWorldX = ORIGIN.X + (col - 0.5) * CELL_SIZE
			local cellWorldZ = ORIGIN.Z + (row - 0.5) * CELL_SIZE
			for _, decor in self._decorFolder:GetChildren() do
				if decor:IsA("BasePart") then
					local dx = math.abs(decor.Position.X - cellWorldX)
					local dz = math.abs(decor.Position.Z - cellWorldZ)
					if dx < CELL_SIZE * 0.6 and dz < CELL_SIZE * 0.6 then
						task.delay(DigDugConfig.CHUNK_SINK_TIME * 0.3, function()
							if decor and decor.Parent then
								decor:Destroy()
							end
						end)
					end
				end
			end
		end
	end
end

function GridController:_spawnSplashParticles(sinkingCells: { { number } })
	local count = math.floor(3 * PlatformUtil.getParticleMultiplier())
	if count < 1 then
		return
	end

	-- Find edge cells (cells bordering water)
	for _, cell in sinkingCells do
		local col, row = cell[1], cell[2]
		local isEdge = not self:_isIslandAt(col - 1, row)
			or not self:_isIslandAt(col + 1, row)
			or not self:_isIslandAt(col, row - 1)
			or not self:_isIslandAt(col, row + 1)
		if not isEdge then
			continue
		end

		local worldPos = self:GridToWorld(col, row)
		for i = 1, count do
			local splash = Instance.new("Part")
			splash.Name = "Splash"
			splash.Anchored = true
			splash.CanCollide = false
			splash.Shape = Enum.PartType.Ball
			splash.Size = Vector3.new(0.4, 0.4, 0.4)
			splash.Position = worldPos
			splash.Color = Color3.fromRGB(180, 220, 255)
			splash.Material = Enum.Material.Neon
			splash.Transparency = 0.3
			splash.Parent = workspace

			local angle = (i / count) * math.pi * 2
			local velX = math.cos(angle) * 4
			local velZ = math.sin(angle) * 4

			task.spawn(function()
				for step = 1, 10 do
					if not splash or not splash.Parent then
						break
					end
					splash.Position = splash.Position + Vector3.new(velX * 0.02, 0.15 - step * 0.03, velZ * 0.02)
					splash.Transparency = 0.3 + (step / 10) * 0.7
					splash.Size = splash.Size * 0.92
					task.wait(0.03)
				end
				if splash and splash.Parent then
					splash:Destroy()
				end
			end)
		end
	end
end

function GridController:_setupCamera()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local centerX = ORIGIN.X + (COLS * CELL_SIZE) / 2
	local centerZ = ORIGIN.Z + (ROWS * CELL_SIZE) / 2

	-- Calculate distance to fit the grid
	local gridSize = math.max(COLS, ROWS) * CELL_SIZE
	local viewportSize = camera.ViewportSize
	local aspect = viewportSize.X / math.max(viewportSize.Y, 1)

	local distance
	if aspect < 1 then
		distance = gridSize / (2 * math.tan(math.rad(camera.FieldOfView / 2)) * aspect)
	else
		local distByWidth = gridSize / (2 * math.tan(math.rad(camera.FieldOfView / 2)) * aspect)
		local distByHeight = gridSize / (2 * math.tan(math.rad(camera.FieldOfView / 2)))
		distance = math.max(distByHeight, distByWidth)
	end
	distance = distance * 1.15

	camera.CameraType = Enum.CameraType.Scriptable
	-- Slight angle (15 degrees from vertical) for depth perception
	local angle = math.rad(15)
	local camY = distance * math.cos(angle)
	local camOffset = distance * math.sin(angle)
	camera.CFrame = CFrame.new(Vector3.new(centerX, camY, centerZ + camOffset), Vector3.new(centerX, 0, centerZ))
end

return GridController
