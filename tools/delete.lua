local Delete = {}

function Delete:checkDirection(controller, button)
  return button == 'touchpad' and self.layout.util.touchpadDirection(controller) == 'down'
end

function Delete:controllerpressed(controller, button)
  local object = self.layout.controllers[controller].hover

  if self:checkDirection(controller, button) and object then
    self.target = object
    controller:vibrate(.002)
  end
end

function Delete:controllerreleased(controller, button)
  local object = self.layout.controllers[controller].hover

  if self:checkDirection(controller, button) and object and object == self.target then
    local x, y, z = self.layout.util.cursorPosition(controller):unpack()
    local angle, ax, ay, az = object.rotation:unpack()

    self.layout:dispatch({
      type = 'remove',
      id = object.id
    })

    controller:vibrate(.001)
    self.target = nil
  end
end

return Delete
