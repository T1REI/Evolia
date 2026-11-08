# Evolia

[![Luau checks](https://github.com/T1REI/Evolia/actions/workflows/ci.yml/badge.svg)](https://github.com/T1REI/Evolia/actions/workflows/ci.yml)

A Roblox UI library by **T1REI**, built incrementally from reusable client modules.

The current UI stage is a compact **diamond of 85 tiny white Acrylic squares**, arranged in 13 centered rows with equal sizes and gaps. Each square measures 12 × 12 UI pixels, separated by 4-pixel gaps. Rounded corners and a gentle reveal from the center accompany fullscreen background blur. Right Shift toggles the interface; the opening key is configurable. No text, buttons, or navigation are added yet.

## Modules

| Module | Path | Description |
| --- | --- | --- |
| [Acrylic](docs/acrylic.md) | [`modules/ui/acrylic.lua`](modules/ui/acrylic.lua) | Glass and depth-of-field blur attached to your existing UI. |

## Quick start

Run this in a client environment that provides `loadstring` and `game:HttpGet`:

```lua
local Evolia = loadstring(game:HttpGet("https://raw.githubusercontent.com/T1REI/Evolia/main/evolia.lua"))()
local Window = Evolia:CreateWindow({
    name = "Evolia",
    toggleKey = "RightShift",
})
```

Loading returns an API. `CreateWindow` loads the Acrylic module, starts hidden, and returns a window handle with `Show`, `Hide`, `Toggle`, `SetToggleKey`, and `Destroy`. Each new window replaces the previous Evolia runtime. Standard Roblox LocalScripts do not provide this client loading path.

Call `Window:SetToggleKey("F4")` to change the opening key at runtime.

The API follows the create-and-return-a-handle approach of [Rayfield Gen2](https://docs.sirius.menu/rayfield-gen2), with camelCase settings and PascalCase aliases. This stage does not implement Rayfield's tabs or elements. Existing `Evolia:Init({...})` calls remain supported.

See the [Evolia reference](docs/evolia.md) for settings and lifecycle methods. The standalone [Acrylic reference](docs/acrylic.md) covers panel effects and fullscreen blur. [`examples/evolia.lua`](examples/evolia.lua) runs the current UI stage; [`examples/acrylic.lua`](examples/acrylic.lua) is a separate panel demonstration.

## Layout

```text
evolia.lua
modules/
  ui/
    acrylic.lua
examples/
  evolia.lua
  acrylic.lua
docs/
  evolia.md
  acrylic.md
tests/
  evolia.spec.lua
  acrylic.spec.lua
  roblox_mock.lua
  run.py
```

`main.lua` is an ignored local playground and is not distributed.

## Development

Install Python 3 and the official [Luau CLI](https://github.com/luau-lang/luau/releases), then run:

```sh
python tests/run.py --luau /path/to/luau
luau-compile --null evolia.lua
luau-compile --null modules/ui/acrylic.lua
luau-compile --null examples/acrylic.lua
```

Tests execute the real library and module against a simulated Roblox API. They cover animation reversal, repeated input, frame-rate independence, keyboard filtering, geometry, rotation, clipping, settings, visibility, camera replacement, and cleanup. They do not validate GPU rendering or the subjective animation feel in a real client.

## License

[MIT](LICENSE) · Copyright © 2026 T1REI
