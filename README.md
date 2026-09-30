# ViewportStencil

ViewportStencil renders a model *inside* a surface in Roblox: ground cracks, holes, craters, portals or openings in
walls. No geometry is cut or destroyed. A ViewportFrame drawn on the surface displays the model with a perspective
projection that matches the player's camera, so the surface appears to open into the model from any viewing angle.

![A crack in a wall and another in the floor, both rendered with ViewportStencil](docs/images/demo.png)

## Contents

- [How it works](#how-it-works)
- [Installation](#installation)
- [Quick start](#quick-start)
- [API reference](#api-reference)
- [Making a model](#making-a-model)
- [Lighting](#lighting)
- [Performance](#performance)
- [Limitations](#limitations)
- [Example](#example)
- [Development](#development)
- [Credits](#credits)
- [License](#license)

## How it works

ViewportStencil combines two existing techniques:

- **Off-axis projection**, from [rbx-viewport-window](https://github.com/EgoMoose/rbx-viewport-window) by EgoMoose.
  An invisible part carries a SurfaceGui with a ViewportFrame. Every frame, the ViewportFrame's camera is placed at
  the player's camera position and given an off-axis projection, so the image lines up with the surface and behaves
  like a window rather than a flat picture.
- **ViewportFrame masking**, described in
  [this DevForum post](https://devforum.roblox.com/t/viewportframe-masking/2964839). Inside a ViewportFrame, faces
  whose vertex alpha has been erased are not drawn, but they still occlude the geometry behind them. Each model
  includes a flat mask plane with erased alpha around its opening. Where the mask is, the ViewportFrame is
  transparent and the real surface shows through; the rest of the model is only visible through the opening.

Because the mask is part of the mesh, every model defines its own shape. See [Making a model](#making-a-model).

## Installation

You don't need a GitHub account to download ViewportStencil. Choose one of the options below.

### Option 1: Model file (recommended)

1. Open the [latest release](https://github.com/sebasvcx/ViewportStencil/releases/latest).
2. Under **Assets**, click `ViewportStencil.rbxm` to download it.
3. In Roblox Studio, open the **Explorer** window, right-click **ReplicatedStorage** and choose
   **Insert from File...**. Select the downloaded `ViewportStencil.rbxm`.
4. Check that `ReplicatedStorage` now contains a ModuleScript named `ViewportStencil`, with the child modules
   `Projection`, `Renderer`, `RigPool`, `Stencil`, `Types` and `Utils`.

The module has to be somewhere LocalScripts can reach. `ReplicatedStorage` is the standard location.

### Option 2: Wally

If your project uses [Rojo](https://rojo.space) and [Wally](https://wally.run), add the dependency to your
`wally.toml`:

```toml
[dependencies]
ViewportStencil = "sebasvcx/viewport-stencil@1.0.1"
```

Then run `wally install`.

### Option 3: Demo place

To try it without setting anything up, download `ViewportStencil-Demo.rbxl` from the
[latest release](https://github.com/sebasvcx/ViewportStencil/releases/latest), open it in Studio and press **Play**.
See [Example](#example).

### Updating

The version is written at the top of the `ViewportStencil` ModuleScript. To update, delete the old module and insert
the new `ViewportStencil.rbxm` from the latest release, or change the version in your `wally.toml`. Check the
[release notes](https://github.com/sebasvcx/ViewportStencil/releases) for changes that may affect your code.

## Quick start

ViewportStencil runs on the client only, so it must be required from a LocalScript (for example, one in
`StarterPlayerScripts`).

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ViewportStencil = require(ReplicatedStorage.ViewportStencil)

local crack = ReplicatedStorage.Crack -- a Model prepared as described in "Making a model"

-- A CFrame on the surface under the mouse, rotated randomly around the surface normal
local cframe = ViewportStencil.Utils.fromMouse(nil, nil, math.random() * 2 * math.pi)
if cframe then
	ViewportStencil.new(crack:Clone(), cframe, { lifetime = 10 })
end
```

Two things to keep in mind:

- The stencil takes ownership of the model: it is parented into the stencil's ViewportFrame and destroyed along with
  the stencil. Always pass a clone.
- The stencil's CFrame is a point on the surface whose UpVector is the surface normal. The `Utils` functions build this
  CFrame from a raycast, so floors, walls, ceilings and slopes are all handled the same way.

## API reference

### ViewportStencil

#### `ViewportStencil.new(model: Model, cframe: CFrame, options: StencilOptions?): Stencil`

Creates a stencil that renders `model` inside the surface at `cframe`.

| Parameter | Type | Description |
| --- | --- | --- |
| `model` | `Model` | The model to render. Must contain at least one BasePart. The stencil takes ownership of it. |
| `cframe` | `CFrame` | A point on the surface. Its UpVector must point out of the surface (along the surface normal). |
| `options` | `StencilOptions?` | Optional settings. See below. |

Throws an error if called on the server, if `model` is not a Model or has no parts, or if `cframe` is not a CFrame.

**StencilOptions**

All fields are optional.

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `size` | `Vector2` | 90% of the model's footprint | Size of the stencil surface in studs, along the CFrame's X and Z axes. Anything outside it is clipped. See [In Studio](#in-studio). |
| `lifetime` | `number` | `nil` (no automatic destruction) | Seconds after which the stencil destroys itself. Destroying it earlier cancels the timer. |
| `destroyModel` | `boolean` | `true` | Whether destroying the stencil also destroys the model. When `false`, the model is unparented instead, so it can be reused. |
| `transparency` | `number` | `0` | Transparency of the whole stencil, from `0` (opaque) to `1` (invisible). Sets `ViewportFrame.ImageTransparency`. |
| `maxDistance` | `number` | `1000` | Distance from the camera, in studs, beyond which the stencil is hidden and stops updating. |
| `brightness` | `number` | `1` | `SurfaceGui.Brightness`. See [Lighting](#lighting). |
| `lightInfluence` | `number` | `1` | `SurfaceGui.LightInfluence`: how much world lighting affects the stencil. See [Lighting](#lighting). |
| `ambient` | `Color3` | `Color3.new(1, 1, 1)` | `ViewportFrame.Ambient`. |
| `lightColor` | `Color3` | `Color3.fromRGB(140, 140, 140)` | `ViewportFrame.LightColor`. |
| `lightDirection` | `Vector3` | `Vector3.new(-1, -1, -1)` | `ViewportFrame.LightDirection`: the direction the light travels, in world space. |

#### `ViewportStencil.getActive(): { Stencil }`

Returns every stencil that has not been destroyed. The returned table is a copy, so stencils can be destroyed while
iterating over it.

#### `ViewportStencil.destroyAll()`

Destroys every active stencil. Equivalent to calling `destroy()` on each stencil returned by `getActive()`.

#### Types

The module exports its types for use in typed code:

```lua
local ViewportStencil = require(ReplicatedStorage.ViewportStencil)

type Stencil = ViewportStencil.Stencil
type StencilOptions = ViewportStencil.StencilOptions
```

### Stencil

The object returned by `ViewportStencil.new`.

| Member | Description |
| --- | --- |
| `stencil.model: Model` | The model being rendered. Read-only: don't reparent or destroy it while the stencil is active. |
| `stencil:setCFrame(cframe: CFrame)` | Moves the stencil. `cframe` follows the same convention as in `new`. |
| `stencil:getCFrame(): CFrame` | Returns the stencil's current CFrame. |
| `stencil:setSize(size: Vector2)` | Resizes the stencil surface, in studs along the CFrame's X and Z axes. |
| `stencil:getSize(): Vector2` | Returns the current surface size. |
| `stencil:setTransparency(transparency: number)` | Sets the transparency of the whole stencil. Useful for fading it out before destroying it. |
| `stencil:getTransparency(): number` | Returns the current transparency. |
| `stencil:destroy()` | Destroys the stencil and, unless `destroyModel` is `false`, its model. Calling it more than once has no effect. Also available as `stencil:Destroy()`, so stencils can be given to Maid, Janitor, Trove and similar cleanup utilities. |
| `stencil:isDestroyed(): boolean` | Returns `true` once the stencil has been destroyed. |

Calling `setCFrame`, `setSize` or `setTransparency` on a destroyed stencil has no effect and prints a warning.

### ViewportStencil.Utils

Helpers that return a CFrame ready to pass to `ViewportStencil.new`: a point on a surface, with its UpVector along the
surface normal. The functions that raycast return `nil` if nothing is hit.

Common parameters:

- `angle: number?`: rotation around the surface normal, in radians. Pass `math.random() * 2 * math.pi` for a random
  rotation. Defaults to no rotation.
- `params: RaycastParams?`: raycast parameters. Defaults to excluding the local player's character.

| Function | Description |
| --- | --- |
| `fromMouse(params?, maxDistance?, angle?): CFrame?` | Raycasts from the camera through the mouse position. `maxDistance` defaults to `1000` studs. |
| `fromScreenPoint(x, y, params?, maxDistance?, angle?): CFrame?` | Raycasts from the camera through a point on the screen, in viewport coordinates (the same space as `UserInputService:GetMouseLocation()`). `maxDistance` defaults to `1000` studs. |
| `belowCharacter(character?, maxDistance?, angle?): CFrame?` | Raycasts straight down from a character's HumanoidRootPart. `character` defaults to the local player's character, and `maxDistance` to `10` studs. The character itself is always excluded. |
| `raycast(origin, direction, params?, angle?): CFrame?` | Raycasts from `origin` along `direction`. The length of `direction` is the maximum distance. |
| `fromRaycastResult(result: RaycastResult, angle?): CFrame` | Converts an existing `RaycastResult` into a stencil CFrame, using its `Position` and `Normal`. |
| `fromNormal(position: Vector3, normal: Vector3, angle?): CFrame` | Builds a stencil CFrame from a position and a surface normal. A normal of `(0, 1, 0)` gives an unrotated CFrame. |

## Making a model

A stencil model is a mesh made of two parts:

- **The mask**: a flat plane on top, with the opening cut out of it. Its vertex alpha is erased, so it is not drawn,
  but it hides the rest of the model everywhere except through the opening.
- **The visible part**: the geometry seen through the opening, such as the walls and bottom of a crack.

The steps below build a ground crack in Blender. The finished file is
[`example/crack.blend`](example/crack.blend). The
[DevForum post on ViewportFrame masking](https://devforum.roblox.com/t/viewportframe-masking/2964839) covers the
masking technique and erased-alpha vertex painting in more detail.

### In Blender

**1.** Model the mesh: a flat plane with the opening cut out, and the geometry below it.

![Initial mesh](docs/images/blender/01-initial-mesh.png)

**2.** Separate the mesh into two objects: the mask (the plane) and the visible part (everything below it). Vertex
colors are stored per vertex, so if both parts shared vertices along the edge of the opening, erasing the mask's alpha
would also fade the edges of the visible part.

![Separated mesh](docs/images/blender/02-separate-mesh.png)

To preview the erased alpha while painting, give the mesh a material with a **Color Attribute** node, connect its
**Alpha** output to the **Base Color** input of the Principled BSDF, and set the viewport shading to
**Material Preview**.

![Color Attribute node](docs/images/blender/03-color-attribute-node.png)

![Material Preview](docs/images/blender/04-material-preview.png)

**3.** Switch to **Vertex Paint** mode.

![Vertex Paint mode](docs/images/blender/05-vertex-paint-mode.png)

**4.** Set the brush's blending mode to **Erase Alpha**.

![Erase Alpha](docs/images/blender/06-erase-alpha.png)

**5.** Paint over the entire mask plane. Any area left unpainted will be visible in game.

![Painting the mask](docs/images/blender/07-paint-progress.png)

**6.** With the preview material from step 2, the finished mask appears black and the visible part stays unchanged.

![Finished mask](docs/images/blender/08-paint-finished.png)

**7.** Export both objects together as a single FBX file. They don't need to be joined in Blender. Import the FBX into
Studio as a single mesh, so both parts end up in one MeshPart.

### In Studio

Place the imported MeshPart inside a `Model` and set it as the model's `PrimaryPart`:

```
Crack (Model, PrimaryPart = Crack)
└── Crack (MeshPart)
```

The stencil positions the model as follows:

- **Height**: the top face of the `PrimaryPart` is placed flush with the surface, so the mask plane must be the highest
  point of the mesh. If the model has no `PrimaryPart`, the top of its bounding box is used.
- **Orientation**: the `PrimaryPart`'s UpVector is aligned with the surface normal. Without a `PrimaryPart`, world up
  is used.
- **Centering**: the surface is centered on the stencil's CFrame, so the opening should be centered on the mesh.

Guidelines for the surface size:

- By default the surface is 90% of the model's footprint. Keeping the mask's outer edges outside the surface prevents
  a thin line of light from appearing along them. If you set `size` yourself, keep it slightly smaller than the mask.
- Keep the mask tight around the opening. The ViewportFrame's resolution is spread over the whole surface, so a large
  mask around a small opening makes the result blurrier.

Additional parts or effects can be added to the model, as long as they stay below the mask.

## Lighting

A stencil is lit in two independent layers, and both affect its final appearance:

1. **ViewportFrame lighting.** Objects inside a ViewportFrame are not affected by the `Lighting` service or by lights
   in the world. They are lit only by the ViewportFrame's `Ambient` color and a single directional light
   (`LightColor`, `LightDirection`). This layer determines the model's shading.
2. **World lighting on the SurfaceGui.** The image produced by the ViewportFrame is displayed on a SurfaceGui, which
   is lit by the world like any other surface, scaled by `LightInfluence`. With `lightInfluence = 1`, colored lights
   near the stencil tint it. With `lightInfluence = 0`, world lighting is ignored.

`brightness` (`SurfaceGui.Brightness`) multiplies the final result, which is useful for glowing effects.

The defaults (white `ambient`, `lightInfluence = 1`) light the model evenly and let it pick up nearby lights. This
suits glowing, stylized effects, but a plain grey mesh will look flat and will take on the color of any light near it.

Example configurations:

```lua
-- Realistic hole: dark interior, lit from above, unaffected by world lights
ViewportStencil.new(model, cframe, {
	ambient = Color3.fromRGB(60, 60, 60),
	lightColor = Color3.fromRGB(200, 200, 200),
	lightDirection = Vector3.new(0, -1, 0),
	lightInfluence = 0,
})

-- Glowing crack: evenly lit and brighter than its surroundings
ViewportStencil.new(model, cframe, {
	ambient = Color3.new(1, 1, 1),
	lightInfluence = 0,
	brightness = 2,
})

-- Blended with the scene: shaded by the ViewportFrame and tinted by nearby lights
ViewportStencil.new(model, cframe, {
	ambient = Color3.fromRGB(120, 120, 120),
	lightInfluence = 1,
})
```

`lightDirection` is the direction the light travels, in world space. `(0, -1, 0)` points straight down and lights
upward-facing surfaces; the default `(-1, -1, -1)` comes diagonally from above.

The model's colors, materials and textures are rendered inside the ViewportFrame, with the ViewportFrame's usual
restrictions: no shadows, no post-processing, and Neon and Glass rendered at the lowest quality. Neon appears as a
flat, bright color; it does not glow or illuminate its surroundings.

## Performance

- Each stencil is tested every frame against the camera's view frustum, against `maxDistance`, and for whether the
  camera is in front of its surface. Stencils that fail any test have their SurfaceGui disabled, which also stops
  their ViewportFrame from rendering, and skip their per-frame update.
- When neither the camera nor a stencil has changed since the previous frame, that stencil is not updated.
- The per-frame update runs only while at least one stencil exists.
- The dominant cost is GPU rendering of each visible ViewportFrame. Keep the number of stencils visible at the same
  time reasonable, and keep the meshes simple.

## Limitations

- Client only.
- ViewportFrames are not anti-aliased, so edges can look slightly jagged.
- The stencil surface is a rectangle; the model's mask defines the visible shape.
- Overlapping stencils do not merge: the one on top covers the other.

## Example

The [latest release](https://github.com/sebasvcx/ViewportStencil/releases/latest) includes a demo place,
`ViewportStencil-Demo.rbxl`. Press **Play** and click the floor or the wall to spawn a crack, which is removed after
10 seconds.

The demo place contains:

| Instance | Description |
| --- | --- |
| `ReplicatedStorage.ViewportStencil` | The module. |
| `ReplicatedStorage.Assets.Crack.CrackTest` | The crack model from [`example/crack.blend`](example/crack.blend), set up as described in [Making a model](#making-a-model). |
| `ReplicatedStorage.Assets.Crack.VFX` | Particles and a purple PointLight spawned with each crack. The light tints nearby stencils; see [Lighting](#lighting). |
| `StarterPlayerScripts.Example` | The LocalScript that spawns the cracks: [`example/Example.client.lua`](example/Example.client.lua). |

## Development

The repository is a [Rojo](https://rojo.space) project:

| Path | Contents |
| --- | --- |
| `src/` | The module. |
| `example/` | The demo LocalScript and the Blender file for the demo crack. |
| `docs/images/` | Images used in this README. |
| `default.project.json` | The module only. Used by Wally and to build `ViewportStencil.rbxm`. |
| `dev.project.json` | A test place: syncs the module into `ReplicatedStorage.ViewportStencil` and the demo script into `StarterPlayerScripts`. |

To work on the module, run `rojo serve dev.project.json` and connect from the Rojo plugin in Studio. To build the
model file, run `rojo build default.project.json -o ViewportStencil.rbxm`.

## Credits

- [EgoMoose](https://github.com/EgoMoose), for [rbx-viewport-window](https://github.com/EgoMoose/rbx-viewport-window).
- The [ViewportFrame masking](https://devforum.roblox.com/t/viewportframe-masking/2964839) technique from the
  Roblox DevForum.

## License

ViewportStencil is released under the [MIT License](LICENSE).
