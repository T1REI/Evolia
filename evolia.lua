local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Evolia = { Version = "0.1.0" }
local acrylic
local blur
local inputConnection
local environment
local runtimeKey = "__EvoliaUIRuntime"

local function validate(options)
	assert(type(options) == "table", "Evolia: expected an options table")
	local result = {
		ToggleKey = Enum.KeyCode.RightShift,
		BlurSize = 24,
		AnimationDuration = 0.7,
	}
	for key, value in pairs(options) do
		assert(result[key] ~= nil, "Evolia: unknown option " .. tostring(key))
		if key == "ToggleKey" then
			assert(typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode
				and value ~= Enum.KeyCode.Unknown, "Evolia: ToggleKey must be a KeyCode")
		else
			local low, high = key == "BlurSize" and 0 or 0.05, key == "BlurSize" and 56 or 10
			assert(type(value) == "number" and value == value and value >= low and value <= high,
				"Evolia: invalid value for " .. key)
		end
		result[key] = value
	end
	return result
end

function Evolia:Init(options)
	assert(RunService:IsClient(), "Evolia: Init must run on the client")
	local settings = validate(options or {})
	if not acrylic then
		local source = game:HttpGet("https://raw.githubusercontent.com/T1REI/Evolia/main/modules/ui/acrylic.lua")
		local chunk, problem = loadstring(source)
		assert(chunk, "Evolia: could not compile Acrylic: " .. tostring(problem))
		acrylic = chunk()
		assert(type(acrylic) == "table" and type(acrylic.fullscreen) == "function",
			"Evolia: Acrylic does not provide fullscreen blur")
	end
	environment = type(getgenv) == "function" and getgenv() or getfenv(0)
	local previous = environment[runtimeKey]
	if type(previous) == "table" and type(previous.Destroy) == "function" then previous:Destroy() end
	self:Destroy()
	blur = acrylic.fullscreen({ Size = settings.BlurSize, Duration = settings.AnimationDuration })
	inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == settings.ToggleKey then self:Toggle() end
	end)
	environment[runtimeKey] = self
	return self
end

function Evolia:SetVisible(visible)
	assert(blur, "Evolia: call Init before changing visibility")
	blur:SetVisible(visible)
	return self
end

function Evolia:Toggle()
	return self:SetVisible(not self:IsVisible())
end

function Evolia:IsVisible()
	return blur ~= nil and blur:IsVisible()
end

function Evolia:Destroy()
	if inputConnection then inputConnection:Disconnect(); inputConnection = nil end
	if blur then blur:Destroy(); blur = nil end
	if environment and environment[runtimeKey] == self then environment[runtimeKey] = nil end
end

return Evolia
