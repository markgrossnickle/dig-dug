--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local DigDugConfig = require(ReplicatedStorage.Shared.DigDugConfig)
local StageLayouts = require(ReplicatedStorage.Shared.StageLayouts)

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
	self._rockPositions = {}

	local layout = StageLayouts.GetLayout(stage)
	if not layout then
		layout = StageLayouts.GenerateProceduralLayout(stage)
	end

	-- Player spawn area (always present)
	local spawnCol = math.floor(COLS / 2)
	for col = spawnCol - 1, spawnCol + 1 do
		if col >= 1 and col <= COLS then
			self._grid[1][col] = CellType.TUNNEL
		end
	end

	-- Carve tunnels from layout
	for _, tunnel in layout.tunnels do
		if tunnel.type == "horizontal" then
			self:_carveTunnel(tunnel.col, tunnel.row, tunnel.length)
		else
			self:_carveVertical(tunnel.col, tunnel.row, tunnel.row + tunnel.length - 1)
		end
	end

	-- Ensure enemy positions are walkable
	for _, spawn in layout.enemies do
		if spawn.col >= 1 and spawn.col <= COLS and spawn.row >= 1 and spawn.row <= ROWS then
			if
				self._grid[spawn.row][spawn.col] ~= CellType.TUNNEL
				and self._grid[spawn.row][spawn.col] ~= CellType.EMPTY
			then
				self._grid[spawn.row][spawn.col] = CellType.TUNNEL
			end
		end
	end

	-- Place rocks from layout
	for _, rock in layout.rocks do
		if rock.col >= 1 and rock.col <= COLS and rock.row >= 1 and rock.row <= ROWS then
			self._grid[rock.row][rock.col] = CellType.ROCK
			table.insert(self._rockPositions, Vector2.new(rock.col, rock.row))
		end
	end

	-- Notify all clients
	local gridData = self:_serializeGrid()
	local rockData = self:_serializeRocks()
	self.Client.GridReset:FireAll(gridData, rockData, stage)
end

function GridService:_carveTunnel(startCol: number, row: number, length: number)
	for col = startCol, math.min(startCol + length - 1, COLS) do
		if col >= 1 and row >= 1 and row <= ROWS then
			if self._grid[row][col] == CellType.DIRT then
				self._grid[row][col] = CellType.TUNNEL
			end
		end
	end
end

function GridService:_carveVertical(col: number, startRow: number, endRow: number)
	for row = startRow, math.min(endRow, ROWS) do
		if col >= 1 and col <= COLS then
			if self._grid[row][col] == CellType.DIRT then
				self._grid[row][col] = CellType.TUNNEL
			end
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
