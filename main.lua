layout = require 'layout'
grid = require 'grid'
json = require 'cjson'
fs = lovr.filesystem

local edit = {}
local controllerModels = {}

function lovr.load()
	edit.active = false
	time = 'night'
	skybox = lovr.graphics.newTexture({
		'sky/'..time..'/left.png',
    'sky/'..time..'/right.png',
    'sky/'..time..'/top.png',
    'sky/'..time..'/bottom.png',
    'sky/'..time..'/back.png',
    'sky/'..time..'/front.png'
  }, { type = 'cube' })

	localGrid = grid.new(5, 5, .25, { .8, .25, .5, .25 })

	local defaultFile = 'default.json'
	local loadFile = fs.isFile(defaultFile) and json.decode(fs.read(defaultFile)) or nil

	layout:init({
	  state = loadFile or {},
	  cursorSize = .03
	  onChange = function(state) end
	  onHover = function(entity, controller) end
	})
end

function lovr.update(dt)
	if edit.active == true then
		layout:update(dt)
	end
end

function lovr.draw()
	lovr.graphics.skybox(skybox)
	lovr.graphics.setColor(.078, .078, .098)
	lovr.graphics.circle('fill', 0, 0, 0, 10, math.pi / 2, 1, 0, 0)
	lovr.graphics.setColor(1, 1, 1)
	localGrid:draw()

	for _, controller in ipairs(lovr.headset.getControllers()) do
    local x, y, z = controller:getPosition()
    local angle, ax, ay, az = controller:getOrientation()
    controllerModels[controller] = controllerModels[controller] or controller:newModel()
		if not controllerModels[controller] then return end
		controllerModels[controller]:draw(x, y, z, 1, angle, ax, ay, az)
  end

	if edit.active == true then
  	layout:draw()
	end
end

function lovr.controlleradded(...)
	if edit.active == true then
		layout:controlleradded(...)
	end
end

function lovr.controllerremoved(...)
	if edit.active == true then
		layout:controllerremoved(...)
	end
end

function lovr.controllerpressed(...)
	if edit.active == true then
		layout:controllerpressed(...)
	elseif button == 'menu' then
		edit.active = true
	end
end

function lovr.controllerreleased(...)
	if edit.active == true then
		layout:controllerreleased(...)
	end
end

function lovr.quit()
	saveLevel(layout.state)
end

function saveLevel(levelData)
	local filename = os.date('%m-%d-%Y_%I%M%p')..'.json'
	print(filename)
	fs.write(filename, json.encode(levelData))
end
