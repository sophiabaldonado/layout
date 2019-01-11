local Nav = {}

function Nav:init()
  self.navs = {}
end

function Nav:update(dt)
  for controller, nav in pairs(self.navs) do
    local function bzz(delta)
      nav.bzz = nav.bzz + delta
      while nav.bzz >= .1 do
        controller:vibrate(.00075)
        nav.bzz = nav.bzz - .1
      end
    end

    local cursor = self.layout:cursorPosition(controller, true)
    self.layout:translate(cursor - nav.position)
    nav.position:set(cursor)
  end
end

function Nav:controllerpressed(controller, button)
  if button == 'grip' then
    self.navs[controller] = {
      position = self.layout:cursorPosition(controller, true):save(),
      bzz = 0
    }
  end
end

function Nav:controllerreleased(controller, button)
  if button == 'grip' and self.navs[controller] then
    self.navs[controller] = nil
  end
end

return Nav
