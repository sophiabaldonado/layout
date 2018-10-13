-- Handles dragging and scaling

local Grab = {}

function Grab:init()
  self.drags = {}
  self.scale = nil
end

function Grab:update(dt)
  if self.scale then
    local controller = next(self.drags)
    local otherController = next(self.drags, controller)

    -- Scale the entity
    local x1, y1, z1 = controller:getPosition()
    local x2, y2, z2 = otherController:getPosition()
    local distance = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2 + (z2 - z1) ^ 2)
    local ratio = distance / (self.scale.distance or distance)
    self.scale.entity.scale = self.scale.entity.scale * ratio

    -- Bzz
    self.scale.bzz = self.scale.bzz + math.abs(distance - self.scale.distance)
    if self.scale.bzz >= .1 then
      controller:vibrate(.001)
      otherController:vibrate(.001)
      self.scale.bzz = 0
    end

    -- Set the new reference distance
    self.scale.distance = distance

    -- Don't drag if we're scaling
    return
  end

  -- Now handle drags
  for controller, drag in pairs(self.drags) do

    -- Move the entity
    local x, y, z = controller:getPosition()
    x, y, z = x + drag.offset.x, y + drag.offset.y, z + drag.offset.z
    local dx, dy, dz = x - drag.entity.x, y - drag.entity.y, z - drag.entity.z
    local locked = drag.lock.x or drag.lock.y, drag.lock.z
    local lx, ly, lz = not locked or drag.lock.x, not locked or drag.lock.y, not locked or drag.lock.z
    dx, dy, dz = lx and dx or 0, ly and dy or 0, lz and dz or 0 -- idk if this works
    drag.entity.x, drag.entity.y, drag.entity.z = drag.entity.x + dx, drag.entity.y + dy, drag.entity.z + dz

    -- Bzz every .1m
    drag.bzz = drag.bzz + math.sqrt(dx ^ 2 + dy ^ 2 + dz ^ 2)
    if drag.bzz >= .1 then
      controller:vibrate(.001)
      drag.bzz = 0
    end
  end
end

function Grab:controllerpressed(controller, button)
  if button == 'trigger' then
    local entity = self.layout:getClosestHover(controller)
    if entity then
      self:grab(controller, entity)
    end
  end
end

function Grab:controllerreleased(controller, button)
  if button == 'trigger' and self.drags[controller] then
    self:ungrab(controller)
  end
end

function Grab:grab(controller, entity)
  local _, otherDrag = next(self.drags)
  if otherDrag and otherDrag.entity == entity then
    self.scale = {
      entity = entity,
      bzz = 0
    }
  end

  local x, y, z = controller:getPosition()
  self.drags[controller] = {
    entity = entity,
    offset = { x = entity.x - x, y = entity.y - y, z = entity.z - z },
    lock = { x = false, y = false, z = false },
    bzz = 0
  }
end

function Grab:ungrab(controller)
  self.drags[controller] = nil
  self.scale = nil
  self.layout:dirty()
end

return Grab
