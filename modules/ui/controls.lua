local Controls = {}
local Container = {}
Container.__index = Container
local Element = {}
Element.__index = Element
local function finite(v) return type(v) == "number" and v == v and math.abs(v) < math.huge end
local function copy(v) return typeof(v) == "table" and table.clone(v) or v end
local function alive(self) assert(not self._dead and not self._window._dead, "Evolia: handle was destroyed") end
function Controls.normalize(props)
	assert(type(props) == "table", "Evolia: expected properties")
	local result = {}
	for key, value in props do
		assert(type(key) == "string", "Evolia: property names must be strings")
		local name = key:sub(1, 1):lower() .. key:sub(2)
		assert(result[name] == nil, "Evolia: duplicate property " .. name)
		result[name] = value
	end
	return result
end
function Controls.image(value)
	assert(type(value) == "string" or type(value) == "number", "Evolia: icon must be an asset id or URI")
	return type(value) == "number" and ("rbxassetid://" .. value) or value
end
local function color(value)
	if type(value) == "string" then
		assert(value:match("^#?%x%x%x%x%x%x$"), "Evolia: expected a six-digit hex color")
		return Color3.fromHex(value:gsub("#", ""))
	end
	assert(typeof(value) == "Color3", "Evolia: expected a Color3 or hex string")
	return value
end
local function bindKey(value)
	if type(value) == "string" then
		local ok, key = pcall(function() return Enum.KeyCode[value] end)
		if not ok then ok, key = pcall(function() return Enum.UserInputType[value] end) end
		value = ok and key or nil
	end
	assert(typeof(value) == "EnumItem" and ((value.EnumType == Enum.KeyCode and value ~= Enum.KeyCode.Unknown)
		or value == Enum.UserInputType.MouseButton1 or value == Enum.UserInputType.MouseButton2
		or value == Enum.UserInputType.MouseButton3), "Evolia: invalid key or mouse binding")
	return value
end
local function validate(kind, p)
	for _, key in { "name", "description", "flag", "placeholder", "suffix", "prefix", "buttonText" } do
		assert(p[key] == nil or type(p[key]) == "string", "Evolia: " .. key .. " must be text")
	end
	for _, key in { "callback", "onChanged" } do assert(p[key] == nil or type(p[key]) == "function", "Evolia: invalid callback") end
	for _, key in { "multiSelect", "forgetState", "follow", "clearOnSubmit" } do
		assert(p[key] == nil or type(p[key]) == "boolean", "Evolia: invalid boolean " .. key)
	end
	assert(p.height == nil or finite(p.height) and p.height >= 24 and p.height <= 2000, "Evolia: invalid height")
	if kind == "Slider" or kind == "Progress" then
		p.range = p.range or { 0, p.max or 100 }
		assert(type(p.range) == "table" and finite(p.range[1]) and finite(p.range[2]) and p.range[1] < p.range[2], "Evolia: invalid range")
		p.range = table.clone(p.range)
		p.increment = p.increment or 1
		assert(finite(p.increment) and p.increment > 0, "Evolia: increment must be positive")
	end
	if kind == "Dropdown" then
		p.options = p.options or {}
		assert(type(p.options) == "table", "Evolia: options must be a list")
		local seen = {}
		for _, option in p.options do assert(type(option) == "string" and not seen[option], "Evolia: duplicate or invalid option"); seen[option] = true end
		p.options = table.clone(p.options)
	end
	if kind == "Keybind" then
		p.mode = p.mode or "press"
		assert(p.mode == "press" or p.mode == "hold" or p.mode == "toggle", "Evolia: invalid keybind mode")
	end
	if kind == "Console" then
		p.maxLines = p.maxLines or 200
		assert(finite(p.maxLines) and p.maxLines >= 1 and p.maxLines <= 10000 and p.maxLines % 1 == 0, "Evolia: invalid line limit")
	end
	assert(p.decimals == nil or finite(p.decimals) and p.decimals >= 0 and p.decimals <= 6, "Evolia: invalid precision")
	if p.style then
		assert(type(p.style) == "table", "Evolia: style must be a table")
		p.style = table.clone(p.style)
		for key, value in p.style do
			if key == "backgroundColor" or key == "textColor" or key == "accentColor" then color(value)
			elseif key == "cornerRadius" or key == "textSize" then assert(finite(value) and value >= 0 and value <= 48, "Evolia: invalid style size")
			else error("Evolia: unknown element style " .. tostring(key)) end
		end
	end
	return p
end
function Controls.container(window, parent, body)
	return setmetatable({ _window = window, _parent = parent, _body = body,
		_tab = parent and parent._tab, _elements = {}, _connections = {}, _direction = "column" }, Container)
end
function Container:_list()
	local w = self._window
	self._listLayout = w:Make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, w._settings.elementGap), FillDirection = self._direction == "row" and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical }, self._body)
	w:Make("UIPadding", { PaddingRight = UDim.new(0, 5), PaddingBottom = UDim.new(0, 6) }, self._body)
end
function Container:_reflow()
	local count = 0
	for _, element in self._elements do if element._row.Visible then count += 1 end end
	for index, element in self._elements do
		element._row.LayoutOrder = index
		local columns = self._direction == "row" and math.max(1, count) or 1
		element._row.Size = UDim2.new(1 / columns, columns > 1 and -self._window._settings.elementGap * (columns - 1) / columns or 0,
			0, element._height or 0)
	end
end
function Container:CreateGroup(props)
	alive(self)
	props = Controls.normalize(props or {})
	local direction = props.direction or "row"
	assert(direction == "row" or direction == "column", "Evolia: group direction must be row or column")
	local group = Controls.container(self._window, self)
	group._direction, group._height = direction, 0
	group._row = self._window:Make("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0) }, self._body)
	group._body = group._row
	group:_list()
	table.insert(self._elements, group); self:_reflow()
	return group
end
function Container:Destroy()
	if self._dead then return end
	self._dead = true
	for _, child in table.clone(self._elements) do child:Destroy() end
	for _, c in self._connections do c:Disconnect() end
	if self._row then self._row:Destroy() end
	if self._parent then
		local index = table.find(self._parent._elements, self)
		if index then table.remove(self._parent._elements, index); self._parent:_reflow() end
	end
end
function Container:_restyle()
	self._listLayout.Padding = UDim.new(0, self._window._settings.elementGap)
	for _, element in self._elements do element:_restyle() end
	self:_reflow()
end
function Container:GetInstance() alive(self); return self._body end

function Element:Get() alive(self); return copy(self.value) end
function Element:GetInstance() alive(self); return self._row end
function Element:IsLocked() return self._locked == true end
function Element:Lock(reason)
	alive(self); self._locked = true
	self._description.Text = reason or self._props.description or ""
	self._row.GroupTransparency = 0.45
	if self._window._drag and self._window._drag.owner == self then self._window._drag = nil end
	if self._window._capture == self then self._window._capture = nil; self:_display() end
	if self._held then self._held = false; self._window:Call(self._props.callback, false) end
	return self
end
function Element:Unlock()
	alive(self); self._locked = false; self._description.Text = self._props.description or ""
	self._row.GroupTransparency = 0; return self
end
function Element:SetVisible(visible)
	alive(self); assert(type(visible) == "boolean", "Evolia: invalid visibility")
	self._row.Visible = visible; self._parent:_reflow(); return self
end
function Element:SetName(name) alive(self); assert(type(name) == "string"); self._props.name = name; self._label.Text = name; return self end
function Element:SetDescription(text) alive(self); assert(type(text) == "string"); self._props.description = text; self._description.Text = text; return self end
function Element:MoveTo(index)
	alive(self)
	assert(finite(index) and index % 1 == 0, "Evolia: invalid element index")
	local list = self._parent._elements
	table.remove(list, table.find(list, self)); table.insert(list, math.clamp(index, 1, #list + 1), self)
	self._parent:_reflow(); return self
end
function Element:MoveToTop() return self:MoveTo(1) end
function Element:MoveToBottom() return self:MoveTo(#self._parent._elements) end
function Element:MoveUp() return self:MoveTo(table.find(self._parent._elements, self) - 1) end
function Element:MoveDown() return self:MoveTo(table.find(self._parent._elements, self) + 1) end
function Element:Destroy()
	if self._dead then return end
	self._dead = true
	local w = self._window
	if w._capture == self then w._capture = nil end
	if w._drag and w._drag.owner == self then w._drag = nil end
	if self._held then self._held = false; w:Call(self._props.callback, false) end
	if self._flag then w._flags[self._flag] = nil end
	w._motions[self] = nil
	if self._kind == "Keybind" then table.remove(w._keybinds, table.find(w._keybinds, self)) end
	for _, c in self._connections do c:Disconnect() end
	self._row:Destroy()
	local list = self._parent._elements
	local index = table.find(list, self)
	if index then table.remove(list, index); self._parent:_reflow() end
end
function Element:Remove(option)
	if option ~= nil and self._kind == "Dropdown" then return self:RemoveOption(option) end
	return self:Destroy()
end
function Element:_heightTo(height)
	self._height = height; self._parent:_reflow()
end
function Element:_restyle()
	local w, style = self._window, self._props.style or {}
	local function setStyle(object, property, token, value)
		if value ~= nil then
			w._styles[object][property] = nil; object[property] = color(value)
			if w._motions[object] then w._motions[object][property] = nil end
		elseif w._styles[object][property] == nil then
			w._styles[object][property] = token; w:Color(object, property, w._theme[token])
		end
	end
	self._label.TextSize = style.textSize or w._settings.textSize
	self._corner.CornerRadius = UDim.new(0, style.cornerRadius or w._settings.cornerRadius)
	setStyle(self._row, "BackgroundColor3", "surface", style.backgroundColor)
	setStyle(self._label, "TextColor3", "text", style.textColor)
	if self._fill then setStyle(self._fill, "BackgroundColor3", "accent", style.accentColor) end
	if not self._props.height and not self._expanded and self._kind ~= "Console" and self._kind ~= "Text" and self._kind ~= "Paragraph" then
		self._height = (self._kind == "Section" or self._kind == "Divider") and 30
			or self._kind == "Input" and 86 or self._kind == "Label" and 44 or w._settings.rowHeight
		if (self._kind == "Slider" or self._kind == "Progress") and (self._props.description or "") ~= "" then self._height += 18 end
	end
	self._parent:_reflow()
end
function Element:Update(changes)
	alive(self)
	changes = Controls.normalize(changes)
	local specific = {
		Slider = { range = true, increment = true, suffix = true }, Progress = { range = true, suffix = true },
		Stat = { prefix = true, suffix = true, decimals = true }, Console = { maxLines = true, follow = true },
		Input = { placeholder = true, clearOnSubmit = true }, Keybind = { mode = true },
		Dropdown = { placeholder = true }, Button = { buttonText = true },
	}
	for key in changes do
		assert(key == "name" or key == "description" or key == "callback" or key == "onChanged" or key == "style" or key == "height"
			or (specific[self._kind] and specific[self._kind][key]),
			"Evolia: use Set/Refresh for values; unsupported Update field " .. key)
	end
	local props = table.clone(self._props)
	for key, value in changes do props[key] = value end
	self._props = validate(self._kind, props)
	self._label.Text, self._description.Text = props.name or "", props.description or ""
	if props.height then self._height = props.height end
	if self._kind == "Button" then self._action.Text = props.buttonText or "Run" end
	if self._kind == "Input" then self._input.PlaceholderText = props.placeholder or "Type here…" end
	if self._kind == "Slider" or self._kind == "Progress" then self:Set(self.value, true)
	elseif self.value ~= nil then self:_display() end
	self:_restyle(); return self
end
function Element:GetOptions()
	alive(self)
	local props = {}
	for key, value in self._props do props[key] = copy(value) end
	if self.value ~= nil then props.value = self:Get() end
	if self.alpha ~= nil then props.alpha = self.alpha end
	return props
end

local function selection(value, p)
	if type(value) == "string" then value = { value } end
	assert(type(value) == "table", "Evolia: dropdown value must be text or a list")
	local selected, seen = {}, {}
	for _, item in value do
		assert(table.find(p.options, item), "Evolia: unknown dropdown option")
		if not seen[item] then table.insert(selected, item); seen[item] = true end
	end
	assert(p.multiSelect or #selected <= 1, "Evolia: single dropdown accepts one value")
	return selected
end
function Element:Set(value, silent)
	alive(self)
	local kind, p, w = self._kind, self._props, self._window
	if kind == "Toggle" then assert(type(value) == "boolean", "Evolia: toggle requires boolean")
	elseif kind == "Slider" or kind == "Progress" then
		assert(finite(value), "Evolia: expected finite number")
		value = math.clamp(value, p.range[1], p.range[2])
		if kind == "Slider" then value = math.clamp(p.range[1] + math.floor((value - p.range[1]) / p.increment + 0.5) * p.increment, p.range[1], p.range[2]) end
	elseif kind == "Stat" then assert(finite(value), "Evolia: expected finite number")
	elseif kind == "Dropdown" then value = selection(value, p)
	elseif kind == "Keybind" then value = bindKey(value)
	elseif kind == "ColorPicker" then value = color(value); self._hsv = { value:ToHSV() }
	elseif kind == "Input" or kind == "Console" or kind == "Text" or kind == "Label" or kind == "Paragraph" then
		assert(type(value) == "string", "Evolia: expected text")
	else error("Evolia: this element has no value") end
	local previous = self.value
	if kind == "Keybind" and self._held then self._held = false; w:Call(p.callback, false) end
	self.value = copy(value)
	self:_display(previous)
	if not silent and not self._locked then
		if kind == "Keybind" then w:Call(p.onChanged, value)
		elseif kind == "ColorPicker" then w:Call(p.callback, value, self.alpha)
		elseif kind == "Dropdown" then w:Call(p.callback, p.multiSelect and copy(value) or value[1])
		elseif kind == "Toggle" or kind == "Slider" or kind == "Input" then w:Call(p.callback, copy(value)) end
	end
	return self
end
function Element:SetAlpha(alpha, silent)
	alive(self); assert(self._kind == "ColorPicker" and finite(alpha) and alpha >= 0 and alpha <= 1, "Evolia: invalid alpha")
	self.alpha = alpha; self:_display()
	if not silent and not self._locked then self._window:Call(self._props.callback, self.value, alpha) end
	return self
end
function Element:SetHSV(h, s, v, silent)
	alive(self)
	assert(self._kind == "ColorPicker" and finite(h) and finite(s) and finite(v)
		and h >= 0 and h <= 1 and s >= 0 and s <= 1 and v >= 0 and v <= 1, "Evolia: invalid HSV")
	self:Set(Color3.fromHSV(h, s, v), true)
	self._hsv = { h, s, v }; self:_display()
	if not silent and not self._locked then self._window:Call(self._props.callback, self.value, self.alpha) end
	return self
end
function Element:Press()
	alive(self)
	if not self._locked then self._window:Call(self._props.callback) end
	return self
end
function Element:Refresh(options)
	alive(self); assert(self._kind == "Dropdown", "Evolia: Refresh is for dropdowns")
	local p = table.clone(self._props); p.options = options; validate("Dropdown", p)
	local selected = {}
	for _, item in self.value do if table.find(options, item) then table.insert(selected, item) end end
	local changed = #selected ~= #self.value
	self._props = p; self.value = selected; self:_choices(); self:_display()
	if changed and not self._locked then self._window:Call(p.callback, p.multiSelect and copy(selected) or selected[1]) end
	return self
end
function Element:Add(option)
	local options = table.clone(self._props.options); table.insert(options, option); return self:Refresh(options)
end
function Element:RemoveOption(option)
	local options = table.clone(self._props.options); local index = table.find(options, option)
	if index then table.remove(options, index) end
	return self:Refresh(options)
end
function Element:Append(line)
	alive(self); assert(self._kind == "Console" and type(line) == "string", "Evolia: Append requires console text")
	return self:Set((self.value ~= "" and self.value .. "\n" or "") .. line)
end
function Element:Clear() return self:Set("") end
function Element:Copy()
	alive(self)
	if type(setclipboard) ~= "function" then return false end
	setclipboard(self.value); return true
end
function Element:SetHeight(height) return self:Update({ height = height }) end

local function drag(element, object, update)
	local w = element._window
	local function corrected(position)
		local inset = game:GetService("GuiService"):GetGuiInset()
		update(Vector2.new(position.X - inset.X, position.Y - inset.Y))
	end
	w:Connect(element, object.InputBegan, function(input)
		if not w:CanUse(element) then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		w._drag = { owner = element, touch = input.UserInputType == Enum.UserInputType.Touch and input or nil, update = corrected }
		corrected(input.Position)
	end)
end
local function box(e, parent, props)
	local w = e._window
	local settings = { BackgroundTransparency = 0, BorderSizePixel = 0, ClearTextOnFocus = false,
		Font = w._settings.font, TextSize = w._settings.textSize, Text = "", Size = UDim2.fromOffset(90, 28) }
	for key, value in props or {} do settings[key] = value end
	local object = w:Make("TextBox", settings, parent, { BackgroundColor3 = "background", TextColor3 = "text", PlaceholderColor3 = "muted" })
	w:Round(object, UDim.new(0, 6)); return object
end
local function bar(e, parent, props)
	local w = e._window
	local settings = { BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false,
		Position = UDim2.new(0, 14, 1, -25), Size = UDim2.new(1, -28, 0, 20) }
	for k, v in props or {} do settings[k] = v end
	local track = w:Make("TextButton", settings, parent)
	local rail = w:Make("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 6) }, track, { BackgroundColor3 = "track" })
	w:Round(rail, UDim.new(0.5, 0))
	local fill = w:Make("Frame", { BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, rail, { BackgroundColor3 = "accent" })
	w:Round(fill, UDim.new(0.5, 0))
	return track, fill
end
local function display(e, previous)
	local kind, w, p = e._kind, e._window, e._props
	if kind == "Toggle" then
		w._styles[e._switch].BackgroundColor3 = e.value and "accent" or "track"
		w:Motion(e, "value", e.value and 1 or 0, previous == true and 1 or 0, function(t)
			e._knob.Position = UDim2.new(0, 3 + 16 * math.clamp(t, 0, 1), 0.5, 0)
			e._switch.BackgroundColor3 = w._theme.track:Lerp(w._theme.accent, math.clamp(t, 0, 1))
		end)
	elseif kind == "Slider" or kind == "Progress" then
		e._valueText.Text = tostring(e.value) .. (p.suffix or "")
		local ratio = (e.value - p.range[1]) / (p.range[2] - p.range[1])
		w:Motion(e, "value", ratio, type(previous) == "number" and (previous - p.range[1]) / (p.range[2] - p.range[1]) or ratio,
			function(t) e._fill.Size = UDim2.fromScale(math.clamp(t, 0, 1), 1) end)
	elseif kind == "Input" then e._input.Text = e.value
	elseif kind == "Keybind" then e._action.Text = e.value.Name
	elseif kind == "Dropdown" then
		e._action.Text = #e.value > 0 and table.concat(e.value, ", ") or p.placeholder or "Choose"
		if e._optionButtons then
			for option, object in e._optionButtons do
				w._styles[object].BackgroundColor3 = table.find(e.value, option) and "accent" or "surface"
				object.BackgroundColor3 = w._theme[w._styles[object].BackgroundColor3]
			end
		end
	elseif kind == "ColorPicker" then
		local h, s, v = unpack(e._hsv)
		e._swatch.BackgroundColor3 = e.value; e._swatch.BackgroundTransparency = 1 - e.alpha
		e._map.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		e._cursor.Position = UDim2.fromScale(s, 1 - v)
		e._hex.Text = "#" .. e.value:ToHex()
		e._alphaText.Text = string.format("%.2f", e.alpha)
	elseif kind == "Stat" then
		local from = type(previous) == "number" and previous or e.value
		w:Motion(e, "value", e.value, from, function(t)
			e._valueText.Text = (p.prefix or "") .. string.format("%." .. math.clamp(math.floor(p.decimals or 0), 0, 6) .. "f", t) .. (p.suffix or "")
		end)
		e._description.Text = previous and string.format("%+.2f", e.value - previous) or p.description or ""
	elseif kind == "Console" then
		local lines = string.split(e.value, "\n")
		while #lines > p.maxLines do table.remove(lines, 1) end
		e.value = table.concat(lines, "\n"); e._consoleText.Text = e.value
		if p.follow then e._console.CanvasPosition = Vector2.new(0, math.max(0, #lines * 17 - (e._console.AbsoluteSize.Y))) end
	else e._content.Text = e.value end
end
function Element:_display(previous) if self.value ~= nil then display(self, previous) end end
function Element:_choices()
	for _, child in self._choicesBody:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
	for _, c in self._choiceConnections or {} do
		c:Disconnect()
		local index = table.find(self._connections, c); if index then table.remove(self._connections, index) end
	end
	self._choiceConnections, self._optionButtons = {}, {}
	local query = self._search.Text:lower()
	for _, option in self._props.options do
		local button = self._window:Button(self._choicesBody, option, { Size = UDim2.new(1, -4, 0, 28) })
		button.Visible = option:lower():find(query, 1, true) ~= nil
		self._optionButtons[option] = button
		table.insert(self._choiceConnections, self._window:Connect(self, button.Activated, function()
			if not self._window:CanUse(self) then return end
			local values = self:Get()
			local found = table.find(values, option)
			if self._props.multiSelect then if found then table.remove(values, found) else table.insert(values, option) end
			else values = { option } end
			self:Set(values)
			if not self._props.multiSelect then self:_expand(false) end
		end))
	end
	self:_display()
end
function Element:_expand(open)
	self._expanded = open
	self._panel.Visible = open
	self:_heightTo(open and (self._props.height or 240) or self._window._settings.rowHeight)
end

local values = { Toggle = false, Slider = 0, Dropdown = {}, Input = "", Keybind = "T", ColorPicker = "#FFFFFF", Stat = 0, Progress = 0,
	Console = "", Text = "", Label = "", Paragraph = "" }
function Container:_create(kind, props)
	alive(self)
	local p = validate(kind, Controls.normalize(props or {}))
	local w = self._window
	local flag = p.flag or ((self._tab.name or "Tab") .. "/" .. (p.name or kind))
	if values[kind] ~= nil and not p.forgetState then assert(not w._flags[flag], "Evolia: duplicate flag " .. flag) end
	local e = setmetatable({ _window = w, _tab = self._tab, _parent = self, _props = p, _kind = kind,
		_connections = {}, _height = p.height or w._settings.rowHeight }, Element)
	local ok, problem = pcall(function()
		e._row = w:Make("CanvasGroup", { Name = kind, BackgroundTransparency = 0.1, BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, e._height) }, self._body, { BackgroundColor3 = "surface" })
		e._corner = w:Round(e._row)
		e._label = w:Text(e._row, p.name or p.title or "", { Position = UDim2.fromOffset(p.icon and 36 or 14, 9), Size = UDim2.new(0.58, -14, 0, 20) })
		e._description = w:Text(e._row, p.description or "", { Position = UDim2.fromOffset(14, 31), Size = UDim2.new(1, -28, 0, 16), TextSize = 10 }, "muted")
		if p.icon then w:Make("ImageLabel", { BackgroundTransparency = 1, Image = Controls.image(p.icon),
			Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(16, 16) }, e._row, { ImageColor3 = "text" }) end
		local function action(text)
			return w:Button(e._row, text, { Position = UDim2.new(0.6, 0, 0, 10), Size = UDim2.new(0.4, -14, 0, 30) })
		end
		if kind == "Button" then
			e._action = action(p.buttonText or "Run")
			w:Connect(e, e._action.Activated, function() if w:CanUse(e) then e:Press() end end)
		elseif kind == "Toggle" then
			e._switch = action(""); e._switch.Size = UDim2.fromOffset(40, 24); e._switch.Position = UDim2.new(1, -54, 0, 14)
			e._knob = w:Make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(18, 18), BorderSizePixel = 0,
				Position = UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1) }, e._switch)
			w:Round(e._knob, UDim.new(0.5, 0)); w:Round(e._switch, UDim.new(0.5, 0))
			w:Connect(e, e._switch.Activated, function() if w:CanUse(e) then e:Set(not e.value) end end)
		elseif kind == "Slider" or kind == "Progress" then
			e._valueText = kind == "Slider" and box(e, e._row, { Position = UDim2.new(1, -88, 0, 5), Size = UDim2.fromOffset(74, 25) })
				or w:Text(e._row, "", { Position = UDim2.new(1, -88, 0, 5), Size = UDim2.fromOffset(74, 25), TextXAlignment = Enum.TextXAlignment.Right })
			e._track, e._fill = bar(e, e._row)
			if kind == "Slider" then
				drag(e, e._track, function(pos)
					local ratio = math.clamp((pos.X - e._track.AbsolutePosition.X) / math.max(1, e._track.AbsoluteSize.X), 0, 1)
					local range = e._props.range
					e:Set(range[1] + (range[2] - range[1]) * ratio)
				end)
				w:Connect(e, e._valueText.FocusLost, function()
					if w:CanUse(e) and tonumber(e._valueText.Text) then e:Set(tonumber(e._valueText.Text)) else e:_display() end
				end)
			end
		elseif kind == "Input" then
			e._height = p.height or 86
			e._input = box(e, e._row, { Position = UDim2.fromOffset(14, 49), Size = UDim2.new(1, -28, 0, 27), PlaceholderText = p.placeholder or "Type here…" })
			w:Connect(e, e._input.FocusLost, function()
				if w:CanUse(e) then
					e:Set(e._input.Text)
					if e._props.clearOnSubmit then e._input.Text = "" end
				else e:_display() end
			end)
		elseif kind == "Keybind" then
			e._action = action("Bind")
			w:Connect(e, e._action.Activated, function()
				if w:CanUse(e) then w:CancelInput(); w._capture = e; e._action.Text = "Press a key…" end
			end)
			table.insert(w._keybinds, e)
		elseif kind == "Dropdown" then
			e._action = action(p.placeholder or "Choose")
			e._panel = w:Make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 57), Size = UDim2.new(1, -24, 1, -65), Visible = false }, e._row)
			e._search = box(e, e._panel, { PlaceholderText = "Search…", Size = UDim2.new(1, 0, 0, 27) })
			e._choicesBody = w:Make("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, 33), Size = UDim2.new(1, 0, 1, -33), CanvasSize = UDim2.fromOffset(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2 }, e._panel, { ScrollBarImageColor3 = "accent" })
			w:Make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, e._choicesBody)
			w:Connect(e, e._search:GetPropertyChangedSignal("Text"), function()
				local query = e._search.Text:lower()
				for option, object in e._optionButtons or {} do object.Visible = option:lower():find(query, 1, true) ~= nil end
			end)
			w:Connect(e, e._action.Activated, function() if w:CanUse(e) then e:_expand(not e._expanded) end end)
		elseif kind == "ColorPicker" then
			e.alpha = p.alpha == nil and 1 or p.alpha
			assert(finite(e.alpha) and e.alpha >= 0 and e.alpha <= 1, "Evolia: invalid alpha")
			e._swatch = action("")
			w._styles[e._swatch].BackgroundColor3 = nil
			e._panel = w:Make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 58), Size = UDim2.new(1, -28, 1, -66), Visible = false }, e._row)
			e._map = w:Make("TextButton", { Text = "", AutoButtonColor = false, BorderSizePixel = 0,
				Size = UDim2.new(1, -34, 0, 112) }, e._panel)
			local saturation = w:Make("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, e._map)
			w:Make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, saturation)
			local brightness = w:Make("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, saturation)
			w:Make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) }, brightness)
			e._cursor = w:Make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(7, 7), BackgroundTransparency = 1 }, e._map)
			w:Round(e._cursor, UDim.new(0.5, 0)); w:Make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }, e._cursor)
			e._hue = w:Make("TextButton", { Text = "", AutoButtonColor = false, BorderSizePixel = 0,
				Position = UDim2.new(1, -22, 0, 0), Size = UDim2.fromOffset(22, 112), BackgroundColor3 = Color3.new(1, 1, 1) }, e._panel)
			local keys = {}; for index = 0, 6 do table.insert(keys, ColorSequenceKeypoint.new(index / 6, Color3.fromHSV(index / 6, 1, 1))) end
			w:Make("UIGradient", { Color = ColorSequence.new(keys), Rotation = 90 }, e._hue)
			e._hex = box(e, e._panel, { Position = UDim2.fromOffset(0, 120), Size = UDim2.new(0.6, -4, 0, 28) })
			e._alphaText = box(e, e._panel, { Position = UDim2.new(0.6, 4, 0, 120), Size = UDim2.new(0.4, -4, 0, 28), PlaceholderText = "Alpha" })
			drag(e, e._map, function(pos)
				local h = e._hsv[1]
				local s = math.clamp((pos.X - e._map.AbsolutePosition.X) / math.max(1, e._map.AbsoluteSize.X), 0, 1)
				local v = 1 - math.clamp((pos.Y - e._map.AbsolutePosition.Y) / math.max(1, e._map.AbsoluteSize.Y), 0, 1)
				e:SetHSV(h, s, v)
			end)
			drag(e, e._hue, function(pos)
				local s, v = e._hsv[2], e._hsv[3]
				local h = math.clamp((pos.Y - e._hue.AbsolutePosition.Y) / math.max(1, e._hue.AbsoluteSize.Y), 0, 1)
				e:SetHSV(h, s, v)
			end)
			w:Connect(e, e._hex.FocusLost, function()
				if not w:CanUse(e) then e:_display(); return end
				local ok, value = pcall(color, e._hex.Text)
				if ok then e:Set(value) else e:_display() end
			end)
			w:Connect(e, e._alphaText.FocusLost, function()
				local value = tonumber(e._alphaText.Text)
				if w:CanUse(e) and finite(value) and value >= 0 and value <= 1 then e:SetAlpha(value) else e:_display() end
			end)
			w:Connect(e, e._swatch.Activated, function() if w:CanUse(e) then e:_expand(not e._expanded) end end)
		elseif kind == "Stat" then
			e._valueText = w:Text(e._row, "", { Position = UDim2.new(0.5, 0, 0, 9), Size = UDim2.new(0.5, -14, 0, 32), TextSize = 24, TextXAlignment = Enum.TextXAlignment.Right }, "accent")
		elseif kind == "Console" then
			e._height = p.height or 160
			e._console = w:Make("ScrollingFrame", { Position = UDim2.fromOffset(12, 48), Size = UDim2.new(1, -24, 1, -58),
				BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2 }, e._row,
				{ ScrollBarImageColor3 = "accent" })
			e._consoleText = w:Text(e._console, "", { Font = Enum.Font.Code, TextSize = 12, TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.None, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -5, 0, 0) })
		elseif kind == "Divider" or kind == "Section" then
			e._height = p.height or 30; e._row.BackgroundTransparency = 1
			e._label.Size = UDim2.new(1, -28, 0, 22); e._label.Position = UDim2.fromOffset(14, 4)
			e._description.Visible = false
			if kind == "Divider" then w:Make("Frame", { BorderSizePixel = 0, Position = UDim2.new(0, 14, 1, -1), Size = UDim2.new(1, -28, 0, 1) }, e._row, { BackgroundColor3 = "border" }) end
		else
			e._height = p.height or (kind == "Label" and 44 or 112)
			e._label.Size = UDim2.new(1, -28, 0, 20)
			e._content = w:Text(e._row, "", { Position = UDim2.fromOffset(14, kind == "Label" and 10 or 37),
				Size = UDim2.new(1, -28, 1, kind == "Label" and -20 or -47), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.None }, kind == "Label" and "text" or "muted")
			if kind == "Label" then e._label.Visible = false end
			e._description.Visible = false
		end
		if values[kind] ~= nil then
			local value = p.value
			if value == nil then
				if kind == "ColorPicker" then value = p.color or values[kind]
				elseif kind == "Console" or kind == "Text" or kind == "Paragraph" or kind == "Label" then
					value = p.text or p.content or p.code or (kind == "Label" and p.name) or ""
				elseif kind == "Slider" or kind == "Progress" then value = p.range[1]
				else value = copy(values[kind]) end
			end
			e:Set(value, true)
			if not p.forgetState then e._flag = flag; w._flags[flag] = e end
		end
		if kind == "Dropdown" then e:_choices() end
		table.insert(self._elements, e); self:_reflow(); e:_restyle()
	end)
	if not ok then
		for _, c in e._connections do c:Disconnect() end
		if e._flag then w._flags[e._flag] = nil end
		local index = table.find(w._keybinds, e); if index then table.remove(w._keybinds, index) end
		w._motions[e] = nil
		if e._row then e._row:Destroy() end
		error("Evolia: cannot create " .. kind .. ": " .. tostring(problem), 2)
	end
	return e
end
for _, kind in { "Button", "Toggle", "Slider", "Dropdown", "Input", "Keybind", "ColorPicker", "Stat", "Progress", "Console", "Text", "Divider", "Section", "Label", "Paragraph" } do
	Container["Create" .. kind] = function(self, props) return self:_create(kind, props) end
end
return Controls
