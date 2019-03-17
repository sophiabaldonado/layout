local Satchel = {}

Satchel.name = 'Satchel'
Satchel.itemSize = .09
Satchel.button = 'menu'

function Satchel:init()
  self.active = false
  self.controller = nil
  self.transform = lovr.math.mat4()
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
  lovr.graphics.setColor(1, 1, 1)

  for i, asset, x, y in self:items() do
    local model = asset.model
    if model then
      local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
      local width, height, depth = maxx - minx, maxy - miny, maxz - minz
      local scale = self.itemSize / math.max(width, height, depth)
      local cx, cy, cz = (minx + maxx) / 2 * scale, (miny + maxy) / 2 * scale, (minz + maxz) / 2 * scale
      model:draw(x - cx, y - cy, 0 - cz, scale, lovr.timer.getTime() * .2, 0, 1, 0)
    end
  end

  lovr.graphics.pop()
  lovr.graphics.flush()
end

function Satchel:controllerpressed(controller, button)
  if button == self.button then
    if self.active then
      self.active = false
      self.controller = nil
    else
      self.active = true
      self.controller = controller
    end
  elseif self.active and button == 'trigger' then
    local controllerPosition = self.layout:cursorPosition(controller, true)
    for i, asset, ix, iy in self:items() do
      local itemPosition = self.layout.pool:vec3(self.transform:transformPoint(ix, iy, 0))
      if controllerPosition:distance(itemPosition) < self.itemSize / 2 then
        local model = asset.model
        if model then
          local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
          local width, height, depth = maxx - minx, maxy - miny, maxz - minz
          local scale = self.itemSize / math.max(width, height, depth)
          local origin = self.layout.pool:vec3((minx + maxx) / 2, (miny + maxy) / 2, (minz + maxz) / 2):mul(scale)

          local x, y, z = self.layout.transform:copy(self.layout.pool):invert():transformPoint(itemPosition:sub(origin))
          local angle, ax, ay, az = self.yaw + lovr.timer.getTime() * .2, 0, 1, 0

          self.layout:dispatch({
            type = 'add',
            asset = asset.key,
            x = x, y = y, z = z,
            scale = scale,
            angle = angle, ax = ax, ay = ay, az = az
          })

          -- This is a little hacky, but it's how we let grab know about the new object
          if self.layout.tools.grab then
            self.layout:updateHovers()
            self.layout.tools.grab:controllerpressed(controller, button)
          end

          return
        end
      end
    end
  end
end

function Satchel:controllerreleased(controller, button)
  if button == self.button and controller == self.controller then
    self:updatePosition()
    self.controller = nil
  end
end

function Satchel:updatePosition(controller)
  local controller = self.controller
  local cursor = self.layout:cursorPosition(controller, true)
  local cx, cy, cz = cursor:unpack()
  local hx, hy, hz = lovr.headset.getPosition()
  local angle, ax, ay, az = lovr.math.lookAt(hx, 0, hz, cx, 0, cz)
  self.transform:identity()
  self.transform:translate(cursor)
  self.transform:rotate(angle, ax, ay, az)
  self.yaw = angle
end

function Satchel:items()
  local count = #self.layout.assets
  local spacing = self.itemSize * 2
  local perRow = math.ceil(math.sqrt(count))
  local rows = math.ceil(count / perRow)
  local i = 0

  return function()
    i = i + 1
    local asset = self.layout.assets[i]
    if not asset then return end
    local col = 1 + ((i - 1) % perRow)
    local row = math.ceil(i / perRow)
    local x = -spacing * (perRow - 1) / 2 + spacing * (col - 1)
    local y = spacing * (rows - 1) / 2 - spacing * (row - 1)
    return i, asset, x, y
  end
end

return Satchel
