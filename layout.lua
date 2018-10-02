local maf = require 'maf'
local json = require 'cjson'

local base = (...):match('^(.*[%./])[^%.%/]+$') or ''
local dot = base:match('%.') and '.' or '/'

local layout = {}

----------------
-- Callbacks
----------------
function layout:init()
  self.isDirty = false
  self.lastChange = nil
  self.actions = {}
  self.axisLock = { x = false, y = false, z = false }

  self:setDefaultActions()
  self:loadModels()
  self:refreshControllers()

  self.colors = {
    default = { 1, 1, 1 },
    green = { .349, .804, .4667 },
    red = { .863, .357, .357 },
    blue = { .223, .459, .890 },
    orange = { .941, .561, .278 }
  }
  self.activeColor = self.colors.default

  local actionTextureName = 'play'
  self.actionMaterial = lovr.graphics.newMaterial()
  self:setActionTexture(actionTextureName)

  self.entities = {}
  self.tools = {}

  for _, t in ipairs({ 'grab', 'rotate', 'satchel', 'clear' }) do
    table.insert(self.tools, setmetatable({ layout = self }, { __index = require(base .. 'tools' .. dot .. t) }))
  end

  self:eachTool('init')
end

function layout:update(dt)
  self:autosave()

  -- Calculate hover state
  for i, entity in ipairs(self.entities) do
    entity.hovered = false
    for _, controller in ipairs(self.controllers) do
      local hovered = self:isHoveredByController(entity, controller)
      entity.hovered = entity.hovered or hovered
      if hovered ~= entity.hoveredBy[controller] then
        entity.hoveredBy[controller] = hovered
        if hovered then controller:vibrate(.002) end
      end
    end
  end

  self:eachTool('update', dt)
end

function layout:draw()
  self:drawCursors()
  self:drawEntities()
  self:drawActionUI()
  self:eachTool('draw')
end

----------------
-- Controllers
----------------
function layout:controllerpressed(controller, button)
  if button == 'touchpad' then
    local touchx, touchy = controller:getAxis('touchx'), controller:getAxis('touchy')
    local angle, distance = math.atan2(touchy, touchx), math.sqrt(touchx * touchx + touchy * touchy)
    local threshold = 0
    while angle < 0 do angle = angle + 2 * math.pi end
    if distance >= threshold then
      if angle < math.pi / 4 then self.actions.right()
      elseif angle < 3 * math.pi / 4 then self.actions.up()
      elseif angle < 5 * math.pi / 4 then self.actions.left()
      elseif angle < 7 * math.pi / 4 then self.actions.down()
      else self.actions.right() end
    end
  end

  self:eachTool('controllerpressed', controller, button)
end

function layout:controllerreleased(controller, button)
  self:eachTool('controllerreleased', controller, button)
end

function layout:controlleradded(controller)
  self:refreshControllers()
end

function layout:controllerremoved(controller)
  for i, entity in ipairs(self.entities) do
    entity.hoveredBy[controller] = nil
    entity.focusedBy[controller] = nil
  end

  self:refreshControllers()
end

function layout:refreshControllers()
  self.controllers = lovr.headset.getControllers()
  for i, controller in ipairs(self.controllers) do
    self.controllers[controller] = self.controllers[3 - i]
  end
end

function layout:getOtherController(controller)
  return self.controllers[controller]
end

----------------
-- Actions
----------------
function layout:setActiveActions()
  self.actions.up = function() self.axisLock.y = not self.axisLock.y end
  self.actions.left = function() self.axisLock.x = not self.axisLock.x end
  self.actions.right = function() self.axisLock.z = not self.axisLock.z end
  self.actions.down = function() end

  self:setActionTexture('active')
end

function layout:setHoverActions()
  local function deleteHovered()
    for i = #self.entities, 1, -1 do
      local entity = self.entities[i]
      if entity.hovered and not entity.locked then
        self:removeEntity(entity)
      end
    end
  end

  local function lockHovered()
    for i = #self.entities, 1, -1 do
      local entity = self.entities[i]
      if entity.hovered then
        entity.locked = not entity.locked
      end
    end
  end

  local function copyHovered()
    local entity
    for i = #self.entities, 1, -1 do
      local controller = next(self.entities[i].hoveredBy)
      if controller then
        entity = self:getClosestEntity(controller)
      end
    end
    if entity then
      self:copyEntity(entity)
    end
  end

  local function setHoverActionsTexture()
    for i = #self.entities, 1, -1 do
      local entity = self.entities[i]
      if entity.hovered then
        local actionTextureName = entity.locked and 'hoverLocked' or 'hover'
        self:setActionTexture(actionTextureName)
      end
    end
  end

  self.actions.up = function() copyHovered() end
  self.actions.left = function() print('left') end
  self.actions.right = function() lockHovered() end
  self.actions.down = function() deleteHovered() end

  setHoverActionsTexture()
end

function layout:setDefaultActions()
  self.actions.up = function() end
  self.actions.left = function() end
  self.actions.right = function() end
  self.actions.down = function() end
end

function layout:setActionTexture(name)
  self.actionTextures = self.actionTextures or {}
  self.actionTextures[name] = self.actionTextures[name] or lovr.graphics.newTexture('resources/' .. name .. '.png')
  self.actionMaterial:setTexture(self.actionTextures[name])
end

function layout:drawActionUI()
  local actionTexture = self.actionTexture

  lovr.graphics.setColor(self.colors.default)
  for _, controller in ipairs(self.controllers) do
    local x, y, z = controller:getPosition()
    local angle, ax, ay, az = controller:getOrientation()
    lovr.graphics.push()
    lovr.graphics.translate(x, y, z)
    lovr.graphics.rotate(angle, ax, ay, az)
    lovr.graphics.plane(self.actionMaterial, 0, .01, .05, .05, .05, -math.pi / 2 + .1, 1, 0, 0)
    lovr.graphics.pop()
  end
end

----------------
-- Cursors
----------------
function layout:cursorPos(controller)
  local x, y, z = controller:getPosition()
  local ox, oy, oz = lovr.math.orientationToDirection(controller:getOrientation())
  return x + ox * scale, y + oy * scale, z + oz * scale
end

function layout:drawCursors()
  for _, controller in ipairs(self.controllers) do
    local x, y, z = self:cursorPos(controller)
    lovr.graphics.setColor(1, 1, 1)
    lovr.graphics.cube('fill', x, y, z, .01)
  end
end

local transform = lovr.math.newTransform()
function layout:isHoveredByController(entity, controller)
  if not controller then return false end
  local function addMinimumBuffer(minx, maxx, miny, maxy, minz, maxz, scale)
    local w, h, d = (maxx - minx) * scale, (maxy - miny) * scale, (maxz - minz) * scale
    if w <= .005 then minx = minx + .005 end
    if h <= .005 then miny = miny + .005 end
    if d <= .005 then minz = minz + .005 end
    return minx, maxx, miny, maxy, minz, maxz
  end

  local t = entity
  local model = self.models[t.kind]
  local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
  minx, maxx, miny, maxy, minz, maxz = addMinimumBuffer(minx, maxx, miny, maxy, minz, maxz, t.scale)
  local cx, cy, cz = (minx + maxx) / 2 * t.scale, (miny + maxy) / 2 * t.scale, (minz + maxz) / 2 * t.scale
  minx, maxx, miny, maxy, minz, maxz = t.x + minx * t.scale, t.x + maxx * t.scale, t.y + miny * t.scale, t.y + maxy * t.scale, t.z + minz * t.scale, t.z + maxz * t.scale
  transform:origin()
  transform:translate(t.x, t.y, t.z)
  transform:translate(cx, cy, cz)
  transform:rotate(-t.angle, t.ax, t.ay, t.az)
  transform:translate(-cx, -cy, -cz)
  local x, y, z = self:cursorPos(controller)
  x, y, z = transform:transformPoint(x - t.x, y - t.y, z - t.z)
  return x >= minx and x <= maxx and y >= miny and y <= maxy and z >= minz and z <= maxz
end

function layout:getClosestEntity(controller)
  local x, y, z = self:cursorPos(controller)
  local minDistance, closestEntity = math.huge, nil
  for _, entity in pairs(self.entities) do
    local d = (x - entity.x) ^ 2 + (y - entity.y) ^ 2 + (z - entity.z) ^ 2
    if d < minDistance and self:isHoveredByController(entity, controller) then
      minDistance = d
      closestEntity = entity
    end
  end
  return closestEntity, math.sqrt(minDistance)
end

----------------
-- Entities
----------------
function layout:addEntity(kind, x, y, z, scale, angle, ax, ay, az)
  table.insert(self.entities, {
    locked = false,
    hovered = false,
    hoveredBy = {},
    focused = false,
    focusedBy = {},
    kind = kind,
    x = x, y = y, z = z,
    scale = scale,
    angle = angle, ax = ax, ay = ay, az = az
  })

  return self.entities[#self.entities]
end

-- Probably just put in copy tool
function layout:copyEntity(entity)
  return self:addEntity(entity.kind, entity.x + .1, entity.y + .1, entity.z + .1, entity.scale, entity.angle, entity.ax, entity.ay, entity.az)
end

function layout:removeEntity(entity)
  for i = 1, #self.entities do
    if self.entities[i] == entity then
      table.remove(self.entities, i)
      break
    end
  end
end

function layout:drawEntities()
  for _, entity in ipairs(self.entities) do
    local model = self.models[entity.kind]
    local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
    local cx, cy, cz = (minx + maxx) / 2 * entity.scale, (miny + maxy) / 2 * entity.scale, (minz + maxz) / 2 * entity.scale
    lovr.graphics.push()
    lovr.graphics.translate(entity.x + cx, entity.y + cy, entity.z + cz)
    lovr.graphics.rotate(entity.angle, entity.ax, entity.ay, entity.az)
    lovr.graphics.translate(-entity.x - cx, -entity.y - cy, -entity.z - cz)
    model:draw(entity.x, entity.y, entity.z, entity.scale)
    lovr.graphics.pop()

    self:drawEntityUI(entity)
  end
end

function layout:drawEntityUI(entity)
  local r, g, b = unpack(self.activeColor)
  local alpha = .392
  local highA = .784
  if entity.hovered then alpha = highA end

  local model = self.models[entity.kind]
  local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
  local w, h, d = (maxx - minx) * entity.scale, (maxy - miny) * entity.scale, (maxz - minz) * entity.scale
  local cx, cy, cz = (maxx + minx) / 2 * entity.scale, (maxy + miny) / 2 * entity.scale, (maxz + minz) / 2 * entity.scale

  lovr.graphics.push()
  lovr.graphics.translate(entity.x, entity.y, entity.z)
  lovr.graphics.translate(cx, cy, cz)
  lovr.graphics.rotate(entity.angle, entity.ax, entity.ay, entity.az)
  lovr.graphics.translate(-cx, -cy, -cz)
  if entity.hovered then
    if entity.locked then
      r, g, b = unpack(self.colors.orange)
    end
    lovr.graphics.setColor(r, g, b, alpha)
  else
    r, g, b = unpack(self.colors.default)
    lovr.graphics.setColor(r, g, b, alpha)
  end
  lovr.graphics.box('line', cx, cy, cz, w, h, d)
  lovr.graphics.pop()

  for axis, locked in pairs(self.axisLock) do
    if locked then
      lovr.graphics.setLineWidth(2)
      local x, y, z = entity.x, entity.y, entity.z
      if axis == 'x' then
        local r, g, b = unpack(self.colors.red)
        lovr.graphics.setColor(r, g, b, highA)
        lovr.graphics.line(x - 10, y, z, x + 10, y, z)
      elseif axis == 'y' then
        local r, g, b = unpack(self.colors.green)
        lovr.graphics.setColor(r, g, b, highA)
        lovr.graphics.line(x, y - 10, z, x, y + 10, z)
      elseif axis == 'z' then
        local r, g, b = unpack(self.colors.blue)
        lovr.graphics.setColor(r, g, b, highA)
        lovr.graphics.line(x, y, z - 10, x, y, z + 10)
      end
      lovr.graphics.setLineWidth(1)
    end
  end

  lovr.graphics.setColor(self.colors.default)
end

----------------
-- IO
----------------
function layout:load(filename)
  self.filename = filename
  local path = lovr.filesystem.isFile('levels/'..filename..'.json') and 'levels/'..filename..'.json' or 'default.json'
  self.data = json.decode(lovr.filesystem.read(path))

  if self.data.entities then
    for _, entity in ipairs(self.data.entities) do
      self:addEntity(entity.kind, unpack(entity.transform))
    end
  end
end

--[[
function layout:save()
  local saveData = {}
  self.filename = self.filename or nextFilename('untitled')
  local path = 'levels/'..self.filename..'.json'
  saveData.entities = {}

  for i, entity in ipairs(self.entities) do
    saveData.entities[i] = {
      transform = { entity.x, entity.y, entity.z, entity.scale, entity.angle, entity.ax, entity.ay, entity.az },
      kind = entity.typeId
    }
  end
  print(self.filename, path)
  lovr.filesystem.createDirectory('levels')
  lovr.filesystem.write(path, json.encode(saveData))
end
]]

--[[
function layout:saveAsCopy()
  self.filename = self.filename and self:nextFilename(self.filename) or nil
  self:save()
end

function layout:nextFilename(filename)
  local function versionFilename(name, version) return name .. '-' .. string.format('%02d', version) end
  local i = 1
  while lovr.filesystem.isFile('levels/' .. versionFilename(filename, i) .. '.json') do i = i + 1 end
  return versionFilename(filename, i) -- TODO: make this not return 'mujugarden-02-01'
end
]]

function layout:autosave()
  if self.isDirty and self.lastChange and lovr.timer.getTime() - self.lastChange > 3 then
    --self:save()
    self.isDirty = false
  end
end

function layout:dirty()
  self.isDirty = true
  self.lastChange = lovr.timer.getTime()
end

function layout:loadModels()
  self.models = {}
  local path = 'models'
  for i, file in ipairs(lovr.filesystem.getDirectoryItems(path)) do
    if file:match('%.obj$') or file:match('%.gltf$') or file:match('%.fbx$') then
      if i > 5 then return end
      local id = file:gsub('%.%a+$', '')
      self.models[id] = lovr.graphics.newModel(path .. '/' .. file)
      table.insert(self.models, id)
    end
  end
end

----------------
-- Tools
----------------
function layout:eachTool(action, ...)
  for _, tool in ipairs(self.tools) do
    if tool[action] then tool[action](tool, ...) end
  end
end

return layout
