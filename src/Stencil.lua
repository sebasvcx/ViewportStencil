--!strict
-- A model rendered inside a surface. The stencil's CFrame is a point on the surface with its UpVector along the
-- surface normal, so it works the same on floors, walls and ceilings.

local RunService = game:GetService("RunService")

local Projection = require(script.Parent.Projection)
local Renderer = require(script.Parent.Renderer)
local RigPool = require(script.Parent.RigPool)
local Types = require(script.Parent.Types)

type Rig = RigPool.Rig
type FrameState = Renderer.FrameState
type StencilOptions = Types.StencilOptions

-- Lifts the surface off the real one to avoid z-fighting
local SURFACE_OFFSET = 0.075
-- Overlapping stencils would z-fight with each other, so each new one is lifted a bit more, cycling through layers
local LAYER_STEP = 0.002
local LAYER_COUNT = 8

-- The default size is slightly smaller than the model's footprint so the mask covers the mesh edges; at the exact
-- size a thin line of light shows along them.
local DEFAULT_SIZE_SCALE = 0.9

local DEFAULT_MAX_DISTANCE = 1000
local DEFAULT_AMBIENT = Color3.new(1, 1, 1)
local DEFAULT_LIGHT_COLOR = Color3.fromRGB(140, 140, 140)
local DEFAULT_LIGHT_DIRECTION = Vector3.new(-1, -1, -1)

local layerCounter = 0

local Stencil = {}
Stencil.__index = Stencil

type StencilData = {
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

	-- Derived from the CFrame and size
	_surfaceCFrame: CFrame,
	_surfaceSize: Vector2,
	_viewRotation: CFrame,
	_center: Vector3,
	_radius: number,

	_canvasHeight: number,
	_visible: boolean,
	_dirty: boolean,
}

export type Stencil = typeof(setmetatable({} :: StencilData, Stencil))

-- Offset from the stencil CFrame to the model pivot that puts the top of the model flush with the surface: the top of
-- the PrimaryPart if there is one, otherwise the top of the bounding box.
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

-- Size of the model's bounding box on the surface, centered on the stencil CFrame
local function getModelFootprint(model: Model, modelOffset: CFrame): Vector2
	local boxCFrame, boxSize = model:GetBoundingBox()
	local stencilCFrame = model:GetPivot() * modelOffset:Inverse()
	local center = stencilCFrame:PointToObjectSpace(boxCFrame.Position)
	return Vector2.new(math.abs(center.X) * 2 + boxSize.X, math.abs(center.Z) * 2 + boxSize.Z)
end

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
		_size = opts.size or getModelFootprint(model, modelOffset) * DEFAULT_SIZE_SCALE,
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

		_canvasHeight = -1,
		_visible = false,
		_dirty = true,
	}
	local self = setmetatable(data, Stencil)

	-- Set on every acquire so nothing carries over from the rig's previous stencil
	local surfaceGui = rig.surfaceGui
	surfaceGui.MaxDistance = 0 -- distance culling is done in _isInView
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

	-- Luau can't match the metatable type against Renderable, hence the cast
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

function Stencil.destroy(self: Stencil)
	-- Releasing the rig twice would put it in the pool twice, and two stencils would end up sharing it
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

-- For Maid, Janitor, Trove, etc.
Stencil.Destroy = Stencil.destroy

function Stencil._warnIfDestroyed(self: Stencil, method: string): boolean
	if self._destroyed then
		warn(`ViewportStencil: {method} called on a destroyed stencil`)
		return true
	end
	return false
end

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

	self._canvasHeight = -1
	self._dirty = true
end

-- Bounding sphere against maxDistance and the camera frustum
function Stencil._isInView(self: Stencil, frame: FrameState): boolean
	local center = frame.cameraCFrame:PointToObjectSpace(self._center)
	local radius = self._radius

	if center.Magnitude - radius > self._maxDistance then
		return false
	end

	-- The side planes pass through the camera; multiplying the radius by sec(half FOV) turns "radius away from the
	-- plane" into an offset along X/Y
	local depth = -center.Z
	return depth > -radius
		and math.abs(center.X) <= depth * frame.tanX + radius * frame.secX
		and math.abs(center.Y) <= depth * frame.tanY + radius * frame.secY
end

function Stencil._render(self: Stencil, frame: FrameState)
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
		offsetX, offsetY, scale, fov, factor, distance =
			Projection.solve(cameraPosition, self._surfaceCFrame, surfaceSize)
		-- Behind the surface (e.g. camera under the floor) the projection breaks down
		visible = distance > 0
	end

	-- A disabled SurfaceGui also stops its ViewportFrame from rendering, which is most of the cost
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
