local maf = require 'maf'
local vector = maf.vector
local quat = maf.quat
local util = require 'util'
local grid = require 'grid'

local layout = {}

function layout:init(level)
  self:loadEntityTypes()
  self:refreshControllers()

  self.entities = level and level.entities or {}

  self.satchel = {
    active = false,
    following = nil,
    itemSize = .06,
    transform = lovr.math.newTransform()
  }

  self.grid = grid.new(5, 5, .25, { .8, .25, .5, .25 })
end

function layout:update(dt)
  util.each(self.entities, function(entity)
    entity.wasHovered = entity.wasHovered or {}
    entity.isHovered = entity.isHovered or {}
    util.each(self.controllers, function(controller)
      entity.wasHovered[controller] = entity.isHovered[controller]
      entity.isHovered[controller] = self:isHoveredByController(entity, controller)
      if (not entity.wasHovered[controller] and entity.isHovered[controller]) then
        -- if not controller.drag.active and not controller.scale.active and not controller.rotate.active then
          self.controllers[controller].object:vibrate(.002)
        -- end
      end
    end, ipairs)
  end)
end

function layout:draw()
  self:updateControllers()
  self.grid:draw()
  self:drawCursors()

  if self.satchel.active then
    self:drawSatchel()
  end

  self:drawEntities()
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
    local entity = self:newEntity(hover, controller)
    self.entities[entity] = entity
    table.insert(self.entities, entity)
  end

  local entity = self:getClosestEntity(controller)
	local otherController = self:getOtherController(self.controllers[controller])

  if entity then
    if button == 'trigger' then
			if otherController and otherController.drag.active and otherController.activeEntity == entity then
        self:beginScale(controller, otherController, entity)
      else
        self:beginDrag(controller, entity)
      end
    elseif button == 'grip' then
      -- self:beginRotate(controller, entity)
    end
  end
end

function layout:controllerreleased(controller, button)
  if button == 'menu' or button == 'b' then
    if self.satchel.following then
      self:positionSatchel()
      self.satchel.following = nil
    end
  end

  if button == 'trigger' then
    self:endScale(controller)
    self:endDrag(controller)
  elseif button == 'grip' then
    -- self:endRotate(controller)
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
    self.controllers[controller] = {
      index = i,
      object = controller,
      model = controller:newModel(),
      currentPosition = vector(),
      lastPosition = vector(),
      activeEntity = nil,
      drag = {
        active = false,
        offset = vector(),
        counter = 0
      },
      scale = {
        active = false,
        lastDistance = 0,
        counter = 0
      },
      rotate = {
        active = false,
        lastRotation = quat(),
        counter = 0
      }
    }
    table.insert(self.controllers, controller)
  end
end

function layout:updateControllers()
  util.each(self.controllers, function(controller)
		local controller = self.controllers[controller]
		controller.currentPosition:set(controller.object:getPosition())

    if controller.drag.active then self:updateDrag(controller) end
    if controller.rotate.active then self:updateRotate(controller) end
    if controller.scale.active then self:updateScale(controller) end

    controller.lastPosition:set(controller.currentPosition)
  end, ipairs)
end

function layout:drawSatchel()
  if self.satchel.following then
    self:positionSatchel()
  end

  local count = #self.entityTypes
  local spacing = self.satchel.itemSize * 2
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

function layout:drawCursors()
  for _, controller in ipairs(self.controllers) do
    local cursor = self:cursorPos(controller)
    x, y, z = cursor:unpack()

    lovr.graphics.cube('fill', x, y, z, .01, angle, ax, ay, az)
  end
end

function layout:drawEntities()
  util.each(self.entities, function(entity)
    entity.model:draw(entity.x, entity.y, entity.z, entity.scale, entity.angle, entity.ax, entity.ay, entity.az)
    self:drawEntityUI(entity)
  end, ipairs)
end

function layout:drawEntityUI(entity)
  local r, g, b, a = 255, 255, 255, 100
  if (self:isHovered(entity)) then
    -- r, g, b = unpack(self.color[self.tool])
    a = 200
  end

  local minx, maxx, miny, maxy, minz, maxz = entity.model:getAABB()
  local w, h, d = (maxx - minx) * entity.scale, (maxy - miny) * entity.scale, (maxz - minz) * entity.scale
  local cx, cy, cz = (maxx + minx) / 2 * entity.scale, (maxy + miny) / 2 * entity.scale, (maxz + minz) / 2 * entity.scale
  lovr.graphics.push()
  lovr.graphics.translate(entity.x, entity.y, entity.z)
  lovr.graphics.rotate(entity.angle, entity.ax, entity.ay, entity.az)
  lovr.graphics.setColor(r, g, b, a)
  lovr.graphics.box('line', cx, cy, cz, w, h, d)
  lovr.graphics.setColor(255, 255, 255)
  lovr.graphics.pop()
end

function layout:beginDrag(controller, entity)
  local controller = self.controllers[controller]
  local entityPosition = vector(entity.x, entity.y, entity.z)
  controller.activeEntity = entity
  controller.drag.active = true
  controller.drag.offset = entityPosition - controller.currentPosition
  controller.drag.counter = 0
end

local tmpVector = vector()
function layout:updateDrag(controller)
  local otherController = self:getOtherController(controller)
  if controller.scale.active or (otherController and otherController.scale.active) then return end
  local newPosition = controller.currentPosition + controller.drag.offset
  local t = controller.activeEntity
  tmpVector:set(t.x, t.y, t.z)
  tmpVector:sub(newPosition)
  controller.drag.counter = controller.drag.counter + tmpVector:length()
  if controller.drag.counter >= .1 then
    controller.object:vibrate(.001)
    controller.drag.counter = 0
  end
  self:updateEntityPosition(controller.activeEntity, newPosition:unpack())
  -- self:dirty()
end

function layout:updateEntityPosition(entity, x, y, z)
  local t = self.entities[entity]
	t.x, t.y, t.z = x, y, z
end

function layout:endDrag(controller)
  self.controllers[controller].drag.active = false
end

function layout:beginScale(controller, otherController, entity)
	local controller = self.controllers[controller]
	
  controller.scale.active = true
  controller.activeEntity = entity
  controller.scale.counter = 0
  controller.scale.lastDistance = (controller.currentPosition - otherController.currentPosition):length()
end

function layout:updateScale(controller)
	local otherController = self:getOtherController(controller)
  local currentDistance = controller.currentPosition:distance(otherController.currentPosition)
  local distanceRatio = (currentDistance / controller.scale.lastDistance)
  controller.scale.counter = controller.scale.counter + math.abs(currentDistance - controller.scale.lastDistance)
  if controller.scale.counter >= .1 then
    controller.object:vibrate(.001)
    otherController.object:vibrate(.001)
    controller.scale.counter = 0
  end
  controller.scale.lastDistance = currentDistance

  self:updateEntityScale(controller.activeEntity, distanceRatio)
  -- self:dirty()
end

function layout:updateEntityScale(entity, scaleMultiplier)
  local t = entity
  t.scale = t.scale * scaleMultiplier
end

function layout:endScale(controller)
	local controller = self.controllers[controller]
  local otherController = self:getOtherController(controller)

  if otherController then
    otherController.scale.active = false
    if otherController.drag.active then
      local entity = otherController.activeEntity
      local entityPosition = vector(entity.x, entity.y, entity.z)
      otherController.drag.offset = entityPosition - otherController.currentPosition
    end
  end

  controller.scale.active = false
end

function layout:getOtherController(controller)
  return self.controllers[self.controllers[3 - controller.index]]
end

local newPos = vector()
function layout:cursorPos(controller)
  local controller = self.controllers[controller]
  local x, y, z = controller.object:getPosition()
  local angle, ax, ay, az = controller.object:getOrientation()
  local offset = vector(self:orientationToVector(angle, ax, ay, az)):scale(.075)
  newPos:set(x, y, z):add(offset)
  return newPos
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

function layout:newEntity(typeId, controller)
  local entity = {}
  local t = self.entityTypes[typeId]
  entity.model = t.model
  entity.scale = t.baseScale * 2

  local x, y, z = self:cursorPos(controller):unpack()
  entity.x, entity.y, entity.z = x, y, z
  entity.angle, entity.ax, entity.ay, entity.az = 0, 1, 0, 0
  entity.transform = lovr.math.newTransform(entity.x, entity.y, entity.z, entity.scale, entity.scale, entity.scale, entity.angle, entity.ax, entity.ay, entity.az)

  return entity
end

function layout:loadEntityTypes()
  local path = 'models'
  local files = lovr.filesystem.getDirectoryItems(path)
  self.entityTypes = {}
  self.satchelItemSize = .09

  local texture = lovr.graphics.newTexture('models/texture1.png')

  for i, file in ipairs(files) do
    if file:match('%.obj$') or file:match('%.fbx$') or file:match('%.dae$') then
      local id = file:gsub('%.%a+$', '')
      local texturePath = path .. '/' .. id .. '.png'
      local modelPath = path .. '/' .. file
      local model = lovr.graphics.newModel(modelPath)
      model:setTexture(texture)

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
  local spacing = self.satchel.itemSize * 2
  local perRow = math.ceil(math.sqrt(count))
  local rows = math.ceil(count / perRow)
  local bx, by, bz = self.satchel.transform:transformPoint(0, 0, 0)
  local y = spacing * (rows - 1) / 2

  tmp2:set(self.controllers[controller].object:getPosition())

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

function layout:getClosestEntity(controller)
  local x, y, z = self.controllers[controller].object:getPosition()
  local minDistance, closestEntity = math.huge, nil
  util.each(self.entities, function(entity)
    local d = (x - entity.x) ^ 2 + (y - entity.y) ^ 2 + (z - entity.z) ^ 2
    if d < minDistance and self:isHoveredByController(entity, controller) then
      minDistance = d
      closestEntity = entity
    end
  end)
  return closestEntity, math.sqrt(minDistance)
end

local transform = lovr.math.newTransform()
function layout:isHoveredByController(entity, controller)
  if not controller then return false end
  local t = entity
  local minx, maxx, miny, maxy, minz, maxz = t.model:getAABB()
  minx, maxx, miny, maxy, minz, maxz = t.x + minx * t.scale, t.x + maxx * t.scale, t.y + miny * t.scale, t.y + maxy * t.scale, t.z + minz * t.scale, t.z + maxz * t.scale
  transform:origin()
  transform:translate(t.x, t.y, t.z)
  transform:rotate(-t.angle, t.ax, t.ay, t.az)
  local x, y, z = self:cursorPos(controller):unpack()
  x, y, z = transform:transformPoint(x - t.x, y - t.y, z - t.z)
  return x >= minx and x <= maxx and y >= miny and y <= maxy and z >= minz and z <= maxz
end

function layout:isHovered(entity)
  for _, controller in ipairs(self.controllers) do
    if self:isHoveredByController(entity, controller) then
      return controller
    end
  end
end

return layout
