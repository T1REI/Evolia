local function advance(seconds, fps)
    stepFrames(math.floor(seconds * (fps or 60) + 0.5), 1 / (fps or 60))
end
local function press(key, processed, userType)
    input.InputBegan:Fire({ KeyCode = key or Enum.KeyCode.RightShift, UserInputType = userType or Enum.UserInputType.Keyboard }, processed or false)
end
local function blur()
    for _, object in lighting:GetChildren() do if object:IsA("BlurEffect") then return object end end
end
local Evolia = loadEvolia()
assert(requests == 0 and #playerGui:GetChildren() == 0)
assert(not pcall(Evolia.CreateWindow, Evolia, { diameter = 20 }))
assert(#playerGui:GetChildren() == 0)
local window = Evolia:CreateWindow({ name = "Test", subtitle = "Radial interface" })
assert(requests == 3 and not window:IsVisible())
assert(not window._root.Visible and blur().Size == 0)
assert(window._circle:FindFirstChildOfClass("UICorner").CornerRadius.Scale == 0.5)
assert(not window._root:FindFirstChild("Tile1"), "legacy squares remain")
local home = window:CreateTab({ name = "Home" })
local calls = {}
local button = home:CreateButton({ name = "Action", callback = function() table.insert(calls, "button") end })
local toggle = home:CreateToggle({ name = "Enabled", flag = "Enabled", value = false, callback = function(v) table.insert(calls, v) end })
local slider = home:CreateSlider({ name = "Amount", range = { 10, 20 }, increment = 0.5, value = 13 })
local dropdown = home:CreateDropdown({ name = "Choice", options = { "One", "Two", "Three" }, value = "One" })
local multi = home:CreateDropdown({ name = "Multiple", options = { "A", "B" }, multiSelect = true, value = { "A" } })
local field = home:CreateInput({ name = "Text input", value = "hello" })
local fired, changed = 0, 0
local keybind = home:CreateKeybind({ name = "Hotkey", value = "T", callback = function() fired += 1 end, onChanged = function() changed += 1 end })
local picker = home:CreateColorPicker({ name = "Color", color = "#339966", alpha = 0.5 })
local stat = home:CreateStat({ name = "Count", value = 7, decimals = 1 })
local progress = home:CreateProgress({ name = "Progress", range = { 0, 100 }, value = 40 })
local console = home:CreateConsole({ name = "Log", maxLines = 3, text = "start", follow = true })
local text = home:CreateText({ name = "Title", content = "Body" })
local label = home:CreateLabel({ name = "Label" })
local paragraph = home:CreateParagraph({ name = "Paragraph", content = "Description" })
local divider = home:CreateDivider({ name = "Details" })
local section = home:CreateSection({ name = "Section" })
local row = home:CreateGroup({ direction = "row" })
local left = row:CreateGroup({ direction = "column" })
local right = row:CreateGroup({ direction = "column" })
left:CreateButton({ name = "Left" })
right:CreateToggle({ name = "Right" })
assert(label:Get() == "Label" and paragraph:Get() == "Description")
assert(window:Get("Enabled") == false and window.Flags.Enabled == false)
assert(not window:Set("missing", 1))
assert(not pcall(home.CreateToggle, home, { name = "Duplicate", flag = "Enabled" }))
local oldCount = #home._elements
assert(not pcall(home.CreateToggle, home, { name = "Bad", value = "bad" }))
assert(#home._elements == oldCount, "failed control creation leaked element")
assert(not pcall(home.CreateSlider, home, { range = { 5, 2 } }))
assert(not pcall(home.CreateDropdown, home, { options = { "A", "A" } }))
assert(not pcall(picker.SetAlpha, picker, 2))
assert(not pcall(toggle.Set, toggle, "bad"))
assert(not pcall(window.SetOptions, window, { theme = { wrong = Color3.new() } }))

press(nil, true); assert(not window:IsVisible())
input.FocusedTextBox = true; press(); assert(not window:IsVisible()); input.FocusedTextBox = nil
press(); assert(window:IsVisible())
advance(0.2)
assert(window._amount > 0 and window._amount < 1 and blur().Size > 0)
local before = window._amount
press(); assert(window._amount == before and not window:IsVisible())
advance(2)
assert(window._amount == 0 and not window._root.Visible and blur().Size == 0)
assert(initial.Enabled and not initiallyOff.Enabled)
window:Show(); advance(2)
assert(window._amount == 1 and window._glass:GetStatus() == "visible")
button._action.Activated:Fire(); assert(calls[#calls] == "button")
button:Lock(); button._action.Activated:Fire(); assert(calls[#calls] == "button")
button:Unlock()
toggle._switch.Activated:Fire(); assert(toggle:Get() and calls[#calls] == true)
local priorCalls = #calls
toggle:Set(false, true); assert(#calls == priorCalls and window.Flags.Enabled == false)
window.Flags.Enabled = true; assert(toggle:Get())
toggle:Lock("Unavailable"); toggle._switch.Activated:Fire(); assert(toggle:Get())
priorCalls = #calls; toggle:Set(false); assert(#calls == priorCalls and not toggle:Get())
toggle:Unlock(); assert(not toggle:IsLocked())
slider:Set(99); assert(slider:Get() == 20)
slider:Set(11.26); assert(slider:Get() == 11.5)
local track = slider._track
local point = track.AbsolutePosition + coreInset + vector(track.AbsoluteSize.X * 0.7, 0)
track.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = point })
assert(slider:Get() == 17 and window._drag)
input.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 }); assert(not window._drag)
local touch = { UserInputType = Enum.UserInputType.Touch, Position = point }
track.InputBegan:Fire(touch); assert(window._drag.touch == touch)
input.WindowFocusReleased:Fire(); assert(not window._drag)
field._input.Text = "edited"; field._input.FocusLost:Fire(); assert(field:Get() == "edited")
field:Lock(); field._input.Text = "blocked"; field._input.FocusLost:Fire(); assert(field:Get() == "edited")
field:Unlock()
dropdown._action.Activated:Fire(); assert(dropdown._expanded)
dropdown._search.Text = "tw"
assert(dropdown._optionButtons.Two.Visible and not dropdown._optionButtons.One.Visible)
dropdown._optionButtons.Two.Activated:Fire(); assert(dropdown:Get()[1] == "Two" and not dropdown._expanded)
local selected = dropdown:Get(); selected[1] = "One"; assert(dropdown:Get()[1] == "Two")
dropdown:Refresh({ "One", "Three" }); assert(#dropdown:Get() == 0)
dropdown:Add("Four"); dropdown:Set("Four"); dropdown:RemoveOption("Four"); assert(#dropdown:Get() == 0)
multi._optionButtons.B.Activated:Fire(); assert(#multi:Get() == 2)
keybind._action.Activated:Fire(); assert(window._capture == keybind)
press(Enum.KeyCode.F4); assert(keybind:Get() == Enum.KeyCode.F4 and changed == 1 and fired == 0,
    "key capture: "..tostring(keybind:Get().Name).." changed="..changed.." fired="..fired)
press(Enum.KeyCode.F4); assert(fired == 1)
keybind:Lock(); press(Enum.KeyCode.F4); assert(fired == 1); keybind:Unlock()
window:SetToggleKey("LeftAlt"); press(); assert(window:IsVisible())
press(Enum.KeyCode.LeftAlt); advance(2); assert(not window:IsVisible())
window:Show(); advance(2)
picker._swatch.Activated:Fire(); assert(picker._expanded)
picker._hex.Text = "#FF8800"; picker._hex.FocusLost:Fire(); assert(picker:Get():ToHex() == "FF8800")
picker._alphaText.Text = "0.3"; picker._alphaText.FocusLost:Fire(); assert(picker.alpha == 0.3)
picker:Set("#112233", true); picker:SetAlpha(0.7, true)
assert(picker:Get():ToHex() == "112233" and picker.alpha == 0.7)
picker:Set("#FFFFFF")
local huePoint = picker._hue.AbsolutePosition + coreInset + vector(5, picker._hue.AbsoluteSize.Y * .5)
picker._hue.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = huePoint })
assert(math.abs(picker._hsv[1]-.5)<0.000001, "hue selection lost on white")
local mapPoint = picker._map.AbsolutePosition + coreInset + vector(picker._map.AbsoluteSize.X*.8,picker._map.AbsoluteSize.Y*.2)
picker._map.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = mapPoint })
assert(picker:Get().G > picker:Get().R and picker:Get().B > picker:Get().R, "color map ignored selected hue")
input.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
console:Append("one\ntwo\nthree"); assert(console:Get() == "one\ntwo\nthree")
assert(console:Copy() == false); console:Clear(); assert(console:Get() == "")
stat:Set(42); progress:Set(150); assert(progress:Get() == 100)
text:Set("New body"); assert(text._content.Text == "New body")
button:Update({ name = "Renamed", description = "Hint", style = { cornerRadius = 4 } })
assert(button._label.Text == "Renamed" and button._corner.CornerRadius.Offset == 4)
slider:Update({ range={0,5},increment=.25,suffix=" units" }); assert(slider:Get()==5)
local snapshot=slider:GetOptions(); snapshot.range[1]=-99; assert(slider:GetOptions().range[1]==0)
button:Update({style={backgroundColor="#FF0000"}}); window:ChangeTheme("dark"); advance(1)
assert(button._row.BackgroundColor3 == Color3.new(1,0,0), "theme overwrote local style")
button:Update({style={}}); advance(1); assert(button._row.BackgroundColor3==window:GetTheme().surface)
button:MoveToBottom(); assert(home._elements[#home._elements] == button)
button:MoveToTop(); assert(home._elements[1] == button)
button:SetVisible(false); assert(not button:GetInstance().Visible); button:SetVisible(true)

for index = 2, 11 do window:CreateTab({ name = "Tab " .. index }) end
assert(#window._tabs == 11 and window._next.Visible)
local function orbitCheck()
    local shown = 0
    local orbit = window._settings.diameter / 2 + window._settings.orbitGap + window._settings.tabSize / 2
    local priorAngle
    for _, tab in window._tabs do
        if tab._node.Visible then
            shown += 1
            local p = tab._node.Position
            assert(math.abs(math.sqrt(p.X.Offset^2+p.Y.Offset^2)-orbit) < 0.000001)
            local angle = math.atan2(p.Y.Offset,p.X.Offset)
            if priorAngle then assert(math.abs(((angle-priorAngle)%(2*math.pi))-2*math.pi/math.min(window._settings.maxTabsPerPage,#window._tabs-(window._page-1)*window._settings.maxTabsPerPage))<0.000001) end
            priorAngle=angle
        end
    end
    assert(shown <= window._settings.maxTabsPerPage)
end
orbitCheck(); window._next.Activated:Fire(); assert(window._page == 2); orbitCheck()
window:Navigate("Tab 11"); assert(window._selected.name == "Tab 11" and window._page == 2)
home:Select(); assert(window._selected == home)
for _, size in { vector(320,568), vector(1920,1080), vector(568,320) } do
    view=size; workspace.CurrentCamera.ViewportSize=size
    window._gui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    local extent=window._root.Size.X.Offset*window._fit
    assert(extent<=math.min(view.X,view.Y)-window._settings.padding*2+0.0001)
    orbitCheck()
end
view=vector(1280,720); workspace.CurrentCamera.ViewportSize=view
window._gui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
window:ChangeTheme("dark"); advance(2)
assert(window._circle.BackgroundColor3 == window._theme.background)
window:SetOptions({ diameter = 500, font = Enum.Font.GothamBold, textSize = 14, rowHeight = 64 })
assert(window:GetOptions().diameter==500 and button._label.Font==Enum.Font.GothamBold)
assert(button._height==64 and field._height==86, "restyle damaged input geometry")
assert(not pcall(window.Popup,window,{options={{callback='invalid'}}}) and not window._popup)
local appearance=window:CreateSettingsTab()
assert(#appearance._elements>=10)
local settingsSlider
for _, element in appearance._elements do if element._props and element._props.name=='Diameter' then settingsSlider=element end end
settingsSlider:Set(440); assert(window:GetOptions().diameter==440)
home:Select()
local tag=window:CreateTag({ name="Beta" }); tag:Set("Ready"); tag:Destroy(); tag:Destroy()
local note=window:Notify({ title="Notification",content="Body",duration=.5 })
note.hovered=true; advance(1); assert(not note._dead)
note.hovered=false; advance(1); assert(note._dead and note._root._destroyed)
local toast=window:Toast({ title="Toast",duration=.5 }); advance(1); assert(toast._dead)
local popup=window:Popup({ title="Choose",content="Body", options={{ text="OK",callback=function() fired+=1 end }} })
assert(window._popup==popup)
priorCalls=#calls; button._action.Activated:Fire(); assert(#calls==priorCalls, "modal did not block underlying controls")
press(Enum.KeyCode.Escape); advance(1); assert(popup._dead and window._popup==nil)
local popup2=window:Popup({ dismissable=false,boxes={{title="Update",description="Details"}} })
press(Enum.KeyCode.Escape); assert(not popup2._dead)
popup2:Close(); advance(1)
local held={}
local hold=home:CreateKeybind({name="Hold",value="T",mode="hold",callback=function(v)table.insert(held,v)end})
press(Enum.KeyCode.T); input.WindowFocusReleased:Fire(); assert(held[1]==true and held[2]==false)
hold:Destroy()
window:SetOptions({ reducedMotion=true }); window:Hide(); assert(window._amount==0)
window:Show(); assert(window._amount==1)
window:Hide(); advance(1)
assert(run.RenderStepped:Count()==0, "idle animation connection retained")
local oldGui=window._gui
local other=loadEvolia()
local replacement=other:CreateWindow()
assert(oldGui._destroyed and not window:IsVisible() and #playerGui:GetChildren()==1)
assert(input.InputBegan:Count()==1 and input.InputChanged:Count()==1 and input.InputEnded:Count()==1)
replacement:Destroy(); replacement:Destroy()
assert(#playerGui:GetChildren()==0 and count(frames)==0 and run.RenderStepped:Count()==0)
assert(input.InputBegan:Count()==0 and input.InputChanged:Count()==0 and input.InputEnded:Count()==0)
assert(initial.Enabled and not initiallyOff.Enabled and not blur())
assert(not pcall(toggle.Set,toggle,true))
assert(not pcall(window.Show,window))
local external=other:CreateWindow()
external:CreateTab({name="External"}):CreateToggle({name="Enabled"})
external:Show();advance(.1)
external._gui:Destroy()
assert(not external:IsVisible() and #playerGui:GetChildren()==0 and count(frames)==0)
local samples={}
for _,fps in {30,60,144} do
    local sample=other:CreateWindow()
    local tab=sample:CreateTab({name="Sample"})
    local bar=tab:CreateProgress({name="Progress",value=0})
    sample:Show();bar:Set(100)
    advance(.5,fps)
    table.insert(samples,{sample._amount,blur().Size,bar._fill.Size.X.Scale})
    sample:Destroy()
end
for index=1,3 do
    assert(math.abs(samples[1][index]-samples[2][index])<.000001 and math.abs(samples[2][index]-samples[3][index])<.000001,
        "animation depends on frame rate")
end
local newInstance=Instance.new
local attempts=0
Instance.new=function(class)
    if class=='Frame' then attempts+=1;if attempts==2 then error('allocation failed') end end
    return newInstance(class)
end
assert(not pcall(other.CreateWindow,other))
Instance.new=newInstance
assert(#playerGui:GetChildren()==0 and count(frames)==0 and run.RenderStepped:Count()==0)
print("PASS: radial layout/pagination, all controls, callbacks/locks, mouse/touch input, key capture, customization, feedback and cleanup")
