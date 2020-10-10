-- Makes my head spin

local Rotate = {}

Rotate.name = 'Rotate'
Rotate.continuous = true
Rotate.context = 'hover'
Rotate.button = 'grip'
Rotate.icon = 'rotate.png'

function Rotate:init()
  self.position = lovr.math.newVec3()
  self.lastPosition = lovr.math.newVec3()
  self.bzz = 0
  self.axis = lovr.math.newVec3()
end

function Rotate:start(controller, entity)
  self.position:set(self.layout:getCursorPosition(controller))
  self.position:sub(vec3(entity.x, entity.y, entity.z))
  self.lastPosition:set(self.position)
  self.bzz = 0
end

function Rotate:use(controller, entity, dt)
  local orientation = quat()
  local rotation = quat()
  self.entity = entity
  self.position:set(self.layout:getCursorPosition(controller))

  local v1 = vec3(self.position.x, self.position.y, self.position.z):sub(vec3(entity.x, entity.y, entity.z)):normalize()
  local v2 = vec3(self.lastPosition.x, self.lastPosition.y, self.lastPosition.z):sub(vec3(entity.x, entity.y, entity.z)):normalize()

  self.axis:set(v2):cross(v1):normalize()
  local angle = math.acos(v2:dot(v1))
  orientation:set(entity.angle, entity.ax, entity.ay, entity.az)
  rotation:set(angle, self.axis:unpack())
  rotation:mul(orientation)

  self.bzz = self.bzz + angle
  if self.bzz >= .1 then
    self.layout:vibrate(controller, .25, .001)
    self.bzz = 0
  end

  entity.angle, entity.ax, entity.ay, entity.az = rotation:unpack()
  self.lastPosition:set(self.position)
  self.layout:dirty()
end

return Rotate
