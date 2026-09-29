--!strict
--[[
	ViewportStencil

	Render models "inside" surfaces using ViewportFrames: ground cracks, holes, portals, windows... without cutting or
	destroying anything. Client only.

		local ViewportStencil = require(path.to.ViewportStencil)

		local cframe = ViewportStencil.Utils.fromMouse()
		if cframe then
			ViewportStencil.new(crackModel:Clone(), cframe, { lifetime = 10 })
		end
]]

local Renderer = require(script.Renderer)
local Stencil = require(script.Stencil)
local Types = require(script.Types)
local Utils = require(script.Utils)

export type Stencil = Stencil.Stencil
export type StencilOptions = Types.StencilOptions

local ViewportStencil = {
	Utils = Utils,

	--[[
		Creates a stencil that renders `model` inside the surface at `cframe`. See Stencil.new.
	]]
	new = Stencil.new,
}

--[[
	Returns every stencil that hasn't been destroyed yet. The list is a copy, so it's safe to destroy stencils while
	iterating it.
]]
function ViewportStencil.getActive(): { Stencil }
	return Renderer.getAll() :: any
end

--[[
	Destroys every active stencil.
]]
function ViewportStencil.destroyAll()
	for _, stencil in ViewportStencil.getActive() do
		stencil:destroy()
	end
end

return ViewportStencil
