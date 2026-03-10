--!strict
-- Stage layouts for Dig Dug II. Each layout defines an island shape, fault lines, and enemy spawns.
-- Grid is 22x22. Stages 1-10 are hand-crafted. Stage 11+ uses procedural generation.

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

-- Helper: create island mask from string template (22 chars wide, up to 22 rows)
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
-- Grid is 22x22. Water border surrounds island shapes.

local StageLayouts: { [number]: StageLayout } = {
	-- Stage 1: Simple rectangle island. Easy intro. Only 2 enemies.
	[1] = {
		islandMask = makeIslandMask({
			"......................",
			"......................",
			"......................",
			"....##############....",
			"....##############....",
			"....##############....",
			"....##############....",
			"....##############....",
			"....##############....",
			"....##############....",
			"....##############....",
			"....##############....",
			"....##############....",
			"....##############....",
			"....##############....",
			"....##############....",
			"....##############....",
			"....##############....",
			"......................",
			"......................",
			"......................",
			"......................",
		}),
		faults = {
			{ type = "horizontal", row = 7, col = 5 },
			{ type = "horizontal", row = 7, col = 6 },
			{ type = "horizontal", row = 7, col = 7 },
			{ type = "horizontal", row = 7, col = 8 },
			{ type = "horizontal", row = 7, col = 9 },
			{ type = "horizontal", row = 7, col = 10 },
			{ type = "horizontal", row = 12, col = 10 },
			{ type = "horizontal", row = 12, col = 11 },
			{ type = "horizontal", row = 12, col = 12 },
			{ type = "horizontal", row = 12, col = 13 },
			{ type = "horizontal", row = 12, col = 14 },
			{ type = "horizontal", row = 12, col = 15 },
			{ type = "horizontal", row = 12, col = 16 },
		},
		enemies = {
			{ enemyType = P, col = 7, row = 5 },
			{ enemyType = P, col = 15, row = 15 },
		},
		playerSpawn = Vector2.new(11, 11),
	},

	-- Stage 2: L-shaped island. 3 enemies.
	[2] = {
		islandMask = makeIslandMask({
			"......................",
			"......................",
			"...############.......",
			"...############.......",
			"...############.......",
			"...############.......",
			"...############.......",
			"...############.......",
			"...############.......",
			"...############.......",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"......................",
			"......................",
			"......................",
			"......................",
		}),
		faults = {
			{ type = "vertical", row = 3, col = 9 },
			{ type = "vertical", row = 4, col = 9 },
			{ type = "vertical", row = 5, col = 9 },
			{ type = "vertical", row = 6, col = 9 },
			{ type = "horizontal", row = 6, col = 4 },
			{ type = "horizontal", row = 6, col = 5 },
			{ type = "horizontal", row = 6, col = 6 },
			{ type = "horizontal", row = 6, col = 7 },
			{ type = "horizontal", row = 6, col = 8 },
			{ type = "horizontal", row = 10, col = 10 },
			{ type = "horizontal", row = 10, col = 11 },
			{ type = "horizontal", row = 10, col = 12 },
			{ type = "horizontal", row = 10, col = 13 },
			{ type = "horizontal", row = 10, col = 14 },
			{ type = "vertical", row = 11, col = 14 },
			{ type = "vertical", row = 12, col = 14 },
			{ type = "vertical", row = 13, col = 14 },
			{ type = "vertical", row = 14, col = 14 },
			{ type = "horizontal", row = 14, col = 4 },
			{ type = "horizontal", row = 14, col = 5 },
			{ type = "horizontal", row = 14, col = 6 },
			{ type = "horizontal", row = 14, col = 7 },
			{ type = "horizontal", row = 14, col = 8 },
		},
		enemies = {
			{ enemyType = P, col = 6, row = 4 },
			{ enemyType = P, col = 12, row = 4 },
			{ enemyType = F, col = 16, row = 16 },
		},
		playerSpawn = Vector2.new(8, 10),
	},

	-- Stage 3: Cross/plus shaped island. 4 enemies.
	[3] = {
		islandMask = makeIslandMask({
			"......................",
			"......................",
			".......######.........",
			".......######.........",
			".......######.........",
			".......######.........",
			"...################...",
			"...################...",
			"...################...",
			"...################...",
			"...################...",
			"...################...",
			"...################...",
			"...################...",
			"...################...",
			"...################...",
			".......######.........",
			".......######.........",
			".......######.........",
			".......######.........",
			"......................",
			"......................",
		}),
		faults = {
			{ type = "horizontal", row = 6, col = 8 },
			{ type = "horizontal", row = 6, col = 9 },
			{ type = "horizontal", row = 6, col = 10 },
			{ type = "horizontal", row = 6, col = 11 },
			{ type = "vertical", row = 7, col = 7 },
			{ type = "vertical", row = 8, col = 7 },
			{ type = "vertical", row = 9, col = 7 },
			{ type = "vertical", row = 7, col = 14 },
			{ type = "vertical", row = 8, col = 14 },
			{ type = "vertical", row = 9, col = 14 },
			{ type = "horizontal", row = 10, col = 4 },
			{ type = "horizontal", row = 10, col = 5 },
			{ type = "horizontal", row = 10, col = 6 },
			{ type = "horizontal", row = 10, col = 7 },
			{ type = "horizontal", row = 10, col = 14 },
			{ type = "horizontal", row = 10, col = 15 },
			{ type = "horizontal", row = 10, col = 16 },
			{ type = "horizontal", row = 10, col = 17 },
			{ type = "horizontal", row = 15, col = 8 },
			{ type = "horizontal", row = 15, col = 9 },
			{ type = "horizontal", row = 15, col = 10 },
			{ type = "horizontal", row = 15, col = 11 },
		},
		enemies = {
			{ enemyType = P, col = 10, row = 3 },
			{ enemyType = P, col = 6, row = 9 },
			{ enemyType = F, col = 16, row = 9 },
			{ enemyType = F, col = 10, row = 18 },
		},
		playerSpawn = Vector2.new(11, 11),
	},

	-- Stage 4: Two-peninsula island. 4 enemies.
	[4] = {
		islandMask = makeIslandMask({
			"......................",
			"......................",
			"...######....######...",
			"...######....######...",
			"...######....######...",
			"...######....######...",
			"...######....######...",
			"...######....######...",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"......................",
			"......................",
			"......................",
			"......................",
		}),
		faults = {
			{ type = "horizontal", row = 8, col = 4 },
			{ type = "horizontal", row = 8, col = 5 },
			{ type = "horizontal", row = 8, col = 6 },
			{ type = "horizontal", row = 8, col = 7 },
			{ type = "horizontal", row = 8, col = 14 },
			{ type = "horizontal", row = 8, col = 15 },
			{ type = "horizontal", row = 8, col = 16 },
			{ type = "horizontal", row = 8, col = 17 },
			{ type = "horizontal", row = 12, col = 4 },
			{ type = "horizontal", row = 12, col = 5 },
			{ type = "horizontal", row = 12, col = 6 },
			{ type = "horizontal", row = 12, col = 7 },
			{ type = "horizontal", row = 12, col = 8 },
			{ type = "vertical", row = 9, col = 11 },
			{ type = "vertical", row = 10, col = 11 },
			{ type = "vertical", row = 11, col = 11 },
			{ type = "vertical", row = 12, col = 11 },
			{ type = "horizontal", row = 15, col = 11 },
			{ type = "horizontal", row = 15, col = 12 },
			{ type = "horizontal", row = 15, col = 13 },
			{ type = "horizontal", row = 15, col = 14 },
			{ type = "horizontal", row = 15, col = 15 },
			{ type = "horizontal", row = 15, col = 16 },
		},
		enemies = {
			{ enemyType = P, col = 6, row = 4 },
			{ enemyType = P, col = 17, row = 4 },
			{ enemyType = F, col = 7, row = 14 },
			{ enemyType = F, col = 16, row = 16 },
		},
		playerSpawn = Vector2.new(11, 12),
	},

	-- Stage 5: Large island with fault network. 5 enemies.
	[5] = {
		islandMask = makeIslandMask({
			"......................",
			"......................",
			"....################..",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"...##################.",
			"....################..",
			"......................",
			"......................",
			"......................",
			"......................",
		}),
		faults = {
			{ type = "vertical", row = 3, col = 8 },
			{ type = "vertical", row = 4, col = 8 },
			{ type = "vertical", row = 5, col = 8 },
			{ type = "horizontal", row = 5, col = 4 },
			{ type = "horizontal", row = 5, col = 5 },
			{ type = "horizontal", row = 5, col = 6 },
			{ type = "horizontal", row = 5, col = 7 },
			{ type = "vertical", row = 3, col = 14 },
			{ type = "vertical", row = 4, col = 14 },
			{ type = "vertical", row = 5, col = 14 },
			{ type = "horizontal", row = 5, col = 14 },
			{ type = "horizontal", row = 5, col = 15 },
			{ type = "horizontal", row = 5, col = 16 },
			{ type = "horizontal", row = 5, col = 17 },
			{ type = "horizontal", row = 9, col = 6 },
			{ type = "horizontal", row = 9, col = 7 },
			{ type = "horizontal", row = 9, col = 8 },
			{ type = "horizontal", row = 9, col = 9 },
			{ type = "horizontal", row = 9, col = 10 },
			{ type = "horizontal", row = 9, col = 11 },
			{ type = "horizontal", row = 9, col = 12 },
			{ type = "horizontal", row = 9, col = 13 },
			{ type = "horizontal", row = 13, col = 4 },
			{ type = "horizontal", row = 13, col = 5 },
			{ type = "horizontal", row = 13, col = 6 },
			{ type = "horizontal", row = 13, col = 7 },
			{ type = "horizontal", row = 13, col = 8 },
			{ type = "vertical", row = 13, col = 13 },
			{ type = "vertical", row = 14, col = 13 },
			{ type = "vertical", row = 15, col = 13 },
			{ type = "vertical", row = 16, col = 13 },
		},
		enemies = {
			{ enemyType = P, col = 6, row = 4 },
			{ enemyType = P, col = 17, row = 4 },
			{ enemyType = P, col = 6, row = 16 },
			{ enemyType = F, col = 11, row = 7 },
			{ enemyType = F, col = 16, row = 15 },
		},
		playerSpawn = Vector2.new(11, 11),
	},

	-- Stage 6: Hourglass/bridge island. 5 enemies.
	[6] = {
		islandMask = makeIslandMask({
			"......................",
			"......................",
			"...##############.....",
			"...##############.....",
			"...##############.....",
			"...##############.....",
			"...##############.....",
			"......########........",
			".........####.........",
			".........####.........",
			".........####.........",
			".........####.........",
			"......########........",
			"...##############.....",
			"...##############.....",
			"...##############.....",
			"...##############.....",
			"...##############.....",
			"......................",
			"......................",
			"......................",
			"......................",
		}),
		faults = {
			{ type = "horizontal", row = 5, col = 4 },
			{ type = "horizontal", row = 5, col = 5 },
			{ type = "horizontal", row = 5, col = 6 },
			{ type = "horizontal", row = 5, col = 7 },
			{ type = "horizontal", row = 5, col = 8 },
			{ type = "horizontal", row = 5, col = 9 },
			{ type = "horizontal", row = 5, col = 10 },
			{ type = "horizontal", row = 5, col = 11 },
			{ type = "horizontal", row = 5, col = 12 },
			{ type = "horizontal", row = 5, col = 13 },
			{ type = "horizontal", row = 5, col = 14 },
			{ type = "horizontal", row = 12, col = 7 },
			{ type = "horizontal", row = 12, col = 8 },
			{ type = "horizontal", row = 12, col = 9 },
			{ type = "horizontal", row = 12, col = 10 },
			{ type = "horizontal", row = 12, col = 11 },
			{ type = "horizontal", row = 12, col = 12 },
			{ type = "vertical", row = 3, col = 9 },
			{ type = "vertical", row = 4, col = 9 },
			{ type = "vertical", row = 14, col = 9 },
			{ type = "vertical", row = 15, col = 9 },
		},
		enemies = {
			{ enemyType = P, col = 5, row = 3 },
			{ enemyType = P, col = 14, row = 3 },
			{ enemyType = F, col = 5, row = 16 },
			{ enemyType = F, col = 14, row = 16 },
			{ enemyType = F, col = 11, row = 10 },
		},
		playerSpawn = Vector2.new(11, 10),
	},

	-- Stage 7: Large irregular island. 6 enemies.
	[7] = {
		islandMask = makeIslandMask({
			"......................",
			"......##########......",
			".....############.....",
			"....##############....",
			"....##############....",
			"....##############....",
			"...################...",
			"..##################..",
			"..##################..",
			"..##################..",
			"..##################..",
			"..##################..",
			"...################...",
			"....##############....",
			"....##############....",
			".....############.....",
			"......##########......",
			"......................",
			"......................",
			"......................",
			"......................",
			"......................",
		}),
		faults = {
			{ type = "horizontal", row = 4, col = 6 },
			{ type = "horizontal", row = 4, col = 7 },
			{ type = "horizontal", row = 4, col = 8 },
			{ type = "horizontal", row = 4, col = 9 },
			{ type = "vertical", row = 5, col = 9 },
			{ type = "vertical", row = 6, col = 9 },
			{ type = "vertical", row = 5, col = 15 },
			{ type = "vertical", row = 6, col = 15 },
			{ type = "vertical", row = 7, col = 15 },
			{ type = "horizontal", row = 8, col = 4 },
			{ type = "horizontal", row = 8, col = 5 },
			{ type = "horizontal", row = 8, col = 6 },
			{ type = "horizontal", row = 8, col = 7 },
			{ type = "horizontal", row = 8, col = 8 },
			{ type = "horizontal", row = 8, col = 9 },
			{ type = "horizontal", row = 12, col = 10 },
			{ type = "horizontal", row = 12, col = 11 },
			{ type = "horizontal", row = 12, col = 12 },
			{ type = "horizontal", row = 12, col = 13 },
			{ type = "horizontal", row = 12, col = 14 },
			{ type = "vertical", row = 9, col = 6 },
			{ type = "vertical", row = 10, col = 6 },
			{ type = "vertical", row = 11, col = 6 },
			{ type = "vertical", row = 12, col = 6 },
		},
		enemies = {
			{ enemyType = P, col = 9, row = 2 },
			{ enemyType = P, col = 14, row = 5 },
			{ enemyType = P, col = 4, row = 10 },
			{ enemyType = F, col = 16, row = 10 },
			{ enemyType = F, col = 8, row = 15 },
			{ enemyType = F, col = 14, row = 15 },
		},
		playerSpawn = Vector2.new(11, 9),
	},

	-- Stage 8: Ring/donut island. 6 enemies.
	[8] = {
		islandMask = makeIslandMask({
			"......................",
			"......##########......",
			".....############.....",
			"....##############....",
			"....####......####....",
			"....####......####....",
			"....####......####....",
			"....####......####....",
			"....####......####....",
			"....####......####....",
			"....####......####....",
			"....####......####....",
			"....####......####....",
			"....##############....",
			".....############.....",
			"......##########......",
			"......................",
			"......................",
			"......................",
			"......................",
			"......................",
			"......................",
		}),
		faults = {
			{ type = "horizontal", row = 3, col = 6 },
			{ type = "horizontal", row = 3, col = 7 },
			{ type = "horizontal", row = 3, col = 8 },
			{ type = "horizontal", row = 3, col = 9 },
			{ type = "horizontal", row = 3, col = 10 },
			{ type = "horizontal", row = 3, col = 11 },
			{ type = "horizontal", row = 3, col = 12 },
			{ type = "horizontal", row = 3, col = 13 },
			{ type = "horizontal", row = 3, col = 14 },
			{ type = "vertical", row = 4, col = 7 },
			{ type = "vertical", row = 5, col = 7 },
			{ type = "vertical", row = 6, col = 7 },
			{ type = "vertical", row = 7, col = 7 },
			{ type = "vertical", row = 8, col = 7 },
			{ type = "vertical", row = 4, col = 16 },
			{ type = "vertical", row = 5, col = 16 },
			{ type = "vertical", row = 6, col = 16 },
			{ type = "vertical", row = 7, col = 16 },
			{ type = "vertical", row = 8, col = 16 },
			{ type = "horizontal", row = 13, col = 6 },
			{ type = "horizontal", row = 13, col = 7 },
			{ type = "horizontal", row = 13, col = 8 },
			{ type = "horizontal", row = 13, col = 9 },
			{ type = "horizontal", row = 13, col = 10 },
			{ type = "horizontal", row = 13, col = 11 },
			{ type = "horizontal", row = 13, col = 12 },
			{ type = "horizontal", row = 13, col = 13 },
			{ type = "horizontal", row = 13, col = 14 },
		},
		enemies = {
			{ enemyType = P, col = 11, row = 2 },
			{ enemyType = P, col = 6, row = 8 },
			{ enemyType = P, col = 17, row = 8 },
			{ enemyType = F, col = 11, row = 14 },
			{ enemyType = F, col = 6, row = 4 },
			{ enemyType = F, col = 17, row = 4 },
		},
		playerSpawn = Vector2.new(11, 3),
	},

	-- Stage 9: Archipelago — two connected masses. 7 enemies.
	[9] = {
		islandMask = makeIslandMask({
			"......................",
			"...##########.........",
			"...##########.........",
			"...##########.........",
			"...##########.........",
			"...##########.........",
			"...##########.........",
			"...##########.........",
			"......######..........",
			".......######.........",
			"........##########....",
			"........##########....",
			"........##########....",
			"........##########....",
			"........##########....",
			"........##########....",
			"........##########....",
			"........##########....",
			"......................",
			"......................",
			"......................",
			"......................",
		}),
		faults = {
			{ type = "horizontal", row = 4, col = 4 },
			{ type = "horizontal", row = 4, col = 5 },
			{ type = "horizontal", row = 4, col = 6 },
			{ type = "horizontal", row = 4, col = 7 },
			{ type = "vertical", row = 2, col = 8 },
			{ type = "vertical", row = 3, col = 8 },
			{ type = "vertical", row = 4, col = 8 },
			{ type = "vertical", row = 5, col = 8 },
			{ type = "horizontal", row = 6, col = 4 },
			{ type = "horizontal", row = 6, col = 5 },
			{ type = "horizontal", row = 6, col = 6 },
			{ type = "horizontal", row = 6, col = 7 },
			{ type = "horizontal", row = 6, col = 8 },
			{ type = "horizontal", row = 6, col = 9 },
			{ type = "horizontal", row = 6, col = 10 },
			{ type = "horizontal", row = 6, col = 11 },
			{ type = "horizontal", row = 14, col = 9 },
			{ type = "horizontal", row = 14, col = 10 },
			{ type = "horizontal", row = 14, col = 11 },
			{ type = "horizontal", row = 14, col = 12 },
			{ type = "horizontal", row = 14, col = 13 },
			{ type = "horizontal", row = 14, col = 14 },
			{ type = "horizontal", row = 14, col = 15 },
			{ type = "horizontal", row = 14, col = 16 },
			{ type = "vertical", row = 11, col = 13 },
			{ type = "vertical", row = 12, col = 13 },
			{ type = "vertical", row = 13, col = 13 },
			{ type = "vertical", row = 14, col = 13 },
			{ type = "vertical", row = 15, col = 13 },
		},
		enemies = {
			{ enemyType = P, col = 5, row = 2 },
			{ enemyType = P, col = 11, row = 2 },
			{ enemyType = P, col = 7, row = 6 },
			{ enemyType = P, col = 12, row = 14 },
			{ enemyType = F, col = 10, row = 17 },
			{ enemyType = F, col = 16, row = 17 },
			{ enemyType = F, col = 4, row = 5 },
		},
		playerSpawn = Vector2.new(8, 5),
	},

	-- Stage 10: Maximum challenge. Large complex island, 8 enemies.
	[10] = {
		islandMask = makeIslandMask({
			"......................",
			"...################...",
			"...################...",
			"..##################..",
			"..##################..",
			"..##################..",
			"..##################..",
			"..##################..",
			"..##################..",
			"..##################..",
			"..##################..",
			"..##################..",
			"..##################..",
			"..##################..",
			"..##################..",
			"..##################..",
			"...################...",
			"...################...",
			"....##############....",
			"......................",
			"......................",
			"......................",
		}),
		faults = {
			-- Top horizontal cut
			{ type = "horizontal", row = 4, col = 5 },
			{ type = "horizontal", row = 4, col = 6 },
			{ type = "horizontal", row = 4, col = 7 },
			{ type = "horizontal", row = 4, col = 8 },
			{ type = "horizontal", row = 4, col = 9 },
			-- Top right vertical
			{ type = "vertical", row = 2, col = 14 },
			{ type = "vertical", row = 3, col = 14 },
			{ type = "vertical", row = 4, col = 14 },
			-- Mid-left horizontal
			{ type = "horizontal", row = 8, col = 3 },
			{ type = "horizontal", row = 8, col = 4 },
			{ type = "horizontal", row = 8, col = 5 },
			{ type = "horizontal", row = 8, col = 6 },
			{ type = "horizontal", row = 8, col = 7 },
			-- Center vertical
			{ type = "vertical", row = 6, col = 11 },
			{ type = "vertical", row = 7, col = 11 },
			{ type = "vertical", row = 8, col = 11 },
			{ type = "vertical", row = 9, col = 11 },
			-- Center right horizontal
			{ type = "horizontal", row = 9, col = 12 },
			{ type = "horizontal", row = 9, col = 13 },
			{ type = "horizontal", row = 9, col = 14 },
			{ type = "horizontal", row = 9, col = 15 },
			{ type = "horizontal", row = 9, col = 16 },
			{ type = "horizontal", row = 9, col = 17 },
			-- Bottom left
			{ type = "horizontal", row = 13, col = 4 },
			{ type = "horizontal", row = 13, col = 5 },
			{ type = "horizontal", row = 13, col = 6 },
			{ type = "horizontal", row = 13, col = 7 },
			{ type = "vertical", row = 13, col = 7 },
			{ type = "vertical", row = 14, col = 7 },
			{ type = "vertical", row = 15, col = 7 },
			-- Bottom right
			{ type = "vertical", row = 11, col = 16 },
			{ type = "vertical", row = 12, col = 16 },
			{ type = "vertical", row = 13, col = 16 },
			{ type = "vertical", row = 14, col = 16 },
			{ type = "horizontal", row = 14, col = 10 },
			{ type = "horizontal", row = 14, col = 11 },
			{ type = "horizontal", row = 14, col = 12 },
			{ type = "horizontal", row = 14, col = 13 },
			{ type = "horizontal", row = 14, col = 14 },
			{ type = "horizontal", row = 14, col = 15 },
		},
		enemies = {
			{ enemyType = P, col = 6, row = 3 },
			{ enemyType = P, col = 17, row = 3 },
			{ enemyType = P, col = 4, row = 10 },
			{ enemyType = P, col = 18, row = 7 },
			{ enemyType = F, col = 8, row = 7 },
			{ enemyType = F, col = 15, row = 13 },
			{ enemyType = F, col = 6, row = 16 },
			{ enemyType = F, col = 14, row = 17 },
		},
		playerSpawn = Vector2.new(11, 11),
	},
}

local StageLayoutsModule = {}

function StageLayoutsModule.GetLayout(stage: number): StageLayout?
	return StageLayouts[stage]
end

function StageLayoutsModule.GenerateProceduralLayout(stage: number): StageLayout
	local enemyCount = math.min(4 + math.floor(stage / 2), 10)
	local pookaCount = math.max(2, math.floor(enemyCount * 0.5))
	local fygarCount = enemyCount - pookaCount

	-- Generate an irregular island using distance from center
	local centerR = ROWS / 2
	local centerC = COLS / 2
	local baseRadius = 7 + math.min(stage * 0.1, 2)

	local mask: { { boolean } } = {}
	for row = 1, ROWS do
		mask[row] = {}
		for col = 1, COLS do
			local dist = math.sqrt((row - centerR) ^ 2 + (col - centerC) ^ 2)
			local angle = math.atan2(row - centerR, col - centerC)
			local noise = math.sin(angle * 3 + stage) * 1.5 + math.cos(angle * 5 + stage * 2) * 1.0
			mask[row][col] = dist < (baseRadius + noise) and row > 1 and row < ROWS and col > 1 and col < COLS
		end
	end

	-- Generate fault lines along grid edges within the island
	local faults: { FaultLine } = {}
	local faultCount = math.min(18 + stage * 2, 50)

	for _ = 1, faultCount do
		local isHorizontal = math.random() > 0.5
		local row = math.random(2, ROWS - 2)
		local col = math.random(2, COLS - 2)

		if isHorizontal then
			if row < ROWS and mask[row][col] and mask[row + 1][col] then
				table.insert(faults, { type = "horizontal", row = row, col = col })
			end
		else
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

	local playerSpawn = Vector2.new(math.floor(centerC), math.floor(centerR))
	usedCells[`{playerSpawn.X}_{playerSpawn.Y}`] = true

	for _ = 1, pookaCount do
		local cell = islandCells[math.random(1, #islandCells)]
		local key = `{cell.X}_{cell.Y}`
		if not usedCells[key] then
			table.insert(enemies, { enemyType = P, col = cell.X, row = cell.Y })
			usedCells[key] = true
		end
	end
	for _ = 1, fygarCount do
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
