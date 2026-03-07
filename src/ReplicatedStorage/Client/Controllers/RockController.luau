--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local RockController = Knit.CreateController({
	Name = "RockController",
})

function RockController:KnitInit() end

function RockController:KnitStart()
	local RockService = Knit.GetService("RockService")
	local GridController = Knit.GetController("GridController")

	RockService.RockFalling:Connect(function(col: number, row: number)
		-- The rock has moved to this position — update visual
		-- GridController handles rock parts via its _rockParts table
		-- We need to find the rock that was above and move it
		GridController:MoveRockPart(col, row - 1, col, row)
	end)

	RockService.RockDestroyed:Connect(function(col: number, row: number)
		GridController:DestroyRockPart(col, row)
	end)
end

return RockController
