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
	-- Player spawn area (top center)
	local spawnCol = math.floor(COLS / 2)
	for col = spawnCol - 1, spawnCol + 1 do
		if col >= 1 and col <= COLS then
			self._grid[1][col] = CellType.TUNNEL
		end
	end

	-- Create horizontal tunnels at various depths for enemies
	local tunnelRows = { 4, 8, 12 }
	for _, row in tunnelRows do
		if row <= ROWS then
			local startCol = math.random(2, 5)
			local endCol = math.random(COLS - 4, COLS - 1)
			for col = startCol, endCol do
				self._grid[row][col] = CellType.TUNNEL
			end
		end
	end

	-- Add some vertical connecting tunnels
	local vertCols = { 4, COLS - 3 }
	for _, col in vertCols do
		local startRow = math.random(3, 5)
		local endRow = math.random(startRow + 2, math.min(startRow + 4, ROWS))
		for row = startRow, endRow do
			self._grid[row][col] = CellType.TUNNEL
		end
	end
end

function GridService:_placeRocks(_stage: number)
	self._rockPositions = {}
	local rockCols = DigDugConfig.DEFAULT_ROCK_COLUMNS
	for _, col in rockCols do
		if col >= 1 and col <= COLS then
			-- Place rocks at row 3 by default (just below surface)
			local row = 3
			self._grid[row][col] = CellType.ROCK
			table.insert(self._rockPositions, Vector2.new(col, row))
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
