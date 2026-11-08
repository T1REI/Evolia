# Evolia circular UI

Tabs follow an orbit around a centered circular Acrylic panel. Each tab owns a scrolling page inside the circle. The orbit paginates when its tab limit is exceeded. Navigation nodes and label widths adapt to the available spacing. One window is active per shared executor environment.

## Load

```lua
local Evolia = loadstring(game:HttpGet("https://raw.githubusercontent.com/T1REI/Evolia/main/evolia.lua"))()
local Window = Evolia:CreateWindow({
    name = "Evolia",
    subtitle = "Your space. Your rhythm.",
    toggleKey = "RightShift",
    theme = "light",
    visible = true,
})
local Home = Window:CreateTab({ name = "Home" })
Window:CreateSettingsTab({ name = "Appearance" })
```

The entry point loads `acrylic.lua`, `controls.lua`, and `radial.lua` from `modules/ui/`. Loading alone creates no UI. `CreateWindow` starts hidden unless `visible = true`. Existing `Evolia:Init(options)` remains a shortcut that returns the library; new code should retain the window handle.

Properties use camelCase; PascalCase aliases also work. Supplying both spellings is an error. Window options reject unknown names. Legacy tile settings have been removed.

## Window options

All options can be changed later with `Window:SetOptions(changes)`. `GetOptions()` returns a copy. Geometry shrinks proportionally to fit the viewport with the configured screen margin; very small viewports also shrink text.

| Option | Default | Accepted values |
| --- | --- | --- |
| `name` | `"Evolia"` | Title string. |
| `subtitle` | `"A little space for everything."` | Subtitle string. |
| `toggleKey` | `Enum.KeyCode.RightShift` | KeyCode or exact name such as `"F4"`. Unknown is rejected. |
| `diameter` | `460` | Circle diameter, `300..800`. |
| `orbitGap` | `24` | Space between the circle and tab nodes, `8..100`. |
| `tabSize` | `58` | Maximum tab node diameter, `36..100`. |
| `startAngle` | `-90` | Orbit starting angle, `-360..360` degrees. |
| `maxTabsPerPage` | `8` | Integer, `3..12`. |
| `position` | `UDim2.fromScale(0.5, 0.5)` | Center position; scale components `0..1`. |
| `padding` | `28` | Viewport margin, `8..100`. |
| `backgroundTransparency` | `0.14` | Panel tint transparency, `0..1`. |
| `blurSize` | `20` | Fullscreen blur, `0..56`. |
| `acrylic` | `true` | Enable the circular Glass/DOF panel effect. |
| `animationDuration` | `0.65` | Window spring response, `0.05..5` seconds. |
| `interactionDuration` | `0.22` | Control/theme spring response, `0.05..2` seconds. |
| `reducedMotion` | `false` | Apply UI transition endpoints directly; native blur uses its shortest response. |
| `visible` | `false` | Initial or requested visibility. |
| `theme` | `"light"` | `"light"`, `"dark"`, or a partial color table. |
| `font` | `Enum.Font.Gotham` | Font enum. Console text retains its monospaced font. |
| `textSize` | `13` | Base control text size, `10..24`. |
| `cornerRadius` | `10` | Control corner radius, `0..32`; the main panel remains circular. |
| `rowHeight` | `58` | Base row height, `48..120`. Text inputs and expanded controls reserve extra height. |
| `elementGap` | `8` | Space between rows, `2..32`. |

## Theme and user customization

```lua
Window:ChangeTheme("dark")
Window:ChangeTheme({
    background = Color3.fromRGB(250, 249, 246),
    surface = Color3.fromRGB(240, 237, 230),
    text = Color3.fromRGB(38, 36, 31),
    muted = Color3.fromRGB(120, 115, 104),
    accent = Color3.fromRGB(164, 145, 105),
    border = Color3.fromRGB(220, 214, 201),
    track = Color3.fromRGB(211, 202, 184),
    danger = Color3.fromRGB(194, 94, 94),
})
Window:SetOptions({ diameter = 500, orbitGap = 32, animationDuration = 0.8 })
local colors = Window:GetTheme()
```

Partial custom palettes start from the light palette. To adjust the current palette, edit a copy returned by `GetTheme()` and pass it to `ChangeTheme`. Theme changes animate, while the UI visibility spring retains amount and velocity when reversed. Animation connections disconnect at rest; active Acrylic masks continue tracking the camera.

`CreateSettingsTab` provides live controls for light/dark theme selection, all eight palette colors, font, title/subtitle, position, diameter, orbit spacing and angle, tab size and pagination, screen margin, text size, corner radius, row height, element spacing, blur, tint opacity, animation timing, reduced motion, Acrylic, and the opening key. Its controls initialize from the settings at creation. Programmatic changes can also be applied through the window API.

## Window and tab handles

```lua
Window:Show()
Window:Hide()
Window:Toggle()
Window:SetVisible(true)
local requestedVisible = Window:IsVisible()
Window:SetToggleKey("F4")
local key = Window:GetToggleKey()

local Tab = Window:CreateTab({ name = "Tools", icon = 123456789 })
Tab:Select()
Window:Navigate("Tools")
Tab:Destroy()
Window:Destroy()
```

Tab icons accept numeric asset ids or asset URI strings. Without an icon, a node displays the first two characters of its name. The first tab selects automatically. Visibility and settings methods return their handle for chaining. Destroy is immediate and repeat-safe. Destroying the ScreenGui externally also cleans up its window. The current runtime is replaced when another window is created, including after reloading the library.

Processed keyboard input and input while a text box is focused are ignored. Capturing a binding consumes that key without also toggling the window. Escape cancels capture or closes a dismissable popup. Dragging supports mouse and touch. Hiding, navigating, focus loss, and modal opening cancel active drags and held-key states.

## Shared element API

Create elements from a tab or group with an options table. Common properties are `name`, `description`, `icon`, `height`, `callback`, and `style`. Value controls also accept `value`, `flag`, and `forgetState`. Initial values do not fire callbacks.

```lua
local Toggle = Tab:CreateToggle({ name = "Enabled", flag = "Enabled", value = false })
Toggle:Set(true)
Toggle:Set(false, true)
local value = Toggle:Get()
Toggle:Lock("Unavailable")
Toggle:Unlock()
Toggle:IsLocked()
Toggle:SetVisible(false)
Toggle:SetName("New name")
Toggle:SetDescription("A useful hint")
Toggle:Update({ name = "Enabled", style = { cornerRadius = 6 } })
local settings = Toggle:GetOptions()
Toggle:MoveTo(1)
Toggle:MoveToTop()
Toggle:MoveToBottom()
Toggle:MoveUp()
Toggle:MoveDown()
Toggle:Destroy()
```

`Set(value, true)` suppresses callbacks. Locks stop user input and callbacks; programmatic Set still updates state. Hidden rows leave the layout. Values returned by `Get` are copied when they are tables. `.value` also exposes the current value; use `Set` for writes so UI and callbacks stay synchronized. Native GUI access is available through `GetInstance()` on windows, tabs, groups, and elements for advanced customization.

Per-element `style` supports `backgroundColor`, `textColor`, `accentColor` (bar fills), `cornerRadius`, and `textSize`. Colors accept Color3 or six-digit hex strings. Per-element color overrides survive theme changes; use an empty style table to restore theme bindings. `Update` changes common presentation properties and callbacks; the element table below lists extra supported fields. Use `Set` for values and `Refresh` for dropdown choices.

## All element types

| Method | Properties and behavior |
| --- | --- |
| `CreateButton` | `buttonText`, `callback()`. `Press()` invokes the callback unless locked. Update supports `buttonText`. |
| `CreateToggle` | Boolean `value`, `callback(boolean)`. Animated thumb and color. |
| `CreateSlider` | `range = {min,max}`, positive `increment`, numeric `value`, optional `suffix`, `callback(number)`. Drag or type a number. Values clamp and snap to the increment. Update supports range, increment, suffix. |
| `CreateDropdown` | `options = {strings}`, `value`, `multiSelect`, `placeholder`. Search filters options. Get/value is always a list; the callback receives a string/nil in single mode or a copied list in multiple mode. `Refresh(options)`, `Add(option)`, `RemoveOption(option)` edit choices. Update supports placeholder. |
| `CreateInput` | Text `value`, `placeholder`, `clearOnSubmit`, `callback(text)`. Commits on focus loss. Update supports placeholder and clearOnSubmit. |
| `CreateKeybind` | KeyCode/mouse enum or name in `value`; `mode = "press"`, `"hold"`, or `"toggle"`. Click to rebind. Set calls `onChanged(key)` rather than the press callback. Hold/toggle callbacks receive a boolean. Press callbacks take no arguments. Update supports mode. |
| `CreateColorPicker` | `color` (Color3/hex), `alpha = 0..1`, `callback(color,alpha)`. Expand for saturation/value map, hue strip, hex input, and alpha input. `Set(color)`, `SetAlpha(alpha, silent?)`, `SetHSV(h,s,v,silent?)`. HSV components use `0..1`, and hue selection is retained even on white or black. |
| `CreateStat` | Numeric `value`, `prefix`, `suffix`, `decimals = 0..6`. Animated number with change delta. Update supports prefix, suffix, decimals. |
| `CreateProgress` | Numeric `value`, `range = {0,100}` by default, optional `suffix`. Read-only animated fill, driven by Set. Update supports range and suffix. |
| `CreateConsole` | `text`, `height = 160`, `maxLines = 200`, `follow`. Read-only scrollable monospaced text. `Set(text)`, `Append(text)`, `Clear()`, `Get()`, `Copy()`, `SetHeight(height)`. Copy returns false without setclipboard. Update supports maxLines and follow. |
| `CreateText` | `name`/`title`, `content`/`text`, optional height. Title and wrapped body card; Set updates the body. |
| `CreateLabel` | `text` or `name`. A single wrapped text card; Set updates its text. |
| `CreateParagraph` | `name`/`title`, `content`/`text`, optional height. Heading with wrapped body; Set updates the body. |
| `CreateDivider` | Optional name and height. A thin rule across the page. |
| `CreateSection` | Name and optional icon. A compact heading. |

Keybinds can fire while the window is hidden. They do not fire while typing, capturing another binding, locked, or under a modal popup. Value callbacks run under error protection and report failures with an Evolia warning. A console only displays text; it does not execute it.

## Groups and flags

```lua
local Row = Tab:CreateGroup({ direction = "row" })
local Left = Row:CreateGroup({ direction = "column" })
local Right = Row:CreateGroup({ direction = "column" })
Left:CreateToggle({ name = "Enabled", flag = "FeatureEnabled" })
Right:CreateButton({ name = "Apply", callback = function() end })

Window:Set("FeatureEnabled", true)
local value = Window:Get("FeatureEnabled")
Window.Flags.FeatureEnabled = false
```

Groups nest; row children share available width, column children stack. A group can create every element and another group. Destroying it destroys its children. A value element's default flag is `Tab name/Element name`; explicit flags must be unique. Set `forgetState = true` to opt out of the flag registry. Flags are session-local state. The library does not read/write configuration files or contact telemetry services.

## Feedback

```lua
local Note = Window:Notify({ title = "Ready", content = "Your changes are applied.", duration = 4 })
local Toast = Window:Toast({ title = "Saved", subtitle = "All set.", duration = 3 })
Note:Close()
Toast:Close()

local Popup = Window:Popup({
    title = "Choose an action",
    content = "Your text here.",
    dismissable = true,
    options = {
        { text = "Cancel" },
        { text = "Apply", style = "primary", callback = function() end },
    },
})
Popup:Close()
local Tag = Window:CreateTag({ name = "BETA", width = 90 })
Tag:Set("READY")
Tag:Destroy()
```

Notifications stack at bottom right; toasts stack at top center. Both have a six-card limit, click dismissal, hover-paused timers, animated appearance/disappearance, and an optional icon asset. Popups block underlying controls, support optional subtitle and a list of `{title, description}` boxes instead of content, and close after an option callback. Option styles are neutral, primary, or danger. Tags sit above the title. Destroying the window cleans up feedback and their timers.

## Rendering and validation

The circular panel uses the existing Glass + DepthOfFieldEffect Acrylic implementation; the background uses a native BlurEffect. These process the 3D scene, not other ScreenGui content or the desktop. Panel Acrylic temporarily suspends competing DOF effects and restores them when inactive. Other BlurEffects remain untouched, so a stronger scene blur can remain after hiding Evolia. Graphics quality and the renderer affect the result; the blur halo has estimated boundaries. See the [Acrylic reference](acrylic.md).

Automated checks execute the real source against a mock engine. They test state, input paths, geometry, navigation, animation transitions, customization, and resource cleanup. Real-engine rendering, automatic layout, device readability, and subjective motion feel require Roblox-client validation.
