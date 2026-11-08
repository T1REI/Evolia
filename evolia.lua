local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Evolia = { Version = "0.2.2" }
local Window = {}
Window.__index = Window
local acrylic
local current
local runtimeKey = "__EvoliaUIRuntime"
local tileLayout = {}
local diamondRadius = 6
for row = -diamondRadius, diamondRadius do
	local halfWidth = diamondRadius - math.abs(row)
	for column = -halfWidth, halfWidth do
		table.insert(tileLayout, { column = column, row = row, wave = math.abs(column) + math.abs(row) })
	end
end

local defaults = {
	name = "Evolia",
	toggleKey = Enum.KeyCode.RightShift,
	blurSize = 24,
	animationDuration = 0.7,
	tileSize = 12,
	tileGap = 4,
	tileColor = Color3.fromRGB(255, 255, 255),
	tileTransparency = 0.24,
	cornerRadius = 2,
}

local function keyCode(value)
	if type(value) == "string" then
		local ok, key = pcall(function() return Enum.KeyCode[value] end)
		value = ok and key or nil
	end
	assert(typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode
		and value ~= Enum.KeyCode.Unknown, "Evolia: toggleKey must be a KeyCode or its name")
	return value
end

local function range(value, low, high)
	return type(value) == "number" and value == value and value >= low and value <= high
end

local validators = {
	name = function(v) return type(v) == "string" and #v > 0 and #v <= 128 end,
	blurSize = function(v) return range(v, 0, 56) end,
	animationDuration = function(v) return range(v, 0.05, 10) end,
	tileSize = function(v) return range(v, 12, 180) end,
	tileGap = function(v) return range(v, 4, 48) end,
	tileColor = function(v) return typeof(v) == "Color3" end,
	tileTransparency = function(v) return range(v, 0, 1) end,
	cornerRadius = function(v) return range(v, 0, 24) end,
}

local function validate(options)
	assert(type(options) == "table", "Evolia: expected an options table")
	local result, seen = table.clone(defaults), {}
	for supplied, value in pairs(options) do
		assert(type(supplied) == "string", "Evolia: option names must be strings")
		local key = supplied:sub(1, 1):lower() .. supplied:sub(2)
		assert(result[key] ~= nil, "Evolia: unknown option " .. supplied)
		assert(not seen[key], "Evolia: duplicate option " .. key)
		seen[key] = true
		if key == "toggleKey" then value = keyCode(value)
		else assert(validators[key](value), "Evolia: invalid value for " .. key) end
		result[key] = value
	end
	return result
end

local function create(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties) do object[key] = value end
	object.Parent = parent
	return object
end

function Window:_layout()
	local viewport = self._gui.AbsoluteSize
	local settings = self._settings
	local diameter = diamondRadius * 2 + 1
	local width = settings.tileSize * diameter + settings.tileGap * (diameter - 1)
	local height = width
	local scale = math.max(0, math.min(1, viewport.X * 0.52 / width, viewport.Y * 0.42 / height))
	local updates = {}
	for _, tile in self._tiles do
		local amount = math.clamp(tile.amount, 0, 1)
		local size = settings.tileSize * scale * (0.94 + 0.06 * amount)
		tile.frame.Size = UDim2.fromOffset(size, size)
		tile.frame.Position = UDim2.new(0.5,
			tile.cell.column * (settings.tileSize + settings.tileGap) * scale,
			0.5, (tile.cell.row * (settings.tileSize + settings.tileGap)
				+ settings.tileSize * 0.125 * (1 - amount)) * scale)
		tile.corner.CornerRadius = UDim.new(0, settings.cornerRadius * scale)
		tile.frame.BackgroundTransparency = 1 - (1 - settings.tileTransparency) * amount
		tile.stroke.Transparency = 1 - 0.35 * amount
		updates[tile.glass] = {
			Enabled = amount > 0, GlassTransparency = 0.999 - 0.019 * amount,
			EdgeCompensation = Vector2.new(math.min(0.8, size / 120), 0),
		}
	end
	acrylic.update(updates)
end

function Window:_animate()
	if self._animationConnection then return end
	self._gui.Enabled = true
	self._animationConnection = RunService.RenderStepped:Connect(function(dt)
		local target = self._visible and 1 or 0
		local settled = true
		for _, tile in self._tiles do
			local omega = 10 / (self._settings.animationDuration + tile.cell.wave * 0.04)
			local displacement = tile.amount - target
			local term = tile.velocity + omega * displacement
			local decay = math.exp(-omega * dt)
			tile.amount = target + (displacement + term * dt) * decay
			tile.velocity = (tile.velocity - omega * term * dt) * decay
			if math.abs(tile.amount - target) < 0.0001 and math.abs(tile.velocity) < 0.001 then
				tile.amount, tile.velocity = target, 0
			else settled = false end
		end
		self:_layout()
		if settled then
			self._gui.Enabled = self._visible
			self._animationConnection:Disconnect()
			self._animationConnection = nil
		end
	end)
end

function Window:SetVisible(visible)
	assert(not self._destroyed, "Evolia: window was destroyed")
	assert(type(visible) == "boolean", "Evolia: visibility must be boolean")
	if self._visible == visible then return self end
	self._visible = visible
	self._blur:SetVisible(visible)
	self:_animate()
	return self
end

function Window:Show() return self:SetVisible(true) end
function Window:Hide() return self:SetVisible(false) end
function Window:Toggle() return self:SetVisible(not self:IsVisible()) end
function Window:IsVisible() return not self._destroyed and self._visible end

function Window:SetToggleKey(key)
	assert(not self._destroyed, "Evolia: window was destroyed")
	self._settings.toggleKey = keyCode(key)
	return self
end

function Window:GetToggleKey() return self._settings.toggleKey end

function Window:Destroy()
	if self._destroyed then return end
	self._destroyed, self._visible = true, false
	for _, connection in self._connections do connection:Disconnect() end
	if self._animationConnection then self._animationConnection:Disconnect(); self._animationConnection = nil end
	for _, tile in self._tiles do tile.glass:Destroy() end
	if self._blur then self._blur:Destroy() end
	if self._gui then self._gui:Destroy() end
	if self._environment[runtimeKey] == self then self._environment[runtimeKey] = nil end
	if current == self then current = nil end
end

function Evolia:CreateWindow(options)
	assert(RunService:IsClient(), "Evolia: CreateWindow must run on the client")
	local settings = validate(options or {})
	if not acrylic then
		local source = game:HttpGet("https://raw.githubusercontent.com/T1REI/Evolia/main/modules/ui/acrylic.lua")
		local chunk, problem = loadstring(source)
		assert(chunk, "Evolia: could not compile Acrylic: " .. tostring(problem))
		local loaded = chunk()
		assert(type(loaded) == "table" and type(loaded.fullscreen) == "function"
			and type(loaded.attach) == "function" and type(loaded.update) == "function",
			"Evolia: Acrylic must provide panel, fullscreen and batch update APIs")
		acrylic = loaded
	end
	local environment = type(getgenv) == "function" and getgenv() or getfenv(0)
	local previous = environment[runtimeKey]
	if type(previous) == "table" and type(previous.Destroy) == "function" then previous:Destroy() end
	self:Destroy()
	local window = setmetatable({
		_settings = settings, _environment = environment, _tiles = {}, _connections = {}, _visible = false,
	}, Window)
	local ok, problem = pcall(function()
		window._gui = create("ScreenGui", {
			Name = settings.name, Enabled = false, ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.None, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100,
		}, Players.LocalPlayer:WaitForChild("PlayerGui"))
		window._blur = acrylic.fullscreen({ Size = settings.blurSize, Duration = settings.animationDuration })
		for index, cell in tileLayout do
			local frame = create("Frame", {
				Name = "Tile" .. index, AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0,
				BackgroundColor3 = settings.tileColor, BackgroundTransparency = 1, Active = false,
			}, window._gui)
			local corner = create("UICorner", { CornerRadius = UDim.new(0, settings.cornerRadius) }, frame)
			local stroke = create("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(255, 255, 255),
				Thickness = 1, Transparency = 1,
			}, frame)
			local glass = acrylic.attach(frame, { Enabled = false, GlassTransparency = 0.999, CornerSegments = 4 })
			table.insert(window._tiles, {
				frame = frame, corner = corner, stroke = stroke, glass = glass,
				cell = cell, amount = 0, velocity = 0,
			})
		end
		window:_layout()
		table.insert(window._connections, window._gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			window:_layout()
		end))
		table.insert(window._connections, window._gui.Destroying:Connect(function() window:Destroy() end))
		table.insert(window._connections, UserInputService.InputBegan:Connect(function(input, processed)
			if processed or UserInputService:GetFocusedTextBox() then return end
			if input.KeyCode == settings.toggleKey then window:Toggle() end
		end))
	end)
	if not ok then window:Destroy(); error("Evolia: could not create window: " .. tostring(problem), 2) end
	environment[runtimeKey], current = window, window
	return window
end

function Evolia:Init(options)
	self:CreateWindow(options)
	return self
end

function Evolia:IsVisible() return current ~= nil and current:IsVisible() end
function Evolia:Destroy() if current then current:Destroy() end end

for _, method in { "SetVisible", "Show", "Hide", "Toggle", "SetToggleKey" } do
	Evolia[method] = function(self, ...)
		assert(current, "Evolia: call CreateWindow or Init first")
		current[method](current, ...)
		return self
	end
end

function Evolia:GetToggleKey()
	assert(current, "Evolia: call CreateWindow or Init first")
	return current:GetToggleKey()
end

return Evolia
