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
assert(#playerGui:GetChildren() == 0, "UI chrome created")
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
local beforeReverse = onlyBlur().Size
press()
assert(not Evolia:IsVisible() and onlyBlur().Size == beforeReverse, "reversal snaps")
stepFrames()
assert(math.abs(onlyBlur().Size - beforeReverse) < 2, "reversal has a visible jump")
advance(2)
assert(onlyBlur().Size == 0 and not onlyBlur().Enabled)
assert(run.RenderStepped:Count() == 0, "closed render loop retained")

for index = 1, 21 do press(); stepFrames(1, 1/144) end
assert(Evolia:IsVisible())
advance(2, 144)
assert(onlyBlur().Size == 24 and onlyBlur().Enabled)
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
assert(blurCount() == 1 and input.InputBegan:Count() == 1, "rerun leaked resources")
press(); advance(0.15)
assert(other:IsVisible() and onlyBlur().Size > 0)
other:Destroy(); other:Destroy()
assert(blurCount() == 0 and input.InputBegan:Count() == 0 and run.RenderStepped:Count() == 0)
assert(not other:IsVisible())
assert(not pcall(other.Toggle, other))

local foreign = Instance.new("BlurEffect")
foreign.Size = 10; foreign.Enabled = true; foreign.Parent = lighting
full = Acrylic.fullscreen({ Visible = true })
advance(2)
Acrylic.destroyAll()
assert(full:GetSize() == 0 and full._destroyed)
assert(foreign.Parent == lighting and foreign.Size == 10 and foreign.Enabled, "foreign blur changed")
foreign:Destroy()
assert(#lighting:GetChildren() == 2 and count(frames) == 0)
print("PASS: blur-only UI, keyboard filtering, smooth reversal, rapid toggles, frame-rate independence and cleanup")
