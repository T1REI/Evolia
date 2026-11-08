local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")

local Acrylic = { Version = "0.2.2" }
local Handle = {}
Handle.__index = Handle

local defaults = table.freeze({
	Enabled = true,
	CornerRadius = "auto",
	CornerSegments = 12,
	EdgeCompensation = Vector2.new(0.8, 0),
	Padding = Vector2.zero,
	DepthOffset = 0.02,
	GlassColor = Color3.new(0, 0, 0),
	GlassTransparency = 0.98,
	Style = false,
	TintColor = Color3.new(1, 1, 1),
	TintTransparency = 0.35,
	StrokeColor = Color3.new(1, 1, 1),
	StrokeTransparency = 0.55,
	StrokeThickness = 1,
})
local config = {
	Intensity = 1,
	FocusDistance = 0,
	InFocusRadius = 0.1,
	FarIntensity = 0,
	ManageDepthOfField = true,
}
local handles = {}
local targets = {}
local manager
local fullscreens = {}

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function range(value, low, high)
	return finite(value) and value >= low and value <= high
end

local function vectorRange(value, low, high)
	return typeof(value) == "Vector2" and range(value.X, low, high) and range(value.Y, low, high)
end

local validators = {
	Enabled = function(v) return type(v) == "boolean" end,
	CornerRadius = function(v)
		return v == "auto" or range(v, 0, 100000)
			or (typeof(v) == "UDim" and range(v.Scale, 0, 1) and range(v.Offset, 0, 100000))
	end,
	CornerSegments = function(v) return range(v, 1, 64) and v % 1 == 0 end,
	EdgeCompensation = function(v) return vectorRange(v, 0, 1) end,
	Padding = function(v) return vectorRange(v, 0, 100000) end,
	DepthOffset = function(v) return range(v, 0.001, 1) end,
	GlassColor = function(v) return typeof(v) == "Color3" end,
	GlassTransparency = function(v) return range(v, 0, 0.999) end,
	Style = function(v) return type(v) == "boolean" end,
	TintColor = function(v) return typeof(v) == "Color3" end,
	TintTransparency = function(v) return range(v, 0, 1) end,
	StrokeColor = function(v) return typeof(v) == "Color3" end,
	StrokeTransparency = function(v) return range(v, 0, 1) end,
	StrokeThickness = function(v) return range(v, 0, 32) end,
}
local configValidators = {
	Intensity = function(v) return range(v, 0, 1) end,
	FocusDistance = function(v) return range(v, 0, 100000) end,
	InFocusRadius = function(v) return range(v, 0, 100000) end,
	FarIntensity = function(v) return range(v, 0, 1) end,
	ManageDepthOfField = function(v) return type(v) == "boolean" end,
}

local function merge(base, changes, rules)
	assert(type(changes) == "table", "Acrylic: expected an options table")
	local result = table.clone(base)
	for key, value in pairs(changes) do
		assert(rules[key], "Acrylic: unknown option " .. tostring(key))
		assert(rules[key](value), "Acrylic: invalid value for " .. tostring(key))
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

local function releaseEffects()
	if not manager then return end
	for effect, enabled in pairs(manager.held) do
		if effect.Parent and not effect.Enabled then effect.Enabled = enabled end
	end
	table.clear(manager.held)
end

local function holdEffect(effect)
	if manager and manager.active and config.ManageDepthOfField and effect ~= manager.effect
		and effect:IsA("DepthOfFieldEffect") and manager.held[effect] == nil then
		manager.held[effect] = effect.Enabled
		effect.Enabled = false
	end
end

local function stopManager()
	if not manager then return end
	RunService:UnbindFromRenderStep(manager.name)
	manager.lightingConnection:Disconnect()
	if manager.cameraConnection then manager.cameraConnection:Disconnect() end
	manager.effect:Destroy()
	manager.root:Destroy()
	releaseEffects()
	manager = nil
end

local function updateStyle(handle, radius, scale)
	local options = handle._options
	if not options.Style then
		if handle._style then handle._style:Destroy(); handle._style = nil end
		return
	end
	if not handle._style then
		handle._style = create("Frame", {
			Name = "EvoliaAcrylicTint",
			Size = UDim2.fromScale(1, 1),
			BorderSizePixel = 0,
			Active = false,
		}, handle._target)
		handle._styleCorner = create("UICorner", {}, handle._style)
		handle._styleStroke = create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, handle._style)
	end
	local style = handle._style
	style.Visible = options.Enabled
	style.ZIndex = handle._target.ZIndex
	style.BackgroundColor3 = options.TintColor
	style.BackgroundTransparency = options.TintTransparency
	handle._styleCorner.CornerRadius = UDim.new(0, radius / math.max(scale, 0.000001))
	handle._styleStroke.Color = options.StrokeColor
	handle._styleStroke.Transparency = options.StrokeTransparency
	handle._styleStroke.Thickness = options.StrokeThickness
end

local function resizeSlices(handle)
	local wanted = 1 + handle._options.CornerSegments * 2
	while #handle._slices > wanted do
		table.remove(handle._slices).part:Destroy()
	end
	while #handle._slices < wanted do
		local part = create("Part", {
			Name = "Glass" .. (#handle._slices + 1),
			Size = Vector3.new(1, 1, 1),
			Anchored = true,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			CastShadow = false,
			Locked = true,
			Material = Enum.Material.Glass,
			Reflectance = 0,
			Transparency = 1,
		}, handle._mask)
		local mesh = create("SpecialMesh", {
			MeshType = Enum.MeshType.Brick,
			Scale = Vector3.zero,
		}, part)
		table.insert(handle._slices, { part = part, mesh = mesh, transform = CFrame.new() })
	end
	for _, slice in handle._slices do slice.part.Color = handle._options.GlassColor end
	handle._cache = nil
end

local function resolveRadius(handle, size)
	local radius = handle._options.CornerRadius
	local scale = 1
	local node = handle._target
	while node and node:IsA("GuiObject") do
		local modifier = node:FindFirstChildOfClass("UIScale")
		if modifier then scale *= modifier.Scale end
		node = node.Parent
	end
	if radius == "auto" then
		local corner = handle._target:FindFirstChildOfClass("UICorner")
		radius = corner and corner.CornerRadius or 0
	end
	if typeof(radius) == "UDim" then radius = math.min(size.X, size.Y) * radius.Scale + radius.Offset * scale end
	return math.min(radius, size.X / 2, size.Y / 2), scale
end

local function visibility(handle)
	if not handle._options.Enabled then return nil, "disabled" end
	local target = handle._target
	local rotation = target.AbsoluteRotation % 360
	local left, top, right, bottom = -math.huge, -math.huge, math.huge, math.huge
	local node = target
	while node do
		if node:IsA("GuiObject") then
			if not node.Visible then return nil, "hidden" end
			if node:IsA("CanvasGroup") and node.GroupTransparency >= 1 then return nil, "hidden" end
			if node ~= target and node.ClipsDescendants then
				if rotation ~= 0 or node.AbsoluteRotation % 360 ~= 0 then return nil, "rotated-clipping" end
				local p, s = node.AbsolutePosition, node.AbsoluteSize
				left, top = math.max(left, p.X), math.max(top, p.Y)
				right, bottom = math.min(right, p.X + s.X), math.min(bottom, p.Y + s.Y)
			end
		elseif node:IsA("ScreenGui") then
			if not node.Enabled then return nil, "hidden" end
			if not node:IsDescendantOf(game) then return nil, "detached" end
			return { left, top, right, bottom }, "visible"
		elseif node:IsA("SurfaceGui") or node:IsA("BillboardGui") then
			return nil, "unsupported-container"
		end
		node = node.Parent
	end
	return nil, "detached"
end

local function equalCache(a, b)
	if not a or #a ~= #b then return false end
	for index, value in b do if a[index] ~= value then return false end end
	return true
end

local function draw(handle, camera, clip, radius)
	local target, options = handle._target, handle._options
	local position, size = target.AbsolutePosition, target.AbsoluteSize
	local rotation = math.rad(target.AbsoluteRotation % 360)
	local frontDepth = math.abs(camera.NearPlaneZ) + options.DepthOffset
	local thickness = frontDepth * 0.000001
	local backDepth = frontDepth + thickness
	local depth = (frontDepth + backDepth) / 2
	local cameraFrame = camera.CFrame
	local basis = CFrame.Angles(0, 0, -rotation)
	local inset = GuiService:GetGuiInset()
	local signature = { position, size, rotation, radius, inset, camera.ViewportSize,
		camera.FieldOfView, camera.FieldOfViewMode, depth, config.Intensity, clip[1], clip[2], clip[3], clip[4] }
	if not equalCache(handle._cache, signature) then
		local footprint = (4 + camera.ViewportSize.Y * 3 / 320) * config.Intensity
		local reserveX = footprint * options.EdgeCompensation.X + options.Padding.X
		local reserveY = footprint * options.EdgeCompensation.Y + options.Padding.Y
		local width, height = math.max(0, size.X - reserveX * 2), math.max(0, size.Y - reserveY * 2)
		local left, top = position.X + reserveX, position.Y + reserveY
		local centerX, centerY = position.X + size.X / 2, position.Y + size.Y / 2
		local cosine, sine = math.cos(rotation), math.sin(rotation)
		local cornerHeight = 0
		if reserveX < radius and reserveY < radius then
			cornerHeight = math.min(height / 2, math.max(0,
				radius - math.sqrt(math.max(0, radius ^ 2 - (radius - reserveX) ^ 2)) - reserveY))
		end
		local function projectBothFaces(x, y)
			local dx, dy = x - centerX, y - centerY
			local screenX = centerX + dx * cosine - dy * sine
			local screenY = centerY + dx * sine + dy * cosine
			local ray = camera:ScreenPointToRay(screenX, screenY)
			local origin = cameraFrame:PointToObjectSpace(ray.Origin)
			local direction = cameraFrame:VectorToObjectSpace(ray.Direction)
			local front = origin + direction * ((-frontDepth - origin.Z) / direction.Z)
			local back = origin + direction * ((-backDepth - origin.Z) / direction.Z)
			return basis:VectorToObjectSpace(front), basis:VectorToObjectSpace(back)
		end
		local drawn = 0
		local function rectangle(index, x, y, w, h)
			local slice = handle._slices[index]
			local x1, y1, x2, y2 = left + x, top + y, left + x + w, top + y + h
			if rotation == 0 then
				x1, y1 = math.max(x1, clip[1]), math.max(y1, clip[2])
				x2, y2 = math.min(x2, clip[3]), math.min(y2, clip[4])
			end
			if w <= 0 or h <= 0 or x2 <= x1 or y2 <= y1 then slice.visible = false; return end
			local a, b = projectBothFaces(x1, y1)
			local c, d = projectBothFaces(x2, y2)
			local minX, maxX = math.max(a.X, b.X), math.min(c.X, d.X)
			local minY, maxY = math.max(c.Y, d.Y), math.min(a.Y, b.Y)
			if minX >= maxX or minY >= maxY then slice.visible = false; return end
			slice.mesh.Scale = Vector3.new(maxX - minX, maxY - minY, thickness)
			slice.transform = basis * CFrame.new((minX + maxX) / 2, (minY + maxY) / 2, -depth)
			slice.visible = true
			drawn += 1
		end
		rectangle(1, 0, cornerHeight, width, math.max(0, height - 2 * cornerHeight))
		local bands = options.CornerSegments
		local bandHeight = cornerHeight / bands
		for band = 1, bands do
			local y = (band - 1) * bandHeight
			local distance = math.max(0, radius - reserveY - y)
			local cornerInset = math.max(0, radius - math.sqrt(math.max(0, radius ^ 2 - distance ^ 2)) - reserveX)
			rectangle(band * 2, cornerInset, y, width - cornerInset * 2, bandHeight)
			rectangle(band * 2 + 1, cornerInset, height - y - bandHeight, width - cornerInset * 2, bandHeight)
		end
		handle._drawn = drawn
		handle._cache = signature
	end
	for _, slice in handle._slices do
		slice.part.Transparency = slice.visible and options.GlassTransparency or 1
		if slice.visible then slice.part.CFrame = cameraFrame * slice.transform end
	end
	return handle._drawn > 0
end

local function renderHandle(handle, camera)
	local size = handle._target.AbsoluteSize
	local radius, scale = resolveRadius(handle, size)
	updateStyle(handle, radius, scale)
	local clip, status = visibility(handle)
	if not camera then clip, status = nil, "no-camera" end
	if size.X <= 0 or size.Y <= 0 then clip, status = nil, "empty" end
	if handle._error then clip, status = nil, "error" end
	if clip and camera.ViewportSize.Y > 0 then
		if draw(handle, camera, clip, radius) then
			handle._mask.Parent = manager.root
			handle._status = "visible"
			return true
		end
		status = "clipped"
	end
	handle._mask.Parent = nil
	handle._status = status
	return false
end

local function step()
	local camera = workspace.CurrentCamera
	if manager.camera ~= camera then
		releaseEffects()
		if manager.cameraConnection then manager.cameraConnection:Disconnect() end
		manager.camera = camera
		manager.cameraConnection = camera and camera.ChildAdded:Connect(holdEffect) or nil
		for _, handle in handles do handle._cache = nil end
	end
	local active = false
	for _, handle in handles do
		local success, visible = pcall(renderHandle, handle, camera)
		if success then
			active = visible or active
		else
			handle._mask.Parent = nil
			handle._error = tostring(visible)
			handle._status = "error"
			if not handle._warned then warn("Acrylic: " .. handle._error); handle._warned = true end
		end
	end
	manager.active = active
	local effect = manager.effect
	effect.NearIntensity = config.Intensity
	effect.FocusDistance = config.FocusDistance
	effect.InFocusRadius = config.InFocusRadius
	effect.FarIntensity = config.FarIntensity
	effect.Enabled = active
	manager.root.Parent = active and workspace or nil
	if active and config.ManageDepthOfField then
		for _, object in Lighting:GetChildren() do holdEffect(object) end
		if camera then for _, object in camera:GetChildren() do holdEffect(object) end end
	else
		releaseEffects()
	end
end

local function startManager()
	if manager then return end
	local name = "EvoliaAcrylic_" .. HttpService:GenerateGUID(false)
	manager = {
		name = name,
		root = create("Folder", { Name = name }, nil),
		effect = create("DepthOfFieldEffect", { Name = name, Enabled = false }, Lighting),
		held = {},
		active = false,
	}
	manager.lightingConnection = Lighting.ChildAdded:Connect(holdEffect)
	RunService:BindToRenderStep(name, Enum.RenderPriority.Last.Value + 1, step)
end

local function applyOptions(handle, options)
	local previous = handle._options
	handle._options = options
	handle._error, handle._warned = nil, nil
	if previous.CornerSegments ~= options.CornerSegments or previous.GlassColor ~= options.GlassColor then
		resizeSlices(handle)
	elseif previous.EdgeCompensation ~= options.EdgeCompensation or previous.Padding ~= options.Padding then
		handle._cache = nil
	end
end

function Handle:SetOptions(changes)
	assert(not self._destroyed, "Acrylic: handle was destroyed")
	applyOptions(self, merge(self._options, changes, validators))
	step()
	return self
end

function Acrylic.update(updates)
	assert(type(updates) == "table", "Acrylic: expected a handle-to-options table")
	local checked = {}
	for handle, changes in pairs(updates) do
		assert(type(handle) == "table" and getmetatable(handle) == Handle and not handle._destroyed,
			"Acrylic: batch requires live panel handles from this module")
		checked[handle] = merge(handle._options, changes, validators)
	end
	for handle, options in pairs(checked) do applyOptions(handle, options) end
	if manager then step() end
end

function Handle:GetOptions()
	return table.clone(self._options)
end

function Handle:SetEnabled(enabled)
	return self:SetOptions({ Enabled = enabled })
end

function Handle:IsEnabled()
	return not self._destroyed and self._options.Enabled
end

function Handle:GetStatus()
	return self._status, self._error
end

function Handle:GetTarget()
	return self._target
end

function Handle:SetTarget(target)
	assert(not self._destroyed, "Acrylic: handle was destroyed")
	assert(typeof(target) == "Instance" and target:IsA("GuiObject"), "Acrylic: target must be a GuiObject")
	assert(not targets[target] or targets[target] == self, "Acrylic: target already attached")
	if target == self._target then return self end
	self._destroyConnection:Disconnect()
	if self._style then self._style:Destroy(); self._style = nil end
	targets[self._target] = nil
	self._target = target
	targets[target] = self
	self._destroyConnection = target.Destroying:Connect(function() self:Destroy() end)
	self._cache, self._error, self._warned = nil, nil, nil
	step()
	return self
end

function Handle:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	self._status = "destroyed"
	self._destroyConnection:Disconnect()
	if self._style then self._style:Destroy(); self._style = nil end
	self._mask:Destroy()
	targets[self._target] = nil
	table.remove(handles, table.find(handles, self))
	if #handles == 0 then stopManager() else step() end
end

function Acrylic.attach(target, options)
	assert(RunService:IsClient(), "Acrylic: attach must run on the client")
	assert(typeof(target) == "Instance" and target:IsA("GuiObject"), "Acrylic: target must be a GuiObject")
	assert(not targets[target], "Acrylic: target already attached; use Acrylic.get(target)")
	local checked = merge(defaults, options or {}, validators)
	local handle = setmetatable({
		_target = target,
		_options = checked,
		_slices = {},
		_mask = create("Folder", { Name = "AcrylicMask" }, nil),
		_status = "detached",
	}, Handle)
	resizeSlices(handle)
	handle._destroyConnection = target.Destroying:Connect(function() handle:Destroy() end)
	table.insert(handles, handle)
	targets[target] = handle
	startManager()
	step()
	return handle
end

function Acrylic.get(target)
	return targets[target]
end

function Acrylic.configure(changes)
	config = merge(config, changes, configValidators)
	if manager then step() end
	return table.clone(config)
end

function Acrylic.getConfig()
	return table.clone(config)
end

local Fullscreen = {}
Fullscreen.__index = Fullscreen
local fullscreenDefaults = {
	Size = 24,
	Duration = 0.7,
	Visible = false,
}
local fullscreenValidators = {
	Size = function(v) return range(v, 0, 56) end,
	Duration = function(v) return range(v, 0.05, 10) end,
	Visible = function(v) return type(v) == "boolean" end,
}

function Fullscreen:_animate()
	if self._connection then return end
	self._effect.Enabled = true
	self._connection = RunService.RenderStepped:Connect(function(deltaTime)
		local target = self._options.Visible and 1 or 0
		local omega = 10 / self._options.Duration
		local displacement = self._amount - target
		local term = self._velocity + omega * displacement
		local decay = math.exp(-omega * deltaTime)
		self._amount = target + (displacement + term * deltaTime) * decay
		self._velocity = (self._velocity - omega * term * deltaTime) * decay
		if math.abs(self._amount - target) < 0.0001 and math.abs(self._velocity) < 0.001 then
			self._amount, self._velocity = target, 0
			self._connection:Disconnect()
			self._connection = nil
		end
		self._effect.Size = math.clamp(self._amount, 0, 1) * self._options.Size
		self._effect.Enabled = self._amount > 0 or self._options.Visible
	end)
end

function Fullscreen:SetOptions(changes)
	assert(not self._destroyed, "Acrylic: fullscreen handle was destroyed")
	self._options = merge(self._options, changes, fullscreenValidators)
	self._effect.Size = math.clamp(self._amount, 0, 1) * self._options.Size
	local target = self._options.Visible and 1 or 0
	if self._amount ~= target or self._velocity ~= 0 then self:_animate() end
	return self
end

function Fullscreen:SetVisible(visible)
	return self:SetOptions({ Visible = visible })
end

function Fullscreen:IsVisible()
	return not self._destroyed and self._options.Visible
end

function Fullscreen:GetOptions()
	return table.clone(self._options)
end

function Fullscreen:GetSize()
	return self._destroyed and 0 or self._effect.Size
end

function Fullscreen:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	if self._connection then self._connection:Disconnect(); self._connection = nil end
	self._destroyConnection:Disconnect()
	self._effect:Destroy()
	fullscreens[self] = nil
end

function Acrylic.fullscreen(options)
	assert(RunService:IsClient(), "Acrylic: fullscreen must run on the client")
	local checked = merge(fullscreenDefaults, options or {}, fullscreenValidators)
	local handle = setmetatable({
		_options = checked,
		_amount = 0,
		_velocity = 0,
		_effect = create("BlurEffect", {
			Name = "EvoliaBackgroundBlur",
			Size = 0,
			Enabled = false,
		}, Lighting),
	}, Fullscreen)
	fullscreens[handle] = true
	handle._destroyConnection = handle._effect.Destroying:Connect(function() handle:Destroy() end)
	if checked.Visible then handle:_animate() end
	return handle
end

function Acrylic.destroyAll()
	for _, handle in table.clone(handles) do handle:Destroy() end
	for handle in table.clone(fullscreens) do handle:Destroy() end
end

Acrylic.Defaults = defaults
return table.freeze(Acrylic)
