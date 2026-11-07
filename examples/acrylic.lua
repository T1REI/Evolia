local Acrylic = loadstring(game:HttpGet("https://raw.githubusercontent.com/T1REI/Evolia/main/modules/ui/acrylic.lua"))()

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local previous = playerGui:FindFirstChild("EvoliaAcrylicExample")
if previous and previous:GetAttribute("EvoliaExample") then previous:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "EvoliaAcrylicExample"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui:SetAttribute("EvoliaExample", true)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.BackgroundTransparency = 1
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = panel

local glass = Acrylic.attach(panel, {
	Style = true,
	CornerRadius = "auto",
	TintColor = Color3.fromRGB(255, 255, 255),
	TintTransparency = 0.35,
	EdgeCompensation = Vector2.new(0.8, 0),
})

local connections = {}
local dragging, pointerStart, panelStart
local centered = false
local function connect(signal, fn)
	table.insert(connections, signal:Connect(fn))
end

local function constrain(position)
	local space, size = gui.AbsoluteSize, panel.AbsoluteSize
	return Vector2.new(
		math.clamp(position.X, 0, math.max(0, space.X - size.X)),
		math.clamp(position.Y, 0, math.max(0, space.Y - size.Y))
	)
end

local function layout()
	local space = gui.AbsoluteSize
	if space.X <= 0 or space.Y <= 0 then return end
	panel.Size = UDim2.fromOffset(math.max(1, math.min(540, space.X - 24)), math.max(1, math.min(340, space.Y - 24)))
	local position = Vector2.new(panel.Position.X.Offset, panel.Position.Y.Offset)
	if not centered then position = (space - panel.AbsoluteSize) / 2; centered = true end
	position = constrain(position)
	panel.Position = UDim2.fromOffset(position.X, position.Y)
	dragging = nil
end

connect(UserInputService.InputBegan, function(input, processed)
	if input.KeyCode == Enum.KeyCode.RightShift and not processed and not UserInputService:GetFocusedTextBox() then
		gui.Enabled = not gui.Enabled
		dragging = nil
		return
	end
	if dragging or not gui.Enabled then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local point = Vector2.new(input.Position.X, input.Position.Y)
	local p, s = panel.AbsolutePosition, panel.AbsoluteSize
	if point.X < p.X or point.Y < p.Y or point.X > p.X + s.X or point.Y > p.Y + s.Y then return end
	dragging, pointerStart = input, point
	panelStart = Vector2.new(panel.Position.X.Offset, panel.Position.Y.Offset)
end)
connect(UserInputService.InputChanged, function(input)
	if not dragging then return end
	local mouse = dragging.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
	if mouse or input == dragging then
		local point = Vector2.new(input.Position.X, input.Position.Y)
		local position = constrain(panelStart + point - pointerStart)
		panel.Position = UDim2.fromOffset(position.X, position.Y)
	end
end)
connect(UserInputService.InputEnded, function(input) if input == dragging then dragging = nil end end)
connect(UserInputService.WindowFocusReleased, function() dragging = nil end)
connect(gui:GetPropertyChangedSignal("AbsoluteSize"), layout)
connect(gui.Destroying, function()
	for _, connection in connections do connection:Disconnect() end
	glass:Destroy()
end)

gui.Parent = playerGui
RunService.RenderStepped:Wait()
layout()
