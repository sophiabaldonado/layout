-- What a drag

local Drag = {}

Drag.name = 'Drag'
Drag.continuous = true
Drag.context = 'hover'
Drag.button = 'trigger'

function Drag:init()
  self.drags = {}
end

function Drag:start(controller, entity)
  local x, y, z = self.layout:cursorPosition(controller)

  -- FIXME we should prevent both controllers from simultaneously having an active drag because
  -- they'll fight over custody
  self.drags[controller] = {
    entity = entity,
    offset = { x = entity.x - x, y = entity.y - y, z = entity.z - z },
    lock = { x = false, y = false, z = false },
    bzz = 0
  }
end

function Drag:use(controller, entity, dt)
  local drag = self.drags[controller]
  if not drag then return end

  -- Move the entity
  local x, y, z = self.layout:cursorPosition(controller)
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

function Drag:stop(controller)
  self.drags[controller] = nil
end

local function axisLock(axis)
  return function(self, controller)
    self.drags[controller].lock[axis] = not self.drags[controller].lock[axis]
  end
end

Drag.modifiers = {
  left = axisLock('x'),
  up = axisLock('y'),
  right = axisLock('z')
}

return Drag
