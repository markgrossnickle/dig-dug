--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local DigDugConfig = require(ReplicatedStorage.Shared.DigDugConfig)

local CELL_SIZE = DigDugConfig.CELL_SIZE

local RockController = Knit.CreateController({
	Name = "RockController",
})

RockController._fallingRocks = {} :: { [number]: Part }

function RockController:KnitInit()
	self._fallingRocks = {}
end

function RockController:KnitStart()
	local RockService = Knit.GetService("RockService")
	local GridController = Knit.GetController("GridController")

	RockService.RockStartFalling:Connect(function(rockId: number, col: number, row: number)
		-- Create a separate falling rock part
		local worldPos = GridController:GridToWorld(col, row)
		local part = Instance.new("Part")
		part.Name = `FallingRock_{rockId}`
		part.Anchored = true
		part.CanCollide = false
		part.Size = Vector3.new(CELL_SIZE * 0.9, CELL_SIZE * 0.9, CELL_SIZE * 0.9)
		part.Position = worldPos
		part.Color = Color3.fromRGB(128, 128, 128)
		part.Material = Enum.Material.Slate
		part.Parent = workspace
		self._fallingRocks[rockId] = part
	end)

	RockService.RockMoved:Connect(function(rockId: number, col: number, row: number)
		local part = self._fallingRocks[rockId]
		if part then
			local worldPos = GridController:GridToWorld(col, row)
			part.Position = worldPos
		end
	end)

	RockService.RockDestroyed:Connect(function(rockId: number)
		local part = self._fallingRocks[rockId]
		if part then
			-- Quick break animation
			task.spawn(function()
				for i = 1, 5 do
					if not part or not part.Parent then
						break
					end
					part.Transparency = i / 5
					task.wait(0.05)
				end
				if part and part.Parent then
					part:Destroy()
				end
			end)
			self._fallingRocks[rockId] = nil
		end
	end)

	-- Clean up on grid reset
	local GridService = Knit.GetService("GridService")
	GridService.GridReset:Connect(function()
		for _, part in self._fallingRocks do
			part:Destroy()
		end
		self._fallingRocks = {}
	end)
end

return RockController
