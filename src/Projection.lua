--!strict
-- Off-axis projection that makes a ViewportFrame on a SurfaceGui line up with the world behind it.
-- Based on EgoMoose's rbx-viewport-window: https://github.com/EgoMoose/rbx-viewport-window

local Projection = {}

local MIN_FOV = 1
local MAX_FOV = 120
local MAX_FOV_RAD = math.rad(MAX_FOV)
local TAN_HALF_MAX_FOV = math.tan(MAX_FOV_RAD / 2)

-- Basis of a part's Top face in SurfaceGui canvas space
local BACK = -Vector3.FromNormalId(Enum.NormalId.Top)
local RIGHT = CFrame.fromAxisAngle(Vector3.new(BACK.Y, 0, 0), math.pi / 2) * BACK
local TOP = BACK:Cross(RIGHT).Unit
local SURFACE_ROTATION = CFrame.fromMatrix(Vector3.zero, RIGHT, TOP, BACK)

-- Returns the CFrame at the center of a part's Top face (LookVector pointing out of it) and the face size in canvas
-- space, in studs.
function Projection.getSurface(partCFrame: CFrame, partSize: Vector3): (CFrame, Vector2)
	local surfaceCFrame = partCFrame * CFrame.new(-BACK * partSize / 2) * SURFACE_ROTATION
	local surfaceSize = Vector2.new((partSize * RIGHT).Magnitude, (partSize * TOP).Magnitude)
	return surfaceCFrame, surfaceSize
end

function Projection.getViewRotation(surfaceCFrame: CFrame): CFrame
	return surfaceCFrame.Rotation * CFrame.Angles(0, math.pi, 0)
end

-- Returns, for a camera at `cameraPosition`:
--   offsetX, offsetY: camera position over the surface, in surface sizes (0, 0 is the center)
--   scale: viewport size, in surface sizes
--   fov: viewport camera FieldOfView, in degrees
--   factor: X/Y scale for the viewport camera CFrame
--   distance: distance to the surface plane, <= 0 when the camera is behind it
function Projection.solve(
	cameraPosition: Vector3,
	surfaceCFrame: CFrame,
	surfaceSize: Vector2
): (number, number, number, number, number, number)
	local relative = surfaceCFrame:PointToObjectSpace(cameraPosition)
	local offsetX = relative.X / surfaceSize.X
	local offsetY = relative.Y / surfaceSize.Y
	local distance = -relative.Z

	-- The viewport is centered under the camera, so it has to reach |offset| + 0.5 on each side to cover the surface.
	-- The original used sqrt(x² + y²), which is never below √2 and wastes about half of the viewport's pixels.
	local scale = 1 + 2 * math.max(math.abs(offsetX), math.abs(offsetY))

	local halfHeight = surfaceSize.Y / 2
	local fov = 2 * math.atan2(halfHeight, distance)

	local fovDegrees, factor
	if fov > MAX_FOV_RAD then
		-- Past the max FOV, keep it clamped and shrink the image instead
		fovDegrees = MAX_FOV
		factor = distance * TAN_HALF_MAX_FOV / halfHeight / scale
	else
		fovDegrees = math.max(math.deg(fov), MIN_FOV)
		factor = 1 / scale
	end

	return offsetX, offsetY, scale, fovDegrees, factor, distance
end

-- The X/Y axes are scaled on purpose: the non-orthonormal CFrame is what skews the projection.
function Projection.getCameraCFrame(cameraPosition: Vector3, viewRotation: CFrame, factor: number): CFrame
	return (viewRotation + cameraPosition) * CFrame.new(0, 0, 0, factor, 0, 0, 0, factor, 0, 0, 0, 1)
end

return Projection
