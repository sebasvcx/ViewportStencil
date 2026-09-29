--!strict
--[[
	Stencil

	A model rendered "inside" a surface: a ViewportFrame on an invisible part's Top face shows the model as if the
	surface were a window into it. Nothing is actually cut, so it works on any part, terrain or mesh, and costs nothing
	physically.

	The stencil's CFrame is a point on the surface, with its UpVector pointing out of the surface (the surface normal).
	The model is placed so its top sits flush with that point, with its "up" (its PrimaryPart's UpVector, or world up
	if it has no PrimaryPart) along the normal. This works for floors, walls and ceilings alike.
]]

local RunService = game:GetService("RunService")

local Projection = require(script.Parent.Projection)
local Renderer = require(script.Parent.Renderer)
local RigPool = require(script.Parent.RigPool)
local Types = require(script.Parent.Types)

type Rig = RigPool.Rig
type FrameState = Renderer.FrameState
type StencilOptions = Types.StencilOptions

-- How far above the stencil CFrame the surface is drawn, so it doesn't z-fight with the real surface.
local SURFACE_OFFSET = 0.075
-- Overlapping stencils would z-fight with each other if their surfaces were coplanar, so each new stencil is lifted by
-- a tiny extra amount, cycling through LAYER_COUNT layers.
local LAYER_STEP = 0.002
local LAYER_COUNT = 8

local DEFAULT_MAX_DISTANCE = 1000
local DEFAULT_AMBIENT = Color3.new(1, 1, 1)
local DEFAULT_LIGHT_COLOR = Color3.fromRGB(140, 140, 140)
local DEFAULT_LIGHT_DIRECTION = Vector3.new(-1, -1, -1)

local layerCounter = 0

local Stencil = {}
Stencil.__index = Stencil

type StencilData = {
	-- The model rendered inside the surface. Owned by the stencil: don't reparent it.
	model: Model,

	_rig: Rig,
	_cframe: CFrame,
	_size: Vector2,
	_modelOffset: CFrame,
	_layerOffset: number,
	_transparency: number,
	_maxDistance: number,
	_destroyModel: boolean,
	_destroyed: boolean,
	_lifetimeThread: thread?,

	-- Cached from the part, recomputed whenever the CFrame or size change
	_surfaceCFrame: CFrame,
	_surfaceSize: Vector2,
	_viewRotation: CFrame,
	-- Bounding sphere of the surface, for culling
	_center: Vector3,
	_radius: number,

	-- Last values written to the rig, to avoid redundant property writes
	_canvasHeight: number,
	_visible: boolean,
	-- The stencil changed since its last render, so it must update even if the camera didn't move
	_dirty: boolean,
}

export type Stencil = typeof(setmetatable({} :: StencilData, Stencil))

--[[
	Offset from the stencil CFrame to the model's pivot, such that the top of the model is flush with the surface.
	Uses the PrimaryPart's top face if there is one, otherwise the top of the bounding box.
]]
local function getModelOffset(model: Model): CFrame
	local topCFrame
	local primary = model.PrimaryPart
	if primary then
		topCFrame = primary.CFrame * CFrame.new(0, primary.Size.Y / 2, 0)
	else
		local boxCFrame, boxSize = model:GetBoundingBox()
		topCFrame = boxCFrame * CFrame.new(0, boxSize.Y / 2, 0)
	end
	return topCFrame:ToObjectSpace(model:GetPivot())
end

--[[
	Smallest surface size, centered on the stencil CFrame, that contains the model's whole footprint.
]]
local function getModelFootprint(model: Model, modelOffset: CFrame): Vector2
	local boxCFrame, boxSize = model:GetBoundingBox()
	-- Where the box center ends up relative to the stencil CFrame
	local stencilCFrame = model:GetPivot() * modelOffset:Inverse()
	local center = stencilCFrame:PointToObjectSpace(boxCFrame.Position)
	return Vector2.new(math.abs(center.X) * 2 + boxSize.X, math.abs(center.Z) * 2 + boxSize.Z)
end

--[[
	Creates a stencil that renders `model` inside the surface at `cframe`.

	The stencil takes ownership of the model: it's parented into the stencil's viewport and, by default, destroyed
	along with it. Pass a clone if you want to keep the original.
]]
function Stencil.new(model: Model, cframe: CFrame, options: StencilOptions?): Stencil
	assert(RunService:IsClient(), "ViewportStencil can only be used on the client")
	assert(typeof(model) == "Instance" and model:IsA("Model"), "ViewportStencil.new: model must be a Model")
	assert(typeof(cframe) == "CFrame", "ViewportStencil.new: cframe must be a CFrame")
	assert(model:FindFirstChildWhichIsA("BasePart", true), "ViewportStencil.new: model has no parts")

	local opts: StencilOptions = options or {}
	local modelOffset = getModelOffset(model)

	layerCounter = (layerCounter + 1) % LAYER_COUNT

	local rig = RigPool.acquire()
	local data: StencilData = {
		model = model,

		_rig = rig,
		_cframe = cframe,
		_size = opts.size or getModelFootprint(model, modelOffset),
		_modelOffset = modelOffset,
		_layerOffset = SURFACE_OFFSET + layerCounter * LAYER_STEP,
		_transparency = opts.transparency or 0,
		_maxDistance = opts.maxDistance or DEFAULT_MAX_DISTANCE,
		_destroyModel = if opts.destroyModel == nil then true else opts.destroyModel,
		_destroyed = false,
		_lifetimeThread = nil,

		_surfaceCFrame = CFrame.identity,
		_surfaceSize = Vector2.one,
		_viewRotation = CFrame.identity,
		_center = Vector3.zero,
		_radius = 0,

		-- Pooled rigs come disabled; the first render enables it if it's in view
		_canvasHeight = -1,
		_visible = false,
		_dirty = true,
	}
	local self = setmetatable(data, Stencil)

	-- Everything a stencil can customize is set here, every time, so nothing leaks from a previous user of the rig
	local surfaceGui = rig.surfaceGui
	-- Distance culling is done by the stencil itself (so hidden stencils also skip their updates)
	surfaceGui.MaxDistance = 0
	surfaceGui.Brightness = opts.brightness or 1
	surfaceGui.LightInfluence = opts.lightInfluence or 1

	local viewport = rig.viewport
	viewport.ImageTransparency = self._transparency
	viewport.Ambient = opts.ambient or DEFAULT_AMBIENT
	viewport.LightColor = opts.lightColor or DEFAULT_LIGHT_COLOR
	viewport.LightDirection = opts.lightDirection or DEFAULT_LIGHT_DIRECTION

	model.Parent = viewport
	self:_applyTransform()
	rig.part.Parent = RigPool.getContainer()

	-- Renders right away. Luau can't match a metatable type against a table type structurally, hence the casts.
	Renderer.add(self :: any)

	local lifetime = opts.lifetime
	if lifetime then
		self._lifetimeThread = task.delay(lifetime, function()
			self._lifetimeThread = nil
			self:destroy()
		end)
	end

	return self
end

--[[
	Moves the stencil. `cframe` is a point on the surface, with its UpVector along the surface normal.
]]
function Stencil.setCFrame(self: Stencil, cframe: CFrame)
	if self:_warnIfDestroyed("setCFrame") then
		return
	end
	self._cframe = cframe
	self:_applyTransform()
end

function Stencil.getCFrame(self: Stencil): CFrame
	return self._cframe
end

--[[
	Resizes the stencil surface, in studs along the CFrame's X and Z axes. Anything of the model outside it is clipped.
]]
function Stencil.setSize(self: Stencil, size: Vector2)
	if self:_warnIfDestroyed("setSize") then
		return
	end
	self._size = size
	self:_applyTransform()
end

function Stencil.getSize(self: Stencil): Vector2
	return self._size
end

--[[
	Sets the transparency of the whole stencil, e.g. to fade it out before destroying it.
]]
function Stencil.setTransparency(self: Stencil, transparency: number)
	if self:_warnIfDestroyed("setTransparency") then
		return
	end
	self._transparency = transparency
	self._rig.viewport.ImageTransparency = transparency
end

function Stencil.getTransparency(self: Stencil): number
	return self._transparency
end

function Stencil.isDestroyed(self: Stencil): boolean
	return self._destroyed
end

--[[
	Destroys the stencil and, unless `destroyModel` was false, its model. Safe to call more than once.
]]
function Stencil.destroy(self: Stencil)
	-- Must be idempotent: releasing the rig twice would put it in the pool twice, and two future stencils would end up
	-- sharing (and stealing) the same Instances.
	if self._destroyed then
		return
	end
	self._destroyed = true

	local lifetimeThread = self._lifetimeThread
	if lifetimeThread then
		self._lifetimeThread = nil
		task.cancel(lifetimeThread)
	end

	Renderer.remove(self :: any)
	RigPool.release(self._rig)

	if self._destroyModel then
		self.model:Destroy()
	else
		self.model.Parent = nil
	end
end

-- Alias so stencils can be given to Maid, Janitor, Trove, etc.
Stencil.Destroy = Stencil.destroy

function Stencil._warnIfDestroyed(self: Stencil, method: string): boolean
	if self._destroyed then
		warn(`ViewportStencil: {method} called on a destroyed stencil`)
		return true
	end
	return false
end

--[[
	Moves the part and the model to the current CFrame/size and recomputes the cached surface.
]]
function Stencil._applyTransform(self: Stencil)
	local part = self._rig.part
	local size = self._size

	part.Size = Vector3.new(size.X, self._layerOffset * 2, size.Y)
	part.CFrame = self._cframe
	self.model:PivotTo(self._cframe * self._modelOffset)

	local surfaceCFrame, surfaceSize = Projection.getSurface(part.CFrame, part.Size)
	self._surfaceCFrame = surfaceCFrame
	self._surfaceSize = surfaceSize
	self._viewRotation = Projection.getViewRotation(surfaceCFrame)
	self._center = surfaceCFrame.Position
	self._radius = surfaceSize.Magnitude / 2

	-- Force a full update (including the canvas size) on the next render
	self._canvasHeight = -1
	self._dirty = true
end

--[[
	Whether the surface's bounding sphere is inside the camera frustum and within `maxDistance`.
]]
function Stencil._isInView(self: Stencil, frame: FrameState): boolean
	local center = frame.cameraCFrame:PointToObjectSpace(self._center)
	local radius = self._radius

	if center.Magnitude - radius > self._maxDistance then
		return false
	end

	-- The camera looks along -Z. Each side plane passes through the camera, so the sphere is outside a plane when its
	-- center is more than `radius` away from it; `sec` converts that distance to an offset along X/Y.
	local depth = -center.Z
	return depth > -radius
		and math.abs(center.X) <= depth * frame.tanX + radius * frame.secX
		and math.abs(center.Y) <= depth * frame.tanY + radius * frame.secY
end

--[[
	Called by the Renderer once per frame.
]]
function Stencil._render(self: Stencil, frame: FrameState)
	-- Neither the camera nor the stencil changed: last frame's layout (or hidden state) is still correct
	if not (frame.changed or self._dirty) then
		return
	end
	self._dirty = false

	local rig = self._rig
	local cameraPosition = frame.cameraPosition
	local surfaceSize = self._surfaceSize

	local visible = self:_isInView(frame)
	local offsetX, offsetY, scale, fov, factor, distance = 0, 0, 1, 1, 1, 0
	if visible then
		offsetX, offsetY, scale, fov, factor, distance = Projection.solve(cameraPosition, self._surfaceCFrame, surfaceSize)
		-- Seen from behind (e.g. the camera is under the floor) the projection is meaningless, so just hide it
		visible = distance > 0
	end

	-- Disabling the SurfaceGui also stops its ViewportFrame from rendering, which is where most of the cost is
	if visible ~= self._visible then
		self._visible = visible
		rig.surfaceGui.Enabled = visible
	end
	if not visible then
		return
	end

	local viewportHeight = frame.viewportHeight
	if viewportHeight ~= self._canvasHeight then
		self._canvasHeight = viewportHeight
		rig.surfaceGui.CanvasSize = Vector2.new(viewportHeight * surfaceSize.X / surfaceSize.Y, viewportHeight)
	end

	rig.viewport.Position = UDim2.fromScale(0.5 - offsetX, 0.5 - offsetY)
	rig.viewport.Size = UDim2.fromScale(scale, scale)
	rig.camera.FieldOfView = fov
	rig.camera.CFrame = Projection.getCameraCFrame(cameraPosition, self._viewRotation, factor)
end

return Stencil
