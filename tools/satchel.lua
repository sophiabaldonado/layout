local maf = require 'maf'

local Satchel = {}

Satchel.itemSize = .09

function Satchel:init()
  self.active = false
  self.controller = nil
  self.transform = lovr.math.newTransform()
  self.yaw = 0
end

function Satchel:update(dt)
  if self.active and self.controller then
    self:updatePosition()
  end
end

function Satchel:draw()
  if not self.active then return end

  lovr.graphics.push()
  lovr.graphics.transform(self.transform)

  for i, kind, x, y in self:items() do
    local model = self.layout.models[kind]
    local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
    local width, height, depth = maxx - minx, maxy - miny, maxz - minz
    local scale = self.itemSize / math.max(width, height, depth)
    local cx, cy, cz = (minx + maxx) / 2 * scale, (miny + maxy) / 2 * scale, (minz + maxz) / 2 * scale
    model:draw(x - cx, y - cy, 0 - cz, scale, lovr.timer.getTime() * .2, 0, 1, 0)
  end

  lovr.graphics.pop()
end

function Satchel:controllerpressed(controller, button)
  if button == 'menu' then
    if self.active then
      self.active = false
      self.controller = nil
    else
      self.active = true
      self.controller = controller
    end
  elseif self.active and button == 'trigger' then
    local controllerPosition = maf.vec3(self.layout:cursorPosition(controller))
    for i, kind, ix, iy in self:items() do
      local itemPosition = maf.vec3(self.transform:transformPoint(ix, iy, 0))
      if controllerPosition:distance(itemPosition) < self.itemSize / 2 then
        local model = self.layout.models[kind]
        local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
        local width, height, depth = maxx - minx, maxy - miny, maxz - minz
        local scale = self.itemSize / math.max(width, height, depth)
        local origin = maf.vec3((minx + maxx) / 2, (miny + maxy) / 2, (minz + maxz) / 2):scale(scale)

        local x, y, z = itemPosition:sub(origin):unpack()
        local angle, ax, ay, az = -self.yaw + lovr.timer.getTime() * .2, 0, 1, 0

        self.layout:addEntity(kind, x, y, z, scale, angle, ax, ay, az)
        return
      end
    end
  end
end

function Satchel:controllerreleased(controller, button)
  if button == 'menu' and controller == self.controller then
    self:updatePosition()
    self.controller = nil
  end
end

function Satchel:updatePosition(controller)
  local controller = self.controller
  local x, y, z = self.layout:cursorPosition(controller)
  local hx, hy, hz = lovr.headset.getPosition()
  local angle, ax, ay, az = lovr.math.lookAt(hx, 0, hz, x, 0, z)
  self.transform:origin()
  self.transform:translate(x, y, z)
  self.transform:rotate(angle, ax, ay, az)
  self.yaw = angle
end

function Satchel:items()
  local count = #self.layout.models
  local spacing = self.itemSize * 2
  local perRow = math.ceil(math.sqrt(count))
  local rows = math.ceil(count / perRow)
  local i = 0

  return function()
    i = i + 1
    local kind = self.layout.models[i]
    if not kind then return end
    local col = 1 + ((i - 1) % perRow)
    local row = math.ceil(i / perRow)
    local x = -spacing * (perRow - 1) / 2 + spacing * (col - 1)
    local y = spacing * (rows - 1) / 2 - spacing * (row - 1)
    return i, kind, x, y
  end
end

return Satchel
