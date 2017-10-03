local maf = require 'maf'
local vector = maf.vector
local quat = maf.quat
local util = require 'util'
local grid = require 'grid'

local layout = {}

function layout:init(level)
  self:loadEntityTypes()
  self:refreshControllers()

  self.satchel = {
    active = false,
    following = nil,
    itemSize = .08,
    transform = lovr.math.newTransform()
  }

  self.grid = grid.new(5, 5, .25, { .8, .25, .5, .25 })
end

function layout:update(dt)
 --
end

function layout:draw()
  self.grid:draw()
  self:drawCursors()

  if self.satchel.active then
    self:drawSatchel()
  end
end

function layout:controllerpressed(controller, button)
  if button == 'menu' or button == 'b' then
    if not self.satchel.active then
      self.satchel.active = true
      self.satchel.following = controller
    else
      self.satchel.active = false
      self.satchel.following = nil
    end
  end

  local hover = self:getSatchelHover(controller)
  if button == 'trigger' and hover then
    print('you added a ' .. hover)
  end
end

function layout:controllerreleased(controller, button)
  if button == 'menu' or button == 'b' then
    if self.satchel.following then
      self:positionSatchel()
      self.satchel.following = nil
    end
  end
end

function layout:controlleradded(controller)
  self:refreshControllers()
end

function layout:controllerremoved(controller)
  self:refreshControllers()
end

function layout:refreshControllers()
  self.controllers = {}

  for i, controller in ipairs(lovr.headset.getControllers()) do
    self.controllers[i] = {
      index = i,
      object = controller,
      model = controller:newModel(),
      hand = ''
    }
  end
end

function layout:drawSatchel()
  if self.satchel.following then
    self:positionSatchel()
  end

  local count = #self.entityTypes
  local spacing = self.satchel.itemSize * 2.5
  local perRow = math.ceil(math.sqrt(count))
  local rows = math.ceil(count / perRow)
  local bx, by, bz = self.satchel.transform:transformPoint(0, 0, 0)
  local y = spacing * (rows - 1) / 2

  lovr.graphics.push()
  lovr.graphics.transform(self.satchel.transform)

  for i = 1, rows do
    local x = -spacing * (perRow - 1) / 2

    for j = 1, perRow do
      local entityType = self.entityTypes[self.entityTypes[(i - 1) * perRow + j]]

      if entityType then
        entityType.model:draw(x, y, 0, entityType.baseScale, lovr.timer.getTime() * .1, 0, 1, 0)
      end

      x = x + spacing
    end

    y = y - spacing
  end

  lovr.graphics.pop()
end

local newPos = vector()
function layout:drawCursors()
  local parts = { 'leftHand', 'rightHand' }
  local state = {}

  if self.controllers[1] then
    x, y, z = self.controllers[1].object:getPosition()
    angle, ax, ay, az = self.controllers[1].object:getOrientation()
    state.leftHand = { x, y, z, angle, ax, ay, az }
  else
    state.leftHand = { 0, 0, 0, 0, 0, 0, 0 }
  end

  if self.controllers[2] then
    x, y, z = self.controllers[2].object:getPosition()
    angle, ax, ay, az = self.controllers[2].object:getOrientation()
    state.rightHand = { x, y, z, angle, ax, ay, az }
  else
    state.rightHand = { 0, 0, 0, 0, 0, 0, 0 }
  end

  for _, part in ipairs(parts) do
    if state[part] then
      local x, y, z, angle, ax, ay, az = unpack(state[part])
      local offset = vector(self:orientationToVector(angle, ax, ay, az)):scale(.075)
      newPos:set(x, y, z):add(offset)
      x, y, z = newPos:unpack()

      lovr.graphics.cube('fill', x, y, z, .01, angle, ax, ay, az)
    end
  end
end

function layout:orientationToVector(angle, ax, ay, az)
  local x, y, z = 0, 0, -1
  local dot = ax * x + ay * y + az * z
  local cx, cy, cz = ay * z - az * y, az * x - ax * z, ax * y - ay * x
  local sin, cos = math.sin(angle), math.cos(angle)
  return
    cos * x + sin * cx + (1 - cos) * dot * ax,
    cos * y + sin * cy + (1 - cos) * dot * ay,
    cos * z + sin * cz + (1 - cos) * dot * az
end

function layout:loadEntityTypes()
  local path = 'models'
  local files = lovr.filesystem.getDirectoryItems(path)
  self.entityTypes = {}
  self.satchelItemSize = .09

  for i, file in ipairs(files) do
    if file:match('%.obj$') or file:match('%.fbx$') or file:match('%.dae$') then
      local id = file:gsub('%.%a+$', '')
      local texturePath = path .. '/' .. id .. '.png'
      local modelPath = path .. '/' .. file
      local model = lovr.filesystem.exists(texturePath) and lovr.graphics.newModel(modelPath, texturePath) or lovr.graphics.newModel(modelPath)

      local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
      local width, height, depth = maxx - minx, maxy - miny, maxz - minz
      local baseScale = self.satchelItemSize / math.max(width, height, depth)

      self.entityTypes[id] = {
        model = model,
        baseScale = baseScale
      }

      table.insert(self.entityTypes, id)
    end
  end
end

local tmp1, tmp2 = vector(), vector()
function layout:getSatchelHover(controller)
  if not self.satchel.active then return end

  local count = #self.entityTypes
  local spacing = self.satchel.itemSize * 2.5
  local perRow = math.ceil(math.sqrt(count))
  local rows = math.ceil(count / perRow)
  local bx, by, bz = self.satchel.transform:transformPoint(0, 0, 0)
  local y = spacing * (rows - 1) / 2

  tmp2:set(controller:getPosition())

  for i = 1, rows do
    local x = -spacing * (perRow - 1) / 2

    for j = 1, perRow do
      tmp1:set(self.satchel.transform:transformPoint(x, y, 0))

      if tmp1:distance(tmp2) < self.satchel.itemSize * 1.5 then
        return self.entityTypes[(i - 1) * perRow + j]
      end

      x = x + spacing
    end

    y = y - spacing
  end
end

function layout:positionSatchel()
  local x, y, z = self.satchel.following:getPosition()
  local hx, hy, hz = lovr.headset.getPosition()
  local angle, ax, ay, az = lovr.math.lookAt(hx, 0, hz, x, 0, z)
  self.satchel.transform:origin()
  self.satchel.transform:translate(x, y, z)
  self.satchel.transform:rotate(angle, ax, ay, az)
end

return layout
