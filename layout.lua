local maf = require 'maf'
local vector = maf.vector
local quat = maf.quat
local util = require 'util'
local grid = require 'grid'
local json = require('json')
local defaultFilename = 'sophia.json'
local transform = lovr.math.newTransform()
local rotateTransform = lovr.math.newTransform()

local layout = {}

function layout:init(level)
	self.isDirty = false
	self.lastChange = lovr.timer.getTime()
  self.tools = {}
  self.axisLock = { x = false, y = false, z = false }
  self:setDefaultTools()

  self:loadEntityTypes()
  self:refreshControllers()

	self.colors = {
		default = { 255, 255, 255 },
		green = { 89, 205, 119 },
		red = { 220, 91, 91 },
		blue = { 57, 117, 227 }
	}
	self.activeColor = self.colors.default

  self.active = true
  self.toolTextureName = self.active and 'play' or 'stop'

	self.entities = level and level.entities or {}

  self.satchel = {
    active = false,
    following = nil,
    itemSize = .06,
    transform = lovr.math.newTransform(),
    yaw = 0
  }

  self.grid = grid.new(5, 5, .25, { .8, .25, .5, .25 })

  self.tokens = {
    { model = lovr.graphics.newModel('tools/token.obj'), texture = lovr.graphics.newTexture('tools/copy.png') }
  }

	self:load(defaultFilename)
end

function layout:update(dt)
	self:checkSave()

  if self.active then
		local hasHover, hasActive = false, false

    util.each(self.entities, function(entity)
      entity.wasHovered = entity.wasHovered or {}
      entity.isHovered = entity.isHovered or {}
      util.each(self.controllers, function(controller)
				local c = self.controllers[controller]

        entity.wasHovered[controller] = entity.isHovered[controller]
        entity.isHovered[controller] = self:isHoveredByController(entity, controller)
				hasHover = hasHover or (entity.isHovered[controller])

        if (not entity.wasHovered[controller] and entity.isHovered[controller]) then
          if not c.drag.active and not c.scale.active and not c.rotate.active then
            self.controllers[controller].object:vibrate(.002)
          end
        end

				hasActive = hasActive or (c.drag.active or c.scale.active or c.rotate.active)
      end, ipairs)
    end)

		if hasActive then
			self:setActiveTools()
		elseif hasHover then
			self:setHoverTools()
		else
			self:setDefaultTools()
		end
	else
		self.satchel.active = false
		self.satchel.following = nil
	end
end

function layout:draw()
  self:updateControllers()

	self.grid:draw()

	if self.active then
		self:drawCursors()

		if self.satchel.active then
			self:drawSatchel()
		end
	end

	for i, controller in ipairs(self.controllers) do
		local c = self.controllers[controller]
		local x, y, z = controller:getPosition()
		lovr.graphics.setColor(255, 255, 255)
		c.model:draw(x, y, z, 1, controller:getOrientation())
	end

  self:drawEntities()
	self:drawToolUI()
end

function layout:drawToolUI()
  local toolTexturePath = self.toolTextureName..'.png'
  local toolTexture = lovr.graphics.newTexture(toolTexturePath)

	lovr.graphics.setColor(255, 255, 255)
  util.each(self.controllers, function(controller)
    local x, y, z = controller:getPosition()
    local angle, ax, ay, az = controller:getOrientation()
		lovr.graphics.push()
		lovr.graphics.translate(x, y, z)
		lovr.graphics.rotate(angle, ax, ay, az)
    lovr.graphics.plane(toolTexture, 0, .01, .05, .05, -math.pi / 2 + .1, 1, 0, 0)
		lovr.graphics.pop()
  end, ipairs)
end

function layout:controllerpressed(controller, button)
  if button == 'touchpad' then
    local touchx, touchy = controller:getAxis('touchx'), controller:getAxis('touchy')
    local angle, distance = util.angle(0, 0, touchx, touchy), util.distance(0, 0, touchx, touchy)
    local threshold = 0
    while angle < 0 do angle = angle + 2 * math.pi end
    if distance >= threshold then
      if angle < math.pi / 4 then self.tools.right()
      elseif angle < 3 * math.pi / 4 then self.tools.up()
      elseif angle < 5 * math.pi / 4 then self.tools.left()
      elseif angle < 7 * math.pi / 4 then self.tools.down()
      else self.tools.right() end
    end
  end

  if self.active then

    if button == 'menu' or button == 'b' then
      if not self.satchel.active then
        self.satchel.active = true
        self.satchel.following = controller
      else
        self.satchel.active = false
        self.satchel.following = nil
      end
    end

    local entity = self:getClosestEntity(controller)
  	local otherController = self:getOtherController(self.controllers[controller])

    local c = self.controllers[controller]
    if entity and not c.drag.active and not c.scale.active and not c.rotate.active then
      -- hover touchpad tools
    end

    if entity and not entity.locked then
      if button == 'trigger' then
  			if otherController and otherController.drag.active and otherController.activeEntity == entity then
          self:beginScale(controller, otherController, entity)
        else
          self:beginDrag(controller, entity)
        end
      elseif button == 'grip' then
        self:beginRotate(controller, entity)
      end
    else
      local hover, x, y, z = self:getSatchelHover(controller)
      if button == 'trigger' and hover then
        local entity = self:newEntity(hover, x, y, z)
				print(hover)
        self.entities[entity] = entity
        table.insert(self.entities, entity)
        self:beginDrag(controller, entity)
      end
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
    self:endRotate(controller)
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
      model = lovr.graphics.newModel('tools/controller.obj', 'tools/controller.png'),
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
        original = quat(),
        originalPosition = vector(),
        counter = 0
      }
    }
    table.insert(self.controllers, controller)
  end
end

function layout:updateControllers()
  util.each(self.controllers, function(controller)
		local controller = self.controllers[controller]
		controller.currentPosition:set(self:cursorPos(controller.object))

    if controller.drag.active then self:updateDrag(controller) end
    if controller.rotate.active then self:updateRotate(controller) end
    if controller.scale.active then self:updateScale(controller) end

    controller.lastPosition:set(controller.currentPosition)
  end, ipairs)
end

function layout:setActiveTools()
  self.tools.up = function() self.axisLock.y = not self.axisLock.y end
  self.tools.left = function() self.axisLock.x = not self.axisLock.x end
  self.tools.right = function() self.axisLock.z = not self.axisLock.z end
  self.tools.down = function() end

  self.toolTextureName = 'active'
end

function layout:setHoverTools()
	local function deleteHovered()
		for i = #self.entities, 1, -1 do
			local entity = self.entities[i]
			if self:isHovered(entity) then
				self:removeEntity(entity)
			end
		end
	end

  self.tools.up = function() print('copy') end
  self.tools.left = function() print('hover left') end
  self.tools.right = function() print('hover right') end
  self.tools.down = function() deleteHovered() end

  self.toolTextureName = 'hover'
end

function layout:setDefaultTools()
	local function toggleActive()
		self.active = not self.active
		self.toolTextureName = self.active and 'play' or 'stop'
	end

  self.tools.up = function() toggleActive() end
  self.tools.left = function() toggleActive() end
  self.tools.right = function() toggleActive() end
  self.tools.down = function() toggleActive() end

	self.toolTextureName = self.active and 'play' or 'stop'
end

function layout:drawSatchel()
  if self.satchel.following then
    self:positionSatchel()
  end

  local count = #self.entityTypes
  local spacing = self.satchel.itemSize * 2
  local perRow = math.ceil(math.sqrt(count))
  local rows = math.ceil(count / perRow)
  local y = spacing * (rows - 1) / 2

  lovr.graphics.push()
  lovr.graphics.transform(self.satchel.transform)

  for i = 1, rows do
    local x = -spacing * (perRow - 1) / 2

    for j = 1, perRow do
      local entityType = self.entityTypes[self.entityTypes[(i - 1) * perRow + j]]

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

function layout:drawCursors()
  for _, controller in ipairs(self.controllers) do
    local cursor = self:cursorPos(controller)
    x, y, z = cursor:unpack()

		if (self.activeColor ~= self.colors.default) then
			lovr.graphics.setColor(self.activeColor)
			lovr.graphics.sphere(x, y, z, .005, angle, ax, ay, az)
			lovr.graphics.setColor(self.colors.default)
		else
			lovr.graphics.cube('fill', x, y, z, .01, angle, ax, ay, az)
		end
  end
end

function layout:drawEntities()
  util.each(self.entities, function(entity)
    local minx, maxx, miny, maxy, minz, maxz = entity.model:getAABB()
    local cx, cy, cz = (minx + maxx) / 2 * entity.scale, (miny + maxy) / 2 * entity.scale, (minz + maxz) / 2 * entity.scale
    lovr.graphics.push()
    lovr.graphics.translate(entity.x + cx, entity.y + cy, entity.z + cz)
    lovr.graphics.rotate(entity.angle, entity.ax, entity.ay, entity.az)
    lovr.graphics.translate(-entity.x - cx, -entity.y - cy, -entity.z - cz)
    entity.model:draw(entity.x, entity.y, entity.z, entity.scale)
    lovr.graphics.pop()

    if self.active then self:drawEntityUI(entity) end
  end, ipairs)
end

function layout:drawEntityUI(entity)
	local r, g, b = unpack(self.activeColor)
  local a = 100
  if (self:isHovered(entity)) then a = 200 end

  local minx, maxx, miny, maxy, minz, maxz = entity.model:getAABB()
  local w, h, d = (maxx - minx) * entity.scale, (maxy - miny) * entity.scale, (maxz - minz) * entity.scale
  local cx, cy, cz = (maxx + minx) / 2 * entity.scale, (maxy + miny) / 2 * entity.scale, (maxz + minz) / 2 * entity.scale
  lovr.graphics.push()
  lovr.graphics.translate(entity.x, entity.y, entity.z)
  lovr.graphics.translate(cx, cy, cz)
  lovr.graphics.rotate(entity.angle, entity.ax, entity.ay, entity.az)
  lovr.graphics.translate(-cx, -cy, -cz)
	if self:isHovered(entity) then
		lovr.graphics.setColor(r, g, b, a)
	else
		lovr.graphics.setColor(255, 255, 255, a)
	end
  lovr.graphics.box('line', cx, cy, cz, w, h, d)
  lovr.graphics.pop()
  for axis, locked in pairs(self.axisLock) do
    if locked then
      lovr.graphics.setLineWidth(2)
      local x, y, z = entity.x, entity.y, entity.z
      if axis == 'x' then
        local r, g, b = unpack(self.colors.red)
        lovr.graphics.setColor(r, g, b, 200)
        lovr.graphics.line(x - 10, y, z, x + 10, y, z)
      elseif axis == 'y' then
        local r, g, b = unpack(self.colors.green)
        lovr.graphics.setColor(r, g, b, 200)
        lovr.graphics.line(x, y - 10, z, x, y + 10, z)
      elseif axis == 'z' then
        local r, g, b = unpack(self.colors.blue)
        lovr.graphics.setColor(r, g, b, 200)
        lovr.graphics.line(x, y, z - 10, x, y, z + 10)
      end
      lovr.graphics.setLineWidth(1)
    end
  end
  lovr.graphics.setColor(self.colors.default)
end

function layout:beginDrag(controller, entity)
  self.axisLock = { x = false, y = false, z = false }
  self:setActiveTools()
  local controller = self.controllers[controller]
  local entityPosition = vector(entity.x, entity.y, entity.z)
  controller.activeEntity = entity
  controller.drag.active = true
  controller.drag.offset = entityPosition - controller.currentPosition
  controller.drag.counter = 0
	self.activeColor = self.colors.green
end

local tmpVector1 = vector()
local tmpVector2 = vector()
function layout:updateDrag(controller)
  local otherController = self:getOtherController(controller)
  if controller.scale.active or (otherController and otherController.scale.active) then return end
  local newPosition = controller.currentPosition + controller.drag.offset
  local t = controller.activeEntity

  local delta = tmpVector1
  delta:set(t.x, t.y, t.z)
  newPosition:sub(delta, delta)

  local isLocked = false
  for axis, locked in pairs(self.axisLock) do
    isLocked = isLocked or locked
  end

  delta.x = (not isLocked or self.axisLock.x) and delta.x or 0
  delta.y = (not isLocked or self.axisLock.y) and delta.y or 0
  delta.z = (not isLocked or self.axisLock.z) and delta.z or 0

  controller.drag.counter = controller.drag.counter + delta:length()
  if controller.drag.counter >= .1 then
    controller.object:vibrate(.001)
    controller.drag.counter = 0
  end

  self:updateEntityPosition(controller.activeEntity, delta:unpack())
  self:dirty()
end

function layout:updateEntityPosition(entity, dx, dy, dz)
  local t = entity
	t.x, t.y, t.z = t.x + dx, t.y + dy, t.z + dz
end

function layout:endDrag(controller)
  self.controllers[controller].drag.active = false
  self:resetDefaults()
end

function layout:beginScale(controller, otherController, entity)
  self:setActiveTools()
	local controller = self.controllers[controller]

  controller.scale.active = true
  controller.activeEntity = entity
  controller.scale.counter = 0
  controller.scale.lastDistance = (controller.currentPosition - otherController.currentPosition):length()
	self.activeColor = self.colors.blue
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
  self:dirty()
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
	self:resetDefaults()
end

function layout:beginRotate(controller, entity)
  self:setActiveTools()
	local controller = self.controllers[controller]

  controller.activeEntity = entity
  controller.rotate.active = true
	self.activeColor = self.colors.red
end

local tmpquat = quat()
function layout:updateRotate(controller)
  local t = controller.activeEntity

  local minx, maxx, miny, maxy, minz, maxz = t.model:getAABB()
  local cx, cy, cz = (minx + maxx) / 2 * t.scale, (miny + maxy) / 2 * t.scale, (minz + maxz) / 2 * t.scale
  local entityPosition = vector(t.x + cx, t.y + cy, t.z + cz)

  local d1 = (controller.currentPosition - entityPosition):normalize()
  local d2 = (controller.lastPosition - entityPosition):normalize()
  local rotation = quat():between(d2, d1)

  controller.rotate.counter = controller.rotate.counter + (controller.currentPosition - controller.lastPosition):length()
  if controller.rotate.counter >= .1 then
    controller.object:vibrate(.001)
    controller.rotate.counter = 0
  end

  self:updateEntityRotation(controller.activeEntity, rotation)
  self:dirty()
end

function layout:updateEntityRotation(entity, rotation)
  local t = entity
	local ogRotation = quat():angleAxis(t.angle, t.ax, t.ay, t.az)
	t.angle, t.ax, t.ay, t.az = (rotation * ogRotation):getAngleAxis()
  local axis = vector(t.ax, t.ay, t.az)
  axis:normalize()
	t.ax, t.ay, t.az = axis:unpack()
end

function layout:endRotate(controller)
  self.controllers[controller].rotate.active = false
  self:resetDefaults()
end

function layout:resetDefaults()
  self.activeColor = self.colors.default
  self.axisLock = {}
  self:setDefaultTools()
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

local tokenPos = vector()
function layout:drawTokens()
  util.each(self.controllers, function(controller)
    local x, y, z = controller:getPosition()
    local angle, ax, ay, az = controller:getOrientation()
    -- local offset = vector(self:orientationToVector(angle, ax, ay, az)):scale(.075)
    local offset = vector(.2, 0, 0)
    tokenPos:set(x, y, z):add(offset)
    x, y, z = tokenPos:unpack()
    for _, token in ipairs(self.tokens) do
      token.model:draw(x, y, z, .25, angle, ax, ay, az)
      lovr.graphics.plane(token.texture, x, y, z, .08, angle, ax, ay, az)
    end
  end, ipairs)
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

function layout:newEntity(typeId, x, y, z)
  local entity = {}
  entity.locked = false
	entity.typeId = typeId
  local t = self.entityTypes[typeId]
  entity.model = t.model
  entity.scale = t.baseScale

  local minx, maxx, miny, maxy, minz, maxz = t.model:getAABB()
  local cx, cy, cz = (minx + maxx) / 2 * t.baseScale, (miny + maxy) / 2 * t.baseScale, (minz + maxz) / 2 * t.baseScale
  entity.x, entity.y, entity.z = x - cx, y - cy, z - cz
  entity.angle, entity.ax, entity.ay, entity.az = -self.satchel.yaw + lovr.timer.getTime() * .2, 0, 1, 0
  entity.transform = lovr.math.newTransform(entity.x, entity.y, entity.z, entity.scale, entity.scale, entity.scale, entity.angle, entity.ax, entity.ay, entity.az)

  return entity
end

function layout:removeEntity(entity)
	for i = 1, #self.entities do
		if self.entities[i] == entity then
			table.remove(self.entities, i)
			break
		end
	end

	self.entities[entity] = nil
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
  local y = spacing * (rows - 1) / 2

  tmp2:set(self:cursorPos(controller))

  for i = 1, rows do
    local x = -spacing * (perRow - 1) / 2

    for j = 1, perRow do
      local id = self.entityTypes[(i - 1) * perRow + j]
      tmp1:set(self.satchel.transform:transformPoint(x, y, 0))

      if tmp1:distance(tmp2) < self.satchel.itemSize * .8 then
        return id, tmp1:unpack()
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
  self.satchel.yaw = angle
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

function layout:isHoveredByController(entity, controller)
  if not controller then return false end
  local t = entity
  local minx, maxx, miny, maxy, minz, maxz = t.model:getAABB()
  local cx, cy, cz = (minx + maxx) / 2 * t.scale, (miny + maxy) / 2 * t.scale, (minz + maxz) / 2 * t.scale
  minx, maxx, miny, maxy, minz, maxz = t.x + minx * t.scale, t.x + maxx * t.scale, t.y + miny * t.scale, t.y + maxy * t.scale, t.z + minz * t.scale, t.z + maxz * t.scale
  transform:origin()
  transform:translate(t.x, t.y, t.z)
  transform:translate(cx, cy, cz)
  transform:rotate(-t.angle, t.ax, t.ay, t.az)
  transform:translate(-cx, -cy, -cz)
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

function layout:checkSave()
  if self.isDirty and lovr.timer.getTime() - self.lastChange > 3 then
    self:save()
    self.isDirty = false
  end
end

function layout:dirty()
  self.isDirty = true
  self.lastChange = lovr.timer.getTime()
end

function layout:save()
	local saveData = {}
	local name = self.filename ~= defaultFilename and self.filename or 'levels/layout.json'
  saveData.entities = {}

  for i, entity in ipairs(self.entities) do
    saveData.entities[i] = {
      transform = { entity.x, entity.y, entity.z, entity.scale, entity.angle, entity.ax, entity.ay, entity.az },
      entityType = entity.typeId
    }
  end

	lovr.filesystem.createDirectory('levels')
  lovr.filesystem.write(name, json.encode(saveData))
end

function layout:load(filename)
  self.filename = filename
  filename = lovr.filesystem.exists(filename) and filename or defaultFilename
  self.data = json.decode(lovr.filesystem.read(filename))

	if self.data.entities then
		util.each(self.data.entities, function(entity)
			local entity = self:loadNewEntity(entity.entityType, entity.transform)
			self.entities[entity] = entity
			table.insert(self.entities, entity)
		end, ipairs)
	end
end


function layout:loadNewEntity(typeId, transform)
  local entity = {}
  entity.locked = false
	entity.typeId = typeId
  entity.model = self.entityTypes[typeId].model
  entity.scale = scale
  entity.x, entity.y, entity.z, entity.scale, entity.angle, entity.ax, entity.ay, entity.az = unpack(transform)
  entity.transform = lovr.math.newTransform(entity.x, entity.y, entity.z, entity.scale, entity.scale, entity.scale, entity.angle, entity.ax, entity.ay, entity.az)

  return entity
end

return layout
