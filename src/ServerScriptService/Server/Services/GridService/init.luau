--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local DigDugConfig = require(ReplicatedStorage.Shared.DigDugConfig)

local COLS = DigDugConfig.GRID_COLUMNS
local ROWS = DigDugConfig.GRID_ROWS
local CellType = DigDugConfig.CellType

local GridService = Knit.CreateService({
	Name = "GridService",
	Client = {
		GridInitialized = Knit.CreateSignal(),
		CellChanged = Knit.CreateSignal(),
		GridReset = Knit.CreateSignal(),
	},
})

-- Internal state
GridService._grid = {} :: { { number } }
GridService._rockPositions = {} :: { Vector2 }
GridService.CellDug = Signal.new() -- server-side signal

function GridService:KnitInit()
	self:_initGrid()
end

function GridService:KnitStart() end

function GridService:_initGrid()
	self._grid = {}
	for row = 1, ROWS do
		self._grid[row] = {}
		for col = 1, COLS do
			self._grid[row][col] = CellType.DIRT
		end
	end
end

function GridService:ResetGrid(stage: number)
	self:_initGrid()

	-- Carve initial tunnels based on stage
	self:_carveStartingTunnels(stage)

	-- Place rocks
	self:_placeRocks(stage)

	-- Notify all clients
	local gridData = self:_serializeGrid()
	local rockData = self:_serializeRocks()
	self.Client.GridReset:FireAll(gridData, rockData, stage)
end

function GridService:_carveStartingTunnels(_stage: number)
	-- Player spawn area (top row, center)
	local spawnCol = math.floor(COLS / 2)
	for col = spawnCol - 1, spawnCol + 1 do
		if col >= 1 and col <= COLS then
			self._grid[1][col] = CellType.TUNNEL
		end
	end

	-- Create enemy chambers at various depths (small horizontal pockets)
	-- Layer 1 enemies (row 4)
	self:_carveTunnel(3, 4, 3) -- left chamber
	self:_carveTunnel(10, 4, 4) -- right chamber

	-- Layer 2 enemies (row 8)
	self:_carveTunnel(2, 8, 4)
	self:_carveTunnel(8, 8, 3)
	self:_carveTunnel(12, 8, 2)

	-- Layer 3 enemies (row 12)
	self:_carveTunnel(4, 12, 3)
	self:_carveTunnel(9, 12, 4)

	-- Layer 4 deep (row 15)
	self:_carveTunnel(5, 15, 5)

	-- Add vertical connecting tunnels between layers
	self:_carveVertical(4, 3, 5)
	self:_carveVertical(11, 3, 5)
	self:_carveVertical(3, 7, 9)
	self:_carveVertical(10, 7, 9)
	self:_carveVertical(6, 11, 13)
	self:_carveVertical(8, 14, 16)
end

function GridService:_carveTunnel(startCol: number, row: number, length: number)
	for col = startCol, math.min(startCol + length - 1, COLS) do
		if col >= 1 and row >= 1 and row <= ROWS then
			self._grid[row][col] = CellType.TUNNEL
		end
	end
end

function GridService:_carveVertical(col: number, startRow: number, endRow: number)
	for row = startRow, math.min(endRow, ROWS) do
		if col >= 1 and col <= COLS then
			self._grid[row][col] = CellType.TUNNEL
		end
	end
end

function GridService:_placeRocks(_stage: number)
	self._rockPositions = {}
	-- Place rocks at different depths, sitting on dirt
	local rockPositions = {
		{ col = 3, row = 3 },
		{ col = 7, row = 6 },
		{ col = 11, row = 10 },
	}
	for _, pos in rockPositions do
		if pos.col >= 1 and pos.col <= COLS and pos.row >= 1 and pos.row <= ROWS then
			self._grid[pos.row][pos.col] = CellType.ROCK
			table.insert(self._rockPositions, Vector2.new(pos.col, pos.row))
		end
	end
end

function GridService:GetCell(col: number, row: number): number
	if row < 1 or row > ROWS or col < 1 or col > COLS then
		return -1 -- out of bounds
	end
	return self._grid[row][col]
end

function GridService:SetCell(col: number, row: number, cellType: number)
	if row < 1 or row > ROWS or col < 1 or col > COLS then
		return
	end
	local old = self._grid[row][col]
	if old == cellType then
		return
	end
	self._grid[row][col] = cellType
	self.Client.CellChanged:FireAll(col, row, cellType)
end

function GridService:DigCell(col: number, row: number): boolean
	if row < 1 or row > ROWS or col < 1 or col > COLS then
		return false
	end
	local current = self._grid[row][col]
	if current == CellType.DIRT then
		self._grid[row][col] = CellType.EMPTY
		self.Client.CellChanged:FireAll(col, row, CellType.EMPTY)
		self.CellDug:Fire(col, row)
		return true
	end
	return false
end

function GridService:IsWalkable(col: number, row: number): boolean
	if row < 1 or row > ROWS or col < 1 or col > COLS then
		return false
	end
	local cell = self._grid[row][col]
	return cell == CellType.EMPTY or cell == CellType.TUNNEL
end

function GridService:IsDirt(col: number, row: number): boolean
	if row < 1 or row > ROWS or col < 1 or col > COLS then
		return false
	end
	return self._grid[row][col] == CellType.DIRT
end

function GridService:IsRock(col: number, row: number): boolean
	if row < 1 or row > ROWS or col < 1 or col > COLS then
		return false
	end
	return self._grid[row][col] == CellType.ROCK
end

function GridService:GetRockPositions(): { Vector2 }
	return self._rockPositions
end

function GridService:RemoveRock(col: number, row: number)
	self._grid[row][col] = CellType.EMPTY
	self.Client.CellChanged:FireAll(col, row, CellType.EMPTY)
	for i, pos in self._rockPositions do
		if pos.X == col and pos.Y == row then
			table.remove(self._rockPositions, i)
			break
		end
	end
end

function GridService:GetDepthLayer(row: number): number
	for i, layer in DigDugConfig.DepthLayers do
		if row >= layer.startRow and row <= layer.endRow then
			return i
		end
	end
	return #DigDugConfig.DepthLayers
end

function GridService:_serializeGrid(): { { number } }
	-- Deep copy the grid for sending to clients
	local data = {}
	for row = 1, ROWS do
		data[row] = {}
		for col = 1, COLS do
			data[row][col] = self._grid[row][col]
		end
	end
	return data
end

function GridService:_serializeRocks(): { { number } }
	local data = {}
	for _, pos in self._rockPositions do
		table.insert(data, { pos.X, pos.Y })
	end
	return data
end

-- Client methods
function GridService.Client:GetGridState(_player: Player): { { number } }
	return self.Server:_serializeGrid()
end

function GridService.Client:GetRockPositions(_player: Player): { { number } }
	return self.Server:_serializeRocks()
end

return GridService
