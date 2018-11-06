-- Makes my head spin

local maf = require 'maf'

local Rotate = {}

Rotate.name = 'Rotate'
Rotate.continuous = true
Rotate.context = 'hover'
Rotate.button = 'grip'

function Rotate:init()
  self.position = maf.vec3()
  self.lastPosition = maf.vec3()
  self.bzz = 0
end

function Rotate:start(controller, entity)
  self.position:set(self.layout:getCursorPosition(controller))
  self.lastPosition:set(self.position)
  self.bzz = 0
end

local axis = maf.vec3()
local orientation = maf.quat()
local rotation = maf.quat()
function Rotate:use(controller, entity, dt)
  self.position:set(self.layout:getCursorPosition(controller))
  self.lastPosition:cross(self.position, axis)
  local angle = self.position:distance(self.lastPosition)
  orientation:angleAxis(entity.angle, entity.ax, entity.ay, entity.az)
  rotation:angleAxis(angle, axis)
  orientation:mul(rotation)

  self.bzz = self.bzz + angle
  if self.bzz >= .1 then
    self.layout:vibrate(controller, .001)
    self.bzz = 0
  end

  entity.angle, entity.ax, entity.ay, entity.az = orientation:getAngleAxis()
  self.lastPosition:set(self.position)
  self.layout:dirty()
end

return Rotate
