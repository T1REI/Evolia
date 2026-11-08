local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Radial = {}
local Window = {}
Window.__index = Window
local light = {
	background = Color3.fromRGB(249, 249, 248), surface = Color3.fromRGB(239, 240, 238),
	text = Color3.fromRGB(37, 41, 40), muted = Color3.fromRGB(114, 121, 118),
	accent = Color3.fromRGB(120, 154, 137), border = Color3.fromRGB(218, 223, 219),
	danger = Color3.fromRGB(194, 94, 94), track = Color3.fromRGB(211, 218, 213),
}
local dark = {
	background = Color3.fromRGB(30, 34, 32), surface = Color3.fromRGB(43, 49, 45),
	text = Color3.fromRGB(242, 245, 240), muted = Color3.fromRGB(157, 168, 159),
	accent = Color3.fromRGB(159, 197, 173), border = Color3.fromRGB(69, 80, 72),
	danger = Color3.fromRGB(231, 137, 137), track = Color3.fromRGB(64, 76, 68),
}
local defaults = {
	name = "Evolia", subtitle = "A little space for everything.", toggleKey = Enum.KeyCode.RightShift,
	diameter = 460, orbitGap = 24, tabSize = 58, startAngle = -90, maxTabsPerPage = 8,
	position = UDim2.fromScale(0.5, 0.5), padding = 28, backgroundTransparency = 0.14,
	blurSize = 20, acrylic = true, animationDuration = 0.65, interactionDuration = 0.22,
	reducedMotion = false, visible = false, theme = "light", font = Enum.Font.Gotham,
	textSize = 13, cornerRadius = 10, rowHeight = 58, elementGap = 8,
}
local function number(v, low, high) return type(v) == "number" and v == v and v >= low and v <= high end
local function keyCode(v)
	if type(v) == "string" then local ok, key = pcall(function() return Enum.KeyCode[v] end); v = ok and key or nil end
	assert(typeof(v) == "EnumItem" and v.EnumType == Enum.KeyCode and v ~= Enum.KeyCode.Unknown,
		"Evolia: expected a KeyCode or its name")
	return v
end
local function theme(value)
	if value == "light" then return table.clone(light) end
	if value == "dark" then return table.clone(dark) end
	assert(type(value) == "table", "Evolia: theme must be light, dark, or a color table")
	local result = table.clone(light)
	for key, color in value do
		assert(result[key] ~= nil and typeof(color) == "Color3", "Evolia: invalid theme token " .. tostring(key))
		result[key] = color
	end
	return result
end
local ranges = {
	diameter = { 300, 800 }, orbitGap = { 8, 100 }, tabSize = { 36, 100 }, startAngle = { -360, 360 },
	maxTabsPerPage = { 3, 12 }, padding = { 8, 100 }, backgroundTransparency = { 0, 1 },
	blurSize = { 0, 56 }, animationDuration = { 0.05, 5 }, interactionDuration = { 0.05, 2 },
	textSize = { 10, 24 }, cornerRadius = { 0, 32 }, rowHeight = { 48, 120 }, elementGap = { 2, 32 },
}
function Radial.validate(options, base)
	assert(type(options) == "table", "Evolia: expected options")
	local result, seen = table.clone(base or defaults), {}
	for supplied, value in options do
		assert(type(supplied) == "string", "Evolia: invalid option name")
		local key = supplied:sub(1, 1):lower() .. supplied:sub(2)
		assert(defaults[key] ~= nil and not seen[key], "Evolia: unknown or repeated option " .. supplied)
		seen[key] = true
		if ranges[key] then assert(number(value, unpack(ranges[key])), "Evolia: invalid " .. key)
		elseif key == "toggleKey" then value = keyCode(value)
		elseif key == "theme" then theme(value); if type(value) == "table" then value = table.clone(value) end
		elseif key == "position" then
			assert(typeof(value) == "UDim2" and number(value.X.Scale, 0, 1) and number(value.Y.Scale, 0, 1)
				and number(value.X.Offset, -10000, 10000) and number(value.Y.Offset, -10000, 10000), "Evolia: invalid position")
		elseif key == "font" then assert(typeof(value) == "EnumItem" and value.EnumType == Enum.Font, "Evolia: invalid font")
		else assert(type(value) == type(defaults[key]), "Evolia: invalid " .. key) end
		result[key] = value
	end
	assert(result.maxTabsPerPage % 1 == 0, "Evolia: maxTabsPerPage must be an integer")
	return result
end

function Window:Connect(owner, signal, callback)
	local connection = signal:Connect(function(...) if not self._dead and not owner._dead then callback(...) end end)
	table.insert(owner._connections, connection)
	return connection
end
function Window:Call(callback, ...)
	if not callback then return end
	local ok, problem = pcall(callback, ...)
	if not ok then warn("Evolia callback: " .. tostring(problem)) end
end
function Window:Make(class, props, parent, tokens)
	local object = Instance.new(class)
	for key, value in props do object[key] = value end
	if tokens then for key, token in tokens do object[key] = self._theme[token] end end
	object.Parent = parent
	if tokens then self._styles[object] = tokens end
	local lifetime = { _connections = {} }
	self._objects[object] = lifetime
	table.insert(lifetime._connections, object.Destroying:Connect(function()
		lifetime._dead = true
		for _, c in lifetime._connections do c:Disconnect() end
		self._styles[object], self._motions[object], self._objects[object] = nil, nil, nil
	end))
	return object
end
function Window:Round(object, radius)
	return self:Make("UICorner", { CornerRadius = radius or UDim.new(0, self._settings.cornerRadius) }, object)
end
function Window:Text(parent, text, props, token)
	local settings = { BackgroundTransparency = 1, BorderSizePixel = 0, Text = text or "", RichText = false,
		Font = self._settings.font, TextSize = self._settings.textSize, TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd }
	for key, value in props or {} do settings[key] = value end
	local object = self:Make("TextLabel", settings, parent, { TextColor3 = token or "text" })
	self._objects[object].fixedFont = props and props.Font ~= nil
	self._objects[object].fixedTextSize = props and props.TextSize ~= nil
	return object
end
function Window:Button(parent, text, props)
	local settings = { Text = text or "", AutoButtonColor = false, BorderSizePixel = 0,
		Font = self._settings.font, TextSize = self._settings.textSize, Size = UDim2.fromOffset(80, 30) }
	for key, value in props or {} do settings[key] = value end
	local object = self:Make("TextButton", settings, parent, { BackgroundColor3 = "surface", TextColor3 = "text" })
	self._objects[object].fixedFont = props and props.Font ~= nil
	self._objects[object].fixedTextSize = props and props.TextSize ~= nil
	self:Round(object)
	self:Connect(self._objects[object], object.MouseEnter, function()
		if object.BackgroundTransparency == 1 or not self._styles[object].BackgroundColor3 then return end
		self:Color(object, "BackgroundColor3", self._theme.accent:Lerp(self._theme.surface, 0.82))
	end)
	self:Connect(self._objects[object], object.MouseLeave, function()
		if object.BackgroundTransparency == 1 or not self._styles[object].BackgroundColor3 then return end
		self:Color(object, "BackgroundColor3", self._theme[self._styles[object].BackgroundColor3])
	end)
	return object
end
function Window:Motion(owner, key, target, initial, apply, duration)
	if self._dead then return end
	local tracks = self._motions[owner]
	if not tracks then tracks = {}; self._motions[owner] = tracks end
	local track = tracks[key]
	if not track then track = { value = initial, velocity = 0 }; tracks[key] = track end
	track.target, track.apply, track.duration = target, apply, duration or self._settings.interactionDuration
	if self._settings.reducedMotion then track.value, track.velocity = target, 0; apply(target); tracks[key] = nil end
	self:Wake()
end
function Window:Color(object, property, target)
	local from = object[property]
	self:Motion(object, property, 1, 0, function(t) object[property] = t == 1 and target or from:Lerp(target, math.clamp(t, 0, 1)) end)
	local track = self._motions[object] and self._motions[object][property]
	if track then track.value, track.velocity = 0, 0 end
end
function Window:Wake()
	if self._render or self._dead then return end
	self._render = RunService.RenderStepped:Connect(function(dt)
		local busy = false
		for owner, tracks in pairs(self._motions) do
			for key, track in pairs(tracks) do
				if self._settings.reducedMotion then track.value, track.velocity = track.target, 0
				else
					local omega = 10 / track.duration
					local displacement = track.value - track.target
					local term = track.velocity + omega * displacement
					local decay = math.exp(-omega * dt)
					track.value = track.target + (displacement + term * dt) * decay
					track.velocity = (track.velocity - omega * term * dt) * decay
				end
				if math.abs(track.value - track.target) < 0.0001 and math.abs(track.velocity) < 0.001 then
					track.value = track.target; tracks[key] = nil
				else busy = true end
				track.apply(track.value)
				if self._dead then return end
			end
			if next(tracks) == nil then self._motions[owner] = nil end
		end
		for handle in pairs(self._timers) do
			if not handle.hovered then handle.remaining -= dt end
			if handle.remaining <= 0 then handle:Close() else busy = true end
		end
		if next(self._motions) ~= nil or next(self._timers) ~= nil then busy = true end
		if not busy and self._render then self._render:Disconnect(); self._render = nil end
	end)
end
function Window:_layout()
	local s = self._settings
	local extent = s.diameter + (s.orbitGap + s.tabSize + 26) * 2
	local view = self._gui.AbsoluteSize
	self._fit = math.min(1, math.max(0, view.X - s.padding * 2) / extent, math.max(0, view.Y - s.padding * 2) / extent)
	self._root.Size = UDim2.fromOffset(extent, extent)
	self._root.Position = s.position
	self._scale.Scale = self._fit * (0.95 + 0.05 * self._amount)
	self._circle.Size = UDim2.fromOffset(s.diameter, s.diameter)
	local orbit = s.diameter / 2 + s.orbitGap + s.tabSize / 2
	self._ring.Size = UDim2.fromOffset(orbit * 2, orbit * 2)
	local pages = math.max(1, math.ceil(#self._tabs / s.maxTabsPerPage))
	self._page = math.clamp(self._page, 1, pages)
	local start = (self._page - 1) * s.maxTabsPerPage + 1
	local count = math.min(s.maxTabsPerPage, #self._tabs - start + 1)
	local chord = count > 1 and 2 * orbit * math.sin(math.pi / count) or orbit * 2
	for index, tab in self._tabs do
		local slot = index - start
		tab._node.Visible = slot >= 0 and slot < count
		local angle = math.rad(s.startAngle + slot * 360 / math.max(1, count))
		tab._node.Position = UDim2.new(0.5, math.cos(angle) * orbit, 0.5, math.sin(angle) * orbit)
		local nodeSize = math.min(s.tabSize, chord * 0.72)
		tab._node.Size = UDim2.fromOffset(nodeSize, nodeSize)
		local labelWidth = math.min(nodeSize * 2.2, chord * 0.9)
		tab._nodeLabel.Size = UDim2.fromOffset(labelWidth, 20)
		tab._nodeLabel.Position = UDim2.new(0.5, -labelWidth / 2, 1, 5)
	end
	self._previous.Visible, self._next.Visible = pages > 1, pages > 1
	self._pager.Text = pages > 1 and (self._page .. " / " .. pages) or ""
	self._title.Text = s.name
	self._subtitle.Text = s.subtitle
	self._hint.Text = s.toggleKey.Name .. "  ·  " .. (self._selected and self._selected.name or "Create a tab to begin")
	self._circle.BackgroundTransparency = s.backgroundTransparency
	self._glass:SetEnabled(s.acrylic and self._amount > 0)
	for _, object in self._circle:GetChildren() do
		if object:IsA("ScrollingFrame") and object.Name == "Page" then
			object.Size = UDim2.new(0.72, 0, 0.56, 0)
		end
	end
end
function Window:SetOptions(changes)
	assert(not self._dead, "Evolia: window was destroyed")
	local settings = Radial.validate(changes, self._settings)
	local visibleChanged = settings.visible ~= self._settings.visible
	local themeChanged = settings.theme ~= self._settings.theme
	self._settings = settings
	self._blur:SetOptions({ Size = settings.blurSize, Duration = settings.reducedMotion and 0.05 or settings.animationDuration })
	if themeChanged then self:ChangeTheme(settings.theme) end
	for object in self._styles do
		if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
			if not self._objects[object].fixedFont then object.Font = settings.font end
			if not self._objects[object].fixedTextSize then object.TextSize = settings.textSize end
		end
	end
	for _, tab in self._tabs do tab:_restyle() end
	self:_layout()
	if visibleChanged then self:SetVisible(settings.visible) end
	return self
end
function Window:ChangeTheme(value)
	assert(not self._dead, "Evolia: window was destroyed")
	local colors = theme(value)
	self._settings.theme, self._theme = type(value) == "table" and table.clone(value) or value, colors
	for object, tokens in pairs(self._styles) do
		for property, token in tokens do self:Color(object, property, colors[token]) end
	end
	return self
end
function Window:GetOptions()
	local copy = table.clone(self._settings)
	if type(copy.theme) == "table" then copy.theme = table.clone(copy.theme) end
	return copy
end
function Window:GetTheme() return table.clone(self._theme) end
function Window:GetInstance() assert(not self._dead, "Evolia: window destroyed"); return self._root end
function Window:SetToggleKey(key) return self:SetOptions({ toggleKey = keyCode(key) }) end
function Window:GetToggleKey() return self._settings.toggleKey end
function Window:IsVisible() return not self._dead and self._visible end
function Window:SetVisible(visible)
	assert(not self._dead and type(visible) == "boolean", "Evolia: invalid visibility or destroyed window")
	self._visible, self._settings.visible = visible, visible
	self._root.Visible = true
	if not visible then self:CancelInput(); if self._popup then self._popup:Close(true) end end
	self._blur:SetVisible(visible)
	self:Motion(self, "visibility", visible and 1 or 0, self._amount, function(amount)
		self._amount = math.clamp(amount, 0, 1)
		self._root.GroupTransparency = 1 - self._amount
		self._scale.Scale = (self._fit or 1) * (0.95 + 0.05 * self._amount)
		self._root.Visible = self._amount > 0 or self._visible
		self._glass:SetOptions({ Enabled = self._settings.acrylic and self._amount > 0,
			GlassTransparency = 0.999 - self._amount * 0.019 })
	end, self._settings.animationDuration)
	return self
end
function Window:Show() return self:SetVisible(true) end
function Window:Hide() return self:SetVisible(false) end
function Window:Toggle() return self:SetVisible(not self:IsVisible()) end
function Window:CancelInput()
	self._drag = nil
	if self._capture then self._capture:_display(); self._capture = nil end
	for _, bind in self._keybinds do
		if bind._held then bind._held = false; self:Call(bind._props.callback, false) end
	end
end
function Window:CanUse(element)
	if self._dead or element._dead or element._locked or not self._visible or element._tab ~= self._selected or self._popup then return false end
	local node = element._row
	while node and node:IsA("GuiObject") do if not node.Visible then return false end; node = node.Parent end
	return true
end
function Window:Navigate(tab)
	if type(tab) == "string" then for _, candidate in self._tabs do if candidate.name == tab then tab = candidate; break end end end
	assert(type(tab) == "table" and tab._window == self and not tab._dead, "Evolia: unknown tab")
	self:CancelInput()
	self._selected = tab
	self._page = math.ceil(table.find(self._tabs, tab) / self._settings.maxTabsPerPage)
	for _, candidate in self._tabs do
		candidate._page.Visible = candidate == tab
		self._styles[candidate._node].BackgroundColor3 = candidate == tab and "accent" or "surface"
		self:Color(candidate._node, "BackgroundColor3", candidate == tab and self._theme.accent or self._theme.surface)
	end
	tab._page.GroupTransparency = 1
	self:Motion(tab, "reveal", 1, 0, function(t)
		tab._page.GroupTransparency = 1 - math.clamp(t, 0, 1)
	end, self._settings.interactionDuration)
	self:_layout()
	return self
end
function Window:CreateTab(props)
	assert(not self._dead, "Evolia: window destroyed")
	props = self._Controls.normalize(props or {})
	local name = props.name or "Tab " .. (#self._tabs + 1)
	assert(type(name) == "string", "Evolia: tab name must be text")
	if props.icon then self._Controls.image(props.icon) end
	local tab = self._Controls.container(self, nil, nil)
	tab.name, tab._tab = name, tab
	tab._page = self:Make("CanvasGroup", { Name = "Page", BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.14, 0.25), Size = UDim2.fromScale(0.72, 0.56), Visible = false }, self._circle)
	tab._body = self:Make("ScrollingFrame", { Name = "Content", BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2, ScrollingDirection = Enum.ScrollingDirection.Y }, tab._page, { ScrollBarImageColor3 = "accent" })
	tab:_list()
	tab._node = self:Button(self._root, props.icon and "" or name:sub(1, 2):upper(), {
		Name = "Tab_" .. name, AnchorPoint = Vector2.new(0.5, 0.5), TextSize = 16 })
	tab._node:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
	if props.icon then
		self:Make("ImageLabel", { BackgroundTransparency = 1, Image = self._Controls.image(props.icon),
			Size = UDim2.fromScale(0.44, 0.44), Position = UDim2.fromScale(0.28, 0.28) }, tab._node,
			{ ImageColor3 = "text" })
	end
	tab._nodeLabel = self:Text(tab._node, name, { Position = UDim2.new(-0.6, 0, 1, 5), Size = UDim2.new(2.2, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11 }, "muted")
	function tab:Select() self._window:Navigate(self); return self end
	function tab:Destroy()
		if self._dead then return end
		self._dead = true
		for _, element in table.clone(self._elements) do element:Destroy() end
		for _, c in self._connections do c:Disconnect() end
		self._window._motions[self] = nil
		self._page:Destroy(); self._node:Destroy()
		table.remove(self._window._tabs, table.find(self._window._tabs, self))
		if self._window._selected == self then
			self._window._selected = nil
			if self._window._tabs[1] and not self._window._dead then self._window:Navigate(self._window._tabs[1]) end
		end
		if not self._window._dead then self._window:_layout() end
	end
	tab.Remove = tab.Destroy
	table.insert(self._tabs, tab)
	self:Connect(tab, tab._node.Activated, function() if self._visible and not self._popup then self:Navigate(tab) end end)
	if not self._selected then self:Navigate(tab) else self:_layout() end
	return tab
end
function Window:Get(flag)
	local element = self._flags[flag]
	if element then return element:Get() end
	return nil
end
function Window:Set(flag, value, silent)
	local element = self._flags[flag]
	if not element then return false end
	element:Set(value, silent); return true
end
function Window:CreateSettingsTab(props)
	local tab = self:CreateTab(props or { name = "Appearance" })
	tab:CreateSection({ name = "Make it yours" })
	tab:CreateDropdown({ name = "Theme", options = { "light", "dark" }, value = type(self._settings.theme) == "string" and self._settings.theme or "light", forgetState = true,
		callback = function(v) self:ChangeTheme(v) end })
	for _, entry in { { "Diameter", "diameter", 300, 800 }, { "Orbit spacing", "orbitGap", 8, 100 },
		{ "Tab size", "tabSize", 36, 100 }, { "Orbit angle", "startAngle", -360, 360 },
		{ "Tabs per page", "maxTabsPerPage", 3, 12 }, { "Screen margin", "padding", 8, 100 },
		{ "Text size", "textSize", 10, 24 }, { "Corner radius", "cornerRadius", 0, 32 },
		{ "Row height", "rowHeight", 48, 120 }, { "Element spacing", "elementGap", 2, 32 },
		{ "Blur", "blurSize", 0, 56 }, { "Animation", "animationDuration", 0.1, 2 },
		{ "Interactions", "interactionDuration", 0.05, 2 }, { "Tint transparency", "backgroundTransparency", 0, 1 } } do
		local key = entry[2]
		tab:CreateSlider({ name = entry[1], range = { entry[3], entry[4] }, value = self._settings[key],
			increment = (key == "animationDuration" or key == "interactionDuration" or key == "backgroundTransparency") and 0.05 or 1,
			forgetState = true, callback = function(v) self:SetOptions({ [key] = v }) end })
	end
	for _, token in { "background", "surface", "text", "muted", "accent", "border", "track", "danger" } do
		tab:CreateColorPicker({ name = token, color = self._theme[token], forgetState = true, callback = function(v)
			local colors = table.clone(self._theme); colors[token] = v; self:ChangeTheme(colors)
		end })
	end
	tab:CreateInput({ name = "Window title", value = self._settings.name, forgetState = true,
		callback = function(v) self:SetOptions({ name = v }) end })
	tab:CreateInput({ name = "Window subtitle", value = self._settings.subtitle, forgetState = true,
		callback = function(v) self:SetOptions({ subtitle = v }) end })
	for _, axis in { "X", "Y" } do
		tab:CreateSlider({ name = "Position " .. axis, range = { 0, 1 }, increment = 0.01,
			value = self._settings.position[axis].Scale, forgetState = true, callback = function(v)
				local p = self._settings.position
				self:SetOptions({ position = UDim2.new(axis == "X" and v or p.X.Scale, p.X.Offset,
					axis == "Y" and v or p.Y.Scale, p.Y.Offset) })
			end })
	end
	local fonts = { "Gotham", "GothamMedium", "GothamBold", "Code" }
	if not table.find(fonts, self._settings.font.Name) then table.insert(fonts, self._settings.font.Name) end
	tab:CreateDropdown({ name = "Font", options = fonts, value = self._settings.font.Name, forgetState = true,
		callback = function(name) self:SetOptions({ font = Enum.Font[name] }) end })
	tab:CreateToggle({ name = "Acrylic", value = self._settings.acrylic, forgetState = true,
		callback = function(v) self:SetOptions({ acrylic = v }) end })
	tab:CreateToggle({ name = "Reduced motion", value = self._settings.reducedMotion, forgetState = true,
		callback = function(v) self:SetOptions({ reducedMotion = v }) end })
	tab:CreateKeybind({ name = "Open / close", value = self:GetToggleKey(), forgetState = true,
		onChanged = function(key) self:SetToggleKey(key) end })
	return tab
end
function Window:_feedback(props, toast)
	assert(not self._dead, "Evolia: window destroyed")
	props = self._Controls.normalize(props or {})
	local duration = props.duration or 5
	assert(number(duration, 0.1, 3600), "Evolia: invalid notification duration")
	for _, key in { "title", "content", "subtitle" } do assert(props[key] == nil or type(props[key]) == "string", "Evolia: invalid notification text") end
	if props.icon then self._Controls.image(props.icon) end
	local handle = { _connections = {}, remaining = duration, _window = self, _toast = toast }
	handle._root = self:Make("CanvasGroup", { Name = toast and "Toast" or "Notification", AnchorPoint = Vector2.new(toast and 0.5 or 1, toast and 0 or 1),
		Size = UDim2.new(0.85, 0, 0, 80), GroupTransparency = 1, ZIndex = 20, BorderSizePixel = 0 }, self._gui, { BackgroundColor3 = "background" })
	self:Make("UISizeConstraint", { MaxSize = Vector2.new(320, 80) }, handle._root)
	self:Round(handle._root)
	self:Make("UIStroke", { Thickness = 1, Transparency = 0.25 }, handle._root, { Color = "border" })
	if props.icon then self:Make("ImageLabel", { BackgroundTransparency = 1, Image = self._Controls.image(props.icon),
		Position = UDim2.fromOffset(16, 14), Size = UDim2.fromOffset(18, 18) }, handle._root, { ImageColor3 = "accent" }) end
	self:Text(handle._root, props.title or "Evolia", { Position = UDim2.fromOffset(props.icon and 42 or 16, 12), Size = UDim2.new(1, props.icon and -58 or -32, 0, 22) })
	self:Text(handle._root, props.content or props.subtitle or "", { Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -32, 0, 32), TextWrapped = true, TextSize = 11 }, "muted")
	local hit = self:Button(handle._root, "", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local function cleanup()
		for _, c in handle._connections do c:Disconnect() end
		handle._root:Destroy(); self._widgets[handle] = nil; self._motions[handle] = nil
	end
	function handle:Close()
		if self._dead then return end
		self._dead = true; self._window._timers[self] = nil
		if self._window._dead then cleanup(); return end
		self._window:Motion(self, "fade", 0, self.amount or 1, function(t)
			self.amount = t; self._root.GroupTransparency = 1 - math.clamp(t, 0, 1)
			if t == 0 then cleanup() end
		end)
	end
	self:Connect(handle, hit.Activated, function() self:Call(props.callback); handle:Close() end)
	self:Connect(handle, hit.MouseEnter, function() handle.hovered = true end)
	self:Connect(handle, hit.MouseLeave, function() handle.hovered = false end)
	local stack = {}
	for widget in self._widgets do if widget._toast == toast and not widget._dead then table.insert(stack, widget) end end
	table.sort(stack, function(a, b) return a._sequence < b._sequence end)
	if #stack >= 6 then stack[1]:Close(); table.remove(stack, 1) end
	for index, widget in stack do
		widget._root.Position = toast and UDim2.new(0.5, 0, 0, 24 + index * 90) or UDim2.new(1, -24, 1, -24 - index * 90)
	end
	self._sequence = (self._sequence or 0) + 1; handle._sequence = self._sequence
	handle._root.Position = toast and UDim2.new(0.5, 0, 0, 24) or UDim2.new(1, -24, 1, -24)
	self._widgets[handle], self._timers[handle] = true, true
	self:Motion(handle, "fade", 1, 0, function(t) handle.amount = t; handle._root.GroupTransparency = 1 - math.clamp(t, 0, 1) end)
	return handle
end
function Window:Notify(props) return self:_feedback(props, false) end
function Window:Toast(props) return self:_feedback(props, true) end
function Window:Popup(props)
	assert(not self._dead, "Evolia: window destroyed")
	props = self._Controls.normalize(props or {})
	local choices = props.options or { { text = "Close" } }
	assert(type(choices) == "table" and #choices > 0, "Evolia: popup requires options")
	for _, key in { "title", "subtitle", "content" } do assert(props[key] == nil or type(props[key]) == "string", "Evolia: invalid popup text") end
	for _, choice in choices do
		assert(type(choice) == "table" and (choice.text == nil or type(choice.text) == "string")
			and (choice.callback == nil or type(choice.callback) == "function"), "Evolia: invalid popup option")
	end
	assert(props.boxes == nil or type(props.boxes) == "table", "Evolia: boxes must be a list")
	for _, entry in props.boxes or {} do
		assert(type(entry) == "table" and (entry.title == nil or type(entry.title) == "string")
			and (entry.description == nil or type(entry.description) == "string"), "Evolia: invalid popup box")
	end
	if self._popup then self._popup:Close(true) end
	self:CancelInput()
	local handle = { _connections = {}, _window = self, dismissable = props.dismissable ~= false }
	handle._root = self:Make("CanvasGroup", { Name = "Popup", Size = UDim2.fromScale(1, 1), GroupTransparency = 1,
		BackgroundTransparency = 1, ZIndex = 50 }, self._gui)
	local backdrop = self:Button(handle._root, "", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Size = UDim2.fromScale(1, 1) })
	self._styles[backdrop].BackgroundColor3 = nil
	local card = self:Make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.68), BorderSizePixel = 0, ZIndex = 2 }, handle._root, { BackgroundColor3 = "background" })
	self:Make("UISizeConstraint", { MaxSize = Vector2.new(430, 420) }, card)
	self:Round(card)
	self:Text(card, props.title or "Evolia", { Position = UDim2.fromOffset(22, 20), Size = UDim2.new(1, -44, 0, 30), TextSize = 20 })
	self:Text(card, props.subtitle or "", { Position = UDim2.fromOffset(22, 51), Size = UDim2.new(1, -44, 0, 22), TextSize = 11 }, "muted")
	local content = props.content or ""
	for _, entry in props.boxes or {} do content ..= "\n" .. (entry.title or "") .. "\n" .. (entry.description or "") .. "\n" end
	local scroll = self:Make("ScrollingFrame", { Position = UDim2.fromOffset(22, 80), Size = UDim2.new(1, -44, 1, -150),
		BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2 }, card, { ScrollBarImageColor3 = "accent" })
	self:Text(scroll, content, { TextWrapped = true, TextTruncate = Enum.TextTruncate.None, AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -4, 0, 0), TextYAlignment = Enum.TextYAlignment.Top }, "muted")
	local footer = self:Make("Frame", { Position = UDim2.new(0, 22, 1, -56), Size = UDim2.new(1, -44, 0, 34), BackgroundTransparency = 1 }, card)
	self:Make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, footer)
	local function cleanup()
		for _, c in handle._connections do c:Disconnect() end
		handle._root:Destroy(); self._widgets[handle] = nil; self._motions[handle] = nil
	end
	function handle:Close(immediate)
		if self._dead then return end
		self._dead = true
		if self._window._popup == self then self._window._popup = nil end
		if immediate or self._window._dead then cleanup(); return end
		self._window:Motion(self, "fade", 0, self.amount or 1, function(t)
			self.amount = t; self._root.GroupTransparency = 1 - math.clamp(t, 0, 1)
			if t == 0 then cleanup() end
		end)
	end
	for index, choice in choices do
		local button = self:Button(footer, choice.text or "Close", { LayoutOrder = index, Size = UDim2.new(1 / #choices, -8, 1, 0) })
		self._styles[button].BackgroundColor3 = choice.style == "danger" and "danger" or choice.style == "primary" and "accent" or "surface"
		button.BackgroundColor3 = self._theme[self._styles[button].BackgroundColor3]
		self:Connect(handle, button.Activated, function() self:Call(choice.callback); handle:Close() end)
	end
	self:Connect(handle, backdrop.Activated, function() if handle.dismissable then handle:Close() end end)
	self._popup, self._widgets[handle] = handle, true
	self:Motion(handle, "fade", 1, 0, function(t) handle.amount = t; handle._root.GroupTransparency = 1 - math.clamp(t, 0, 1) end)
	return handle
end
function Window:CreateTag(props)
	assert(not self._dead, "Evolia: window destroyed")
	props = self._Controls.normalize(props or {})
	local tag = { _connections = {} }
	assert(props.width == nil or number(props.width, 30, 260), "Evolia: invalid tag width")
	local frame = self:Make("Frame", { Size = UDim2.fromOffset(props.width or 90, 20), BorderSizePixel = 0 }, self._tags, { BackgroundColor3 = "surface" })
	self:Round(frame, UDim.new(0.5, 0))
	local label = self:Text(frame, props.name or props.text or "Tag", { Size = UDim2.fromScale(1, 1), TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center }, "accent")
	local window = self
	function tag:Set(text) assert(not self._dead and not window._dead and type(text) == "string"); label.Text = text; return self end
	function tag:Destroy() if self._dead then return end; self._dead = true; frame:Destroy() end
	tag.Remove = tag.Destroy
	return tag
end
function Window:Destroy()
	if self._dead then return end
	self:CancelInput()
	self._dead, self._visible = true, false
	if self._render then self._render:Disconnect(); self._render = nil end
	for handle in pairs(self._widgets) do handle:Close(true) end
	for _, connection in self._connections do connection:Disconnect() end
	for _, tab in table.clone(self._tabs) do tab:Destroy() end
	if self._glass then self._glass:Destroy() end
	if self._blur then self._blur:Destroy() end
	if self._gui then self._gui:Destroy() end
	table.clear(self._motions); table.clear(self._styles); table.clear(self._timers); table.clear(self._objects)
	table.clear(self._widgets); table.clear(self._flags); table.clear(self._keybinds)
	if self._onDestroy then self._onDestroy() end
end
function Radial.new(settings, Acrylic, Controls)
	local self = setmetatable({ _settings = settings, _theme = theme(settings.theme), _Controls = Controls,
		_connections = {}, _tabs = {}, _flags = {}, _keybinds = {}, _styles = {}, _objects = {}, _motions = {}, _timers = {},
		_widgets = {}, _page = 1, _amount = 0, _visible = false }, Window)
	self.Flags = setmetatable({}, { __index = function(_, flag) return self:Get(flag) end,
		__newindex = function(_, flag, value) assert(self:Set(flag, value), "Evolia: unknown flag") end })
	local ok, problem = pcall(function()
		self._gui = self:Make("ScreenGui", { Name = settings.name, ResetOnSpawn = false, DisplayOrder = 100,
			ScreenInsets = Enum.ScreenInsets.None, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, Players.LocalPlayer:WaitForChild("PlayerGui"))
		self._root = self:Make("CanvasGroup", { Name = "Radial", BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5), GroupTransparency = 1, Visible = false }, self._gui)
		self._scale = self:Make("UIScale", { Scale = 1 }, self._root)
		self._ring = self:Make("Frame", { Name = "Orbit", AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1 }, self._root)
		self:Round(self._ring, UDim.new(0.5, 0))
		self:Make("UIStroke", { Thickness = 1, Transparency = 0.65 }, self._ring, { Color = "border" })
		self._circle = self:Make("Frame", { Name = "Circle", AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), BorderSizePixel = 0 }, self._root, { BackgroundColor3 = "background" })
		self:Round(self._circle, UDim.new(0.5, 0))
		self._tags = self:Make("Frame", { Position = UDim2.fromScale(0.2, 0.065), Size = UDim2.fromScale(0.6, 0.05), BackgroundTransparency = 1 }, self._circle)
		self:Make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6) }, self._tags)
		self:Make("UIStroke", { Thickness = 1, Transparency = 0.2 }, self._circle, { Color = "border" })
		self._title = self:Text(self._circle, settings.name, { Position = UDim2.fromScale(0.2, 0.125),
			Size = UDim2.fromScale(0.6, 0.07), TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center })
		self._subtitle = self:Text(self._circle, settings.subtitle, { Position = UDim2.fromScale(0.18, 0.20),
			Size = UDim2.fromScale(0.64, 0.04), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center }, "muted")
		self._hint = self:Text(self._circle, "", { Position = UDim2.fromScale(0.2, 0.84), Size = UDim2.fromScale(0.6, 0.05),
			TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center }, "muted")
		self._previous = self:Button(self._circle, "‹", { Position = UDim2.fromScale(0.26, 0.91), Size = UDim2.fromOffset(28, 24) })
		self._next = self:Button(self._circle, "›", { Position = UDim2.fromScale(0.68, 0.91), Size = UDim2.fromOffset(28, 24) })
		self._pager = self:Text(self._circle, "", { Position = UDim2.fromScale(0.42, 0.91), Size = UDim2.fromScale(0.16, 0.05), TextXAlignment = Enum.TextXAlignment.Center }, "muted")
		self:Connect(self, self._previous.Activated, function() self._page -= 1; self:_layout() end)
		self:Connect(self, self._next.Activated, function() self._page += 1; self:_layout() end)
		self._glass = Acrylic.attach(self._circle, { Enabled = false, CornerSegments = 32 })
		self._blur = Acrylic.fullscreen({ Size = settings.blurSize, Duration = settings.reducedMotion and 0.05 or settings.animationDuration })
		self:Connect(self, self._gui:GetPropertyChangedSignal("AbsoluteSize"), function() self:_layout() end)
		self:Connect(self, self._gui.Destroying, function() self:Destroy() end)
		self:Connect(self, Input.WindowFocusReleased, function() self:CancelInput() end)
		self:Connect(self, Input.InputBegan, function(input, processed)
			if processed or Input:GetFocusedTextBox() then return end
			if self._capture then
				local bind = self._capture
				self._capture = nil
				if input.KeyCode ~= Enum.KeyCode.Escape then
					local success = pcall(bind.Set, bind, input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode or input.UserInputType)
					if not success then bind:_display() end
				else bind:_display() end
				return
			end
			if input.KeyCode == Enum.KeyCode.Escape and self._popup and self._popup.dismissable then self._popup:Close(); return end
			if input.KeyCode == self._settings.toggleKey then self:Toggle(); return end
			if self._popup then return end
			for _, bind in self._keybinds do
				if not bind._dead and not bind._locked and (input.KeyCode == bind.value or input.UserInputType == bind.value) then
					if bind._props.mode == "hold" then bind._held = true; self:Call(bind._props.callback, true)
					elseif bind._props.mode == "toggle" then bind._toggled = not bind._toggled; self:Call(bind._props.callback, bind._toggled)
					else self:Call(bind._props.callback) end
				end
			end
		end)
		self:Connect(self, Input.InputChanged, function(input)
			local drag = self._drag
			if drag and self:CanUse(drag.owner) and (input == drag.touch or (not drag.touch and input.UserInputType == Enum.UserInputType.MouseMovement)) then
				drag.update(input.Position)
			end
		end)
		self:Connect(self, Input.InputEnded, function(input)
			local drag = self._drag
			if drag and (input == drag.touch or input.UserInputType == Enum.UserInputType.MouseButton1) then self._drag = nil end
			for _, bind in self._keybinds do
				if bind._held and (input.KeyCode == bind.value or input.UserInputType == bind.value) then
					bind._held = false; self:Call(bind._props.callback, false)
				end
			end
		end)
		self:_layout()
		if settings.visible then self:Show() end
	end)
	if not ok then self:Destroy(); error("Evolia: cannot build radial UI: " .. tostring(problem), 2) end
	return self
end
return Radial
