local Grab = {}

function Grab:init()
  self.grabs = {}
end

function Grab:update(dt)
  for hand, grab in pairs(self.grabs) do
    local function bzz(delta)
      grab.bzz = grab.bzz + delta
      while grab.bzz >= .1 do
        lovr.headset.vibrate(hand, .00075)
        grab.bzz = grab.bzz - .1
      end
    end

    local object = grab.object
    local other = self.layout.hands[hand].other
    local scale = self.grabs[other] and self.grabs[other].object == object
    local cursor = self.layout:cursorPosition(hand)

    if scale then
      local distance = cursor:distance(self.layout:cursorPosition(other))
      local lastDistance = grab.distance or distance
      local delta = math.abs(distance - lastDistance)
      local factor = distance / lastDistance
      object.scale = object.scale * factor
      grab.distance = distance
      bzz(delta)

      local otherCursor = self.layout:cursorPosition(other)
      local otherGrab = self.grabs[other]

      local d1 = grab.lastPosition:copy(self.layout.pool):sub(otherGrab.lastPosition):normalize()
      local d2 = cursor:copy(self.layout.pool):sub(otherCursor):normalize()
      local angle = math.acos(d1:dot(d2))
      local axis = d1:cross(d2):normalize()

      if angle == angle then
        local rotation = self.layout.pool:quat(angle, axis)
        object.rotation:set(rotation:mul(object.rotation)):normalize()
      end

      grab.lastPosition:set(cursor)
      otherGrab.lastPosition:set(otherCursor)
      break
    else
      local target = cursor:add(grab.offset)
      local delta = object.position:distance(target)
      object.position:set(target)
      bzz(delta)
    end
  end
end

function Grab:controllerpressed(hand, button)
  if button == 'trigger' and self.layout.hands[hand].hover then
    local object = self.layout.hands[hand].hover
    local cursor = self.layout:cursorPosition(hand)

    self.grabs[hand] = {
      object = object,
      offset = object.position:copy():sub(cursor):save(),
      lastPosition = cursor:save(),
      distance = nil,
      bzz = 0
    }

    lovr.headset.vibrate(hand, .002)
  end
end

function Grab:controllerreleased(hand, button)
  if button == 'trigger' and self.grabs[hand] then
    local other = self.layout.hands[hand].other
    local object = self.grabs[hand].object
    local x, y, z = object.position:unpack()
    local angle, ax, ay, az = object.rotation:unpack()

    self.grabs[hand] = nil

    if other and self.grabs[other] and self.grabs[other].object == object then
      self.grabs[other].offset:set(x, y, z):sub(self.layout:cursorPosition(other))
      self.grabs[other].distance = nil
    else
      self.layout:dispatch({
        type = 'transform',
        id = object.id,
        x = x, y = y, z = z,
        scale = object.scale,
        angle = angle, ax = ax, ay = ay, az = az
      })
    end
  end
end

return Grab
