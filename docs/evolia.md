# Evolia UI library

Evolia is built incrementally. This stage displays six pastel-blue Acrylic squares in a compact, centered 3 × 2 grid over animated fullscreen background blur. There are no labels, buttons, or tabs yet.

## Load and create

```lua
local Evolia = loadstring(game:HttpGet("https://raw.githubusercontent.com/T1REI/Evolia/main/evolia.lua"))()
local Window = Evolia:CreateWindow({
    name = "Evolia",
    toggleKey = "RightShift",
})
```

The client environment must expose `loadstring` and `game:HttpGet`. `CreateWindow` downloads [`modules/ui/acrylic.lua`](../modules/ui/acrylic.lua), creates the UI, and returns its handle. Loading the library alone creates nothing. The interface starts hidden; press Right Shift to reveal it, then press again to hide it.

The API follows [Rayfield Gen2's](https://docs.sirius.menu/rayfield-gen2/windows) options-table and returned-handle conventions. This is an Evolia API, not a compatibility layer for Rayfield scripts. Both camelCase and PascalCase option names work, such as `toggleKey` and `ToggleKey`. Supplying both spellings of one option is an error.

## Settings

```lua
local Window = Evolia:CreateWindow({
    name = "Evolia",
    toggleKey = Enum.KeyCode.RightShift,
    blurSize = 24,
    animationDuration = 0.7,
    tileSize = 96,
    tileGap = 12,
    tileColor = Color3.fromRGB(186, 219, 248),
    tileTransparency = 0.42,
    cornerRadius = 6,
})
```

| Option | Default | Values |
| --- | --- | --- |
| `name` | `"Evolia"` | Nonempty string, up to 128 bytes. Names the ScreenGui; adds no visible title. |
| `toggleKey` | `Enum.KeyCode.RightShift` | KeyCode or exact name, such as `"F4"`; Unknown is rejected. |
| `blurSize` | `24` | Fullscreen blur radius, `0..56`. |
| `animationDuration` | `0.7` | Response time, `0.05..10` seconds. |
| `tileSize` | `96` | Square side, `48..180` UI pixels before responsive scaling. |
| `tileGap` | `12` | Gap between squares, `4..48` UI pixels before scaling. |
| `tileColor` | `Color3.fromRGB(186, 219, 248)` | Tile tint. |
| `tileTransparency` | `0.42` | Tint transparency at rest, `0..1`. |
| `cornerRadius` | `6` | Corner radius, `0..24` UI pixels before scaling. |

The default grid measures 312 × 204 UI pixels. It remains centered on the full viewport and shrinks proportionally when needed to fit within 52% of viewport width and 42% of height. Squares stay square, gaps scale consistently, and the grid never grows beyond its configured size.

## Visibility and key binding

```lua
Window:SetToggleKey("F4")
Window:SetToggleKey(Enum.KeyCode.LeftAlt)
local key = Window:GetToggleKey()

Window:Show()
Window:Hide()
Window:Toggle()
Window:SetVisible(true)
local requestedVisible = Window:IsVisible()

Window:Destroy()
```

Changing the key takes effect immediately, including during animation, and does not recreate the UI. Input already consumed by the game and input while a text box is focused are ignored. `GetToggleKey` returns an Enum.KeyCode even when configured with a string.

Setters and visibility methods return the handle for chaining. `IsVisible` reports the requested destination during animation. `Destroy` immediately removes the GUI, panel masks, fullscreen blur, and all associated connections. It is safe to repeat; a destroyed handle cannot be shown again. Destroying the ScreenGui externally also cleans up its window.

The reveal combines tint and border opacity, a 12-pixel upward movement, and a scale from 94% to 100%. A small variation in response speed gives the six squares a gentle sequence. The fullscreen blur and tile transitions use analytically integrated critically damped springs. Reversals retain current amount and velocity. Duration controls response speed rather than a fixed deadline. Animation callbacks disconnect after settling; active panel masks continue to track the camera.

## Existing Init API

```lua
Evolia:Init({ ToggleKey = Enum.KeyCode.RightShift })
Evolia:SetVisible(true)
Evolia:SetToggleKey("F4")
Evolia:Toggle()
Evolia:Destroy()
```

`Init` remains a shortcut for creating the current window and returns Evolia. Evolia's visibility and key methods forward to that current window. New code should retain the handle returned by `CreateWindow`.

Only one Evolia window is active at a time. Creating another window or loading and initializing another library instance destroys the previous runtime. Discovery uses the executor's shared `getgenv` environment when available, and the script environment otherwise. Independent script environments cannot discover each other's runtimes. A library instance caches its Acrylic API.

## Rendering

Each square uses the existing Acrylic module's camera-aligned Glass geometry and shared DepthOfFieldEffect. The tint remains translucent so the scene can show through. While panel Acrylic is visible, its controller temporarily suspends competing DepthOfFieldEffects and restores them when hidden or destroyed. Fullscreen blur uses an independent native BlurEffect; other BlurEffects remain untouched.

These effects process the 3D scene. They do not blur other ScreenGui content or the desktop. Graphics quality affects the result, and another stronger BlurEffect can keep the world blurred after Evolia closes. The panel blur halo is estimated because Roblox does not expose its kernel radius. Local mock tests validate layout, geometry, animation behavior, and cleanup; they do not establish pixel-perfect GPU rendering or subjective animation quality in a real client.
