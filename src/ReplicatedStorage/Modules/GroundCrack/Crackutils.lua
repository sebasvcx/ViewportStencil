local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local Camera = workspace.CurrentCamera

local Crackutils = {}

function Crackutils.CastToMouseCFrame(maxDistance: number?, params: RaycastParams)
	local unitRay = Camera:ScreenPointToRay(Mouse.X, Mouse.Y)
	
	local ray = workspace:Raycast(unitRay.Origin, unitRay.Direction * (maxDistance or 1000), params)
	if ray then
		return CFrame.new(ray.Position, ray.Position + ray.Normal) * CFrame.Angles(-math.pi / 2, 0, 0)
	end
	
	print("Raycast failed")
	return Mouse.Hit
end

function Crackutils.CastToCharacterGroundPosition(rayLength: number?)
	local character = LocalPlayer.Character
	if not character then return end

	local root: BasePart = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}
	
	rayLength = rayLength or 10
	
	local ray = workspace:Raycast(root.Position, Vector3.new(0, -rayLength, 0), params)
	if ray then
		return CFrame.new(ray.Position, ray.Position + ray.Normal) * CFrame.Angles(-math.pi / 2, 0, 0)
	end
	
	print("Raycast failed")
	return root.CFrame
end

return Crackutils
