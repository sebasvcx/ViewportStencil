--!strict
--[[
	Projection

	Pure math that makes a ViewportFrame drawn on a SurfaceGui look like a window into 3D space: the viewport camera
	sits where the real camera is, looks straight into the surface, and uses an off-center (oblique) projection so the
	image lines up with the surface from any angle.

	Based on EgoMoose's ViewportFrame "window" technique. No Instances are touched here.
]]

local Projection = {}

local MIN_FOV = 1
local MAX_FOV = 120
local MAX_FOV_RAD = math.rad(MAX_FOV)
local TAN_HALF_MAX_FOV = math.tan(MAX_FOV_RAD / 2)

-- Basis of a part's Top face as seen by a SurfaceGui (X = canvas right, Y = canvas up, Z = into the part).
local BACK = -Vector3.FromNormalId(Enum.NormalId.Top)
local RIGHT = CFrame.fromAxisAngle(Vector3.new(BACK.Y, 0, 0), math.pi / 2) * BACK
local TOP = BACK:Cross(RIGHT).Unit
local SURFACE_ROTATION = CFrame.fromMatrix(Vector3.zero, RIGHT, TOP, BACK)

--[[
	Returns the CFrame of the center of a part's Top face (LookVector pointing out of the part) and the size of that
	face in SurfaceGui canvas space (X = canvas width, Y = canvas height), in studs.
]]
function Projection.getSurface(partCFrame: CFrame, partSize: Vector3): (CFrame, Vector2)
	local surfaceCFrame = partCFrame * CFrame.new(-BACK * partSize / 2) * SURFACE_ROTATION
	local surfaceSize = Vector2.new((partSize * RIGHT).Magnitude, (partSize * TOP).Magnitude)
	return surfaceCFrame, surfaceSize
end

--[[
	Rotation the viewport camera should use for a given surface. It only depends on the surface, so it can be cached.
]]
function Projection.getViewRotation(surfaceCFrame: CFrame): CFrame
	return surfaceCFrame.Rotation * CFrame.Angles(0, math.pi, 0)
end

--[[
	Solves the viewport layout for a camera at `cameraPosition`.

	Returns:
	- offsetX, offsetY: where the camera is over the surface, in surface sizes (0, 0 = centered). The ViewportFrame
	  goes at UDim2.fromScale(0.5 - offsetX, 0.5 - offsetY).
	- scale: ViewportFrame size, in surface sizes. It is the smallest size that still covers the whole surface.
	- fov: FieldOfView for the viewport camera, in degrees.
	- factor: X/Y scale to apply to the viewport camera's CFrame (see `Projection.getCameraCFrame`).
	- distance: distance from the camera to the surface plane. <= 0 means the camera is behind the surface.
]]
function Projection.solve(
	cameraPosition: Vector3,
	surfaceCFrame: CFrame,
	surfaceSize: Vector2
): (number, number, number, number, number, number)
	local relative = surfaceCFrame:PointToObjectSpace(cameraPosition)
	local offsetX = relative.X / surfaceSize.X
	local offsetY = relative.Y / surfaceSize.Y
	-- LookVector is -Z, so the distance along it is -Z
	local distance = -relative.Z

	-- The viewport is centered under the camera, so to cover the whole surface it has to reach |offset| + 0.5 on each
	-- side. Taking the max of both axes is the tightest fit; EgoMoose's original sqrt(x² + y²) was never below √2,
	-- which wasted about half of the viewport's pixels on area outside the surface and made the result blurrier.
	local scale = 1 + 2 * math.max(math.abs(offsetX), math.abs(offsetY))

	local halfHeight = surfaceSize.Y / 2
	local fov = 2 * math.atan2(halfHeight, distance)

	local fovDegrees, factor
	if fov > MAX_FOV_RAD then
		-- Too close for the maximum FOV: keep it at the maximum and shrink the image to compensate
		fovDegrees = MAX_FOV
		factor = distance * TAN_HALF_MAX_FOV / halfHeight / scale
	else
		fovDegrees = math.max(math.deg(fov), MIN_FOV)
		factor = 1 / scale
	end

	return offsetX, offsetY, scale, fovDegrees, factor, distance
end

--[[
	Builds the viewport camera CFrame. The X/Y axes are intentionally scaled by `factor`: a non-orthonormal camera
	CFrame is what produces the off-center projection.
]]
function Projection.getCameraCFrame(cameraPosition: Vector3, viewRotation: CFrame, factor: number): CFrame
	return (viewRotation + cameraPosition) * CFrame.new(0, 0, 0, factor, 0, 0, 0, factor, 0, 0, 0, 1)
end

return Projection
