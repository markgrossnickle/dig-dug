--!strict
-- Predefined stage layouts for stages 1-10. Stage 11+ uses procedural generation.
-- Each layout defines: enemy spawn positions, rock positions, and tunnel segments.

local DigDugConfig = require(script.Parent.DigDugConfig)

local COLS = DigDugConfig.GRID_COLUMNS
local ROWS = DigDugConfig.GRID_ROWS

export type TunnelSegment = {
	type: "horizontal" | "vertical",
	col: number,
	row: number,
	length: number,
}

export type EnemySpawn = {
	enemyType: string,
	col: number,
	row: number,
}

export type RockPos = {
	col: number,
	row: number,
}

export type StageLayout = {
	tunnels: { TunnelSegment },
	enemies: { EnemySpawn },
	rocks: { RockPos },
}

local P = DigDugConfig.EnemyType.POOKA
local F = DigDugConfig.EnemyType.FYGAR

local StageLayouts: { [number]: StageLayout } = {
	-- Stage 1: Easy. Generous tunnels, enemies spread out, 2 rocks.
	[1] = {
		tunnels = {
			-- Player area
			{ type = "horizontal", col = 5, row = 1, length = 4 },
			-- Layer 1: wide open tunnel
			{ type = "horizontal", col = 2, row = 4, length = 10 },
			{ type = "vertical", col = 4, row = 2, length = 3 },
			{ type = "vertical", col = 10, row = 2, length = 3 },
			-- Layer 2: medium tunnel
			{ type = "horizontal", col = 3, row = 8, length = 8 },
			{ type = "vertical", col = 6, row = 5, length = 4 },
			-- Layer 3: small pocket
			{ type = "horizontal", col = 5, row = 12, length = 5 },
			{ type = "vertical", col = 8, row = 9, length = 4 },
		},
		enemies = {
			{ enemyType = P, col = 3, row = 4 },
			{ enemyType = P, col = 9, row = 4 },
			{ enemyType = P, col = 5, row = 8 },
			{ enemyType = F, col = 7, row = 12 },
		},
		rocks = {
			{ col = 5, row = 3 },
			{ col = 11, row = 7 },
		},
	},

	-- Stage 2: Slightly harder. More vertical tunnels, enemies a bit deeper.
	[2] = {
		tunnels = {
			{ type = "horizontal", col = 6, row = 1, length = 3 },
			{ type = "horizontal", col = 3, row = 4, length = 5 },
			{ type = "horizontal", col = 9, row = 5, length = 4 },
			{ type = "vertical", col = 5, row = 2, length = 3 },
			{ type = "vertical", col = 11, row = 2, length = 4 },
			{ type = "horizontal", col = 2, row = 9, length = 6 },
			{ type = "horizontal", col = 8, row = 10, length = 5 },
			{ type = "vertical", col = 4, row = 5, length = 5 },
			{ type = "vertical", col = 10, row = 6, length = 5 },
			{ type = "horizontal", col = 4, row = 14, length = 6 },
		},
		enemies = {
			{ enemyType = P, col = 4, row = 4 },
			{ enemyType = P, col = 10, row = 5 },
			{ enemyType = P, col = 3, row = 9 },
			{ enemyType = F, col = 6, row = 14 },
		},
		rocks = {
			{ col = 3, row = 3 },
			{ col = 12, row = 8 },
		},
	},

	-- Stage 3: Two Fygars now. Tunnels less connected.
	[3] = {
		tunnels = {
			{ type = "horizontal", col = 6, row = 1, length = 3 },
			{ type = "vertical", col = 7, row = 2, length = 3 },
			{ type = "horizontal", col = 2, row = 5, length = 4 },
			{ type = "horizontal", col = 10, row = 4, length = 3 },
			{ type = "vertical", col = 3, row = 6, length = 4 },
			{ type = "horizontal", col = 5, row = 9, length = 5 },
			{ type = "vertical", col = 11, row = 5, length = 5 },
			{ type = "horizontal", col = 3, row = 13, length = 4 },
			{ type = "horizontal", col = 9, row = 13, length = 4 },
			{ type = "vertical", col = 7, row = 10, length = 4 },
		},
		enemies = {
			{ enemyType = P, col = 3, row = 5 },
			{ enemyType = P, col = 11, row = 4 },
			{ enemyType = F, col = 7, row = 9 },
			{ enemyType = F, col = 4, row = 13 },
		},
		rocks = {
			{ col = 6, row = 3 },
			{ col = 10, row = 7 },
			{ col = 4, row = 11 },
		},
	},

	-- Stage 4: More enemies, tighter spaces.
	[4] = {
		tunnels = {
			{ type = "horizontal", col = 6, row = 1, length = 3 },
			{ type = "vertical", col = 7, row = 2, length = 2 },
			{ type = "horizontal", col = 2, row = 4, length = 3 },
			{ type = "horizontal", col = 10, row = 4, length = 3 },
			{ type = "vertical", col = 4, row = 5, length = 3 },
			{ type = "horizontal", col = 5, row = 8, length = 4 },
			{ type = "vertical", col = 11, row = 5, length = 4 },
			{ type = "horizontal", col = 2, row = 12, length = 5 },
			{ type = "horizontal", col = 9, row = 11, length = 4 },
			{ type = "vertical", col = 6, row = 9, length = 4 },
		},
		enemies = {
			{ enemyType = P, col = 3, row = 4 },
			{ enemyType = P, col = 11, row = 4 },
			{ enemyType = F, col = 6, row = 8 },
			{ enemyType = F, col = 3, row = 12 },
		},
		rocks = {
			{ col = 5, row = 3 },
			{ col = 9, row = 6 },
			{ col = 7, row = 10 },
		},
	},

	-- Stage 5: Five enemies total.
	[5] = {
		tunnels = {
			{ type = "horizontal", col = 6, row = 1, length = 3 },
			{ type = "vertical", col = 8, row = 2, length = 3 },
			{ type = "horizontal", col = 2, row = 4, length = 4 },
			{ type = "horizontal", col = 10, row = 5, length = 3 },
			{ type = "vertical", col = 3, row = 5, length = 4 },
			{ type = "vertical", col = 12, row = 6, length = 3 },
			{ type = "horizontal", col = 5, row = 8, length = 5 },
			{ type = "horizontal", col = 2, row = 12, length = 4 },
			{ type = "horizontal", col = 8, row = 13, length = 5 },
			{ type = "vertical", col = 6, row = 9, length = 4 },
			{ type = "vertical", col = 10, row = 9, length = 5 },
		},
		enemies = {
			{ enemyType = P, col = 3, row = 4 },
			{ enemyType = P, col = 11, row = 5 },
			{ enemyType = P, col = 3, row = 12 },
			{ enemyType = F, col = 7, row = 8 },
			{ enemyType = F, col = 10, row = 13 },
		},
		rocks = {
			{ col = 4, row = 3 },
			{ col = 9, row = 7 },
			{ col = 5, row = 11 },
		},
	},

	-- Stage 6: Three Fygars. Disconnected chambers.
	[6] = {
		tunnels = {
			{ type = "horizontal", col = 6, row = 1, length = 3 },
			{ type = "vertical", col = 6, row = 2, length = 2 },
			{ type = "horizontal", col = 2, row = 4, length = 3 },
			{ type = "horizontal", col = 11, row = 3, length = 2 },
			{ type = "vertical", col = 12, row = 4, length = 3 },
			{ type = "horizontal", col = 5, row = 7, length = 4 },
			{ type = "horizontal", col = 2, row = 10, length = 3 },
			{ type = "vertical", col = 8, row = 8, length = 4 },
			{ type = "horizontal", col = 9, row = 12, length = 4 },
			{ type = "horizontal", col = 3, row = 14, length = 5 },
			{ type = "vertical", col = 4, row = 5, length = 6 },
		},
		enemies = {
			{ enemyType = P, col = 3, row = 4 },
			{ enemyType = P, col = 12, row = 3 },
			{ enemyType = F, col = 6, row = 7 },
			{ enemyType = F, col = 3, row = 10 },
			{ enemyType = F, col = 10, row = 12 },
		},
		rocks = {
			{ col = 5, row = 3 },
			{ col = 11, row = 6 },
			{ col = 7, row = 10 },
			{ col = 4, row = 13 },
		},
	},

	-- Stage 7: Six enemies. Maze-like.
	[7] = {
		tunnels = {
			{ type = "horizontal", col = 6, row = 1, length = 3 },
			{ type = "vertical", col = 7, row = 2, length = 2 },
			{ type = "horizontal", col = 2, row = 3, length = 3 },
			{ type = "horizontal", col = 11, row = 4, length = 2 },
			{ type = "vertical", col = 3, row = 4, length = 3 },
			{ type = "horizontal", col = 5, row = 6, length = 4 },
			{ type = "vertical", col = 12, row = 5, length = 4 },
			{ type = "horizontal", col = 2, row = 9, length = 4 },
			{ type = "horizontal", col = 8, row = 9, length = 4 },
			{ type = "vertical", col = 6, row = 7, length = 4 },
			{ type = "vertical", col = 10, row = 10, length = 3 },
			{ type = "horizontal", col = 3, row = 13, length = 4 },
			{ type = "horizontal", col = 9, row = 14, length = 4 },
			{ type = "vertical", col = 5, row = 11, length = 3 },
		},
		enemies = {
			{ enemyType = P, col = 3, row = 3 },
			{ enemyType = P, col = 12, row = 4 },
			{ enemyType = P, col = 3, row = 9 },
			{ enemyType = F, col = 6, row = 6 },
			{ enemyType = F, col = 10, row = 9 },
			{ enemyType = F, col = 4, row = 13 },
		},
		rocks = {
			{ col = 4, row = 2 },
			{ col = 9, row = 5 },
			{ col = 7, row = 8 },
			{ col = 11, row = 12 },
		},
	},

	-- Stage 8: Six enemies, deep Fygars.
	[8] = {
		tunnels = {
			{ type = "horizontal", col = 6, row = 1, length = 3 },
			{ type = "vertical", col = 8, row = 2, length = 3 },
			{ type = "horizontal", col = 2, row = 4, length = 3 },
			{ type = "horizontal", col = 10, row = 3, length = 3 },
			{ type = "vertical", col = 4, row = 5, length = 3 },
			{ type = "vertical", col = 11, row = 4, length = 4 },
			{ type = "horizontal", col = 5, row = 7, length = 3 },
			{ type = "horizontal", col = 2, row = 10, length = 4 },
			{ type = "horizontal", col = 9, row = 10, length = 4 },
			{ type = "vertical", col = 7, row = 8, length = 4 },
			{ type = "horizontal", col = 3, row = 14, length = 3 },
			{ type = "horizontal", col = 8, row = 14, length = 4 },
			{ type = "vertical", col = 5, row = 11, length = 4 },
			{ type = "vertical", col = 10, row = 11, length = 4 },
		},
		enemies = {
			{ enemyType = P, col = 3, row = 4 },
			{ enemyType = P, col = 11, row = 3 },
			{ enemyType = P, col = 3, row = 10 },
			{ enemyType = F, col = 6, row = 7 },
			{ enemyType = F, col = 10, row = 10 },
			{ enemyType = F, col = 9, row = 14 },
		},
		rocks = {
			{ col = 5, row = 3 },
			{ col = 9, row = 6 },
			{ col = 3, row = 9 },
			{ col = 12, row = 12 },
		},
	},

	-- Stage 9: Seven enemies. Minimal tunnels.
	[9] = {
		tunnels = {
			{ type = "horizontal", col = 6, row = 1, length = 3 },
			{ type = "vertical", col = 7, row = 2, length = 2 },
			{ type = "horizontal", col = 2, row = 4, length = 3 },
			{ type = "horizontal", col = 10, row = 4, length = 3 },
			{ type = "vertical", col = 4, row = 5, length = 2 },
			{ type = "vertical", col = 11, row = 5, length = 2 },
			{ type = "horizontal", col = 3, row = 7, length = 3 },
			{ type = "horizontal", col = 9, row = 8, length = 3 },
			{ type = "vertical", col = 6, row = 6, length = 3 },
			{ type = "horizontal", col = 5, row = 11, length = 4 },
			{ type = "vertical", col = 8, row = 9, length = 3 },
			{ type = "horizontal", col = 2, row = 14, length = 4 },
			{ type = "horizontal", col = 9, row = 14, length = 4 },
			{ type = "vertical", col = 4, row = 12, length = 3 },
			{ type = "vertical", col = 11, row = 12, length = 3 },
		},
		enemies = {
			{ enemyType = P, col = 3, row = 4 },
			{ enemyType = P, col = 11, row = 4 },
			{ enemyType = P, col = 4, row = 7 },
			{ enemyType = P, col = 10, row = 8 },
			{ enemyType = F, col = 6, row = 11 },
			{ enemyType = F, col = 3, row = 14 },
			{ enemyType = F, col = 11, row = 14 },
		},
		rocks = {
			{ col = 5, row = 3 },
			{ col = 9, row = 6 },
			{ col = 3, row = 10 },
			{ col = 12, row = 11 },
		},
	},

	-- Stage 10: Eight enemies. Dense, hard.
	[10] = {
		tunnels = {
			{ type = "horizontal", col = 6, row = 1, length = 3 },
			{ type = "vertical", col = 7, row = 2, length = 2 },
			{ type = "horizontal", col = 2, row = 3, length = 2 },
			{ type = "horizontal", col = 11, row = 3, length = 2 },
			{ type = "vertical", col = 3, row = 4, length = 2 },
			{ type = "vertical", col = 12, row = 4, length = 2 },
			{ type = "horizontal", col = 5, row = 6, length = 4 },
			{ type = "horizontal", col = 2, row = 8, length = 3 },
			{ type = "horizontal", col = 10, row = 8, length = 3 },
			{ type = "vertical", col = 6, row = 7, length = 2 },
			{ type = "vertical", col = 9, row = 7, length = 2 },
			{ type = "horizontal", col = 3, row = 11, length = 3 },
			{ type = "horizontal", col = 9, row = 11, length = 4 },
			{ type = "vertical", col = 5, row = 9, length = 3 },
			{ type = "vertical", col = 11, row = 9, length = 3 },
			{ type = "horizontal", col = 4, row = 14, length = 3 },
			{ type = "horizontal", col = 9, row = 15, length = 3 },
			{ type = "vertical", col = 7, row = 12, length = 4 },
		},
		enemies = {
			{ enemyType = P, col = 2, row = 3 },
			{ enemyType = P, col = 12, row = 3 },
			{ enemyType = P, col = 3, row = 8 },
			{ enemyType = P, col = 11, row = 8 },
			{ enemyType = F, col = 6, row = 6 },
			{ enemyType = F, col = 4, row = 11 },
			{ enemyType = F, col = 10, row = 11 },
			{ enemyType = F, col = 5, row = 14 },
		},
		rocks = {
			{ col = 4, row = 2 },
			{ col = 10, row = 5 },
			{ col = 3, row = 7 },
			{ col = 12, row = 10 },
			{ col = 6, row = 13 },
		},
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
	local rockCount = math.min(3 + math.floor(stage / 3), 6)

	local tunnels: { TunnelSegment } = {}
	local enemies: { EnemySpawn } = {}
	local rocks: { RockPos } = {}

	-- Player spawn tunnel
	table.insert(tunnels, { type = "horizontal", col = 6, row = 1, length = 3 })

	-- Generate tunnel chambers at different depths
	local chamberRows = { 4, 7, 10, 13, 15 }
	for _, row in chamberRows do
		if row <= ROWS then
			local col = math.random(2, COLS - 4)
			local length = math.random(3, 5)
			table.insert(tunnels, { type = "horizontal", col = col, row = row, length = length })
		end
	end

	-- Connect with vertical tunnels
	for _ = 1, 4 do
		local col = math.random(3, COLS - 2)
		local startRow = math.random(2, 6)
		local length = math.random(3, 5)
		table.insert(tunnels, { type = "vertical", col = col, row = startRow, length = length })
	end

	-- Place enemies in tunnel areas
	for i = 1, pookaCount do
		local row = chamberRows[math.min(i, #chamberRows)]
		local col = math.random(2, COLS - 1)
		table.insert(enemies, { enemyType = P, col = col, row = row })
	end
	for i = 1, fygarCount do
		local row = chamberRows[math.min(pookaCount + i, #chamberRows)]
		local col = math.random(2, COLS - 1)
		table.insert(enemies, { enemyType = F, col = col, row = row })
	end

	-- Place rocks
	for i = 1, rockCount do
		local col = math.random(2, COLS - 1)
		local row = math.min(2 + i * 3, ROWS - 2)
		table.insert(rocks, { col = col, row = row })
	end

	return { tunnels = tunnels, enemies = enemies, rocks = rocks }
end

return StageLayoutsModule
