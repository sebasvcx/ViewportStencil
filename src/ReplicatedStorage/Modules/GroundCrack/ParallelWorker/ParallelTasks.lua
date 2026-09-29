local ParallelTasks = {}

--credits to EgoMoose for this

function ParallelTasks.CalculateSurfaceInfo(partCF, partSize)
	local back = -Vector3.FromNormalId(Enum.NormalId.Top)
	local axis = (math.abs(back.y) == 1) and Vector3.new(back.y, 0, 0) or Vector3.yAxis
	local right = CFrame.fromAxisAngle(axis, math.pi / 2) * back
	local top = back:Cross(right).Unit

	local cf = partCF * CFrame.fromMatrix(-back * partSize / 2, right, top, back)
	local size = Vector2.new((partSize * right).Magnitude, (partSize * top).Magnitude)

	return cf, size
end

function ParallelTasks.CalculateCameraProperties(camCF, surfaceCF, surfaceSize, viewportSizeY)
	local rPoint = surfaceCF:PointToObjectSpace(camCF.p)
	local sX, sY = rPoint.x / surfaceSize.x, rPoint.y / surfaceSize.y

	local scaleX = 1 + math.abs(sX) * 2
	local scaleY = 1 + math.abs(sY) * 2
	local scale = math.sqrt(scaleX * scaleX + scaleY * scaleY)

	local rDist = (camCF.p - surfaceCF.p):Dot(surfaceCF.LookVector)
	local newFov = 2 * math.atan2(surfaceSize.y / 2, rDist)
	local clampedFov = math.clamp(math.deg(newFov), 1, 120)
	local pDist = surfaceSize.y / 2 / math.tan(math.rad(clampedFov) / 2)
	local adjust = rDist / pDist

	local factor = (newFov > math.rad(120) and adjust or 1) / scale
	local scaleCF = CFrame.new(0, 0, 0, factor, 0, 0, 0, factor, 0, 0, 0, 1)

	return sX, sY, scale, scaleCF, clampedFov
end

return ParallelTasks
