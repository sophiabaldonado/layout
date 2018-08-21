-- What a drag

local Drag = {}

function Drag:init()
  self.active = false
  self.entity = nil
  self.controller = nil
  self.offset = { x = 0, y = 0, z = 0 }
  self.lock = { x = false, y = false, z = false }
  self.bzz = 0
end

function Drag:update(dt)
  if not self.active then return end

  -- TODO handle scale case where other:isDown('trigger')
  local other = self.layout:getOtherController(controller)

  -- Move the entity
  local x, y, z = controller:getPosition()
  x, y, z = x + self.offset.x, y + self.offset.y, z + self.offset.z
  local dx, dy, dz = x - self.entity.x, y - self.entity.y, z - self.entity.z
  local locked = next(self.lock)
  local lx, ly, lz = not locked or self.lock.x, not locked or self.lock.y, not locked or self.lock.z
  dx, dy, dz = lx and dx or 0, ly and dy or 0, lz and dz or 0 -- idk if this works
  self.entity.x, self.entity.y, self.entity.z = self.entity.x + dx, self.entity.y + dy, self.entity.z + dz

  -- Bzz every .1m
  self.bzz = self.bzz + math.sqrt(dx ^ 2 + dy ^ 2 + dz ^ 2)
  if self.bzz >= .1 then
    self.controller:vibrate(.001)
    self.bzz = 0
  end
end

function Drag:controllerpressed(controller, button)
  if button == 'trigger' then
    local entity = self.layout:getClosestEntity(controller)
    if entity and entity:isHoveredBy(controller) then
      self:grab(entity, controller)
    end
  end
end

function Drag:controllerreleased(controller, button)
  if button == 'trigger' and controller == self.controller then
    self:ungrab()
  end
end

function Drag:grab(entity, controller)
  self.active = true
  self.entity = entity
  self.controller = controller

  local x, y, z = controller:getPosition()
  self.offset.x, self.offset.y, self.offset.z = entity.x - x, entity.y - y, entity.z - z
end

function Drag:ungrab()
  self.active = false
  self.entity, self.controller = nil, nil
  self.offset.x, self.offset.y, self.offset.z = 0, 0, 0
  self.layout:dirty()
end

return Drag
