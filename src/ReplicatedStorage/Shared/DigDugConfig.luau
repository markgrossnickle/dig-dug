--!strict
-- Central configuration for Dig Dug II (island/fault-line style)

local DigDugConfig = {}

-- Grid dimensions (island area including surrounding water)
DigDugConfig.GRID_COLUMNS = 16
DigDugConfig.GRID_ROWS = 16

-- Cell size in studs
DigDugConfig.CELL_SIZE = 4

-- Grid origin in world space (top-left corner on XZ plane, Y=0)
DigDugConfig.GRID_ORIGIN = Vector3.new(
	-(DigDugConfig.GRID_COLUMNS * DigDugConfig.CELL_SIZE) / 2,
	0,
	-(DigDugConfig.GRID_ROWS * DigDugConfig.CELL_SIZE) / 2
)

-- Movement speed (cells per second)
DigDugConfig.PLAYER_SPEED = 5
DigDugConfig.ENEMY_SPEED = 3

-- Pump mechanics
DigDugConfig.PUMP_RANGE = 4 -- cells
DigDugConfig.PUMP_INFLATE_TIME = 0.4 -- seconds per pump
DigDugConfig.PUMP_POPS_REQUIRED = 4
DigDugConfig.PUMP_DEFLATE_TIME = 1.0 -- seconds before enemy deflates one stage

-- Cell types
DigDugConfig.CellType = {
	WATER = 0,
	ISLAND = 1,
	SUNK = 2, -- island chunk that sank (becomes water visually)
}

-- Fault line states
DigDugConfig.FaultState = {
	INTACT = 0,
	DRILLED = 1,
}

-- Direction vectors (grid-relative: col, row)
DigDugConfig.Direction = {
	UP = Vector2.new(0, -1),
	DOWN = Vector2.new(0, 1),
	LEFT = Vector2.new(-1, 0),
	RIGHT = Vector2.new(1, 0),
	NONE = Vector2.new(0, 0),
}

-- Enemy types
DigDugConfig.EnemyType = {
	POOKA = "Pooka", -- round red enemies
	FYGAR = "Fygar", -- fire-breathing dragons
}

-- Visual colors
DigDugConfig.ISLAND_COLOR = Color3.fromRGB(210, 180, 120) -- sandy tan
DigDugConfig.WATER_COLOR = Color3.fromRGB(40, 100, 200)   -- ocean blue
DigDugConfig.SUNK_COLOR = Color3.fromRGB(30, 80, 170)     -- darker blue (recently sunk)
DigDugConfig.FAULT_INTACT_COLOR = Color3.fromRGB(140, 110, 70) -- subtle brown crack
DigDugConfig.FAULT_DRILLED_COLOR = Color3.fromRGB(255, 60, 60) -- bright red drilled

-- Scoring
DigDugConfig.Scoring = {
	-- Pooka kill by pump
	POOKA_PUMP = 200,
	-- Fygar kill by pump
	FYGAR_PUMP = 400,
	-- Chunk kills (by number of enemies sunk)
	CHUNK_KILL_1 = 1000,  -- 1 enemy sunk
	CHUNK_KILL_2 = 2500,  -- 2 enemies sunk
	CHUNK_KILL_3 = 4000,  -- 3 enemies sunk
	CHUNK_KILL_4 = 6000,  -- 4 enemies sunk
	CHUNK_KILL_5 = 8000,  -- 5+ enemies sunk
	-- Drilling
	DRILL_FAULT = 10,
	-- Last enemy fleeing
	LAST_ENEMY_ESCAPED = 0,
}

-- Stage configuration
DigDugConfig.STARTING_LIVES = 3
DigDugConfig.EXTRA_LIFE_SCORE = 20000

-- Player spawn position (grid coordinates) — default center, overridden per stage
DigDugConfig.PLAYER_SPAWN = Vector2.new(8, 8)

-- Timing
DigDugConfig.ROUND_START_DELAY = 2.0
DigDugConfig.DEATH_DELAY = 2.0
DigDugConfig.STAGE_CLEAR_DELAY = 3.0
DigDugConfig.CHUNK_SINK_TIME = 1.0 -- seconds for chunk sink animation

return DigDugConfig
