# Evolia

[![Luau checks](https://github.com/T1REI/Evolia/actions/workflows/ci.yml/badge.svg)](https://github.com/T1REI/Evolia/actions/workflows/ci.yml)

A collection of configurable Roblox client modules by **T1REI**.

Modules are distributed as standalone Lua files and loaded with `loadstring`. Each module returns an API; loading Acrylic alone creates no UI or render loop.

## Modules

| Module | Path | Description |
| --- | --- | --- |
| [Acrylic](docs/acrylic.md) | [`modules/ui/acrylic.lua`](modules/ui/acrylic.lua) | Glass and depth-of-field blur attached to your existing UI. |

## Quick start

Run this in a client environment that provides `loadstring` and `game:HttpGet`:

```lua
local Acrylic = assert(loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/T1REI/Evolia/main/modules/ui/acrylic.lua"
)))()

-- Use a GuiObject from your own ScreenGui.
local panel = game:GetService("Players").LocalPlayer.PlayerGui.MyGui.MyPanel
panel.BackgroundTransparency = 1

local glass = Acrylic.attach(panel, {
    CornerRadius = 6,
    Style = true,
    TintColor = Color3.fromRGB(255, 255, 255),
    TintTransparency = 0.35,
})

glass:SetOptions({ TintTransparency = 0.5 })
glass:SetEnabled(false)
glass:SetEnabled(true)

-- Removes the effect and its optional styling; keeps your panel.
glass:Destroy()
```

Standard Roblox LocalScripts do not provide this client loading path. The loader above is for environments that expose those functions. Reuse the returned `Acrylic` table for all panels so they share one render loop and one depth-of-field controller.

For a complete draggable white window, run [`examples/acrylic.lua`](examples/acrylic.lua). See the [Acrylic reference](docs/acrylic.md) for every option, lifecycle method, and rendering limit.

## Layout

```text
modules/
  ui/
    acrylic.lua
examples/
  acrylic.lua
docs/
  acrylic.md
tests/
  acrylic.spec.lua
  roblox_mock.lua
  run.py
```

`main.lua` is an ignored local playground and is not distributed.

## Development

Install Python 3 and the official [Luau CLI](https://github.com/luau-lang/luau/releases), then run:

```sh
python tests/run.py --luau /path/to/luau
luau-compile --null modules/ui/acrylic.lua
luau-compile --null examples/acrylic.lua
```

The tests execute the real module against a simulated Roblox API. They cover geometry, rotation, clipping, settings, multiple attachments, visibility, camera replacement, and cleanup. They do not validate GPU rendering or guarantee an identical blur boundary on every graphics setting. Check the example in a real client when changing the effect.

## License

[MIT](LICENSE) · Copyright © 2026 T1REI
