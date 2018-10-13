local Copy = {}

Copy.direction = 'up'

function Copy:controllerpressed(controller, button)
  if button ~= 'touchpad' or self.layout:getTouchpadDirection(controller) ~= self.direction then return end

  local entity = self.layout:getClosestHover(controller)
  if entity and not entity.focused and not entity.locked then
    local x, y, z = entity.x + .1, entity.y + .1, entity.z + .1
    local scale = entity.scale
    local angle, ax, ay, az = entity.angle, entity.ax, entity.ay, entity.az
    self.layout:addEntity(entity.kind, x, y, z, scale, angle, ax, ay, az)
  end
end

return Copy
