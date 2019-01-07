-- Makes my head spin

local Rotate = {}

Rotate.name = 'Rotate'
Rotate.continuous = true
Rotate.context = 'hover'
Rotate.button = 'grip'

function Rotate:init()
  self.lastPosition = lovr.math.vec3()
  self.bzz = 0
end

function Rotate:start(controller, entity)
  self.bzz = 0
end

function Rotate:use(controller, entity, dt)
  self.entity = entity
  local controllerPosition = lovr.math.vec3(self.layout:getCursorPosition(controller))
  local entityPosition = lovr.math.vec3(entity.x, entity.y, entity.z)

  local v1 = controllerPosition - entityPosition
  local v2 = self.lastPosition - entityPosition
  local axis = v2:cross(v1):normalize()
  local angle = math.acos(v2:dot(v1))

  local orientation = lovr.math.quat(entity.angle, entity.ax, entity.ay, entity.az)
  local rotation = lovr.math.quat(angle, axis)
  entity.angle, entity.ax, entity.ay, entity.az = orientation:mul(rotation):unpack()

  self.bzz = self.bzz + angle
  if self.bzz >= .1 then
    self.layout:vibrate(controller, .001)
    self.bzz = 0
  end

  self.lastPosition:set(controllerPosition)
  self.layout:dirty()
end

return Rotate
