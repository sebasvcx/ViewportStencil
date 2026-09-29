--!strict
--[[
	RigPool

	A rig is everything a stencil needs to be drawn: an invisible Part, a SurfaceGui on its Top face, a ViewportFrame
	and the viewport's Camera. Rigs are pooled as a whole so creating and destroying stencils doesn't churn Instances.

	Only properties that are the same for every stencil are set here. Anything a stencil can customize is set by the
	stencil every time it acquires a rig, so nothing leaks from one stencil to the next.

	The SurfaceGui lives in PlayerGui and is attached to the part through Adornee: ViewportFrames inside a SurfaceGui
	that is parented to a part in Workspace don't render.
]]

local Players = game:GetService("Players")

export type Rig = {
	part: Part,
	surfaceGui: SurfaceGui,
	viewport: ViewportFrame,
	camera: Camera,
}

local RigPool = {}

local pool: { Rig } = {}
local container: Folder? = nil

local function createRig(): Rig
	local part = Instance.new("Part")
	part.Name = "ViewportStencil"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Top
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surfaceGui.ClipsDescendants = true
	surfaceGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	surfaceGui.ResetOnSpawn = false
	surfaceGui.Enabled = false
	surfaceGui.Adornee = part
	surfaceGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local viewport = Instance.new("ViewportFrame")
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Position = UDim2.fromScale(0.5, 0.5)
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.Parent = surfaceGui

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	return {
		part = part,
		surfaceGui = surfaceGui,
		viewport = viewport,
		camera = camera,
	}
end

--[[
	Folder in Workspace that holds the parts of every active stencil. Created on first use.
]]
function RigPool.getContainer(): Folder
	local current = container
	if current and current.Parent then
		return current
	end

	local folder = Instance.new("Folder")
	folder.Name = "ViewportStencils"
	folder.Parent = workspace
	container = folder
	return folder
end

--[[
	Returns a rig that is not parented anywhere. The caller is responsible for parenting `rig.part`.
]]
function RigPool.acquire(): Rig
	while true do
		local rig = table.remove(pool)
		if not rig then
			return createRig()
		end
		-- Skip rigs whose SurfaceGui was destroyed from outside while pooled
		if rig.surfaceGui.Parent then
			return rig
		end
	end
end

--[[
	Returns a rig to the pool. The rig must not be used by the caller afterwards.
]]
function RigPool.release(rig: Rig)
	-- If the rig was destroyed from outside (e.g. someone destroyed the container), its Parent is locked and it
	-- can't be reused, so just drop it.
	if pcall(function()
		rig.surfaceGui.Enabled = false
		rig.part.Parent = nil
	end) then
		table.insert(pool, rig)
	end
end

return RigPool
