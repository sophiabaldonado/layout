local util = {}

function util.getModelBox(model, scale)
  scale = scale or 1
  local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
  local min = lovr.math.vec3(minx, miny, minz)
  local max = lovr.math.vec3(maxx, maxy, maxz)
  local center = (max + min) / 2
  local size = max - min
  return center:mul(scale), size:mul(scale)
end

function util.testPointBox(point, position, rotation, scale)
  local transform = lovr.math.mat4()
  transform:translate(position)
  transform:rotate(rotation)
  transform:scale(scale)
  transform:invert()
  x, y, z = transform:transformPoint(point)
  return x >= -.5 and y >= -.5 and z >= -.5 and x <= .5 and y <= .5 and z <= .5
end

function util.cursorPosition(controller)
  local offset = .075
  local position = lovr.math.vec3(controller:getPosition())
  local direction = lovr.math.vec3(lovr.math.orientationToDirection(controller:getOrientation()))
  return position:add(direction:mul(offset))
end

function util.touchpadDirection(controller)
  if not controller:isTouched('touchpad') then return nil end
  local x, y = controller:getAxis('touchx'), controller:getAxis('touchy')
  local angle = math.atan2(y, x)
  local quadrant = math.floor((angle % (2 * math.pi) + (math.pi / 4)) / (math.pi / 2))
  return ({ [0] = 'right', [1] = 'up', [2] = 'left', [3] = 'down' })[quadrant]
end

return util
