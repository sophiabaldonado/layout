local Model = {}

function Model:filter(object)
  return object.asset.model
end

function Model:draw(object)
  local model = object.asset.model
  local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
  local cx, cy, cz = (minx + maxx) / 2 * object.scale, (miny + maxy) / 2 * object.scale, (minz + maxz) / 2 * object.scale
  lovr.graphics.push()
  lovr.graphics.translate(object.position + lovr.math.vec3(cx, cy, cz))
  lovr.graphics.rotate(object.rotation)
  lovr.graphics.translate(-object.position - lovr.math.vec3(cx, cy, cz))
  model:draw(object.position, object.scale)
  lovr.graphics.pop()
end

return Model
