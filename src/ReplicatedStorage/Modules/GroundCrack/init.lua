local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CrackManager = require(script.CrackManager)
local BufferManager = require(script.BufferManager)
local ParallelTasks = require(script.ParallelWorker.ParallelTasks)

local parent = workspace:WaitForChild("VFX")

local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui

local UP = Vector3.yAxis
local FOV120 = math.rad(120)
local PI2 = math.pi/2

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
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
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
		object.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		object.PixelsPerStud = 50
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

function Crack.new(model: Model, cframe: CFrame, size: Vector3?)
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
	
	self:_setInstanceProps()
	
	self:setCFrame(cframe or CFrame.new())
	self:setSize(size or Vector3.new(45, .15, 45))
	
	self:_updateSurfaceInfo()
	
	CrackManager:add(self)
	
	--print(CrackManager:getActiveCracks())
	
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
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 1000
	surfaceGui.ClipsDescendants = true

	Viewport.Parent = surfaceGui
	Viewport.CurrentCamera = vCam
	Viewport.AnchorPoint = Vector2.new(.5, .5)
	Viewport.Position = UDim2.new(.5, 0, .5, 0)
	Viewport.Size = UDim2.new(1, 0, 1, 0)
	Viewport.BackgroundTransparency = 1

	vCam.Parent = Viewport

	Part.Parent = parent
	Part.Transparency = 1
	Part.Anchored = true
	Part.CanCollide = false
	Part.CanTouch = false
	Part.CanQuery = false
	Part.Name = "Crackpart"

	model.Parent = Viewport
end

function Crack:setCFrame(cframe: CFrame)
	self.CFrame = cframe
	self.Part.CFrame = self.CFrame
	self.Model:PivotTo(self.Part.CFrame * CFrame.new(0, -self.Model.PrimaryPart.Size.Y / 2, 0))
	self:_updateSurfaceInfo()
end

function Crack:getCFrame()
	return self.CFrame
end

function Crack:setSize(size: Vector3)
	self.Size = size
	self.Part.Size = self.Size
	self:_updateSurfaceInfo()
end

function Crack:getSize()
	return self.Size
end

function Crack:_updateSurfaceInfo()
	local part = self.Part
	local partCF, partSize = part.CFrame, part.Size

	local cf, size = ParallelTasks.CalculateSurfaceInfo(partCF, partSize)
	self.SurfaceInfo = {
		cf = cf,
		size = size,
	}
end

function Crack:updateCamera()
	local camCF = Camera.CFrame
	local surfaceCF = self.SurfaceInfo.cf
	local surfaceSize = self.SurfaceInfo.size
	local viewportSizeY = Camera.ViewportSize.y
	
	if not surfaceCF or not surfaceSize then return end

	local sX, sY, scale, scaleCF, clampedFov = ParallelTasks.CalculateCameraProperties(
		camCF, surfaceCF, surfaceSize, viewportSizeY
	)
	
	local vpf = self.Viewport

	vpf.Position = UDim2.new(vpf.AnchorPoint.x - sX, 0, vpf.AnchorPoint.y - sY, 0)
	vpf.Size = UDim2.new(scale, 0, scale, 0)
	vpf.BackgroundColor3 = self.SurfaceGui.Adornee.Color

	self.SurfaceGui.CanvasSize = Vector2.new(viewportSizeY*(surfaceSize.x/surfaceSize.y), viewportSizeY)

	self.vCam.FieldOfView = clampedFov
	self.vCam.CFrame = CFrame.new(camCF.p) * (surfaceCF - surfaceCF.p) * CFrame.Angles(0, math.pi, 0) * scaleCF
end

function Crack:Destroy() 
	CrackManager:remove(self)
	
	cameraBuffer:release(self.vCam)
	viewportBuffer:release(self.Viewport)
	surfaceGuiBuffer:release(self.SurfaceGui)
	partBuffer:release(self.Part)
	
	self.Model:Destroy()
	
	self = nil
	--print(CrackManager:getActiveCracks())
end

RunService.PreAnimation:Connect(function(dt)
	CrackManager:updateAllCameras()
end)

setmetatable(Crack, {
	__index = function(self, key)
		if rawget(self, key) then
			return rawget(self, key)
		end
		error(string.format("'%s' is not a valid member of 'Crack'", key), 2)
	end,
})

return Crack
