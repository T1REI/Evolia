local RunService = game:GetService("RunService")
local Evolia = { Version = "0.3.0" }
local baseUrl = "https://raw.githubusercontent.com/T1REI/Evolia/main/"
local modules = {}
local current

local function loadModule(path)
	if modules[path] then return modules[path] end
	local source = game:HttpGet(baseUrl .. path)
	local chunk, problem = loadstring(source)
	assert(chunk, "Evolia: cannot compile " .. path .. ": " .. tostring(problem))
	local loaded = chunk()
	modules[path] = loaded
	return loaded
end

function Evolia:CreateWindow(options)
	assert(RunService:IsClient(), "Evolia must run on the client")
	local Acrylic = loadModule("modules/ui/acrylic.lua")
	local Controls = loadModule("modules/ui/controls.lua")
	local Radial = loadModule("modules/ui/radial.lua")
	local settings = Radial.validate(options or {})
	local environment = type(getgenv) == "function" and getgenv() or getfenv(0)
	local previous = environment.__EvoliaUIRuntime
	if type(previous) == "table" and type(previous.Destroy) == "function" then previous:Destroy() end
	self:Destroy()
	current = Radial.new(settings, Acrylic, Controls)
	local window = current
	environment.__EvoliaUIRuntime = window
	window._onDestroy = function()
		if environment.__EvoliaUIRuntime == window then environment.__EvoliaUIRuntime = nil end
		if current == window then current = nil end
	end
	return window
end

function Evolia:Init(options) self:CreateWindow(options); return self end
function Evolia:IsVisible() return current ~= nil and current:IsVisible() end
function Evolia:Destroy() if current then current:Destroy() end end
for _, method in { "SetVisible", "Show", "Hide", "Toggle", "SetToggleKey", "SetOptions", "ChangeTheme" } do
	Evolia[method] = function(self, ...)
		assert(current, "Evolia: call CreateWindow first")
		current[method](current, ...)
		return self
	end
end
function Evolia:GetToggleKey() assert(current, "Evolia: no window"); return current:GetToggleKey() end
return Evolia
