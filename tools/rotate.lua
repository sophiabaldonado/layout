-- Makes my head spin

local maf = require 'maf'

local Rotate = {}

function Rotate:init()
  self.active = false
  self.entity = nil
  self.controller = nil
  self.position = maf.vec3()
  self.lastPosition = maf.vec3()
  self.bzz = 0
end

local origin = maf.vec3()
local dir1 = maf.vec3()
local dir2 = maf.vec3()
local delta = maf.quat()
local oldRotation = maf.quat()
function Rotate:update(dt)
  if not self.entity then return end

  local scale = self.entity.scale
  local minx, maxx, miny, maxy, minz, maxz = self.entity.model:getAABB()
  local cx, cy, cz = (minx + maxx) / 2 * scale, (miny + maxy) / 2 * scale, (minz + maxz) / 2 * scale
  origin:set(self.entity.x + cx, self.entity.y + cy, self.entity.z + cz)

  self.position:set(controller:getPosition())

  dir1:set(self.lastPosition):sub(origin):normalize()
  dir2:set(self.position):sub(origin):normalize()
  delta:between(d2, d1)

  self.bzz = self.bzz + self.position:distance(self.lastPosition)
  if self.bzz >= .1 then
    self.controller:vibrate(.001)
    self.bzz = 0
  end

  oldRotation:angleAxis(self.entity.angle, self.entity.ax, self.entity.ay, self.entity.az)
  self.entity.angle, self.entity.ax, self.entity.ay, self.entity.az = (delta * oldRotation):getAngleAxis()

  self.lastPosition:set(self.position)
end

function Rotate:controllerpressed(controller, button)
  if button == 'trigger' then
    local entity = self.layout:getClosestEntity(controller)
    if entity then
      self.active = true
      self.entity = entity
      self.controller = controller
      self.lastPosition:set(controller:getPosition())
      self.position:set(controller:getPosition())
    end
  end
end

function Rotate:controllerreleased(controller, button)
  if button == 'trigger' and self.drags[controller] then
    self.active = false
    self.layout:dirty()
  end
end

return Rotate
