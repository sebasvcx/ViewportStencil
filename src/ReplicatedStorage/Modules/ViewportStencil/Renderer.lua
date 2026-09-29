--!strict
--[[
	Renderer

	Keeps the list of active stencils and updates all of them once per frame, right after the default camera scripts,
	so every viewport uses this frame's camera CFrame (updating any earlier makes the viewports lag a frame behind and
	jitter while the camera moves).
]]

local RunService = game:GetService("RunService")

-- Anything the renderer can draw. Stencil implements this.
export type Renderable = {
	_render: (self: any, cameraCFrame: CFrame, viewportHeight: number) -> (),
}

local Renderer = {}

local BIND_NAME = "ViewportStencilRender"
local BIND_PRIORITY = Enum.RenderPriority.Camera.Value + 1

local active: { Renderable } = {}
local indexOf: { [Renderable]: number } = {}

local function renderAll()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local cameraCFrame = camera.CFrame
	local viewportHeight = camera.ViewportSize.Y

	for _, item in active do
		item:_render(cameraCFrame, viewportHeight)
	end
end

function Renderer.add(item: Renderable)
	if indexOf[item] then
		return
	end

	table.insert(active, item)
	indexOf[item] = #active
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
end

--[[
	Returns a copy of the active list, so callers can destroy items while iterating it.
]]
function Renderer.getAll(): { Renderable }
	return table.clone(active)
end

if RunService:IsClient() then
	RunService:BindToRenderStep(BIND_NAME, BIND_PRIORITY, renderAll)
end

return Renderer
