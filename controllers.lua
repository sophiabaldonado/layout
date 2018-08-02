local maf = require 'maf'
local vector = maf.vector
local quat = maf.quat

local controllers = {}

function controllers:init()
	self:refreshControllers()
end

function controllers:get()
		if not self.controllers then
			self:init()
		end
		return self.controllers
end

function controllers:controlleradded(controller)
  self:refreshControllers()
end

function controllers:controllerremoved(controller)
  self:refreshControllers()
end

function controllers:refreshControllers()
  self.controllers = {}
	print('YO')

  for i, controller in ipairs(lovr.headset.getControllers()) do
    self.controllers[controller] = {
      index = i,
      object = controller,
      model = lovr.graphics.newModel('toolsUI/controller.obj', 'toolsUI/controller.png'),
      currentPosition = vector(),
      lastPosition = vector(),
      activeEntity = nil,
      drag = {
        active = false,
        offset = vector(),
        counter = 0
      },
      scale = {
        active = false,
        lastDistance = 0,
        counter = 0
      },
      rotate = {
        active = false,
        original = quat(),
        originalPosition = vector(),
        counter = 0
      }
    }
    table.insert(self.controllers, controller)
  end
end

function controllers:updateControllers()
  util.each(self.controllers, function(controller)
		local controller = self.controllers[controller]
		controller.currentPosition:set(self:cursorPos(controller.object))

    if self.resizeWorld then self:updateResizeWorld(controller) end

    if controller.drag.active then self:updateDrag(controller) end
    if controller.rotate.active then self:updateRotate(controller) end
    if controller.scale.active then self:updateScale(controller) end

    controller.lastPosition:set(controller.currentPosition)
  end, ipairs)
end

return controllers
