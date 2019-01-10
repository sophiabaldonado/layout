local Copy = {}

function Copy:checkDirection(controller, button)
  return button == 'touchpad' and self.layout.util.touchpadDirection(controller) == 'up'
end

function Copy:controllerpressed(controller, button)
  local object = self.layout.controllers[controller].hover

  if self:checkDirection(controller, button) and object then
    self.target = object
    controller:vibrate(.002)
  end
end

function Copy:controllerreleased(controller, button)
  local object = self.layout.controllers[controller].hover

  if self:checkDirection(controller, button) and object and object == self.target then
    local x, y, z = self.layout.util.cursorPosition(controller):unpack()
    local angle, ax, ay, az = object.rotation:unpack()

    self.layout:dispatch({
      type = 'add',
      asset = object.asset.key,
      x = x, y = y, z = z, scale = object.scale,
      angle = angle, ax = ax, ay = ay, az = az
    })

    controller:vibrate(.001)
    self.target = nil
  end
end

return Copy
