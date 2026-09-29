local CrackManager = {}
local ActiveCracks = {}

function CrackManager:add(crack)
	table.insert(ActiveCracks, crack)
end

function CrackManager:remove(crack)
	for i, v in ipairs(ActiveCracks) do
		if v == crack then
			if i ~= #ActiveCracks then
				ActiveCracks[i] = ActiveCracks[#ActiveCracks]
			end
			
			ActiveCracks[#ActiveCracks] = nil
			break
		end
	end
end

function CrackManager:updateAllCameras(camera)
	for _, crack in ipairs(ActiveCracks) do
		crack:updateCamera(camera)
	end
end

function CrackManager:getActiveCracks()
	return ActiveCracks
end

function CrackManager:clearAll()
	for i = #ActiveCracks, 1, -1 do
		ActiveCracks[i]:Destroy()
	end
	ActiveCracks = {}
end

return CrackManager
