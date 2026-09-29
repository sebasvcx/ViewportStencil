local bufferManager = {}
bufferManager.__index = bufferManager

function bufferManager.new(createFunc)
	local self = setmetatable({
		pool = {},
		createFunc = createFunc
	}, bufferManager)
	
	return self
end

function bufferManager:get()
	if #self.pool > 0 then
		return table.remove(self.pool)
	else
		return self.createFunc()
	end
end

function bufferManager:release(object)
	table.insert(self.pool, object)

	object.Parent = nil
end

return bufferManager
