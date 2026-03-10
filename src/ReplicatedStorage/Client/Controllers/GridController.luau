--!strict
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local DigDugConfig = require(ReplicatedStorage.Shared.DigDugConfig)

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

	GridService.GridReset:Connect(function(gridData: { { number } }, faultData: { { any } }, _stage: number)
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

	-- Set ambient lighting for top-down ocean view
	Lighting.Ambient = Color3.fromRGB(100, 120, 140)
	Lighting.Brightness = 1.5
	Lighting.ClockTime = 14
	Lighting.FogEnd = 1000
end

function GridController:GridToWorld(col: number, row: number): Vector3
	-- Top-down: X = col, Z = row, Y = surface height
	return Vector3.new(
		ORIGIN.X + (col - 0.5) * CELL_SIZE,
		0.5, -- slightly above Y=0 for island surface
		ORIGIN.Z + (row - 0.5) * CELL_SIZE
	)
end

function GridController:_buildGrid(gridData: { { number } }, faultData: { { any } })
	-- Clean up old grid
	if self._gridFolder then
		self._gridFolder:Destroy()
	end

	self._gridFolder = Instance.new("Folder")
	self._gridFolder.Name = "DigDugGrid"
	self._gridFolder.Parent = workspace

	self._cells = {}
	self._faultParts = {}
	self._gridData = gridData

	-- Create grid cells on XZ plane
	for row = 1, ROWS do
		self._cells[row] = {}
		for col = 1, COLS do
			local cellType = gridData[row][col]
			self:_createCell(col, row, cellType)
		end
	end

	-- Create fault line visuals
	for _, fault in faultData do
		local fType = fault[1] :: string
		local fRow = fault[2] :: number
		local fCol = fault[3] :: number
		local fState = fault[4] :: number
		self:_createFaultPart(fType, fRow, fCol, fState)
	end

	-- Set up camera
	self:_setupCamera()
end

function GridController:_createCell(col: number, row: number, cellType: number)
	local part = Instance.new("Part")
	part.Name = `Cell_{col}_{row}`
	part.Anchored = true
	part.Size = Vector3.new(CELL_SIZE, CELL_SIZE * 0.5, CELL_SIZE)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	if cellType == CellType.ISLAND then
		part.Position = Vector3.new(
			ORIGIN.X + (col - 0.5) * CELL_SIZE,
			0,
			ORIGIN.Z + (row - 0.5) * CELL_SIZE
		)
		part.Color = DigDugConfig.ISLAND_COLOR
		part.Material = Enum.Material.Sand
	else
		-- Water or Sunk
		part.Position = Vector3.new(
			ORIGIN.X + (col - 0.5) * CELL_SIZE,
			-0.3,
			ORIGIN.Z + (row - 0.5) * CELL_SIZE
		)
		part.Color = DigDugConfig.WATER_COLOR
		part.Material = Enum.Material.Water
		part.Transparency = 0.15
	end

	part.Parent = self._gridFolder
	self._cells[row][col] = part
end

function GridController:_updateCell(col: number, row: number, cellType: number)
	if not self._cells[row] or not self._cells[row][col] then
		return
	end
	local part = self._cells[row][col]
	if not part then
		return
	end

	if cellType == CellType.ISLAND then
		part.Color = DigDugConfig.ISLAND_COLOR
		part.Material = Enum.Material.Sand
		part.Position = Vector3.new(
			ORIGIN.X + (col - 0.5) * CELL_SIZE,
			0,
			ORIGIN.Z + (row - 0.5) * CELL_SIZE
		)
		part.Transparency = 0
	elseif cellType == CellType.SUNK then
		part.Color = DigDugConfig.SUNK_COLOR
		part.Material = Enum.Material.Water
		part.Transparency = 0.15
	else
		part.Color = DigDugConfig.WATER_COLOR
		part.Material = Enum.Material.Water
		part.Transparency = 0.15
	end
end

function GridController:_createFaultPart(fType: string, row: number, col: number, state: number)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false

	local faultThickness = CELL_SIZE * 0.08

	if fType == "h" then
		-- Horizontal fault: between (row,col) and (row+1,col) — runs along X axis
		part.Name = `Fault_h_{row}_{col}`
		part.Size = Vector3.new(CELL_SIZE * 0.9, faultThickness, faultThickness)
		part.Position = Vector3.new(
			ORIGIN.X + (col - 0.5) * CELL_SIZE,
			0.3,
			ORIGIN.Z + row * CELL_SIZE -- between row and row+1
		)
	else
		-- Vertical fault: between (row,col) and (row,col+1) — runs along Z axis
		part.Name = `Fault_v_{row}_{col}`
		part.Size = Vector3.new(faultThickness, faultThickness, CELL_SIZE * 0.9)
		part.Position = Vector3.new(
			ORIGIN.X + col * CELL_SIZE, -- between col and col+1
			0.3,
			ORIGIN.Z + (row - 0.5) * CELL_SIZE
		)
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
	end
end

function GridController:_onChunkSinking(sinkingCells: { { number } })
	-- Animate sinking: tween cells down and fade, then convert to water
	for _, cell in sinkingCells do
		local col, row = cell[1], cell[2]
		local part = self._cells[row] and self._cells[row][col]
		if part then
			-- Tween down and fade
			local targetPos = part.Position - Vector3.new(0, 3, 0)
			local tweenInfo = TweenInfo.new(DigDugConfig.CHUNK_SINK_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local tween = TweenService:Create(part, tweenInfo, {
				Position = targetPos,
				Transparency = 0.9,
			})
			tween:Play()

			-- After sink, convert to water visual
			task.delay(DigDugConfig.CHUNK_SINK_TIME + 0.1, function()
				if part and part.Parent then
					part.Position = Vector3.new(
						ORIGIN.X + (col - 0.5) * CELL_SIZE,
						-0.3,
						ORIGIN.Z + (row - 0.5) * CELL_SIZE
					)
					part.Color = DigDugConfig.WATER_COLOR
					part.Material = Enum.Material.Water
					part.Transparency = 0.15
				end
			end)
		end

		-- Also remove any fault parts that were on these cells
		for key, faultPart in self._faultParts do
			-- Parse key to get fault position and check if it touches a sinking cell
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
end

function GridController:_setupCamera()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	-- Top-down camera looking straight down at the island
	local centerX = ORIGIN.X + (COLS * CELL_SIZE) / 2
	local centerZ = ORIGIN.Z + (ROWS * CELL_SIZE) / 2

	-- Calculate distance to fit the grid in viewport
	local gridSize = math.max(COLS, ROWS) * CELL_SIZE
	local viewportSize = camera.ViewportSize
	local aspect = viewportSize.X / math.max(viewportSize.Y, 1)

	local distance
	if aspect < 1 then
		-- Portrait mode: zoom out more to fit width
		distance = gridSize / (2 * math.tan(math.rad(camera.FieldOfView / 2)) * aspect)
	else
		local distByWidth = gridSize / (2 * math.tan(math.rad(camera.FieldOfView / 2)) * aspect)
		local distByHeight = gridSize / (2 * math.tan(math.rad(camera.FieldOfView / 2)))
		distance = math.max(distByHeight, distByWidth)
	end
	distance = distance * 1.15 -- margin

	camera.CameraType = Enum.CameraType.Scriptable
	-- Look straight down
	camera.CFrame = CFrame.new(
		Vector3.new(centerX, distance, centerZ),
		Vector3.new(centerX, 0, centerZ)
	)
end

return GridController
