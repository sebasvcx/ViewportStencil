--!strict
--[[
	Renderer

	Keeps the list of active stencils and updates all of them once per frame, right after the default camera scripts,
	so every viewport uses this frame's camera CFrame (updating any earlier makes the viewports lag a frame behind and
	jitter while the camera moves).

	The render step is only bound while there is at least one active stencil.
]]

local RunService = game:GetService("RunService")

-- Per-frame camera data shared by every stencil. A single table is reused every frame.
export type FrameState = {
	cameraCFrame: CFrame,
	cameraPosition: Vector3,
	viewportHeight: number,

	-- Frustum half-extents: tan of half the horizontal/vertical FOV, and the matching secants (used to expand the
	-- frustum planes by a bounding sphere's radius)
	tanX: number,
	tanY: number,
	secX: number,
	secY: number,

	-- Whether anything above changed since the previous frame. When false, stencils that haven't changed themselves
	-- can skip their update entirely.
	changed: boolean,
}

-- Anything the renderer can draw. Stencil implements this.
export type Renderable = {
	_render: (self: any, frame: FrameState) -> (),
}

local Renderer = {}

local BIND_NAME = "ViewportStencilRender"
local BIND_PRIORITY = Enum.RenderPriority.Camera.Value + 1

local active: { Renderable } = {}
local indexOf: { [Renderable]: number } = {}
local bound = false

local frame: FrameState = {
	cameraCFrame = CFrame.identity,
	cameraPosition = Vector3.zero,
	viewportHeight = 0,
	tanX = 0,
	tanY = 0,
	secX = 0,
	secY = 0,
	changed = true,
}

-- Values the frame state was last built from, to detect changes
local lastCFrame: CFrame? = nil
local lastViewportSize: Vector2? = nil
local lastFieldOfView: number? = nil

local function fillFrame(state: FrameState, camera: Camera)
	local cameraCFrame = camera.CFrame
	local viewportSize = camera.ViewportSize

	local tanY = math.tan(math.rad(camera.FieldOfView) / 2)
	local tanX = tanY * viewportSize.X / math.max(viewportSize.Y, 1)

	state.cameraCFrame = cameraCFrame
	state.cameraPosition = cameraCFrame.Position
	state.viewportHeight = viewportSize.Y
	state.tanX = tanX
	state.tanY = tanY
	state.secX = math.sqrt(1 + tanX * tanX)
	state.secY = math.sqrt(1 + tanY * tanY)
end

local function renderAll()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local cameraCFrame = camera.CFrame
	local viewportSize = camera.ViewportSize
	local fieldOfView = camera.FieldOfView

	local changed = cameraCFrame ~= lastCFrame or viewportSize ~= lastViewportSize or fieldOfView ~= lastFieldOfView
	if changed then
		lastCFrame = cameraCFrame
		lastViewportSize = viewportSize
		lastFieldOfView = fieldOfView
		fillFrame(frame, camera)
	end
	frame.changed = changed

	for _, item in active do
		item:_render(frame)
	end
end

--[[
	Adds an item and renders it right away, so it never shows a stale frame even if it's added after this frame's
	render step already ran.
]]
function Renderer.add(item: Renderable)
	if indexOf[item] then
		return
	end

	table.insert(active, item)
	indexOf[item] = #active

	local camera = workspace.CurrentCamera
	if camera then
		-- Separate state so the shared one's change tracking isn't affected
		local state = table.clone(frame)
		fillFrame(state, camera)
		state.changed = true
		item:_render(state)
	end

	if not bound then
		bound = true
		RunService:BindToRenderStep(BIND_NAME, BIND_PRIORITY, renderAll)
	end
end

function Renderer.remove(item: Renderable)
	local index = indexOf[item]
	if not index then
		return
	end

	-- Swap with the last item so removal is O(1)
	local last = active[#active]
	active[index] = last
	indexOf[last] = index
	active[#active] = nil
	indexOf[item] = nil

	if bound and #active == 0 then
		bound = false
		RunService:UnbindFromRenderStep(BIND_NAME)
		-- Stencils added later must not assume they saw the last camera
		lastCFrame = nil
	end
end

--[[
	Returns a copy of the active list, so callers can destroy items while iterating it.
]]
function Renderer.getAll(): { Renderable }
	return table.clone(active)
end

return Renderer
