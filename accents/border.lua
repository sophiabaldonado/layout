local Border = {}

function Border:filter(object)
  return object.model
end

function Border:draw(object)
  -- TODO need easy way to tell if object is hovered
  local hovered = false
  for k, v in pairs(self.layout.hover) do if v == object then hovered = true break end end

  local model = object.model
  local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
  local w, h, d = (maxx - minx) * object.scale, (maxy - miny) * object.scale, (maxz - minz) * object.scale
  local cx, cy, cz = (maxx + minx) / 2 * object.scale, (maxy + miny) / 2 * object.scale, (maxz + minz) / 2 * object.scale
  local r, g, b, a = 1, 1, 1, .3 * (self:isFocused(object) and 3 or (hovered and 2 or 1))

  lovr.graphics.push()
  lovr.graphics.translate(object.x, object.y, object.z)
  lovr.graphics.translate(cx, cy, cz)
  lovr.graphics.rotate(object.angle, object.ax, object.ay, object.az)
  lovr.graphics.translate(-cx, -cy, -cz)
  lovr.graphics.setColor(r, g, b, a)
  lovr.graphics.box('line', cx, cy, cz, w, h, d)
  lovr.graphics.pop()
end

return Border
