local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Assets = ReplicatedStorage:WaitForChild("Assets")

local ViewportStencil = require(Modules.ViewportStencil)

local LIFETIME = 10

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	local cframe = ViewportStencil.Utils.fromMouse(nil, nil, math.random() * 2 * math.pi)
	if not cframe then
		return
	end

	ViewportStencil.new(Assets.Crack["Model(neon1)"]:Clone(), cframe, { lifetime = LIFETIME })

	local vfx = Assets.Crack.VFX:Clone()
	vfx.CFrame = cframe
	vfx.Parent = workspace
	task.delay(LIFETIME, vfx.Destroy, vfx)
end)
