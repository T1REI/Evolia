local function advance(seconds, fps)
	stepFrames(math.floor(seconds * (fps or 60) + 0.5), 1 / (fps or 60))
end

local function blurCount()
	local count = 0
	for _, object in lighting:GetChildren() do if object:IsA("BlurEffect") then count += 1 end end
	return count
end

local function onlyBlur()
	for _, object in lighting:GetChildren() do
		if object:IsA("BlurEffect") then return object end
	end
	error("no blur effect")
end

local function press(key, processed)
	input.InputBegan:Fire({ KeyCode = key or Enum.KeyCode.RightShift }, processed or false)
end

local Evolia = loadEvolia()
assert(blurCount() == 0 and input.InputBegan:Count() == 0, "loading started the UI")
assert(not pcall(Evolia.Init, Evolia, { BlurSize = 100 }))
assert(not pcall(Evolia.Init, Evolia, { SomethingElse = true }))
assert(blurCount() == 0 and requests == 0, "invalid options have side effects")
assert(Evolia:Init() == Evolia)
assert(requests == 1 and blurCount() == 1 and input.InputBegan:Count() == 1)
assert(not Evolia:IsVisible() and onlyBlur().Size == 0 and not onlyBlur().Enabled)
local gui = child(playerGui, "Evolia")
assert(#gui:GetChildren() == 6 and not gui.Enabled, "expected six hidden tiles")
for _, tile in gui:GetChildren() do
	assert(tile:IsA("Frame") and tile.BackgroundTransparency == 1)
	assert(Acrylic.get(tile) and not Acrylic.get(tile):IsEnabled(), "tile missing Acrylic")
	assert(not tile:FindFirstChildOfClass("TextLabel"), "unexpected UI chrome")
end
assert(#workspace:GetChildren() == 0, "glass geometry created for fullscreen blur")
assert(initial.Enabled and not initiallyOff.Enabled, "fullscreen changed DOF")
assert(run.RenderStepped:Count() == 0, "idle render loop")

press(nil, true); assert(not Evolia:IsVisible(), "processed input toggled UI")
input.FocusedTextBox = true
press(); assert(not Evolia:IsVisible(), "typing toggled UI")
input.FocusedTextBox = nil
press(Enum.KeyCode.T); assert(not Evolia:IsVisible(), "wrong key toggled UI")
press(); assert(Evolia:IsVisible() and onlyBlur().Enabled)
assert(onlyBlur().Size == 0, "initial press jumps the blur")
local last = 0
for _ = 1, 12 do
	stepFrames()
	assert(onlyBlur().Size >= last and onlyBlur().Size <= 24, "opening is not monotonic")
	last = onlyBlur().Size
end
assert(last > 0 and last < 24)
local firstTile = child(gui, "Tile1")
local lastTile = child(gui, "Tile6")
assert(firstTile.BackgroundTransparency > 0.42 and firstTile.BackgroundTransparency < 1)
assert(lastTile.BackgroundTransparency > firstTile.BackgroundTransparency, "reveal has no gentle sequence")
assert(Acrylic.get(firstTile):GetStatus() == "visible", "tile glass is missing")
local tileBeforeReverse = firstTile.BackgroundTransparency
local beforeReverse = onlyBlur().Size
press()
assert(not Evolia:IsVisible() and onlyBlur().Size == beforeReverse, "reversal snaps")
assert(firstTile.BackgroundTransparency == tileBeforeReverse, "tile reversal snaps")
stepFrames()
assert(math.abs(onlyBlur().Size - beforeReverse) < 2, "reversal has a visible jump")
advance(2)
assert(onlyBlur().Size == 0 and not onlyBlur().Enabled)
assert(not gui.Enabled and firstTile.BackgroundTransparency == 1)
assert(#workspace:GetChildren() == 0 and initial.Enabled and not initiallyOff.Enabled, "closed glass/DOF retained")
assert(run.RenderStepped:Count() == 0, "closed render loop retained")

for index = 1, 21 do press(); stepFrames(1, 1/144) end
assert(Evolia:IsVisible())
advance(2, 144)
assert(onlyBlur().Size == 24 and onlyBlur().Enabled)
assert(gui.Enabled and math.abs(firstTile.BackgroundTransparency - 0.42) < 0.000001)
local function checkLayout()
	local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
	local lastRight, firstWidth
	for index, tile in gui:GetChildren() do
		local p, size = tile.AbsolutePosition + coreInset, tile.AbsoluteSize
		assert(math.abs(size.X - size.Y) < 0.000001, "tiles are not square")
		assert(not firstWidth or math.abs(size.X - firstWidth) < 0.000001, "unequal tile sizes")
		if (index - 1) % 3 ~= 0 then assert(p.X > lastRight, "tiles overlap or touch") end
		firstWidth, lastRight = size.X, p.X + size.X
		left, top = math.min(left, p.X), math.min(top, p.Y)
		right, bottom = math.max(right, p.X + size.X), math.max(bottom, p.Y + size.Y)
	end
	assert(math.abs((left + right) / 2 - view.X / 2) < 0.000001, "not horizontally centered")
	assert(math.abs((top + bottom) / 2 - view.Y / 2) < 0.000001, "not vertically centered")
	assert(right - left <= view.X * 0.52 + 0.001 and bottom - top <= view.Y * 0.42 + 0.001, "UI occupies too much screen")
end
checkLayout()
for _, size in { vector(320, 568), vector(1920, 1080), vector(568, 320) } do
	view = size
	workspace.CurrentCamera.ViewportSize = size
	gui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
	stepFrames()
	checkLayout()
end
view = vector(1280, 720)
workspace.CurrentCamera.ViewportSize = view
gui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
assert(run.RenderStepped:Count() == 0, "open idle loop retained")
press()
last = 24
for _ = 1, 120 do
	stepFrames()
	assert(onlyBlur().Size <= last and onlyBlur().Size >= 0, "closing is not monotonic")
	last = onlyBlur().Size
end
assert(last == 0 and not onlyBlur().Enabled)

local samples = {}
for _, fps in { 30, 60, 144 } do
	local full = Acrylic.fullscreen({ Duration = 0.7, Size = 24 })
	full:SetVisible(true)
	advance(0.5, fps)
	table.insert(samples, full:GetSize())
	full:Destroy()
end
assert(math.abs(samples[1] - samples[2]) < 0.000001 and math.abs(samples[2] - samples[3]) < 0.000001,
	"animation depends on frame rate")

local full = Acrylic.fullscreen()
assert(not pcall(full.SetOptions, full, { Duration = 0 }))
full:SetVisible(true); advance(0.2)
local copy = full:GetOptions(); copy.Size = 1
assert(full:GetOptions().Size == 24)
full:Destroy(); full:Destroy()
assert(not pcall(full.SetVisible, full, true))

Evolia:Init({ ToggleKey = Enum.KeyCode.T, BlurSize = 18, AnimationDuration = 0.5 })
assert(blurCount() == 1 and input.InputBegan:Count() == 1)
press(); assert(not Evolia:IsVisible())
press(Enum.KeyCode.T); advance(2)
assert(Evolia:IsVisible() and onlyBlur().Size == 18)

local oldEffect = onlyBlur()
local other = loadEvolia()
other:Init()
assert(oldEffect._destroyed and not Evolia:IsVisible())
assert(gui._destroyed and #playerGui:GetChildren() == 1, "rerun leaked GUI")
assert(blurCount() == 1 and input.InputBegan:Count() == 1, "rerun leaked resources")
press(); advance(0.15)
assert(other:IsVisible() and onlyBlur().Size > 0)
other:Destroy(); other:Destroy()
assert(blurCount() == 0 and input.InputBegan:Count() == 0 and run.RenderStepped:Count() == 0)
assert(#playerGui:GetChildren() == 0 and count(frames) == 0, "destroy leaked tiles or glass rendering")
assert(not other:IsVisible())
assert(not pcall(other.Toggle, other))

local window = other:CreateWindow({ toggleKey = "LeftAlt", tileSize = 110, tileGap = 16 })
assert(window ~= other and window:GetToggleKey() == Enum.KeyCode.LeftAlt)
press(); assert(not window:IsVisible())
press(Enum.KeyCode.LeftAlt); advance(2)
assert(window:IsVisible())
assert(window:SetToggleKey("F4") == window)
assert(other:GetToggleKey() == Enum.KeyCode.F4)
press(Enum.KeyCode.LeftAlt); assert(window:IsVisible(), "old key still active")
press(Enum.KeyCode.F4); advance(2)
assert(not window:IsVisible())
assert(not pcall(window.SetToggleKey, window, "DoesNotExist"))
assert(not pcall(window.SetToggleKey, window, Enum.KeyCode.Unknown))
assert(window:GetToggleKey() == Enum.KeyCode.F4, "invalid binding changed key")
assert(not pcall(other.CreateWindow, other, { toggleKey = "T", ToggleKey = "F4" }))
assert(child(playerGui, "Evolia") and input.InputBegan:Count() == 1, "invalid options destroyed window")
assert(window:Show() == window); advance(0.2)
assert(window:Hide() == window); advance(2)
assert(not window:IsVisible())
window:Show(); advance(0.1)
child(playerGui, "Evolia"):Destroy()
assert(not window:IsVisible() and not other:IsVisible())
assert(blurCount() == 0 and input.InputBegan:Count() == 0 and count(frames) == 0)
assert(not pcall(window.Show, window), "destroyed handle reused")
window:Destroy()

local tileSamples = {}
for _, fps in { 30, 60, 144 } do
	local sampleWindow = other:CreateWindow({ name = "Sample" })
	sampleWindow:Show()
	advance(0.5, fps)
	local tile = child(child(playerGui, "Sample"), "Tile6")
	table.insert(tileSamples, { tile.BackgroundTransparency, tile.AbsoluteSize.X, tile.Position.Y.Offset })
	sampleWindow:Destroy()
end
for index = 1, 3 do
	assert(math.abs(tileSamples[1][index] - tileSamples[2][index]) < 0.000001
		and math.abs(tileSamples[2][index] - tileSamples[3][index]) < 0.000001,
		"tile animation depends on frame rate")
end

local newInstance = Instance.new
local attempts = 0
Instance.new = function(class)
	if class == "Frame" then
		attempts += 1
		if attempts == 3 then error("simulated allocation failure") end
	end
	return newInstance(class)
end
assert(not pcall(other.CreateWindow, other))
Instance.new = newInstance
assert(#playerGui:GetChildren() == 0 and blurCount() == 0 and count(frames) == 0, "partial creation leaked resources")

local foreign = Instance.new("BlurEffect")
foreign.Size = 10; foreign.Enabled = true; foreign.Parent = lighting
full = Acrylic.fullscreen({ Visible = true })
advance(2)
Acrylic.destroyAll()
assert(full:GetSize() == 0 and full._destroyed)
assert(foreign.Parent == lighting and foreign.Size == 10 and foreign.Enabled, "foreign blur changed")
foreign:Destroy()
assert(#lighting:GetChildren() == 2 and count(frames) == 0)
print("PASS: Acrylic tile layout/resizing, window API, key rebinding, smooth reversal, rapid toggles, frame-rate independence and cleanup")
