local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local CrackManager = require(script.CrackManager)
local BufferManager = require(script.BufferManager)
local Projection = require(script.Projection)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Thickness of the invisible part the SurfaceGui is drawn on. The surface sits half of this above the crack CFrame.
local PART_THICKNESS = 0.15
-- Overlapping cracks would z-fight if their surfaces were coplanar, so each new crack is lifted by a tiny extra amount.
local LAYER_STEP = 0.002
local LAYER_COUNT = 8

local container = Instance.new("Folder")
container.Name = "GroundCracks"
container.Parent = workspace

local layerCounter = 0

local Crack = {}
Crack.__index = Crack

local viewportBuffer = BufferManager.new(function()
	local viewport = Instance.new("ViewportFrame")
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Size = UDim2.new(1, 0, 1, 0)
	viewport.BackgroundTransparency = 1
	return viewport
end)

local surfaceGuiBuffer = BufferManager.new(function()
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.ResetOnSpawn = false
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surfaceGui.ClipsDescendants = true
	return surfaceGui
end)

local cameraBuffer = BufferManager.new(function()
	return Instance.new("Camera")
end)

local partBuffer = BufferManager.new(function()
	return Instance.new("Part")
end)

local function SetDefaults(object)
	if object:IsA("Part") then
		object.Size = Vector3.new(1, 1, 1)
		object.CFrame = CFrame.new()
		object.Transparency = 0
		object.Anchored = false
		object.CanCollide = true
		object.CanTouch = true
		object.CanQuery = true
		object.Color = Color3.new(1, 1, 1)
		object.Material = Enum.Material.Plastic
		object.CastShadow = true
		object.Name = "Part"

	elseif object:IsA("SurfaceGui") then
		object.Adornee = nil
		object.ResetOnSpawn = true
		object.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		object.ClipsDescendants = false
		object.Face = Enum.NormalId.Front
		object.ZIndexBehavior = Enum.ZIndexBehavior.Global
		object.Enabled = true
		object.Brightness = 1
		object.LightInfluence = 1
		object.AlwaysOnTop = false
		object.ToolPunchThroughDistance = 0
		object.Name = "SurfaceGui"
		object.Parent = nil

	elseif object:IsA("ViewportFrame") then
		object.CurrentCamera = nil
		object.AnchorPoint = Vector2.new(0, 0)
		object.Size = UDim2.new(0, 100, 0, 100)
		object.Position = UDim2.new(0, 0, 0, 0)
		object.LightDirection = Vector3.new(-1, -1, -1)
		object.BackgroundTransparency = 0
		object.BorderSizePixel = 1
		object.Ambient = Color3.new(1, 1, 1)
		object.Name = "ViewportFrame"
	end
end

-- Returns the offset from the crack CFrame (a point on the ground) to the model's pivot, such that the top of the
-- model sits flush with the ground. Uses the PrimaryPart's top face when there is one, otherwise the bounding box.
local function GetModelOffset(model: Model): CFrame
	local topCF
	local primary = model.PrimaryPart
	if primary then
		topCF = primary.CFrame * CFrame.new(0, primary.Size.Y / 2, 0)
	else
		local boxCF, boxSize = model:GetBoundingBox()
		topCF = boxCF * CFrame.new(0, boxSize.Y / 2, 0)
	end
	return topCF:ToObjectSpace(model:GetPivot())
end

-- Returns the smallest surface size (centered on the crack CFrame) that fully contains the model's footprint.
local function GetModelFootprint(model: Model, offset: CFrame): Vector3
	local boxCF, boxSize = model:GetBoundingBox()
	-- Where the box center is, relative to the crack CFrame the model will be placed at
	local center = (model:GetPivot() * offset:Inverse()):PointToObjectSpace(boxCF.Position)
	local halfX = math.abs(center.X) + boxSize.X / 2
	local halfZ = math.abs(center.Z) + boxSize.Z / 2
	return Vector3.new(halfX * 2, PART_THICKNESS, halfZ * 2)
end

function Crack.new(model: Model, cframe: CFrame, size: Vector3?)
	assert(RunService:IsClient(), "GroundCrack can only be used on the client")
	assert(typeof(model) == "Instance" and model:IsA("Model"), "GroundCrack.new expects a Model")

	local self = setmetatable({}, Crack)

	local surfaceGui = surfaceGuiBuffer:get()
	SetDefaults(surfaceGui)
	local Viewport = viewportBuffer:get()
	SetDefaults(Viewport)
	local Part = partBuffer:get()
	SetDefaults(Part)
	local vCam = cameraBuffer:get()

	self.SurfaceGui = surfaceGui
	self.Viewport = Viewport
	self.Part = Part
	self.vCam = vCam
	self.Model = model
	self.Destroyed = false
	self.ModelOffset = GetModelOffset(model)

	layerCounter = (layerCounter + 1) % LAYER_COUNT
	self.LayerOffset = layerCounter * LAYER_STEP

	self:_setInstanceProps()

	self:setSize(size or GetModelFootprint(model, self.ModelOffset))
	self:setCFrame(cframe or CFrame.new())

	CrackManager:add(self)

	return self
end

function Crack:_setInstanceProps()
	local surfaceGui = self.SurfaceGui
	local Viewport = self.Viewport
	local Part = self.Part
	local vCam = self.vCam
	local model = self.Model

	surfaceGui.Parent = PlayerGui
	surfaceGui.Name = "GroundCrackSurfaceGui"
	surfaceGui.ResetOnSpawn = false
	surfaceGui.Adornee = Part
	surfaceGui.Face = Enum.NormalId.Top
	surfaceGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	surfaceGui.MaxDistance = 1000
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surfaceGui.ClipsDescendants = true

	Viewport.Parent = surfaceGui
	Viewport.CurrentCamera = vCam
	Viewport.AnchorPoint = Vector2.new(.5, .5)
	Viewport.Position = UDim2.new(.5, 0, .5, 0)
	Viewport.Size = UDim2.new(1, 0, 1, 0)
	Viewport.BackgroundTransparency = 1

	vCam.Parent = Viewport

	Part.Parent = container
	Part.Transparency = 1
	Part.Anchored = true
	Part.CanCollide = false
	Part.CanTouch = false
	Part.CanQuery = false
	Part.CastShadow = false
	Part.Name = "Crackpart"

	model.Parent = Viewport
end

function Crack:setCFrame(cframe: CFrame)
	if self.Destroyed then
		warn("GroundCrack: setCFrame called on a destroyed crack")
		return
	end

	self.CFrame = cframe
	self.Part.CFrame = cframe * CFrame.new(0, self.LayerOffset, 0)
	self.Model:PivotTo(cframe * self.ModelOffset)
	self:_updateSurfaceInfo()
end

function Crack:getCFrame()
	return self.CFrame
end

function Crack:setSize(size: Vector3)
	if self.Destroyed then
		warn("GroundCrack: setSize called on a destroyed crack")
		return
	end

	self.Size = size
	self.Part.Size = size
	self:_updateSurfaceInfo()
end

function Crack:getSize()
	return self.Size
end

function Crack:_updateSurfaceInfo()
	local part = self.Part
	local partCF, partSize = part.CFrame, part.Size

	local cf, size = Projection.CalculateSurfaceInfo(partCF, partSize)
	self.SurfaceInfo = {
		cf = cf,
		size = size,
	}
	-- Force the canvas to be resized on the next update
	self.CanvasHeight = nil
end

function Crack:updateCamera(camera: Camera)
	local camCF = camera.CFrame
	local surfaceCF = self.SurfaceInfo.cf
	local surfaceSize = self.SurfaceInfo.size
	local viewportSizeY = camera.ViewportSize.Y

	local sX, sY, scale, scaleCF, clampedFov, rDist = Projection.CalculateCameraProperties(
		camCF, surfaceCF, surfaceSize, viewportSizeY
	)

	-- Seen from behind (e.g. camera under the floor) the projection is meaningless, so just hide it
	local visible = rDist > 0
	if self.SurfaceGui.Enabled ~= visible then
		self.SurfaceGui.Enabled = visible
	end
	if not visible then return end

	local vpf = self.Viewport

	vpf.Position = UDim2.new(vpf.AnchorPoint.x - sX, 0, vpf.AnchorPoint.y - sY, 0)
	vpf.Size = UDim2.new(scale, 0, scale, 0)

	if self.CanvasHeight ~= viewportSizeY then
		self.CanvasHeight = viewportSizeY
		self.SurfaceGui.CanvasSize = Vector2.new(viewportSizeY*(surfaceSize.x/surfaceSize.y), viewportSizeY)
	end

	self.vCam.FieldOfView = clampedFov
	self.vCam.CFrame = CFrame.new(camCF.p) * (surfaceCF - surfaceCF.p) * CFrame.Angles(0, math.pi, 0) * scaleCF
end

function Crack:Destroy()
	-- Destroy must be idempotent: releasing the same instances twice would put them in the pool twice, and two
	-- future cracks would end up sharing (and stealing) the same SurfaceGui/Viewport/Part.
	if self.Destroyed then return end
	self.Destroyed = true

	CrackManager:remove(self)

	self.Viewport.CurrentCamera = nil
	self.SurfaceGui.Adornee = nil

	cameraBuffer:release(self.vCam)
	viewportBuffer:release(self.Viewport)
	surfaceGuiBuffer:release(self.SurfaceGui)
	partBuffer:release(self.Part)

	self.Model:Destroy()
end

-- Runs right after the default camera scripts, so the viewports use this frame's camera CFrame instead of the last one
RunService:BindToRenderStep("GroundCrackUpdate", Enum.RenderPriority.Camera.Value + 1, function()
	local camera = workspace.CurrentCamera
	if camera then
		CrackManager:updateAllCameras(camera)
	end
end)

return Crack
