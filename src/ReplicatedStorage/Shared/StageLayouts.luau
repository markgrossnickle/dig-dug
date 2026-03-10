--!strict
-- Stage layouts for Dig Dug II. Each layout defines an island shape, fault lines, and enemy spawns.
-- Stages 1-10 are hand-crafted. Stage 11+ uses procedural generation.

local DigDugConfig = require(script.Parent.DigDugConfig)

local COLS = DigDugConfig.GRID_COLUMNS
local ROWS = DigDugConfig.GRID_ROWS

export type FaultLine = {
	type: "horizontal" | "vertical",
	row: number,
	col: number,
}

export type EnemySpawn = {
	enemyType: string,
	col: number,
	row: number,
}

export type StageLayout = {
	islandMask: { { boolean } }, -- [row][col] = true means island
	faults: { FaultLine },
	enemies: { EnemySpawn },
	playerSpawn: Vector2?,
}

local P = DigDugConfig.EnemyType.POOKA
local F = DigDugConfig.EnemyType.FYGAR

-- Helper: create a rectangular island mask with optional cutouts
local function makeIslandMask(template: { string }): { { boolean } }
	local mask = {}
	for row = 1, ROWS do
		mask[row] = {}
		local line = template[row]
		for col = 1, COLS do
			if line and col <= #line then
				mask[row][col] = string.sub(line, col, col) == "#"
			else
				mask[row][col] = false
			end
		end
	end
	return mask
end

-- Stage templates: '#' = island, '.' = water
-- Grid is 16x16. Water border surrounds island shapes.

local StageLayouts: { [number]: StageLayout } = {
	-- Stage 1: Simple rectangle island. Easy intro.
	[1] = {
		islandMask = makeIslandMask({
			"................",
			"................",
			"...##########...",
			"...##########...",
			"...##########...",
			"...##########...",
			"...##########...",
			"...##########...",
			"...##########...",
			"...##########...",
			"...##########...",
			"...##########...",
			"...##########...",
			"...##########...",
			"................",
			"................",
		}),
		faults = {
			{ type = "horizontal", row = 5, col = 4 },
			{ type = "horizontal", row = 5, col = 5 },
			{ type = "horizontal", row = 5, col = 6 },
			{ type = "horizontal", row = 5, col = 7 },
			{ type = "vertical", row = 6, col = 7 },
			{ type = "vertical", row = 7, col = 7 },
			{ type = "horizontal", row = 8, col = 4 },
			{ type = "horizontal", row = 8, col = 5 },
			{ type = "horizontal", row = 8, col = 6 },
			{ type = "horizontal", row = 8, col = 7 },
			{ type = "horizontal", row = 10, col = 8 },
			{ type = "horizontal", row = 10, col = 9 },
			{ type = "horizontal", row = 10, col = 10 },
			{ type = "horizontal", row = 10, col = 11 },
			{ type = "horizontal", row = 10, col = 12 },
		},
		enemies = {
			{ enemyType = P, col = 5, row = 4 },
			{ enemyType = P, col = 10, row = 4 },
			{ enemyType = P, col = 7, row = 12 },
			{ enemyType = F, col = 10, row = 12 },
		},
		playerSpawn = Vector2.new(8, 8),
	},

	-- Stage 2: L-shaped island
	[2] = {
		islandMask = makeIslandMask({
			"................",
			"................",
			"..########......",
			"..########......",
			"..########......",
			"..########......",
			"..########......",
			"..########......",
			"..############..",
			"..############..",
			"..############..",
			"..############..",
			"..############..",
			"..############..",
			"................",
			"................",
		}),
		faults = {
			{ type = "vertical", row = 3, col = 6 },
			{ type = "vertical", row = 4, col = 6 },
			{ type = "vertical", row = 5, col = 6 },
			{ type = "horizontal", row = 5, col = 3 },
			{ type = "horizontal", row = 5, col = 4 },
			{ type = "horizontal", row = 5, col = 5 },
			{ type = "horizontal", row = 8, col = 7 },
			{ type = "horizontal", row = 8, col = 8 },
			{ type = "horizontal", row = 8, col = 9 },
			{ type = "horizontal", row = 8, col = 10 },
			{ type = "vertical", row = 9, col = 10 },
			{ type = "vertical", row = 10, col = 10 },
			{ type = "vertical", row = 11, col = 10 },
			{ type = "horizontal", row = 11, col = 3 },
			{ type = "horizontal", row = 11, col = 4 },
			{ type = "horizontal", row = 11, col = 5 },
			{ type = "horizontal", row = 11, col = 6 },
		},
		enemies = {
			{ enemyType = P, col = 4, row = 4 },
			{ enemyType = P, col = 8, row = 4 },
			{ enemyType = P, col = 5, row = 10 },
			{ enemyType = F, col = 12, row = 12 },
		},
		playerSpawn = Vector2.new(6, 8),
	},

	-- Stage 3: Cross/plus shaped island
	[3] = {
		islandMask = makeIslandMask({
			"................",
			"......####......",
			"......####......",
			"......####......",
			"...##########...",
			"...##########...",
			"...##########...",
			"...##########...",
			"...##########...",
			"...##########...",
			"...##########...",
			"...##########...",
			"......####......",
			"......####......",
			"......####......",
			"................",
		}),
		faults = {
			{ type = "horizontal", row = 4, col = 7 },
			{ type = "horizontal", row = 4, col = 8 },
			{ type = "horizontal", row = 4, col = 9 },
			{ type = "vertical", row = 5, col = 6 },
			{ type = "vertical", row = 6, col = 6 },
			{ type = "vertical", row = 7, col = 6 },
			{ type = "vertical", row = 5, col = 10 },
			{ type = "vertical", row = 6, col = 10 },
			{ type = "vertical", row = 7, col = 10 },
			{ type = "horizontal", row = 8, col = 4 },
			{ type = "horizontal", row = 8, col = 5 },
			{ type = "horizontal", row = 8, col = 6 },
			{ type = "horizontal", row = 8, col = 10 },
			{ type = "horizontal", row = 8, col = 11 },
			{ type = "horizontal", row = 8, col = 12 },
			{ type = "horizontal", row = 11, col = 7 },
			{ type = "horizontal", row = 11, col = 8 },
			{ type = "horizontal", row = 11, col = 9 },
		},
		enemies = {
			{ enemyType = P, col = 8, row = 2 },
			{ enemyType = P, col = 5, row = 7 },
			{ enemyType = F, col = 11, row = 7 },
			{ enemyType = F, col = 8, row = 13 },
		},
		playerSpawn = Vector2.new(8, 8),
	},

	-- Stage 4: Two-peninsula island
	[4] = {
		islandMask = makeIslandMask({
			"................",
			"................",
			"..####....####..",
			"..####....####..",
			"..####....####..",
			"..####....####..",
			"..##########..",
			"..############..",
			"..############..",
			"..############..",
			"..############..",
			"..############..",
			"..############..",
			"..############..",
			"................",
			"................",
		}),
		faults = {
			{ type = "horizontal", row = 6, col = 3 },
			{ type = "horizontal", row = 6, col = 4 },
			{ type = "horizontal", row = 6, col = 5 },
			{ type = "horizontal", row = 6, col = 11 },
			{ type = "horizontal", row = 6, col = 12 },
			{ type = "horizontal", row = 6, col = 13 },
			{ type = "horizontal", row = 9, col = 3 },
			{ type = "horizontal", row = 9, col = 4 },
			{ type = "horizontal", row = 9, col = 5 },
			{ type = "horizontal", row = 9, col = 6 },
			{ type = "vertical", row = 7, col = 8 },
			{ type = "vertical", row = 8, col = 8 },
			{ type = "vertical", row = 9, col = 8 },
			{ type = "horizontal", row = 11, col = 8 },
			{ type = "horizontal", row = 11, col = 9 },
			{ type = "horizontal", row = 11, col = 10 },
			{ type = "horizontal", row = 11, col = 11 },
			{ type = "horizontal", row = 11, col = 12 },
		},
		enemies = {
			{ enemyType = P, col = 4, row = 3 },
			{ enemyType = P, col = 12, row = 3 },
			{ enemyType = F, col = 5, row = 10 },
			{ enemyType = F, col = 11, row = 12 },
		},
		playerSpawn = Vector2.new(8, 9),
	},

	-- Stage 5: Large island with internal fault network, 5 enemies
	[5] = {
		islandMask = makeIslandMask({
			"................",
			"...##########...",
			"..############..",
			"..############..",
			"..############..",
			"..############..",
			"..############..",
			"..############..",
			"..############..",
			"..############..",
			"..############..",
			"..############..",
			"..############..",
			"...##########...",
			"................",
			"................",
		}),
		faults = {
			{ type = "vertical", row = 2, col = 6 },
			{ type = "vertical", row = 3, col = 6 },
			{ type = "vertical", row = 4, col = 6 },
			{ type = "horizontal", row = 4, col = 3 },
			{ type = "horizontal", row = 4, col = 4 },
			{ type = "horizontal", row = 4, col = 5 },
			{ type = "vertical", row = 2, col = 10 },
			{ type = "vertical", row = 3, col = 10 },
			{ type = "vertical", row = 4, col = 10 },
			{ type = "horizontal", row = 4, col = 10 },
			{ type = "horizontal", row = 4, col = 11 },
			{ type = "horizontal", row = 4, col = 12 },
			{ type = "horizontal", row = 7, col = 5 },
			{ type = "horizontal", row = 7, col = 6 },
			{ type = "horizontal", row = 7, col = 7 },
			{ type = "horizontal", row = 7, col = 8 },
			{ type = "horizontal", row = 7, col = 9 },
			{ type = "horizontal", row = 7, col = 10 },
			{ type = "horizontal", row = 10, col = 3 },
			{ type = "horizontal", row = 10, col = 4 },
			{ type = "horizontal", row = 10, col = 5 },
			{ type = "horizontal", row = 10, col = 6 },
			{ type = "vertical", row = 10, col = 9 },
			{ type = "vertical", row = 11, col = 9 },
			{ type = "vertical", row = 12, col = 9 },
		},
		enemies = {
			{ enemyType = P, col = 4, row = 3 },
			{ enemyType = P, col = 12, row = 3 },
			{ enemyType = P, col = 4, row = 12 },
			{ enemyType = F, col = 8, row = 6 },
			{ enemyType = F, col = 11, row = 11 },
		},
		playerSpawn = Vector2.new(8, 8),
	},

	-- Stage 6: Narrow bridge island (hourglass)
	[6] = {
		islandMask = makeIslandMask({
			"................",
			"..##########....",
			"..##########....",
			"..##########....",
			"..##########....",
			"....######......",
			"......####......",
			"......####......",
			"......####......",
			"....######......",
			"..##########....",
			"..##########....",
			"..##########....",
			"..##########....",
			"................",
			"................",
		}),
		faults = {
			{ type = "horizontal", row = 4, col = 3 },
			{ type = "horizontal", row = 4, col = 4 },
			{ type = "horizontal", row = 4, col = 5 },
			{ type = "horizontal", row = 4, col = 6 },
			{ type = "horizontal", row = 4, col = 7 },
			{ type = "horizontal", row = 4, col = 8 },
			{ type = "horizontal", row = 4, col = 9 },
			{ type = "horizontal", row = 4, col = 10 },
			{ type = "horizontal", row = 9, col = 5 },
			{ type = "horizontal", row = 9, col = 6 },
			{ type = "horizontal", row = 9, col = 7 },
			{ type = "horizontal", row = 9, col = 8 },
			{ type = "horizontal", row = 9, col = 9 },
			{ type = "horizontal", row = 9, col = 10 },
			{ type = "vertical", row = 2, col = 6 },
			{ type = "vertical", row = 3, col = 6 },
			{ type = "vertical", row = 11, col = 6 },
			{ type = "vertical", row = 12, col = 6 },
		},
		enemies = {
			{ enemyType = P, col = 4, row = 2 },
			{ enemyType = P, col = 9, row = 2 },
			{ enemyType = F, col = 4, row = 12 },
			{ enemyType = F, col = 9, row = 12 },
			{ enemyType = F, col = 8, row = 7 },
		},
		playerSpawn = Vector2.new(8, 8),
	},

	-- Stage 7: Large irregular island, 6 enemies
	[7] = {
		islandMask = makeIslandMask({
			"................",
			"....########....",
			"...##########...",
			"..############..",
			"..############..",
			"..############..",
			".#############..",
			".##############.",
			".##############.",
			"..############..",
			"..############..",
			"..############..",
			"...##########...",
			"....########....",
			"................",
			"................",
		}),
		faults = {
			{ type = "horizontal", row = 3, col = 5 },
			{ type = "horizontal", row = 3, col = 6 },
			{ type = "horizontal", row = 3, col = 7 },
			{ type = "vertical", row = 4, col = 7 },
			{ type = "vertical", row = 5, col = 7 },
			{ type = "horizontal", row = 5, col = 4 },
			{ type = "horizontal", row = 5, col = 5 },
			{ type = "horizontal", row = 5, col = 6 },
			{ type = "vertical", row = 4, col = 11 },
			{ type = "vertical", row = 5, col = 11 },
			{ type = "vertical", row = 6, col = 11 },
			{ type = "horizontal", row = 7, col = 3 },
			{ type = "horizontal", row = 7, col = 4 },
			{ type = "horizontal", row = 7, col = 5 },
			{ type = "horizontal", row = 7, col = 6 },
			{ type = "horizontal", row = 7, col = 7 },
			{ type = "horizontal", row = 10, col = 7 },
			{ type = "horizontal", row = 10, col = 8 },
			{ type = "horizontal", row = 10, col = 9 },
			{ type = "horizontal", row = 10, col = 10 },
			{ type = "horizontal", row = 10, col = 11 },
			{ type = "vertical", row = 8, col = 5 },
			{ type = "vertical", row = 9, col = 5 },
			{ type = "vertical", row = 10, col = 5 },
		},
		enemies = {
			{ enemyType = P, col = 6, row = 2 },
			{ enemyType = P, col = 10, row = 4 },
			{ enemyType = P, col = 3, row = 8 },
			{ enemyType = F, col = 12, row = 8 },
			{ enemyType = F, col = 6, row = 12 },
			{ enemyType = F, col = 10, row = 12 },
		},
		playerSpawn = Vector2.new(8, 7),
	},

	-- Stage 8: Ring/donut island
	[8] = {
		islandMask = makeIslandMask({
			"................",
			"....########....",
			"...##########...",
			"..############..",
			"..###......###..",
			"..###......###..",
			"..###......###..",
			"..###......###..",
			"..###......###..",
			"..###......###..",
			"..############..",
			"...##########...",
			"....########....",
			"................",
			"................",
			"................",
		}),
		faults = {
			{ type = "horizontal", row = 3, col = 5 },
			{ type = "horizontal", row = 3, col = 6 },
			{ type = "horizontal", row = 3, col = 7 },
			{ type = "horizontal", row = 3, col = 8 },
			{ type = "horizontal", row = 3, col = 9 },
			{ type = "horizontal", row = 3, col = 10 },
			{ type = "horizontal", row = 3, col = 11 },
			{ type = "vertical", row = 4, col = 5 },
			{ type = "vertical", row = 5, col = 5 },
			{ type = "vertical", row = 6, col = 5 },
			{ type = "vertical", row = 7, col = 5 },
			{ type = "vertical", row = 4, col = 12 },
			{ type = "vertical", row = 5, col = 12 },
			{ type = "vertical", row = 6, col = 12 },
			{ type = "vertical", row = 7, col = 12 },
			{ type = "horizontal", row = 10, col = 5 },
			{ type = "horizontal", row = 10, col = 6 },
			{ type = "horizontal", row = 10, col = 7 },
			{ type = "horizontal", row = 10, col = 8 },
			{ type = "horizontal", row = 10, col = 9 },
			{ type = "horizontal", row = 10, col = 10 },
			{ type = "horizontal", row = 10, col = 11 },
		},
		enemies = {
			{ enemyType = P, col = 8, row = 2 },
			{ enemyType = P, col = 4, row = 7 },
			{ enemyType = P, col = 13, row = 7 },
			{ enemyType = F, col = 8, row = 11 },
			{ enemyType = F, col = 4, row = 4 },
			{ enemyType = F, col = 13, row = 4 },
		},
		playerSpawn = Vector2.new(8, 3),
	},

	-- Stage 9: Archipelago — two connected masses, 7 enemies
	[9] = {
		islandMask = makeIslandMask({
			"................",
			"..########......",
			"..########......",
			"..########......",
			"..########......",
			"..########......",
			"..########......",
			".....#####......",
			"......#####.....",
			"......########..",
			"......########..",
			"......########..",
			"......########..",
			"......########..",
			"......########..",
			"................",
		}),
		faults = {
			{ type = "horizontal", row = 3, col = 3 },
			{ type = "horizontal", row = 3, col = 4 },
			{ type = "horizontal", row = 3, col = 5 },
			{ type = "vertical", row = 2, col = 6 },
			{ type = "vertical", row = 3, col = 6 },
			{ type = "vertical", row = 4, col = 6 },
			{ type = "horizontal", row = 5, col = 3 },
			{ type = "horizontal", row = 5, col = 4 },
			{ type = "horizontal", row = 5, col = 5 },
			{ type = "horizontal", row = 5, col = 6 },
			{ type = "horizontal", row = 5, col = 7 },
			{ type = "horizontal", row = 5, col = 8 },
			{ type = "horizontal", row = 11, col = 7 },
			{ type = "horizontal", row = 11, col = 8 },
			{ type = "horizontal", row = 11, col = 9 },
			{ type = "horizontal", row = 11, col = 10 },
			{ type = "horizontal", row = 11, col = 11 },
			{ type = "horizontal", row = 11, col = 12 },
			{ type = "vertical", row = 10, col = 10 },
			{ type = "vertical", row = 11, col = 10 },
			{ type = "vertical", row = 12, col = 10 },
			{ type = "vertical", row = 13, col = 10 },
		},
		enemies = {
			{ enemyType = P, col = 4, row = 2 },
			{ enemyType = P, col = 8, row = 2 },
			{ enemyType = P, col = 5, row = 5 },
			{ enemyType = P, col = 9, row = 11 },
			{ enemyType = F, col = 8, row = 13 },
			{ enemyType = F, col = 12, row = 13 },
			{ enemyType = F, col = 3, row = 4 },
		},
		playerSpawn = Vector2.new(6, 4),
	},

	-- Stage 10: Maximum challenge. Large complex island, 8 enemies, many fault segments
	[10] = {
		islandMask = makeIslandMask({
			"................",
			"..############..",
			"..############..",
			".#############..",
			".##############.",
			".##############.",
			".##############.",
			".##############.",
			".##############.",
			".##############.",
			".##############.",
			".##############.",
			"..############..",
			"..############..",
			"...##########...",
			"................",
		}),
		faults = {
			-- Top horizontal cut
			{ type = "horizontal", row = 3, col = 4 },
			{ type = "horizontal", row = 3, col = 5 },
			{ type = "horizontal", row = 3, col = 6 },
			{ type = "horizontal", row = 3, col = 7 },
			-- Top right vertical cut
			{ type = "vertical", row = 2, col = 10 },
			{ type = "vertical", row = 3, col = 10 },
			-- Mid-left horizontal
			{ type = "horizontal", row = 6, col = 2 },
			{ type = "horizontal", row = 6, col = 3 },
			{ type = "horizontal", row = 6, col = 4 },
			{ type = "horizontal", row = 6, col = 5 },
			-- Center vertical
			{ type = "vertical", row = 5, col = 8 },
			{ type = "vertical", row = 6, col = 8 },
			{ type = "vertical", row = 7, col = 8 },
			-- Center right horizontal
			{ type = "horizontal", row = 7, col = 9 },
			{ type = "horizontal", row = 7, col = 10 },
			{ type = "horizontal", row = 7, col = 11 },
			{ type = "horizontal", row = 7, col = 12 },
			{ type = "horizontal", row = 7, col = 13 },
			-- Bottom left
			{ type = "horizontal", row = 10, col = 3 },
			{ type = "horizontal", row = 10, col = 4 },
			{ type = "horizontal", row = 10, col = 5 },
			{ type = "vertical", row = 10, col = 5 },
			{ type = "vertical", row = 11, col = 5 },
			{ type = "vertical", row = 12, col = 5 },
			-- Bottom right
			{ type = "vertical", row = 9, col = 12 },
			{ type = "vertical", row = 10, col = 12 },
			{ type = "vertical", row = 11, col = 12 },
			{ type = "horizontal", row = 11, col = 8 },
			{ type = "horizontal", row = 11, col = 9 },
			{ type = "horizontal", row = 11, col = 10 },
			{ type = "horizontal", row = 11, col = 11 },
		},
		enemies = {
			{ enemyType = P, col = 4, row = 2 },
			{ enemyType = P, col = 12, row = 2 },
			{ enemyType = P, col = 3, row = 8 },
			{ enemyType = P, col = 13, row = 5 },
			{ enemyType = F, col = 6, row = 5 },
			{ enemyType = F, col = 11, row = 10 },
			{ enemyType = F, col = 4, row = 12 },
			{ enemyType = F, col = 10, row = 13 },
		},
		playerSpawn = Vector2.new(8, 8),
	},
}

local StageLayoutsModule = {}

function StageLayoutsModule.GetLayout(stage: number): StageLayout?
	return StageLayouts[stage]
end

function StageLayoutsModule.GenerateProceduralLayout(stage: number): StageLayout
	-- For stage 11+, procedurally generate based on difficulty
	local enemyCount = math.min(4 + math.floor(stage / 2), 10)
	local pookaCount = math.max(2, math.floor(enemyCount * 0.5))
	local fygarCount = enemyCount - pookaCount

	-- Generate an irregular island using distance from center
	local centerR = ROWS / 2
	local centerC = COLS / 2
	local baseRadius = 5.5 + math.min(stage * 0.1, 2)

	local mask: { { boolean } } = {}
	for row = 1, ROWS do
		mask[row] = {}
		for col = 1, COLS do
			local dist = math.sqrt((row - centerR) ^ 2 + (col - centerC) ^ 2)
			-- Add noise based on angle for irregular shape
			local angle = math.atan2(row - centerR, col - centerC)
			local noise = math.sin(angle * 3 + stage) * 1.2 + math.cos(angle * 5 + stage * 2) * 0.8
			mask[row][col] = dist < (baseRadius + noise) and row > 1 and row < ROWS and col > 1 and col < COLS
		end
	end

	-- Generate fault lines along grid edges within the island
	local faults: { FaultLine } = {}
	local faultCount = math.min(15 + stage * 2, 40)

	for _ = 1, faultCount do
		local isHorizontal = math.random() > 0.5
		local row = math.random(2, ROWS - 2)
		local col = math.random(2, COLS - 2)

		if isHorizontal then
			-- Horizontal fault between (row, col) and (row+1, col)
			if row < ROWS and mask[row][col] and mask[row + 1][col] then
				table.insert(faults, { type = "horizontal", row = row, col = col })
			end
		else
			-- Vertical fault between (row, col) and (row, col+1)
			if col < COLS and mask[row][col] and mask[row][col + 1] then
				table.insert(faults, { type = "vertical", row = row, col = col })
			end
		end
	end

	-- Place enemies on island cells
	local islandCells: { Vector2 } = {}
	for row = 1, ROWS do
		for col = 1, COLS do
			if mask[row][col] then
				table.insert(islandCells, Vector2.new(col, row))
			end
		end
	end

	local enemies: { EnemySpawn } = {}
	local usedCells: { [string]: boolean } = {}

	-- Player spawn at center
	local playerSpawn = Vector2.new(math.floor(centerC), math.floor(centerR))
	usedCells[`{playerSpawn.X}_{playerSpawn.Y}`] = true

	for i = 1, pookaCount do
		local cell = islandCells[math.random(1, #islandCells)]
		local key = `{cell.X}_{cell.Y}`
		if not usedCells[key] then
			table.insert(enemies, { enemyType = P, col = cell.X, row = cell.Y })
			usedCells[key] = true
		end
	end
	for i = 1, fygarCount do
		local cell = islandCells[math.random(1, #islandCells)]
		local key = `{cell.X}_{cell.Y}`
		if not usedCells[key] then
			table.insert(enemies, { enemyType = F, col = cell.X, row = cell.Y })
			usedCells[key] = true
		end
	end

	return {
		islandMask = mask,
		faults = faults,
		enemies = enemies,
		playerSpawn = playerSpawn,
	}
end

return StageLayoutsModule
