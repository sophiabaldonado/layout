-- What a drag

local maf = require 'maf'

local Drag = {}

Drag.name = 'Drag'
Drag.continuous = true
Drag.context = 'hover'
Drag.button = 'trigger'

function Drag:init()
  self.drags = {}
end

function Drag:start(controller, entity)
  local x, y, z = self.layout:getCursorPosition(controller)
  entity.vx, entity.vy, entity.vz = 0, 0, 0

  -- FIXME we should prevent both controllers from simultaneously having an active drag because
  -- they'll fight over custody
  self.drags[controller] = {
    entity = entity,
    offset = { x = entity.x - x, y = entity.y - y, z = entity.z - z },
    velocity = { x = 0, y = 0, z = 0 },
    lock = { x = false, y = false, z = false },
    bzz = 0
  }
end

function Drag:use(controller, entity, dt)
  local drag = self.drags[controller]
  if not drag then return end

  -- Move the entity
  local entity = drag.entity
  local x, y, z = self.layout:getCursorPosition(controller)
  x, y, z = x + drag.offset.x, y + drag.offset.y, z + drag.offset.z
  local dx, dy, dz = x - entity.x, y - entity.y, z - entity.z
  local locked = drag.lock.x or drag.lock.y or drag.lock.z
  local lx, ly, lz = not locked or drag.lock.x, not locked or drag.lock.y, not locked or drag.lock.z
  dx, dy, dz = lx and dx or 0, ly and dy or 0, lz and dz or 0 -- idk if this works
  entity.x, entity.y, entity.z = entity.x + dx, entity.y + dy, entity.z + dz
  drag.velocity.x, drag.velocity.y, drag.velocity.z = dx / dt, dy / dt, dz / dt
  self.layout:dirty()

  -- Bzz every .1m
  drag.bzz = drag.bzz + math.sqrt(dx ^ 2 + dy ^ 2 + dz ^ 2)
  if drag.bzz >= .1 then
    self.layout:vibrate(controller, .001)
    drag.bzz = 0
  end
end

function Drag:stop(controller, entity)
  local v = self.drags[controller].velocity
  if math.sqrt(maf.vec3(v.x, v.y, v.z):length()) > .5 then
    entity.vx, entity.vy, entity.vz = v.x, v.y, v.z
  end

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

local axisBasis = { x = { 1, 0, 0 }, y = { 0, 1, 0 }, z = { 0, 0, 1 } }
function Drag:draw()
  for controller, drag in pairs(self.drags) do
    local x, y, z = drag.entity.x, drag.entity.y, drag.entity.z

    for axis, locked in pairs(drag.lock) do
      if locked then
        local basis = axisBasis[axis]
        local color = { .3 + .5 * basis[1], .3 + .5 * basis[2], .3 + .5 * basis[3], 1 }
        local xx, yy, zz = basis[1] * 100, basis[2] * 100, basis[3] * 100
        lovr.graphics.setColor(color)
        lovr.graphics.line(x - xx, y - yy, z - zz, x + xx, y + yy, z + zz)
      end
    end
  end
end

return Drag
