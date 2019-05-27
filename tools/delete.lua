local Delete = {}

function Delete:checkDirection(hand, button)
  return button == 'touchpad' and self.layout:touchpadDirection(hand) == 'down'
end

function Delete:controllerpressed(hand, button)
  local object = self.layout.hands[hand].hover

  if self:checkDirection(hand, button) and object then
    self.target = object
    lovr.headset.vibrate(hand, .002)
  end
end

function Delete:controllerreleased(hand, button)
  local object = self.layout.hands[hand].hover

  if self:checkDirection(hand, button) and object and object == self.target then
    local x, y, z = self.layout:cursorPosition(hand):unpack()
    local angle, ax, ay, az = object.rotation:unpack()

    self.layout:dispatch({
      type = 'remove',
      id = object.id
    })

    lovr.headset.vibrate(hand, .001)
    self.target = nil
  end
end

return Delete
