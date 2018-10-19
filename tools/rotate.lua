-- Makes my head spin

local maf = require 'maf'

local Rotate = {}

Rotate.continuous = true
Rotate.context = 'hover'
Rotate.button = 'grip'

function Rotate:init()
  self.position = maf.vec3()
  self.lastPosition = maf.vec3()
  self.bzz = 0
end

function Rotate:start(controller, entity)
  self.position:set(controller:getPosition())
  self.lastPosition:set(self.position)
  self.bzz = 0
end

local origin = maf.vec3()
local dir1 = maf.vec3()
local dir2 = maf.vec3()
local delta = maf.quat()
local oldRotation = maf.quat()
function Rotate:use(controller, entity, dt)
  local scale = entity.scale
  local minx, maxx, miny, maxy, minz, maxz = entity.model:getAABB()
  local cx, cy, cz = (minx + maxx) / 2 * scale, (miny + maxy) / 2 * scale, (minz + maxz) / 2 * scale
  origin:set(entity.x + cx, entity.y + cy, entity.z + cz)
  self.position:set(controller:getPosition())
  dir1:set(self.lastPosition):sub(origin):normalize()
  dir2:set(self.position):sub(origin):normalize()
  delta:between(d2, d1)

  self.bzz = self.bzz + self.position:distance(self.lastPosition)
  if self.bzz >= .1 then
    controller:vibrate(.001)
    self.bzz = 0
  end

  oldRotation:angleAxis(entity.angle, entity.ax, entity.ay, entity.az)
  entity.angle, entity.ax, entity.ay, entity.az = (delta * oldRotation):getAngleAxis()
  self.lastPosition:set(self.position)
end

return Rotate
