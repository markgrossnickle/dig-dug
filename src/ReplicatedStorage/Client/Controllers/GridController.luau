--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
GridController._rockParts = {} :: { [string]: Part }

function GridController:KnitInit()
	self._gridData = {}
	self._cells = {}
	self._rockParts = {}
end

function GridController:KnitStart()
	local GridService = Knit.GetService("GridService")

	GridService.CellChanged:Connect(function(col: number, row: number, cellType: number)
		self:_updateCell(col, row, cellType)
	end)

	GridService.GridReset:Connect(function(gridData: { { number } }, rockData: { { number } }, _stage: number)
		self:_buildGrid(gridData, rockData)
	end)

	-- Clean up default workspace objects
	self:_cleanWorkspace()

	-- Set up camera immediately so the start screen looks right
	self:_setupCamera()
end

function GridController:_cleanWorkspace()
	-- Remove default baseplate if it exists
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	-- Remove any default spawn location
	local spawn = workspace:FindFirstChild("SpawnLocation")
	if spawn then
		spawn:Destroy()
	end

	-- Set ambient lighting for the game
	local Lighting = game:GetService("Lighting")
	Lighting.Ambient = Color3.fromRGB(80, 80, 80)
	Lighting.Brightness = 1
	Lighting.ClockTime = 14
	Lighting.FogEnd = 1000
end

function GridController:GridToWorld(col: number, row: number): Vector3
	return Vector3.new(ORIGIN.X + (col - 0.5) * CELL_SIZE, ORIGIN.Y - (row - 0.5) * CELL_SIZE, ORIGIN.Z)
end

function GridController:_buildGrid(gridData: { { number } }, rockData: { { number } })
	-- Clean up old grid
	if self._gridFolder then
		self._gridFolder:Destroy()
	end

	self._gridFolder = Instance.new("Folder")
	self._gridFolder.Name = "DigDugGrid"
	self._gridFolder.Parent = workspace

	self._cells = {}
	self._rockParts = {}
	self._gridData = gridData

	-- Create sky/surface row above the grid
	self:_createSurface()

	-- Create grid cells
	for row = 1, ROWS do
		self._cells[row] = {}
		for col = 1, COLS do
			local cellType = gridData[row][col]
			self:_createCell(col, row, cellType)
		end
	end

	-- Create rocks
	for _, rockPos in rockData do
		self:_createRock(rockPos[1], rockPos[2])
	end

	-- Create boundary walls
	self:_createBoundaries()

	-- Set up camera
	self:_setupCamera()
end

function GridController:_createSurface()
	-- Sky background
	local sky = Instance.new("Part")
	sky.Name = "Sky"
	sky.Anchored = true
	sky.Size = Vector3.new(COLS * CELL_SIZE, CELL_SIZE * 2, CELL_SIZE)
	sky.Position = Vector3.new(ORIGIN.X + (COLS * CELL_SIZE) / 2, ORIGIN.Y + CELL_SIZE, ORIGIN.Z)
	sky.Color = DigDugConfig.SKY_COLOR
	sky.Material = Enum.Material.SmoothPlastic
	sky.Parent = self._gridFolder

	-- Grass strip
	local grass = Instance.new("Part")
	grass.Name = "Grass"
	grass.Anchored = true
	grass.Size = Vector3.new(COLS * CELL_SIZE, CELL_SIZE * 0.3, CELL_SIZE)
	grass.Position = Vector3.new(ORIGIN.X + (COLS * CELL_SIZE) / 2, ORIGIN.Y + CELL_SIZE * 0.15, ORIGIN.Z)
	grass.Color = DigDugConfig.SURFACE_COLOR
	grass.Material = Enum.Material.Grass
	grass.Parent = self._gridFolder
end

function GridController:_getColorForCell(_col: number, row: number): Color3
	for _, layer in DigDugConfig.DepthLayers do
		if row >= layer.startRow and row <= layer.endRow then
			return layer.color
		end
	end
	return DigDugConfig.DepthLayers[#DigDugConfig.DepthLayers].color
end

function GridController:_createCell(col: number, row: number, cellType: number)
	local part = Instance.new("Part")
	part.Name = `Cell_{col}_{row}`
	part.Anchored = true
	part.Size = Vector3.new(CELL_SIZE, CELL_SIZE, CELL_SIZE)
	part.Position = self:GridToWorld(col, row)
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	if cellType == CellType.EMPTY or cellType == CellType.TUNNEL then
		part.Color = DigDugConfig.TUNNEL_COLOR
		part.Transparency = 0
		part.Material = Enum.Material.Neon
	else
		-- DIRT and ROCK cells both show the earth layer color
		part.Color = self:_getColorForCell(col, row)
		part.Transparency = 0
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

	if cellType == CellType.EMPTY or cellType == CellType.TUNNEL then
		part.Color = DigDugConfig.TUNNEL_COLOR
		part.Material = Enum.Material.Neon
		part.Transparency = 0
	elseif cellType == CellType.DIRT then
		part.Color = self:_getColorForCell(col, row)
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = 0
	end

	-- Remove rock part if exists
	local key = `{col}_{row}`
	if self._rockParts[key] then
		self._rockParts[key]:Destroy()
		self._rockParts[key] = nil
	end
end

function GridController:_createRock(col: number, row: number)
	local rock = Instance.new("Part")
	rock.Name = `Rock_{col}_{row}`
	rock.Anchored = true
	rock.Size = Vector3.new(CELL_SIZE * 0.9, CELL_SIZE * 0.9, CELL_SIZE * 0.9)
	rock.Position = self:GridToWorld(col, row)
	rock.Color = Color3.fromRGB(128, 128, 128)
	rock.Material = Enum.Material.Slate
	rock.Shape = Enum.PartType.Block
	rock.Parent = self._gridFolder

	local key = `{col}_{row}`
	self._rockParts[key] = rock
end

function GridController:_createBoundaries()
	-- Left wall
	local left = Instance.new("Part")
	left.Name = "WallLeft"
	left.Anchored = true
	left.Size = Vector3.new(CELL_SIZE * 0.5, (ROWS + 2) * CELL_SIZE, CELL_SIZE)
	left.Position = Vector3.new(ORIGIN.X - CELL_SIZE * 0.25, ORIGIN.Y - (ROWS / 2 - 1) * CELL_SIZE, ORIGIN.Z)
	left.Color = Color3.fromRGB(40, 40, 40)
	left.Material = Enum.Material.SmoothPlastic
	left.Parent = self._gridFolder

	-- Right wall
	local right = left:Clone()
	right.Name = "WallRight"
	right.Position = Vector3.new(ORIGIN.X + COLS * CELL_SIZE + CELL_SIZE * 0.25, left.Position.Y, ORIGIN.Z)
	right.Parent = self._gridFolder

	-- Bottom wall
	local bottom = Instance.new("Part")
	bottom.Name = "WallBottom"
	bottom.Anchored = true
	bottom.Size = Vector3.new((COLS + 1) * CELL_SIZE, CELL_SIZE * 0.5, CELL_SIZE)
	bottom.Position =
		Vector3.new(ORIGIN.X + (COLS * CELL_SIZE) / 2, ORIGIN.Y - ROWS * CELL_SIZE - CELL_SIZE * 0.25, ORIGIN.Z)
	bottom.Color = Color3.fromRGB(40, 40, 40)
	bottom.Material = Enum.Material.SmoothPlastic
	bottom.Parent = self._gridFolder
end

function GridController:_setupCamera()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	-- Position camera to see the full grid (2D side view)
	local centerX = ORIGIN.X + (COLS * CELL_SIZE) / 2
	local centerY = ORIGIN.Y - (ROWS * CELL_SIZE) / 2
	local distance = math.max(COLS, ROWS) * CELL_SIZE * 0.9

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame =
		CFrame.new(Vector3.new(centerX, centerY, ORIGIN.Z + distance), Vector3.new(centerX, centerY, ORIGIN.Z))
end

function GridController:MoveRockPart(fromCol: number, fromRow: number, toCol: number, toRow: number)
	local oldKey = `{fromCol}_{fromRow}`
	local rock = self._rockParts[oldKey]
	if rock then
		self._rockParts[oldKey] = nil
		local newKey = `{toCol}_{toRow}`
		self._rockParts[newKey] = rock
		rock.Position = self:GridToWorld(toCol, toRow)
	end
end

function GridController:DestroyRockPart(col: number, row: number)
	local key = `{col}_{row}`
	if self._rockParts[key] then
		self._rockParts[key]:Destroy()
		self._rockParts[key] = nil
	end
end

return GridController
