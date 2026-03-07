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
			local shatterPos = part.Position
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
			-- Spawn debris fragments
			self:_spawnDebris(shatterPos)
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

function RockController:_spawnDebris(pos: Vector3)
	for i = 1, 6 do
		local debris = Instance.new("Part")
		debris.Name = "RockDebris"
		debris.Anchored = true
		debris.CanCollide = false
		local size = 0.4 + math.random() * 0.5
		debris.Size = Vector3.new(size, size, size)
		debris.Position = pos
		debris.Color = Color3.fromRGB(100 + math.random(0, 50), 100 + math.random(0, 50), 100 + math.random(0, 50))
		debris.Material = Enum.Material.Slate
		debris.Parent = workspace

		local angle = (i / 6) * math.pi * 2
		local velX = math.cos(angle) * (4 + math.random() * 3)
		local velY = math.sin(angle) * 4 + 2

		task.spawn(function()
			for step = 1, 15 do
				if not debris or not debris.Parent then
					break
				end
				velY = velY - 0.5
				debris.Position = debris.Position + Vector3.new(velX * 0.02, velY * 0.02, 0)
				debris.Transparency = step / 15
				task.wait(0.03)
			end
			if debris and debris.Parent then
				debris:Destroy()
			end
		end)
	end
end

return RockController
