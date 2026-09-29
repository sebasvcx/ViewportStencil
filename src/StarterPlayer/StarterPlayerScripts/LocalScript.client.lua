local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Assets = ReplicatedStorage:WaitForChild("Assets")

local crack = require(Modules.GroundCrack)
local crackUtils = require(Modules.GroundCrack.Crackutils)

local a = false
Mouse.Button1Down:Connect(function()
	if not a then
		--a = true
		
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {LocalPlayer.Character}
		
		local new = crack.new(Assets.Crack["Model(neon1)"]:Clone(), crackUtils.CastToMouseCFrame(nil, params))
		--new.SurfaceGui.Brightness = math.random(1, 20)
		--new.Model:ScaleTo(15)
		--new:setSize(Vector3.new(new.Model:GetExtentsSize().X, .1, new.Model:GetExtentsSize().Z))
		--new:setCFrame(new.CFrame)
		--new.SurfaceGui.PixelsPerStud = 1000
		
		local vfx = Assets.Crack.VFX:Clone()
		vfx.Parent = workspace.VFX
		vfx.CFrame = new:getCFrame()

		task.wait(10)
		
		vfx:Destroy()
		new:Destroy()
	end
end)
	