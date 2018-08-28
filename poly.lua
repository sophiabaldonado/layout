local http = require 'luajit-request'
local json = require 'json'
local pprint = require 'pretty-print'

local poly = {}

function poly:init()
	self.thumbnails = {}
	self.models = {}

	local list = json.decode(http.send('https://poly.googleapis.com/v1/assets?category=food&orderBy=BEST&pageSize=5&key=APIKEY').body)

	self:makeThumbnails(list)
	self:makeModels(list)
end

function poly:makeModels(list)
	local bestTypes = { 'GLTF2', 'GLTF', 'OBJ', 'FBX' }
	local extensions = { GLTF2 = 'gltf', GLTF = 'gltf',  OBJ = 'obj',  FBX = 'fbx' }

	for i = 1, #list.assets do
		local format
		for j = 1, #list.assets[i].formats do
			local formats = list.assets[i].formats
			formats[formats[j].formatType] = formats[j]
		end

		for j = 1, #bestTypes do
			local bestType = list.assets[i].formats[bestTypes[j]]
			if bestType ~= nil then
				format = bestType
				break
			end
		end

		if format ~= nil then
			local assetBlob = lovr.data.newBlob(http.send(format.root.url).body, list.assets[i].name..'.'..extensions[format.formatType])
			local pngBlob = lovr.data.newBlob(http.send(format.resources.url).body)
			local assetMat = lovr.graphics.newMaterial(lovr.graphics.newTexture(pngBlob))
			table.insert(self.models, lovr.graphics.newModel(assetBlob))
		end
	end
end

function poly:makeThumbnails(list)
	for i = 1, #list.assets do
		self.thumbnails[list.assets[i].name] = {}

		local thumbPath = list.assets[i].thumbnail.url
		local thumbBlob = lovr.data.newBlob(http.send(thumbPath).body)
		local thumbMat = lovr.graphics.newMaterial(lovr.graphics.newTexture(thumbBlob))
		self.thumbnails[list.assets[i].name].material = thumbMat
	end
end

function poly:draw()
	-- lovr.graphics.sphere(0, 0, 0, .1)
	-- polyModel:draw(0, 0, -5, .3)

	for i = 1, #self.models do
		print(self.models[i])
		self.models[i]:draw(-3 + (1.25 * i), 1, -2, .15)
	end

	-- local i = 0
	-- for k,v in pairs(self.thumbnails) do
	-- 		lovr.graphics.plane(v.material, -3 + (1.25 * i), 2, -2)
	-- 		i = i + 1
	-- end
end

return poly
