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

	-- local list = json.decode(http.send('https://poly.googleapis.com/v1/assets?category=food&orderBy=BEST&pageSize=20&key='..bla).body)

	-- self:makeThumbnails(list)
	-- self:makeFormats(list)
	-- polyModel = self:getModel(self.assets[1].name, self.assets[1].format)
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
		self.assets[asset.name] = self.assets[i]
	end
end

function poly:getModels(number)
	local list = json.decode(http.send('https://poly.googleapis.com/v1/assets?category=food&orderBy=BEST&pageSize='..number..'&key='..bla).body)

	self:makeFormats(list)
	for i, asset in ipairs(self.assets) do
		self:getModel(asset.name, asset.format)
	end
	print(#self.assets)
	return self.assets
end

function poly:getModel(name, format)
	if self.models[format] then return self.models[format] end
	local material
	local basePath = 'poly/'..name..'/'
	fs.createDirectory(basePath)
	fs.write(basePath..format.root.relativePath, http.send(format.root.url).body)
	for i, resource in ipairs(format.resources) do
		fs.write(basePath..resource.relativePath, http.send(resource.url).body)
		-- material = lovr.graphics.newMaterial(basePath..resource.relativePath)
	end
	local model = lovr.graphics.newModel(basePath..format.root.relativePath)
	self.models[format] = model
	self.assets[name].model = model
	-- self.assets[name].material = material
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
	local modelSpawn = lovr.math.newTransform(0, 1, -2, .25)
	-- polyModel:draw(modelSpawn)

	--poly:drawThumbnails()
end

function poly:drawThumbnails()
	local j = 0
	for k, v in pairs(self.thumbnails) do
			lovr.graphics.plane(v.material, -3 + (1 * j), 2, -2, .3, .3)
			j = j + .5
	end
end

return poly
