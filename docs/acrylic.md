# Acrylic

Apply a camera-aligned Glass mask and a shared `DepthOfFieldEffect` to existing `GuiObject` instances inside `ScreenGui`. The module has no runtime library or image dependencies.

## Load once

```lua
local Acrylic = assert(loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/T1REI/Evolia/main/modules/ui/acrylic.lua"
)))()
```

This requires a client environment with `loadstring` and `game:HttpGet`. Loading returns the API without creating an effect. The first attachment starts rendering; removing the last attachment releases the shared resources. Loading several separate copies creates separate controllers, so reuse one API table.

The `main` URL tracks development. To pin a deployment, replace `main` in the URL with a commit SHA from this repository.

## Attach

```lua
local glass = Acrylic.attach(myFrame, {
    CornerRadius = "auto",
    EdgeCompensation = Vector2.new(0.8, 0),
    Padding = Vector2.zero,
    Style = true,
    TintColor = Color3.fromRGB(255, 255, 255),
    TintTransparency = 0.35,
})
```

Frames, labels, buttons, text boxes, scrolling frames, and other `GuiObject` subclasses can be targets. The target may be detached during construction and reparented later. Ancestor visibility, `ScreenGui.Enabled`, position, size, rotation, and camera changes are followed automatically.

Give the target a transparent background so the scene can show through it. Acrylic leaves the target's properties unchanged. `Style = true` adds its own tint Frame, UICorner, and UIStroke as children; destroying the handle removes only those objects. Keep content above the tint with a higher `ZIndex`. If the target has a child layout that would reposition the tint Frame, use `Style = false` and style the target yourself.

An attachment is unique per target within one loaded API. `Acrylic.get(target)` returns its existing handle. Duplicate attachment is an error.

## Per-target options

Pass any subset to `attach` or `handle:SetOptions`. Updates merge with current options. Unknown names and invalid values raise an error before changing options. `GetOptions` returns a copy.

| Option | Default | Accepted values / behavior |
| --- | --- | --- |
| `Enabled` | `true` | Boolean. Suspends this mask and its optional tint. |
| `CornerRadius` | `"auto"` | `"auto"`, a nonnegative number, or `UDim`. Auto follows the target's UICorner; without one, radius is zero. A number is a radius in screen UI units. UDim uses the smaller absolute dimension and scales its offset through ancestor UIScale objects. Clamped to half the smaller dimension. |
| `CornerSegments` | `12` | Integer `1..64`. Maximum mask part count is `1 + 2 * CornerSegments`. Higher values make curved corners more finely stepped. |
| `EdgeCompensation` | `Vector2.new(0.8, 0)` | Each axis `0..1`. Reserves space for the estimated blur halo. X affects left/right; Y affects top/bottom. The default preserves full top/bottom coverage. |
| `Padding` | `Vector2.zero` | Nonnegative inward padding per axis, in screen UI units. Added to halo compensation. |
| `DepthOffset` | `0.02` | `0.001..1` studs beyond the camera's near clipping plane. |
| `GlassColor` | Black | `Color3` for the 3D mask. |
| `GlassTransparency` | `0.98` | `0..0.999`. Must remain below one for this rendering technique. |
| `Style` | `false` | Boolean. Creates optional tint and border children. |
| `TintColor` | White | `Color3`; used when Style is enabled. |
| `TintTransparency` | `0.35` | `0..1`; used when Style is enabled. |
| `StrokeColor` | White | `Color3`; used when Style is enabled. |
| `StrokeTransparency` | `0.55` | `0..1`; used when Style is enabled. |
| `StrokeThickness` | `1` | `0..32` UI units; set to zero to remove the visible border. |

`Acrylic.Defaults` is a frozen table containing the attachment defaults.

### Edge tuning

The geometric mask is projected onto a plane at a fixed camera depth. Both faces of each thin glass slice are constrained to the target's bounds, including when the panel is away from the screen center. Rounded corners follow the intersection of the original rounded rectangle and the inward bounds.

The halo reserve is an empirical estimate, not a public Roblox kernel formula:

```text
estimatedHalo = (4 + viewportHeight * 3 / 320) * globalIntensity
reserveX = estimatedHalo * EdgeCompensation.X + Padding.X
reserveY = estimatedHalo * EdgeCompensation.Y + Padding.Y
```

If a clear strip appears, decrease that axis's compensation. If the blur spills outside, increase it. Zero compensation projects that axis to the UI edge; it does not guarantee that the DOF halo stays inside. Coordinates remain fractional to avoid added gaps and snapping during movement.

## Global rendering settings

```lua
Acrylic.configure({
    Intensity = 1,
    FocusDistance = 0,
    InFocusRadius = 0.1,
    FarIntensity = 0,
    ManageDepthOfField = true,
})

local settings = Acrylic.getConfig()
```

| Setting | Default | Behavior |
| --- | --- | --- |
| `Intensity` | `1` | Near-field intensity, `0..1`. Shared by every mask. |
| `FocusDistance` | `0` | Nonnegative camera focus distance in studs. |
| `InFocusRadius` | `0.1` | Nonnegative in-focus radius in studs. |
| `FarIntensity` | `0` | Far-field intensity, `0..1`. Nonzero values can blur the surrounding world. |
| `ManageDepthOfField` | `true` | Temporarily disables other DOF effects in Lighting and the current camera while any mask renders. Restores captured states when inactive or destroyed. |

Focus distance and in-focus radius accept `0..100000` studs. Changing them can affect the entire scene, not only the masked region. If your game manages DOF dynamically, use `ManageDepthOfField = false` and resolve interactions yourself. Blur strength is global because Roblox applies DOF to the camera render; individual masks have separate geometry and appearance settings.

## Handle methods

```lua
glass:SetOptions({ CornerRadius = 12, TintTransparency = 0.5 })
glass:SetEnabled(false)
glass:SetEnabled(true)
glass:SetTarget(anotherFrame)

local enabled = glass:IsEnabled()
local options = glass:GetOptions()
local target = glass:GetTarget()
local status, errorMessage = glass:GetStatus()

glass:Destroy()
Acrylic.destroyAll()
```

`SetOptions`, `SetEnabled`, and `SetTarget` return the handle for chaining. Retargeting keeps options, releases the old target, and follows the new one. The old target can then be destroyed independently.

Destroying a target automatically destroys its handle. `Destroy` and `destroyAll` are safe to repeat. A destroyed handle cannot be updated or retargeted. Removing one attachment leaves other attachments running; removing the last releases the render binding, mask folders, DOF effect, and shared event connections.

`IsEnabled` reports the requested state, not actual visibility. `GetStatus` reports:

| Status | Meaning |
| --- | --- |
| `visible` | Mask geometry is being submitted; this does not detect GPU effect support. |
| `disabled` | Explicitly disabled through options. |
| `hidden` | Target, ancestor, ScreenGui, or fully transparent CanvasGroup is hidden. |
| `detached` | Target is not in an attached ScreenGui. |
| `no-camera` | No current camera. |
| `empty` | Zero-sized target. |
| `clipped` | Padding or clipping leaves no drawable slices. |
| `rotated-clipping` | A rotated target or ancestor intersects an ancestor using ClipsDescendants. This combination is suspended. |
| `unsupported-container` | Target is under SurfaceGui or BillboardGui. |
| `error` | Rendering failed; the second return value contains the error. A warning is issued once. SetOptions or SetTarget can clear the error and retry. |
| `destroyed` | Handle has been cleaned up. |

## Rendering boundaries

- This blurs the 3D scene behind the UI. Other ScreenGui layers, UI text, and the desktop behind Roblox cannot be sampled or blurred by this method.
- DOF output depends on graphics quality and renderer behavior. Exact halo clipping is not available through this API. The module cannot promise a perfect pixel boundary on every device.
- Rotated targets work without clipping ancestors. Rectangular ClipsDescendants regions work for unrotated targets and ancestors. Arbitrary polygon clips, rounded ancestor clips, and per-corner radii are not supported.
- CanvasGroup transparency is followed when it reaches one. Partial CanvasGroup opacity is not a per-mask DOF fade.
- The supported camera is a standard perspective, non-VR camera. Custom projection and VR need separate validation.
- Glass rendering has engine limitations with transparent scene content and particles. Overlapping UI and 3D masks do not form a general UI compositor.
- An opaque target, image, or child can cover the effect. The module does not rewrite your UI to expose it.

Roblox references: [DepthOfFieldEffect](https://create.roblox.com/docs/reference/engine/classes/DepthOfFieldEffect), [Camera projection](https://create.roblox.com/docs/reference/engine/classes/Camera#ScreenPointToRay), [GUI coordinates](https://create.roblox.com/docs/reference/engine/classes/GuiBase2d#AbsolutePosition).
