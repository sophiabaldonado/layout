local Lock = {}

function Lock:checkDirection(controller, button)
  return button == 'touchpad' and self.layout.util.touchpadDirection(controller) == 'up'
end

function Lock:controllerpressed(controller, button)
  local object = self.layout:getClosestHover(controller, true)

  if self:checkDirection(controller, button) and object then
    self.target = object
    controller:vibrate(.002)
  end
end

function Lock:controllerreleased(controller, button)
  local object = self.layout:getClosestHover(controller, true)

  if self:checkDirection(controller, button) and object and object == self.target then
    self.layout:dispatch({
      type = 'setLocked',
      id = object.id,
      locked = not object.locked
    })

    controller:vibrate(.001)
    self.target = nil
  end
end

return Lock
