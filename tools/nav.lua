local Nav = {}

function Nav:init()
  self.navs = {}
end

function Nav:update(dt)
  for hand, nav in pairs(self.navs) do
    local function bzz(delta)
      nav.bzz = nav.bzz + delta
      while nav.bzz >= .1 do
        lovr.headset.vibrate(hand, .00075)
        nav.bzz = nav.bzz - .1
      end
    end

    local cursor = self.layout:cursorPosition(hand, true)
    self.layout:translate(cursor - nav.position)
    nav.position:set(cursor)
  end
end

function Nav:controllerpressed(hand, button)
  if button == 'grip' then
    self.navs[hand] = {
      position = self.layout:cursorPosition(hand, true),
      bzz = 0
    }
  end
end

function Nav:controllerreleased(hand, button)
  if button == 'grip' and self.navs[hand] then
    self.navs[hand] = nil
  end
end

return Nav
