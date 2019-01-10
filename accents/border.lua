local Border = {}

function Border:filter(object)
  return object.asset.model
end

function Border:draw(object)
  local model = object.asset.model
  local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
  local min = lovr.math.vec3(minx, miny, minz)
  local max = lovr.math.vec3(maxx, maxy, maxz)

  local size = (max - min) * object.scale
  local center = (max + min) / 2 * object.scale

  lovr.graphics.setColor(1, 1, 1, object.hovered and 1 or .5)
  lovr.graphics.box('line', object.position + center, size, object.rotation)
  lovr.graphics.setColor(1, 1, 1)
end

return Border
