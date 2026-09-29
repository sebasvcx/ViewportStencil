--!strict
--[[
	Types

	Public types shared between modules. Re-exported from the main module.
]]

--[[
	Options for `ViewportStencil.new`. Every field is optional.
]]
export type StencilOptions = {
	-- Size of the stencil surface in studs, along the CFrame's X and Z axes. Anything of the model outside this area is
	-- clipped. Defaults to the smallest size that fits the model's bounding box. Tighter is sharper: the viewport's
	-- pixels are spread over this area.
	size: Vector2?,

	-- Seconds until the stencil destroys itself. Defaults to never.
	lifetime: number?,

	-- Whether destroying the stencil also destroys its model. Defaults to true. When false, the model is unparented
	-- instead and can be reused.
	destroyModel: boolean?,

	-- Transparency of the whole stencil (ViewportFrame.ImageTransparency). Defaults to 0.
	transparency: number?,

	-- SurfaceGui.MaxDistance. Defaults to 1000.
	maxDistance: number?,

	-- SurfaceGui.Brightness. Defaults to 1.
	brightness: number?,

	-- SurfaceGui.LightInfluence. Defaults to 1.
	lightInfluence: number?,

	-- ViewportFrame.Ambient. Defaults to white.
	ambient: Color3?,

	-- ViewportFrame.LightColor. Defaults to Color3.fromRGB(140, 140, 140).
	lightColor: Color3?,

	-- ViewportFrame.LightDirection. Defaults to (-1, -1, -1).
	lightDirection: Vector3?,
}

return {}
