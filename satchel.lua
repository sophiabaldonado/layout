local maf = require 'maf'
local vector = maf.vector

local satchel = {}

function satchel:init(loader)
	self.loader = loader
	self.active = false
	self.following = nil
	self.itemSize = .06
	self.transform = lovr.math.newTransform()
	self.yaw = 0
end

function satchel:draw()
	if self.following then
    self:reposition()
  end

  local count = #self.loader.entityTypes
  local spacing = self.itemSize * 2
  local perRow = math.ceil(math.sqrt(count))
  local rows = math.ceil(count / perRow)
  local y = spacing * (rows - 1) / 2

  lovr.graphics.push()
  lovr.graphics.transform(self.transform)

  for i = 1, rows do
    local x = -spacing * (perRow - 1) / 2

    for j = 1, perRow do
      local entityType = self.loader:getEntityById(self.loader:getEntityByIndex((i - 1) * perRow + j))

      if entityType then
        local minx, maxx, miny, maxy, minz, maxz = entityType.model:getAABB()
        local cx, cy, cz = (minx + maxx) / 2 * entityType.baseScale, (miny + maxy) / 2 * entityType.baseScale, (minz + maxz) / 2 * entityType.baseScale
        entityType.model:draw(x - cx, y - cy, 0 - cz, entityType.baseScale, lovr.timer.getTime() * .2, 0, 1, 0)
      end

      x = x + spacing
    end

    y = y - spacing
  end

  lovr.graphics.pop()
end

function satchel:reposition()
  local x, y, z = self.following:getPosition()
  local hx, hy, hz = lovr.headset.getPosition()
  local angle, ax, ay, az = lovr.math.lookAt(hx, 0, hz, x, 0, z)
  self.transform:origin()
  self.transform:translate(x, y, z)
  self.transform:rotate(angle, ax, ay, az)
  self.yaw = angle
end


local tmp1, tmp2 = vector(), vector()
function satchel:getHover(controllerPosition)
  if not self.active then return end

  local count = #self.self.loader.entityTypes -- probably change to paginated total?
  local spacing = self.itemSize * 2
  local perRow = math.ceil(math.sqrt(count))
  local rows = math.ceil(count / perRow)
  local y = spacing * (rows - 1) / 2

  tmp2:set(controllerPosition)

  for i = 1, rows do
    local x = -spacing * (perRow - 1) / 2

    for j = 1, perRow do
			print((i - 1) * perRow + j)
			print(self.loader:getEntityByIndex((i - 1) * perRow + j))
      local id = self.loader:getEntityByIndex((i - 1) * perRow + j) -- loader.entityTypes[(i - 1) * perRow + j]
      tmp1:set(self.transform:transformPoint(x, y, 0))

      if tmp1:distance(tmp2) < self.itemSize * .8 then
        return id, tmp1:unpack()
      end

      x = x + spacing
    end

    y = y - spacing
  end
end



return satchel
