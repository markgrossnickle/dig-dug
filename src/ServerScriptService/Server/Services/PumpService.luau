--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local DigDugConfig = require(ReplicatedStorage.Shared.DigDugConfig)

type PumpState = {
	active: boolean,
	targetEnemyId: number?,
	pumpTimer: number,
}

local PumpService = Knit.CreateService({
	Name = "PumpService",
	Client = {
		PumpHit = Knit.CreateSignal(),
		PumpMiss = Knit.CreateSignal(),
	},
})

PumpService._pumpStates = {} :: { [Player]: PumpState }
PumpService._heartbeatConn = nil :: RBXScriptConnection?

function PumpService:KnitInit() end

function PumpService:KnitStart()
	local PlayerService = Knit.GetService("PlayerService")
	PlayerService.PumpFired:Connect(function(player: Player)
		self:_onPumpFired(player)
	end)
end

function PumpService:_onPumpFired(player: Player)
	local PlayerService = Knit.GetService("PlayerService")
	local EnemyService = Knit.GetService("EnemyService")

	local pos = PlayerService:GetPosition(player)
	local dir = PlayerService:GetDirection(player)
	if not pos or not dir then
		return
	end

	-- Find enemy in pump direction
	local enemy = EnemyService:GetEnemyInDirection(pos.X, pos.Y, dir, DigDugConfig.PUMP_RANGE)
	if enemy then
		-- Start pumping this enemy
		self._pumpStates[player] = {
			active = true,
			targetEnemyId = enemy.id,
			pumpTimer = 0,
		}
		self.Client.PumpHit:Fire(player, enemy.id)
		self:_startPumpLoop()
	else
		self.Client.PumpMiss:Fire(player)
	end
end

function PumpService:_startPumpLoop()
	if self._heartbeatConn then
		return -- already running
	end

	self._heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		local anyActive = false

		for player, state in self._pumpStates do
			if not state.active then
				continue
			end

			local PlayerService = Knit.GetService("PlayerService")
			if not PlayerService:IsPumping(player) then
				state.active = false
				continue
			end

			anyActive = true
			state.pumpTimer += dt

			if state.pumpTimer >= DigDugConfig.PUMP_INFLATE_TIME then
				state.pumpTimer = 0
				if state.targetEnemyId then
					local EnemyService = Knit.GetService("EnemyService")
					local popped = EnemyService:InflateEnemy(state.targetEnemyId, player)
					if popped then
						state.active = false
					end
				end
			end
		end

		if not anyActive then
			if self._heartbeatConn then
				self._heartbeatConn:Disconnect()
				self._heartbeatConn = nil
			end
		end
	end)
end

return PumpService
