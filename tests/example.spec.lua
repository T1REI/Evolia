local runtime = environment.__EvoliaUIRuntime
assert(runtime and #runtime._tabs == 6 and runtime:IsVisible())
stepFrames(120)
local kinds = {}
local function scan(container)
	for _, element in container._elements do
		if element._kind then kinds[element._kind] = element else scan(element) end
	end
end
for _, tab in runtime._tabs do scan(tab) end
for _, kind in { "Button", "Toggle", "Slider", "Dropdown", "Input", "Keybind", "ColorPicker", "Stat", "Progress", "Console", "Text", "Label", "Paragraph", "Section", "Divider" } do
	assert(kinds[kind], "demonstration is missing " .. kind)
end
local controlsTab = runtime._tabs[2]
local demoToggle, demoSlider
for _, element in controlsTab._elements do
	if element._kind == "Toggle" then demoToggle = element end
	if element._kind == "Slider" then demoSlider = element end
end
demoToggle:Set(false)
assert(runtime:Get("Insights/Changes") == 1)
assert(runtime:Get("Insights/Activity"):find("Enabled: false", 1, true))
demoSlider:Set(70)
assert(runtime:Get("Insights/Preview level") == 70)
kinds.ColorPicker:Set("#88AA99")
stepFrames(120)
runtime:Destroy()
assert(#playerGui:GetChildren() == 0 and count(frames) == 0 and run.RenderStepped:Count() == 0)
print("PASS: published example loads every element and its cross-control callbacks work")
