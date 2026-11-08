# Evolia

[![Luau checks](https://github.com/T1REI/Evolia/actions/workflows/ci.yml/badge.svg)](https://github.com/T1REI/Evolia/actions/workflows/ci.yml)

A collection of reusable Roblox client modules by **T1REI**. Currently contains the standalone Acrylic module.

## Acrylic

```lua
local Acrylic = loadstring(game:HttpGet("https://raw.githubusercontent.com/T1REI/Evolia/main/modules/ui/acrylic.lua"))()
local Glass = Acrylic.attach(myFrame, { CornerRadius = "auto" })
```

The client environment must provide `loadstring` and `game:HttpGet`. Apply the effect to an existing GuiObject inside a ScreenGui. The module also supports native animated fullscreen blur. See the [Acrylic reference](docs/acrylic.md) and [standalone example](examples/acrylic.lua).

## Branches

- `main` contains approved versions. Future releases are published here only after the owner's explicit approval.
- `Preview` is reserved for test versions. It starts with an empty file tree.

## Development

Install Python 3 and the official [Luau CLI](https://github.com/luau-lang/luau/releases), then run:

```sh
python tests/run.py --luau /path/to/luau
luau-compile --null modules/ui/acrylic.lua examples/acrylic.lua
```

Checks execute the real module against a simulated Roblox API. Real-client rendering still requires validation in Roblox.

## License

[MIT](LICENSE) · Copyright © 2026 T1REI
