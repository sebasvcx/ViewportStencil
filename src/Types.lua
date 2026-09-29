--!strict

export type StencilOptions = {
	-- Surface size in studs, along the CFrame's X and Z axes. Anything of the model outside it is clipped. Defaults to
	-- 90% of the model's footprint, so the mask hides the mesh edges.
	size: Vector2?,
	-- Seconds until the stencil destroys itself. Defaults to never.
	lifetime: number?,
	-- Whether destroying the stencil also destroys the model. Defaults to true; when false the model is unparented.
	destroyModel: boolean?,
	-- ViewportFrame.ImageTransparency. Defaults to 0.
	transparency: number?,
	-- Hidden beyond this distance from the camera, in studs. Defaults to 1000.
	maxDistance: number?,
	-- SurfaceGui.Brightness. Defaults to 1.
	brightness: number?,
	-- SurfaceGui.LightInfluence. Defaults to 1.
	lightInfluence: number?,
	-- ViewportFrame.Ambient. Defaults to white.
	ambient: Color3?,
	-- ViewportFrame.LightColor. Defaults to (140, 140, 140).
	lightColor: Color3?,
	-- ViewportFrame.LightDirection. Defaults to (-1, -1, -1).
	lightDirection: Vector3?,
}

return {}
