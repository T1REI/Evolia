local gui = makeGui()
local target = makeTarget(gui)
local originalBackground = target.BackgroundTransparency
assert(count(frames) == 0, "loading the module started rendering")

local handle = Acrylic.attach(target, { CornerRadius = 6, Style = true })
assert(Acrylic.get(target) == handle)
assert(handle:GetStatus() == "visible")
assert(handle:GetTarget() == target)
assert(not initial.Enabled and not initiallyOff.Enabled)
assert(target.BackgroundTransparency == originalBackground, "target properties were modified")
assert(count(frames) == 1)
assert(not pcall(Acrylic.attach, target), "duplicate attachment accepted")
assert(not pcall(Acrylic.attach, Instance.new("Part")), "non-GuiObject accepted")

local function projectVertex(part, mesh, x, y, z)
	local offset = rotate(vector(mesh.Scale.X * x, mesh.Scale.Y * y, mesh.Scale.Z * z), part.CFrame.Angle)
	local localPoint = workspace.CurrentCamera.CFrame:PointToObjectSpace(part.CFrame.Position + offset)
	local camera = workspace.CurrentCamera
	local s = math.tan(math.rad(camera.FieldOfView) / 2) / (view.Y / 2)
	return vector(localPoint.X / -localPoint.Z / s + view.X / 2 - coreInset.X,
		view.Y / 2 - localPoint.Y / -localPoint.Z / s - coreInset.Y)
end

local geometryChecks = 0
local function checkGeometry(subject, expectedRadius, expectFullHeight)
	local object = subject:GetTarget()
	local p, size = object.AbsolutePosition, object.AbsoluteSize
	local angle = math.rad(object.AbsoluteRotation)
	local center = p + size * 0.5
	local minY, maxY = math.huge, -math.huge
	local visible = 0
	for _, slice in subject._slices do
		if slice.part.Transparency == 1 then continue end
		visible += 1
		for _, x in { -0.5, 0.5 } do
			for _, y in { -0.5, 0.5 } do
				for _, z in { -0.5, 0.5 } do
					local screen = projectVertex(slice.part, slice.mesh, x, y, z)
					local point = center + rotate(screen - center, -angle)
					assert(point.X >= p.X - 0.001 and point.X <= p.X + size.X + 0.001, "horizontal spill")
					assert(point.Y >= p.Y - 0.001 and point.Y <= p.Y + size.Y + 0.001, "vertical spill")
					local r = math.min(expectedRadius, size.X / 2, size.Y / 2)
					local qx = math.abs(point.X - center.X) - (size.X / 2 - r)
					local qy = math.abs(point.Y - center.Y) - (size.Y / 2 - r)
					local signed = math.sqrt(math.max(qx, 0)^2 + math.max(qy, 0)^2) + math.min(math.max(qx, qy), 0) - r
					assert(signed <= 0.002, "rounded corner spill")
					minY, maxY = math.min(minY, point.Y), math.max(maxY, point.Y)
					geometryChecks += 1
				end
			end
		end
	end
	assert(visible > 0, "no glass rendered")
	if expectFullHeight then
		assert(minY - p.Y < 0.05 and p.Y + size.Y - maxY < 0.05, "top/bottom strip")
	end
end

checkGeometry(handle, 6, true)
local secondTarget = makeTarget(gui, 650, 100, 260, 220, "TextButton")
local second = Acrylic.attach(secondTarget, { CornerRadius = 18, EdgeCompensation = Vector2.zero })
assert(count(frames) == 1, "multiple render loops")
assert(handle:GetStatus() == "visible" and second:GetStatus() == "visible")
checkGeometry(second, 18, true)

local previousOptions = handle:GetOptions()
assert(not pcall(handle.SetOptions, handle, { TintTransparency = 9 }))
assert(handle:GetOptions().TintTransparency == previousOptions.TintTransparency, "failed update changed state")
assert(not pcall(handle.SetOptions, handle, { Unsupported = true }))
assert(not pcall(handle.SetOptions, handle, { DepthOffset = 0/0 }))
local copy = handle:GetOptions()
copy.Enabled = false
assert(handle:IsEnabled(), "options table leaked")
assert(not pcall(Acrylic.configure, { Intensity = 4 }))

assert(not pcall(Acrylic.update, {
	[handle] = { GlassTransparency = 0.8 },
	[second] = { GlassTransparency = 5 },
}))
assert(handle:GetOptions().GlassTransparency == previousOptions.GlassTransparency,
	"invalid batch partially changed options")
assert(not pcall(Acrylic.update, { [{}] = { Enabled = false } }), "foreign handle accepted")
Acrylic.update({ [handle] = { Enabled = false }, [second] = { Enabled = false } })
assert(handle:GetStatus() == "disabled" and second:GetStatus() == "disabled")
assert(initial.Enabled and not initiallyOff.Enabled, "batch did not restore shared DOF")
Acrylic.update({ [handle] = { Enabled = true }, [second] = { Enabled = true } })
assert(handle:GetStatus() == "visible" and second:GetStatus() == "visible")
assert(not initial.Enabled, "batch did not activate shared DOF")
checkGeometry(handle, 6, true)
checkGeometry(second, 18, true)

handle:SetEnabled(false)
assert(handle:GetStatus() == "disabled" and not handle:IsEnabled())
assert(not initial.Enabled, "one handle restored shared DOF too early")
second:SetEnabled(false)
assert(initial.Enabled and not initiallyOff.Enabled)
handle:SetEnabled(true)
second:SetEnabled(true)

gui.Enabled = false; stepFrames()
assert(handle:GetStatus() == "hidden" and initial.Enabled)
gui.Enabled = true; target.Visible = false; stepFrames()
assert(handle:GetStatus() == "hidden")
target.Visible = true; stepFrames()
target.Parent = nil; stepFrames()
assert(handle:GetStatus() == "detached")
target.Parent = gui; stepFrames()
assert(handle:GetStatus() == "visible")

local clipper = makeTarget(gui, 150, 150, 100, 80)
clipper.ClipsDescendants = true
target.Parent = clipper
target.Position = UDim2.fromOffset(-20, -30)
stepFrames()
for _, slice in handle._slices do
	if slice.part.Transparency == 1 then continue end
	for _, x in { -0.5, 0.5 } do
		for _, y in { -0.5, 0.5 } do
			local point = projectVertex(slice.part, slice.mesh, x, y, 0.5)
			assert(point.X >= 150 - 0.001 and point.X <= 250 + 0.001)
			assert(point.Y >= 150 - 0.001 and point.Y <= 230 + 0.001)
		end
	end
end
target.Rotation = 10; stepFrames()
assert(handle:GetStatus() == "rotated-clipping")
target.Rotation = 0
target.Parent = gui
target.Position = UDim2.fromOffset(100, 100)
clipper:Destroy()

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 24)
corner.Parent = target
handle:SetOptions({ CornerRadius = "auto", CornerSegments = 24, EdgeCompensation = Vector2.zero })
assert(#handle._slices == 49)
checkGeometry(handle, 24, true)
corner.CornerRadius = UDim.new(0.5, 0)
stepFrames(); checkGeometry(handle, 170, true)
corner.CornerRadius = UDim.new(0, 24)
local scale = Instance.new("UIScale")
scale.Scale = 1.5
scale.Parent = target
stepFrames(); checkGeometry(handle, 36, true)
assert(handle._styleCorner.CornerRadius.Offset == 24, "tint radius was scaled twice")
scale:Destroy()
handle:SetOptions({ CornerRadius = 6, CornerSegments = 12, EdgeCompensation = Vector2.new(0.8, 0) })
assert(#handle._slices == 25)

for _, viewport in { vector(1280, 720), vector(3840, 2160), vector(360, 640) } do
	view = viewport
	workspace.CurrentCamera.ViewportSize = view
	for _, fov in { 35, 70, 120 } do
		workspace.CurrentCamera.FieldOfView = fov
		for _, angle in { 0, 30, 90, 170 } do
			target.Rotation = angle
			for _, intensity in { 0, 0.25, 1 } do
				Acrylic.configure({ Intensity = intensity })
				stepFrames(); checkGeometry(handle, 6, true)
			end
		end
	end
end
target.Rotation = 0
target.Position = UDim2.fromOffset(180.375, 145.625)
coreInset = vector(40, 58)
workspace.CurrentCamera.NearPlaneZ = -0.1
stepFrames(); checkGeometry(handle, 6, true)
workspace.CurrentCamera.CFrame = CFrame.new(100, 20, -10) * CFrame.Angles(0, 0, 0.5)
stepFrames(); checkGeometry(handle, 6, true)
workspace.CurrentCamera = makeCamera()
stepFrames(); checkGeometry(handle, 6, true)
workspace.CurrentCamera = nil
stepFrames()
assert(handle:GetStatus() == "no-camera" and initial.Enabled)
workspace.CurrentCamera = makeCamera(); stepFrames()

local late = Instance.new("DepthOfFieldEffect"); late.Parent = lighting
assert(not late.Enabled, "late DOF not suspended")
Acrylic.configure({ ManageDepthOfField = false })
assert(initial.Enabled and late.Enabled and not initiallyOff.Enabled)
Acrylic.configure({ ManageDepthOfField = true })
assert(not initial.Enabled)

second:Destroy(); second:Destroy()
assert(not initial.Enabled, "shared DOF restored while first handle is active")
assert(not pcall(second.SetOptions, second, {}))
assert(Acrylic.get(secondTarget) == nil)
local replacement = makeTarget(gui, 200, 200)
handle:SetTarget(replacement)
assert(Acrylic.get(target) == nil and Acrylic.get(replacement) == handle)
assert(not target:FindFirstChild("EvoliaAcrylicTint"), "old tint was not removed")
assert(replacement:FindFirstChild("EvoliaAcrylicTint"))
target:Destroy()
assert(handle:GetStatus() == "visible", "old target still owns the handle")
replacement:Destroy()
assert(handle:GetStatus() == "destroyed" and count(frames) == 0)
assert(initial.Enabled and late.Enabled and not initiallyOff.Enabled)
assert(#lighting:GetChildren() == 3, "effect leak")

local third = Acrylic.attach(makeTarget(gui), { Style = true })
Acrylic.destroyAll()
assert(third:GetStatus() == "destroyed" and count(frames) == 0)
assert(#lighting:GetChildren() == 3)
Acrylic.destroyAll()
print("PASS: lifecycle, shared DOF, clipping, rotation, visibility, reparenting, validation, styles and cleanup")
print("Projected glass vertices checked:", geometryChecks)
