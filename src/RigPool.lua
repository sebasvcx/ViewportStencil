--!strict
-- Pool of rigs: the Part, SurfaceGui, ViewportFrame and Camera each stencil needs. Only properties shared by every
-- stencil are set here; per-stencil options are applied by Stencil each time it takes a rig.

local Players = game:GetService("Players")

export type Rig = {
	part: Part,
	surfaceGui: SurfaceGui,
	viewport: ViewportFrame,
	camera: Camera,
}

local RigPool = {}

local MAX_POOL_SIZE = 32

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

	-- The SurfaceGui has to live in PlayerGui and point at the part through Adornee: a ViewportFrame inside a
	-- SurfaceGui parented to a part in Workspace doesn't render.
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

-- The returned rig's part is unparented and its SurfaceGui disabled.
function RigPool.acquire(): Rig
	while true do
		local rig = table.remove(pool)
		if not rig then
			return createRig()
		end
		-- Its SurfaceGui may have been destroyed while it was pooled
		if rig.surfaceGui.Parent then
			return rig
		end
	end
end

function RigPool.release(rig: Rig)
	if #pool >= MAX_POOL_SIZE then
		rig.surfaceGui:Destroy()
		rig.part:Destroy()
		return
	end

	-- Fails if the part was destroyed from outside (its Parent is locked), in which case it can't be reused
	if pcall(function()
		rig.surfaceGui.Enabled = false
		rig.part.Parent = nil
	end) then
		table.insert(pool, rig)
	end
end

return RigPool
