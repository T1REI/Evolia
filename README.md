# Evolia

[![Luau checks](https://github.com/T1REI/Evolia/actions/workflows/ci.yml/badge.svg)](https://github.com/T1REI/Evolia/actions/workflows/ci.yml)

A customizable circular Roblox UI library by **T1REI**. Tabs sit on an orbit around a central Acrylic panel; controls scroll inside the circle. Soft light and dark palettes, spring animations, and live appearance settings are included.

## Quick start

```lua
local Evolia = loadstring(game:HttpGet("https://raw.githubusercontent.com/T1REI/Evolia/main/evolia.lua"))()
local Window = Evolia:CreateWindow({
    name = "My space",
    subtitle = "Make yourself at home.",
    toggleKey = "RightShift",
    theme = "light",
    visible = true,
})
local Home = Window:CreateTab({ name = "Home" })
Home:CreateToggle({ name = "Enabled", value = false, callback = function(value)
    print(value)
end })
Window:CreateSettingsTab({ name = "Appearance" })
```

The client environment must provide `loadstring` and `game:HttpGet`. The entry point loads the UI modules from this repository. Standard Roblox LocalScripts do not provide this loading path. Reinitialization removes the previous Evolia runtime. Right Shift toggles visibility; `Window:SetToggleKey("F4")` changes the key immediately.

## Elements

Buttons, toggles, sliders, searchable single/multiple dropdowns, text inputs, keyboard/mouse keybinds, HSV/hex color pickers with alpha, animated stats, progress bars, bounded consoles, text cards, labels, paragraphs, sections, and dividers. Nested row/column groups organize controls. Notifications, toasts, modal popups, and title tags complete the feedback tools.

Every value control has `Get` and `Set`, including silent updates. Handles support locking, visibility, reordering, styling, and cleanup. Window options control geometry, typography, colors, blur, Acrylic, and animation. `CreateSettingsTab` lets the user change appearance directly in the interface. State is session-local; no files are written automatically.

See the [UI reference](docs/evolia.md) for the complete API and customization options. Run [the complete demonstration](examples/evolia.lua) to explore every element. `main.lua` is the ignored local copy of that demonstration.

## Modules

| Module | Purpose |
| --- | --- |
| [`evolia.lua`](evolia.lua) | GitHub loader and runtime lifecycle. |
| [`modules/ui/radial.lua`](modules/ui/radial.lua) | Circular window, orbit navigation, animation, feedback, and appearance. |
| [`modules/ui/controls.lua`](modules/ui/controls.lua) | Elements, groups, value handling, and pointer interaction. |
| [`modules/ui/acrylic.lua`](modules/ui/acrylic.lua) | Reusable panel Glass/DOF and fullscreen blur. [Standalone reference](docs/acrylic.md). |

## Development

Install Python 3 and the official [Luau CLI](https://github.com/luau-lang/luau/releases), then run:

```sh
python tests/run.py --luau /path/to/luau
luau-compile --null evolia.lua modules/ui/acrylic.lua modules/ui/radial.lua modules/ui/controls.lua examples/evolia.lua examples/acrylic.lua
```

Tests run the real sources against a simulated Roblox API. They validate control state and callbacks, pointer/key input, orbit layout, pagination, appearance changes, animation lifecycle, modal behavior, Acrylic geometry, and cleanup. GPU rendering, engine layout, touch ergonomics, and visual animation quality still require a real Roblox client.

## License

[MIT](LICENSE) · Copyright © 2026 T1REI
