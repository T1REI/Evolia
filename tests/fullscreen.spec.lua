local function advance(seconds, fps)
	stepFrames(math.floor(seconds * (fps or 60) + 0.5), 1 / (fps or 60))
end
local function effect()
	for _, object in lighting:GetChildren() do
		if object:IsA("BlurEffect") then return object end
	end
end

local full = Acrylic.fullscreen({ Size = 24, Duration = 0.7 })
assert(not full:IsVisible() and full:GetSize() == 0 and not effect().Enabled)
assert(not pcall(full.SetOptions, full, { Duration = 0 }))
full:SetVisible(true)
local previous = 0
for _ = 1, 12 do
	stepFrames()
	assert(full:GetSize() >= previous and full:GetSize() <= 24)
	previous = full:GetSize()
end
full:SetVisible(false)
assert(full:GetSize() == previous, "reversal snapped")
advance(2)
assert(full:GetSize() == 0 and not effect().Enabled and run.RenderStepped:Count() == 0)
for _ = 1, 21 do full:SetVisible(not full:IsVisible()); stepFrames(1, 1 / 144) end
advance(2, 144)
assert(full:GetSize() == 24 and full:IsVisible() and run.RenderStepped:Count() == 0)
local options = full:GetOptions(); options.Size = 1
assert(full:GetOptions().Size == 24)
full:Destroy(); full:Destroy()
assert(not pcall(full.SetVisible, full, true) and not effect())

local samples = {}
for _, fps in { 30, 60, 144 } do
	local sample = Acrylic.fullscreen({ Size = 24, Duration = 0.7 })
	sample:SetVisible(true); advance(0.5, fps)
	table.insert(samples, sample:GetSize()); sample:Destroy()
end
assert(math.abs(samples[1] - samples[2]) < 0.000001 and math.abs(samples[2] - samples[3]) < 0.000001)
local foreign = Instance.new("BlurEffect")
foreign.Size = 10; foreign.Enabled = true; foreign.Parent = lighting
full = Acrylic.fullscreen({ Visible = true }); advance(2)
Acrylic.destroyAll()
assert(full:GetSize() == 0 and foreign.Parent == lighting and foreign.Size == 10 and foreign.Enabled)
foreign:Destroy()
assert(initial.Enabled and not initiallyOff.Enabled and run.RenderStepped:Count() == 0)
print("PASS: standalone fullscreen blur, reversal, rapid toggles, frame-rate independence and cleanup")
