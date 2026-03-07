--!strict
-- Central configuration for the Dig Dug game

local DigDugConfig = {}

-- Grid dimensions (classic Dig Dug is roughly 14 columns x 16 rows)
DigDugConfig.GRID_COLUMNS = 14
DigDugConfig.GRID_ROWS = 16

-- Cell size in studs
DigDugConfig.CELL_SIZE = 4

-- Grid origin in world space (top-left corner of the grid)
DigDugConfig.GRID_ORIGIN = Vector3.new(
	-(DigDugConfig.GRID_COLUMNS * DigDugConfig.CELL_SIZE) / 2,
	DigDugConfig.GRID_ROWS * DigDugConfig.CELL_SIZE,
	0
)

-- Movement speed (cells per second)
DigDugConfig.PLAYER_SPEED = 5
DigDugConfig.ENEMY_SPEED = 3
DigDugConfig.ENEMY_GHOST_SPEED = 2

-- Pump mechanics
DigDugConfig.PUMP_RANGE = 4 -- cells
DigDugConfig.PUMP_INFLATE_TIME = 0.4 -- seconds per pump
DigDugConfig.PUMP_POPS_REQUIRED = 4
DigDugConfig.PUMP_DEFLATE_TIME = 1.0 -- seconds before enemy deflates one stage

-- Rock mechanics
DigDugConfig.ROCK_FALL_DELAY = 0.5 -- seconds before rock starts falling
DigDugConfig.ROCK_FALL_SPEED = 10 -- cells per second

-- Cell types
DigDugConfig.CellType = {
	EMPTY = 0,
	DIRT = 1,
	ROCK = 2,
	TUNNEL = 3, -- pre-dug starting tunnels
}

-- Direction vectors (grid-relative)
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

-- Depth layers (rows) and their colors
-- Classic Dig Dug has 4 distinct earth layers
DigDugConfig.DepthLayers = {
	{ startRow = 1, endRow = 2, color = Color3.fromRGB(139, 90, 43) }, -- topsoil (brown)
	{ startRow = 3, endRow = 6, color = Color3.fromRGB(180, 100, 30) }, -- light earth
	{ startRow = 7, endRow = 11, color = Color3.fromRGB(120, 70, 20) }, -- mid earth
	{ startRow = 12, endRow = 16, color = Color3.fromRGB(80, 50, 15) }, -- deep earth
}

-- Surface/sky color
DigDugConfig.SKY_COLOR = Color3.fromRGB(100, 149, 237) -- cornflower blue
DigDugConfig.SURFACE_COLOR = Color3.fromRGB(34, 139, 34) -- green grass

-- Tunnel color (background behind dug paths)
DigDugConfig.TUNNEL_COLOR = Color3.fromRGB(20, 20, 40) -- dark background

-- Scoring
DigDugConfig.Scoring = {
	-- Pooka kill by pump (varies by depth layer)
	POOKA_LAYER_1 = 200,
	POOKA_LAYER_2 = 300,
	POOKA_LAYER_3 = 400,
	POOKA_LAYER_4 = 500,
	-- Fygar kill by pump (varies by depth layer, horizontal bonus)
	FYGAR_LAYER_1 = 400,
	FYGAR_LAYER_2 = 600,
	FYGAR_LAYER_3 = 800,
	FYGAR_LAYER_4 = 1000,
	-- Rock kills
	ROCK_KILL_1 = 1000, -- 1 enemy crushed
	ROCK_KILL_2 = 2500, -- 2 enemies crushed
	ROCK_KILL_3 = 4000, -- 3 enemies crushed
	ROCK_KILL_4 = 6000, -- 4 enemies crushed
	ROCK_KILL_5 = 8000, -- 5+ enemies crushed
	-- Vegetables (bonus items)
	CARROT = 400,
	TURNIP = 600,
	MUSHROOM = 800,
	CUCUMBER = 1000,
	EGGPLANT = 2000,
	BELL_PEPPER = 3000,
	TOMATO = 4000,
	GARLIC = 5000,
	WATERMELON = 6000,
	GALAXIAN = 7000,
	PINEAPPLE = 8000,
	-- Digging
	DIG_CELL = 10,
	-- Last enemy fleeing
	LAST_ENEMY_ESCAPED = 0,
}

-- Stage configuration
DigDugConfig.STARTING_LIVES = 3
DigDugConfig.EXTRA_LIFE_SCORE = 20000

-- Stage enemy counts (index = stage number, value = {Pooka, Fygar})
DigDugConfig.StageEnemies = {
	{ 3, 1 }, -- Stage 1: 3 Pooka, 1 Fygar
	{ 3, 1 }, -- Stage 2
	{ 2, 2 }, -- Stage 3
	{ 2, 2 }, -- Stage 4
	{ 3, 2 }, -- Stage 5
	{ 2, 3 }, -- Stage 6
	{ 2, 3 }, -- Stage 7
	{ 3, 3 }, -- Stage 8
}

-- Rock positions per stage (column positions for rocks)
-- These are just defaults; actual positions depend on level layout
DigDugConfig.DEFAULT_ROCK_COLUMNS = { 3, 7, 11 }

-- Player spawn position (grid coordinates)
DigDugConfig.PLAYER_SPAWN = Vector2.new(7, 1)

-- Timing
DigDugConfig.ROUND_START_DELAY = 2.0
DigDugConfig.DEATH_DELAY = 2.0
DigDugConfig.STAGE_CLEAR_DELAY = 3.0
DigDugConfig.GHOST_MODE_TIME = 5.0 -- seconds before enemies start ghosting

return DigDugConfig
