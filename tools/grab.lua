local Grab = {}

function Grab:init()
  self.grabs = {}
end

function Grab:update(dt)
  for controller, grab in pairs(self.grabs) do
    local cursor = self.layout.util.cursorPosition(controller)
    local target = cursor + grab.offset
    local delta = grab.object.position:distance(target)
    grab.object.position:set(target)

    grab.bzz = grab.bzz + delta
    if grab.bzz >= .1 then
      controller:vibrate(.00075)
      grab.bzz = 0
    end
  end
end

function Grab:controllerpressed(controller, button)
  if button == 'trigger' and self.layout.controllers[controller].hover then
    local object = self.layout.controllers[controller].hover

    self.grabs[controller] = {
      object = object,
      offset = object.position:copy():sub(self.layout.util.cursorPosition(controller)):save(),
      bzz = 0
    }

    controller:vibrate(.003)
  end
end

function Grab:controllerreleased(controller, button)
  if button == 'trigger' and self.grabs[controller] then
    local object = self.grabs[controller].object
    local x, y, z = object.position:unpack()

    self.layout:dispatch({
      type = 'move',
      id = object.id,
      x = x, y = y, z = z
    })

    self.grabs[controller] = nil
  end
end

return Grab
