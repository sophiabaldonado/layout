-- Do you copy

local Copy = {}

Copy.context = 'hover'
Copy.button = 'up'

function Copy:use(controller, entity)
  local x, y, z = self.layout:cursorPos(controller) -- So they don't stack on top of each other
  local scale, angle, ax, ay, az = entity.scale, entity.angle, entity.ax, entity.ay, entity.az
  self.layout:addEntity(entity.kind, x, y, z, scale, angle, ax, ay, az)
end

return Copy
