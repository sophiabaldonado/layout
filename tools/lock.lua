local Lock = {}

Lock.direction = 'right'

function Lock:controllerpressed(controller, button)
  if button ~= 'touchpad' or self.layout:getTouchpadDirection(controller) ~= self.direction then return end

  local entity = self.layout:getClosestHover(controller)
  if entity and not entity.focused then
    self.layout:setLock(entity, not entity.locked)
  end
end

return Lock
