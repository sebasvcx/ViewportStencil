--!strict
-- ViewportStencil: render models inside surfaces with ViewportFrames. Client only.
-- https://github.com/EgoMoose/rbx-viewport-window + https://devforum.roblox.com/t/viewportframe-masking/2964839

local Renderer = require(script.Renderer)
local Stencil = require(script.Stencil)
local Types = require(script.Types)
local Utils = require(script.Utils)

export type Stencil = Stencil.Stencil
export type StencilOptions = Types.StencilOptions

local ViewportStencil = {
	Utils = Utils,
	new = Stencil.new,
}

-- Returns a copy, so it's safe to destroy stencils while iterating it
function ViewportStencil.getActive(): { Stencil }
	return Renderer.getAll() :: any
end

function ViewportStencil.destroyAll()
	for _, stencil in ViewportStencil.getActive() do
		stencil:destroy()
	end
end

return ViewportStencil
