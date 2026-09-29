--!strict
-- Updates every active stencil once per frame. Runs right after the camera scripts: any earlier and the viewports
-- use last frame's camera, which makes them lag behind and jitter while the camera moves.

local RunService = game:GetService("RunService")

export type FrameState = {
	cameraCFrame: CFrame,
	cameraPosition: Vector3,
	viewportHeight: number,

	-- tan of half the horizontal/vertical FOV, and their secants, for frustum culling
	tanX: number,
	tanY: number,
	secX: number,
	secY: number,

	-- False when the camera is exactly as it was last frame
	changed: boolean,
}

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

-- Also renders the item right away, so it doesn't show a stale frame when added after this frame's render step.
function Renderer.add(item: Renderable)
	if indexOf[item] then
		return
	end

	table.insert(active, item)
	indexOf[item] = #active

	local camera = workspace.CurrentCamera
	if camera then
		-- Uses its own state so the shared one keeps tracking changes correctly
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

	local last = active[#active]
	active[index] = last
	indexOf[last] = index
	active[#active] = nil
	indexOf[item] = nil

	if bound and #active == 0 then
		bound = false
		RunService:UnbindFromRenderStep(BIND_NAME)
		lastCFrame = nil
	end
end

function Renderer.getAll(): { Renderable }
	return table.clone(active)
end

return Renderer
