local json = require 'cjson'

local base = (...):match('^(.*[%./])[^%.%/]+$') or ''
local dot = base:match('%.') and '.' or '/'

local layout = {}

----------------
-- Callbacks
----------------
function layout:init()
  self:loadModels()
  self:refreshControllers()

  self.isDirty = false
  self.lastChange = nil

  self.entities = {}
  self.focus = {}
  self.tools = {}

  for _, t in ipairs({ 'drag', 'rotate', 'scale', 'satchel', 'clear', 'delete', 'copy', 'lock' }) do
    table.insert(self.tools, setmetatable({ layout = self }, { __index = require(base .. 'tools' .. dot .. t) }))
  end

  self:eachTool('init')
end

function layout:update(dt)
  self:autosave()

  -- Calculate hover state
  for i, entity in ipairs(self.entities) do
    entity.hovered = false
    entity.focused = false
    if not entity.locked then
      for _, controller in ipairs(self.controllers) do
        local hovered = self:isHoveredByController(entity, controller)
        entity.hovered = entity.hovered or hovered
        if hovered ~= entity.hoveredBy[controller] then
          entity.hoveredBy[controller] = hovered
          if hovered then controller:vibrate(.002) end
          self:eachTool('hover', entity, hovered, controller)
        end
      end
    end
  end

  -- Use continuous tools
  for controller, focus in pairs(self.focus) do
    focus.entity.focused = true
    focus.tool:use(controller, focus.entity, dt)
  end

  self:eachTool('update', dt)
end

function layout:draw()
  self:drawCursors()
  self:drawEntities()
  self:eachTool('draw')
end

----------------
-- Controllers
----------------
function layout:controllerpressed(controller, rawButton)
  local otherController = self:getOtherController(controller)
  local button = rawButton == 'touchpad' and self:getTouchpadDirection(controller) or rawButton

  -- Tries to use a tool.  This or parts of it should be extracted into in the 'tools' section below
  local function useTool(tool)
    if tool.button ~= button then return end

    local entity = self:getClosestHover(controller, tool.lockpick, tool.twoHanded)
    local context = entity and 'hover' or 'default'
    if tool.context ~= context then return end

    -- If I'm a two-handed tool, I can only be used if:
    --   * Another continuous tool is being used on the same entity that I'm hovering over,
    --     AND that tool has the same button as me.
    --   * No tool is being used on the other controller but it's hovering over the same entity
    --     as me AND it's holding down my button
    if tool.twoHanded then
      local otherButton = rawButton == 'touchpad' and self:getTouchpadDirection(otherController) or rawButton
      local otherFocus = self.focus[otherController]

      if otherFocus then
        if otherFocus.tool.button ~= button or otherFocus.entity ~= entity then
          return
        elseif otherFocus.tool.stop then
          otherFocus.tool:stop(controller, otherFocus.entity)
        end
      elseif not otherController:isDown(rawButton) or otherButton ~= button then
        return
      end
    elseif self.focus[controller] and self.focus[controller].tool.twoHanded then
      return -- two handed tools have priority
    end

    -- A continuous tool calls start once, then calls use in update
    -- Non continuous tools just call use once when the button is pressed
    -- TODO is this weird
    if tool.continuous then
      self.focus[controller] = { tool = tool, entity = entity }
      controller:vibrate(.003)

      if tool.twoHanded then
        self.focus[otherController] = self.focus[controller]
        otherController:vibrate(.003)
      end

      if tool.start then tool:start(controller, entity) end
    else
      if tool.use then tool:use(controller, entity) end
      controller:vibrate(.003)
    end
  end

  self:eachTool('controllerpressed', controller, rawButton)

  if self.focus[controller] then
    local tool = self.focus[controller].tool
    if tool.modifiers and tool.modifiers[button] then
      tool.modifiers[button](tool, controller)
    end
  else
    for _, tool in ipairs(self.tools) do
      useTool(tool)
    end
  end
end

function layout:controllerreleased(controller, rawButton)
  local button = rawButton == 'touchpad' and self:getTouchpadDirection(controller) or rawButton
  self:eachTool('controllerreleased', controller, rawButton)

  if self.focus[controller] then
    local tool = self.focus[controller].tool
    if tool.button == button then
      if tool.stop then tool:stop(controller, self.focus[controller].entity) end
      self.focus[controller] = nil

      if tool.twoHanded then
        self.focus[self:getOtherController(controller)] = nil
        -- FIXME check if we can re-enable a one-handed tool here, maybe use a stack
      end
    end
  end
end

function layout:controlleradded(controller)
  self:refreshControllers()
end

function layout:controllerremoved(controller)
  for i, entity in ipairs(self.entities) do
    entity.hoveredBy[controller] = nil
  end

  if self.focus[controller] then
    if self.focus[controller].tool.stop then self.focus[controller].tool:stop() end
    self.focus[controller] = nil
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

function layout:getTouchpadDirection(controller)
  local touchx, touchy = controller:getAxis('touchx'), controller:getAxis('touchy')
  local angle, distance = math.atan2(touchy, touchx), math.sqrt(touchx * touchx + touchy * touchy)
  angle = math.floor((angle % (2 * math.pi) + (math.pi / 4)) / (math.pi / 2))
  return ({ [0] = 'right', [1] = 'up', [2] = 'left', [3] = 'down' })[angle] or 'right'
end

----------------
-- Cursors
----------------
function layout:cursorPosition(controller)
  local offset = .075
  local x, y, z = controller:getPosition()
  local ox, oy, oz = lovr.math.orientationToDirection(controller:getOrientation())
  return x + ox * offset, y + oy * offset, z + oz * offset
end

function layout:drawCursors()
  for _, controller in ipairs(self.controllers) do
    local x, y, z = self:cursorPosition(controller)
    lovr.graphics.setColor(1, 1, 1)
    lovr.graphics.cube('fill', x, y, z, .01)
  end
end

local transform = lovr.math.newTransform()
function layout:isHoveredByController(entity, controller, includeLocked, includeFocused)

  -- Currently if a controller is focusing on an entity then it can't hover over other entities.
  -- This is okay right now but it prohibits doing interesting things like dragging an entity onto
  -- another entity, so it may need to be adjusted in the future.
  if not controller or (not includeFocused and self.focus[controller]) then return false end
  if not includeLocked and entity.locked then return false end

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
  local x, y, z = self:cursorPosition(controller)
  x, y, z = transform:transformPoint(x - t.x, y - t.y, z - t.z)
  return x >= minx and x <= maxx and y >= miny and y <= maxy and z >= minz and z <= maxz
end

function layout:getClosestHover(controller, includeLocked, includeFocused)
  local x, y, z = self:cursorPosition(controller)
  local minDistance, closestEntity = math.huge, nil
  for _, entity in pairs(self.entities) do
    local d = (x - entity.x) ^ 2 + (y - entity.y) ^ 2 + (z - entity.z) ^ 2
    if d < minDistance and self:isHoveredByController(entity, controller, includeLocked, includeFocused) then
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
    kind = kind,
    x = x, y = y, z = z,
    scale = scale,
    angle = angle, ax = ax, ay = ay, az = az
  })

  return self.entities[#self.entities]
end

function layout:removeEntity(entity)
  for i = 1, #self.entities do
    if self.entities[i] == entity then
      table.remove(self.entities, i)
      break
    end
  end
end

function layout:setLocked(entity, locked)
  entity.locked = locked
end

function layout:setFocus(controller, entity, tool)
  self.focus[controller] = entity
  self:eachTool('focus', controller, entity)
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
    lovr.graphics.setColor(1, 1, 1)
    model:draw(entity.x, entity.y, entity.z, entity.scale)
    lovr.graphics.pop()
    self:drawEntityUI(entity)
  end
end

function layout:drawEntityUI(entity)
  local model = self.models[entity.kind]
  local minx, maxx, miny, maxy, minz, maxz = model:getAABB()
  local w, h, d = (maxx - minx) * entity.scale, (maxy - miny) * entity.scale, (maxz - minz) * entity.scale
  local cx, cy, cz = (maxx + minx) / 2 * entity.scale, (maxy + miny) / 2 * entity.scale, (maxz + minz) / 2 * entity.scale
  local r, g, b, a = 1, 1, 1, .392 * ((entity.hovered or entity.focused) and 2 or 1)

  lovr.graphics.push()
  lovr.graphics.translate(entity.x, entity.y, entity.z)
  lovr.graphics.translate(cx, cy, cz)
  lovr.graphics.rotate(entity.angle, entity.ax, entity.ay, entity.az)
  lovr.graphics.translate(-cx, -cy, -cz)
  lovr.graphics.setColor(r, g, b, a)
  lovr.graphics.box('line', cx, cy, cz, w, h, d)
  lovr.graphics.pop()
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
  local function halp(path)
    for i, file in ipairs(lovr.filesystem.getDirectoryItems(path)) do
      if not file:match('^%.') then
        local filename = path .. '/' .. file
        if lovr.filesystem.isDirectory(filename) then
          halp(filename)
        elseif file:match('%.obj$') or filename:match('%.gltf$') then
          self.models[filename] = lovr.graphics.newModel(filename)
          table.insert(self.models, filename)
        end
      end
    end
  end

  self.models = {}
  halp('models')
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
