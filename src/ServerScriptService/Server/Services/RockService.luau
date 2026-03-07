--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local DigDugConfig = require(ReplicatedStorage.Shared.DigDugConfig)

type FallingRock = {
	id: number,
	col: number,
	row: number,
	fallTimer: number,
	falling: boolean,
	settled: boolean,
}

local RockService = Knit.CreateService({
	Name = "RockService",
	Client = {
		RockStartFalling = Knit.CreateSignal(), -- (rockId, col, row)
		RockMoved = Knit.CreateSignal(), -- (rockId, col, row)
		RockDestroyed = Knit.CreateSignal(), -- (rockId)
	},
})

RockService._rocks = {} :: { FallingRock }
RockService._nextId = 1
RockService._heartbeatConn = nil :: RBXScriptConnection?
RockService._active = false

function RockService:KnitInit() end

function RockService:KnitStart() end

function RockService:InitRocks(player: Player)
	self._rocks = {}
	local GridService = Knit.GetService("GridService")

	for _, pos in GridService:GetRockPositions() do
		table.insert(self._rocks, {
			id = self._nextId,
			col = pos.X,
			row = pos.Y,
			fallTimer = 0,
			falling = false,
			settled = false,
		})
		self._nextId += 1
	end

	self._active = true
	self:_startLoop(player)
end

function RockService:Stop()
	self._active = false
	if self._heartbeatConn then
		self._heartbeatConn:Disconnect()
		self._heartbeatConn = nil
	end
end

function RockService:_startLoop(player: Player)
	if self._heartbeatConn then
		self._heartbeatConn:Disconnect()
	end

	self._heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		if not self._active then
			return
		end
		self:_update(dt, player)
	end)
end

function RockService:_update(dt: number, player: Player)
	local GridService = Knit.GetService("GridService")
	local EnemyService = Knit.GetService("EnemyService")
	local PlayerService = Knit.GetService("PlayerService")
	local GameService = Knit.GetService("GameService")

	for i = #self._rocks, 1, -1 do
		local rock = self._rocks[i]
		if rock.settled then
			continue
		end

		-- Check if ground below was dug out
		local belowRow = rock.row + 1
		if not rock.falling then
			if belowRow <= DigDugConfig.GRID_ROWS and GridService:IsWalkable(rock.col, belowRow) then
				rock.fallTimer += dt
				if rock.fallTimer >= DigDugConfig.ROCK_FALL_DELAY then
					rock.falling = true
					rock.fallTimer = 0
					-- Remove rock from grid at current position
					GridService:RemoveRock(rock.col, rock.row)
					-- Tell client a rock started falling
					self.Client.RockStartFalling:Fire(player, rock.id, rock.col, rock.row)
				end
			else
				rock.fallTimer = 0
			end
		else
			-- Rock is falling
			rock.fallTimer += dt
			local fallInterval = 1 / DigDugConfig.ROCK_FALL_SPEED

			if rock.fallTimer >= fallInterval then
				rock.fallTimer = 0
				local nextRow = rock.row + 1

				-- Check if can continue falling
				if nextRow > DigDugConfig.GRID_ROWS then
					self:_destroyRock(rock, i, player)
					continue
				end

				if not GridService:IsWalkable(rock.col, nextRow) then
					self:_destroyRock(rock, i, player)
					continue
				end

				-- Move rock down
				rock.row = nextRow

				-- Check for crushing enemies
				local crushed = EnemyService:CrushEnemiesAt(rock.col, rock.row, player)
				if crushed > 0 then
					local scoreKey = "ROCK_KILL_" .. tostring(math.min(crushed, 5))
					local points = DigDugConfig.Scoring[scoreKey] or 1000
					GameService:AddScore(player, points)
				end

				-- Check for crushing player
				local playerPos = PlayerService:GetPosition(player)
				if
					playerPos
					and math.floor(playerPos.X + 0.5) == rock.col
					and math.floor(playerPos.Y + 0.5) == rock.row
				then
					GameService:OnPlayerDied(player)
				end

				self.Client.RockMoved:Fire(player, rock.id, rock.col, rock.row)
			end
		end
	end
end

function RockService:_destroyRock(rock: FallingRock, index: number, player: Player)
	rock.settled = true
	self.Client.RockDestroyed:Fire(player, rock.id)
	table.remove(self._rocks, index)
end

return RockService
