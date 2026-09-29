--!strict
-- Helpers to get stencil CFrames from raycasts. `angle` (radians) spins the stencil around the surface normal.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local DEFAULT_MAX_DISTANCE = 1000
local DEFAULT_GROUND_DISTANCE = 10

local Utils = {}

local function getDefaultParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	if character then
		params.FilterDescendantsInstances = { character }
	end
	return params
end

-- CFrame at `position` with its UpVector along `normal`. A +Y normal gives an unrotated CFrame.
function Utils.fromNormal(position: Vector3, normal: Vector3, angle: number?): CFrame
	local up = normal.Unit
	local reference = if math.abs(up.Z) < 0.999 then Vector3.zAxis else Vector3.xAxis
	local right = up:Cross(reference).Unit
	local back = right:Cross(up)

	local cframe = CFrame.fromMatrix(position, right, up, back)
	if angle then
		cframe *= CFrame.Angles(0, angle, 0)
	end
	return cframe
end

function Utils.fromRaycastResult(result: RaycastResult, angle: number?): CFrame
	return Utils.fromNormal(result.Position, result.Normal, angle)
end

-- `params` defaults to ignoring the local player's character. Returns nil if nothing was hit.
function Utils.raycast(origin: Vector3, direction: Vector3, params: RaycastParams?, angle: number?): CFrame?
	local result = workspace:Raycast(origin, direction, params or getDefaultParams())
	return if result then Utils.fromRaycastResult(result, angle) else nil
end

-- `x` and `y` are in viewport coordinates, like UserInputService:GetMouseLocation().
function Utils.fromScreenPoint(
	x: number,
	y: number,
	params: RaycastParams?,
	maxDistance: number?,
	angle: number?
): CFrame?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ViewportPointToRay(x, y)
	return Utils.raycast(ray.Origin, ray.Direction * (maxDistance or DEFAULT_MAX_DISTANCE), params, angle)
end

function Utils.fromMouse(params: RaycastParams?, maxDistance: number?, angle: number?): CFrame?
	local location = UserInputService:GetMouseLocation()
	return Utils.fromScreenPoint(location.X, location.Y, params, maxDistance, angle)
end

-- Ground under a character's HumanoidRootPart (the local player's by default).
function Utils.belowCharacter(character: Model?, maxDistance: number?, angle: number?): CFrame?
	local target = character or (Players.LocalPlayer and Players.LocalPlayer.Character)
	if not target then
		return nil
	end

	local root = target:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { target }

	local direction = Vector3.new(0, -(maxDistance or DEFAULT_GROUND_DISTANCE), 0)
	return Utils.raycast(root.Position, direction, params, angle)
end

return Utils
