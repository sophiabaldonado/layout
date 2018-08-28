local http = require 'luajit-request'
local json = require 'json'
local pprint = require 'pretty-print'
local fs = lovr.filesystem

local poly = {}

function poly:init()
	self.thumbnails = {}
	self.formats = {}
	self.models = {}
	self.assets = {}

	local list = json.decode(http.send('https://poly.googleapis.com/v1/assets?category=food&orderBy=BEST&pageSize=5&key=APIKEY').body)

	self:makeThumbnails(list)
	self:makeFormats(list)
	polyModel = self:getModel(self.assets[1].name, self.assets[1].format)
end

function poly:makeFormats(list)
	local bestTypes = { 'OBJ', 'FBX' } -- { 'GLTF2', 'GLTF', 'OBJ', 'FBX' }
	local extensions = { GLTF2 = 'gltf', GLTF = 'gltf',  OBJ = 'obj',  FBX = 'fbx' }

	for i, asset in ipairs(list.assets) do
		self.assets[i] = {}
		self.assets[i].name = asset.name
		self.assets[i].displayName = asset.displayName
		local format
		local formats = asset.formats
		for j = 1, #formats do
			formats[formats[j].formatType] = formats[j]
		end

		for j, type in ipairs(bestTypes) do
			local bestType = formats[type]
			if bestType then
				format = bestType
				break
			end
		end

		if format then
			self.assets[i].format = format
			self.formats[asset.name] = format
		end
	end
end

function poly:getModel(name, format)
	if self.models[format] then return self.models[format] end
	local basePath = name..'/'

	fs.createDirectory(basePath)
	fs.write(basePath..format.root.relativePath, http.send(format.root.url).body)
	for i, resource in ipairs(format.resources) do
		fs.write(basePath..resource.relativePath, http.send(resource.url).body)
	end
	local model = lovr.graphics.newModel(basePath..format.root.relativePath)
	self.models[format] = model
	return model
end

function poly:makeThumbnails(list)
	for i, asset in ipairs(list.assets) do
		self.thumbnails[asset.name] = {}

		local thumbPath = asset.thumbnail.url
		local thumbBlob = lovr.data.newBlob(http.send(thumbPath).body)
		local thumbMat = lovr.graphics.newMaterial(lovr.graphics.newTexture(thumbBlob))
		self.thumbnails[asset.name].material = thumbMat
	end
end

function poly:draw()
	polyModel:draw(0, 1, -2, .25)

	local j = 0
	for k, v in pairs(self.thumbnails) do
			lovr.graphics.plane(v.material, -3 + (1 * j), 2, -2)
			j = j + 1
	end
end

return poly
