-- local http = require 'http.request'

-- if enablePoly then local poly = require 'poly' end -- TODO: check conf for enablePoly

local loader = {}

function loader:init()
	self.entityTypes = {}
	self.itemSize = .09

	if poly then
		self:loadPolyModels()
	end
	self:loadLocalModels()
end

function loader:loadLocalModels()
  local path = 'models'
  local files = lovr.filesystem.getDirectoryItems(path)

  for i, file in ipairs(files) do
    if file:match('%.obj$') or file:match('%.gltf$') or file:match('%.fbx$') or file:match('%.dae$') then
      local id = file:gsub('%.%a+$', '')
      local modelPath = path .. '/' .. file
      local model = lovr.graphics.newModel(modelPath)
      model:setMaterial(self.mainMaterial)
			local baseScale = self:getBaseScale(model)

      self.entityTypes[id] = {
        model = model,
        baseScale = baseScale
      }
			-- print(id)
      table.insert(self.entityTypes, id)
    end
  end
end

function loader:loadPolyModels()
	-- make http request to Poly API
	-- loop response?
		local id = "temp" -- model.name? model.id?
		local model = "temp" --model from poly
		local baseScale = self:getBaseScale(model)

		self.entityTypes[id] = {
			model = model,
			baseScale = baseScale
		}
		table.insert(self.entityTypes, id)
	-- end
end

function loader:getBaseScale(model)
	local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
	local width, height, depth = maxx - minx, maxy - miny, maxz - minz
	return self.itemSize / math.max(width, height, depth)
end

function loader:getEntityById(typeId)
	return self.entityTypes[typeId]
end

function loader:getEntityByIndex(index)
	return self.entityTypes[index]
end



return loader
