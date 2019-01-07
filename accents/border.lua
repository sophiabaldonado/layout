local Border = {}

-- Applies to all entities
Border.filter = function() return true end

function Border:draw(entity)
  -- TODO need easy way to tell if entity is hovered
  local hovered = false
  for k, v in pairs(self.layout.hover) do if v == entity then hovered = true break end end

  local model = self.layout.models[entity.kind]
  local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
  local w, h, d = (maxx - minx) * entity.scale, (maxy - miny) * entity.scale, (maxz - minz) * entity.scale
  local cx, cy, cz = (maxx + minx) / 2 * entity.scale, (maxy + miny) / 2 * entity.scale, (maxz + minz) / 2 * entity.scale
  local r, g, b, a = 1, 1, 1, .3 * (self:isFocused(entity) and 3 or (hovered and 2 or 1))

  lovr.graphics.push()
  lovr.graphics.translate(entity.x, entity.y, entity.z)
  lovr.graphics.translate(cx, cy, cz)
  lovr.graphics.rotate(entity.angle, entity.ax, entity.ay, entity.az)
  lovr.graphics.translate(-cx, -cy, -cz)
  lovr.graphics.setColor(r, g, b, a)
  lovr.graphics.box('line', cx, cy, cz, w, h, d)
  lovr.graphics.pop()
end

return Border
