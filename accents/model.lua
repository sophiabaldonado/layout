local Model = {}

function Model:filter(object)
  return object.model
end

function Model:draw(object)
  local model = object.model
  local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
  local cx, cy, cz = (minx + maxx) / 2 * object.scale, (miny + maxy) / 2 * object.scale, (minz + maxz) / 2 * object.scale
  lovr.graphics.push()
  lovr.graphics.translate(object.x + cx, object.y + cy, object.z + cz)
  lovr.graphics.rotate(object.angle, object.ax, object.ay, object.az)
  lovr.graphics.translate(-object.x - cx, -object.y - cy, -object.z - cz)
  model:draw(object.x, object.y, object.z, object.scale)
  lovr.graphics.pop()
end

return Model
