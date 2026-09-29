--!strict
--[[
	Utils

	Helpers to build stencil CFrames: a position on a surface with the UpVector along the surface normal. They work on
	any surface (floors, walls, ceilings, slopes).

	Every function takes an optional `angle` (radians) to spin the stencil around the normal. Pass
	`math.random() * 2 * math.pi` for a random rotation.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local DEFAULT_MAX_DISTANCE = 1000
local DEFAULT_GROUND_DISTANCE = 10

local Utils = {}

-- Raycast params that ignore the local player's character, used when none are given
local function getDefaultParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	if character then
		params.FilterDescendantsInstances = { character }
	end
	return params
end

--[[
	CFrame at `position` with its UpVector along `normal`. Flat ground (normal = +Y) gives an unrotated CFrame.
]]
function Utils.fromNormal(position: Vector3, normal: Vector3, angle: number?): CFrame
	local up = normal.Unit
	-- Any vector not parallel to the normal works as a reference for the other two axes
	local reference = if math.abs(up.Z) < 0.999 then Vector3.zAxis else Vector3.xAxis
	local right = up:Cross(reference).Unit
	local back = right:Cross(up)

	local cframe = CFrame.fromMatrix(position, right, up, back)
	if angle then
		cframe *= CFrame.Angles(0, angle, 0)
	end
	return cframe
end

--[[
	CFrame at the hit point of a raycast, with its UpVector along the hit surface normal.
]]
function Utils.fromRaycastResult(result: RaycastResult, angle: number?): CFrame
	return Utils.fromNormal(result.Position, result.Normal, angle)
end

--[[
	Raycasts from `origin` along `direction` and returns a CFrame on whatever was hit, or nil if nothing was hit.
	`params` defaults to ignoring the local player's character.
]]
function Utils.raycast(origin: Vector3, direction: Vector3, params: RaycastParams?, angle: number?): CFrame?
	local result = workspace:Raycast(origin, direction, params or getDefaultParams())
	return if result then Utils.fromRaycastResult(result, angle) else nil
end

--[[
	Returns a CFrame on whatever is under a point on the screen (in viewport coordinates, like
	UserInputService:GetMouseLocation()), or nil if nothing is there.
]]
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

--[[
	Returns a CFrame on whatever is under the mouse, or nil if nothing is there.
]]
function Utils.fromMouse(params: RaycastParams?, maxDistance: number?, angle: number?): CFrame?
	local location = UserInputService:GetMouseLocation()
	return Utils.fromScreenPoint(location.X, location.Y, params, maxDistance, angle)
end

--[[
	Returns a CFrame on the ground under a character (the local player's by default), or nil if there is no ground
	within `maxDistance` studs below its HumanoidRootPart.
]]
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
