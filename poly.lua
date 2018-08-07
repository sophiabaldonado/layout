local http = require 'luajit-request'
local json = require 'json'

local poly = {}

function poly:init()
	self.assets = {

	}
	local response = json.decode(http.send('https://poly.googleapis.com/v1/assets/fCT73jIf5jN?key=APIKEY').body)
	local tree = response.formats[1]
	local treeBlob = lovr.data.newBlob(http.send(tree.root.url).body, 'pinetree.obj')
	local pngBlob = lovr.data.newBlob(http.send(tree.resources[2].url).body)
	local treeMat = lovr.graphics.newMaterial(lovr.graphics.newTexture(pngBlob))

	polyModel = lovr.graphics.newModel(treeBlob, treeMat)

	local list = json.decode(http.send('https://poly.googleapis.com/v1/assets?category=food&orderBy=BEST&pageSize=5&key=APIKEY').body)

	self:makeAssets(list)
end

function poly:makeAssets(list)
	for i = 1, #list.assets do
		self.assets[list.assets[i].name] = {}

		local thumbPath = list.assets[i].thumbnail.url
		local thumbBlob = lovr.data.newBlob(http.send(thumbPath).body)
		local thumbMat = lovr.graphics.newMaterial(lovr.graphics.newTexture(thumbBlob))
		self.assets[list.assets[i].name].material = thumbMat
	end
end

function poly:draw()
	lovr.graphics.sphere(0, 0, 0, .1)
	polyModel:draw(0, 0, -5, .3)

	local i = 0
	for k,v in pairs(self.assets) do
			lovr.graphics.plane(v.material, -3 + (1.25 * i), 2, -2)
			i = i + 1
	end
end

return poly
