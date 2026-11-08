# Evolia UI library

Evolia is being built incrementally. This stage provides only fullscreen background blur controlled by Right Shift. It creates no GUI objects, glass geometry, windows, buttons, or color overlays.

## Load and initialize

```lua
local Evolia = loadstring(game:HttpGet("https://raw.githubusercontent.com/T1REI/Evolia/main/evolia.lua"))()
Evolia:Init()
```

The client environment must expose `loadstring` and `game:HttpGet`. `Init` downloads [`modules/ui/acrylic.lua`](../modules/ui/acrylic.lua); Evolia uses its fullscreen effect controller. Loading the library alone does not start the UI. Blur begins disabled.

Right Shift opens the blur; the next press closes it. Input already consumed by the game and input while a text box is focused are ignored. Pressing the key during a transition changes its destination while preserving its current amount and velocity.

## Settings

```lua
Evolia:Init({
    ToggleKey = Enum.KeyCode.RightShift,
    BlurSize = 24,
    AnimationDuration = 0.7,
})
```

| Option | Default | Values |
| --- | --- | --- |
| `ToggleKey` | `Enum.KeyCode.RightShift` | A KeyCode other than Unknown. |
| `BlurSize` | `24` | Blur radius, `0..56`. |
| `AnimationDuration` | `0.7` | Response time in seconds, `0.05..10`. |

The animation uses a critically damped response with an analytical time step. It eases in and settles without a bounce. Duration controls response speed rather than a fixed tween deadline; the final tiny remainder is snapped only when both amount and velocity are negligible. Rendering callbacks disconnect after settling, including while open.

## API

```lua
Evolia:SetVisible(true)
Evolia:SetVisible(false)
Evolia:Toggle()

local requestedVisible = Evolia:IsVisible()

Evolia:Destroy()
```

`Init`, `SetVisible`, and `Toggle` return Evolia. `IsVisible` reports the requested destination, including during animation. `Destroy` immediately removes the blur and disconnects input and animation; it is safe to repeat. Reinitialization starts hidden and removes the previous runtime.

Only one initialized Evolia runtime is kept in the executor's shared environment, using `getgenv` when available and the current script environment otherwise. Independent script environments cannot discover each other's runtimes. `Init` caches its loaded Acrylic API; reloading the outer library downloads it again on initialization.

## Scope and rendering

Fullscreen blur is provided by a native `BlurEffect` in Lighting. Local panel Acrylic remains a separate `Glass` + DOF operation in the same module. Evolia does not suspend other effects or change Lighting settings. Another BlurEffect with a larger size can keep the scene blurred even after Evolia is hidden: Roblox renders the strongest active blur.

This affects the rendered 3D world. It does not blur other ScreenGui content or the desktop. Output depends on graphics quality. See [Roblox BlurEffect](https://create.roblox.com/docs/reference/engine/classes/BlurEffect) for engine behavior.
