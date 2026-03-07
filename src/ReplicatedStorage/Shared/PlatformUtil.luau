--!strict
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local PlatformUtil = {}

function PlatformUtil.isMobile(): boolean
	return UserInputService.TouchEnabled and not GuiService:IsTenFootInterface()
end

function PlatformUtil.isConsole(): boolean
	return GuiService:IsTenFootInterface()
end

function PlatformUtil.isDesktop(): boolean
	return not PlatformUtil.isMobile() and not PlatformUtil.isConsole()
end

function PlatformUtil.isGamepad(): boolean
	return UserInputService.GamepadEnabled
end

function PlatformUtil.getUIScale(): number
	if PlatformUtil.isConsole() then
		return 1.25
	elseif PlatformUtil.isMobile() then
		return 1.15
	end
	return 1.0
end

function PlatformUtil.getParticleMultiplier(): number
	if PlatformUtil.isMobile() then
		return 0.5
	end
	return 1.0
end

return PlatformUtil
