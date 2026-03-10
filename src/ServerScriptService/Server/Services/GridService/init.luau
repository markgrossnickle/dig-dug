--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local DigDugConfig = require(ReplicatedStorage.Shared.DigDugConfig)
local StageLayouts = require(ReplicatedStorage.Shared.StageLayouts)

local COLS = DigDugConfig.GRID_COLUMNS
local ROWS = DigDugConfig.GRID_ROWS
local CellType = DigDugConfig.CellType
local FaultState = DigDugConfig.FaultState

local GridService = Knit.CreateService({
	Name = "GridService",
	Client = {
		GridInitialized = Knit.CreateSignal(),
		CellChanged = Knit.CreateSignal(),
		GridReset = Knit.CreateSignal(),
		FaultDrilled = Knit.CreateSignal(), -- (faultType, row, col)
		ChunkSinking = Knit.CreateSignal(), -- (sinkingCells: {{number, number}})
	},
})

-- Internal state
GridService._grid = {} :: { { number } }
-- Horizontal faults: hFaults[row][col] = fault between (row,col) and (row+1,col)
GridService._hFaults = {} :: { { number? } }
-- Vertical faults: vFaults[row][col] = fault between (row,col) and (row,col+1)
GridService._vFaults = {} :: { { number? } }
GridService.FaultDrilled = Signal.new() -- server-side signal (faultType, row, col)
GridService.ChunkBroke = Signal.new() -- server-side signal (sunkCells, player)

function GridService:KnitInit()
	self:_initGrid()
end

function GridService:KnitStart() end

function GridService:_initGrid()
	self._grid = {}
	self._hFaults = {}
	self._vFaults = {}
	for row = 1, ROWS do
		self._grid[row] = {}
		self._hFaults[row] = {}
		self._vFaults[row] = {}
		for col = 1, COLS do
			self._grid[row][col] = CellType.WATER
			self._hFaults[row][col] = nil
			self._vFaults[row][col] = nil
		end
	end
end

function GridService:ResetGrid(stage: number)
	self:_initGrid()

	local layout = StageLayouts.GetLayout(stage)
	if not layout then
		layout = StageLayouts.GenerateProceduralLayout(stage)
	end

	-- Set island cells from mask
	for row = 1, ROWS do
		for col = 1, COLS do
			if layout.islandMask[row] and layout.islandMask[row][col] then
				self._grid[row][col] = CellType.ISLAND
			end
		end
	end

	-- Place fault lines
	for _, fault in layout.faults do
		if fault.type == "horizontal" then
			-- Between (row,col) and (row+1,col)
			if fault.row >= 1 and fault.row < ROWS and fault.col >= 1 and fault.col <= COLS then
				self._hFaults[fault.row][fault.col] = FaultState.INTACT
			end
		else
			-- Between (row,col) and (row,col+1)
			if fault.row >= 1 and fault.row <= ROWS and fault.col >= 1 and fault.col < COLS then
				self._vFaults[fault.row][fault.col] = FaultState.INTACT
			end
		end
	end

	-- Notify all clients
	local gridData = self:_serializeGrid()
	local faultData = self:_serializeFaults()
	self.Client.GridReset:FireAll(gridData, faultData, stage)
end

function GridService:GetCell(col: number, row: number): number
	if row < 1 or row > ROWS or col < 1 or col > COLS then
		return -1
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

function GridService:IsIsland(col: number, row: number): boolean
	if row < 1 or row > ROWS or col < 1 or col > COLS then
		return false
	end
	return self._grid[row][col] == CellType.ISLAND
end

function GridService:IsWalkable(col: number, row: number): boolean
	return self:IsIsland(col, row)
end

function GridService:IsWater(col: number, row: number): boolean
	if row < 1 or row > ROWS or col < 1 or col > COLS then
		return true
	end
	local cell = self._grid[row][col]
	return cell == CellType.WATER or cell == CellType.SUNK
end

-- Get fault between two adjacent cells. Returns fault state or nil.
function GridService:GetFaultBetween(fromCol: number, fromRow: number, toCol: number, toRow: number): number?
	local dc = toCol - fromCol
	local dr = toRow - fromRow

	if dr == 1 and dc == 0 then
		-- Moving down: horizontal fault between (fromRow, fromCol) and (fromRow+1, fromCol)
		return self._hFaults[fromRow] and self._hFaults[fromRow][fromCol]
	elseif dr == -1 and dc == 0 then
		-- Moving up: horizontal fault between (toRow, toCol) and (toRow+1, toCol)
		return self._hFaults[toRow] and self._hFaults[toRow][toCol]
	elseif dc == 1 and dr == 0 then
		-- Moving right: vertical fault between (fromRow, fromCol) and (fromRow, fromCol+1)
		return self._vFaults[fromRow] and self._vFaults[fromRow][fromCol]
	elseif dc == -1 and dr == 0 then
		-- Moving left: vertical fault between (fromRow, toCol) and (fromRow, toCol+1)
		return self._vFaults[fromRow] and self._vFaults[fromRow][toCol]
	end

	return nil
end

-- Drill a fault between two cells. Returns true if a fault was drilled.
function GridService:DrillFault(fromCol: number, fromRow: number, toCol: number, toRow: number): boolean
	local dc = toCol - fromCol
	local dr = toRow - fromRow
	local faultType: string
	local faultRow: number
	local faultCol: number

	if dr == 1 and dc == 0 then
		faultType = "horizontal"
		faultRow = fromRow
		faultCol = fromCol
		if self._hFaults[faultRow] and self._hFaults[faultRow][faultCol] == FaultState.INTACT then
			self._hFaults[faultRow][faultCol] = FaultState.DRILLED
		else
			return false
		end
	elseif dr == -1 and dc == 0 then
		faultType = "horizontal"
		faultRow = toRow
		faultCol = toCol
		if self._hFaults[faultRow] and self._hFaults[faultRow][faultCol] == FaultState.INTACT then
			self._hFaults[faultRow][faultCol] = FaultState.DRILLED
		else
			return false
		end
	elseif dc == 1 and dr == 0 then
		faultType = "vertical"
		faultRow = fromRow
		faultCol = fromCol
		if self._vFaults[faultRow] and self._vFaults[faultRow][faultCol] == FaultState.INTACT then
			self._vFaults[faultRow][faultCol] = FaultState.DRILLED
		else
			return false
		end
	elseif dc == -1 and dr == 0 then
		faultType = "vertical"
		faultRow = fromRow
		faultCol = toCol
		if self._vFaults[faultRow] and self._vFaults[faultRow][faultCol] == FaultState.INTACT then
			self._vFaults[faultRow][faultCol] = FaultState.DRILLED
		else
			return false
		end
	else
		return false
	end

	self.Client.FaultDrilled:FireAll(faultType, faultRow, faultCol)
	self.FaultDrilled:Fire(faultType, faultRow, faultCol)
	return true
end

-- Check for broken chunks after a fault is drilled.
-- Returns array of sinking cell positions (empty if no chunk broke).
function GridService:CheckChunks(player: Player): { { number } }
	-- Find all connected components of ISLAND cells.
	-- Two ISLAND cells are connected if they're adjacent AND no drilled fault between them.
	local visited = {}
	for row = 1, ROWS do
		visited[row] = {}
		for col = 1, COLS do
			visited[row][col] = false
		end
	end

	local components: { { { number } } } = {} -- array of components, each component is array of {col, row}

	for row = 1, ROWS do
		for col = 1, COLS do
			if self._grid[row][col] == CellType.ISLAND and not visited[row][col] then
				-- BFS to find connected component
				local component: { { number } } = {}
				local queue: { { number } } = { { col, row } }
				visited[row][col] = true

				while #queue > 0 do
					local cell = table.remove(queue, 1) :: { number }
					local c, r = cell[1], cell[2]
					table.insert(component, { c, r })

					-- Check 4 neighbors
					local neighbors = {
						{ c, r - 1 }, -- up
						{ c, r + 1 }, -- down
						{ c - 1, r }, -- left
						{ c + 1, r }, -- right
					}

					for _, nb in neighbors do
						local nc, nr = nb[1], nb[2]
						if nr < 1 or nr > ROWS or nc < 1 or nc > COLS then
							continue
						end
						if visited[nr][nc] then
							continue
						end
						if self._grid[nr][nc] ~= CellType.ISLAND then
							continue
						end

						-- Check if there's a drilled fault between (c,r) and (nc,nr)
						if self:_hasDrilledFaultBetween(c, r, nc, nr) then
							continue -- drilled fault blocks connectivity
						end

						visited[nr][nc] = true
						table.insert(queue, { nc, nr })
					end
				end

				table.insert(components, component)
			end
		end
	end

	if #components <= 1 then
		return {} -- no chunks broke off
	end

	-- Find the largest component (main island)
	local largestIdx = 1
	local largestSize = #components[1]
	for i = 2, #components do
		if #components[i] > largestSize then
			largestIdx = i
			largestSize = #components[i]
		end
	end

	-- All other components are broken chunks — they sink
	local sinkingCells: { { number } } = {}
	for i, component in components do
		if i ~= largestIdx then
			for _, cell in component do
				table.insert(sinkingCells, cell)
			end
		end
	end

	if #sinkingCells > 0 then
		-- Convert sinking cells to SUNK
		for _, cell in sinkingCells do
			self._grid[cell[2]][cell[1]] = CellType.SUNK
		end

		-- Notify clients
		self.Client.ChunkSinking:FireAll(sinkingCells)
		self.ChunkBroke:Fire(sinkingCells, player)
	end

	return sinkingCells
end

-- Check if there's a drilled fault between two adjacent cells (public for movement blocking)
function GridService:HasDrilledFaultBetween(c1: number, r1: number, c2: number, r2: number): boolean
	return self:_hasDrilledFaultBetween(c1, r1, c2, r2)
end

function GridService:_hasDrilledFaultBetween(c1: number, r1: number, c2: number, r2: number): boolean
	local dc = c2 - c1
	local dr = r2 - r1

	if dr == 1 and dc == 0 then
		-- Vertical adjacency: check horizontal fault at (r1, c1)
		return self._hFaults[r1] ~= nil and self._hFaults[r1][c1] == FaultState.DRILLED
	elseif dr == -1 and dc == 0 then
		return self._hFaults[r2] ~= nil and self._hFaults[r2][c2] == FaultState.DRILLED
	elseif dc == 1 and dr == 0 then
		-- Horizontal adjacency: check vertical fault at (r1, c1)
		return self._vFaults[r1] ~= nil and self._vFaults[r1][c1] == FaultState.DRILLED
	elseif dc == -1 and dr == 0 then
		return self._vFaults[r1] ~= nil and self._vFaults[r1][c2] == FaultState.DRILLED
	end

	return false
end

-- Check if a specific cell is in a sinking chunk
function GridService:IsSunk(col: number, row: number): boolean
	if row < 1 or row > ROWS or col < 1 or col > COLS then
		return false
	end
	return self._grid[row][col] == CellType.SUNK
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

function GridService:_serializeFaults(): { { any } }
	-- Serialize as array of {type, row, col, state}
	local data = {}
	for row = 1, ROWS do
		for col = 1, COLS do
			if self._hFaults[row][col] ~= nil then
				table.insert(data, { "h", row, col, self._hFaults[row][col] })
			end
			if self._vFaults[row][col] ~= nil then
				table.insert(data, { "v", row, col, self._vFaults[row][col] })
			end
		end
	end
	return data
end

-- Client methods
function GridService.Client:GetGridState(_player: Player): { { number } }
	return self.Server:_serializeGrid()
end

function GridService.Client:GetFaultState(_player: Player): { { any } }
	return self.Server:_serializeFaults()
end

return GridService
