local Lock = {}

function Lock:checkDirection(hand, button)
  return button == 'touchpad' and self.layout:touchpadDirection(hand) == 'up'
end

function Lock:controllerpressed(hand, button)
  local object = self.layout:getClosestHover(hand, true)

  if self:checkDirection(hand, button) and object then
    self.target = object
    lovr.headset.vibrate(hand, .002)
  end
end

function Lock:controllerreleased(hand, button)
  local object = self.layout:getClosestHover(hand, true)

  if self:checkDirection(hand, button) and object and object == self.target then
    self.layout:dispatch({
      type = 'setLocked',
      id = object.id,
      locked = not object.locked
    })

    lovr.headset.vibrate(hand, .001)
    self.target = nil
  end
end

return Lock
