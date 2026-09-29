local Projection = {}

--credits to EgoMoose for this

function Projection.CalculateSurfaceInfo(partCF, partSize)
	local back = -Vector3.FromNormalId(Enum.NormalId.Top)
	local axis = (math.abs(back.y) == 1) and Vector3.new(back.y, 0, 0) or Vector3.yAxis
	local right = CFrame.fromAxisAngle(axis, math.pi / 2) * back
	local top = back:Cross(right).Unit

	local cf = partCF * CFrame.fromMatrix(-back * partSize / 2, right, top, back)
	local size = Vector2.new((partSize * right).Magnitude, (partSize * top).Magnitude)

	return cf, size
end

function Projection.CalculateCameraProperties(camCF, surfaceCF, surfaceSize, viewportSizeY)
	local rPoint = surfaceCF:PointToObjectSpace(camCF.p)
	local sX, sY = rPoint.x / surfaceSize.x, rPoint.y / surfaceSize.y

	-- The viewport is centered under the camera, so to cover the whole surface it has to reach |s| + 0.5 on each
	-- side. max() is the tightest scale that does that; the original sqrt(x² + y²) was never below √2, which wasted
	-- about half of the viewport's pixels on area outside the surface and made the result look blurrier.
	local scaleX = 1 + math.abs(sX) * 2
	local scaleY = 1 + math.abs(sY) * 2
	local scale = math.max(scaleX, scaleY)

	local rDist = (camCF.p - surfaceCF.p):Dot(surfaceCF.LookVector)
	local newFov = 2 * math.atan2(surfaceSize.y / 2, rDist)
	local clampedFov = math.clamp(math.deg(newFov), 1, 120)
	local pDist = surfaceSize.y / 2 / math.tan(math.rad(clampedFov) / 2)
	local adjust = rDist / pDist

	local factor = (newFov > math.rad(120) and adjust or 1) / scale
	local scaleCF = CFrame.new(0, 0, 0, factor, 0, 0, 0, factor, 0, 0, 0, 1)

	-- rDist is the camera's height above the surface plane; <= 0 means the camera is behind it
	return sX, sY, scale, scaleCF, clampedFov, rDist
end

return Projection
