local Copy = {}

function Copy:checkDirection(hand, button)
  return button == 'touchpad' and self.layout:touchpadDirection(hand) == 'right'
end

function Copy:controllerpressed(hand, button)
  local object = self.layout.hands[hand].hover

  if self:checkDirection(hand, button) and object then
    self.target = object
    lovr.headset.vibrate(hand, .002)
  end
end

function Copy:controllerreleased(controller, button)
  local object = self.layout.hands[hand].hover

  if self:checkDirection(hand, button) and object and object == self.target then
    local x, y, z = self.layout:cursorPosition(hand):unpack()
    local angle, ax, ay, az = object.rotation:unpack()

    self.layout:dispatch({
      type = 'add',
      asset = object.asset.key,
      x = x, y = y, z = z, scale = object.scale,
      angle = angle, ax = ax, ay = ay, az = az
    })

    lovr.headset.vibrate(hand, .001)
    self.target = nil
  end
end

return Copy
